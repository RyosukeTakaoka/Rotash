import AVFoundation
import UIKit

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

    let session = AVCaptureSession()

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
        session.commitConfiguration()

        device = camera
        currentInput = input
        isConfigured = true

        DispatchQueue.main.async {
            self.status = .ready
            self.bindRotationCoordinator()
        }
    }

    private func device(for position: AVCaptureDevice.Position) -> AVCaptureDevice? {
        AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: position)
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
