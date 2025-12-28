import SwiftUI

// MARK: - MealCompletionSheet

/// Sheet para marcar una comida como completada
/// Incluye rating de satisfaccion y opcion de subir foto
struct MealCompletionSheet: View {
    // MARK: - Properties

    let meal: Meal
    let onComplete: (Int, String?, String?) async -> Bool

    @EnvironmentObject var themeManager: ThemeManager
    @Environment(\.dismiss) private var dismiss

    @State private var selectedRating: Int = 0
    @State private var notes: String = ""
    @State private var selectedImage: UIImage?
    @State private var showImagePicker = false
    @State private var isSubmitting = false
    @State private var showError = false
    @State private var errorMessage = ""
    @State private var portionSize: Double = 1.0

    // MARK: - Body

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // Meal summary header
                    mealSummaryHeader

                    // Rating section
                    ratingSection

                    // Portion size section
                    portionSizeSection

                    // Photo section
                    photoSection

                    // Notes section
                    notesSection

                    // Submit button
                    submitButton
                }
                .padding(20)
            }
            .background(Color.dynamicBackground(theme: themeManager.currentTheme))
            .navigationTitle("Completar Comida")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancelar") {
                        dismiss()
                    }
                    .foregroundColor(Color.dynamicAccent(theme: themeManager.currentTheme))
                }
            }
            .alert("Error", isPresented: $showError) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(errorMessage)
            }
        }
    }

    // MARK: - Meal Summary Header

    private var mealSummaryHeader: some View {
        VStack(spacing: 12) {
            // Meal icon/image
            ZStack {
                Circle()
                    .fill(mealTypeColor.opacity(0.15))
                    .frame(width: 70, height: 70)

                Image(systemName: meal.mealType.icon)
                    .font(.system(size: 30))
                    .foregroundColor(mealTypeColor)
            }

            // Meal type
            Text(meal.mealType.displayName)
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(Color.dynamicTextSecondary(theme: themeManager.currentTheme))
                .textCase(.uppercase)

            // Meal name
            Text(meal.name)
                .font(.system(size: 20, weight: .bold))
                .foregroundColor(Color.dynamicText(theme: themeManager.currentTheme))
                .multilineTextAlignment(.center)

            // Calories
            HStack(spacing: 6) {
                Image(systemName: "flame.fill")
                    .font(.system(size: 14))
                    .foregroundColor(.orange)
                Text("\(meal.calories) kcal")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(Color.dynamicTextSecondary(theme: themeManager.currentTheme))
            }
        }
        .padding(.vertical, 8)
    }

    // MARK: - Rating Section

    private var ratingSection: some View {
        VStack(spacing: 16) {
            Text("Como te ha parecido esta comida?")
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(Color.dynamicText(theme: themeManager.currentTheme))

            // Star rating
            HStack(spacing: 12) {
                ForEach(1...5, id: \.self) { star in
                    Button(action: {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                            selectedRating = star
                        }
                        let impact = UIImpactFeedbackGenerator(style: .light)
                        impact.impactOccurred()
                    }) {
                        Image(systemName: star <= selectedRating ? "star.fill" : "star")
                            .font(.system(size: 36))
                            .foregroundColor(star <= selectedRating ? .yellow : Color.dynamicBorder(theme: themeManager.currentTheme))
                            .scaleEffect(star <= selectedRating ? 1.1 : 1.0)
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }

            // Rating text
            if selectedRating > 0 {
                Text(ratingText)
                    .font(.system(size: 14))
                    .foregroundColor(Color.dynamicTextSecondary(theme: themeManager.currentTheme))
                    .transition(.opacity)
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.dynamicSurface(theme: themeManager.currentTheme))
        )
    }

    // MARK: - Portion Size Section

    private var portionSizeSection: some View {
        VStack(spacing: 12) {
            HStack {
                Text("Porcion consumida")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(Color.dynamicText(theme: themeManager.currentTheme))

                Spacer()

                Text("\(Int(portionSize * 100))%")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(Color.dynamicAccent(theme: themeManager.currentTheme))
            }

            // Slider
            Slider(value: $portionSize, in: 0.25...1.5, step: 0.25)
                .tint(Color.dynamicAccent(theme: themeManager.currentTheme))

            // Preset buttons
            HStack(spacing: 10) {
                ForEach([0.5, 0.75, 1.0, 1.25, 1.5], id: \.self) { portion in
                    Button(action: {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                            portionSize = portion
                        }
                    }) {
                        Text("\(Int(portion * 100))%")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(
                                portionSize == portion
                                    ? .white
                                    : Color.dynamicText(theme: themeManager.currentTheme)
                            )
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(
                                Capsule()
                                    .fill(
                                        portionSize == portion
                                            ? Color.dynamicAccent(theme: themeManager.currentTheme)
                                            : Color.dynamicSurface(theme: themeManager.currentTheme)
                                    )
                            )
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.dynamicSurface(theme: themeManager.currentTheme))
        )
    }

    // MARK: - Photo Section

    private var photoSection: some View {
        VStack(spacing: 12) {
            HStack {
                Text("Foto de tu comida (opcional)")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(Color.dynamicText(theme: themeManager.currentTheme))

                Spacer()
            }

            if let image = selectedImage {
                // Show selected photo
                ZStack(alignment: .topTrailing) {
                    Image(uiImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(height: 200)
                        .clipShape(RoundedRectangle(cornerRadius: 12))

                    Button(action: {
                        withAnimation {
                            selectedImage = nil
                        }
                    }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 24))
                            .foregroundColor(.white)
                            .shadow(radius: 2)
                    }
                    .padding(8)
                }
            } else {
                // Photo picker button
                Button(action: {
                    showImagePicker = true
                }) {
                    VStack(spacing: 12) {
                        Image(systemName: "camera.fill")
                            .font(.system(size: 28))
                            .foregroundColor(Color.dynamicAccent(theme: themeManager.currentTheme))

                        Text("Agregar foto")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(Color.dynamicTextSecondary(theme: themeManager.currentTheme))
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 120)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(
                                Color.dynamicBorder(theme: themeManager.currentTheme),
                                style: StrokeStyle(lineWidth: 2, dash: [8])
                            )
                    )
                }
                .buttonStyle(PlainButtonStyle())
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.dynamicSurface(theme: themeManager.currentTheme))
        )
        .sheet(isPresented: $showImagePicker) {
            PhotosPicker(selectedImage: $selectedImage, isPresented: $showImagePicker)
        }
    }

    // MARK: - Notes Section

    private var notesSection: some View {
        VStack(spacing: 12) {
            HStack {
                Text("Notas (opcional)")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(Color.dynamicText(theme: themeManager.currentTheme))

                Spacer()

                Text("\(notes.count)/200")
                    .font(.system(size: 12))
                    .foregroundColor(Color.dynamicTextTertiary(theme: themeManager.currentTheme))
            }

            TextField("Como preparaste la comida, sustituciones...", text: $notes, axis: .vertical)
                .font(.system(size: 14))
                .foregroundColor(Color.dynamicText(theme: themeManager.currentTheme))
                .lineLimit(3...5)
                .padding(12)
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .fill(Color.dynamicBackground(theme: themeManager.currentTheme))
                )
                .onChange(of: notes) { _, newValue in
                    if newValue.count > 200 {
                        notes = String(newValue.prefix(200))
                    }
                }
        }
        .padding(20)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.dynamicSurface(theme: themeManager.currentTheme))
        )
    }

    // MARK: - Submit Button

    private var submitButton: some View {
        Button(action: {
            Task {
                await submitCompletion()
            }
        }) {
            HStack(spacing: 10) {
                if isSubmitting {
                    ProgressView()
                        .tint(.white)
                        .scaleEffect(0.9)
                } else {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 18))
                }

                Text(isSubmitting ? "Guardando..." : "Marcar como Completada")
                    .font(.system(size: 16, weight: .semibold))
            }
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(
                        selectedRating > 0
                            ? Color.dynamicAccent(theme: themeManager.currentTheme)
                            : Color.gray
                    )
            )
        }
        .disabled(selectedRating == 0 || isSubmitting)
        .padding(.top, 8)
    }

    // MARK: - Helpers

    private var mealTypeColor: Color {
        switch meal.mealType {
        case .breakfast: return .orange
        case .midMorning: return .yellow
        case .lunch: return .green
        case .afternoon: return .blue
        case .dinner: return .purple
        case .postWorkout: return .red
        case .lateSnack: return .indigo
        }
    }

    private var ratingText: String {
        switch selectedRating {
        case 1: return "Muy mala experiencia"
        case 2: return "No me gusto mucho"
        case 3: return "Regular, esta bien"
        case 4: return "Me gusto bastante"
        case 5: return "Excelente, deliciosa"
        default: return ""
        }
    }

    // MARK: - Actions

    private func submitCompletion() async {
        guard selectedRating > 0 else { return }

        isSubmitting = true

        // TODO: Upload photo if selected and get URL
        let photoUrl: String? = nil // Would be uploaded via MediaUploadService

        let success = await onComplete(
            selectedRating,
            photoUrl,
            notes.isEmpty ? nil : notes
        )

        await MainActor.run {
            isSubmitting = false

            if success {
                let notification = UINotificationFeedbackGenerator()
                notification.notificationOccurred(.success)
                dismiss()
            } else {
                errorMessage = "No se pudo completar la comida. Intenta de nuevo."
                showError = true
            }
        }
    }
}

