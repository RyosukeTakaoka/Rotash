import AVFoundation
import CoreImage
import UIKit
import VideoToolbox

/// 7 分割の枠の中だけにプレビューを出すためのカメラ。
/// 通常のカメラ UI（全画面プレビュー＋確認画面）は意図的に作らない。
final class CameraController: NSObject, ObservableObject {

    enum Status: Equatable {
        case idle
        case ready
        case denied
        case unavailable
    }

    @Published private(set) var status: Status = .idle
    /// 今どちらのカメラを使っているか。自撮り用に前面へ切り替えられる。
    @Published private(set) var position: AVCaptureDevice.Position = .back
    /// Rotash レンズのライブビューに映像を渡せるか。
    /// 映像の出口を追加できなかった端末では false になり、画面は普通のプレビューに戻す
    /// （ここを見ずにレンズ表示にすると、ライブビューが真っ黒のままになる）。
    @Published private(set) var supportsLensPreview = false
    /// パノラマ用にためたコマの数（撮っている間だけ増える）。
    @Published private(set) var panoramaFrameCount = 0

    /// パノラマでためるコマの上限。1コマ 720×960 ほど（約 2.8MB）なので、36 コマで約 100MB。
    static let panoramaMaxFrames = 36

    /// 前と後ろのカメラを同時に動かせる端末か（iPhone XS 以降）。
    /// 同時に動かせるときは、表（大きい画面側）と裏（シャッター側）を同じ瞬間に撮る。
    /// 動かせない端末では、表を撮ったあとカメラを切り替えて裏を続けて撮る。
    let isDual: Bool
    let session: AVCaptureSession
    /// 表の映像の縦横比（短い辺 ÷ 長い辺）。縦持ちの撮影画面で、写る範囲をそのまま見せるのに使う。
    @Published private(set) var frameAspect: CGFloat = 0.75

    /// 同時撮影のときの、前と後ろのカメラそれぞれの一式。画面のスレッドで読み書きする。
    private var rigs: [AVCaptureDevice.Position: Rig] = [:]
    /// いま表になっているカメラの映像の出口（映像のスレッドで、表のコマだけを使うため）。
    private let mainOutput = MainOutputBox()
    /// 同時撮影で、写真ができあがるまで受け取り役を持っておく。
    private var processors: [PhotoProcessor] = []

    private let sessionQueue = DispatchQueue(label: "com.rotash.camera.session")
    private let output = AVCapturePhotoOutput()
    /// Rotash レンズのライブビュー用に、映像を1コマずつ受け取る出口。
    private let videoOutput = AVCaptureVideoDataOutput()
    private let videoQueue = DispatchQueue(label: "com.rotash.camera.video")
    private var device: AVCaptureDevice?
    private var currentInput: AVCaptureDeviceInput?
    private var rotationCoordinator: AVCaptureDevice.RotationCoordinator?
    private var rotationObservation: NSKeyValueObservation?
    /// レンズ表示では普通のプレビューレイヤーを使わないので、撮影側の向きも直接見張る。
    private var captureRotationObservation: NSKeyValueObservation?
    private var isConfigured = false
    private var captureCompletion: ((Data?) -> Void)?

    /// プレビューレイヤーが用意できたら渡してもらう（水平基準の回転を合わせるため）。
    weak var previewLayer: AVCaptureVideoPreviewLayer? {
        didSet { bindRotationCoordinator() }
    }

    /// Rotash レンズのライブビュー。ここに View があるときだけ映像を渡す。
    weak var lensView: LensView? {
        didSet {
            frameGate.setWantsFrames(lensView != nil)
            applyVideoOutputRotation()
        }
    }

    /// - Parameter position: 最初に表（大きい画面側）にするカメラ。
    init(position: AVCaptureDevice.Position = .back) {
        // @Published の中身は、super.init の前にはこの形で入れる。
        _position = Published(initialValue: position)
        let dual = AVCaptureMultiCamSession.isMultiCamSupported
        isDual = dual
        session = dual ? AVCaptureMultiCamSession() : AVCaptureSession()
        super.init()
    }

    /// 裏（シャッター側）のカメラ。
    var reversePosition: AVCaptureDevice.Position { position == .back ? .front : .back }

    /// 同時撮影のとき、そのカメラの映像をそのまま映すレイヤー（表は大きい画面、裏はシャッターの丸）。
    /// 同時撮影できない端末では nil。
    func livePreviewLayer(for position: AVCaptureDevice.Position) -> AVCaptureVideoPreviewLayer? {
        rigs[position]?.previewLayer
    }

    /// 画面から外されたレンズ表示を切り離す（SwiftUI が作り直したとき、古い表示へ映像を送らない）。
    func detachLensView(_ view: LensView) {
        if lensView === view { lensView = nil }
    }

    /// 映像を受け取るスレッドと画面のスレッドのあいだで、
    /// 「View があるか」「前のコマをまだ表示していないか」を安全にやり取りする。
    private let frameGate = FrameGate()

    /// パノラマ用に、映像のコマをためる（映像のスレッドと画面のスレッドで共有）。
    private let panoramaRecorder = PanoramaRecorder()
    private static let ciContext = CIContext(options: [.cacheIntermediates: false])

    // MARK: - パノラマ（試験中）

    /// パノラマ用のコマをため始める。映像の出口（`supportsLensPreview`）が無い端末では何もたまらない。
    func startPanorama() {
        panoramaFrameCount = 0
        panoramaRecorder.start(maxFrames: Self.panoramaMaxFrames)
    }

    /// ためるのをやめて、ためたコマを受け取る。
    func finishPanorama() -> [CGImage] {
        panoramaRecorder.finish()
    }

    /// パノラマ用の1コマ。長い辺を 960px に小さくする（大きいままためると、すぐにメモリが足りなくなる）。
    private static func panoramaFrame(from pixelBuffer: CVPixelBuffer) -> CGImage? {
        let source = CIImage(cvPixelBuffer: pixelBuffer)
        let longSide = max(source.extent.width, source.extent.height)
        guard longSide > 0 else { return nil }
        let scale = min(1, 960 / longSide)
        let scaled = source.transformed(by: CGAffineTransform(scaleX: scale, y: scale))
        return ciContext.createCGImage(scaled, from: scaled.extent.integral)
    }

    // MARK: - Lifecycle

