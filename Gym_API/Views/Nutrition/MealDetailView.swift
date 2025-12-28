import SwiftUI

// MARK: - MealDetailView

/// Vista de detalle de una comida individual
/// Muestra imagen, macros, ingredientes, instrucciones y acciones
struct MealDetailView: View {
    // MARK: - Properties

    let meal: Meal

    @EnvironmentObject var themeManager: ThemeManager
    @EnvironmentObject var nutritionService: NutritionService
    @Environment(\.dismiss) private var dismiss

    @State private var showCompletionSheet = false
    @State private var showCompletedPhoto = false
    @State private var isSubmitting = false
    @State private var showError = false
    @State private var errorMessage = ""
    @State private var appearAnimation = false

    // MARK: - Body

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 0) {
                    // Header with image
                    headerSection
                        .opacity(appearAnimation ? 1 : 0)

                    VStack(spacing: 20) {
                        // Meal info section
                        mealInfoSection
                            .opacity(appearAnimation ? 1 : 0)
                            .offset(y: appearAnimation ? 0 : 20)

                        // Macros section
                        macrosSection
                            .opacity(appearAnimation ? 1 : 0)
                            .offset(y: appearAnimation ? 0 : 20)

                        // Ingredients section
                        if !meal.ingredients.isEmpty {
                            ingredientsSection
                                .opacity(appearAnimation ? 1 : 0)
                                .offset(y: appearAnimation ? 0 : 20)
                        }

                        // Cooking instructions section
                        if meal.hasInstructions {
                            instructionsSection
                                .opacity(appearAnimation ? 1 : 0)
                                .offset(y: appearAnimation ? 0 : 20)
                        }

                        // Completed status section
                        if meal.isCompleted {
                            completedSection
                                .opacity(appearAnimation ? 1 : 0)
                                .offset(y: appearAnimation ? 0 : 20)
                        }

                        // Action buttons
                        actionButtonsSection
                            .opacity(appearAnimation ? 1 : 0)
                            .offset(y: appearAnimation ? 0 : 20)

                        // Bottom spacing
                        Spacer()
                            .frame(height: 40)
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 20)
                }
            }
            .background(Color.dynamicBackground(theme: themeManager.currentTheme))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: { dismiss() }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 24))
                            .foregroundColor(Color.dynamicTextSecondary(theme: themeManager.currentTheme))
                    }
                }

                ToolbarItem(placement: .principal) {
                    Text(meal.mealType.displayName)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(Color.dynamicText(theme: themeManager.currentTheme))
                }
            }
            .sheet(isPresented: $showCompletionSheet) {
                MealCompletionSheet(meal: meal) { rating, photoUrl, notes in
                    await completeMeal(rating: rating, photoUrl: photoUrl, notes: notes)
                }
                .environmentObject(themeManager)
            }
            .fullScreenCover(isPresented: $showCompletedPhoto) {
                if let photoUrl = meal.completionPhotoUrl {
                    PhotoViewerSheet(imageUrl: photoUrl)
                        .environmentObject(themeManager)
                }
            }
            .alert("Error", isPresented: $showError) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(errorMessage)
            }
            .onAppear {
                withAnimation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.1)) {
                    appearAnimation = true
                }
            }
        }
    }

    // MARK: - Header Section

    private var headerSection: some View {
        ZStack(alignment: .bottomLeading) {
            // Image or placeholder
            if let imageUrl = meal.imageUrl, !imageUrl.isEmpty {
                AsyncImage(url: URL(string: imageUrl)) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                    case .failure, .empty:
                        headerPlaceholder
                    @unknown default:
                        headerPlaceholder
                    }
                }
                .frame(height: 280)
                .clipped()
            } else {
                headerPlaceholder
            }

            // Gradient overlay
            LinearGradient(
                colors: [
                    Color.dynamicBackground(theme: themeManager.currentTheme),
                    Color.dynamicBackground(theme: themeManager.currentTheme).opacity(0.8),
                    .clear
                ],
                startPoint: .bottom,
                endPoint: .top
            )
            .frame(height: 120)

            // Status badge
            if meal.isCompleted {
                HStack(spacing: 6) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 14))
                    Text("Completada")
                        .font(.system(size: 13, weight: .semibold))
                }
                .foregroundColor(.white)
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(
                    Capsule()
                        .fill(Color.green)
                )
                .padding(20)
            }
        }
    }

    private var headerPlaceholder: some View {
        ZStack {
            Rectangle()
                .fill(
                    LinearGradient(
                        colors: [mealTypeColor.opacity(0.3), mealTypeColor.opacity(0.1)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )

            VStack(spacing: 12) {
                Image(systemName: meal.mealType.icon)
                    .font(.system(size: 50))
                    .foregroundColor(mealTypeColor)

                Text(meal.mealType.displayName)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(mealTypeColor.opacity(0.8))
            }
        }
        .frame(height: 280)
    }

    // MARK: - Meal Info Section

    private var mealInfoSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Meal type badge
            HStack(spacing: 8) {
                Image(systemName: meal.mealType.icon)
                    .font(.system(size: 12))
                Text(meal.mealType.displayName)
                    .font(.system(size: 12, weight: .semibold))
                    .textCase(.uppercase)
            }
            .foregroundColor(mealTypeColor)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(
                Capsule()
                    .fill(mealTypeColor.opacity(0.15))
            )

            // Meal name
            Text(meal.name)
                .font(.system(size: 26, weight: .bold))
                .foregroundColor(Color.dynamicText(theme: themeManager.currentTheme))

            // Description
            if let description = meal.description, !description.isEmpty {
                Text(description)
                    .font(.system(size: 15))
                    .foregroundColor(Color.dynamicTextSecondary(theme: themeManager.currentTheme))
                    .lineSpacing(4)
            }

            // Prep time and typical time
            HStack(spacing: 16) {
                if let prepTime = meal.preparationTimeFormatted {
                    HStack(spacing: 6) {
                        Image(systemName: "clock")
                            .font(.system(size: 13))
                        Text(prepTime)
                            .font(.system(size: 13))
                    }
                    .foregroundColor(Color.dynamicTextSecondary(theme: themeManager.currentTheme))
                }

                HStack(spacing: 6) {
                    Image(systemName: "sun.max")
                        .font(.system(size: 13))
                    Text(meal.mealType.typicalTime)
                        .font(.system(size: 13))
                }
                .foregroundColor(Color.dynamicTextSecondary(theme: themeManager.currentTheme))
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Macros Section

    private var macrosSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Informacion Nutricional")
                .font(.system(size: 18, weight: .bold))
                .foregroundColor(Color.dynamicText(theme: themeManager.currentTheme))

            MealMacrosPills(meal: meal)
                .environmentObject(themeManager)
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.dynamicSurface(theme: themeManager.currentTheme))
        )
    }

    // MARK: - Ingredients Section

    private var ingredientsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Ingredientes")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(Color.dynamicText(theme: themeManager.currentTheme))

                Spacer()

                Text("\(meal.ingredientCount) items")
                    .font(.system(size: 13))
                    .foregroundColor(Color.dynamicTextSecondary(theme: themeManager.currentTheme))
            }

            IngredientChecklistView(
                ingredients: meal.ingredients,
                isInteractive: !meal.isCompleted
            )
            .environmentObject(themeManager)
        }
    }

    // MARK: - Instructions Section

    private var instructionsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            CookingInstructionsView(
                instructions: meal.cookingInstructions,
                tips: nil, // Would come from API
                preparationTime: meal.preparationTimeMinutes,
                isInteractive: !meal.isCompleted
            )
            .environmentObject(themeManager)
        }
    }

    // MARK: - Completed Section

    private var completedSection: some View {
        VStack(spacing: 16) {
            // Completed header
            HStack {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 20))
                    .foregroundColor(.green)

                Text("Comida Completada")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(Color.dynamicText(theme: themeManager.currentTheme))

                Spacer()
            }

            // Rating
            if let rating = meal.satisfactionRating {
                HStack {
                    Text("Tu calificacion:")
                        .font(.system(size: 14))
                        .foregroundColor(Color.dynamicTextSecondary(theme: themeManager.currentTheme))

                    Spacer()

                    HStack(spacing: 4) {
                        ForEach(1...5, id: \.self) { star in
                            Image(systemName: star <= rating ? "star.fill" : "star")
                                .font(.system(size: 16))
                                .foregroundColor(star <= rating ? .yellow : Color.dynamicBorder(theme: themeManager.currentTheme))
                        }
                    }
                }
            }

            // Completion time
            if let completedAt = meal.completedAt {
                HStack {
                    Text("Completada:")
                        .font(.system(size: 14))
                        .foregroundColor(Color.dynamicTextSecondary(theme: themeManager.currentTheme))

                    Spacer()

                    Text(formatDate(completedAt))
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(Color.dynamicText(theme: themeManager.currentTheme))
                }
            }

            // Completion photo
            if let photoUrl = meal.completionPhotoUrl, !photoUrl.isEmpty {
                Button(action: {
                    showCompletedPhoto = true
                }) {
                    HStack {
                        Image(systemName: "photo.fill")
                            .font(.system(size: 14))
                        Text("Ver foto")
                            .font(.system(size: 14, weight: .medium))
                    }
                    .foregroundColor(Color.dynamicAccent(theme: themeManager.currentTheme))
                }
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.green.opacity(0.1))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Color.green.opacity(0.3), lineWidth: 1)
                )
        )
    }

    // MARK: - Action Buttons Section

    private var actionButtonsSection: some View {
        VStack(spacing: 12) {
            if !meal.isCompleted {
                // Complete button
                Button(action: {
                    let impact = UIImpactFeedbackGenerator(style: .medium)
                    impact.impactOccurred()
                    showCompletionSheet = true
                }) {
                    HStack(spacing: 10) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 18))
                        Text("Marcar como Completada")
                            .font(.system(size: 16, weight: .semibold))
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(
                        RoundedRectangle(cornerRadius: 14)
                            .fill(Color.dynamicAccent(theme: themeManager.currentTheme))
                    )
                }
            }

            // Share button (optional)
            Button(action: {
                let impact = UIImpactFeedbackGenerator(style: .light)
                impact.impactOccurred()
                // Share functionality
            }) {
                HStack(spacing: 10) {
                    Image(systemName: "square.and.arrow.up")
                        .font(.system(size: 16))
                    Text("Compartir Receta")
                        .font(.system(size: 15, weight: .medium))
                }
                .foregroundColor(Color.dynamicAccent(theme: themeManager.currentTheme))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(Color.dynamicAccent(theme: themeManager.currentTheme), lineWidth: 1.5)
                )
            }
        }
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

    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        formatter.locale = Locale(identifier: "es_ES")
        return formatter.string(from: date)
    }

    // MARK: - Actions

    private func completeMeal(rating: Int, photoUrl: String?, notes: String?) async -> Bool {
        isSubmitting = true

        let result = await nutritionService.completeMeal(
            mealId: meal.id,
            rating: rating,
            photoUrl: photoUrl,
            notes: notes,
            portionModifier: 1.0
        )

        await MainActor.run {
            isSubmitting = false

            if result != nil {
                // Success - dismiss will happen from the sheet
                return
            } else {
                errorMessage = nutritionService.errorMessage ?? "Error al completar la comida"
                showError = true
            }
        }

        return result != nil
    }
}

