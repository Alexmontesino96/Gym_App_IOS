import SwiftUI

// MARK: - MealDetailView
/// Detailed meal view with hero image, macros, ingredients, preparation, portion slider
/// Replicates MealDetailScreen from prototype exactly
struct MealDetailView: View {
    let meal: Meal

    @EnvironmentObject var themeManager: ThemeManager
    @EnvironmentObject var nutritionService: NutritionService
    @Environment(\.dismiss) private var dismiss

    @State private var portion: Double = 1.0
    @State private var isDone: Bool = false
    @State private var isSubmitting = false
    @State private var showCheckmark = false
    @State private var checkmarkScale: CGFloat = 0.3
    @State private var buttonScale: CGFloat = 1.0
    @State private var confettiOffset: CGFloat = 0

    private let accentColor = Color(hex: "#D4FF3F")!

    // MARK: - Computed

    private var adjustedKcal: Int { Int(Double(meal.calories) * portion) }
    private var adjustedP: Int { Int(Double(meal.proteinG ?? 0) * portion) }
    private var adjustedC: Int { Int(Double(meal.carbsG ?? 0) * portion) }
    private var adjustedF: Int { Int(Double(meal.fatG ?? 0) * portion) }

    private var mealColor: Color {
        switch meal.mealType {
        case .breakfast: return Color(hex: "#FFB347")!
        case .midMorning: return Color(hex: "#F472B6")!
        case .lunch: return Color(hex: "#FF5A1F")!
        case .afternoon: return Color(hex: "#A78BFA")!
        case .dinner: return Color(hex: "#3B82F6")!
        case .postWorkout: return Color(hex: "#D4FF3F")!
        case .lateSnack: return Color(hex: "#8B5CF6")!
        }
    }

    private var prepTimeString: String {
        guard let minutes = meal.preparationTimeMinutes else { return "" }
        return "\(minutes) min"
    }

    private var timeString: String {
        switch meal.mealType {
        case .breakfast: return "08:00"
        case .midMorning: return "11:00"
        case .lunch: return "14:00"
        case .afternoon: return "16:00"
        case .postWorkout: return "18:30"
        case .dinner: return "20:30"
        case .lateSnack: return "22:00"
        }
    }

    // MARK: - Body

    var body: some View {
        ZStack(alignment: .bottom) {
            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: 0) {
                    // Hero image area
                    heroSection

                    // Elevated card (overlapping)
                    elevatedMacroCard
                        .padding(.horizontal, 20)
                        .offset(y: -28)

                    // Ingredients
                    ingredientsSection
                        .padding(.horizontal, 20)
                        .padding(.top, -4)

                    // Preparation
                    preparationSection
                        .padding(.horizontal, 20)
                        .padding(.top, 24)

                    // Portion slider
                    portionSlider
                        .padding(.horizontal, 20)
                        .padding(.top, 24)

                    Spacer(minLength: 100)
                }
            }

