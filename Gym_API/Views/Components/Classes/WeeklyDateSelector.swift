import SwiftUI

struct WeeklyDateSelector: View {
    @Binding var selectedDate: Date
    @EnvironmentObject var themeManager: ThemeManager
    @State private var weekDates: [Date] = []
    
    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ForEach(weekDates, id: \.self) { date in
                    DateButton(
                        date: date,
                        isSelected: Calendar.current.isDate(date, inSameDayAs: selectedDate),
                        themeManager: themeManager
                    ) {
                        selectedDate = date
                    }
                }
            }
            .padding(.horizontal, 20)
        }
        .onAppear {
            generateWeekDates()
        }
    }
    
    private func generateWeekDates() {
        let calendar = Calendar.current
        let today = Date()
        var dates: [Date] = []
        
        // Generar 5 días como en el original: Thu, Fri(Today), Sat, Sun, Mon
        for i in -1...3 {
            if let date = calendar.date(byAdding: .day, value: i, to: today) {
                dates.append(date)
            }
        }
        
        weekDates = dates
    }
}

struct DateButton: View {
    let date: Date
    let isSelected: Bool
    let themeManager: ThemeManager
    let action: () -> Void
    
    private var dayFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEE"
        return formatter
    }
    
    private var dayNumberFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateFormat = "d"
        return formatter
    }
    
    private var isToday: Bool {
        Calendar.current.isDateInToday(date)
    }
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Text(dayFormatter.string(from: date).uppercased())
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(textColor)
                
                Text(dayNumberFormatter.string(from: date))
                    .font(.system(size: 16, weight: isSelected ? .bold : .medium))
                    .foregroundColor(textColor)
                
                if isToday {
                    Circle()
                        .fill(dotColor)
                        .frame(width: 4, height: 4)
                } else {
                    Spacer()
                        .frame(height: 4)
                }
            }
            .frame(width: 44, height: 64)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(backgroundColor)
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    private var backgroundColor: Color {
        if isSelected {
            return Color.dynamicAccent(theme: themeManager.currentTheme)
        } else {
            return Color.dynamicSurface(theme: themeManager.currentTheme)
        }
    }
    
    private var textColor: Color {
        if isSelected {
            return .white
        } else {
            return Color.dynamicText(theme: themeManager.currentTheme)
        }
    }
    
    private var dotColor: Color {
        if isSelected {
            return .white
        } else {
            return Color.dynamicAccent(theme: themeManager.currentTheme)
        }
    }
}

#Preview {
    WeeklyDateSelector(selectedDate: .constant(Date()))
        .environmentObject(ThemeManager())
        .padding()
}