    func start() {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            configureAndRun()
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { [weak self] granted in
                DispatchQueue.main.async {
                    if granted {
                        self?.configureAndRun()
                    } else {
                        self?.status = .denied
                    }
                }
            }
        default:
            DispatchQueue.main.async { self.status = .denied }
        }
    }

    func stop() {
        sessionQueue.async { [weak self] in
            guard let self, self.session.isRunning else { return }
            self.session.stopRunning()
        }
    }

    private func configureAndRun() {
        sessionQueue.async { [weak self] in
            guard let self else { return }
            if !self.isConfigured {
                self.configure()
            }
            guard self.isConfigured else { return }
            if !self.session.isRunning { self.session.startRunning() }
        }
    }

    private func configure() {
        if isDual, let multiCam = session as? AVCaptureMultiCamSession {
            configureDual(multiCam)
            return
        }
        session.beginConfiguration()
        session.sessionPreset = .photo

        guard let camera = device(for: position),
              let input = try? AVCaptureDeviceInput(device: camera),
              session.canAddInput(input),
              session.canAddOutput(output)
        else {
            session.commitConfiguration()
            DispatchQueue.main.async { self.status = .unavailable }
            return
        }

        session.addInput(input)
        session.addOutput(output)

        // レンズ用の出口は無くても撮影はできるので、追加できなければそのまま進む。
        videoOutput.videoSettings = [kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA]
        videoOutput.alwaysDiscardsLateVideoFrames = true
        videoOutput.setSampleBufferDelegate(self, queue: videoQueue)
        let addedVideoOutput = session.canAddOutput(videoOutput)
        if addedVideoOutput {
            session.addOutput(videoOutput)
        }
        configureDevice(camera, photoOutput: output, multiCam: false)
        session.commitConfiguration()

        device = camera
        currentInput = input
        isConfigured = true
        let aspect = Self.aspect(of: camera)

        DispatchQueue.main.async {
            self.supportsLensPreview = addedVideoOutput
            self.frameAspect = aspect
            self.status = .ready
            self.bindRotationCoordinator()
        }
    }

    // MARK: - 同時撮影（前と後ろのカメラを同時に動かす）

    /// 前と後ろのカメラを、どちらも動かし続ける形で組む。
    ///
    /// 同時撮影のセッションでは、カメラと出口を勝手につながないので、つなぎ方をすべて自分で決める
    /// （写真・映像・画面のプレビューの3本を、それぞれのカメラから引く）。
    private func configureDual(_ multiCam: AVCaptureMultiCamSession) {
        guard let devices = Self.dualDevices() else {
            DispatchQueue.main.async { self.status = .unavailable }
            return
        }
        multiCam.beginConfiguration()
        var built: [AVCaptureDevice.Position: Rig] = [:]
        for device in [devices.back, devices.front] {
            if let rig = makeRig(device: device, in: multiCam) { built[device.position] = rig }
        }
        multiCam.commitConfiguration()

        // 2台ぶんの重さが上限（1.0）を超えると動かないので、超えていたら小さいフォーマットに落とす。
        if multiCam.hardwareCost > 1.0 {
            multiCam.beginConfiguration()
            for rig in built.values {
                Self.useLighterFormat(rig.device)
                // 写真の大きさも、新しいフォーマットで撮れる最大に合わせ直す（大きいままだと撮れない）。
                if let largest = rig.device.activeFormat.supportedMaxPhotoDimensions
                    .max(by: { Int($0.width) * Int($0.height) < Int($1.width) * Int($1.height) }) {
                    rig.photoOutput.maxPhotoDimensions = largest
                }
            }
            multiCam.commitConfiguration()
        }

        #if DEBUG
        print("📷 同時撮影 hardwareCost \(multiCam.hardwareCost) systemPressureCost \(multiCam.systemPressureCost)")
        #endif

        guard built[.back] != nil, built[.front] != nil else {
            DispatchQueue.main.async { self.status = .unavailable }
            return
        }
        isConfigured = true

        DispatchQueue.main.async {
            self.rigs = built
            self.mainOutput.set(built[self.position]?.videoOutput)
            self.frameAspect = built[self.position].map { Self.aspect(of: $0.device) } ?? 0.75
            self.supportsLensPreview = true
            self.status = .ready
            self.bindRotationCoordinator()
        }
    }

    /// 同時に動かせる組み合わせのうち、後ろは超広角（あれば）、前は普通の広角。
    private static func dualDevices() -> (back: AVCaptureDevice, front: AVCaptureDevice)? {
        let discovery = AVCaptureDevice.DiscoverySession(
            deviceTypes: [.builtInUltraWideCamera, .builtInWideAngleCamera],
            mediaType: .video, position: .unspecified)
        let sets = discovery.supportedMultiCamDeviceSets
        func pick(_ backType: AVCaptureDevice.DeviceType) -> (back: AVCaptureDevice, front: AVCaptureDevice)? {
            for set in sets {
                if let back = set.first(where: { $0.position == .back && $0.deviceType == backType }),
                   let front = set.first(where: { $0.position == .front && $0.deviceType == .builtInWideAngleCamera }) {
                    return (back, front)
                }
            }
            return nil
        }
        if RotashFeatureFlags.prefersUltraWideBackCamera, let pair = pick(.builtInUltraWideCamera) { return pair }
        return pick(.builtInWideAngleCamera)
    }

    /// 1台のカメラから、写真・映像・プレビューの3本をつなぐ。セッションの設定中に呼ぶ。
    private func makeRig(device: AVCaptureDevice, in multiCam: AVCaptureMultiCamSession) -> Rig? {
        guard let input = try? AVCaptureDeviceInput(device: device), multiCam.canAddInput(input) else { return nil }
        multiCam.addInputWithNoConnections(input)
        guard let port = input.ports(for: .video, sourceDeviceType: device.deviceType,
                                     sourceDevicePosition: device.position).first
        else { return nil }

        let rig = Rig(device: device, input: input, session: multiCam)
        let mirrored = device.position == .front

        // 写真
        guard multiCam.canAddOutput(rig.photoOutput) else { return nil }
        multiCam.addOutputWithNoConnections(rig.photoOutput)
        let photoConnection = AVCaptureConnection(inputPorts: [port], output: rig.photoOutput)
        guard multiCam.canAddConnection(photoConnection) else { return nil }
        multiCam.addConnection(photoConnection)
        Self.setMirrored(photoConnection, mirrored)

        // 映像（Rotash レンズのライブビューとパノラマ用）
        rig.videoOutput.videoSettings = [kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA]
        rig.videoOutput.alwaysDiscardsLateVideoFrames = true
        rig.videoOutput.setSampleBufferDelegate(self, queue: videoQueue)
        if multiCam.canAddOutput(rig.videoOutput) {
            multiCam.addOutputWithNoConnections(rig.videoOutput)
            let videoConnection = AVCaptureConnection(inputPorts: [port], output: rig.videoOutput)
            if multiCam.canAddConnection(videoConnection) {
                multiCam.addConnection(videoConnection)
                Self.setMirrored(videoConnection, mirrored)
            }
        }

        // 画面のプレビュー
        let previewConnection = AVCaptureConnection(inputPort: port, videoPreviewLayer: rig.previewLayer)
        if multiCam.canAddConnection(previewConnection) {
            multiCam.addConnection(previewConnection)
            Self.setMirrored(previewConnection, mirrored)
        }

        configureDevice(device, photoOutput: rig.photoOutput, multiCam: true)
        return rig
    }

    /// 同時撮影で使えるフォーマットのうち、映像が横 1280 以下でいちばん大きいものにする（重さを下げる）。
    private static func useLighterFormat(_ device: AVCaptureDevice) {
        let candidates = device.formats.filter {
            $0.isMultiCamSupported && CMVideoFormatDescriptionGetDimensions($0.formatDescription).width <= 1280
        }
        guard let lighter = candidates.max(by: {
            CMVideoFormatDescriptionGetDimensions($0.formatDescription).width
                < CMVideoFormatDescriptionGetDimensions($1.formatDescription).width
        }), (try? device.lockForConfiguration()) != nil else { return }
        device.activeFormat = lighter
        device.unlockForConfiguration()
    }

    /// 内カメは鏡写しにする（画面で見たとおりに残す。自撮りで右手を上げたら右側が動く）。
    private static func setMirrored(_ connection: AVCaptureConnection, _ mirrored: Bool) {
        guard connection.isVideoMirroringSupported else { return }
        connection.automaticallyAdjustsVideoMirroring = false
        connection.isVideoMirrored = mirrored
    }

    /// カメラの映像の縦横比（短い辺 ÷ 長い辺）。
    private static func aspect(of device: AVCaptureDevice) -> CGFloat {
        let dims = CMVideoFormatDescriptionGetDimensions(device.activeFormat.formatDescription)
        guard dims.width > 0, dims.height > 0 else { return 0.75 }
        return CGFloat(min(dims.width, dims.height)) / CGFloat(max(dims.width, dims.height))
    }

    /// 使うカメラを選ぶ。枠が細いので、レンズそのものが広いほうが「撮るものがない」が起きにくい。
    ///
    /// - 外カメ: 超広角（0.5倍）があればそちら。無い機種（SE など）は普通の広角。
    /// - 内カメ: センターフレーム対応の iPad などは、内カメそのものが超広角なのでそちら。
    ///   iPhone の内カメは超広角レンズを持たないので普通の広角を使い、
    ///   `configureDevice` でセンサーを最も広く読むモードに切り替える（純正カメラの矢印ボタンで広がる状態）。
    ///   TrueDepth は深度のためのもので、選んでも広くはならないので使わない。
    private func device(for position: AVCaptureDevice.Position) -> AVCaptureDevice? {
        let prefersUltraWide = position == .back
            ? RotashFeatureFlags.prefersUltraWideBackCamera
            : RotashFeatureFlags.prefersWidestFrontCamera
        if prefersUltraWide,
           let ultraWide = AVCaptureDevice.default(.builtInUltraWideCamera, for: .video, position: position) {
            return ultraWide
        }
        return AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: position)
    }

    /// カメラを「いちばん広く写る状態」にそろえる。セッションの設定中（begin/commit のあいだ）に呼ぶ。
    ///
    /// 同じカメラでも、読み出し方（フォーマット）によって写る範囲が違う。
    /// 純正カメラの内カメは既定で少し切り出していて、矢印ボタンでセンサー全体に広がる。
    /// ここでは写る範囲（画角）がいちばん広いフォーマットを選び、ズームも最小にする。
    ///
    /// 7分割の枠は縦に細長く、写る範囲は「高さ」で決まるので、縦の画角で比べる
    /// （同じ横の画角なら 16:9 より 4:3 のほうが縦に広い）。
    /// - Parameter multiCam: 同時撮影か。同時撮影で使えるフォーマットだけから選び、重すぎないものにする。
    private func configureDevice(_ device: AVCaptureDevice, photoOutput: AVCapturePhotoOutput, multiCam: Bool) {
        do {
            try device.lockForConfiguration()
            defer { device.unlockForConfiguration() }

            if RotashFeatureFlags.prefersWidestFrontCamera || device.position == .back,
               let widest = Self.widestPhotoFormat(of: device, multiCam: multiCam),
               widest != device.activeFormat {
                // activeFormat を直接決めると、セッションのプリセットは inputPriority に切り替わる。
                device.activeFormat = widest
            }

            // 同時撮影では、同時撮影に使えないフォーマットのままだとセッションが動かないので必ず替える。
            if multiCam, !device.activeFormat.isMultiCamSupported,
               let fallback = device.formats.last(where: { $0.isMultiCamSupported }) {
                device.activeFormat = fallback
            }

            // ズームで狭めない（仮想カメラでなければ最小は 1.0）。
            device.videoZoomFactor = max(device.minAvailableVideoZoomFactor, 1.0)

            if device.isFocusModeSupported(.continuousAutoFocus) {
                device.focusMode = .continuousAutoFocus
            }
            if device.isExposureModeSupported(.continuousAutoExposure) {
                device.exposureMode = .continuousAutoExposure
            }

            #if DEBUG
            let dims = CMVideoFormatDescriptionGetDimensions(device.activeFormat.formatDescription)
            print("📷 \(device.localizedName) \(dims.width)x\(dims.height) " +
                  "FOV \(device.activeFormat.videoFieldOfView)° zoom \(device.videoZoomFactor)")
            #endif
        } catch {
            #if DEBUG
            print("📷 カメラの設定に失敗:", error)
            #endif
        }

        // 写真も、選んだフォーマットでいちばん大きく撮る（小さいままだと画質が落ちる）。
        if let largest = device.activeFormat.supportedMaxPhotoDimensions
            .max(by: { Int($0.width) * Int($0.height) < Int($1.width) * Int($1.height) }) {
            photoOutput.maxPhotoDimensions = largest
        }
        applyDistortionCorrection(to: photoOutput)
    }

    /// Apple の「内容を見て歪みを直す」補正（設定画面でオンにしたときだけ）。
    ///
    /// 広角レンズの端で顔などが引き伸ばされるのを、写っているものを見ながら直す機能。
    /// 撮った写真にだけ効き、ライブビューには効かない。対応していないカメラ（多くの内カメ）では何もしない。
    /// セッションのスレッドで呼ぶこと。
    private func applyDistortionCorrection(to output: AVCapturePhotoOutput) {
        let wanted = UserDefaults.standard.bool(forKey: RotashLens.appleCorrectionKey)
        guard output.isContentAwareDistortionCorrectionSupported else {
            #if DEBUG
            if wanted { print("📷 このカメラは Apple の歪み補正に対応していない") }
            #endif
            return
        }
        if output.isContentAwareDistortionCorrectionEnabled != wanted {
            output.isContentAwareDistortionCorrectionEnabled = wanted
        }
    }

    /// 写真が撮れるフォーマットのうち、縦の画角がいちばん広いもの。
    /// 同じくらいなら、映像が重すぎない（横 1920 以下）もの、写真が大きいものを選ぶ。
    /// 同時撮影（`multiCam`）では、同時撮影で使えるもの、かつ映像が横 1920 以下のものに限る
    /// （2台ぶんの重さが上限を超えると、セッションが動かない）。
    static func widestPhotoFormat(of device: AVCaptureDevice, multiCam: Bool = false) -> AVCaptureDevice.Format? {
        func verticalFOV(_ format: AVCaptureDevice.Format) -> Double {
            let dims = CMVideoFormatDescriptionGetDimensions(format.formatDescription)
            guard dims.width > 0, dims.height > 0 else { return 0 }
            let horizontal = Double(format.videoFieldOfView) * .pi / 180
            let short = Double(min(dims.width, dims.height)), long = Double(max(dims.width, dims.height))
            return 2 * atan(tan(horizontal / 2) * short / long)
        }
        func photoPixels(_ format: AVCaptureDevice.Format) -> Int {
            format.supportedMaxPhotoDimensions.map { Int($0.width) * Int($0.height) }.max() ?? 0
        }
        func isLight(_ format: AVCaptureDevice.Format) -> Bool {
            CMVideoFormatDescriptionGetDimensions(format.formatDescription).width <= 1920
        }

        return device.formats
            .filter { photoPixels($0) > 0 }
            .filter { !multiCam || ($0.isMultiCamSupported && isLight($0)) }
            .max { a, b in
                let fa = verticalFOV(a), fb = verticalFOV(b)
                // 0.5° 未満の差は同じ広さとみなす。
                if abs(fa - fb) > 0.5 * .pi / 180 { return fa < fb }
                if isLight(a) != isLight(b) { return !isLight(a) }
                return photoPixels(a) < photoPixels(b)
            }
    }

    // MARK: - 前面 / 背面切り替え（自撮り対応）

    /// 表と裏のカメラを入れ替える（FLIP）。撮影中は呼び出し側で無効化しておくこと。
    ///
    /// 同時撮影では両方のカメラが動いているので、役割を入れ替えるだけ（一瞬で終わる）。
    /// 同時撮影できない端末では、動かしているカメラそのものを切り替える。
    /// - Parameter completion: 切り替え終わったら画面のスレッドで呼ぶ。
    func switchCamera(completion: (() -> Void)? = nil) {
        if isDual {
            position = reversePosition
            mainOutput.set(rigs[position]?.videoOutput)
            if let rig = rigs[position] { frameAspect = Self.aspect(of: rig.device) }
            completion?()
            return
        }
        sessionQueue.async { [weak self] in
            guard let self, self.isConfigured else { return }
            let newPosition: AVCaptureDevice.Position = self.position == .back ? .front : .back

            guard let newDevice = self.device(for: newPosition),
                  let newInput = try? AVCaptureDeviceInput(device: newDevice)
            else { return }

            self.session.beginConfiguration()
            if let oldInput = self.currentInput {
                self.session.removeInput(oldInput)
            }
            if self.session.canAddInput(newInput) {
                self.session.addInput(newInput)
                self.currentInput = newInput
                self.device = newDevice
                self.configureDevice(newDevice, photoOutput: self.output, multiCam: false)
            } else if let oldInput = self.currentInput {
                // 追加できなかった場合は元に戻す。
                self.session.addInput(oldInput)
            }
            self.session.commitConfiguration()

            let aspect = Self.aspect(of: self.device ?? newDevice)
            DispatchQueue.main.async {
                self.position = newPosition
                self.frameAspect = aspect
                self.bindRotationCoordinator()
                completion?()
            }
        }
    }

    // MARK: - Rotation

    private func bindRotationCoordinator() {
        if isDual {
            bindDualRotation()
            return
        }
        guard let device else { return }
        let coordinator = AVCaptureDevice.RotationCoordinator(device: device, previewLayer: previewLayer)
        rotationCoordinator = coordinator
        applyPreviewRotation()
        applyVideoOutputRotation()
        rotationObservation = coordinator.observe(\.videoRotationAngleForHorizonLevelPreview, options: [.new]) { [weak self] _, _ in
            DispatchQueue.main.async { self?.applyPreviewRotation() }
        }
        captureRotationObservation = coordinator.observe(\.videoRotationAngleForHorizonLevelCapture, options: [.new]) { [weak self] _, _ in
            DispatchQueue.main.async { self?.applyVideoOutputRotation() }
        }
    }

    private func applyPreviewRotation() {
        guard let angle = rotationCoordinator?.videoRotationAngleForHorizonLevelPreview,
              let connection = previewLayer?.connection,
              connection.isVideoRotationAngleSupported(angle)
        else { return }
        connection.videoRotationAngle = angle
    }

    /// レンズ用の映像を、撮る写真と同じ向き（水平基準）で受け取れるようにする。
    /// 内カメは普通のプレビューと同じく鏡写しにする（自撮りで右手を上げたら右側が動く）。
    private func applyVideoOutputRotation() {
        if isDual {
            rigs.values.forEach(applyCaptureRotation)
            return
        }
        let angle = rotationCoordinator?.videoRotationAngleForHorizonLevelCapture
        sessionQueue.async { [weak self] in
            guard let self, let connection = self.videoOutput.connection(with: .video) else { return }
            if let angle, connection.isVideoRotationAngleSupported(angle) {
                connection.videoRotationAngle = angle
            }
            if connection.isVideoMirroringSupported {
                connection.automaticallyAdjustsVideoMirroring = false
                connection.isVideoMirrored = self.device?.position == .front
            }
        }
    }

    /// 同時撮影では、カメラごとに向きを見張る（プレビュー・写真・映像のすべてを水平に合わせる）。
    private func bindDualRotation() {
        for rig in rigs.values {
            let coordinator = AVCaptureDevice.RotationCoordinator(device: rig.device, previewLayer: rig.previewLayer)
            rig.rotationCoordinator = coordinator
            applyPreviewRotation(rig)
            applyCaptureRotation(rig)
            rig.observations = [
                coordinator.observe(\.videoRotationAngleForHorizonLevelPreview, options: [.new]) { [weak self, weak rig] _, _ in
                    DispatchQueue.main.async { if let rig { self?.applyPreviewRotation(rig) } }
                },
                coordinator.observe(\.videoRotationAngleForHorizonLevelCapture, options: [.new]) { [weak self, weak rig] _, _ in
                    DispatchQueue.main.async { if let rig { self?.applyCaptureRotation(rig) } }
                }
            ]
        }
    }

    private func applyPreviewRotation(_ rig: Rig) {
        guard let angle = rig.rotationCoordinator?.videoRotationAngleForHorizonLevelPreview,
              let connection = rig.previewLayer.connection,
              connection.isVideoRotationAngleSupported(angle)
        else { return }
        connection.videoRotationAngle = angle
    }

    private func applyCaptureRotation(_ rig: Rig) {
        guard let angle = rig.rotationCoordinator?.videoRotationAngleForHorizonLevelCapture else { return }
        sessionQueue.async {
            for output in [rig.photoOutput as AVCaptureOutput, rig.videoOutput] {
                if let connection = output.connection(with: .video), connection.isVideoRotationAngleSupported(angle) {
                    connection.videoRotationAngle = angle
                }
            }
        }
    }

    // MARK: - Capture

    /// 表（大きい画面側）と裏（シャッター側）を撮る。
    ///
    /// - 同時撮影の端末: 2台のカメラで同じ瞬間に撮る
    /// - それ以外: 表を撮ってからカメラを切り替え、少し待って裏を撮り、元に戻す（BeReal と同じく少しずれる）
    /// - Parameter completion: 表と裏の JPEG。撮れなかった方は nil。画面のスレッドで呼ぶ。
    func captureBoth(fallbackSeed: Int = 0, completion: @escaping (_ main: Data?, _ reverse: Data?) -> Void) {
        guard status == .ready else {
            completion(SimulatedCapture.jpegData(seed: fallbackSeed), nil)
            return
        }
        guard isDual else {
            captureSequentially(fallbackSeed: fallbackSeed, completion: completion)
            return
        }
        guard let mainRig = rigs[position], let reverseRig = rigs[reversePosition] else {
            completion(nil, nil)
            return
        }

        sessionQueue.async { [weak self] in
            guard let self else { return }
            let group = DispatchGroup()
            var results: [AVCaptureDevice.Position: Data] = [:]
            let lock = NSLock()
            for rig in [mainRig, reverseRig] {
                if let angle = rig.rotationCoordinator?.videoRotationAngleForHorizonLevelCapture,
                   let connection = rig.photoOutput.connection(with: .video),
                   connection.isVideoRotationAngleSupported(angle) {
                    connection.videoRotationAngle = angle
                }
                self.applyDistortionCorrection(to: rig.photoOutput)
                let settings = AVCapturePhotoSettings()
                settings.flashMode = .off
                settings.maxPhotoDimensions = rig.photoOutput.maxPhotoDimensions

                group.enter()
                let position = rig.device.position
                let processor = PhotoProcessor { data in
                    lock.lock()
                    if let data { results[position] = data }
                    lock.unlock()
                    group.leave()
                }
                self.processors.append(processor)
                rig.photoOutput.capturePhoto(with: settings, delegate: processor)
            }
            group.notify(queue: .main) {
                self.sessionQueue.async { self.processors.removeAll() }
                completion(results[mainRig.device.position], results[reverseRig.device.position])
            }
        }
    }

    /// 同時撮影できない端末: 表 → カメラを切り替える → 少し待って裏 → 元に戻す。
    private func captureSequentially(fallbackSeed: Int, completion: @escaping (Data?, Data?) -> Void) {
        capture(fallbackSeed: fallbackSeed) { [weak self] main in
            guard let self else { return completion(main, nil) }
            self.switchCamera {
                // 切り替えた直後は明るさやピントが合っていないので、少しだけ待つ。
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.45) {
                    self.capture(fallbackSeed: fallbackSeed) { reverse in
                        self.switchCamera {
                            completion(main, reverse)
                        }
                    }
                }
            }
        }
    }

    /// 撮影。確認画面は出さず、そのまま枠に入る。
    func capture(fallbackSeed: Int = 0, completion: @escaping (Data?) -> Void) {
        guard status == .ready else {
            completion(SimulatedCapture.jpegData(seed: fallbackSeed))
            return
        }

        captureCompletion = completion
        let angle = rotationCoordinator?.videoRotationAngleForHorizonLevelCapture

        sessionQueue.async { [weak self] in
            guard let self else { return }
            if let angle,
               let connection = self.output.connection(with: .video),
               connection.isVideoRotationAngleSupported(angle) {
                connection.videoRotationAngle = angle
            }
            // 設定画面で切り替えたばかりでも、この1枚から効くように撮る直前にも合わせる。
            self.applyDistortionCorrection(to: self.output)
            let settings = AVCapturePhotoSettings()
            settings.flashMode = .off
            settings.maxPhotoDimensions = self.output.maxPhotoDimensions
            self.output.capturePhoto(with: settings, delegate: self)
        }
    }

    private func finish(with data: Data?) {
        DispatchQueue.main.async {
            let completion = self.captureCompletion
            self.captureCompletion = nil
            completion?(data)
        }
    }
}