// MARK: - PhotoViewerSheet

/// Sheet para ver una foto en pantalla completa
struct PhotoViewerSheet: View {
    let imageUrl: String

    @EnvironmentObject var themeManager: ThemeManager
    @Environment(\.dismiss) private var dismiss

    @State private var scale: CGFloat = 1.0

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            AsyncImage(url: URL(string: imageUrl)) { phase in
                switch phase {
                case .success(let image):
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .scaleEffect(scale)
                        .gesture(
                            MagnificationGesture()
                                .onChanged { value in
                                    scale = value.magnitude
                                }
                                .onEnded { _ in
                                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                        scale = 1.0
                                    }
                                }
                        )
                case .failure:
                    VStack(spacing: 12) {
                        Image(systemName: "exclamationmark.triangle")
                            .font(.system(size: 40))
                            .foregroundColor(.gray)
                        Text("No se pudo cargar la imagen")
                            .foregroundColor(.gray)
                    }
                case .empty:
                    ProgressView()
                        .tint(.white)
                        .scaleEffect(1.5)
                @unknown default:
                    EmptyView()
                }
            }

            // Close button
            VStack {
                HStack {
                    Spacer()
                    Button(action: { dismiss() }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 30))
                            .foregroundColor(.white)
                            .shadow(radius: 3)
                    }
                    .padding(20)
                }
                Spacer()
            }
        }
    }
}

// MARK: - Preview

#Preview {
    Color.black
        .ignoresSafeArea()
        .sheet(isPresented: .constant(true)) {
            Text("Preview requires real meal data")
                .environmentObject(ThemeManager())
                .environmentObject(NutritionService.shared)
        }
}
