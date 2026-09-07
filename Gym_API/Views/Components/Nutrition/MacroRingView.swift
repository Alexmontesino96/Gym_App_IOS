import SwiftUI

// MARK: - MacroRingView
/// Circular ring showing macro progress (protein, carbs, fat)
/// Matches prototype: size 70, stroke 4, center value + label
struct MacroRingView: View {
    let value: Int
    let target: Int
    let color: Color
    let label: String
    let unit: String
    var size: CGFloat = 70

    @EnvironmentObject var themeManager: ThemeManager

    private var percentage: CGFloat {
        guard target > 0 else { return 0 }
        return min(CGFloat(value) / CGFloat(target), 1.0)
    }

    var body: some View {
        ZStack {
            // Background ring
            Circle()
                .stroke(
                    Color.dynamicSurface2(theme: themeManager.currentTheme),
                    lineWidth: 4
                )

            // Progress ring
            Circle()
                .trim(from: 0, to: percentage)
                .stroke(
                    color,
                    style: StrokeStyle(lineWidth: 4, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
                .animation(.easeOut(duration: 0.6), value: percentage)

            // Center content
            VStack(spacing: 2) {
                HStack(spacing: 0) {
                    Text("\(value)")
                        .font(.system(size: 15, weight: .bold, design: .monospaced))
                        .tracking(-0.3)
                    Text(unit)
                        .font(.system(size: 9, weight: .medium, design: .monospaced))
                        .foregroundColor(Color.dynamicText(theme: themeManager.currentTheme).opacity(0.45))
                }

                Text(label.uppercased())
                    .font(.system(size: 8, weight: .medium))
                    .tracking(0.5)
                    .foregroundColor(Color.dynamicText(theme: themeManager.currentTheme).opacity(0.45))
            }
        }
        .frame(width: size, height: size)
    }
}
