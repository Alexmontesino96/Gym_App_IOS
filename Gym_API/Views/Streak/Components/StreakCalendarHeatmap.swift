import SwiftUI

/// GitHub-style activity calendar heatmap for workout streaks
struct StreakCalendarHeatmap: View {
    let activityData: [Date: Int] //  Date -> number of classes
    let theme: ThemeManager.AppTheme

    @State private var selectedDay: Date?
    @State private var showDetail = false
    @State private var animateIn = false

    private let columns = 12 // Last 12 weeks
    private let rows = 7 // Days of week
    private let cellSize: CGFloat = 28
    private let cellSpacing: CGFloat = 4

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("ACTIVIDAD")
                .font(.system(size: 12, weight: .bold))
                .foregroundColor(Color.dynamicTextSecondary(theme: theme))
                .tracking(1)

            VStack(alignment: .leading, spacing: 4) {
                // Day labels
                HStack(spacing: cellSpacing) {
                    // Spacer for week column
                    Text("")
                        .frame(width: 20)

                    ForEach(dayLabels, id: \.self) { day in
                        Text(day)
                            .font(.system(size: 10, weight: .medium))
                            .foregroundColor(Color.dynamicTextSecondary(theme: theme))
                            .frame(width: cellSize)
                    }
                }

                // Heatmap grid
                HStack(alignment: .top, spacing: cellSpacing) {
                    // Week labels (vertical)
                    VStack(alignment: .trailing, spacing: cellSpacing) {
                        ForEach(weekLabels, id: \.self) { week in
                            Text(week)
                                .font(.system(size: 9, weight: .medium))
                                .foregroundColor(Color.dynamicTextSecondary(theme: theme))
                                .frame(height: cellSize)
                        }
                    }
                    .frame(width: 20)

                    // Calendar cells
                    ScrollView(.horizontal, showsIndicators: false) {
                        LazyHGrid(rows: Array(repeating: GridItem(.fixed(cellSize), spacing: cellSpacing), count: rows), spacing: cellSpacing) {
                            ForEach(weekDays, id: \.self) { date in
                                CalendarCell(
                                    date: date,
                                    classCount: activityData[Calendar.current.startOfDay(for: date)] ?? 0,
                                    theme: theme,
                                    isSelected: selectedDay == date,
                                    animateIn: animateIn
                                )
                                .onTapGesture {
                                    selectedDay = date
                                    showDetail = true
                                    let impactFeedback = UIImpactFeedbackGenerator(style: .light)
                                    impactFeedback.impactOccurred()
                                }
                            }
                        }
                        .frame(height: CGFloat(rows) * (cellSize + cellSpacing))
                    }
                }
            }

            // Legend
            HStack(spacing: 8) {
                Text("Menos")
                    .font(.system(size: 10))
                    .foregroundColor(Color.dynamicTextSecondary(theme: theme))

                ForEach(0..<5) { level in
                    RoundedRectangle(cornerRadius: 3)
                        .fill(colorForLevel(level))
                        .frame(width: 12, height: 12)
                }

                Text("Más")
                    .font(.system(size: 10))
                    .foregroundColor(Color.dynamicTextSecondary(theme: theme))
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.dynamicSurface(theme: theme))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Color.dynamicTextSecondary(theme: theme).opacity(0.1), lineWidth: 1)
                )
        )
        .onAppear {
            withAnimation(.easeOut(duration: 0.6)) {
                animateIn = true
            }
        }
        .sheet(isPresented: $showDetail) {
            if let day = selectedDay {
                DayDetailView(
                    date: day,
                    classCount: activityData[Calendar.current.startOfDay(for: day)] ?? 0,
                    theme: theme
                )
                .presentationDetents([.height(200)])
            }
        }
    }

    // MARK: - Computed Properties

    private var dayLabels: [String] {
        ["L", "M", "X", "J", "V", "S", "D"]
    }

    private var weekLabels: [String] {
        ["", "", "Sem", "", "", "", ""]
    }

    private var weekDays: [Date] {
        var days: [Date] = []
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())

        // Generate last 12 weeks (84 days)
        for weekOffset in 0..<columns {
            for dayOffset in 0..<rows {
                if let date = calendar.date(byAdding: .day, value: -(columns - 1 - weekOffset) * 7 + dayOffset, to: today) {
                    days.append(date)
                }
            }
        }

        return days
    }

    private func colorForLevel(_ level: Int) -> Color {
        switch level {
        case 0:
            return theme == .dark
                ? Color(red: 0.2, green: 0.2, blue: 0.2)
                : Color(red: 0.9, green: 0.9, blue: 0.9)
        case 1:
            return Color(red: 0.85, green: 0.2, blue: 0.2).opacity(0.25)
        case 2:
            return Color(red: 0.85, green: 0.2, blue: 0.2).opacity(0.5)
        case 3:
            return Color(red: 0.85, green: 0.2, blue: 0.2).opacity(0.75)
        case 4:
            return Color(red: 0.85, green: 0.2, blue: 0.2)
        default:
            return Color.gray
        }
    }
}

