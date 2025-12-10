import SwiftUI
import CoreImage.CIFilterBuiltins

/// Sheet that displays the user's QR code for attendance confirmation
struct QRCodeSheet: View {
    let qrCode: String?
    let userName: String?

    @EnvironmentObject var themeManager: ThemeManager
    @Environment(\.dismiss) var dismiss

    // QR code generator
    private let context = CIContext()
    private let filter = CIFilter.qrCodeGenerator()

    var body: some View {
        NavigationStack {
            ZStack {
                // Background
                Color.dynamicBackground(theme: themeManager.currentTheme)
                    .ignoresSafeArea()

                VStack(spacing: 32) {
                    Spacer()

                    // QR Code
                    qrCodeImage
                        .frame(width: 250, height: 250)
                        .padding(20)
                        .background(
                            RoundedRectangle(cornerRadius: 20)
                                .fill(Color.white)
                                .shadow(
                                    color: Color.black.opacity(0.15),
                                    radius: 20,
                                    x: 0,
                                    y: 10
                                )
                        )

                    // User Info
                    VStack(spacing: 12) {
                        if let name = userName, !name.isEmpty {
                            Text(name)
                                .font(.system(size: 22, weight: .bold))
                                .foregroundColor(Color.dynamicText(theme: themeManager.currentTheme))
                        }

                        Text("Escanear para confirmar asistencia")
                            .font(.system(size: 15, weight: .medium))
                            .foregroundColor(Color.dynamicTextSecondary(theme: themeManager.currentTheme))
                            .multilineTextAlignment(.center)
                    }

                    Spacer()

                    // Info note
                    HStack(spacing: 8) {
                        Image(systemName: "info.circle.fill")
                            .font(.system(size: 16))
                            .foregroundColor(Color.dynamicAccent(theme: themeManager.currentTheme))

                        Text("Muestra este codigo al staff del gimnasio")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(Color.dynamicTextSecondary(theme: themeManager.currentTheme))
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 12)
                    .background(
                        Capsule()
                            .fill(Color.dynamicAccent(theme: themeManager.currentTheme).opacity(0.1))
                    )
                    .padding(.bottom, 20)
                }
                .padding(.horizontal, 24)
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { dismiss() }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 24))
                            .foregroundColor(Color.dynamicTextSecondary(theme: themeManager.currentTheme))
                    }
                }

                ToolbarItem(placement: .principal) {
                    Text("Mi Codigo QR")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundColor(Color.dynamicText(theme: themeManager.currentTheme))
                }
            }
        }
    }

    // MARK: - QR Code Image

    @ViewBuilder
    private var qrCodeImage: some View {
        if let qrCode = qrCode, !qrCode.isEmpty, let image = generateQRCode(from: qrCode) {
            Image(uiImage: image)
                .interpolation(.none)
                .resizable()
                .scaledToFit()
        } else {
            // Placeholder when no QR code available
            VStack(spacing: 16) {
                Image(systemName: "qrcode")
                    .font(.system(size: 60))
                    .foregroundColor(.gray.opacity(0.5))

                Text("QR no disponible")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.gray)
            }
        }
    }

    // MARK: - QR Code Generation

    private func generateQRCode(from string: String) -> UIImage? {
        let data = Data(string.utf8)
        filter.setValue(data, forKey: "inputMessage")
        filter.setValue("H", forKey: "inputCorrectionLevel") // High error correction

        guard let outputImage = filter.outputImage else { return nil }

        // Scale up the QR code for better quality
        let scale = UIScreen.main.scale * 10
        let transform = CGAffineTransform(scaleX: scale, y: scale)
        let scaledImage = outputImage.transformed(by: transform)

        guard let cgImage = context.createCGImage(scaledImage, from: scaledImage.extent) else { return nil }

        return UIImage(cgImage: cgImage)
    }
}

// MARK: - Preview

#Preview {
    QRCodeSheet(qrCode: "TEST-QR-CODE-12345", userName: "Juan Perez")
        .environmentObject(ThemeManager())
}
