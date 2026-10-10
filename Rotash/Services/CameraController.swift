import AVFoundation
import UIKit

/// Rotash のカメラ。表（大きい画面側）と裏（シャッター側）を撮る。
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
    /// 前と後ろのカメラを同時に動かせる端末か（iPhone XS 以降）。
    /// 同時に動かせるときは、表（大きい画面側）と裏（シャッター側）を同じ瞬間に撮る。
    /// 動かせない端末では、表を撮ったあとカメラを切り替えて裏を続けて撮る。
    let isDual: Bool
    let session: AVCaptureSession
    /// 表の映像の縦横比（短い辺 ÷ 長い辺）。縦持ちの撮影画面で、写る範囲をそのまま見せるのに使う。
    @Published private(set) var frameAspect: CGFloat = 0.75

    /// 同時撮影のときの、前と後ろのカメラそれぞれの一式。画面のスレッドで読み書きする。
    private var rigs: [AVCaptureDevice.Position: Rig] = [:]
    /// 同時撮影で、写真ができあがるまで受け取り役を持っておく。
    private var processors: [PhotoProcessor] = []

    private let sessionQueue = DispatchQueue(label: "com.rotash.camera.session")
    private let output = AVCapturePhotoOutput()
    private var device: AVCaptureDevice?
    private var currentInput: AVCaptureDeviceInput?
    private var rotationCoordinator: AVCaptureDevice.RotationCoordinator?
    private var rotationObservation: NSKeyValueObservation?
    private var isConfigured = false
    private var captureCompletion: ((Data?) -> Void)?

    /// プレビューレイヤーが用意できたら渡してもらう（水平基準の回転を合わせるため）。
    weak var previewLayer: AVCaptureVideoPreviewLayer? {
        didSet { bindRotationCoordinator() }
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
        // self ではなく session を持っていく。画面を縦にして ThisWeekView が消えると、
        // この処理が走る前に CameraController が先に消えることがあり、そのときもカメラを止めるため。
        let session = self.session
        sessionQueue.async {
            guard session.isRunning else { return }
            session.stopRunning()
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
        configureDevice(camera, photoOutput: output, multiCam: false)
        session.commitConfiguration()

        device = camera
        currentInput = input
        isConfigured = true
        let aspect = Self.aspect(of: camera)

        DispatchQueue.main.async {
            self.frameAspect = aspect
            self.status = .ready
            self.bindRotationCoordinator()
        }
    }

    // MARK: - 同時撮影（前と後ろのカメラを同時に動かす）

    /// 前と後ろのカメラを、どちらも動かし続ける形で組む。
    ///
    /// 同時撮影のセッションでは、カメラと出口を勝手につながないので、つなぎ方をすべて自分で決める
    /// （写真と画面のプレビューの2本を、それぞれのカメラから引く）。
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
            self.frameAspect = built[self.position].map { Self.aspect(of: $0.device) } ?? 0.75
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

    /// 1台のカメラから、写真とプレビューの2本をつなぐ。セッションの設定中に呼ぶ。
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
    /// 写真が撮れるもの（supportedMaxPhotoDimensions が空でない）に限り、4:3 があればそれを選ぶ
    /// （16:9 になると、写る形が変わってしまうため）。
    private static func useLighterFormat(_ device: AVCaptureDevice) {
        let candidates = device.formats.filter {
            $0.isMultiCamSupported
                && !$0.supportedMaxPhotoDimensions.isEmpty
                && CMVideoFormatDescriptionGetDimensions($0.formatDescription).width <= 1280
        }
        func isFourByThree(_ format: AVCaptureDevice.Format) -> Bool {
            let dims = CMVideoFormatDescriptionGetDimensions(format.formatDescription)
            return dims.height > 0 && abs(Double(dims.width) / Double(dims.height) - 4.0 / 3.0) < 0.01
        }
        let preferred = candidates.contains(where: isFourByThree) ? candidates.filter(isFourByThree) : candidates
        guard let lighter = preferred.max(by: {
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

    /// 使うカメラを選ぶ。
    ///
    /// - 外カメ: 超広角（iPhone 標準の 0.5倍）があればそちら。無い機種（SE など）は普通の広角。
    ///   枠が細いので、レンズそのものが広いほうが「撮るものがない」が起きにくい。
    /// - 内カメ: 普通の広角。
    private func device(for position: AVCaptureDevice.Position) -> AVCaptureDevice? {
        if position == .back, RotashFeatureFlags.prefersUltraWideBackCamera,
           let ultraWide = AVCaptureDevice.default(.builtInUltraWideCamera, for: .video, position: .back) {
            return ultraWide
        }
        return AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: position)
    }

    /// カメラのピント・明るさ・写真の大きさをそろえる。セッションの設定中（begin/commit のあいだ）に呼ぶ。
    /// - Parameter multiCam: 同時撮影か。同時撮影で使えるフォーマットにそろえる。
    private func configureDevice(_ device: AVCaptureDevice, photoOutput: AVCapturePhotoOutput, multiCam: Bool) {
        do {
            try device.lockForConfiguration()
            defer { device.unlockForConfiguration() }

            // 同時撮影では、同時撮影に使えないフォーマットのままだとセッションが動かないので必ず替える。
            // 2台ぶんの重さを抑えるため、映像が横 1920 以下のうちいちばん大きいものにする。
            if multiCam, let format = Self.multiCamFormat(of: device), format != device.activeFormat {
                device.activeFormat = format
            }

            // ズームで狭めない（仮想カメラでなければ最小は 1.0）。外カメは超広角（0.5倍）のカメラそのもの、
            // 内カメはセンサーいっぱい（標準カメラで自撮りを広くしたときの広さ）になる。
            // 指のピンチはライブビューの広さを変えるのに使うので、ズームは付けない。
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
    }

    /// 同時撮影で使うフォーマット。同時撮影で使えて写真が撮れるもののうち、
    /// 4:3（写真と同じ形）で、映像が横 1920 以下のもの。その中で**いちばん広く写る**（画角が大きい）もの、
    /// 同じなら映像が大きいもの。無ければ同時撮影で使える何か。
    ///
    /// フォーマットによってはセンサーの一部だけを使って狭く写るので、画角で選ぶ。
    /// 内カメはこれで、iPhone の標準カメラで自撮りを広くしたときと同じ、センサーいっぱいの広さになる。
    private static func multiCamFormat(of device: AVCaptureDevice) -> AVCaptureDevice.Format? {
        func dims(_ format: AVCaptureDevice.Format) -> CMVideoDimensions {
            CMVideoFormatDescriptionGetDimensions(format.formatDescription)
        }
        let usable = device.formats.filter { $0.isMultiCamSupported && !$0.supportedMaxPhotoDimensions.isEmpty }
        let preferred = usable.filter {
            let d = dims($0)
            return d.width <= 1920 && d.height > 0 && abs(Double(d.width) / Double(d.height) - 4.0 / 3.0) < 0.05
        }
        return (preferred.isEmpty ? usable : preferred).max {
            if abs($0.videoFieldOfView - $1.videoFieldOfView) > 0.5 { return $0.videoFieldOfView < $1.videoFieldOfView }
            return dims($0).width < dims($1).width
        }
    }

    // MARK: - 前面 / 背面切り替え（自撮り対応）

    /// 表と裏のカメラを入れ替える（FLIP）。撮影中は呼び出し側で無効化しておくこと。
    ///
    /// 同時撮影では両方のカメラが動いているので、役割を入れ替えるだけ（一瞬で終わる）。
    /// 同時撮影できない端末では、動かしているカメラそのものを切り替える。
    /// - Parameter completion: 終わったら画面のスレッドで呼ぶ（切り替えられなかったときも必ず呼ぶ）。
    ///   引数は、実際に切り替えられたか。
    func switchCamera(completion: ((Bool) -> Void)? = nil) {
        if isDual {
            position = reversePosition
            if let rig = rigs[position] { frameAspect = Self.aspect(of: rig.device) }
            completion?(true)
            return
        }
        sessionQueue.async { [weak self] in
            guard let self else {
                DispatchQueue.main.async { completion?(false) }
                return
            }
            let newPosition: AVCaptureDevice.Position = self.position == .back ? .front : .back

            // 呼び出し側は completion を待っている（撮影中はシャッターを止めている）ので、
            // 切り替えられないときも黙って抜けずに知らせる。
            guard self.isConfigured,
                  let newDevice = self.device(for: newPosition),
                  let newInput = try? AVCaptureDeviceInput(device: newDevice)
            else {
                DispatchQueue.main.async { completion?(false) }
                return
            }

            var switched = false
            self.session.beginConfiguration()
            if let oldInput = self.currentInput {
                self.session.removeInput(oldInput)
            }
            if self.session.canAddInput(newInput) {
                self.session.addInput(newInput)
                self.currentInput = newInput
                self.device = newDevice
                self.configureDevice(newDevice, photoOutput: self.output, multiCam: false)
                switched = true
            } else if let oldInput = self.currentInput {
                // 追加できなかった場合は元に戻す。
                self.session.addInput(oldInput)
            }
            self.session.commitConfiguration()

            let aspect = Self.aspect(of: self.device ?? newDevice)
            DispatchQueue.main.async {
                // 切り替えられなかったときは、どちらのカメラかの記録を変えない（表・裏を取り違えないように）。
                if switched { self.position = newPosition }
                self.frameAspect = aspect
                self.bindRotationCoordinator()
                completion?(switched)
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
        rotationObservation = coordinator.observe(\.videoRotationAngleForHorizonLevelPreview, options: [.new]) { [weak self] _, _ in
            DispatchQueue.main.async { self?.applyPreviewRotation() }
        }
    }

    private func applyPreviewRotation() {
        guard let angle = rotationCoordinator?.videoRotationAngleForHorizonLevelPreview,
              let connection = previewLayer?.connection,
              connection.isVideoRotationAngleSupported(angle)
        else { return }
        connection.videoRotationAngle = angle
    }

    /// 同時撮影では、カメラごとに向きを見張る（プレビューと写真を水平に合わせる）。
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
            if let connection = rig.photoOutput.connection(with: .video), connection.isVideoRotationAngleSupported(angle) {
                connection.videoRotationAngle = angle
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
            // 2台の写真を受け取る入れ物。notify のクロージャは別のスレッドで動く扱いになり、
            // そこから var を読むとコンパイルエラーになりうるので、クラスに入れて let で持つ。
            let results = CaptureResults()
            for rig in [mainRig, reverseRig] {
                if let angle = rig.rotationCoordinator?.videoRotationAngleForHorizonLevelCapture,
                   let connection = rig.photoOutput.connection(with: .video),
                   connection.isVideoRotationAngleSupported(angle) {
                    connection.videoRotationAngle = angle
                }
                let settings = AVCapturePhotoSettings()
                settings.flashMode = .off
                settings.maxPhotoDimensions = rig.photoOutput.maxPhotoDimensions

                group.enter()
                let position = rig.device.position
                let processor = PhotoProcessor { data in
                    results.set(data, for: position)
                    group.leave()
                }
                self.processors.append(processor)
                rig.photoOutput.capturePhoto(with: settings, delegate: processor)
            }
            group.notify(queue: .main) {
                self.sessionQueue.async { self.processors.removeAll() }
                completion(results.data(for: mainRig.device.position), results.data(for: reverseRig.device.position))
            }
        }
    }

    /// 同時撮影できない端末: 表 → カメラを切り替える → 少し待って裏 → 元に戻す。
    private func captureSequentially(fallbackSeed: Int, completion: @escaping (Data?, Data?) -> Void) {
        capture(fallbackSeed: fallbackSeed) { [weak self] main in
            guard let self else { return completion(main, nil) }
            self.switchCamera { switched in
                // もう一方のカメラに切り替えられなければ、裏は無しで表だけ残す
                // （同じカメラでもう1枚撮って「裏」にすると、表と同じ写真になってしまう）。
                guard switched else { return completion(main, nil) }
                // 切り替えた直後は明るさやピントが合っていないので、少しだけ待つ。
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.45) {
                    self.capture(fallbackSeed: fallbackSeed) { reverse in
                        self.switchCamera { _ in
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
            if let connection = self.output.connection(with: .video) {
                if let angle, connection.isVideoRotationAngleSupported(angle) {
                    connection.videoRotationAngle = angle
                }
                // 画面のプレビューと同じく、内カメは鏡写しで残す（同時撮影の端末とそろえる）。
                Self.setMirrored(connection, self.device?.position == .front)
            }
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

/// 同時撮影での、1台のカメラの一式（写真・プレビュー）。
private final class Rig {
    let device: AVCaptureDevice
    let input: AVCaptureDeviceInput
    let photoOutput = AVCapturePhotoOutput()
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

/// 同時撮影で、2台のカメラの写真を集める入れ物。2台の写真は別々のスレッドで届くので、鍵をかけて出し入れする。
private final class CaptureResults: @unchecked Sendable {
    private var store: [AVCaptureDevice.Position: Data] = [:]
    private let lock = NSLock()

    func set(_ data: Data?, for position: AVCaptureDevice.Position) {
        guard let data else { return }
        lock.lock()
        store[position] = data
        lock.unlock()
    }

    func data(for position: AVCaptureDevice.Position) -> Data? {
        lock.lock()
        defer { lock.unlock() }
        return store[position]
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
