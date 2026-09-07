import SwiftUI

// MARK: - Session Review Sheet
/// Modal for creating/editing a class review with star rating + optional comment

struct SessionReviewSheet: View {
    let sessionId: Int
    let className: String
    var existingReview: ClassReview?
    var onReviewSubmitted: (() -> Void)?

    @EnvironmentObject var themeManager: ThemeManager
    @StateObject private var reviewService = ReviewService.shared
    @Environment(\.dismiss) private var dismiss

    @State private var rating: Int = 0
    @State private var comment: String = ""
    @State private var isSubmitting = false
    @State private var showSuccess = false
    @State private var errorText: String?

    private let accentColor = Color(hex: "#D4FF3F")!

    var body: some View {
        NavigationStack {
            ZStack {
                Color.dynamicBackground(theme: themeManager.currentTheme).ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 28) {
                        // Header
                        VStack(spacing: 8) {
                            Text("¿Qué tal estuvo?")
                                .font(.system(size: 22, weight: .bold))
                                .tracking(-0.4)
                                .foregroundColor(Color.dynamicText(theme: themeManager.currentTheme))

                            Text(className)
                                .font(.system(size: 14))
                                .foregroundColor(Color.dynamicText(theme: themeManager.currentTheme).opacity(0.5))
                        }
                        .padding(.top, 20)

                        // Star rating
                        starRatingView

                        // Rating label
                        if rating > 0 {
                            Text(ratingLabel)
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(accentColor)
                                .transition(.opacity.combined(with: .scale))
                        }

                        // Comment field
                        VStack(alignment: .leading, spacing: 8) {
                            Text("COMENTARIO")
                                .font(.system(size: 9, weight: .bold))
                                .tracking(1.0)
                                .foregroundColor(Color.dynamicText(theme: themeManager.currentTheme).opacity(0.5))

                            TextEditor(text: $comment)
                                .font(.system(size: 14))
                                .foregroundColor(Color.dynamicText(theme: themeManager.currentTheme))
                                .scrollContentBackground(.hidden)
                                .frame(minHeight: 100)
                                .padding(14)
                                .background(Color.dynamicSurface(theme: themeManager.currentTheme))
                                .clipShape(RoundedRectangle(cornerRadius: 14))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 14)
                                        .stroke(Color.white.opacity(0.08), lineWidth: 1)
                                )

                            Text("Opcional · máx 1000 caracteres")
                                .font(.system(size: 11))
                                .foregroundColor(Color.dynamicText(theme: themeManager.currentTheme).opacity(0.35))
                        }
                        .padding(.horizontal, 20)

                        // Error message
                        if let error = errorText {
                            HStack(spacing: 8) {
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .font(.system(size: 14))
                                    .foregroundColor(Color(hex: "#FF5A5A")!)
                                Text(error)
                                    .font(.system(size: 13))
                                    .foregroundColor(Color(hex: "#FF5A5A")!)
                            }
                            .padding(.horizontal, 20)
                        }

                        // Submit button
                        Button(action: submitReview) {
                            HStack(spacing: 8) {
                                if isSubmitting {
                                    ProgressView()
                                        .tint(.white)
                                        .scaleEffect(0.8)
                                } else {
                                    Image(systemName: existingReview != nil ? "pencil" : "checkmark")
                                        .font(.system(size: 16, weight: .semibold))
                                    Text(existingReview != nil ? "Actualizar review" : "Enviar review")
                                        .font(.system(size: 16, weight: .bold))
                                }
                            }
                            .frame(maxWidth: .infinity)
                            .frame(height: 52)
                            .foregroundColor(Color.accentInk)
                            .background(
                                RoundedRectangle(cornerRadius: 14)
                                    .fill(rating > 0 ? accentColor : Color.dynamicSurface(theme: themeManager.currentTheme))
                            )
                        }
                        .disabled(rating == 0 || isSubmitting)
                        .padding(.horizontal, 20)

                        // Delete button (if editing)
                        if let review = existingReview {
                            Button(action: { deleteReview(reviewId: review.id) }) {
                                Text("Eliminar review")
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundColor(Color(hex: "#FF5A5A")!)
                            }
                        }

                        Spacer(minLength: 40)
                    }
                }

                // Success overlay
                if showSuccess {
                    successOverlay
                }
            }
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cerrar") { dismiss() }
                        .foregroundColor(Color.dynamicText(theme: themeManager.currentTheme).opacity(0.7))
                }
            }
            .onAppear {
                reviewService.authService = reviewService.authService ?? ServiceContainer.shared.authService
                if let existing = existingReview {
                    rating = existing.rating
                    comment = existing.comment ?? ""
                }
            }
        }
    }

    // MARK: - Star Rating

    private var starRatingView: some View {
        HStack(spacing: 12) {
            ForEach(1...5, id: \.self) { star in
                Button(action: {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                        rating = star
                    }
                    HapticManager.shared.buttonTap()
                }) {
                    Image(systemName: star <= rating ? "star.fill" : "star")
                        .font(.system(size: 36))
                        .foregroundColor(star <= rating ? accentColor : Color.dynamicText(theme: themeManager.currentTheme).opacity(0.2))
                        .scaleEffect(star <= rating ? 1.1 : 1.0)
                        .animation(.spring(response: 0.3, dampingFraction: 0.6), value: rating)
                }
            }
        }
    }

    private var ratingLabel: String {
        switch rating {
        case 1: return "Mala"
        case 2: return "Regular"
        case 3: return "Buena"
        case 4: return "Muy buena"
        case 5: return "Excelente"
        default: return ""
        }
    }

    // MARK: - Success Overlay

    private var successOverlay: some View {
        VStack(spacing: 16) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 56))
                .foregroundColor(accentColor)

            Text("¡Review enviada!")
                .font(.system(size: 20, weight: .bold))
                .foregroundColor(Color.dynamicText(theme: themeManager.currentTheme))

            Text("Gracias por tu feedback")
                .font(.system(size: 14))
                .foregroundColor(Color.dynamicText(theme: themeManager.currentTheme).opacity(0.5))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.dynamicBackground(theme: themeManager.currentTheme).opacity(0.95))
        .transition(.opacity)
    }

    // MARK: - Actions

    private func submitReview() {
        guard rating > 0, !isSubmitting else { return }
        isSubmitting = true
        errorText = nil

        let trimmedComment = comment.trimmingCharacters(in: .whitespacesAndNewlines)
        let finalComment = trimmedComment.isEmpty ? nil : String(trimmedComment.prefix(1000))

        Task {
            if let existing = existingReview {
                // Update
                if let _ = await reviewService.updateReview(
                    reviewId: existing.id,
                    rating: rating,
                    comment: finalComment
                ) {
                    showSuccessAndDismiss()
                } else {
                    errorText = reviewService.errorMessage ?? "Error al actualizar"
                    isSubmitting = false
                }
            } else {
                // Create
                if let _ = await reviewService.createReview(
                    sessionId: sessionId,
                    rating: rating,
                    comment: finalComment
                ) {
                    showSuccessAndDismiss()
                } else {
                    errorText = reviewService.errorMessage ?? "Error al enviar"
                    isSubmitting = false
                }
            }
        }
    }

    private func deleteReview(reviewId: Int) {
        Task {
            if await reviewService.deleteReview(reviewId: reviewId) {
                showSuccessAndDismiss()
            }
        }
    }

    private func showSuccessAndDismiss() {
        withAnimation { showSuccess = true }
        isSubmitting = false
        HapticManager.shared.play(.success)
        onReviewSubmitted?()
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
            dismiss()
        }
    }
}
