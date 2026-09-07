import SwiftUI

// MARK: - Weekly Activity Chart
/// Bar chart showing daily calorie burn for the current week with trend indicator
struct WeeklyActivityChart: View {
    let dailyData: [DayActivity] // 7 items, Mon-Sun
    let totalKcal: Int
    let trendPercentage: Int? // e.g., +18

    @EnvironmentObject var themeManager: ThemeManager

    struct DayActivity: Identifiable {
        let id = UUID()
        let dayLabel: String // L, M, X, J, V, S, D
        let kcal: Int
        let value: CGFloat // 0.0 to 1.0 normalized
    }

    private var peakIndex: Int? {
        guard let maxVal = dailyData.map(\.value).max(), maxVal > 0 else { return nil }
        return dailyData.firstIndex(where: { $0.value == maxVal })
    }

    var body: some View {
        VStack(spacing: 16) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("ESTA SEMANA")
                        .font(.system(size: 11, weight: .semibold))
                        .tracking(0.8)
                        .foregroundColor(Color.dynamicTextTertiary(theme: themeManager.currentTheme))

                    HStack(alignment: .firstTextBaseline, spacing: 6) {
                        Text(formattedKcal)
                            .font(.system(size: 26, weight: .bold, design: .monospaced))
                            .tracking(-0.8)
                            .foregroundColor(Color.dynamicText(theme: themeManager.currentTheme))
                        Text("kcal")
                            .font(.system(size: 13, weight: .regular))
                            .foregroundColor(Color.dynamicTextSecondary(theme: themeManager.currentTheme))
                    }
                }

                Spacer()

                // Trend chip
                if let trend = trendPercentage, trend != 0 {
                    HStack(spacing: 4) {
                        Image(systemName: trend > 0 ? "arrow.up.right" : "arrow.down.right")
                            .font(.system(size: 12, weight: .semibold))
                        Text("\(trend > 0 ? "+" : "")\(trend)%")
                            .font(.system(size: 13, weight: .semibold))
                    }
                    .foregroundColor(Color.successGreen)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(
                        Capsule()
                            .stroke(Color.successGreen.opacity(0.3), lineWidth: 1)
                    )
                }
            }

            // Bars
            HStack(alignment: .bottom, spacing: 8) {
                ForEach(Array(dailyData.enumerated()), id: \.element.id) { index, day in
                    VStack(spacing: 8) {
                        ZStack(alignment: .top) {
                            // Bar
                            RoundedRectangle(cornerRadius: 6)
                                .fill(day.value > 0
                                      ? Color.dynamicAccent(theme: themeManager.currentTheme)
                                      : Color.dynamicSurface2(theme: themeManager.currentTheme))
                                .frame(height: max(CGFloat(day.value) * 80, 4))

                            // Tooltip on peak day
                            if index == peakIndex && day.kcal > 0 {
                                Text("\(day.kcal)")
                                    .font(.system(size: 10, weight: .semibold, design: .monospaced))
                                    .foregroundColor(Color.dynamicBackground(theme: themeManager.currentTheme))
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(Color.dynamicText(theme: themeManager.currentTheme))
                                    .clipShape(RoundedRectangle(cornerRadius: 4))
                                    .offset(y: -22)
                            }
                        }
                        .frame(maxWidth: 28)

                        // Day label
                        Text(day.dayLabel)
                            .font(.system(size: 10, weight: .medium))
                            .foregroundColor(Color.dynamicTextTertiary(theme: themeManager.currentTheme))
                    }
                    .frame(maxWidth: .infinity)
                }
            }
            .frame(height: 100)
        }
        .padding(18)
        .background(Color.dynamicSurface(theme: themeManager.currentTheme))
        .clipShape(RoundedRectangle(cornerRadius: 22))
        .overlay(
            RoundedRectangle(cornerRadius: 22)
                .stroke(Color.dynamicBorder(theme: themeManager.currentTheme).opacity(0.15), lineWidth: 1)
        )
    }

    private var formattedKcal: String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.groupingSeparator = ","
        return formatter.string(from: NSNumber(value: totalKcal)) ?? "\(totalKcal)"
    }
}
