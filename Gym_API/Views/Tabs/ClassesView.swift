import SwiftUI

struct ClassesView: View {
    @EnvironmentObject var authService: AuthServiceDirect
    @EnvironmentObject var classService: ClassService
    @EnvironmentObject var themeManager: ThemeManager
    @EnvironmentObject var attendanceService: AttendanceService
    @StateObject private var gymService = GymService.shared
    @StateObject private var profileService = UserProfileService.shared
    @State private var selectedDate = Date()
    @State private var isRefreshing = false
    @State private var showingCreateSession = false
    @State private var showingQRScanner = false
    @State private var showingClassSelection = false
    @State private var selectedSessionForScanner: SessionWithClass?
    @State private var showError = false
    @State private var errorMessage = ""
    
    // Filtered classes based on selected date
    private var filteredClasses: [GymClass] {
        let calendar = Calendar.current

        // Normalizar las fechas al inicio del día en el timezone local para comparación correcta
        let startOfSelectedDay = calendar.startOfDay(for: selectedDate)
        let endOfSelectedDay = calendar.date(byAdding: .day, value: 1, to: startOfSelectedDay) ?? selectedDate

        let filtered = classService.classes.filter { gymClass in
            // Verificar si la clase cae dentro del día seleccionado
            let classStartTime = gymClass.startTime
            return classStartTime >= startOfSelectedDay && classStartTime < endOfSelectedDay
        }

        // Debug logging mejorado
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm"
        formatter.timeZone = TimeZone.current
        print("🔍 [ClassesView] Filtrado de clases:")
        print("   - Total sesiones: \(classService.sessions.count)")
        print("   - Total clases convertidas: \(classService.classes.count)")
        print("   - Fecha seleccionada: \(formatter.string(from: selectedDate))")
        print("   - Inicio del día: \(formatter.string(from: startOfSelectedDay))")
        print("   - Fin del día: \(formatter.string(from: endOfSelectedDay))")
        print("   - Clases filtradas: \(filtered.count)")
        for gymClass in classService.classes.prefix(5) {
            let inRange = gymClass.startTime >= startOfSelectedDay && gymClass.startTime < endOfSelectedDay
            print("   - Clase '\(gymClass.name)' - Start: \(formatter.string(from: gymClass.startTime)) - InRange: \(inRange)")
        }

        return filtered
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

                        // QR Scanner button (solo para ADMIN/TRAINER/OWNER)
                        if RolePermissions.canScanQRCheckIn(gymService.currentGym?.userRoleInGym) {
                            Button(action: handleScannerButtonTap) {
                                Image(systemName: "qrcode.viewfinder")
                                    .font(.system(size: 24, weight: .semibold))
                                    .foregroundColor(Color.dynamicAccent(theme: themeManager.currentTheme))
                            }
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 8)
                    // Weekly Date Selector
                    WeeklyDateSelector(selectedDate: $selectedDate)
                    .padding(.bottom, 16)
                    .background(Color.dynamicCard(theme: themeManager.currentTheme))
                    
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
                            // Using modern design with coach photos
                            ScrollView {
                                LazyVStack(spacing: 16) {
                                    ForEach(filteredClasses) { gymClass in
                                        ModernClassCardView(gymClass: gymClass)
                                            .environmentObject(themeManager)
                                            .environmentObject(classService)
                                            .environmentObject(gymService)
                                    }
                                }
                                .padding(.horizontal, 16)
                                .padding(.vertical, 12)
                            }
                            .refreshable {
                                await refreshClasses()
                            }
                        }
                        
                        // Floating Action Button (solo para crear sesión)
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
                // Configurar el authService en el classService para operaciones de sesiones
                classService.authService = authService

                // Cargar trainers primero para que estén disponibles para las tarjetas
                await classService.loadTrainers()

                // SIEMPRE cargar sesiones para la fecha actual seleccionada
                // Esto asegura que tengamos las clases correctas al abrir la vista
                await classService.loadSessionsForDateIfNeeded(date: selectedDate)

                await classService.fetchMyClasses() // Cargar estado de registro del usuario

                // Si no hay clases para la fecha actual, seleccionar automáticamente
                // la primera fecha que tenga clases disponibles
                await MainActor.run {
                    if filteredClasses.isEmpty && !classService.classes.isEmpty {
                        // Buscar la primera fecha con clases disponibles
                        let calendar = Calendar.current
                        let sortedClasses = classService.classes.sorted { $0.startTime < $1.startTime }

                        if let firstClass = sortedClasses.first {
                            // Seleccionar el día de la primera clase disponible
                            selectedDate = calendar.startOfDay(for: firstClass.startTime)
                            print("📅 [ClassesView] Auto-seleccionando fecha con clases: \(selectedDate)")
                        }
                    }
                }
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
        .fullScreenCover(isPresented: $showingQRScanner) {
            QRScannerView(preSelectedSession: selectedSessionForScanner)
                .environmentObject(attendanceService)
                .environmentObject(classService)
                .environmentObject(themeManager)
                .environmentObject(authService)
                .onDisappear {
                    selectedSessionForScanner = nil
                }
        }
        .sheet(isPresented: $showingClassSelection) {
            ClassSelectionSheet(
                sessions: attendanceService.availableSessions,
                onSessionSelected: { session in
                    selectedSessionForScanner = session
                    showingClassSelection = false
                    showingQRScanner = true
                },
                onCancel: {
                    showingClassSelection = false
                }
            )
            .environmentObject(themeManager)
        }
        .alert("Error", isPresented: $showError) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(errorMessage)
        }
    }

    // MARK: - Scanner Button Handler

    private func handleScannerButtonTap() {
        Task {
            await attendanceService.getAvailableSessionsForCheckIn()

            let sessionCount = attendanceService.availableSessions.count

            if sessionCount == 0 {
                errorMessage = "No hay clases disponibles para check-in en este momento"
                showError = true
            } else if sessionCount >= 3 {
                // 3+ clases: Mostrar selector PRIMERO
                showingClassSelection = true
            } else {
                // 1-2 clases: Abrir scanner directamente
                showingQRScanner = true
            }
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
        .environmentObject(ServiceContainer.shared.attendanceService)
        .environmentObject(ThemeManager())
}
