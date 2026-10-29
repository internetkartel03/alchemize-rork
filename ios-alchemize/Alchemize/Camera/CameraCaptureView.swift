import SwiftUI
import AVFoundation
import UIKit

final class CameraModel: NSObject, AVCapturePhotoCaptureDelegate, @unchecked Sendable {
    enum State { case idle, running, denied, unavailable }

    let session = AVCaptureSession()
    private let output = AVCapturePhotoOutput()
    private let queue = DispatchQueue(label: "alchemize.camera")
    private var configured = false
    private var onPhoto: ((UIImage?) -> Void)?

    @MainActor
    func start() async -> State {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized: break
        case .notDetermined:
            guard await AVCaptureDevice.requestAccess(for: .video) else { return .denied }
        default: return .denied
        }
        let discovery = AVCaptureDevice.DiscoverySession(
            deviceTypes: [.builtInWideAngleCamera, .builtInDualCamera, .builtInTripleCamera, .external],
            mediaType: .video, position: .unspecified
        )
        let device = discovery.devices.first(where: { $0.position == .back }) ?? discovery.devices.first
        guard let device else { return .unavailable }

        let ok: Bool = await withCheckedContinuation { cont in
            queue.async { [self] in
                if !configured {
                    session.beginConfiguration()
                    session.sessionPreset = .photo
                    guard let input = try? AVCaptureDeviceInput(device: device), session.canAddInput(input), session.canAddOutput(output) else {
                        session.commitConfiguration()
                        cont.resume(returning: false)
                        return
                    }
                    session.addInput(input)
                    session.addOutput(output)
                    session.commitConfiguration()
                    configured = true
                }
                if !session.isRunning { session.startRunning() }
                cont.resume(returning: true)
            }
        }
        return ok ? .running : .unavailable
    }

    func stop() {
        queue.async { [session] in if session.isRunning { session.stopRunning() } }
    }

    func capture(_ completion: @escaping (UIImage?) -> Void) {
        onPhoto = completion
        queue.async { [self] in
            output.capturePhoto(with: AVCapturePhotoSettings(), delegate: self)
        }
    }

    func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        let image = photo.fileDataRepresentation().flatMap(UIImage.init(data:))
        let callback = onPhoto
        DispatchQueue.main.async { callback?(image) }
    }
}

private final class PreviewUIView: UIView {
    override class var layerClass: AnyClass { AVCaptureVideoPreviewLayer.self }
    var previewLayer: AVCaptureVideoPreviewLayer { layer as! AVCaptureVideoPreviewLayer }
}

private struct CameraPreview: UIViewRepresentable {
    let session: AVCaptureSession
    func makeUIView(context: Context) -> PreviewUIView {
        let v = PreviewUIView()
        v.previewLayer.session = session
        v.previewLayer.videoGravity = .resizeAspectFill
        return v
    }
    func updateUIView(_ uiView: PreviewUIView, context: Context) {}
}

/// Full-screen camera that returns a captured photo.
struct CameraCaptureView: View {
    var onCapture: (UIImage) -> Void
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL
    @State private var camera = CameraModel()
    @State private var state: CameraModel.State = .idle
    @State private var flash = false

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            switch state {
            case .running:
                CameraPreview(session: camera.session).ignoresSafeArea()
            case .denied:
                message(icon: "camera.fill", title: "Camera access needed",
                        body: "Allow camera access in Settings to snap photos.", action: "Open Settings") {
                    if let url = URL(string: UIApplication.openSettingsURLString) { openURL(url) }
                }
            case .unavailable:
                message(icon: "camera.badge.ellipsis", title: "No camera found",
                        body: "Choose a photo from your library instead.", action: nil, perform: {})
            case .idle:
                ProgressView().tint(.white)
            }
            Color.white.opacity(flash ? 0.8 : 0).ignoresSafeArea().allowsHitTesting(false)

            VStack {
                HStack {
                    Button { dismiss() } label: {
                        Image(systemName: "xmark").font(.headline).foregroundStyle(.white)
                            .frame(width: 44, height: 44).background(.black.opacity(0.5), in: .circle)
                    }
                    .buttonStyle(.squish(0.9))
                    Spacer()
                }
                .padding()
                Spacer()
                if state == .running {
                    Button {
                        Haptics.medium()
                        withAnimation(.easeOut(duration: 0.1)) { flash = true }
                        withAnimation(.easeIn(duration: 0.3).delay(0.1)) { flash = false }
                        camera.capture { image in
                            guard let image else { return }
                            onCapture(image)
                            dismiss()
                        }
                    } label: {
                        Circle().fill(.white).frame(width: 68, height: 68)
                            .overlay(Circle().strokeBorder(.white.opacity(0.6), lineWidth: 4).padding(-8))
                    }
                    .buttonStyle(.squish(0.88))
                    .padding(.bottom, 40)
                }
            }
        }
        .task { state = await camera.start() }
        .onDisappear { camera.stop() }
    }

    private func message(icon: String, title: String, body: String, action: String?, perform: @escaping () -> Void) -> some View {
        VStack(spacing: 14) {
            Image(systemName: icon).font(.system(size: 44)).foregroundStyle(AZ.violetLight)
            Text(title).font(.title3.bold()).foregroundStyle(.white)
            Text(body).font(.subheadline).foregroundStyle(.white.opacity(0.7)).multilineTextAlignment(.center)
            if let action {
                Button(action, action: perform).buttonStyle(.borderedProminent).tint(AZ.violet)
            }
        }
        .padding(32)
    }
}