// MARK: - AVCapturePhotoCaptureDelegate

extension CameraController: AVCapturePhotoCaptureDelegate {
    func photoOutput(_ output: AVCapturePhotoOutput,
                     didFinishProcessingPhoto photo: AVCapturePhoto,
                     error: Error?) {
        guard error == nil,
              let raw = photo.fileDataRepresentation(),
              let image = UIImage(data: raw),
              let jpeg = image.rotashJPEGData()
        else {
            finish(with: nil)
            return
        }
        finish(with: jpeg)
    }
}

// MARK: - AVCaptureVideoDataOutputSampleBufferDelegate（Rotash レンズのライブビュー）

extension CameraController: AVCaptureVideoDataOutputSampleBufferDelegate {
    func captureOutput(_ output: AVCaptureOutput,
                       didOutput sampleBuffer: CMSampleBuffer,
                       from connection: AVCaptureConnection) {
        // 同時撮影では2台ぶんのコマが届くので、表のカメラのコマだけを使う（裏はシャッターの丸がそのまま映す）。
        if isDual, !mainOutput.isMain(output) { return }

        // パノラマを撮っている間は、画面に出すかどうかに関係なくコマをためる。
        if panoramaRecorder.wantsFrame(), let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer),
           let frame = Self.panoramaFrame(from: pixelBuffer) {
            let count = panoramaRecorder.append(frame)
            DispatchQueue.main.async { [weak self] in self?.panoramaFrameCount = count }
        }

