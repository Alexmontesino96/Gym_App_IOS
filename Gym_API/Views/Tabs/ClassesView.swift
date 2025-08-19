import SwiftUI

struct ClassesView: View {
    @EnvironmentObject var authService: AuthServiceDirect
    @EnvironmentObject var classService: ClassService
    @EnvironmentObject var themeManager: ThemeManager
    @StateObject private var gymService = GymService.shared
    @State private var selectedDate = Date()
    @State private var isRefreshing = false
    @State private var showingCreateSession = false
    
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
                    // Consistent header title
                    HStack {
                        Text("Classes")
                            .font(.system(size: 28, weight: .bold))
                            .foregroundColor(Color.dynamicText(theme: themeManager.currentTheme))
                        Spacer()
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 8)
                    // Weekly Date Selector
                    WeeklyDateSelector(selectedDate: $selectedDate)
                    .padding(.bottom, 16)
                    .background(Color.dynamicBackground(theme: themeManager.currentTheme))
                    
                    // Classes Content with FAB overlay
                    ZStack {
                        if classService.isLoading && !isRefreshing {
                            VStack {
                                Spacer()
                                ProgressView("Loading classes...")
                                    .font(.system(size: 16, weight: .medium))
                                    .foregroundColor(Color.dynamicText(theme: themeManager.currentTheme))
                                Spacer()
                            }
                        } else if filteredClasses.isEmpty {
                            VStack {
                                Spacer()
                                VStack(spacing: 16) {
                                    if isRefreshing {
                                        ProgressView()
                                            .scaleEffect(1.2)
                                            .padding(.bottom, 8)
                                        
                                        Text("Refreshing classes...")
                                            .font(.system(size: 16, weight: .medium))
                                            .foregroundColor(Color.dynamicText(theme: themeManager.currentTheme))
                                    } else {
                                        Image(systemName: "calendar.badge.exclamationmark")
                                            .font(.system(size: 48))
                                            .foregroundColor(Color.dynamicTextSecondary(theme: themeManager.currentTheme))
                                        
                                        Text("No classes available")
                                            .font(.system(size: 18, weight: .medium))
                                            .foregroundColor(Color.dynamicTextSecondary(theme: themeManager.currentTheme))
                                        
                                        Text("for \(formatSelectedDate())")
                                            .font(.system(size: 16, weight: .medium))
                                            .foregroundColor(Color.dynamicAccent(theme: themeManager.currentTheme))
                                        
                                        Text("Try selecting a different date or pull to refresh")
                                            .font(.system(size: 14))
                                            .foregroundColor(Color.dynamicTextSecondary(theme: themeManager.currentTheme).opacity(0.7))
                                    }
                                }
                                Spacer()
                            }
                            .refreshable {
                                await refreshClasses()
                            }
                        } else {
                            ScrollView {
                                LazyVStack(spacing: 16) {
                                    ForEach(filteredClasses) { gymClass in
                                        ClassCardView(gymClass: gymClass)
                                            .padding(.horizontal, 20)
                                    }
                                }
                                .padding(.vertical, 20)
                                
                                Spacer(minLength: 100)
                            }
                            .refreshable {
                                await refreshClasses()
                            }
                        }
                        
                        // Floating Action Button (always visible for admins and owners)
                        if RolePermissions.canCreateSessions(gymService.currentGym?.userRoleInGym) {
                            FABContainer(position: .bottomTrailing) {
                                FloatingActionButton(
                                    icon: "plus",
                                    themeManager: themeManager
                                ) {
                                    showingCreateSession = true
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .safeAreaPadding(.top, 16)
        }
        .onAppear {
            Task {
                // Cargar trainers primero para que estén disponibles para las tarjetas
                await classService.loadTrainers()
                await classService.loadSessionsForDateIfNeeded(date: selectedDate)
                await classService.fetchMyClasses() // Cargar estado de registro del usuario
            }
        }
        .onChange(of: selectedDate) { _, newDate in
            Task {
                await classService.loadSessionsForDateIfNeeded(date: newDate)
            }
        }
        .sheet(isPresented: $showingCreateSession) {
            CreateSessionView()
                .environmentObject(themeManager)
                .environmentObject(authService)
                .environmentObject(classService)
        }
    }
    
    // MARK: - Refresh Function
    private func refreshClasses() async {
        await MainActor.run {
            isRefreshing = true
        }
        
        // Forzar recarga de clases para la fecha seleccionada
        await classService.forceRefreshSessions(date: selectedDate)
        // Recargar el estado de registro del usuario  
        await classService.forceRefreshMyClasses()
        // Recargar trainers por si hubo cambios - forzar recarga en refresh
        await classService.forceReloadTrainers()
        
        // Pequeño delay para asegurar que las imágenes se actualicen después del refresh
        try? await Task.sleep(nanoseconds: 100_000_000) // 0.1 segundos
        
        await MainActor.run {
            isRefreshing = false
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
