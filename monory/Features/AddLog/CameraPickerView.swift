import SwiftUI
import AVFoundation

struct CameraPickerView: UIViewControllerRepresentable {
    static let jpegCompressionQuality: CGFloat = 0.8

    let onCapture: (Data) -> Void
    @Environment(\.dismiss) private var dismiss

    func makeUIViewController(context: Context) -> LiveCameraViewController {
        LiveCameraViewController(
            onCapture: { data in
                onCapture(data)
                dismiss()
            },
            onCancel: { dismiss() }
        )
    }

    func updateUIViewController(_ uiViewController: LiveCameraViewController, context: Context) {}
}

final class LiveCameraViewController: UIViewController {
    private let onCaptureHandler: (Data) -> Void
    private let onCancelHandler: () -> Void

    private let session = AVCaptureSession()
    private let videoOutput = AVCaptureVideoDataOutput()
    private let sessionQueue = DispatchQueue(label: "com.monory.camera.session")
    private let ciContext = CIContext()
    private var previewLayer: AVCaptureVideoPreviewLayer?
    private var pendingCapture = false  // accessed only on sessionQueue

    init(onCapture: @escaping (Data) -> Void, onCancel: @escaping () -> Void) {
        self.onCaptureHandler = onCapture
        self.onCancelHandler = onCancel
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) { fatalError() }

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black
        setupUI()
        checkCameraPermission()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        previewLayer?.frame = view.bounds
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        sessionQueue.async { self.session.stopRunning() }
    }

    // MARK: - Camera Setup

    private func checkCameraPermission() {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            setupCaptureSession()
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { [weak self] granted in
                if granted { self?.setupCaptureSession() }
            }
        default:
            break
        }
    }

    private func setupCaptureSession() {
        sessionQueue.async { [weak self] in
            guard let self else { return }
            self.session.beginConfiguration()
            self.session.sessionPreset = .photo

            guard
                let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back),
                let input = try? AVCaptureDeviceInput(device: device),
                self.session.canAddInput(input)
            else {
                self.session.commitConfiguration()
                return
            }
            self.session.addInput(input)

            self.videoOutput.setSampleBufferDelegate(self, queue: self.sessionQueue)
            self.videoOutput.alwaysDiscardsLateVideoFrames = true
            if self.session.canAddOutput(self.videoOutput) {
                self.session.addOutput(self.videoOutput)
            }

            if let conn = self.videoOutput.connection(with: .video),
               conn.isVideoOrientationSupported {
                conn.videoOrientation = .portrait
            }

            self.session.commitConfiguration()

            DispatchQueue.main.async {
                let layer = AVCaptureVideoPreviewLayer(session: self.session)
                layer.videoGravity = .resizeAspectFill
                if let conn = layer.connection, conn.isVideoOrientationSupported {
                    conn.videoOrientation = .portrait
                }
                layer.frame = self.view.bounds
                // insertSublayer at 0 → under UIView subviews (buttons)
                self.view.layer.insertSublayer(layer, at: 0)
                self.previewLayer = layer
            }

            self.session.startRunning()
        }
    }

    // MARK: - UI

    private lazy var shutterButton: UIButton = {
        let outer = UIButton(type: .custom)
        outer.backgroundColor = .white.withAlphaComponent(0.85)
        outer.layer.cornerRadius = 36
        outer.layer.borderWidth = 4
        outer.layer.borderColor = UIColor.white.cgColor
        outer.translatesAutoresizingMaskIntoConstraints = false
        outer.addTarget(self, action: #selector(didTapShutter), for: .touchUpInside)
        return outer
    }()

    private lazy var cancelButton: UIButton = {
        let btn = UIButton(type: .system)
        btn.setTitle("キャンセル", for: .normal)
        btn.setTitleColor(.white, for: .normal)
        btn.titleLabel?.font = .systemFont(ofSize: 17)
        btn.translatesAutoresizingMaskIntoConstraints = false
        btn.addTarget(self, action: #selector(didTapCancel), for: .touchUpInside)
        return btn
    }()

    private func setupUI() {
        view.addSubview(shutterButton)
        view.addSubview(cancelButton)

        NSLayoutConstraint.activate([
            shutterButton.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            shutterButton.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -24),
            shutterButton.widthAnchor.constraint(equalToConstant: 72),
            shutterButton.heightAnchor.constraint(equalToConstant: 72),

            cancelButton.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor, constant: 20),
            cancelButton.centerYAnchor.constraint(equalTo: shutterButton.centerYAnchor),
        ])
    }

    @objc private func didTapShutter() {
        // set flag on sessionQueue to avoid data race with delegate
        sessionQueue.async { self.pendingCapture = true }
    }

    @objc private func didTapCancel() {
        onCancelHandler()
    }
}

// MARK: - AVCaptureVideoDataOutputSampleBufferDelegate

extension LiveCameraViewController: AVCaptureVideoDataOutputSampleBufferDelegate {
    nonisolated func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        guard pendingCapture else { return }
        pendingCapture = false

        guard let imageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
        let ciImage = CIImage(cvImageBuffer: imageBuffer)
        let ciContext = CIContext()
        guard let cgImage = ciContext.createCGImage(ciImage, from: ciImage.extent) else { return }
        let uiImage = UIImage(cgImage: cgImage)
        guard let data = uiImage.jpegData(compressionQuality: CameraPickerView.jpegCompressionQuality) else { return }

        DispatchQueue.main.async { [weak self] in
            self?.onCaptureHandler(data)
        }
    }
}
