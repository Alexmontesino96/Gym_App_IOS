//
//  CameraView.swift
//  Gym_API
//
//  Camera view wrapper for AVCaptureSession
//

import SwiftUI
import AVFoundation

struct StoryCameraView: UIViewRepresentable {
    @ObservedObject var camera: CameraManager

    func makeUIView(context: Context) -> UIView {
        let view = UIView(frame: .zero)

        camera.preview = AVCaptureVideoPreviewLayer(session: camera.session)
        camera.preview.frame = view.bounds
        camera.preview.videoGravity = .resizeAspectFill
        view.layer.addSublayer(camera.preview)

        camera.checkPermissions()

        return view
    }

    func updateUIView(_ uiView: UIView, context: Context) {
        if let previewLayer = uiView.layer.sublayers?.first as? AVCaptureVideoPreviewLayer {
            DispatchQueue.main.async {
                previewLayer.frame = uiView.bounds
            }
        }
    }
}

// MARK: - Camera Manager
class CameraManager: NSObject, ObservableObject, AVCapturePhotoCaptureDelegate {
    @Published var isTaken = false
    @Published var session = AVCaptureSession()
    @Published var alert = false
    @Published var output = AVCapturePhotoOutput()
    @Published var preview: AVCaptureVideoPreviewLayer!
    @Published var isSaved = false
    @Published var picData = Data(count: 0)
    @Published var capturedImage: UIImage?

    private var isConfiguring = false

    func checkPermissions() {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            setUp()
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { [weak self] status in
                if status {
                    self?.setUp()
                }
            }
        case .denied, .restricted:
            alert = true
        @unknown default:
            break
        }
    }

    func setUp() {
        do {
            isConfiguring = true
            session.beginConfiguration()

            guard let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back) else {
                session.commitConfiguration()
                isConfiguring = false
                return
            }
            let input = try AVCaptureDeviceInput(device: device)

            if session.canAddInput(input) {
                session.addInput(input)
            }

            if session.canAddOutput(output) {
                session.addOutput(output)
            }

            session.commitConfiguration()
            isConfiguring = false

            DispatchQueue.global(qos: .background).async { [weak self] in
                self?.session.startRunning()
            }
        } catch {
            print("Camera setup error: \(error.localizedDescription)")
            if isConfiguring {
                session.commitConfiguration()
                isConfiguring = false
            }
        }
    }

    func takePicture() {
        let settings = AVCapturePhotoSettings()
        output.capturePhoto(with: settings, delegate: self)

        // Haptic feedback
        let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
        impactFeedback.impactOccurred()

        DispatchQueue.main.async {
            withAnimation { self.isTaken = true }
        }
    }

    func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        guard error == nil else {
            print("Photo capture error: \(error!.localizedDescription)")
            return
        }

        guard let imageData = photo.fileDataRepresentation() else { return }

        DispatchQueue.main.async {
            self.picData = imageData
            self.capturedImage = UIImage(data: imageData)
        }
    }

    func retake() {
        DispatchQueue.main.async {
            withAnimation {
                print("DEBUG:📷 CameraManager.retake() called - clearing captured image and resetting state")
                self.isTaken = false
                self.capturedImage = nil
                self.picData = Data(count: 0)
            }
        }
    }

    func stopSession() {
        print("DEBUG:📷 CameraManager.stopSession()")
        if session.isRunning {
            session.stopRunning()
        }
        // Detach preview layer to avoid stale overlay and potential freezes
        DispatchQueue.main.async { [weak self] in
            if let preview = self?.preview {
                preview.removeFromSuperlayer()
                self?.preview = nil
                print("DEBUG:📷 Preview layer removed")
            }
        }
    }

    func startSessionIfNeeded() {
        print("DEBUG:📷 CameraManager.startSessionIfNeeded() - isRunning=\(session.isRunning), isConfiguring=\(isConfiguring)")

        // Don't start if already running or currently configuring
        guard !session.isRunning && !isConfiguring else {
            print("DEBUG:📷 Skipping startSession - already running or configuring")
            return
        }

        DispatchQueue.global(qos: .background).async { [weak self] in
            guard let self = self, !self.isConfiguring else { return }
            self.session.startRunning()
            print("DEBUG:📷 Session started successfully")
        }
    }
}
