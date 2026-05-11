import SwiftUI
import AVFoundation

// Обертка для настоящей камеры
struct RealCameraScreen: UIViewControllerRepresentable {
    func makeUIViewController(context: Context) -> CameraViewController {
        return CameraViewController()
    }
    func updateUIViewController(_ uiViewController: CameraViewController, context: Context) {}
}

// Контроллер, который работает напрямую с железом
class CameraViewController: UIViewController {
    var captureSession: AVCaptureSession!
    var previewLayer: AVCaptureVideoPreviewLayer!

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = UIColor.black
        captureSession = AVCaptureSession()

        // Запрашиваем фронтальную камеру
        guard let videoCaptureDevice = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .front) else { return }
        let videoInput: AVCaptureDeviceInput

        do {
            videoInput = try AVCaptureDeviceInput(device: videoCaptureDevice)
        } catch { return }

        if (captureSession.canAddInput(videoInput)) {
            captureSession.addInput(videoInput)
        } else { return }

        // Настраиваем слой вывода
        previewLayer = AVCaptureVideoPreviewLayer(session: captureSession)
        previewLayer.frame = view.layer.bounds
        previewLayer.videoGravity = .resizeAspectFill
        view.layer.addSublayer(previewLayer)

        // Запускаем поток в фоне, чтобы не тормозить интерфейс
        DispatchQueue.global(qos: .userInitiated).async {
            self.captureSession.startRunning()
        }
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        previewLayer.frame = view.bounds
    }
}