            // Bottom CTA
            ctaButton
        }
        .background(Color.dynamicBackground(theme: themeManager.currentTheme))
        .navigationBarHidden(true)
        .onAppear {
            // Check fresh state from todayPlan (not the stale meal copy)
            if let freshMeal = nutritionService.todayPlan?.meals.first(where: { $0.id == meal.id }) {
                isDone = freshMeal.isCompleted
            } else {
                isDone = meal.isCompleted
            }
        }
    }

    // MARK: - Hero Section

    private var heroSection: some View {
        ZStack(alignment: .top) {
            // Gradient background
            ZStack {
                // Radial meal-colored gradient
                RadialGradient(
                    colors: [mealColor.opacity(0.8), mealColor.opacity(0.3), Color(hex: "#0A0A0A")!],
                    center: UnitPoint(x: 0.4, y: 0.5),
                    startRadius: 0,
                    endRadius: 180
                )

                // Stylized plate
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [
                                Color(hex: "#E8DCB6")!,
                                Color(hex: "#C4A878")!,
                                Color(hex: "#8B6F3F")!
                            ],
                            center: UnitPoint(x: 0.35, y: 0.35),
                            startRadius: 0,
                            endRadius: 100
                        )
                    )
                    .frame(width: 200, height: 200)
                    .shadow(color: .black.opacity(0.45), radius: 15, y: 15)
                    .overlay {
                        // Food elements on plate
                        ZStack {
                            Ellipse()
                                .fill(LinearGradient(colors: [Color(hex: "#D4A574")!, Color(hex: "#A87B4A")!], startPoint: .topLeading, endPoint: .bottomTrailing))
                                .frame(width: 70, height: 50)
                                .offset(x: -25, y: -20)

                            Circle()
                                .fill(LinearGradient(colors: [Color(hex: "#E8DCB6")!, Color(hex: "#C4A878")!], startPoint: .topLeading, endPoint: .bottomTrailing))
                                .frame(width: 60, height: 55)
                                .offset(x: 30, y: -18)

                            Circle()
                                .fill(LinearGradient(colors: [Color(hex: "#5A8A3E")!, Color(hex: "#3D5F28")!], startPoint: .topLeading, endPoint: .bottomTrailing))
                                .frame(width: 50, height: 40)
                                .offset(x: -15, y: 30)

                            Circle()
                                .fill(LinearGradient(colors: [Color(hex: "#C73E2E")!, Color(hex: "#8B2A20")!], startPoint: .topLeading, endPoint: .bottomTrailing))
                                .frame(width: 35, height: 35)
                                .offset(x: 25, y: 25)
                        }
                    }
                    .offset(y: -10)
            }
            .frame(height: 260)
            .clipShape(
                UnevenRoundedRectangle(bottomLeadingRadius: 32, bottomTrailingRadius: 32)
            )

            // Top bar buttons
            HStack {
                Button(action: { dismiss() }) {
                    Image(systemName: "arrow.left")
                        .font(.system(size: 18))
                        .foregroundColor(.white)
                        .frame(width: 40, height: 40)
                        .background(.ultraThinMaterial.opacity(0.6))
                        .background(Color.black.opacity(0.4))
                        .clipShape(Circle())
                }

                Spacer()

                HStack(spacing: 8) {
                    Button(action: {}) {
                        Image(systemName: "bookmark")
                            .font(.system(size: 18))
                            .foregroundColor(.white)
                            .frame(width: 40, height: 40)
                            .background(Color.black.opacity(0.4))
                            .clipShape(Circle())
                    }
                    Button(action: {}) {
                        Image(systemName: "frying.pan")
                            .font(.system(size: 18))
                            .foregroundColor(.white)
                            .frame(width: 40, height: 40)
                            .background(Color.black.opacity(0.4))
                            .clipShape(Circle())
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 8)

            // Bottom chips
            VStack {
                Spacer()
                HStack(spacing: 6) {
                    // Meal type chip
                    Text(meal.mealType.displayName.uppercased())
                        .font(.system(size: 10, weight: .bold))
                        .tracking(1.0)
                        .foregroundColor(mealColor)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(Color.black.opacity(0.6))
                        .clipShape(Capsule())

                    // Time chip
                    HStack(spacing: 4) {
                        Image(systemName: "clock")
                            .font(.system(size: 11))
                        Text(timeString)
                            .font(.system(size: 11, weight: .semibold, design: .monospaced))
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(Color.black.opacity(0.6))
                    .clipShape(Capsule())

                    // Prep time chip
                    if meal.preparationTimeMinutes != nil {
                        HStack(spacing: 4) {
                            Image(systemName: "timer")
                                .font(.system(size: 11))
                            Text(prepTimeString)
                                .font(.system(size: 11, weight: .semibold, design: .monospaced))
                        }
                        .foregroundColor(.white)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(Color.black.opacity(0.6))
                        .clipShape(Capsule())
                    }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 56)
            }
            .frame(height: 260)
        }
    }

    // MARK: - Elevated Macro Card

    private var elevatedMacroCard: some View {
        VStack(alignment: .leading, spacing: 6) {
            // Meal name
            Text(meal.name)
                .font(.system(size: 20, weight: .bold))
                .foregroundColor(Color.dynamicText(theme: themeManager.currentTheme))

            // Description
            if let desc = meal.description {
                Text(desc)
                    .font(.system(size: 14))
                    .foregroundColor(Color.dynamicText(theme: themeManager.currentTheme).opacity(0.7))
                    .lineSpacing(4)
            }

            // Macros row
            HStack(spacing: 0) {
                macroColumn(value: adjustedKcal, label: "kcal", color: Color.dynamicText(theme: themeManager.currentTheme))
                Spacer()
                macroColumn(value: adjustedP, label: "P", color: accentColor)
                Spacer()
                macroColumn(value: adjustedC, label: "C", color: Color(hex: "#FF5A1F")!)
                Spacer()
                macroColumn(value: adjustedF, label: "F", color: Color(hex: "#A78BFA")!)
            }
            .padding(.top, 14)
            .overlay(alignment: .top) {
                Rectangle()
                    .fill(Color.white.opacity(0.08))
                    .frame(height: 1)
            }
        }
        .padding(18)
        .background(Color.dynamicSurface(theme: themeManager.currentTheme))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.white.opacity(0.08), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.4), radius: 16, y: 6)
    }

    private func macroColumn(value: Int, label: String, color: Color) -> some View {
        VStack(spacing: 2) {
            Text("\(value)")
                .font(.system(size: 18, weight: .bold, design: .monospaced))
                .tracking(-0.36)
                .foregroundColor(color)

            Text(label.uppercased())
                .font(.system(size: 9, weight: .semibold))
                .tracking(0.7)
                .foregroundColor(Color.dynamicText(theme: themeManager.currentTheme).opacity(0.45))
        }
    }

    // MARK: - Ingredients Section

    private var ingredientsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("INGREDIENTES · \(meal.ingredients.count)")
                .font(.system(size: 9, weight: .bold))
                .tracking(1.0)
                .foregroundColor(Color.dynamicText(theme: themeManager.currentTheme).opacity(0.5))

            VStack(spacing: 0) {
                ForEach(Array(meal.ingredients.sorted().enumerated()), id: \.element.id) { index, ingredient in
                    VStack(spacing: 0) {
                        HStack(alignment: .top, spacing: 12) {
                            VStack(alignment: .leading, spacing: 4) {
                                HStack(spacing: 6) {
                                    Text(ingredient.name)
                                        .font(.system(size: 13, weight: .semibold))
                                        .foregroundColor(Color.dynamicText(theme: themeManager.currentTheme))

                                    if ingredient.isOptional {
                                        Text("OPT")
                                            .font(.system(size: 8, weight: .bold))
                                            .tracking(0.5)
                                            .foregroundColor(Color.dynamicText(theme: themeManager.currentTheme).opacity(0.45))
                                            .padding(.horizontal, 6)
                                            .padding(.vertical, 2)
                                            .background(Color.dynamicSurface2(theme: themeManager.currentTheme))
                                            .clipShape(RoundedRectangle(cornerRadius: 4))
                                    }
                                }

                                if ingredient.hasAlternatives {
                                    HStack(spacing: 0) {
                                        Text("Alt: ")
                                            .foregroundColor(Color.dynamicText(theme: themeManager.currentTheme).opacity(0.3))
                                        Text(ingredient.alternatives ?? "")
                                            .foregroundColor(Color.dynamicText(theme: themeManager.currentTheme).opacity(0.5))
                                    }
                                    .font(.system(size: 11))
                                    .lineSpacing(2)
                                }
                            }

                            Spacer()

                            Text(ingredient.formattedQuantity)
                                .font(.system(size: 13, weight: .semibold, design: .monospaced))
                                .foregroundColor(Color.dynamicText(theme: themeManager.currentTheme))
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, ingredient.hasAlternatives ? 14 : 12)

                        if index < meal.ingredients.count - 1 {
                            Rectangle()
                                .fill(Color.white.opacity(0.08))
                                .frame(height: 1)
                        }
                    }
                }
            }
            .background(Color.dynamicSurface(theme: themeManager.currentTheme))
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(Color.white.opacity(0.08), lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: 16))
        }
    }

    // MARK: - Preparation Section

    private var preparationSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            let steps = meal.cookingSteps

            Text("PREP · \(steps.count) steps")
                .font(.system(size: 9, weight: .bold))
                .tracking(1.0)
                .foregroundColor(Color.dynamicText(theme: themeManager.currentTheme).opacity(0.5))

            VStack(spacing: 10) {
                ForEach(Array(steps.enumerated()), id: \.offset) { index, step in
                    HStack(alignment: .top, spacing: 12) {
                        // Step number
                        Text("\(index + 1)")
                            .font(.system(size: 11, weight: .bold, design: .monospaced))
                            .foregroundColor(Color.dynamicText(theme: themeManager.currentTheme))
                            .frame(width: 24, height: 24)
                            .background(Color.dynamicSurface(theme: themeManager.currentTheme))
                            .overlay(
                                Circle()
                                    .stroke(Color.white.opacity(0.08), lineWidth: 1)
                            )
                            .clipShape(Circle())

                        // Step text
                        Text(step)
                            .font(.system(size: 13))
                            .foregroundColor(Color.dynamicText(theme: themeManager.currentTheme).opacity(0.7))
                            .lineSpacing(4)
                            .padding(.top, 2)
                    }
                }
            }
        }
    }

    // MARK: - Portion Slider

    private var portionSlider: some View {
        VStack(spacing: 12) {
            HStack {
                Text("YOUR SERVING")
                    .font(.system(size: 9, weight: .bold))
                    .tracking(1.0)
                    .foregroundColor(Color.dynamicText(theme: themeManager.currentTheme).opacity(0.5))

                Spacer()

                Text(String(format: "%.2fx", portion))
                    .font(.system(size: 18, weight: .bold, design: .monospaced))
                    .foregroundColor(accentColor)
            }

            Slider(value: $portion, in: 0.5...2.0, step: 0.05)
                .tint(accentColor)

            HStack {
                Text("0.5x")
                Spacer()
                Text("1.0x")
                Spacer()
                Text("1.5x")
                Spacer()
                Text("2.0x")
            }
            .font(.system(size: 10, weight: .semibold, design: .monospaced))
            .foregroundColor(Color.dynamicText(theme: themeManager.currentTheme).opacity(0.45))
        }
        .padding(16)
        .background(Color.dynamicSurface(theme: themeManager.currentTheme))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.white.opacity(0.08), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    // MARK: - CTA Button

    private var ctaButton: some View {
        ZStack {
            VStack {
                Button(action: toggleCompletion) {
                    ZStack {
                        // Button content
                        HStack(spacing: 8) {
                            if isDone {
                                Image(systemName: "checkmark.circle.fill")
                                    .font(.system(size: 18, weight: .semibold))
                                    .transition(.scale.combined(with: .opacity))
                            } else {
                                Image(systemName: "checkmark")
                                    .font(.system(size: 18, weight: .semibold))
                            }

                            Text(isDone ? "Completado" : "Marcar completada")
                                .font(.system(size: 16, weight: .bold))
                                .contentTransition(.numericText())
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .foregroundColor(isDone ? Color(hex: "#4ADE80")! : Color.accentInk)
                        .background(
                            isDone
                                ? Color(hex: "#4ADE80")!.opacity(0.15)
                                : accentColor
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 14)
                                .stroke(isDone ? Color(hex: "#4ADE80")!.opacity(0.4) : .clear, lineWidth: 1)
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                    }
                }
                .buttonStyle(.plain)
                .disabled(isDone)
                .scaleEffect(buttonScale)
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 32)
            .padding(.top, 16)
            .background(
                LinearGradient(
                    colors: [
                        Color.dynamicBackground(theme: themeManager.currentTheme),
                        Color.dynamicBackground(theme: themeManager.currentTheme),
                        Color.dynamicBackground(theme: themeManager.currentTheme).opacity(0)
                    ],
                    startPoint: .bottom,
                    endPoint: .top
                )
            )

            // Fullscreen checkmark celebration
            if showCheckmark {
                ZStack {
                    // Radial burst
                    Circle()
                        .fill(accentColor.opacity(0.08))
                        .frame(width: 200, height: 200)
                        .scaleEffect(checkmarkScale * 1.5)

                    // Checkmark
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 72))
                        .foregroundColor(accentColor)
                        .scaleEffect(checkmarkScale)
                        .shadow(color: accentColor.opacity(0.4), radius: 20)
                }
                .transition(.opacity)
                .allowsHitTesting(false)
            }
        }
    }

    // MARK: - Actions

    private func toggleCompletion() {
        guard !isDone else { return }

        // 1. Instant haptic
        let impact = UIImpactFeedbackGenerator(style: .heavy)
        impact.impactOccurred()

        // 2. Optimistic UI — mark done immediately with animation
        withAnimation(.spring(response: 0.35, dampingFraction: 0.6)) {
            isDone = true
            buttonScale = 0.92
        }

        // 3. Button bounce back
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.5)) {
                buttonScale = 1.0
            }
        }

        // 4. Show celebration checkmark
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.5)) {
                showCheckmark = true
                checkmarkScale = 1.2
            }
        }

        // 5. Shrink checkmark
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                checkmarkScale = 1.0
            }
        }

        // 6. Success haptic
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            let success = UINotificationFeedbackGenerator()
            success.notificationOccurred(.success)
        }

        // 7. Hide celebration
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
            withAnimation(.easeOut(duration: 0.3)) {
                showCheckmark = false
                checkmarkScale = 0.3
            }
        }

        // 8. Fire API in background (don't wait)
        Task {
            let result = await nutritionService.completeMeal(mealId: meal.id, rating: 5, portionModifier: portion)
            if result == nil {
                // Rollback on failure
                await MainActor.run {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                        isDone = false
                    }
                    HapticManager.shared.play(.error)
                }
            }
        }
    }
}
