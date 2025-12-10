//
//  QRScannerView.swift
//  Gym_API
//
//  Created by Claude Code on 12/1/25.
//  Updated: 12/3/25 - v2.0 con flujo de confirmación de perfil
//

import SwiftUI
import AVFoundation
import AudioToolbox

/// Vista principal para escanear códigos QR de miembros y realizar check-in
/// Solo accesible para usuarios con roles: ADMIN, TRAINER, OWNER
/// v2.0: Muestra perfil del miembro antes de confirmar check-in
struct QRScannerView: View {
    @EnvironmentObject var attendanceService: AttendanceService
    @EnvironmentObject var classService: ClassService
    @EnvironmentObject var themeManager: ThemeManager
    @EnvironmentObject var authService: AuthServiceDirect
    @Environment(\.dismiss) var dismiss

    // Parámetro: Sesión pre-seleccionada (cuando hay 3+ sesiones)
    let preSelectedSession: SessionWithClass?

    @State private var scannedQRCode: String?
    @State private var showMemberPreview = false
    @State private var showSuccess = false
    @State private var showError = false
    @State private var currentError: AttendanceCheckInError?
    @State private var memberProfile: UserPublicProfile?
    @State private var checkInResponse: AttendanceCheckInResponse?
    @State private var cameraPermissionDenied = false

    var contextBadgeText: String {
        if let session = preSelectedSession {
            return "\(session.classInfo.name) - \(session.formattedTime)"
        } else if attendanceService.availableSessions.count == 1 {
            return "1 clase activa"
        } else if attendanceService.availableSessions.count == 2 {
            return "2 clases activas"
        }
        return ""
    }

    var body: some View {
        ZStack {
            // Scanner de cámara
            if cameraPermissionDenied {
                cameraPermissionDeniedView
            } else {
                QRCodeScannerRepresentable { code in
                    handleScannedCode(code)
                }
                .ignoresSafeArea()
            }

            // Overlay
            VStack {
                // Header
                HStack {
                    // Botón cerrar
                    Button(action: { dismiss() }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 32))
                            .foregroundColor(.white.opacity(0.8))
                    }

                    Spacer()

                    // Badge de contexto
                    if !contextBadgeText.isEmpty {
                        Text(contextBadgeText)
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(.white)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(
                                Capsule()
                                    .fill(Color.dynamicAccent(theme: themeManager.currentTheme))
                            )
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 16)

                Spacer()

                // Frame de escaneo
                RoundedRectangle(cornerRadius: 20)
                    .stroke(Color.dynamicAccent(theme: themeManager.currentTheme), lineWidth: 3)
                    .frame(width: 250, height: 250)

                Spacer()

                // Instrucciones
                VStack(spacing: 16) {
                    Text("Escanea el código QR del miembro")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(.white)

                    if let session = preSelectedSession {
                        VStack(spacing: 4) {
                            Text("Clase seleccionada:")
                                .font(.system(size: 14))
                                .foregroundColor(.white.opacity(0.7))
                            Text(session.classInfo.name)
                                .font(.system(size: 16, weight: .medium))
                                .foregroundColor(.white)
                            Text(session.formattedTime)
                                .font(.system(size: 14))
                                .foregroundColor(.white.opacity(0.7))
                        }
                        .padding(16)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color.black.opacity(0.5))
                        )
                    }
                }
                .padding(.horizontal, 32)
                .padding(.bottom, 32)
            }

            // Loading overlay
            if attendanceService.isLoadingProfile {
                Color.black.opacity(0.7)
                    .ignoresSafeArea()

                VStack(spacing: 16) {
                    ProgressView()
                        .scaleEffect(1.5)
                        .tint(.white)

                    Text("Buscando miembro...")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.white)
                }
            }
        }
        .sheet(isPresented: $showMemberPreview) {
            if let profile = memberProfile {
                MemberProfilePreviewSheet(
                    profile: profile,
                    availableSessions: attendanceService.availableSessions,
                    preSelectedSessionId: preSelectedSession?.session.id,
                    onConfirm: { sessionId in
                        performCheckIn(userId: profile.id, sessionId: sessionId)
                    },
                    onCancel: {
                        showMemberPreview = false
                        scannedQRCode = nil // Permitir reescaneo
                    }
                )
                .environmentObject(themeManager)
            }
        }
        .sheet(isPresented: $showSuccess) {
            if let response = checkInResponse, let profile = memberProfile {
                CheckInSuccessView(
                    response: response,
                    memberName: profile.fullName
                )
            }
        }
        .alert(currentError?.title ?? "Error", isPresented: $showError) {
            Button("OK", role: .cancel) {
                scannedQRCode = nil // Permitir reescaneo
            }
        } message: {
            Text(currentError?.errorDescription ?? "Ocurrió un error")
        }
        .onAppear {
            checkCameraPermission()
        }
    }

    // MARK: - Subviews

    private var cameraPermissionDeniedView: some View {
        VStack(spacing: 20) {
            Image(systemName: "camera.fill")
                .font(.system(size: 60))
                .foregroundColor(.gray)

            Text("Permiso de Cámara Requerido")
                .font(.system(size: 22, weight: .bold))
                .foregroundColor(Color.dynamicText(theme: themeManager.currentTheme))

            Text("Necesitamos acceso a tu cámara para escanear códigos QR. Por favor, habilita el permiso en Configuración.")
                .font(.system(size: 15))
                .foregroundColor(Color.dynamicTextSecondary(theme: themeManager.currentTheme))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)

            Button(action: openSettings) {
                Text("Abrir Configuración")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 30)
                    .padding(.vertical, 12)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color.dynamicAccent(theme: themeManager.currentTheme))
                    )
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.dynamicBackground(theme: themeManager.currentTheme))
    }

    // MARK: - Actions

    private func handleScannedCode(_ code: String) {
        guard scannedQRCode == nil else { return } // Evitar múltiples escaneos

        scannedQRCode = code
        triggerHapticFeedback(style: .medium)

        // Extraer user_id del QR
        guard let userId = attendanceService.extractUserId(from: code) else {
            currentError = AttendanceCheckInError.invalidQRCode
            triggerHapticFeedback(style: .heavy)
            showError = true
            scannedQRCode = nil
            return
        }

        // Buscar perfil del miembro
        Task {
            do {
                let profile = try await attendanceService.fetchMemberProfile(userId: userId)
                memberProfile = profile
                showMemberPreview = true
            } catch {
                if let attendanceError = error as? AttendanceCheckInError {
                    currentError = attendanceError
                } else {
                    currentError = AttendanceCheckInError.networkError(error.localizedDescription)
                }
                triggerHapticFeedback(style: .heavy)
                showError = true
                scannedQRCode = nil
            }
        }
    }

    private func performCheckIn(userId: Int, sessionId: Int?) {
        Task {
            do {
                let response = try await attendanceService.confirmCheckIn(
                    userId: userId,
                    sessionId: sessionId ?? preSelectedSession?.session.id
                )

                checkInResponse = response
                showMemberPreview = false
                triggerHapticFeedback(style: .light)
                showSuccess = true

                // Esperar 2 segundos y cerrar todo
                try? await Task.sleep(nanoseconds: 2_000_000_000)
                showSuccess = false
                dismiss()

            } catch {
                showMemberPreview = false

                if let attendanceError = error as? AttendanceCheckInError {
                    currentError = attendanceError
                } else {
                    currentError = AttendanceCheckInError.networkError(error.localizedDescription)
                }

                triggerHapticFeedback(style: .heavy)
                showError = true
                scannedQRCode = nil
            }
        }
    }

    private func checkCameraPermission() {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            cameraPermissionDenied = false
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { granted in
                DispatchQueue.main.async {
                    cameraPermissionDenied = !granted
                }
            }
        case .denied, .restricted:
            cameraPermissionDenied = true
        @unknown default:
            cameraPermissionDenied = true
        }
    }

    private func openSettings() {
        if let url = URL(string: UIApplication.openSettingsURLString) {
            UIApplication.shared.open(url)
        }
    }

    private func triggerHapticFeedback(style: UIImpactFeedbackGenerator.FeedbackStyle) {
        let generator = UIImpactFeedbackGenerator(style: style)
        generator.impactOccurred()
    }
}