// MARK: - Calendar Cell
private struct CalendarCell: View {
    let date: Date
    let classCount: Int
    let theme: ThemeManager.AppTheme
    let isSelected: Bool
    let animateIn: Bool

    @State private var scale: CGFloat = 0.5

    var body: some View {
        RoundedRectangle(cornerRadius: 4)
            .fill(cellColor)
            .frame(width: 28, height: 28)
            .overlay(
                RoundedRectangle(cornerRadius: 4)
                    .stroke(
                        isSelected
                            ? Color.dynamicAccent(theme: theme)
                            : Color.clear,
                        lineWidth: 2
                    )
            )
            .scaleEffect(animateIn ? 1.0 : scale)
            .onAppear {
                // Staggered animation
                let delay = Double.random(in: 0...0.3)
                withAnimation(.spring(response: 0.4, dampingFraction: 0.7).delay(delay)) {
                    scale = 1.0
                }
            }
    }

    private var cellColor: Color {
        let level: Int
        switch classCount {
        case 0:
            level = 0
        case 1:
            level = 1
        case 2:
            level = 2
        case 3:
            level = 3
        default: // 4+
            level = 4
        }

        switch level {
        case 0:
            return theme == .dark
                ? Color(red: 0.2, green: 0.2, blue: 0.2)
                : Color(red: 0.9, green: 0.9, blue: 0.9)
        case 1:
            return Color(red: 0.85, green: 0.2, blue: 0.2).opacity(0.25)
        case 2:
            return Color(red: 0.85, green: 0.2, blue: 0.2).opacity(0.5)
        case 3:
            return Color(red: 0.85, green: 0.2, blue: 0.2).opacity(0.75)
        case 4:
            return Color(red: 0.85, green: 0.2, blue: 0.2)
        default:
            return Color.gray
        }
    }
}

// MARK: - Day Detail View
private struct DayDetailView: View {
    let date: Date
    let classCount: Int
    let theme: ThemeManager.AppTheme

    var body: some View {
        VStack(spacing: 16) {
            // Date header
            Text(dateString)
                .font(.system(size: 18, weight: .bold))
                .foregroundColor(Color.dynamicText(theme: theme))

            // Activity info
            HStack(spacing: 8) {
                Image(systemName: classCount > 0 ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 24))
                    .foregroundColor(classCount > 0 ? Color.dynamicAccent(theme: theme) : Color.dynamicTextSecondary(theme: theme))

                Text(activityText)
                    .font(.system(size: 16))
                    .foregroundColor(Color.dynamicText(theme: theme))
            }
        }
        .padding()
        .frame(maxWidth: .infinity)
        .background(Color.dynamicBackground(theme: theme))
    }

    private var dateString: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.locale = Locale(identifier: "es_ES")
        return formatter.string(from: date)
    }

    private var activityText: String {
        switch classCount {
        case 0:
            return "Sin actividad"
        case 1:
            return "1 clase"
        default:
            return "\(classCount) clases"
        }
    }
}

// MARK: - Preview
#Preview {
    // Generate mock activity data
    var mockData: [Date: Int] {
        var data: [Date: Int] = [:]
        let calendar = Calendar.current
        let today = Date()

        for dayOffset in 0..<84 {
            if let date = calendar.date(byAdding: .day, value: -dayOffset, to: today) {
                let startOfDay = calendar.startOfDay(for: date)
                // Random activity
                data[startOfDay] = Int.random(in: 0...4)
            }
        }

        return data
    }

    ScrollView {
        StreakCalendarHeatmap(activityData: mockData, theme: .dark)
            .padding()
    }
    .background(Color.dynamicBackground(theme: .dark))
}
