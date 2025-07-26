import SwiftUI

struct WeeklyDateSelector: View {
    @Binding var selectedDate: Date
    
    var body: some View {
        DateSelectorView(selectedDate: $selectedDate)
    }
}

struct DateSelectorView: View {
    @Binding var selectedDate: Date
    
    var body: some View {
        ScrollViewReader { proxy in
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 16) {
                    ForEach(Array(dateRange.enumerated()), id: \.offset) { index, date in
                        DateTabView(
                            date: date,
                            isSelected: Calendar.current.isDate(date, inSameDayAs: selectedDate),
                            isToday: Calendar.current.isDateInToday(date)
                        )
                        .id(index)
                        .onTapGesture {
                            selectedDate = date
                        }
                    }
                }
                .padding(.horizontal, 20)
            }
            .onAppear {
                // El índice 7 corresponde al día 0 (hoy) en el rango -7...7
                // Rango: [-7, -6, -5, -4, -3, -2, -1, 0, 1, 2, 3, 4, 5, 6, 7]
                // Índice:[ 0,  1,  2,  3,  4,  5,  6, 7, 8, 9,10,11,12,13,14]
                let todayIndex = 7
                
                // Primer intento inmediato
                DispatchQueue.main.async {
                    proxy.scrollTo(todayIndex, anchor: .center)
                }
                
                // Segundo intento con delay para asegurar el posicionamiento
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        proxy.scrollTo(todayIndex, anchor: .center)
                    }
                }
            }
        }
    }
    
    private var dateRange: [Date] {
        let calendar = Calendar.current
        let today = Date()
        var dates: [Date] = []
        
        // Mostrar desde 7 días atrás hasta 7 días adelante (15 días total)
        for i in -7...7 {
            if let date = calendar.date(byAdding: .day, value: i, to: today) {
                dates.append(date)
            }
        }
        
        return dates
    }
}

struct DateTabView: View {
    @EnvironmentObject var themeManager: ThemeManager
    let date: Date
    let isSelected: Bool
    let isToday: Bool
    
    var body: some View {
        VStack(spacing: 4) {
            Text(dayName)
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(isSelected ? .white : Color.dynamicTextSecondary(theme: themeManager.currentTheme))
            
            Text(dayNumber)
                .font(.system(size: 18, weight: .bold))
                .foregroundColor(isSelected ? .white : Color.dynamicTextSecondary(theme: themeManager.currentTheme))
        }
        .frame(width: 60, height: 60)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(isSelected ? Color.dynamicAccent(theme: themeManager.currentTheme) : Color.clear)
                .overlay(
                    // Marco para el día de hoy (siempre visible)
                    isToday && !isSelected ? 
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.dynamicAccent(theme: themeManager.currentTheme), lineWidth: 2) : nil
                )
        )
    }
    
    private var dayName: String {
        let formatter = DateFormatter()
        if Calendar.current.isDateInToday(date) {
            return "Today"
        } else {
            formatter.dateFormat = "EEE"
            return formatter.string(from: date)
        }
    }
    
    private var dayNumber: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "dd"
        return formatter.string(from: date)
    }
}

#Preview {
    WeeklyDateSelector(selectedDate: .constant(Date()))
        .environmentObject(ThemeManager())
        .padding()
}