        // 前のコマをまだ画面に出していなければ、このコマは捨てる（遅れを溜めない）。
        guard frameGate.beginFrame() else { return }

        var image: CGImage?
        if let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) {
            _ = VTCreateCGImageFromCVPixelBuffer(pixelBuffer, options: nil, imageOut: &image)
        }
        guard let image else {
            frameGate.endFrame()
            return
        }

        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            if let lensView = self.lensView {
                lensView.display(image)
            } else {
                // View が閉じられた（weak なので didSet は呼ばれない）。変換をやめる。
                self.frameGate.setWantsFrames(false)
            }
            self.frameGate.endFrame()
        }
    }
}

/// 同時撮影での、1台のカメラの一式（写真・映像・プレビュー）。
private final class Rig {
    let device: AVCaptureDevice
    let input: AVCaptureDeviceInput
    let photoOutput = AVCapturePhotoOutput()
    let videoOutput = AVCaptureVideoDataOutput()
    let previewLayer: AVCaptureVideoPreviewLayer
    var rotationCoordinator: AVCaptureDevice.RotationCoordinator?
    var observations: [NSKeyValueObservation] = []

    init(device: AVCaptureDevice, input: AVCaptureDeviceInput, session: AVCaptureMultiCamSession) {
        self.device = device
        self.input = input
        previewLayer = AVCaptureVideoPreviewLayer(sessionWithNoConnection: session)
        previewLayer.videoGravity = .resizeAspectFill
    }
}

