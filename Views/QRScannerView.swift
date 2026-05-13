import SwiftUI
import AVFoundation

struct QRScannerView: UIViewControllerRepresentable {
    var completion: (String) -> Void

    func makeUIViewController(context: Context) -> ScannerController {
        let controller = ScannerController()
        controller.completion = completion
        return controller
    }

    func updateUIViewController(_ uiViewController: ScannerController, context: Context) {}

    class ScannerController: UIViewController, AVCaptureMetadataOutputObjectsDelegate {
        var captureSession: AVCaptureSession!
        var previewLayer: AVCaptureVideoPreviewLayer!
        var completion: ((String) -> Void)?

        override func viewDidLoad() {
            super.viewDidLoad()
            self.view.backgroundColor = .black
            self.setupCamera()
        }

        private func setupCamera() {
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
            previewLayer.frame = self.view.layer.bounds
            previewLayer.videoGravity = .resizeAspectFill
            self.view.layer.addSublayer(previewLayer)

            DispatchQueue.global(qos: .userInitiated).async {
                self.captureSession.startRunning()
            }
        }

        func metadataOutput(_ output: AVCaptureMetadataOutput, didOutput metadataObjects: [AVMetadataObject], from connection: AVCaptureConnection) {
            if let metadataObject = metadataObjects.first {
                guard let readableObject = metadataObject as? AVMetadataMachineReadableCodeObject,
                      let stringValue = readableObject.stringValue else { return }
                
                AudioServicesPlaySystemSound(SystemSoundID(kSystemSoundID_Vibrate))
                completion?(stringValue)
                dismiss(animated: true)
            }
        }

        override func viewWillDisappear(_ animated: Bool) {
            super.viewWillDisappear(animated)
            if captureSession.isRunning { captureSession.stopRunning() }
        }
    }
}