// MARK: - MealCompletedView

/// Vista que muestra una comida ya completada
struct MealCompletedView: View {
    let meal: Meal

    @EnvironmentObject var themeManager: ThemeManager

    var body: some View {
        VStack(spacing: 16) {
            // Success icon
            ZStack {
                Circle()
                    .fill(Color.green.opacity(0.15))
                    .frame(width: 80, height: 80)

                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 40))
                    .foregroundColor(.green)
            }

            // Title
            Text("Comida Completada")
                .font(.system(size: 18, weight: .bold))
                .foregroundColor(Color.dynamicText(theme: themeManager.currentTheme))

            // Completion time
            if let completedAt = meal.completedAt {
                Text(formatDate(completedAt))
                    .font(.system(size: 14))
                    .foregroundColor(Color.dynamicTextSecondary(theme: themeManager.currentTheme))
            }

            // Rating
            if let rating = meal.satisfactionRating {
                HStack(spacing: 4) {
                    ForEach(1...5, id: \.self) { star in
                        Image(systemName: star <= rating ? "star.fill" : "star")
                            .font(.system(size: 18))
                            .foregroundColor(star <= rating ? .yellow : Color.dynamicBorder(theme: themeManager.currentTheme))
                    }
                }
            }

            // Photo (if exists)
            if let photoUrl = meal.completionPhotoUrl, !photoUrl.isEmpty {
                AsyncImage(url: URL(string: photoUrl)) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(height: 200)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                    case .failure, .empty:
                        EmptyView()
                    @unknown default:
                        EmptyView()
                    }
                }
            }
        }
        .padding(24)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Color.green.opacity(0.1))
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(Color.green.opacity(0.3), lineWidth: 1)
                )
        )
    }

    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        formatter.locale = Locale(identifier: "es_ES")
        return formatter.string(from: date)
    }
}

// MARK: - Preview

#Preview {
    Color.black
        .ignoresSafeArea()
        .sheet(isPresented: .constant(true)) {
            Text("Preview requires real meal data")
                .environmentObject(ThemeManager())
        }
}