/// いま表になっているカメラの映像の出口。映像のスレッドと画面のスレッドで共有する。
private final class MainOutputBox {
    private let lock = NSLock()
    private weak var output: AVCaptureOutput?

    func set(_ output: AVCaptureOutput?) {
        lock.lock()
        self.output = output
        lock.unlock()
    }

    func isMain(_ candidate: AVCaptureOutput) -> Bool {
        lock.lock()
        defer { lock.unlock() }
        return output === candidate
    }
}

/// 同時撮影で、1枚の写真ができあがったら JPEG にして返す受け取り役。
private final class PhotoProcessor: NSObject, AVCapturePhotoCaptureDelegate {
    private let completion: (Data?) -> Void

    init(completion: @escaping (Data?) -> Void) {
        self.completion = completion
    }

    func photoOutput(_ output: AVCapturePhotoOutput,
                     didFinishProcessingPhoto photo: AVCapturePhoto,
                     error: Error?) {
        guard error == nil,
              let raw = photo.fileDataRepresentation(),
              let image = UIImage(data: raw),
              let jpeg = image.rotashJPEGData()
        else {
            completion(nil)
            return
        }
        completion(jpeg)
    }
}

/// パノラマ用のコマをためる箱。映像のスレッドでためて、画面のスレッドで受け取る。
private final class PanoramaRecorder {
    private let lock = NSLock()
    private var isRecording = false
    private var frames: [CGImage] = []
    private var maxFrames = 0
    private var tick = 0

    func start(maxFrames: Int) {
        lock.lock()
        frames = []
        self.maxFrames = maxFrames
        tick = 0
        isRecording = true
        lock.unlock()
    }

    /// このコマをためるか。毎秒 30 コマのうち 10 コマだけためる（となりのコマが近すぎても役に立たない）。
    func wantsFrame() -> Bool {
        lock.lock()
        defer { lock.unlock() }
        guard isRecording, frames.count < maxFrames else { return false }
        tick += 1
        return tick % 3 == 1
    }

    /// ためて、いまの数を返す。
    func append(_ frame: CGImage) -> Int {
        lock.lock()
        defer { lock.unlock() }
        if isRecording, frames.count < maxFrames { frames.append(frame) }
        return frames.count
    }

    func finish() -> [CGImage] {
        lock.lock()
        defer { lock.unlock() }
        isRecording = false
        let result = frames
        frames = []
        return result
    }
}

/// 映像のスレッドと画面のスレッドで共有する小さな状態。
private final class FrameGate {
    private let lock = NSLock()
    private var wantsFrames = false
    private var isFramePending = false

    func setWantsFrames(_ wants: Bool) {
        lock.lock()
        wantsFrames = wants
        lock.unlock()
    }

    /// このコマを表示しに行ってよいか。よければ「表示中」にする。
    func beginFrame() -> Bool {
        lock.lock()
        defer { lock.unlock() }
        guard wantsFrames, !isFramePending else { return false }
        isFramePending = true
        return true
    }

    func endFrame() {
        lock.lock()
        isFramePending = false
        lock.unlock()
    }
}

// MARK: - Simulator fallback

/// シミュレータにはカメラが無いので、7 分割の埋まり方だけ確認できるようにダミーを作る。
/// 実機では使われない。
enum SimulatedCapture {
    static func jpegData(seed: Int) -> Data? {
        #if targetEnvironment(simulator)
        let size = CGSize(width: 1600, height: 1200)
        let tone = 0.18 + Double(seed % 7) * 0.09
        let renderer = UIGraphicsImageRenderer(size: size)
        let image = renderer.image { context in
            UIColor(white: tone, alpha: 1).setFill()
            context.fill(CGRect(origin: .zero, size: size))
            UIColor(white: tone + 0.10, alpha: 1).setFill()
            context.fill(CGRect(x: 0, y: size.height * 0.62, width: size.width, height: 2))
        }
        return image.jpegData(compressionQuality: 0.9)
        #else
        return nil
        #endif
    }
}

