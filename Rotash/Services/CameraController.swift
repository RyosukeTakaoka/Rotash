import AVFoundation
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

    /// 映像を受け取るスレッドと画面のスレッドのあいだで、
    /// 「View があるか」「前のコマをまだ表示していないか」を安全にやり取りする。
    private let frameGate = FrameGate()

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

    /// 外カメは超広角（0.5倍）があればそちらを使う。枠が細いので、
    /// レンズそのものが広いほうが「撮るものがない」が起きにくい。
    /// 超広角の無い機種（SE など）と内カメは、これまでどおりの広角。
    private func device(for position: AVCaptureDevice.Position) -> AVCaptureDevice? {
        if position == .back,
           RotashFeatureFlags.prefersUltraWideBackCamera,
           let ultraWide = AVCaptureDevice.default(.builtInUltraWideCamera, for: .video, position: .back) {
            return ultraWide
        }
        return AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: position)
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
            let settings = AVCapturePhotoSettings()
            settings.flashMode = .off
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
