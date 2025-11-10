import SwiftUI

/// Vista para reportar un post con selector de razón y descripción opcional
struct ReportPostView: View {
    @EnvironmentObject var themeManager: ThemeManager
    @StateObject private var viewModel: ReportPostViewModel
    @Environment(\.dismiss) var dismiss

    init(postId: Int) {
        _viewModel = StateObject(wrappedValue: ReportPostViewModel(postId: postId))
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color.dynamicBackground(theme: themeManager.currentTheme)
                    .ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 24) {
                        // Header info
                        headerSection

                        // Reason selector
                        reasonSection

                        // Description (optional)
                        descriptionSection

                        // Submit button
                        submitButton
                    }
                    .padding()
                }
            }
            .navigationTitle("Reportar Post")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Cancelar") {
                        dismiss()
                    }
                    .foregroundColor(Color.dynamicText(theme: themeManager.currentTheme))
                    .disabled(viewModel.isSubmitting)
                }
            }
            .alert("Reporte enviado", isPresented: $viewModel.showSuccessAlert) {
                Button("OK") {
                    dismiss()
                }
            } message: {
                Text("Gracias por tu reporte. Revisaremos el contenido lo antes posible.")
            }
            .alert("Error", isPresented: .constant(viewModel.errorMessage != nil)) {
                Button("OK") {
                    viewModel.errorMessage = nil
                }
            } message: {
                if let error = viewModel.errorMessage {
                    Text(error)
                }
            }
        }
    }

    // MARK: - Header Section

    private var headerSection: some View {
        VStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 48))
                .foregroundColor(.orange)

            Text("Reportar contenido inapropiado")
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(Color.dynamicText(theme: themeManager.currentTheme))
                .multilineTextAlignment(.center)

            Text("Tu reporte es anónimo. Revisaremos el contenido y tomaremos las medidas necesarias.")
                .font(.system(size: 14))
                .foregroundColor(.gray)
                .multilineTextAlignment(.center)
        }
        .padding()
    }

    // MARK: - Reason Section

    private var reasonSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Motivo del reporte")
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(Color.dynamicText(theme: themeManager.currentTheme))

            ForEach(ReportReason.allCases, id: \.self) { reason in
                reasonButton(reason)
            }
        }
    }

    private func reasonButton(_ reason: ReportReason) -> some View {
        Button(action: {
            withAnimation(.spring(response: 0.3)) {
                viewModel.selectedReason = reason
            }
        }) {
            HStack(spacing: 12) {
                Image(systemName: viewModel.selectedReason == reason ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 20))
                    .foregroundColor(viewModel.selectedReason == reason ? Color.dynamicAccent(theme: themeManager.currentTheme) : .gray)

                VStack(alignment: .leading, spacing: 4) {
                    Text(reason.title)
                        .font(.system(size: 15, weight: .medium))
                        .foregroundColor(Color.dynamicText(theme: themeManager.currentTheme))

                    Text(reason.description)
                        .font(.system(size: 13))
                        .foregroundColor(.gray)
                }

                Spacer()
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(viewModel.selectedReason == reason ? Color.dynamicAccent(theme: themeManager.currentTheme).opacity(0.1) : Color.dynamicSurface(theme: themeManager.currentTheme))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(viewModel.selectedReason == reason ? Color.dynamicAccent(theme: themeManager.currentTheme) : Color.dynamicBorder(theme: themeManager.currentTheme), lineWidth: viewModel.selectedReason == reason ? 2 : 1)
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Description Section

    private var descriptionSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Detalles adicionales (opcional)")
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(Color.dynamicText(theme: themeManager.currentTheme))

            TextField("Proporciona más información sobre el problema...", text: $viewModel.description, axis: .vertical)
                .font(.system(size: 15))
                .foregroundColor(Color.dynamicText(theme: themeManager.currentTheme))
                .padding()
                .background(Color.dynamicSurface(theme: themeManager.currentTheme))
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.dynamicBorder(theme: themeManager.currentTheme), lineWidth: 1)
                )
                .lineLimit(5...10)

            HStack {
                Spacer()
                Text("\(viewModel.description.count)/500")
                    .font(.system(size: 12))
                    .foregroundColor(viewModel.description.count > 500 ? .red : .gray)
            }
        }
    }

    // MARK: - Submit Button

    private var submitButton: some View {
        Button(action: {
            Task {
                await viewModel.submitReport()
            }
        }) {
            HStack {
                if viewModel.isSubmitting {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        .scaleEffect(0.9)
                } else {
                    Text("Enviar reporte")
                        .font(.system(size: 16, weight: .semibold))
                }
            }
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(viewModel.canSubmit ? Color.dynamicAccent(theme: themeManager.currentTheme) : Color.gray)
            )
        }
        .disabled(!viewModel.canSubmit || viewModel.isSubmitting)
        .padding(.top, 8)
    }
}

// MARK: - Report Reason

enum ReportReason: String, CaseIterable {
    case spam = "spam"
    case harassment = "harassment"
    case hateSpeech = "hate_speech"
    case violence = "violence"
    case nudity = "nudity"
    case falseInfo = "false_info"
    case other = "other"

    var title: String {
        switch self {
        case .spam:
            return "Spam o publicidad"
        case .harassment:
            return "Acoso o bullying"
        case .hateSpeech:
            return "Discurso de odio"
        case .violence:
            return "Violencia o contenido peligroso"
        case .nudity:
            return "Desnudez o contenido sexual"
        case .falseInfo:
            return "Información falsa"
        case .other:
            return "Otro"
        }
    }

    var description: String {
        switch self {
        case .spam:
            return "Contenido repetitivo o no deseado"
        case .harassment:
            return "Ataque o intimidación a otros usuarios"
        case .hateSpeech:
            return "Discriminación por raza, género, etc."
        case .violence:
            return "Amenazas o contenido violento"
        case .nudity:
            return "Contenido explícito o inapropiado"
        case .falseInfo:
            return "Información engañosa o falsa"
        case .other:
            return "Otra razón no listada"
        }
    }
}

// MARK: - Report Post ViewModel

@MainActor
class ReportPostViewModel: ObservableObject {
    @Published var selectedReason: ReportReason?
    @Published var description: String = ""
    @Published var isSubmitting = false
    @Published var errorMessage: String?
    @Published var showSuccessAlert = false

    private let postId: Int
    private let postService: PostService

    init(postId: Int, postService: PostService = .shared) {
        self.postId = postId
        self.postService = postService
    }

    var canSubmit: Bool {
        selectedReason != nil && !isSubmitting && description.count <= 500
    }

    func submitReport() async {
        guard let reason = selectedReason, canSubmit else { return }

        isSubmitting = true
        errorMessage = nil

        do {
            let trimmedDescription = description.trimmingCharacters(in: .whitespacesAndNewlines)
            let descriptionToSend = trimmedDescription.isEmpty ? nil : trimmedDescription

            try await postService.reportPost(
                postId: postId,
                reason: reason.rawValue,
                description: descriptionToSend
            )

            showSuccessAlert = true

        } catch {
            errorMessage = "Error al enviar reporte: \(error.localizedDescription)"
        }

        isSubmitting = false
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        ReportPostView(postId: 1)
            .environmentObject(ThemeManager())
    }
}
