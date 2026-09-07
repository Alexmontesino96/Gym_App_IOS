import SwiftUI

// MARK: - Stats Row View
/// Two-column stats: Streak card (left) + Weekly Goal card (right)
struct StatsRowView: View {
    let streak: Int
    let weeklyClasses: Int
    let weeklyGoal: Int
    let activeDaysThisWeek: [Bool] // 7 bools for Mon-Sun

    @EnvironmentObject var themeManager: ThemeManager

    var body: some View {
        HStack(spacing: 10) {
            // Streak card
            streakCard

            // Weekly goal card
            weeklyGoalCard
        }
    }

    // MARK: - Streak Card
    private var streakCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            HStack {
                Text("RACHA")
                    .font(.system(size: 11, weight: .semibold))
                    .tracking(0.8)
                    .foregroundColor(Color.dynamicTextTertiary(theme: themeManager.currentTheme))
                Spacer()
                Image(systemName: "flame.fill")
                    .font(.system(size: 16))
                    .foregroundColor(Color.dynamicAccent(theme: themeManager.currentTheme))
            }

            // Big number
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text("\(streak)")
                    .font(.system(size: 36, weight: .bold, design: .monospaced))
                    .tracking(-1.5)
                    .foregroundColor(Color.dynamicText(theme: themeManager.currentTheme))
                Text("días")
                    .font(.system(size: 13, weight: .regular))
                    .foregroundColor(Color.dynamicTextSecondary(theme: themeManager.currentTheme))
            }

            // 7-day bar visualization
            HStack(spacing: 4) {
                ForEach(0..<7, id: \.self) { index in
                    RoundedRectangle(cornerRadius: 2)
                        .fill(activeDaysThisWeek.indices.contains(index) && activeDaysThisWeek[index]
                              ? Color.dynamicAccent(theme: themeManager.currentTheme)
                              : Color.dynamicSurface2(theme: themeManager.currentTheme))
                        .frame(height: 4)
                }
            }
        }
        .padding(16)
        .background(Color.dynamicSurface(theme: themeManager.currentTheme))
        .clipShape(RoundedRectangle(cornerRadius: 22))
        .overlay(
            RoundedRectangle(cornerRadius: 22)
                .stroke(Color.dynamicBorder(theme: themeManager.currentTheme).opacity(0.15), lineWidth: 1)
        )
    }

    // MARK: - Weekly Goal Card
    private var weeklyGoalCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            HStack {
                Text("OBJETIVO SEMANAL")
                    .font(.system(size: 11, weight: .semibold))
                    .tracking(0.8)
                    .foregroundColor(Color.dynamicTextTertiary(theme: themeManager.currentTheme))
                Spacer()
                Image(systemName: "target")
                    .font(.system(size: 16))
                    .foregroundColor(Color.dynamicTextTertiary(theme: themeManager.currentTheme))
            }

            // Big number
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text("\(weeklyClasses)")
                    .font(.system(size: 36, weight: .bold, design: .monospaced))
                    .tracking(-1.5)
                    .foregroundColor(Color.dynamicText(theme: themeManager.currentTheme))
                Text("/ \(weeklyGoal)")
                    .font(.system(size: 13, weight: .regular))
                    .foregroundColor(Color.dynamicTextSecondary(theme: themeManager.currentTheme))
            }

            // Progress bar
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 100)
                        .fill(Color.dynamicSurface2(theme: themeManager.currentTheme))
                        .frame(height: 4)

                    RoundedRectangle(cornerRadius: 100)
                        .fill(Color.dynamicAccent(theme: themeManager.currentTheme))
                        .frame(width: geometry.size.width * progressFraction, height: 4)
                        .animation(.easeOut(duration: 0.4), value: weeklyClasses)
                }
            }
            .frame(height: 4)
        }
        .padding(16)
        .background(Color.dynamicSurface(theme: themeManager.currentTheme))
        .clipShape(RoundedRectangle(cornerRadius: 22))
        .overlay(
            RoundedRectangle(cornerRadius: 22)
                .stroke(Color.dynamicBorder(theme: themeManager.currentTheme).opacity(0.15), lineWidth: 1)
        )
    }

    private var progressFraction: CGFloat {
        guard weeklyGoal > 0 else { return 0 }
        return min(CGFloat(weeklyClasses) / CGFloat(weeklyGoal), 1.0)
    }
}
