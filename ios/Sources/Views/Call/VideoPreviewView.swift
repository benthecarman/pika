import AVFoundation
import CoreVideo
import SwiftUI

/// Local camera preview using AVCaptureVideoPreviewLayer (zero-copy).
struct CameraPreviewView: UIViewRepresentable {
    let session: AVCaptureSession

    func makeUIView(context: Context) -> CameraPreviewUIView {
        let view = CameraPreviewUIView()
        view.previewLayer.session = session
        view.previewLayer.videoGravity = .resizeAspectFill
        return view
    }

    func updateUIView(_ uiView: CameraPreviewUIView, context: Context) {
        uiView.previewLayer.session = session
    }
}

final class CameraPreviewUIView: UIView {
    override class var layerClass: AnyClass { AVCaptureVideoPreviewLayer.self }
    var previewLayer: AVCaptureVideoPreviewLayer { layer as! AVCaptureVideoPreviewLayer }
}

/// Renders a CVPixelBuffer via CoreImage into a SwiftUI-compatible view.
struct RemoteVideoView: UIViewRepresentable {
    let pixelBuffer: CVPixelBuffer?

    func makeUIView(context: Context) -> RemoteVideoUIView {
        let view = RemoteVideoUIView()
        view.contentMode = .scaleAspectFill
        view.clipsToBounds = true
        return view
    }

    func updateUIView(_ uiView: RemoteVideoUIView, context: Context) {
        uiView.displayPixelBuffer(pixelBuffer)
    }
}

final class RemoteVideoUIView: UIView {
    private lazy var ciContext = CIContext(options: [.useSoftwareRenderer: false])

    func displayPixelBuffer(_ pixelBuffer: CVPixelBuffer?) {
        guard let pixelBuffer else {
            layer.contents = nil
            return
        }
        let ciImage = CIImage(cvPixelBuffer: pixelBuffer)
        let width = CVPixelBufferGetWidth(pixelBuffer)
        let height = CVPixelBufferGetHeight(pixelBuffer)
        if let cgImage = ciContext.createCGImage(ciImage, from: CGRect(x: 0, y: 0, width: width, height: height)) {
            layer.contents = cgImage
        }
    }
}

/// Camera permission helper for video calls.
@MainActor
enum CallCameraPermission {
    static func ensureGranted() async -> Bool {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            return true
        case .denied, .restricted:
            return false
        case .notDetermined:
            return await AVCaptureDevice.requestAccess(for: .video)
        @unknown default:
            return false
        }
    }
}
