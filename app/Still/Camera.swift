import AVFoundation
import Vision
import Photos
import SwiftUI

/// Camera + on-device Vision. All frame analysis stays on the phone.
final class Camera: NSObject, ObservableObject, AVCaptureVideoDataOutputSampleBufferDelegate, AVCapturePhotoCaptureDelegate, @unchecked Sendable {
    let session = AVCaptureSession()
    @Published var scene = FrameScene()
    @Published var authorized: Bool? = nil
    @Published var flash = false

    private let queue = DispatchQueue(label: "still.camera")
    private let photoOutput = AVCapturePhotoOutput()
    private var frame = 0

    func start() {
        AVCaptureDevice.requestAccess(for: .video) { ok in
            DispatchQueue.main.async { self.authorized = ok }
            guard ok else { return }
            self.queue.async { self.setUp(); self.session.startRunning() }
        }
    }

    func stop() { queue.async { self.session.stopRunning() } }

    private func setUp() {
        guard session.inputs.isEmpty,
              let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back),
              let input = try? AVCaptureDeviceInput(device: device) else { return }
        session.beginConfiguration()
        session.sessionPreset = .photo
        if session.canAddInput(input) { session.addInput(input) }
        let video = AVCaptureVideoDataOutput()
        video.alwaysDiscardsLateVideoFrames = true
        video.setSampleBufferDelegate(self, queue: queue)
        if session.canAddOutput(video) { session.addOutput(video) }
        if session.canAddOutput(photoOutput) { session.addOutput(photoOutput) }
        session.commitConfiguration()
    }

    // Analyse ~6 times a second; Vision on every frame is wasted battery.
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        frame += 1
        guard frame % 5 == 0, let pixels = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
        let horizon = VNDetectHorizonRequest()
        let faces = VNDetectFaceRectanglesRequest()
        let saliency = VNGenerateObjectnessBasedSaliencyImageRequest()
        let handler = VNImageRequestHandler(cvPixelBuffer: pixels, orientation: .right)
        try? handler.perform([horizon, faces, saliency])

        var s = FrameScene()
        if let h = horizon.results?.first { s.horizonDegrees = Double(h.angle) * 180 / .pi }
        if let face = faces.results?.max(by: { $0.boundingBox.width < $1.boundingBox.width }) {
            s.subject = Self.topLeft(face.boundingBox); s.subjectIsFace = true
        } else if let obj = (saliency.results?.first?.salientObjects)?.max(by: { $0.confidence < $1.confidence }),
                  obj.confidence > 0.5 {
            s.subject = Self.topLeft(obj.boundingBox)
        }
        DispatchQueue.main.async { self.scene = s }
    }

    private static func topLeft(_ r: CGRect) -> CGRect {
        CGRect(x: r.minX, y: 1 - r.maxY, width: r.width, height: r.height)
    }

    func shoot() {
        queue.async {
            guard self.session.isRunning else { return }
            self.photoOutput.capturePhoto(with: AVCapturePhotoSettings(), delegate: self)
        }
        DispatchQueue.main.async { self.flash = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) { self.flash = false }
    }

    func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        guard let data = photo.fileDataRepresentation() else { return }
        PHPhotoLibrary.requestAuthorization(for: .addOnly) { status in
            guard status == .authorized || status == .limited else { return }
            PHPhotoLibrary.shared().performChanges {
                PHAssetCreationRequest.forAsset().addResource(with: .photo, data: data, options: nil)
            }
        }
    }
}

struct CameraPreview: UIViewRepresentable {
    let session: AVCaptureSession
    final class PreviewView: UIView {
        override class var layerClass: AnyClass { AVCaptureVideoPreviewLayer.self }
        var preview: AVCaptureVideoPreviewLayer { layer as! AVCaptureVideoPreviewLayer }
    }
    func makeUIView(context: Context) -> PreviewView {
        let v = PreviewView()
        v.preview.session = session
        v.preview.videoGravity = .resizeAspectFill
        return v
    }
    func updateUIView(_ uiView: PreviewView, context: Context) {}
}
