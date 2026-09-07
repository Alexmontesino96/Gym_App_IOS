import SwiftUI

// MARK: - MealTimelineCard
/// Individual meal card for the nutrition plan timeline
/// Matches prototype: time+status node left, content right, status badges
struct MealTimelineCard: View {
    let meal: Meal
    let isCurrentMeal: Bool
    let onTap: () -> Void

    @EnvironmentObject var themeManager: ThemeManager

    private let accentColor = Color(hex: "#D4FF3F")!

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

    private var mealIcon: String {
        switch meal.mealType {
        case .breakfast: return "cup.and.saucer.fill"
        case .midMorning: return "apple.logo"
        case .lunch: return "fork.knife"
        case .afternoon: return "birthday.cake.fill"
        case .dinner: return "leaf.fill"
        case .postWorkout: return "mug.fill"
        case .lateSnack: return "moon.stars.fill"
        }
    }

    private var timeString: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        // Use meal type typical time as fallback
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

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 0) {
                // MARK: - Time + Status Node
                VStack(spacing: 8) {
                    Text(timeString)
                        .font(.system(size: 13, weight: .bold, design: .monospaced))
                        .tracking(-0.26)

                    // Status circle
                    ZStack {
                        Circle()
                            .fill(statusCircleBackground)
                            .frame(width: 32, height: 32)

                        if isCurrentMeal {
                            Circle()
                                .stroke(accentColor, lineWidth: 2)
                                .frame(width: 32, height: 32)

                            // Glow ring
                            Circle()
                                .stroke(accentColor.opacity(0.2), lineWidth: 4)
                                .frame(width: 40, height: 40)
                        }

                        if meal.isCompleted {
                            Image(systemName: "checkmark")
                                .font(.system(size: 16, weight: .bold))
                                .foregroundColor(Color.accentInk)
                        } else {
                            Image(systemName: mealIcon)
                                .font(.system(size: 16))
                                .foregroundColor(isCurrentMeal ? Color.accentInk : mealColor)
                        }
                    }
                }
                .frame(width: 64)
                .padding(.vertical, 14)
                .padding(.horizontal, 8)

                // Divider
                Rectangle()
                    .fill(Color.white.opacity(0.08))
                    .frame(width: 1)

                // MARK: - Content
                VStack(alignment: .leading, spacing: 4) {
                    // Type label + status badge
                    HStack {
                        Text(meal.mealType.displayName.uppercased())
                            .font(.system(size: 10, weight: .bold))
                            .tracking(0.8)
                            .foregroundColor(mealColor)

                        Spacer()

                        if isCurrentMeal {
                            Text("AHORA")
                                .font(.system(size: 9, weight: .bold))
                                .tracking(0.7)
                                .foregroundColor(Color.accentInk)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 2)
                                .background(accentColor)
                                .clipShape(Capsule())
                        } else if meal.isCompleted {
                            Text("COMPLETADO")
                                .font(.system(size: 9, weight: .bold))
                                .tracking(0.7)
                                .foregroundColor(Color.dynamicText(theme: themeManager.currentTheme).opacity(0.45))
                        }
                    }

                    // Meal name
                    Text(meal.name)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(Color.dynamicText(theme: themeManager.currentTheme))
                        .strikethrough(meal.isCompleted, color: Color.dynamicText(theme: themeManager.currentTheme).opacity(0.3))
                        .lineLimit(1)
                        .padding(.bottom, 4)

                    // Macros mini row
                    HStack(spacing: 10) {
                        HStack(spacing: 0) {
                            Text("\(meal.calories)")
                                .font(.system(size: 11, weight: .semibold, design: .monospaced))
                            Text(" kcal")
                                .font(.system(size: 10, design: .monospaced))
                                .foregroundColor(Color.dynamicText(theme: themeManager.currentTheme).opacity(0.45))
                        }

                        Text("·")
                            .foregroundColor(Color.dynamicText(theme: themeManager.currentTheme).opacity(0.3))

                        HStack(spacing: 6) {
                            macroLabel("P", value: meal.proteinG ?? 0, color: accentColor)
                            macroLabel("C", value: meal.carbsG ?? 0, color: Color(hex: "#FF5A1F")!)
                            macroLabel("F", value: meal.fatG ?? 0, color: Color(hex: "#A78BFA")!)
                        }
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundColor(Color.dynamicText(theme: themeManager.currentTheme).opacity(0.45))
                    }
                }
                .padding(.vertical, 14)
                .padding(.horizontal, 16)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .background(cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(cardBorderColor, lineWidth: 1)
            )
            .opacity(meal.isCompleted ? 0.7 : 1)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Helpers

    @ViewBuilder
    private func macroLabel(_ letter: String, value: Int, color: Color) -> some View {
        HStack(spacing: 0) {
            Text(letter)
                .foregroundColor(color)
            Text(" \(value)")
        }
    }

    private var statusCircleBackground: Color {
        if meal.isCompleted || isCurrentMeal {
            return accentColor
        }
        return Color.dynamicSurface2(theme: themeManager.currentTheme)
    }

    private var cardBackground: some ShapeStyle {
        if isCurrentMeal {
            return AnyShapeStyle(
                LinearGradient(
                    colors: [
                        Color.dynamicSurface(theme: themeManager.currentTheme),
                        accentColor.opacity(0.08)
                    ],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
        }
        return AnyShapeStyle(Color.dynamicSurface(theme: themeManager.currentTheme))
    }

    private var cardBorderColor: Color {
        if isCurrentMeal {
            return accentColor.opacity(0.35)
        }
        return Color.white.opacity(0.08)
    }
}