// MARK: - パノラマのつなぎ合わせ（試験中）

/// 上下または左右に動かしながら撮ったコマを、1枚のパノラマにつなぐ（試験中）。
///
/// # なぜ上下にも振れるようにしたか
///
/// 縦持ちの内カメで足りないのは「高さ」。横はもともと余っている。
/// 上下に振ってつなげば高さが増えるので、上下の黒も曲げも無しで縮めて、横を広く入れられる。
/// 左右に振れば、横がさらに広い写真になる。どちらに振ったかは、つないだずれの大きさで自動で決める。
///
/// # 手順
///
/// 1. コマごとに Vision の人物の切り抜きで「人」を見つけ、人ではない所（背景）だけで、
///    となりのコマとのずれを求める。自撮りでは人はいつも画面の同じ所にいるので、人を入れると
///    「ずれていない」と間違える
///    - 小さくした画像の明るさの変わり目を、列ごと・行ごとに平均した1次元の形でおおまかに合わせ
///    - 2次元の差で ±3px だけ詰め、放物線で 1px より細かく寄せる（つなぐほど誤差が積もるので）
/// 2. 重なる所の明るさの比から、コマごとの明るさをそろえる（そろえないと空に横じまが出る）
/// 3. 背景は、人を除いたコマを、ふちをぼかしながら重ねて平均する
/// 4. 人は、真ん中のコマから1回だけ重ねる（何コマも重ねると人が何人にも見える）
/// 5. どのコマでも人に隠れていた所（上下に振ったときの体のうしろなど）は、
///    多すぎる端は切り落とし、少しだけ残ったら上下のとなりの色で埋める
///
/// 重いので、画面のスレッドでは呼ばないこと。
enum PanoramaStitcher {

    /// 大まかに合わせるときの画像の幅と、詰めるときの幅。
    private static let coarseWidth = 160
    private static let fineWidth = 320
    /// コマのふちを、どれだけの幅でぼかして重ねるか（px）。
    private static let feather: Float = 48
    /// 動かした向きに、1コマの何倍まで広げるか（それより先は切る）。広すぎると枠では使い切れない。
    static let maxSpan: CGFloat = 2.0

    static func stitch(_ input: [CGImage]) -> CGImage? {
        guard let first = input.first else { return nil }
        let frameWidth = first.width, frameHeight = first.height
        let frames = input.filter { $0.width == frameWidth && $0.height == frameHeight }
        guard frames.count >= 3 else { return nil }
        let count = frames.count

        // ---- 1. 人の切り抜きと、ずれ
        let masks = frames.map { frame -> MaskGrid? in
            LensAnalyzer.personMask(frame, live: true).map(MaskGrid.init(buffer:))
        }
        // 太らせた人の所は何度も使うので、先に1回だけ求めておく。
        let grownMasks = masks.map { $0?.grown }
        var offsets: [(x: CGFloat, y: CGFloat)] = [(0, 0)]
        var gains: [CGFloat] = [1]
        var previous: Level?
        for index in 0..<count {
            guard let current = Level(frame: frames[index], grown: grownMasks[index]) else { return nil }
            if let previous {
                let coarseX = match(previous.columns, current.columns, maxShift: coarseWidth / 3)
                let coarseY = match(previous.rows, current.rows, maxShift: coarseWidth / 3)
                let fine = refine(previous, current, dx: coarseX * fineWidth / coarseWidth,
                                  dy: coarseY * fineWidth / coarseWidth, radius: 3)
                let toFrame = CGFloat(frameWidth) / CGFloat(fineWidth)
                let last = offsets[offsets.count - 1]
                offsets.append((last.x + fine.x * toFrame, last.y + fine.y * toFrame))
                gains.append(gains[gains.count - 1] * brightnessRatio(previous, current, dx: fine.x, dy: fine.y))
            }
            previous = current
        }

        // ---- 並べる範囲
        let reference = count / 2
        let xs = offsets.map { $0.x }, ys = offsets.map { $0.y }
        guard let minX = xs.min(), let maxX = xs.max(), let minY = ys.min(), let maxY = ys.max() else { return nil }
        let vertical = (maxY - minY) >= (maxX - minX)
        var left: CGFloat, right: CGFloat, top: CGFloat, bottom: CGFloat
        if vertical {
            // 横は全部のコマが重なる所だけ、縦は広げる（1コマの maxSpan 倍まで）。
            left = maxX; right = minX + CGFloat(frameWidth)
            let middle = ys[reference] + CGFloat(frameHeight) / 2, half = maxSpan * CGFloat(frameHeight) / 2
            top = max(minY, middle - half); bottom = min(maxY + CGFloat(frameHeight), middle + half)
        } else {
            top = maxY; bottom = minY + CGFloat(frameHeight)
            let middle = xs[reference] + CGFloat(frameWidth) / 2, half = maxSpan * CGFloat(frameWidth) / 2
            left = max(minX, middle - half); right = min(maxX + CGFloat(frameWidth), middle + half)
        }
        let width = Int((right - left).rounded(.down)), height = Int((bottom - top).rounded(.down))
        guard width >= frameWidth / 2, height >= frameHeight / 2 else { return nil }

        // ---- 3. 背景を重ねる
        let base = gains[reference]
        var accumulated = [Float](repeating: 0, count: width * height * 3)
        var weights = [Float](repeating: 0, count: width * height)
        for index in 0..<count {
            guard let pixels = rgba(frames[index]) else { continue }
            let originX = Int((xs[index] - left).rounded()), originY = Int((ys[index] - top).rounded())
            let gain = Float(gains[index] / base)
            let grown = grownMasks[index]
            let x0 = max(0, originX), x1 = min(width, originX + frameWidth)
            let y0 = max(0, originY), y1 = min(height, originY + frameHeight)
            guard x1 > x0, y1 > y0 else { continue }
            for y in y0..<y1 {
                let fy = y - originY
                let edgeY = Float(min(fy + 1, frameHeight - fy))
                for x in x0..<x1 {
                    let fx = x - originX
                    if let grown, grown.isPerson(x: fx, y: fy, frameWidth: frameWidth, frameHeight: frameHeight) {
                        continue
                    }
                    let edge = min(Float(min(fx + 1, frameWidth - fx)), edgeY)
                    let weight = min(1, max(0.02, edge / feather))
                    let source = (fy * frameWidth + fx) * 4
                    let target = y * width + x
                    accumulated[target * 3] += Float(pixels[source]) * gain * weight
                    accumulated[target * 3 + 1] += Float(pixels[source + 1]) * gain * weight
                    accumulated[target * 3 + 2] += Float(pixels[source + 2]) * gain * weight
                    weights[target] += weight
                }
            }
        }
        var canvas = [Float](repeating: 0, count: width * height * 3)
        var filled = [Bool](repeating: false, count: width * height)
        for index in 0..<(width * height) where weights[index] > 0.001 {
            canvas[index * 3] = accumulated[index * 3] / weights[index]
            canvas[index * 3 + 1] = accumulated[index * 3 + 1] / weights[index]
            canvas[index * 3 + 2] = accumulated[index * 3 + 2] / weights[index]
            filled[index] = true
        }
        accumulated = []

        // ---- 4. 人は真ん中のコマから
        let referenceX = Int((xs[reference] - left).rounded()), referenceY = Int((ys[reference] - top).rounded())
        let personRows = max(0, referenceY)..<max(max(0, referenceY), min(height, referenceY + frameHeight))
        let personColumns = max(0, referenceX)..<max(max(0, referenceX), min(width, referenceX + frameWidth))
        if let pixels = rgba(frames[reference]), let mask = masks[reference] {
            for y in personRows {
                let fy = y - referenceY
                for x in personColumns {
                    let fx = x - referenceX
                    let alpha = mask.value(x: fx, y: fy, frameWidth: frameWidth, frameHeight: frameHeight)
                    guard alpha > 0.01 else { continue }
                    let source = (fy * frameWidth + fx) * 4
                    let target = y * width + x
                    for channel in 0..<3 {
                        let value = Float(pixels[source + channel])
                        canvas[target * 3 + channel] = canvas[target * 3 + channel] * (1 - alpha) + value * alpha
                    }
                    if alpha > 0.5 { filled[target] = true }
                }
            }
        }

        // ---- 5. 抜けの多い端を切り落とす（人のいるコマの範囲までは切らない）
        var start = 0, end = vertical ? height : width
        let keepStart = vertical ? referenceY : referenceX
        let keepEnd = vertical ? referenceY + frameHeight : referenceX + frameWidth
        func fillRatio(_ line: Int) -> Float {
            var hits = 0
            let length = vertical ? width : height
            for i in 0..<length where filled[vertical ? line * width + i : i * width + line] { hits += 1 }
            return Float(hits) / Float(max(1, length))
        }
        while start < keepStart, start < end - 1, fillRatio(start) < 0.98 { start += 1 }
        while end > keepEnd, end - 1 > start, fillRatio(end - 1) < 0.98 { end -= 1 }

        let outX = vertical ? 0 : start, outY = vertical ? start : 0
        let outWidth = vertical ? width : end - start, outHeight = vertical ? end - start : height
        guard outWidth > 0, outHeight > 0 else { return nil }

        // 残った抜けは、上（なければ下）のとなりの色で埋める。
        for y in 0..<height {
            for x in 0..<width where !filled[y * width + x] && y > 0 && filled[(y - 1) * width + x] {
                for channel in 0..<3 { canvas[(y * width + x) * 3 + channel] = canvas[((y - 1) * width + x) * 3 + channel] }
                filled[y * width + x] = true
            }
        }
        for y in stride(from: height - 2, through: 0, by: -1) {
            for x in 0..<width where !filled[y * width + x] && filled[(y + 1) * width + x] {
                for channel in 0..<3 { canvas[(y * width + x) * 3 + channel] = canvas[((y + 1) * width + x) * 3 + channel] }
                filled[y * width + x] = true
            }
        }

        return makeImage(canvas, width: width, crop: (outX, outY, outWidth, outHeight))
    }

