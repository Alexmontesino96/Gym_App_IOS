import SwiftUI

struct MainTabView: View {
    @EnvironmentObject var authService: AuthServiceDirect
    @EnvironmentObject var themeManager: ThemeManager
    @State private var selectedTab = 0
    @State private var showThemeChangeConfirmation = false
    @State private var pendingTheme: ThemeManager.AppTheme?
    @State private var showWelcomeAnimation = false
    @StateObject private var userStatsService = UserStatsService.shared
    @StateObject private var unreadCountService = UnreadCountService.shared
    
    var body: some View {
        ZStack {
            TabView(selection: $selectedTab) {
            // Home Tab
            AnimatedTabContent(isSelected: selectedTab == 0) {
                HomeView()
            }
            .tabItem {
                Image(systemName: selectedTab == 0 ? "house.fill" : "house")
                Text("Home")
            }
            .tag(0)

            // Classes Tab
            AnimatedTabContent(isSelected: selectedTab == 1) {
                ClassesView()
            }
            .tabItem {
                Image(systemName: selectedTab == 1 ? "dumbbell.fill" : "dumbbell")
                Text("Classes")
            }
            .tag(1)

            // Events Tab
            AnimatedTabContent(isSelected: selectedTab == 2) {
                EventsView()
            }
            .tabItem {
                Image(systemName: selectedTab == 2 ? "calendar.circle.fill" : "calendar.circle")
                Text("Events")
            }
            .tag(2)

            // Social Tab (Messages + Feed)
            AnimatedTabContent(isSelected: selectedTab == 3) {
                SocialFeedView()
            }
            .tabItem {
                Image(systemName: selectedTab == 3 ? "message.fill" : "message")
                Text("Social")
            }
            .badge(unreadCountService.totalUnreadCount > 0 ? unreadCountService.totalUnreadCount : 0)
            .tag(3)

            // Profile Tab
            AnimatedTabContent(isSelected: selectedTab == 4) {
                ModernProfileView()
            }
            .tabItem {
                Image(systemName: selectedTab == 4 ? "person.fill" : "person")
                Text("Profile")
            }
            .tag(4)
            }
            .accentColor(themeManager.currentTheme == .dark ?
                        Color(red: 0.85, green: 0.2, blue: 0.2) :
                        Color(red: 61.0/255.0, green: 190.0/255.0, blue: 208.0/255.0))
            .onChange(of: selectedTab) { oldValue, newValue in
                // Haptic feedback al cambiar de tab
                let impact = UIImpactFeedbackGenerator(style: .light)
                impact.impactOccurred()

                // Precargar siguiente tab probable en background
                Task {
                    await PreloadService.shared.preloadNextProbableTab(from: newValue)
                }
            }

            // Notification Overlay - Siempre encima de todo
            NotificationOverlay(selectedTab: selectedTab)
            
            // Welcome Animation Overlay
            if showWelcomeAnimation {
                WelcomeAnimationOverlay(
                    isVisible: $showWelcomeAnimation,
                    userStatsService: userStatsService,
                    authService: authService
                )
                .environmentObject(themeManager)
                .environmentObject(authService)
                .transition(.opacity)
                .zIndex(100)
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .openProfileTab)) { _ in
            selectedTab = 4
        }
        .onReceive(NotificationCenter.default.publisher(for: .openClassesTab)) { _ in
            selectedTab = 1
        }
        .onAppear {
            configureTabBarAppearance()
            checkAndShowWelcomeAnimation()
        }
        .onChange(of: themeManager.currentTheme) { _, newTheme in
            debugLog("🔄 Tema cambió a: \(newTheme.rawValue)")
            configureTabBarAppearance()
            
            // Forzar actualización inmediata
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                forceTabBarUpdate()
            }
        }
        .alert("Cambio de tema", isPresented: $showThemeChangeConfirmation) {
            Button("Apply theme") {
                if let newTheme = pendingTheme {
                    themeManager.setTheme(newTheme)
                    debugLog("🔄 Tema cambiado a: \(newTheme.rawValue) y guardado")
                    pendingTheme = nil
                }
            }
            
            Button("Cancel", role: .cancel) {
                pendingTheme = nil
            }
        } message: {
            if let newTheme = pendingTheme {
                Text("Se aplicará el tema \(newTheme == .dark ? "oscuro" : "claro") sin reiniciar.")
            }
        }
    }
    
    // MARK: - Private Methods
    
    private func checkAndShowWelcomeAnimation() {
        // Check if we should show the welcome animation
        let defaults = UserDefaults.standard
        let lastWelcomeKey = "lastWelcomeAnimationDate"
        
        // Get last shown date
        let lastShownDate = defaults.object(forKey: lastWelcomeKey) as? Date ?? Date.distantPast
        
        // Check if it's a new day
        let calendar = Calendar.current
        let isNewDay = !calendar.isDateInToday(lastShownDate)
        
        // Show animation only once per day
        if isNewDay {
            // Setup services
            userStatsService.authService = authService
            
            // Load stats first
            Task {
                await userStatsService.fetchComprehensiveStats()
                
                // Show animation after a small delay
                await MainActor.run {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    withAnimation(.easeIn(duration: 0.3)) {
                        showWelcomeAnimation = true
                    }
                    
                    // Update last shown date
                    defaults.set(Date(), forKey: lastWelcomeKey)
                    }
                }
            }
        }
    }
    
    private func configureTabBarAppearance() {
        debugLog("🎨 Configurando TabBar para tema: \(themeManager.currentTheme.rawValue)")
        
        // Crear una nueva instancia de apariencia
        let appearance = UITabBarAppearance()
        
        // Colores del TabBar según el tema
        let backgroundColor: UIColor
        let normalIconColor: UIColor   // Color para iconos no seleccionados
        let selectedIconColor: UIColor // Color para iconos seleccionados
        
        if themeManager.currentTheme == .dark {
            // MODO OSCURO: fondo oscuro, iconos normales CLAROS, seleccionados ROJOS
            backgroundColor = UIColor(red: 0.05, green: 0.05, blue: 0.05, alpha: 1.0) // #0D0D0D
            normalIconColor = UIColor(red: 0.7, green: 0.7, blue: 0.7, alpha: 1.0)    // Gris claro
            selectedIconColor = UIColor(red: 0.85, green: 0.2, blue: 0.2, alpha: 1.0) // Rojo
        } else {
            // MODO CLARO: fondo claro, iconos normales OSCUROS, seleccionados AZUL TURQUESA
            backgroundColor = UIColor(red: 0.98, green: 0.98, blue: 0.98, alpha: 1.0) // #FAFAFA
            normalIconColor = UIColor(red: 0.4, green: 0.4, blue: 0.4, alpha: 1.0)    // Gris oscuro
            selectedIconColor = UIColor(red: 61.0/255.0, green: 190.0/255.0, blue: 208.0/255.0, alpha: 1.0) // Turquesa
        }
        
        // Configurar el fondo
        appearance.configureWithDefaultBackground()
        appearance.backgroundColor = backgroundColor
        
        // Configuración para TODOS los layouts con los mismos colores
        // Layout apilado (estándar en dispositivos con botón home)
        appearance.stackedLayoutAppearance.normal.iconColor = normalIconColor
        appearance.stackedLayoutAppearance.normal.titleTextAttributes = [
            .foregroundColor: normalIconColor
        ]
        appearance.stackedLayoutAppearance.selected.iconColor = selectedIconColor
        appearance.stackedLayoutAppearance.selected.titleTextAttributes = [
            .foregroundColor: selectedIconColor
        ]
        
        // Layout inline (para dispositivos con pantalla más pequeña)
        appearance.inlineLayoutAppearance.normal.iconColor = normalIconColor
        appearance.inlineLayoutAppearance.normal.titleTextAttributes = [
            .foregroundColor: normalIconColor
        ]
        appearance.inlineLayoutAppearance.selected.iconColor = selectedIconColor
        appearance.inlineLayoutAppearance.selected.titleTextAttributes = [
            .foregroundColor: selectedIconColor
        ]
        
        // Layout compacto (iPad y dispositivos grandes en landscape)
        appearance.compactInlineLayoutAppearance.normal.iconColor = normalIconColor
        appearance.compactInlineLayoutAppearance.normal.titleTextAttributes = [
            .foregroundColor: normalIconColor
        ]
        appearance.compactInlineLayoutAppearance.selected.iconColor = selectedIconColor
        appearance.compactInlineLayoutAppearance.selected.titleTextAttributes = [
            .foregroundColor: selectedIconColor
        ]
        
        // Aplicar la apariencia
        UITabBar.appearance().standardAppearance = appearance
        UITabBar.appearance().scrollEdgeAppearance = appearance
        
        debugLog("   🎨 TabBar configurado:")
        debugLog("   🎨 - Fondo: \(backgroundColor)")
        debugLog("   🎨 - Iconos normales: \(normalIconColor)")
        debugLog("   🎨 - Iconos seleccionados: \(selectedIconColor)")
    }
    
    private func forceTabBarUpdate() {
        DispatchQueue.main.async {
            // Forzar recreación de la apariencia
            let currentTheme = themeManager.currentTheme
            debugLog("   🎨 Forzando para tema: \(currentTheme.rawValue)")
            
            // Obtener todas las instancias de UITabBar y forzar actualización
            UIApplication.shared.connectedScenes
                .compactMap { $0 as? UIWindowScene }
                .flatMap { $0.windows }
                .forEach { window in
                    window.rootViewController?.view.subviews
                        .compactMap { $0 as? UITabBar }
                        .forEach { tabBar in
                            tabBar.setNeedsLayout()
                            tabBar.layoutIfNeeded()
                        }
                }
            
            debugLog("   ✅ TabBar forzado exitosamente")
        }
    }
    
    // Función para iniciar el proceso de cambio de tema
    private func requestThemeChange() {
        let newTheme: ThemeManager.AppTheme = themeManager.currentTheme == .dark ? .light : .dark
        pendingTheme = newTheme
        showThemeChangeConfirmation = true
    }
    
    // Función para reiniciar la aplicización
    // Restart removed; theme applies dynamically without exiting the app.
    private func restartApp() {
        debugLog("🔄 Reinicio eliminado; el tema se actualiza dinámicamente")
    }
}

#Preview {
    MainTabView()
        .environmentObject(AuthServiceDirect())
        .environmentObject(ThemeManager())
        .environmentObject(ColorCustomizationManager.shared)
        .environmentObject(UserStatsService.shared)
} 
