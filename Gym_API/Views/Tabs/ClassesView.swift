import SwiftUI

struct ClassesView: View {
    @EnvironmentObject var authService: AuthServiceDirect
    @EnvironmentObject var classService: ClassService
    @EnvironmentObject var themeManager: ThemeManager
    @State private var selectedDate = Date()
    
    // Filtered classes based on selected date
    private var filteredClasses: [GymClass] {
        let calendar = Calendar.current
        return classService.classes.filter { gymClass in
            calendar.isDate(gymClass.startTime, inSameDayAs: selectedDate)
        }
    }
    
    var body: some View {
        NavigationView {
            ZStack {
                Color.dynamicBackground(theme: themeManager.currentTheme).ignoresSafeArea()
                
                VStack(spacing: 0) {
                    // Weekly Date Selector
                    VStack(spacing: 16) {
                        HStack {
                            Text("Select Date")
                                .font(.system(size: 18, weight: .semibold))
                                .foregroundColor(Color.dynamicText(theme: themeManager.currentTheme))
                            
                            Spacer()
                            
                            Button(action: {
                                selectedDate = Date()
                                Task {
                                    await classService.loadSessionsForDateIfNeeded(date: selectedDate)
                                }
                            }) {
                                Text("Today")
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundColor(Color.dynamicAccent(theme: themeManager.currentTheme))
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 6)
                                    .background(
                                        RoundedRectangle(cornerRadius: 8)
                                            .stroke(Color.dynamicAccent(theme: themeManager.currentTheme), lineWidth: 1)
                                    )
                            }
                        }
                        .padding(.horizontal, 20)
                        
                        WeeklyDateSelector(selectedDate: $selectedDate)
                    }
                    .padding(.top, 10)
                    .padding(.bottom, 16)
                    .background(Color.dynamicBackground(theme: themeManager.currentTheme))
                    
                    // Classes Content
                    if classService.isLoading {
                        Spacer()
                        ProgressView("Loading classes...")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(Color.dynamicText(theme: themeManager.currentTheme))
                        Spacer()
                    } else if filteredClasses.isEmpty {
                        Spacer()
                        VStack(spacing: 16) {
                            Image(systemName: "calendar.badge.exclamationmark")
                                .font(.system(size: 48))
                                .foregroundColor(Color.dynamicTextSecondary(theme: themeManager.currentTheme))
                            
                            Text("No classes available")
                                .font(.system(size: 18, weight: .medium))
                                .foregroundColor(Color.dynamicTextSecondary(theme: themeManager.currentTheme))
                            
                            Text("for \(formatSelectedDate())")
                                .font(.system(size: 16, weight: .medium))
                                .foregroundColor(Color.dynamicAccent(theme: themeManager.currentTheme))
                            
                            Text("Try selecting a different date")
                                .font(.system(size: 14))
                                .foregroundColor(Color.dynamicTextSecondary(theme: themeManager.currentTheme).opacity(0.7))
                        }
                        Spacer()
                    } else {
                        ScrollView {
                            LazyVStack(spacing: 16) {
                                ForEach(filteredClasses) { gymClass in
                                    ClassCardView(gymClass: gymClass)
                                        .padding(.horizontal, 20)
                                }
                            }
                            .padding(.vertical, 20)
                        }
                    }
                }
            }
            .navigationTitle("Classes")
            .navigationBarTitleDisplayMode(.large)
        }
        .onAppear {
            Task {
                await classService.loadSessionsForDateIfNeeded(date: selectedDate)
            }
        }
        .onChange(of: selectedDate) { _, newDate in
            Task {
                await classService.loadSessionsForDateIfNeeded(date: newDate)
            }
        }
    }
    
    private func formatSelectedDate() -> String {
        let formatter = DateFormatter()
        let calendar = Calendar.current
        
        if calendar.isDateInToday(selectedDate) {
            return "today"
        } else if calendar.isDateInTomorrow(selectedDate) {
            return "tomorrow"
        } else {
            formatter.dateFormat = "EEEE, MMM d"
            return formatter.string(from: selectedDate)
        }
    }
}

#Preview {
    ClassesView()
        .environmentObject(AuthServiceDirect())
        .environmentObject(ClassService())
        .environmentObject(ThemeManager())
}