    // MARK: - ずれを求める

    /// 1コマを、ずれを求めやすい形にしたもの。
    private struct Level {
        /// 粗い幅での、列ごと・行ごとの明るさの変わり目の平均（人の所は除く。人ばかりの列は nil）。
        let columns: [Float?]
        let rows: [Float?]
        /// 細かい幅での、明るさと、明るさの変わり目、人ではない所。
        let gray: [Float]
        let gradient: [Float]
        let valid: [Bool]
        let width: Int
        let height: Int

        /// - Parameter grown: 太らせた人の切り抜き（無ければ全部を背景として使う）。
        init?(frame: CGImage, grown: MaskGrid?) {
            let coarseWidth = PanoramaStitcher.coarseWidth, fineWidth = PanoramaStitcher.fineWidth
            let coarseHeight = max(8, Int((CGFloat(frame.height) * CGFloat(coarseWidth) / CGFloat(frame.width)).rounded()))
            let fineHeight = max(8, Int((CGFloat(frame.height) * CGFloat(fineWidth) / CGFloat(frame.width)).rounded()))
            guard let coarse = PanoramaStitcher.gray(frame, width: coarseWidth, height: coarseHeight),
                  let fine = PanoramaStitcher.gray(frame, width: fineWidth, height: fineHeight)
            else { return nil }

            func validity(width: Int, height: Int) -> [Bool] {
                var result = [Bool](repeating: true, count: width * height)
                guard let grown else { return result }
                for y in 0..<height {
                    for x in 0..<width where grown.isPerson(x: x, y: y, frameWidth: width, frameHeight: height) {
                        result[y * width + x] = false
                    }
                }
                return result
            }

            let coarseValid = validity(width: coarseWidth, height: coarseHeight)
            let coarseGradient = PanoramaStitcher.gradients(coarse, width: coarseWidth, height: coarseHeight)
            var columns: [Float?] = []
            for x in 0..<coarseWidth {
                var sum: Float = 0, samples = 0
                for y in 0..<coarseHeight where coarseValid[y * coarseWidth + x] {
                    sum += coarseGradient.x[y * coarseWidth + x]; samples += 1
                }
                columns.append(samples > 3 ? sum / Float(samples) : nil)
            }
            var rows: [Float?] = []
            for y in 0..<coarseHeight {
                var sum: Float = 0, samples = 0
                for x in 0..<coarseWidth where coarseValid[y * coarseWidth + x] {
                    sum += coarseGradient.y[y * coarseWidth + x]; samples += 1
                }
                rows.append(samples > 3 ? sum / Float(samples) : nil)
            }
            self.columns = columns
            self.rows = rows

            let fineGradient = PanoramaStitcher.gradients(fine, width: fineWidth, height: fineHeight)
            gray = fine
            gradient = zip(fineGradient.x, fineGradient.y).map { $0 + $1 }
            valid = validity(width: fineWidth, height: fineHeight)
            width = fineWidth
            height = fineHeight
        }
    }

    /// current[i] = previous[i + d] になる d（1次元の形どうしを、ずらしながら比べる）。
    private static func match(_ previous: [Float?], _ current: [Float?], maxShift: Int) -> Int {
        let length = min(previous.count, current.count)
        var best = Float.infinity, bestShift = 0
        for shift in -maxShift...maxShift {
            let low = max(0, -shift), high = min(length, length - shift)
            guard high - low >= length / 3 else { continue }
            var sum: Float = 0, samples = 0
            for i in low..<high {
                guard let a = current[i], let b = previous[i + shift] else { continue }
                sum += abs(a - b); samples += 1
            }
            guard samples >= length / 4 else { continue }
            let score = sum / Float(samples)
            if score < best { best = score; bestShift = shift }
        }
        return bestShift
    }

    /// 細かい幅で ±radius だけ2次元で詰め、放物線で 1px より細かく寄せる。
    private static func refine(_ previous: Level, _ current: Level, dx: Int, dy: Int, radius: Int) -> (x: CGFloat, y: CGFloat) {
        let width = current.width, height = current.height
        var costs: [Int: Float] = [:]
        func key(_ x: Int, _ y: Int) -> Int { (y + 10_000) * 100_000 + (x + 10_000) }
        var best = Float.infinity, bestX = dx, bestY = dy
        for shiftY in (dy - radius)...(dy + radius) {
            for shiftX in (dx - radius)...(dx + radius) {
                let y0 = max(0, -shiftY), y1 = min(height, height - shiftY)
                let x0 = max(0, -shiftX), x1 = min(width, width - shiftX)
                guard y1 - y0 >= height / 3, x1 - x0 >= width / 3 else { continue }
                var sum: Float = 0, samples = 0
                // 1行おき・1列おきに比べる（十分に正確で、4倍速い）。
                for y in stride(from: y0, to: y1, by: 2) {
                    let row = y * width, previousRow = (y + shiftY) * width + shiftX
                    for x in stride(from: x0, to: x1, by: 2)
                    where current.valid[row + x] && previous.valid[previousRow + x] {
                        sum += abs(current.gradient[row + x] - previous.gradient[previousRow + x])
                        samples += 1
                    }
                }
                guard samples >= 200 else { continue }
                let score = sum / Float(samples)
                costs[key(shiftX, shiftY)] = score
                if score < best { best = score; bestX = shiftX; bestY = shiftY }
            }
        }
        func vertex(_ minus: Float?, _ plus: Float?) -> CGFloat {
            guard let minus, let plus else { return 0 }
            let denominator = minus - 2 * best + plus
            guard denominator > 1e-9 else { return 0 }
            return CGFloat(max(-0.5, min(0.5, 0.5 * (minus - plus) / denominator)))
        }
        return (CGFloat(bestX) + vertex(costs[key(bestX - 1, bestY)], costs[key(bestX + 1, bestY)]),
                CGFloat(bestY) + vertex(costs[key(bestX, bestY - 1)], costs[key(bestX, bestY + 1)]))
    }

