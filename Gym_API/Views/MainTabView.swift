import SwiftUI

struct MainTabView: View {
    @EnvironmentObject var authService: AuthServiceDirect
    @EnvironmentObject var themeManager: ThemeManager
    @State private var selectedTab = 0
    @State private var showThemeChangeConfirmation = false
    @State private var pendingTheme: ThemeManager.AppTheme?
    
    var body: some View {
        TabView(selection: $selectedTab) {
            // Home Tab
            HomeView()
                .tabItem {
                    Image(systemName: selectedTab == 0 ? "house.fill" : "house")
                    Text("Home")
                }
                .tag(0)
            
            // Classes Tab
            ClassesView()
                .tabItem {
                    Image(systemName: selectedTab == 1 ? "dumbbell.fill" : "dumbbell")
                    Text("Classes")
                }
                .tag(1)
            
            // Events Tab
            EventsView()
                .tabItem {
                    Image(systemName: selectedTab == 2 ? "calendar.circle.fill" : "calendar.circle")
                    Text("Events")
                }
                .tag(2)
            
            // Messages Tab
            MessagesView()
                .tabItem {
                    Image(systemName: selectedTab == 3 ? "message.fill" : "message")
                    Text("Messages")
                }
                .tag(3)
            
            // Profile Tab
            EnhancedProfileView(onThemeChangeRequest: requestThemeChange)
                .tabItem {
                    Image(systemName: selectedTab == 4 ? "person.fill" : "person")
                    Text("Profile")
                }
                .tag(4)
        }
        .accentColor(themeManager.currentTheme == .dark ? 
                    Color(red: 0.85, green: 0.2, blue: 0.2) : 
                    Color(red: 61.0/255.0, green: 190.0/255.0, blue: 208.0/255.0))
        .onAppear {
            configureTabBarAppearance()
        }
        .onChange(of: themeManager.currentTheme) { _, newTheme in
            print("🔄 Tema cambió a: \(newTheme.rawValue)")
            configureTabBarAppearance()
            
            // Forzar actualización inmediata
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                forceTabBarUpdate()
            }
        }
        .alert("Cambio de tema", isPresented: $showThemeChangeConfirmation) {
            Button("Change and restart") {
                // Aplicar el cambio de tema y reiniciar
                if let newTheme = pendingTheme {
                    themeManager.setTheme(newTheme)
                    print("🔄 Tema cambiado a: \(newTheme.rawValue) y guardado")
                    
                    // Reiniciar la aplicación para aplicar el cambio
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        restartApp()
                    }
                }
            }
            
            Button("Cancel", role: .cancel) {
                pendingTheme = nil
            }
        } message: {
            if let newTheme = pendingTheme {
                Text("La aplicación se reiniciará para cambiar al tema \(newTheme == .dark ? "oscuro" : "claro").")
            }
        }
    }
    
    // MARK: - Private Methods
    private func configureTabBarAppearance() {
        print("🎨 Configurando TabBar para tema: \(themeManager.currentTheme.rawValue)")
        
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
        
        print("   🎨 TabBar configurado:")
        print("   🎨 - Fondo: \(backgroundColor)")
        print("   🎨 - Iconos normales: \(normalIconColor)")
        print("   🎨 - Iconos seleccionados: \(selectedIconColor)")
    }
    
    private func forceTabBarUpdate() {
        DispatchQueue.main.async {
            // Forzar recreación de la apariencia
            let currentTheme = themeManager.currentTheme
            print("   🎨 Forzando para tema: \(currentTheme.rawValue)")
            
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
            
            print("   ✅ TabBar forzado exitosamente")
        }
    }
    
    // Función para iniciar el proceso de cambio de tema
    private func requestThemeChange() {
        let newTheme: ThemeManager.AppTheme = themeManager.currentTheme == .dark ? .light : .dark
        pendingTheme = newTheme
        showThemeChangeConfirmation = true
    }
    
    // Función para reiniciar la aplicización
    private func restartApp() {
        print("🔄 Reiniciando aplicación...")
        exit(0)
    }
}

#Preview {
    MainTabView()
        .environmentObject(AuthServiceDirect())
        .environmentObject(ThemeManager())
}