// MARK: - QR Scanner Representable

struct QRCodeScannerRepresentable: UIViewControllerRepresentable {
    let onCodeScanned: (String) -> Void

    func makeUIViewController(context: Context) -> QRScannerViewController {
        let scanner = QRScannerViewController()
        scanner.onCodeScanned = onCodeScanned
        return scanner
    }

    func updateUIViewController(_ uiViewController: QRScannerViewController, context: Context) {}
}

// MARK: - QR Scanner View Controller

class QRScannerViewController: UIViewController, AVCaptureMetadataOutputObjectsDelegate {
    var onCodeScanned: ((String) -> Void)?
    private var captureSession: AVCaptureSession?
    private var previewLayer: AVCaptureVideoPreviewLayer?
    private var hasScanned = false

    override func viewDidLoad() {
        super.viewDidLoad()
        setupCamera()
    }

    private func setupCamera() {
        captureSession = AVCaptureSession()

        guard let videoCaptureDevice = AVCaptureDevice.default(for: .video),
              let videoInput = try? AVCaptureDeviceInput(device: videoCaptureDevice),
              let captureSession = captureSession else { return }

        if captureSession.canAddInput(videoInput) {
            captureSession.addInput(videoInput)
        }

        let metadataOutput = AVCaptureMetadataOutput()

        if captureSession.canAddOutput(metadataOutput) {
            captureSession.addOutput(metadataOutput)
            metadataOutput.setMetadataObjectsDelegate(self, queue: DispatchQueue.main)
            metadataOutput.metadataObjectTypes = [.qr]
        }

        previewLayer = AVCaptureVideoPreviewLayer(session: captureSession)
        previewLayer?.frame = view.layer.bounds
        previewLayer?.videoGravity = .resizeAspectFill

        if let previewLayer = previewLayer {
            view.layer.addSublayer(previewLayer)
        }

        DispatchQueue.global(qos: .userInitiated).async {
            captureSession.startRunning()
        }
    }

    func metadataOutput(_ output: AVCaptureMetadataOutput,
                       didOutput metadataObjects: [AVMetadataObject],
                       from connection: AVCaptureConnection) {
        guard !hasScanned,
              let metadataObject = metadataObjects.first,
              let readableObject = metadataObject as? AVMetadataMachineReadableCodeObject,
              let stringValue = readableObject.stringValue else { return }

        hasScanned = true
        AudioServicesPlaySystemSound(SystemSoundID(kSystemSoundID_Vibrate))
        onCodeScanned?(stringValue)
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        captureSession?.stopRunning()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        previewLayer?.frame = view.layer.bounds
    }
}

// MARK: - Preview

#Preview {
    QRScannerView(preSelectedSession: nil)
        .environmentObject(ServiceContainer.shared.attendanceService)
        .environmentObject(ServiceContainer.shared.classService)
        .environmentObject(ServiceContainer.shared.themeManager)
        .environmentObject(ServiceContainer.shared.authService)
}