    /// 重なる所の明るさの比（前のコマ ÷ このコマ）。このコマに掛けると前のコマとそろう。
    private static func brightnessRatio(_ previous: Level, _ current: Level, dx: CGFloat, dy: CGFloat) -> CGFloat {
        let shiftX = Int(dx.rounded()), shiftY = Int(dy.rounded())
        let width = current.width, height = current.height
        var a: Float = 0, b: Float = 0
        for y in stride(from: max(0, -shiftY), to: min(height, height - shiftY), by: 2) {
            for x in stride(from: max(0, -shiftX), to: min(width, width - shiftX), by: 2) {
                let here = y * width + x, there = (y + shiftY) * width + x + shiftX
                guard current.valid[here], previous.valid[there] else { continue }
                a += previous.gray[there]; b += current.gray[here]
            }
        }
        guard a > 0, b > 0 else { return 1 }
        return CGFloat(min(1.5, max(0.67, a / b)))
    }

    // MARK: - 画素

    /// 灰色に小さくした画像（0〜255）。
    private static func gray(_ image: CGImage, width: Int, height: Int) -> [Float]? {
        guard let context = CGContext(data: nil, width: width, height: height, bitsPerComponent: 8,
                                      bytesPerRow: width, space: CGColorSpaceCreateDeviceGray(),
                                      bitmapInfo: CGImageAlphaInfo.none.rawValue),
              let data = context.data
        else { return nil }
        context.interpolationQuality = .medium
        context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
        let bytes = data.bindMemory(to: UInt8.self, capacity: width * height)
        return (0..<(width * height)).map { Float(bytes[$0]) }
    }

    private static func gradients(_ gray: [Float], width: Int, height: Int) -> (x: [Float], y: [Float]) {
        var gx = [Float](repeating: 0, count: width * height), gy = gx
        for y in 0..<height {
            for x in 0..<width {
                let index = y * width + x
                if x > 0, x < width - 1 { gx[index] = abs(gray[index + 1] - gray[index - 1]) }
                if y > 0, y < height - 1 { gy[index] = abs(gray[index + width] - gray[index - width]) }
            }
        }
        return (gx, gy)
    }

    /// 画素の並び（R, G, B, A の順。行 0 が画像の上）。
    private static func rgba(_ image: CGImage) -> [UInt8]? {
        let width = image.width, height = image.height
        guard let context = CGContext(data: nil, width: width, height: height, bitsPerComponent: 8,
                                      bytesPerRow: width * 4, space: CGColorSpaceCreateDeviceRGB(),
                                      bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
                                        | CGBitmapInfo.byteOrder32Big.rawValue),
              let data = context.data
        else { return nil }
        context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
        return Array(UnsafeBufferPointer(start: data.bindMemory(to: UInt8.self, capacity: width * height * 4),
                                         count: width * height * 4))
    }

    private static func makeImage(_ canvas: [Float], width: Int,
                                  crop: (x: Int, y: Int, width: Int, height: Int)) -> CGImage? {
        guard let context = CGContext(data: nil, width: crop.width, height: crop.height, bitsPerComponent: 8,
                                      bytesPerRow: crop.width * 4, space: CGColorSpaceCreateDeviceRGB(),
                                      bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue
                                        | CGBitmapInfo.byteOrder32Big.rawValue),
              let data = context.data
        else { return nil }
        let bytes = data.bindMemory(to: UInt8.self, capacity: crop.width * crop.height * 4)
        for y in 0..<crop.height {
            for x in 0..<crop.width {
                let source = ((y + crop.y) * width + x + crop.x) * 3
                let target = (y * crop.width + x) * 4
                bytes[target] = UInt8(min(255, max(0, canvas[source])))
                bytes[target + 1] = UInt8(min(255, max(0, canvas[source + 1])))
                bytes[target + 2] = UInt8(min(255, max(0, canvas[source + 2])))
                bytes[target + 3] = 255
            }
        }
        return context.makeImage()
    }
}

/// Vision の人物の切り抜き（マスク）を、配列に写したもの。
/// Vision の画素の入れ物は使い回されることがあるので、すぐに写しておく。
struct MaskGrid {
    let width: Int
    let height: Int
    /// 0〜1。1 が人。
    let values: [Float]

    init(buffer: CVPixelBuffer) {
        CVPixelBufferLockBaseAddress(buffer, .readOnly)
        defer { CVPixelBufferUnlockBaseAddress(buffer, .readOnly) }
        let width = CVPixelBufferGetWidth(buffer), height = CVPixelBufferGetHeight(buffer)
        let bytesPerRow = CVPixelBufferGetBytesPerRow(buffer)
        var values = [Float](repeating: 0, count: width * height)
        if let base = CVPixelBufferGetBaseAddress(buffer) {
            let pixels = base.assumingMemoryBound(to: UInt8.self)
            for y in 0..<height {
                for x in 0..<width { values[y * width + x] = Float(pixels[y * bytesPerRow + x]) / 255 }
            }
        }
        self.init(width: width, height: height, values: values)
    }

    init(width: Int, height: Int, values: [Float]) {
        self.width = width
        self.height = height
        self.values = values
    }

    /// 人の所を少し太らせたもの（ふちの取り残しで、背景に人の影が残らないように）。
    var grown: MaskGrid {
        let radius = max(1, width / 60)
        // 横に太らせてから縦に太らせる（四角い範囲の最大値）。
        var horizontal = [Float](repeating: 0, count: width * height)
        for y in 0..<height {
            for x in 0..<width {
                var peak: Float = 0
                for dx in max(0, x - radius)...min(width - 1, x + radius) { peak = max(peak, values[y * width + dx]) }
                horizontal[y * width + x] = peak
            }
        }
        var result = [Float](repeating: 0, count: width * height)
        for y in 0..<height {
            for x in 0..<width {
                var peak: Float = 0
                for dy in max(0, y - radius)...min(height - 1, y + radius) { peak = max(peak, horizontal[dy * width + x]) }
                result[y * width + x] = peak
            }
        }
        return MaskGrid(width: width, height: height, values: result)
    }

    /// コマの (x, y)（コマの大きさ frameWidth × frameHeight の中の位置）の値。近い画素を使う。
    func value(x: Int, y: Int, frameWidth: Int, frameHeight: Int) -> Float {
        guard width > 0, height > 0 else { return 0 }
        let mx = min(width - 1, max(0, x * width / max(1, frameWidth)))
        let my = min(height - 1, max(0, y * height / max(1, frameHeight)))
        return values[my * width + mx]
    }

    func isPerson(x: Int, y: Int, frameWidth: Int, frameHeight: Int) -> Bool {
        value(x: x, y: y, frameWidth: frameWidth, frameHeight: frameHeight) > 0.08
    }
}
