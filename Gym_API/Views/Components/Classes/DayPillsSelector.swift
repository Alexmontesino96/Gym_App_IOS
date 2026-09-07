import SwiftUI

// MARK: - DayPillsSelector
/// Horizontal scrolling day pills matching prototype exactly:
/// minWidth 56, radius 22, day letter (10px) + date number (17px mono bold)
struct DayPillsSelector: View {
    @Binding var selectedDate: Date
    @EnvironmentObject var themeManager: ThemeManager

    private let accentColor = Color(hex: "#D4FF3F")!

    // Show 7 days centered on today (today ±3)
    private var dates: [Date] {
        let calendar = Calendar.current
        let today = Date()
        return (-3...3).compactMap { calendar.date(byAdding: .day, value: $0, to: today) }
    }

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(Array(dates.enumerated()), id: \.offset) { index, date in
                        dayPill(date: date, index: index)
                            .id(index)
                            .onTapGesture {
                                HapticManager.shared.buttonTap()
                                withAnimation(.easeInOut(duration: 0.2)) {
                                    selectedDate = date
                                }
                            }
                    }
                }
                .padding(.horizontal, 20)
            }
            .onAppear {
                // Scroll to today (index 3)
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    withAnimation { proxy.scrollTo(3, anchor: .center) }
                }
            }
        }
    }

    private func dayPill(date: Date, index: Int) -> some View {
        let calendar = Calendar.current
        let isSelected = calendar.isDate(date, inSameDayAs: selectedDate)

        return VStack(spacing: 2) {
            // Day letter
            Text(dayLetter(for: date))
                .font(.system(size: 10, weight: .semibold))
                .tracking(0.6)
                .opacity(0.7)

            // Date number
            Text(dayNumber(for: date))
                .font(.system(size: 17, weight: .bold, design: .monospaced))
        }
        .foregroundColor(isSelected ? Color.accentInk : Color.dynamicText(theme: themeManager.currentTheme))
        .frame(minWidth: 56)
        .padding(.vertical, 10)
        .padding(.horizontal, 4)
        .background(
            isSelected
                ? AnyShapeStyle(accentColor)
                : AnyShapeStyle(Color.dynamicSurface(theme: themeManager.currentTheme))
        )
        .clipShape(RoundedRectangle(cornerRadius: 22))
        .overlay(
            RoundedRectangle(cornerRadius: 22)
                .stroke(
                    isSelected ? Color.clear : Color.white.opacity(0.08),
                    lineWidth: 1
                )
        )
    }

    // MARK: - Helpers

    private func dayLetter(for date: Date) -> String {
        let calendar = Calendar.current
        let weekday = calendar.component(.weekday, from: date)
        // Sunday=1, Monday=2, ..., Saturday=7
        let letters = ["D", "L", "M", "X", "J", "V", "S"]
        return letters[weekday - 1]
    }

    private func dayNumber(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "dd"
        return formatter.string(from: date)
    }
}
