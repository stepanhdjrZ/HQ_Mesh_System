import SwiftUI
import AVFoundation

struct QRScannerView: UIViewControllerRepresentable {
    var completion: (String) -> Void

    func makeUIViewController(context: Context) -> ScannerVC {
        let vc = ScannerVC()
        vc.completion = completion
        return vc
    }

    func updateUIViewController(_ uiViewController: ScannerVC, context: Context) {}

    class ScannerVC: UIViewController, AVCaptureMetadataOutputObjectsDelegate {
        var captureSession: AVCaptureSession!
        var previewLayer: AVCaptureVideoPreviewLayer!
        var completion: ((String) -> Void)?

        override func viewDidLoad() {
            super.viewDidLoad()
            view.backgroundColor = .black
            captureSession = AVCaptureSession()

            guard let videoCaptureDevice = AVCaptureDevice.default(for: .video) else { return }
            let videoInput: AVCaptureDeviceInput

            do { videoInput = try AVCaptureDeviceInput(device: videoCaptureDevice) } 
            catch { return }

            if captureSession.canAddInput(videoInput) { captureSession.addInput(videoInput) } 
            else { return }

            let metadataOutput = AVCaptureMetadataOutput()
            if captureSession.canAddOutput(metadataOutput) {
                captureSession.addOutput(metadataOutput)
                metadataOutput.setMetadataObjectsDelegate(self, queue: DispatchQueue.main)
                metadataOutput.metadataObjectTypes = [.qr]
            } else { return }

            previewLayer = AVCaptureVideoPreviewLayer(session: captureSession)
            previewLayer.frame = view.layer.bounds
            previewLayer.videoGravity = .resizeAspectFill
            view.layer.addSublayer(previewLayer)

            captureSession.startRunning()
        }

        func metadataOutput(_ output: AVCaptureMetadataOutput, didOutput metadataObjects: [AVMetadataObject], from connection: AVCaptureConnection) {
            if let metadataObject = metadataObjects.first {
                guard let readableObject = metadataObject as? AVMetadataMachineReadableCodeObject else { return }
                guard let stringValue = readableObject.stringValue else { return }
                AudioServicesPlaySystemSound(SystemSoundID(kSystemSoundID_Vibrate))
                completion?(stringValue)
                dismiss(animated: true)
            }
        }
    }
}
