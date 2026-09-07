import SwiftUI

// MARK: - PlanProgressBar
/// Segmented progress bar showing plan days (past/today/published/future)
/// Matches prototype: 28 segments, 4px height, 2px gap
struct PlanProgressBar: View {
    let totalDays: Int
    let currentDay: Int

    @EnvironmentObject var themeManager: ThemeManager

    private let accentColor = Color(hex: "#D4FF3F")!

    var body: some View {
        GeometryReader { geo in
            let spacing: CGFloat = 2
            let totalSpacing = spacing * CGFloat(totalDays - 1)
            let segmentWidth = (geo.size.width - totalSpacing) / CGFloat(totalDays)

            HStack(spacing: spacing) {
                ForEach(1...totalDays, id: \.self) { day in
                    let status = dayStatus(day: day)
                    RoundedRectangle(cornerRadius: 1)
                        .fill(fillColor(for: status))
                        .opacity(status == .past ? 0.85 : 1)
                        .frame(width: segmentWidth, height: 4)
                        .overlay {
                            if status == .today {
                                RoundedRectangle(cornerRadius: 1)
                                    .stroke(accentColor, lineWidth: 2)
                                    .padding(-1)
                            }
                        }
                }
            }
        }
        .frame(height: 4)
    }

    // MARK: - Day Status

    private enum DayStatus {
        case past, today, published, future
    }

    private func dayStatus(day: Int) -> DayStatus {
        if day < currentDay { return .past }
        if day == currentDay { return .today }
        if day <= currentDay + 1 { return .published }
        return .future
    }

    private func fillColor(for status: DayStatus) -> Color {
        switch status {
        case .past:
            return accentColor
        case .today:
            return Color.dynamicText(theme: themeManager.currentTheme)
        case .published:
            return Color.dynamicText(theme: themeManager.currentTheme).opacity(0.3)
        case .future:
            return Color.dynamicSurface2(theme: themeManager.currentTheme)
        }
    }
}
