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

    let session = AVCaptureSession()

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

    /// - Parameter position: 最初に使うカメラ。縦で撮る画面では自撮りが多いので前面から始める。
    init(position: AVCaptureDevice.Position = .back) {
        // @Published の中身は、super.init の前にはこの形で入れる。
        _position = Published(initialValue: position)
        super.init()
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
        configureDevice(camera)
        session.commitConfiguration()

        device = camera
        currentInput = input
        isConfigured = true

        DispatchQueue.main.async {
            self.supportsLensPreview = addedVideoOutput
            self.status = .ready
            self.bindRotationCoordinator()
        }
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
    private func configureDevice(_ device: AVCaptureDevice) {
        do {
            try device.lockForConfiguration()
            defer { device.unlockForConfiguration() }

            if RotashFeatureFlags.prefersWidestFrontCamera || device.position == .back,
               let widest = Self.widestPhotoFormat(of: device),
               widest != device.activeFormat {
                // activeFormat を直接決めると、セッションのプリセットは inputPriority に切り替わる。
                device.activeFormat = widest
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
            output.maxPhotoDimensions = largest
        }
        applyDistortionCorrection()
    }

    /// Apple の「内容を見て歪みを直す」補正（検証用ビルドの設定画面でオンにしたときだけ）。
    ///
    /// 広角レンズの端で顔などが引き伸ばされるのを、写っているものを見ながら直す機能。
    /// 撮った写真にだけ効き、ライブビューには効かない。対応していないカメラ（多くの内カメ）では何もしない。
    /// セッションのスレッドで呼ぶこと。
    private func applyDistortionCorrection() {
        let wanted = RotashFeatureFlags.isTestBuild
            && UserDefaults.standard.bool(forKey: RotashLens.appleCorrectionKey)
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
    static func widestPhotoFormat(of device: AVCaptureDevice) -> AVCaptureDevice.Format? {
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
            .max { a, b in
                let fa = verticalFOV(a), fb = verticalFOV(b)
                // 0.5° 未満の差は同じ広さとみなす。
                if abs(fa - fb) > 0.5 * .pi / 180 { return fa < fb }
                if isLight(a) != isLight(b) { return !isLight(a) }
                return photoPixels(a) < photoPixels(b)
            }
    }

    // MARK: - 前面 / 背面切り替え（自撮り対応）

    /// 前面・背面カメラを切り替える。撮影中は呼び出し側で無効化しておくこと。
    func switchCamera() {
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
                self.configureDevice(newDevice)
            } else if let oldInput = self.currentInput {
                // 追加できなかった場合は元に戻す。
                self.session.addInput(oldInput)
            }
            self.session.commitConfiguration()

            DispatchQueue.main.async {
                self.position = newPosition
                self.bindRotationCoordinator()
            }
        }
    }

    // MARK: - Rotation

    private func bindRotationCoordinator() {
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

    // MARK: - Capture

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
            self.applyDistortionCorrection()
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
