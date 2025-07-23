//
//  MainTabView.swift
//  Gym_API
//
//  Created by Alex Montesino on 7/14/25.
//

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
            ProfileView(onThemeChangeRequest: requestThemeChange)
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
            Button("Cambiar y reiniciar") {
                // Aplicar el cambio de tema y reiniciar
                if let newTheme = pendingTheme {
                    themeManager.setTheme(newTheme)
                    print("🔄 Tema cambiado a: \(newTheme.rawValue) y guardado")
                    
                    // Reiniciar después de un breve delay
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        restartApp()
                    }
                }
                pendingTheme = nil
            }
            Button("Cancelar", role: .cancel) {
                // No cambiar nada
                pendingTheme = nil
            }
        } message: {
            let newThemeName = pendingTheme == .dark ? "oscuro" : "claro"
            Text("¿Deseas cambiar al tema \(newThemeName)? Se recomienda reiniciar la app para aplicar todos los cambios correctamente.")
        }
    }
    
    // MARK: - Private Methods
    private func configureTabBarAppearance() {
        print("🎨 Configurando TabBar para tema: \(themeManager.currentTheme.rawValue)")
        
        // Crear una nueva instancia de apariencia
        let appearance = UITabBarAppearance()
        
        // DEFINICIÓN CLARA Y DEFINITIVA DE COLORES
        let backgroundColor: UIColor
        let normalIconColor: UIColor  // Color para iconos NO seleccionados
        let selectedIconColor: UIColor // Color para iconos seleccionados
        
        if themeManager.currentTheme == .dark {
            // MODO OSCURO: fondo oscuro, iconos normales CLAROS, seleccionados ROJOS
            backgroundColor = UIColor(red: 0.05, green: 0.05, blue: 0.05, alpha: 1.0) // #0D0D0D
            normalIconColor = UIColor(red: 0.95, green: 0.95, blue: 0.95, alpha: 1.0)  // #F2F2F2 (claro)
            selectedIconColor = UIColor(red: 0.85, green: 0.2, blue: 0.2, alpha: 1.0)  // #D93333 (rojo)
            print("   📱 Modo oscuro: fondo=\(backgroundColor), normal=\(normalIconColor), selected=\(selectedIconColor)")
        } else {
            // MODO CLARO: fondo claro, iconos normales OSCUROS, seleccionados AZULES
            backgroundColor = UIColor.white  // #FFFFFF
            normalIconColor = UIColor(red: 0.4, green: 0.4, blue: 0.4, alpha: 1.0)     // #666666 (oscuro)
            selectedIconColor = UIColor(red: 61.0/255.0, green: 190.0/255.0, blue: 208.0/255.0, alpha: 1.0) // RGB(61, 190, 208) (azul)
            print("   📱 Modo claro: fondo=\(backgroundColor), normal=\(normalIconColor), selected=\(selectedIconColor)")
        }
        
        // APLICAR CONFIGURACIÓN
        appearance.configureWithOpaqueBackground()
        appearance.backgroundColor = backgroundColor
        
        // Configuración para TODOS los layouts con los mismos colores
        // Layout apilado (estándar en dispositivos con botón home)
        appearance.stackedLayoutAppearance.normal.iconColor = normalIconColor
        appearance.stackedLayoutAppearance.normal.titleTextAttributes = [.foregroundColor: normalIconColor]
        appearance.stackedLayoutAppearance.selected.iconColor = selectedIconColor
        appearance.stackedLayoutAppearance.selected.titleTextAttributes = [.foregroundColor: selectedIconColor]
        
        // Layout en línea (dispositivos modernos en landscape)
        appearance.inlineLayoutAppearance.normal.iconColor = normalIconColor
        appearance.inlineLayoutAppearance.normal.titleTextAttributes = [.foregroundColor: normalIconColor]
        appearance.inlineLayoutAppearance.selected.iconColor = selectedIconColor
        appearance.inlineLayoutAppearance.selected.titleTextAttributes = [.foregroundColor: selectedIconColor]
        
        // Layout compacto en línea (algunos casos específicos)
        appearance.compactInlineLayoutAppearance.normal.iconColor = normalIconColor
        appearance.compactInlineLayoutAppearance.normal.titleTextAttributes = [.foregroundColor: normalIconColor]
        appearance.compactInlineLayoutAppearance.selected.iconColor = selectedIconColor
        appearance.compactInlineLayoutAppearance.selected.titleTextAttributes = [.foregroundColor: selectedIconColor]
        
        // APLICAR DIRECTAMENTE AL TABBAR ACTUAL
        DispatchQueue.main.async {
            // Buscar el TabBar actual en la jerarquía de vistas
            if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
               let window = windowScene.windows.first,
               let tabBarController = window.rootViewController as? UITabBarController ?? 
                                    findTabBarController(in: window.rootViewController) {
                
                print("   📱 Aplicando directamente al TabBar actual")
                tabBarController.tabBar.standardAppearance = appearance
                tabBarController.tabBar.scrollEdgeAppearance = appearance
                
                if #available(iOS 15.0, *) {
                    tabBarController.tabBar.scrollEdgeAppearance = appearance
                }
                
                // Forzar actualización visual
                tabBarController.tabBar.setNeedsLayout()
                tabBarController.tabBar.layoutIfNeeded()
                print("   ✅ TabBar actualizado directamente")
            }
            
            // También aplicar a la apariencia global como respaldo
            let globalTabBar = UITabBar.appearance()
            globalTabBar.standardAppearance = appearance
            globalTabBar.scrollEdgeAppearance = appearance
            print("   ✅ Apariencia global aplicada como respaldo")
        }
    }
    
    // Función auxiliar para encontrar el TabBarController en la jerarquía
    private func findTabBarController(in viewController: UIViewController?) -> UITabBarController? {
        if let tabBarController = viewController as? UITabBarController {
            return tabBarController
        }
        
        for child in viewController?.children ?? [] {
            if let found = findTabBarController(in: child) {
                return found
            }
        }
        
        return nil
    }
    
    // Función para forzar actualización del TabBar
    private func forceTabBarUpdate() {
        print("🔧 Forzando actualización del TabBar")
        
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let window = windowScene.windows.first,
           let tabBarController = window.rootViewController as? UITabBarController ?? 
                                findTabBarController(in: window.rootViewController) {
            
            // Forzar recreación de la apariencia
            let currentTheme = themeManager.currentTheme
            print("   🎨 Forzando para tema: \(currentTheme.rawValue)")
            
            // Recrear apariencia desde cero
            let appearance = UITabBarAppearance()
            
            let backgroundColor: UIColor
            let normalIconColor: UIColor
            let selectedIconColor: UIColor
            
            if currentTheme == .dark {
                backgroundColor = UIColor(red: 0.05, green: 0.05, blue: 0.05, alpha: 1.0)
                normalIconColor = UIColor(red: 0.95, green: 0.95, blue: 0.95, alpha: 1.0)
                selectedIconColor = UIColor(red: 0.85, green: 0.2, blue: 0.2, alpha: 1.0)
            } else {
                backgroundColor = UIColor.white
                normalIconColor = UIColor(red: 0.4, green: 0.4, blue: 0.4, alpha: 1.0)
                selectedIconColor = UIColor(red: 61.0/255.0, green: 190.0/255.0, blue: 208.0/255.0, alpha: 1.0)
            }
            
            appearance.configureWithOpaqueBackground()
            appearance.backgroundColor = backgroundColor
            
            // Configurar todos los layouts
            appearance.stackedLayoutAppearance.normal.iconColor = normalIconColor
            appearance.stackedLayoutAppearance.normal.titleTextAttributes = [.foregroundColor: normalIconColor]
            appearance.stackedLayoutAppearance.selected.iconColor = selectedIconColor
            appearance.stackedLayoutAppearance.selected.titleTextAttributes = [.foregroundColor: selectedIconColor]
            
            appearance.inlineLayoutAppearance.normal.iconColor = normalIconColor
            appearance.inlineLayoutAppearance.normal.titleTextAttributes = [.foregroundColor: normalIconColor]
            appearance.inlineLayoutAppearance.selected.iconColor = selectedIconColor
            appearance.inlineLayoutAppearance.selected.titleTextAttributes = [.foregroundColor: selectedIconColor]
            
            appearance.compactInlineLayoutAppearance.normal.iconColor = normalIconColor
            appearance.compactInlineLayoutAppearance.normal.titleTextAttributes = [.foregroundColor: normalIconColor]
            appearance.compactInlineLayoutAppearance.selected.iconColor = selectedIconColor
            appearance.compactInlineLayoutAppearance.selected.titleTextAttributes = [.foregroundColor: selectedIconColor]
            
            // Aplicar con animación
            UIView.animate(withDuration: 0.3) {
                tabBarController.tabBar.standardAppearance = appearance
                tabBarController.tabBar.scrollEdgeAppearance = appearance
                
                // Forzar actualización visual inmediata
                tabBarController.tabBar.backgroundColor = backgroundColor
                tabBarController.tabBar.barTintColor = backgroundColor
                
                tabBarController.tabBar.setNeedsLayout()
                tabBarController.tabBar.layoutIfNeeded()
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
    
    // Función para reiniciar la aplicación
    private func restartApp() {
        print("🔄 Reiniciando aplicación...")
        
        // Mostrar un indicador de carga breve
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            // Cerrar la aplicación
            exit(0)
        }
    }
}

struct HomeView: View {
    @EnvironmentObject var themeManager: ThemeManager
    @State private var userName = "Alex"
    @State private var nextClass = "Kickboxing Avanzado"
    @State private var nextClassTime = "Hoy, 1:30 PM"
    @State private var nextClassInstructor = "Coach Laura"
    
    var body: some View {
        NavigationView {
            ZStack {
                Color.dynamicBackground(theme: themeManager.currentTheme).ignoresSafeArea()
                
                ScrollView {
                    VStack(alignment: .leading, spacing: 24) {
                        // Header con saludo
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Hola, \(userName).")
                                    .font(.system(size: 28, weight: .bold))
                                    .foregroundColor(Color.dynamicText(theme: themeManager.currentTheme))
                                
                                Text("¿Listo para tu próxima clase?")
                                    .font(.system(size: 16, weight: .medium))
                                    .foregroundColor(Color.dynamicTextSecondary(theme: themeManager.currentTheme))
                            }
                            
                            Spacer()
                            
                            Image(systemName: "figure.boxing")
                                .font(.system(size: 40))
                                .foregroundColor(Color.dynamicAccent(theme: themeManager.currentTheme))
                        }
                        .padding(.horizontal, 20)
                        .padding(.top, 20)
                        
                        // Próxima clase
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Próxima Clase")
                                .font(.system(size: 18, weight: .semibold))
                                .foregroundColor(Color.dynamicText(theme: themeManager.currentTheme))
                                .padding(.horizontal, 20)
                            
                            ClassCard(
                                title: nextClass,
                                time: nextClassTime,
                                instructor: nextClassInstructor
                            )
                            .padding(.horizontal, 20)
                        }
                        
                        // Accesos rápidos
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Accesos Rápidos")
                                .font(.system(size: 18, weight: .semibold))
                                .foregroundColor(Color.dynamicText(theme: themeManager.currentTheme))
                                .padding(.horizontal, 20)
                            
                            QuickAccessGrid()
                                .padding(.horizontal, 20)
                        }
                        
                        // Evento destacado
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Evento Destacado")
                                .font(.system(size: 18, weight: .semibold))
                                .foregroundColor(Color.dynamicText(theme: themeManager.currentTheme))
                                .padding(.horizontal, 20)
                            
                            EventCardHome()
                                .padding(.horizontal, 20)
                        }
                        
                        // Actividad reciente
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Actividad Reciente")
                                .font(.system(size: 18, weight: .semibold))
                                .foregroundColor(Color.dynamicText(theme: themeManager.currentTheme))
                                .padding(.horizontal, 20)
                            
                            RecentActivityList()
                                .padding(.horizontal, 20)
                        }
                    }
                    .padding(.bottom, 20)
                }
            }
            .navigationTitle("Home")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    NavigationLink(destination: ThemeSettingsView()) {
                        Image(systemName: themeManager.currentTheme == .dark ? "moon.fill" : "sun.max.fill")
                            .font(.system(size: 18))
                            .foregroundColor(Color.dynamicAccent(theme: themeManager.currentTheme))
                    }
                }
            }
        }
    }
}

struct ClassCard: View {
    @EnvironmentObject var themeManager: ThemeManager
    let title: String
    let time: String
    let instructor: String
    
    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: "figure.martial.arts")
                .font(.system(size: 24))
                .foregroundColor(Color.dynamicAccent(theme: themeManager.currentTheme))
                .frame(width: 40, height: 40)
                .background(Color.dynamicAccent(theme: themeManager.currentTheme).opacity(0.2))
                .clipShape(Circle())
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(Color.dynamicText(theme: themeManager.currentTheme))
                
                Text("\(time) con \(instructor)")
                    .font(.system(size: 14))
                    .foregroundColor(Color.dynamicTextSecondary(theme: themeManager.currentTheme))
            }
            
            Spacer()
            
            Image(systemName: "chevron.right")
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(Color.dynamicTextSecondary(theme: themeManager.currentTheme))
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.dynamicSurface(theme: themeManager.currentTheme))
        )
    }
}

struct QuickAccessGrid: View {
    @EnvironmentObject var themeManager: ThemeManager
    
    var items: [QuickAccessItem] {
        [
            QuickAccessItem(icon: "message", title: "Chat", color: Color.dynamicAccent(theme: themeManager.currentTheme)),
            QuickAccessItem(icon: "fork.knife", title: "Nutrición", color: Color.dynamicAccent(theme: themeManager.currentTheme)),
            QuickAccessItem(icon: "calendar", title: "Calendario", color: Color.dynamicAccent(theme: themeManager.currentTheme)),
            QuickAccessItem(icon: "chart.line.uptrend.xyaxis", title: "Progreso", color: Color.dynamicAccent(theme: themeManager.currentTheme))
        ]
    }
    
    var body: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 4), spacing: 16) {
            ForEach(items, id: \.title) { item in
                QuickAccessButton(item: item)
            }
        }
    }
}

struct QuickAccessItem {
    let icon: String
    let title: String
    let color: Color
}

struct QuickAccessButton: View {
    @EnvironmentObject var themeManager: ThemeManager
    let item: QuickAccessItem
    
    var body: some View {
        VStack(spacing: 8) {
            Circle()
                .fill(item.color)
                .frame(width: 56, height: 56)
                .overlay(
                    Image(systemName: item.icon)
                        .font(.system(size: 24))
                        .foregroundColor(.white)
                )
            
            Text(item.title)
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(Color.dynamicText(theme: themeManager.currentTheme))
        }
    }
}

struct EventCardHome: View {
    @EnvironmentObject var themeManager: ThemeManager
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "figure.run")
                    .font(.system(size: 24))
                    .foregroundColor(Color.dynamicAccent(theme: themeManager.currentTheme))
                    .frame(width: 40, height: 40)
                    .background(Color.dynamicAccent(theme: themeManager.currentTheme).opacity(0.2))
                    .clipShape(Circle())
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("Training Run")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.white)
                    
                    Text("Venetian Bridge • Hoy, 11:30 a.m.")
                        .font(.system(size: 14))
                        .foregroundColor(.gray)
                }
                
                Spacer()
            }
            
            Text("Carrera grupal en Venetian Bridge, enfocada en cardio e resistencia.")
                .font(.system(size: 14))
                .foregroundColor(.gray)
                .lineLimit(2)
            
            HStack(spacing: 12) {
                Button("Unirse") {
                    // Acción de unirse
                }
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(.white)
                .padding(.horizontal, 24)
                .padding(.vertical, 10)
                .background(Color.dynamicAccent(theme: themeManager.currentTheme))
                .clipShape(RoundedRectangle(cornerRadius: 8))
                
                Button("Chat") {
                    // Acción de chat
                }
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(.white)
                .padding(.horizontal, 24)
                .padding(.vertical, 10)
                .background(Color.white.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 8))
                
                Spacer()
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.surfacePrimary)
        )
    }
}

struct RecentActivityList: View {
    var body: some View {
        VStack(spacing: 12) {
            RecentActivityRow(
                icon: "checkmark.circle.fill",
                iconColor: .green,
                title: "Clase completada: Kick boxing Intermedio",
                time: "Ayer, 7:00 PM"
            )
            
            RecentActivityRow(
                icon: "message.fill",
                iconColor: .blue,
                title: "Nuevo mensaje de Coach Laura",
                time: "Hace 2 horas"
            )
        }
    }
}

struct RecentActivityRow: View {
    let icon: String
    let iconColor: Color
    let title: String
    let time: String
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 16))
                .foregroundColor(iconColor)
                .frame(width: 20)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.white)
                
                Text(time)
                    .font(.system(size: 12))
                    .foregroundColor(.gray)
            }
            
            Spacer()
        }
    }
}

// Classes View
struct ClassesView: View {
    @EnvironmentObject var authService: AuthServiceDirect
    @EnvironmentObject var classService: ClassService
    @EnvironmentObject var themeManager: ThemeManager
    @State private var selectedDate = Date()
    
    var body: some View {
        NavigationView {
            ZStack {
                Color.dynamicBackground(theme: themeManager.currentTheme).ignoresSafeArea()
                
                if classService.isLoading {
                    LoadingClassesView()
                } else if let errorMessage = classService.errorMessage {
                    ErrorClassesView(message: errorMessage) {
                        Task {
                            await classService.loadSessionsForDateIfNeeded(date: selectedDate)
                        }
                    }
                } else {
                    ClassesContentView(selectedDate: $selectedDate)
                }
            }
            .navigationBarHidden(true)
        }
        .onAppear {
            classService.authService = authService
            Task {
                // Cargar trainers si aún no se han cargado
                if classService.trainers.isEmpty {
                    await classService.loadTrainers()
                }
                
                // Cargar datos para la fecha seleccionada (inicialmente hoy)
                async let sessionsTask: () = classService.loadSessionsForDateIfNeeded(date: selectedDate)
                async let myClassesTask: () = classService.fetchMyClasses()
                
                await sessionsTask
                await myClassesTask
            }
        }
        .onChange(of: selectedDate) {
            Task {
                await classService.loadSessionsForDateIfNeeded(date: selectedDate)
            }
        }
    }
}

struct EventsView: View {
    @EnvironmentObject var authService: AuthServiceDirect
    @EnvironmentObject var eventService: EventService
    @EnvironmentObject var themeManager: ThemeManager
    @State private var searchText = ""
    @State private var selectedFilter: EventFilter = .available
    @State private var showingFilterSheet = false
    @State private var searchTask: Task<Void, Never>?
    
    // Estados para navegación de chat desde tarjetas
    @State private var showingEventChatFromCard = false
    @State private var selectedChatEventFromCard: Event?
    
    var body: some View {
        NavigationView {
            ZStack {
                Color.dynamicBackground(theme: themeManager.currentTheme).ignoresSafeArea()
                
                ScrollView {
                    VStack(alignment: .leading, spacing: 24) {
                        // Header Section
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Eventos")
                                .font(.system(size: 32, weight: .bold))
                                .foregroundColor(Color.dynamicText(theme: themeManager.currentTheme))
                            
                            Text("Conéctate con tu comunidad. Entrena juntos.")
                                .font(.system(size: 16, weight: .medium))
                                .foregroundColor(Color.dynamicTextSecondary(theme: themeManager.currentTheme))
                        }
                        .padding(.horizontal, 20)
                        .padding(.top, 20)
                        
                        // Search Bar
                        HStack(spacing: 12) {
                            HStack {
                                Image(systemName: "magnifyingglass")
                                    .foregroundColor(Color.dynamicTextSecondary(theme: themeManager.currentTheme))
                                    .font(.system(size: 16))
                                
                                TextField("Buscar eventos...", text: $searchText)
                                    .textFieldStyle(PlainTextFieldStyle())
                                    .foregroundColor(Color.dynamicText(theme: themeManager.currentTheme))
                                    .autocorrectionDisabled()
                                    .onChange(of: searchText) { _, newValue in
                                        debounceSearch(newValue)
                                    }
                                
                                if !searchText.isEmpty {
                                    Button(action: {
                                        searchText = ""
                                    }) {
                                        Image(systemName: "xmark.circle.fill")
                                            .foregroundColor(Color.dynamicTextSecondary(theme: themeManager.currentTheme))
                                            .font(.system(size: 16))
                                    }
                                }
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 12)
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(Color.dynamicSurface(theme: themeManager.currentTheme))
                            )
                            
                            HStack(spacing: 16) {
                                // Refresh Button
                                Button(action: {
                                    Task {
                                        await eventService.forceRefresh()
                                    }
                                }) {
                                    Image(systemName: eventService.isLoading ? "arrow.clockwise.circle.fill" : "arrow.clockwise.circle")
                                        .font(.system(size: 20))
                                        .foregroundColor(Color.dynamicAccent(theme: themeManager.currentTheme))
                                        .rotationEffect(.degrees(eventService.isLoading ? 360 : 0))
                                        .animation(eventService.isLoading ? Animation.linear(duration: 1).repeatForever(autoreverses: false) : .default, value: eventService.isLoading)
                                }
                                .disabled(eventService.isLoading)
                                
                                // Filter Button
                                Button(action: {
                                    showingFilterSheet = true
                                }) {
                                    Image(systemName: "line.3.horizontal.decrease.circle")
                                        .font(.system(size: 20))
                                        .foregroundColor(Color.dynamicAccent(theme: themeManager.currentTheme))
                                }
                            }
                        }
                        .padding(.horizontal, 20)
                        
                        // Events List
                        if eventService.isLoading {
                            // Loading State
                            VStack(spacing: 16) {
                                ForEach(0..<3, id: \.self) { _ in
                                    EventCardSkeleton()
                                }
                            }
                            .padding(.horizontal, 20)
                        } else if filteredEvents.isEmpty {
                            // Empty State
                            VStack(spacing: 16) {
                                Image(systemName: searchText.isEmpty ? "calendar.badge.exclamationmark" : "magnifyingglass")
                                    .font(.system(size: 48))
                                    .foregroundColor(Color.dynamicTextSecondary(theme: themeManager.currentTheme))
                                
                                Text(searchText.isEmpty ? "No hay eventos disponibles" : "No se encontraron eventos")
                                    .font(.system(size: 18, weight: .medium))
                                    .foregroundColor(Color.dynamicTextSecondary(theme: themeManager.currentTheme))
                                    .multilineTextAlignment(.center)
                                
                                Text(searchText.isEmpty ? "Mantente atento a nuevos eventos" : "Prueba con otros términos de búsqueda")
                                    .font(.system(size: 14))
                                    .foregroundColor(Color.dynamicTextSecondary(theme: themeManager.currentTheme).opacity(0.7))
                                    .multilineTextAlignment(.center)
                            }
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                            .padding(.vertical, 40)
                        } else {
                            // Events List by Time Sections
                            LazyVStack(spacing: 24) {
                                ForEach(eventSections, id: \.title) { section in
                                    EventTimeSection(section: section, eventService: eventService, onChatTapped: handleChatEvent)
                                }
                            }
                            .padding(.horizontal, 20)
                        }
                        
                        // Error Message
                        if let errorMessage = eventService.errorMessage {
                            VStack(spacing: 12) {
                                Image(systemName: "exclamationmark.triangle")
                                    .font(.system(size: 24))
                                    .foregroundColor(themeManager.currentTheme == .dark ? .orange : .red)
                                
                                Text("Error al cargar eventos")
                                    .font(.system(size: 16, weight: .medium))
                                    .foregroundColor(Color.dynamicText(theme: themeManager.currentTheme))
                                
                                Text(errorMessage)
                                    .font(.system(size: 14))
                                    .foregroundColor(Color.dynamicTextSecondary(theme: themeManager.currentTheme))
                                    .multilineTextAlignment(.center)
                                
                                Button("Reintentar") {
                                    Task {
                                        await eventService.fetchEvents()
                                    }
                                }
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(.white)
                                    .padding(.horizontal, 20)
                                    .padding(.vertical, 8)
                                    .background(Color.dynamicAccent(theme: themeManager.currentTheme))
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                            }
                            .padding(.horizontal, 20)
                            .padding(.vertical, 20)
                        }
                    }
                    .padding(.bottom, 100) // Para el tab bar
                }
                .onTapGesture {
                    // Dismiss keyboard when tapping outside
                    UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                }
            }
            .navigationBarHidden(true)
            .refreshable {
                await eventService.forceRefresh()
            }
            .background(
                NavigationLink(
                    destination: selectedChatEventFromCard.map { event in
                        EventChatView(
                            eventId: String(event.id),
                            eventTitle: event.title,
                            authService: authService
                        )
                    },
                    isActive: $showingEventChatFromCard,
                    label: { EmptyView() }
                )
                .hidden()
            )
            .sheet(isPresented: $showingFilterSheet) {
                EventFilterSheet(selectedFilter: $selectedFilter)
            }
        }
        .onAppear {
            // Configurar AuthService en EventService
            eventService.authService = authService
            
            Task {
                // Si no hay eventos cargados, hacer un fetch inicial
                if eventService.events.isEmpty {
                    print("📱 Initial load - fetching events")
                    await eventService.fetchEvents()
                } else {
                    print("📱 Events already loaded (\(eventService.events.count) events)")
                }
            }
        }
        .onDisappear {
            // Cancel any pending search tasks
            searchTask?.cancel()
        }
    }
    
    // MARK: - Private Methods
    
    private func debounceSearch(_ searchText: String) {
        // Cancel previous search task
        searchTask?.cancel()
        
        // Create new search task with delay
        searchTask = Task {
            try? await Task.sleep(nanoseconds: 300_000_000) // 300ms delay
            
            // Check if task was cancelled
            if Task.isCancelled {
                return
            }
            
            // Perform search here if needed
            // For now, we're just using computed properties for filtering
            // But this prevents multiple API calls if we implement server-side search later
        }
    }
    
    private func handleChatEvent(_ event: Event) {
        print("💬 Abriendo chat para evento: \(event.title)")
        selectedChatEventFromCard = event
        showingEventChatFromCard = true
    }
    
    // MARK: - Computed Properties
    
    var filteredEvents: [Event] {
        let searchFiltered = eventService.events.filter { event in
            searchText.isEmpty || 
            event.title.localizedCaseInsensitiveContains(searchText) ||
            event.location.localizedCaseInsensitiveContains(searchText)
        }
        
        let statusFiltered = searchFiltered.filter { event in
            switch selectedFilter {
            case .all:
                return true
            case .available:
                return event.status == .scheduled && event.participantsCount < event.maxParticipants
            case .today:
                return Calendar.current.isDateInToday(event.startTime)
            case .scheduled:
                return event.status == .scheduled
            case .completed:
                return event.status == .completed
            }
        }
        
        return statusFiltered.sorted { $0.startTime < $1.startTime }
    }
    
    var eventSections: [EventSection] {
        let now = Date()
        let calendar = Calendar.current
        
        // Función auxiliar para ordenar eventos por fecha
        func sortedEvents(_ events: [Event]) -> [Event] {
            return events.sorted { $0.startTime < $1.startTime }
        }
        
        // Si el filtro es "Disponibles", usar una organización específica
        if selectedFilter == .available {
            let availableEvents = filteredEvents
            
            // Eventos disponibles de hoy
            let todayAvailable = sortedEvents(availableEvents.filter { 
                calendar.isDateInToday($0.startTime)
            })
            
            // Eventos disponibles de mañana
            let tomorrowAvailable = sortedEvents(availableEvents.filter {
                calendar.isDateInTomorrow($0.startTime)
            })
            
            // Eventos disponibles futuros (después de mañana)
            let laterAvailable = sortedEvents(availableEvents.filter {
                !calendar.isDateInToday($0.startTime) &&
                !calendar.isDateInTomorrow($0.startTime) &&
                $0.startTime > now
            })
            
            // Crear secciones solo para las que tienen eventos
            var sections: [EventSection] = []
            
            if !todayAvailable.isEmpty {
                sections.append(EventSection(title: "Hoy", events: todayAvailable))
            }
            if !tomorrowAvailable.isEmpty {
                sections.append(EventSection(title: "Mañana", events: tomorrowAvailable))
            }
            if !laterAvailable.isEmpty {
                sections.append(EventSection(title: "Próximamente", events: laterAvailable))
            }
            
            return sections
        }
        
        // Para otros filtros, mantener la lógica original
        let today = sortedEvents(filteredEvents.filter { calendar.isDateInToday($0.startTime) })
        let tomorrow = sortedEvents(filteredEvents.filter { 
            calendar.isDateInTomorrow($0.startTime) 
        })
        let thisWeek = sortedEvents(filteredEvents.filter { 
            !calendar.isDateInToday($0.startTime) && 
            !calendar.isDateInTomorrow($0.startTime) &&
            calendar.isDate($0.startTime, equalTo: now, toGranularity: .weekOfYear) &&
            $0.startTime > now
        })
        let later = sortedEvents(filteredEvents.filter { 
            !calendar.isDateInToday($0.startTime) &&
            !calendar.isDateInTomorrow($0.startTime) &&
            !calendar.isDate($0.startTime, equalTo: now, toGranularity: .weekOfYear) &&
            $0.startTime > now
        })
        
        // Eventos pasados
        let yesterday = sortedEvents(filteredEvents.filter { calendar.isDateInYesterday($0.startTime) })
        let lastWeek = sortedEvents(filteredEvents.filter { 
            !calendar.isDateInYesterday($0.startTime) &&
            calendar.isDate($0.startTime, equalTo: now, toGranularity: .weekOfYear) &&
            $0.startTime < now
        })
        let earlier = sortedEvents(filteredEvents.filter { 
            !calendar.isDate($0.startTime, equalTo: now, toGranularity: .weekOfYear) &&
            $0.startTime < now
        })
        
        // Definir el orden de las secciones
        let sectionDefinitions: [(String, [Event], Int)] = [
            ("Hoy", today, 0),
            ("Mañana", tomorrow, 1),
            ("Esta semana", thisWeek, 2),
            ("Más tarde", later, 3),
            ("Ayer", yesterday, 4),
            ("Esta semana pasada", lastWeek, 5),
            ("Anteriores", earlier, 6)
        ]
        
        // Crear secciones solo para las que tienen eventos y ordenarlas
        let sections = sectionDefinitions
            .filter { !$0.1.isEmpty }
            .map { EventSection(title: $0.0, events: $0.1) }
            .sorted { (section1, section2) in
                // Encontrar el orden de cada sección
                let order1 = sectionDefinitions.first { $0.0 == section1.title }?.2 ?? 0
                let order2 = sectionDefinitions.first { $0.0 == section2.title }?.2 ?? 0
                return order1 < order2
            }
        
        return sections
    }
}

// MARK: - Event Filter Types
enum EventFilter: String, CaseIterable {
    case all = "Todos"
    case available = "Disponibles"
    case today = "Hoy"
    case scheduled = "Programados"
    case completed = "Completados"
}

// MARK: - Event Section Model
struct EventSection {
    let title: String
    let events: [Event]
}

// MARK: - Event Time Section View
struct EventTimeSection: View {
    @EnvironmentObject var themeManager: ThemeManager
    let section: EventSection
    @ObservedObject var eventService: EventService
    let onChatTapped: (Event) -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text(section.title)
                .font(.system(size: 20, weight: .bold))
                .foregroundColor(Color.dynamicText(theme: themeManager.currentTheme))
            
            LazyVStack(spacing: 20) {
                ForEach(section.events) { event in
                    EventCard(event: event, eventService: eventService, onChatTapped: onChatTapped)
                }
            }
        }
    }
}

// MARK: - Event Filter Sheet
struct EventFilterSheet: View {
    @EnvironmentObject var themeManager: ThemeManager
    @Binding var selectedFilter: EventFilter
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        ZStack {
            Color.dynamicBackground(theme: themeManager.currentTheme).ignoresSafeArea()
            
            VStack(alignment: .leading, spacing: 20) {
                // Header
                HStack {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Filtrar eventos")
                            .font(.system(size: 24, weight: .bold))
                            .foregroundColor(Color.dynamicText(theme: themeManager.currentTheme))
                        
                        Text("Selecciona el tipo de eventos que quieres ver")
                            .font(.system(size: 16))
                            .foregroundColor(Color.dynamicTextSecondary(theme: themeManager.currentTheme))
                    }
                    
                    Spacer()
                    
                    Button("Cerrar") {
                        dismiss()
                    }
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(Color.dynamicAccent(theme: themeManager.currentTheme))
                }
                .padding(.horizontal, 20)
                .padding(.top, 20)
                
                // Filter Options
                ScrollView {
                    LazyVStack(spacing: 12) {
                        ForEach(EventFilter.allCases, id: \.self) { filter in
                            FilterOption(
                                filter: filter,
                                isSelected: selectedFilter == filter
                            ) {
                                selectedFilter = filter
                                dismiss()
                            }
                        }
                    }
                    .padding(.horizontal, 20)
                }
                
                Spacer(minLength: 0)
            }
        }
        .presentationDetents([.medium])
        .presentationDragIndicator(.visible)
    }
}

// MARK: - Filter Option View
struct FilterOption: View {
    @EnvironmentObject var themeManager: ThemeManager
    let filter: EventFilter
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(filter.rawValue)
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(Color.dynamicText(theme: themeManager.currentTheme))
                    
                    Text(filterDescription(for: filter))
                        .font(.system(size: 14))
                        .foregroundColor(Color.dynamicTextSecondary(theme: themeManager.currentTheme))
                }
                
                Spacer()
                
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 20))
                        .foregroundColor(Color.dynamicAccent(theme: themeManager.currentTheme))
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 16)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(isSelected ? Color.dynamicAccent(theme: themeManager.currentTheme).opacity(0.1) : Color.dynamicSurface(theme: themeManager.currentTheme))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(isSelected ? Color.dynamicAccent(theme: themeManager.currentTheme) : Color.dynamicBorder(theme: themeManager.currentTheme), lineWidth: 1)
                    )
            )
        }
    }
    
    private func filterDescription(for filter: EventFilter) -> String {
        switch filter {
        case .all:
            return "Mostrar todos los eventos"
        case .available:
            return "Solo eventos con espacios disponibles"
        case .today:
            return "Eventos que ocurren hoy"
        case .scheduled:
            return "Eventos programados para el futuro"
        case .completed:
            return "Eventos que ya terminaron"
        }
    }
}

struct MessagesView: View {
    @EnvironmentObject var themeManager: ThemeManager
    @EnvironmentObject var authService: AuthServiceDirect
    @ObservedObject private var chatService = ChatService.shared
    @StateObject private var directMessageService = DirectMessageService()
    @State private var selectedChatType: ChatType? = nil
    @State private var showingChat = false
    @State private var selectedChatRoom: ChatRoom? = nil
    @State private var showingDirectMessageSheet = false
    
    var body: some View {
        NavigationView {
            ZStack {
                Color.dynamicBackground(theme: themeManager.currentTheme).ignoresSafeArea()
                
                VStack(spacing: 0) {
                    // Header personalizado con título y botones
                    VStack(spacing: 16) {
                        // Título y botones
                        HStack {
                            Text("Mensajes")
                                .font(.system(size: 34, weight: .bold))
                                .foregroundColor(Color.dynamicText(theme: themeManager.currentTheme))
                            
                            Spacer()
                            
                            Button(action: {
                                showingDirectMessageSheet = true
                            }) {
                                Image(systemName: "person.crop.circle.badge.plus")
                                    .font(.system(size: 18))
                                    .foregroundColor(Color.dynamicAccent(theme: themeManager.currentTheme))
                            }
                        }
                        .padding(.horizontal, 20)
                        .padding(.top, 16)
                        
                        // Header con filtros
                        ChatFilterHeader(selectedChatType: $selectedChatType, themeManager: themeManager)
                    }
                    .background(Color.dynamicBackground(theme: themeManager.currentTheme))
                    
                    // Contenido principal
                    if chatService.isLoadingRooms {
                        LoadingChatsView(themeManager: themeManager)
                    } else if let errorMessage = chatService.roomsErrorMessage {
                        ErrorChatsView(message: errorMessage, themeManager: themeManager) {
                            loadChatRooms()
                        }
                    } else if chatService.chatRooms.isEmpty {
                        EmptyChatsView(themeManager: themeManager)
                    } else {
                        ChatRoomsList(
                            chatRooms: filteredChatRooms,
                            themeManager: themeManager,
                            onChatSelected: { chatRoom in
                                handleChatSelection(chatRoom)
                            }
                        )
                    }
                }
            }
            .navigationBarHidden(true)
            .onAppear {
                setupChatService()
                loadChatRooms()
                directMessageService.authService = authService
            }
            .background(
                NavigationLink(
                    destination: selectedChatRoom.map { chatRoom in
                        UniversalChatView(
                            chatRoom: chatRoom,
                            authService: authService
                        )
                    },
                    isActive: $showingChat,
                    label: { EmptyView() }
                )
            )
            .sheet(isPresented: $showingDirectMessageSheet) {
                DirectMessagesView()
                    .environmentObject(authService)
                    .environmentObject(themeManager)
            }
        }
    }
    
    private var filteredChatRooms: [ChatRoom] {
        guard let selectedType = selectedChatType else {
            return chatService.chatRooms
        }
        return chatService.chatRooms.filter { $0.chatType == selectedType }
    }
    
    private func setupChatService() {
        chatService.authService = authService
        // TODO: En el futuro, configurar con el gym_id del usuario actual
        // Por ahora usar el default (4) que ya está configurado
        chatService.currentGymId = 4  // Hardcodeado por ahora
    }
    
    private func loadChatRooms() {
        Task {
            await chatService.getMyRooms()
        }
    }
    
    private func handleChatSelection(_ chatRoom: ChatRoom) {
        print("📱 Chat seleccionado: \(chatRoom.name ?? "Sin nombre") - Tipo: \(chatRoom.chatType)")
        selectedChatRoom = chatRoom
        showingChat = true
    }
    
}

struct ProfileView: View {
    @EnvironmentObject var authService: AuthServiceDirect
    @EnvironmentObject var themeManager: ThemeManager
    @EnvironmentObject var oneSignalService: OneSignalService
    @State private var refreshID = UUID()
    let onThemeChangeRequest: () -> Void
    
    var body: some View {
        NavigationView {
            ZStack {
                Color.dynamicBackground(theme: themeManager.currentTheme).ignoresSafeArea()
                
                VStack(spacing: 32) {
                    // Información del usuario
                    VStack(spacing: 20) {
                        // Avatar con fondo
                        VStack(spacing: 0) {
                            Circle()
                                .fill(Color.dynamicSurface(theme: themeManager.currentTheme))
                                .frame(width: 120, height: 120)
                                .overlay(
                                    Image(systemName: "person.circle.fill")
                                        .font(.system(size: 65))
                                        .foregroundColor(Color.dynamicAccent(theme: themeManager.currentTheme))
                                )
                        }
                        
                        if let user = authService.user {
                            VStack(spacing: 8) {
                                Text(user.name)
                                    .font(.system(size: 28, weight: .bold))
                                    .foregroundColor(Color.dynamicText(theme: themeManager.currentTheme))
                                
                                Text(user.email)
                                    .font(.system(size: 16))
                                    .foregroundColor(Color.dynamicTextSecondary(theme: themeManager.currentTheme))
                            }
                        }
                    }
                    
                    // Opciones de perfil
                    VStack(spacing: 16) {
                        ProfileOptionRow(
                            icon: "moon.circle.fill",
                            title: "Tema",
                            subtitle: themeManager.currentTheme == .dark ? "Oscuro" : "Claro",
                            themeManager: themeManager
                        ) {
                            onThemeChangeRequest()
                        }
                        
                        ProfileOptionRow(
                            icon: "bell.circle.fill",
                            title: "Notificaciones",
                            subtitle: "Configurar alertas",
                            themeManager: themeManager
                        ) {
                            // Acción futura
                        }
                        
                        ProfileOptionRow(
                            icon: "questionmark.circle.fill",
                            title: "Ayuda",
                            subtitle: "Soporte y FAQ",
                            themeManager: themeManager
                        ) {
                            // Acción futura
                        }
                    }
                    .padding(.horizontal, 20)
                    
                    Spacer()
                    
                    // Sección de Notificaciones de Prueba
                    VStack(alignment: .leading, spacing: 16) {
                        HStack {
                            Image(systemName: "bell.fill")
                                .foregroundColor(Color.dynamicAccent(theme: themeManager.currentTheme))
                                .font(.system(size: 20))
                            Text("Push Notifications")
                                .font(.system(size: 20, weight: .semibold))
                                .foregroundColor(Color.dynamicText(theme: themeManager.currentTheme))
                            Spacer()
                        }
                        
                        // Estado de suscripción
                        HStack {
                            HStack(spacing: 8) {
                                Circle()
                                    .fill(oneSignalService.isSubscribed() ? .green : .red)
                                    .frame(width: 8, height: 8)
                                Text(oneSignalService.isSubscribed() ? "Activado" : "Desactivado")
                                    .font(.system(size: 14))
                                    .foregroundColor(Color.dynamicTextSecondary(theme: themeManager.currentTheme))
                            }
                            
                            Spacer()
                            
                            // Botón de re-suscripción si no está suscrito
                            if !oneSignalService.isSubscribed() {
                                Button(action: {
                                    oneSignalService.manuallyOptIn()
                                    // Forzar actualización de la vista
                                    DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                                        refreshID = UUID()
                                    }
                                }) {
                                    Text("Activar")
                                        .font(.system(size: 12, weight: .medium))
                                        .foregroundColor(.white)
                                        .padding(.horizontal, 12)
                                        .padding(.vertical, 6)
                                        .background(Color.dynamicAccent(theme: themeManager.currentTheme))
                                        .clipShape(RoundedRectangle(cornerRadius: 8))
                                }
                            }
                        }
                        
                        // Player ID
                        if let playerId = oneSignalService.getPlayerId() {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Player ID:")
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundColor(Color.dynamicTextSecondary(theme: themeManager.currentTheme))
                                Text(playerId.prefix(16) + "...")
                                    .font(.system(size: 11, design: .monospaced))
                                    .foregroundColor(Color.dynamicTextSecondary(theme: themeManager.currentTheme))
                            }
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 16)
                    .background(Color.dynamicSurface(theme: themeManager.currentTheme))
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                    .padding(.horizontal, 20)
                    .id(refreshID)
                    
                    // Botón de logout
                    Button(action: {
                        Task {
                            await authService.logout()
                        }
                    }) {
                        HStack(spacing: 12) {
                            Image(systemName: "rectangle.portrait.and.arrow.right")
                                .font(.system(size: 18))
                            Text("Cerrar Sesión")
                                .font(.system(size: 16, weight: .semibold))
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 52)
                        .background(themeManager.currentTheme == .light ? Color.red : Color.red.opacity(0.9))
                        .foregroundColor(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 32)
                }
                .padding(.top, 20)
            }
            .navigationTitle("Perfil")
            .navigationBarTitleDisplayMode(.large)
            .animation(.easeInOut(duration: 0.3), value: themeManager.currentTheme)
        }
    }
}

// MARK: - Profile Option Row Component
struct ProfileOptionRow: View {
    let icon: String
    let title: String
    let subtitle: String
    let themeManager: ThemeManager
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 16) {
                // Icono
                Image(systemName: icon)
                    .font(.system(size: 24))
                    .foregroundColor(Color.dynamicAccent(theme: themeManager.currentTheme))
                    .frame(width: 32)
                
                // Contenido
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(Color.dynamicText(theme: themeManager.currentTheme))
                    
                    Text(subtitle)
                        .font(.system(size: 14))
                        .foregroundColor(Color.dynamicTextSecondary(theme: themeManager.currentTheme))
                }
                
                Spacer()
                
                // Flecha
                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(Color.dynamicTextSecondary(theme: themeManager.currentTheme))
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
            .background(Color.dynamicSurface(theme: themeManager.currentTheme))
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .animation(.easeInOut(duration: 0.3), value: themeManager.currentTheme)
            .id("profile-option-\(themeManager.currentTheme.rawValue)") // Forzar actualización al cambiar tema
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Event Card Component
struct EventCard: View {
    let event: Event
    @ObservedObject var eventService: EventService
    let onChatTapped: (Event) -> Void
    
    @State private var navigateToDetail = false
    
    var body: some View {
        ZStack {
            NavigationLink(destination: EventDetailView(eventId: event.id), isActive: $navigateToDetail) {
                EmptyView()
            }
            .opacity(0)
            
            ModernEventCardContent(event: event, eventService: eventService, onChatTapped: onChatTapped)
                .onTapGesture {
                    navigateToDetail = true
                }
        }
    }
}

// MARK: - Modern Event Card Content
struct ModernEventCardContent: View {
    @EnvironmentObject var themeManager: ThemeManager
    let event: Event
    @ObservedObject var eventService: EventService
    let onChatTapped: (Event) -> Void
    @State private var isLoading = false
    @State private var shakeOffset: CGFloat = 0
    
    // Función para determinar si un evento está disponible
    private func isEventAvailable() -> Bool {
        return (event.status == .scheduled || event.status == .active) && 
               event.participantsCount < event.maxParticipants
    }
    
    // Función para determinar los colores de la línea según el estado
    private func getEventStatusColors(_ status: EventStatus) -> [Color] {
        let accentColor = Color.dynamicAccent(theme: themeManager.currentTheme)
        
        // Si el evento está disponible (programado o activo y con espacios), usar color de acento
        if isEventAvailable() {
            return [accentColor, accentColor.opacity(0.8)]
        }
        
        // Para eventos no disponibles, usar colores según estado
        switch status {
        case .completed:
            return [Color.gray, Color.gray.opacity(0.8)]
        case .cancelled:
            return [Color.orange, Color.orange.opacity(0.8)]
        default:
            // Para eventos llenos
            return [Color.gray, Color.gray.opacity(0.8)]
        }
    }
    

    
    // Función para crear el efecto de sacudida
    private func shakeCard() {
        withAnimation(.easeInOut(duration: 0.1)) {
            shakeOffset = -8
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            withAnimation(.easeInOut(duration: 0.1)) {
                shakeOffset = 8
            }
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            withAnimation(.easeInOut(duration: 0.1)) {
                shakeOffset = -4
            }
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            withAnimation(.easeInOut(duration: 0.1)) {
                shakeOffset = 4
            }
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
            withAnimation(.easeInOut(duration: 0.1)) {
                shakeOffset = 0
            }
        }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Fondo con gradiente y glassmorphism
            ZStack {
                // Gradiente de fondo dinámico
                LinearGradient(
                    gradient: Gradient(colors: [
                        Color.dynamicBackground(theme: themeManager.currentTheme),
                        Color.dynamicSurface(theme: themeManager.currentTheme)
                    ]),
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                
                // Fondo de la tarjeta
                RoundedRectangle(cornerRadius: 20)
                    .fill(Color.dynamicSurface(theme: themeManager.currentTheme))
                
                HStack(spacing: 0) {
                    // Indicador de estado (línea colorida)
                    Rectangle()
                        .fill(
                            LinearGradient(
                                gradient: Gradient(colors: getEventStatusColors(event.status)),
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .frame(width: 5)
                        .clipShape(RoundedRectangle(cornerRadius: 2.5))
                    
                    // Contenido principal
                    VStack(alignment: .leading, spacing: 18) {
                        // Header: Título + Tipo de evento
                        VStack(alignment: .leading, spacing: 8) {
                            // Categoría/Tipo
                            Text("FITNESS EVENT")
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundColor(Color.dynamicAccent(theme: themeManager.currentTheme))
                                .tracking(1.2)
                            
                            // Título principal
                            Text(event.title)
                                .font(.system(size: 26, weight: .bold))
                                .foregroundColor(Color.dynamicText(theme: themeManager.currentTheme))
                                .lineLimit(2)
                                .multilineTextAlignment(.leading)
                        }
                        
                        // Información del evento
                        VStack(alignment: .leading, spacing: 12) {
                            // Ubicación con ícono elegante
                            HStack(spacing: 12) {
                                Image(systemName: "mappin.circle.fill")
                                    .font(.system(size: 16))
                                    .foregroundColor(Color.dynamicAccent(theme: themeManager.currentTheme))
                                
                                Text(event.location)
                                    .font(.system(size: 16, weight: .medium))
                                    .foregroundColor(Color.dynamicText(theme: themeManager.currentTheme).opacity(0.9))
                            }
                            
                            // Coach con ícono

                            
                            HStack(spacing: 12) {
                                Image(systemName: "person.crop.circle.fill")
                                    .font(.system(size: 16))
                                    .foregroundColor(Color.dynamicAccent(theme: themeManager.currentTheme))
                                
                                Text(getCoachName(from: event.description))
                                    .font(.system(size: 16, weight: .medium))
                                    .foregroundColor(Color.dynamicText(theme: themeManager.currentTheme).opacity(0.9))
                            }
                        }
                        
                        // Footer: Fecha + Acción
                        HStack(alignment: .center) {
                            // Fecha con diseño moderno
                            VStack(alignment: .leading, spacing: 4) {
                                Text("SCHEDULE")
                                    .font(.system(size: 10, weight: .medium))
                                    .foregroundColor(Color.dynamicTextSecondary(theme: themeManager.currentTheme).opacity(0.8))
                                    .tracking(1)
                                
                                HStack(spacing: 8) {
                                    Image(systemName: "calendar.badge.clock")
                                        .font(.system(size: 14))
                                        .foregroundColor(Color.dynamicTextSecondary(theme: themeManager.currentTheme))
                                    
                                    Text(formatEventDateFull(event.startTime))
                                        .font(.system(size: 15, weight: .semibold))
                                        .foregroundColor(Color.dynamicText(theme: themeManager.currentTheme))
                                }
                            }
                            
                            Spacer()
                            
                            // Contenedor fijo para botones
                            ZStack {
                                // Área para evitar que los toques pasen a la tarjeta
                                Color.clear
                                    .contentShape(Rectangle())
                                    .allowsHitTesting(true)
                                    .onTapGesture { }
                                // Fondo común para ambos botones
                                Capsule()
                                    .fill(Color.dynamicSurface(theme: themeManager.currentTheme).opacity(0.8))
                                    .overlay(
                                        Capsule()
                                            .stroke(Color.dynamicBorder(theme: themeManager.currentTheme), lineWidth: 0.5)
                                    )
                                
                                // Estado de loading
                                if isLoading {
                                    VStack {
                                        Spacer()
                                        // Efecto de puntos desplazándose
                                        HStack(spacing: 8) {
                                            ForEach(0..<5) { index in
                                                Circle()
                                                    .fill(Color.dynamicText(theme: themeManager.currentTheme))
                                                    .frame(width: 6, height: 6)
                                                    .opacity(isLoading ? (getOpacityForDot(index: index)) : 0.3)
                                                    .scaleEffect(isLoading ? (getScaleForDot(index: index)) : 0.8)
                                                    .animation(
                                                        Animation.easeInOut(duration: 0.5)
                                                            .repeatForever(autoreverses: true)
                                                            .delay(Double(index) * 0.08),
                                                        value: isLoading
                                                    )
                                            }
                                        }
                                        Spacer()
                                    }
                                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                                    .transition(.opacity)
                                } else if event.status == .completed && eventService.isUserRegistered(eventId: event.id) {
                                    // Evento completado donde el usuario participó: botón doble con Chat + Complete
                                    HStack(alignment: .center, spacing: 0) {
                                        // IconButton - Chat
                                        Button(action: {
                                            print("💬 Opening chat for completed event: \(event.title)")
                                            onChatTapped(event)
                                        }) {
                                            Image(systemName: "bubble")
                                                .font(.system(size: 18))
                                                .foregroundColor(themeManager.currentTheme == .light ? Color.dynamicAccent(theme: themeManager.currentTheme) : Color(red: 0.96, green: 0.96, blue: 0.96))
                                                .padding(.leading, 8)
                                        }
                                        .frame(minWidth: 0, maxWidth: .infinity)
                                        .layoutPriority(0.40)
                                        
                                        // Línea divisoria
                                        Rectangle()
                                            .fill(Color.dynamicBorder(theme: themeManager.currentTheme).opacity(0.5))
                                            .frame(width: 0.5, height: 24)
                                        
                                        // TextButton - Complete (área más grande)
                                        Button(action: {
                                            print("✅ Event completed: \(event.title)")
                                            shakeCard()
                                        }) {
                                            Text("Complete")
                                                .font(.system(size: 15, weight: .semibold))
                                                .foregroundColor(Color(red: 0.96, green: 0.96, blue: 0.96))
                                        }
                                        .frame(minWidth: 0, maxWidth: .infinity)
                                        .layoutPriority(0.60)
                                        .disabled(false) // Habilitado para permitir el efecto de sacudida
                                    }
                                    .frame(height: 44)
                                    .transition(.opacity)
                                } else if event.status == .completed {
                                    // Evento completado donde el usuario NO participó: botón simple Complete
                                    Button(action: {
                                        print("✅ Event completed (not participated): \(event.title)")
                                        shakeCard()
                                    }) {
                                        HStack(spacing: 8) {
                                            Image(systemName: "checkmark.circle.fill")
                                                .font(.system(size: 16))
                                            
                                            Text("Complete")
                                                .font(.system(size: 16, weight: .semibold))
                                        }
                                        .foregroundColor(.white.opacity(0.7))
                                    }
                                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                                    .background(
                                        Capsule()
                                            .fill(Color.gray.opacity(0.5))
                                    )
                                    .disabled(false) // Habilitado para permitir el efecto de sacudida
                                    .transition(.opacity)
                                } else if eventService.isUserRegistered(eventId: event.id) {
                                    // Estado registrado en eventos activos/programados: píldora con dos botones
                                    ZStack {
                                        // Background
                                        Capsule()
                                            .fill(Color.dynamicSurface(theme: themeManager.currentTheme))
                                            .overlay(
                                                Capsule()
                                                    .stroke(Color.dynamicBorder(theme: themeManager.currentTheme).opacity(0.3), lineWidth: 1)
                                            )
                                        
                                        HStack(spacing: 0) {
                                            // Chat Button
                                            Button(action: {
                                                print("💬 Opening chat for event: \(event.title)")
                                                onChatTapped(event)
                                            }) {
                                                Image(systemName: "bubble.left")
                                                    .font(.system(size: 16, weight: .medium))
                                                    .foregroundColor(themeManager.currentTheme == .light ? Color.dynamicAccent(theme: themeManager.currentTheme) : Color(red: 0.96, green: 0.96, blue: 0.96))
                                                    .frame(width: 40, height: 44)
                                            }
                                            
                                            // Divider
                                            Rectangle()
                                                .fill(Color.dynamicBorder(theme: themeManager.currentTheme).opacity(0.5))
                                                .frame(width: 0.5, height: 24)
                                            
                                            // Cancel Button
                                            Button(action: {
                                                if !isLoading {
                                                    print("🚫 Cancelling event: \(event.title)")
                                                    isLoading = true
                                                    Task {
                                                        await eventService.cancelEvent(eventId: event.id)
                                                        try? await Task.sleep(nanoseconds: 500_000_000)
                                                        withAnimation(.easeInOut(duration: 0.3)) {
                                                            isLoading = false
                                                        }
                                                    }
                                                }
                                            }) {
                                                Text("Cancel")
                                                    .font(.system(size: 15, weight: .semibold))
                                                    .foregroundColor(themeManager.currentTheme == .light ? .red : Color(red: 0.96, green: 0.96, blue: 0.96))
                                                    .frame(maxWidth: .infinity, maxHeight: 44)
                                            }
                                        }
                                    }
                                    .frame(height: 44)
                                    .transition(.opacity)
                                } else {
                                    // Estado no registrado: botón único
                                    Button(action: {
                                        if event.participantsCount < event.maxParticipants && !isLoading {
                                            print("🎯 Joining event: \(event.title)")
                                            isLoading = true
                                            Task {
                                                await eventService.joinEvent(eventId: event.id)
                                                // Simular espera mínima para mostrar el efecto
                                                try? await Task.sleep(nanoseconds: 500_000_000) // 0.5 segundos
                                                withAnimation(.easeInOut(duration: 0.3)) {
                                                    isLoading = false
                                                }
                                            }
                                        }
                                    }) {
                                        HStack(spacing: 8) {
                                            Image(systemName: event.participantsCount >= event.maxParticipants ? "person.fill.xmark" : "person.fill.checkmark")
                                                .font(.system(size: 16))
                                            
                                            Text(buttonText)
                                                .font(.system(size: 16, weight: .semibold))
                                        }
                                        .foregroundColor(.white)
                                    }
                                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                                    .background(
                                        Capsule()
                                            .fill(
                                                event.participantsCount >= event.maxParticipants ?
                                                Color.gray.opacity(0.7) :
                                                Color.dynamicAccent(theme: themeManager.currentTheme)
                                            )
                                    )
                                    .disabled(event.participantsCount >= event.maxParticipants)
                                    .transition(.opacity)
                                }
                            }
                            .frame(width: 120, height: 46)
                            .animation(.easeInOut(duration: 0.3), value: eventService.isUserRegistered(eventId: event.id))
                            .animation(.easeInOut(duration: 0.3), value: isLoading)
                        }
                    }
                    .padding(.leading, 24)
                    .padding(.trailing, 20)
                    .padding(.vertical, 24)
                }
            }
        }
        .frame(height: 220)
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .offset(x: shakeOffset)
    }
    
    private func getCoachName(from description: String?) -> String {
        guard let description = description else { return "Coach" }
        if description.localizedCaseInsensitiveContains("john") {
            return "Coach John"
        } else if description.localizedCaseInsensitiveContains("bruce") {
            return "Coach Bruce K"
        } else if description.localizedCaseInsensitiveContains("david") {
            return "Coach David"
        } else if description.localizedCaseInsensitiveContains("caucaú") {
            return "Coach Caucaú"
        } else if description.localizedCaseInsensitiveContains("miami") {
            return "Coach David"
        }
        return "Coach"
    }
    
    private func formatEventDateFull(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d, h:mm a"
        return formatter.string(from: date)
    }
    
    // Computed properties para el botón
    private var buttonText: String {
        if eventService.isUserRegistered(eventId: event.id) {
            // Cuando está registrado, este texto ya no se usa (tiene botones separados)
            return "Registrado"
        } else if event.participantsCount >= event.maxParticipants {
            return "Full"
        } else {
            return "Unirse"
        }
    }
    
    // Funciones para el efecto de loading
    private func getOpacityForDot(index: Int) -> Double {
        let cycle = (Date().timeIntervalSince1970 * 4).truncatingRemainder(dividingBy: 5.0)
        let position = cycle < 2.5 ? cycle : 5.0 - cycle // Ida y vuelta más rápida
        let dotPosition = Double(index)
        let distance = abs(position - dotPosition)
        return max(0.3, 1.0 - (distance * 0.3))
    }
    
    private func getScaleForDot(index: Int) -> Double {
        let cycle = (Date().timeIntervalSince1970 * 4).truncatingRemainder(dividingBy: 5.0)
        let position = cycle < 2.5 ? cycle : 5.0 - cycle // Ida y vuelta más rápida
        let dotPosition = Double(index)
        let distance = abs(position - dotPosition)
        return max(0.8, 1.4 - (distance * 0.2))
    }
}

// MARK: - Event Card Skeleton
struct EventCardSkeleton: View {
    @EnvironmentObject var themeManager: ThemeManager
    @State private var isAnimating = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Título skeleton
            Rectangle()
                .fill(Color.dynamicTextSecondary(theme: themeManager.currentTheme).opacity(0.3))
                .frame(height: 24)
                .clipShape(RoundedRectangle(cornerRadius: 4))
            
            // Ubicación skeleton
            Rectangle()
                .fill(Color.dynamicTextSecondary(theme: themeManager.currentTheme).opacity(0.2))
                .frame(height: 16)
                .frame(width: 200)
                .clipShape(RoundedRectangle(cornerRadius: 4))
            
            // Coach skeleton
            Rectangle()
                .fill(Color.dynamicTextSecondary(theme: themeManager.currentTheme).opacity(0.2))
                .frame(height: 16)
                .frame(width: 150)
                .clipShape(RoundedRectangle(cornerRadius: 4))
            
            // Fecha y botón skeleton
            HStack {
                Rectangle()
                    .fill(Color.dynamicTextSecondary(theme: themeManager.currentTheme).opacity(0.2))
                    .frame(height: 16)
                    .frame(width: 120)
                    .clipShape(RoundedRectangle(cornerRadius: 4))
                
                Spacer()
                
                Rectangle()
                    .fill(Color.dynamicTextSecondary(theme: themeManager.currentTheme).opacity(0.3))
                    .frame(width: 100, height: 32)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.dynamicSurface(theme: themeManager.currentTheme))
        )
        .opacity(isAnimating ? 0.6 : 1.0)
        .animation(.easeInOut(duration: 1.0).repeatForever(autoreverses: true), value: isAnimating)
        .onAppear {
            isAnimating = true
        }
    }
}

// MARK: - Classes Content Views
struct ClassesContentView: View {
    @EnvironmentObject var classService: ClassService
    @EnvironmentObject var themeManager: ThemeManager
    @Binding var selectedDate: Date
    
    var body: some View {
        VStack(spacing: 0) {
            // Header fijo - No participa en el refresh
            VStack(alignment: .leading, spacing: 20) {
                // Title
                HStack {
                    Text("Session")
                        .font(.system(size: 34, weight: .bold))
                        .foregroundColor(Color.dynamicText(theme: themeManager.currentTheme))
                    Spacer()
                }
                .padding(.horizontal, 20)
                .padding(.top, 10)
                
                // Date Selector
                DateSelectorView(selectedDate: $selectedDate)
                    .padding(.horizontal, 20)
            }
            .background(Color.dynamicBackground(theme: themeManager.currentTheme))
            
            // Classes List - Solo esta parte se refresca
            RefreshableClassesList(selectedDate: $selectedDate)
        }
        .background(Color.dynamicBackground(theme: themeManager.currentTheme))
    }
    
    private var filteredSessions: [SessionWithClass] {
        let calendar = Calendar.current
        return classService.sessions.filter { session in
            calendar.isDate(session.session.startTime, inSameDayAs: selectedDate)
        }.sorted { $0.session.startTime < $1.session.startTime }
    }
}

// MARK: - Refreshable Classes List
struct RefreshableClassesList: View {
    @EnvironmentObject var classService: ClassService
    @EnvironmentObject var themeManager: ThemeManager
    @Binding var selectedDate: Date
    
    var body: some View {
        ScrollView {
            LazyVStack(spacing: 16) {
                ForEach(filteredSessions) { session in
                    ClassCardView(session: session)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 20)
        }
        .refreshable {
            // Solo refrescar las sesiones de la fecha seleccionada
            await classService.forceRefreshSessions(date: selectedDate)
        }
        .background(Color.dynamicBackground(theme: themeManager.currentTheme))
    }
    
    private var filteredSessions: [SessionWithClass] {
        let calendar = Calendar.current
        return classService.sessions.filter { session in
            calendar.isDate(session.session.startTime, inSameDayAs: selectedDate)
        }.sorted { $0.session.startTime < $1.session.startTime }
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
                // El índice 6 corresponde al día -1 (ayer) en el rango -7...7
                // Rango: [-7, -6, -5, -4, -3, -2, -1, 0, 1, 2, 3, 4, 5, 6, 7]
                // Índice:[ 0,  1,  2,  3,  4,  5,  6, 7, 8, 9,10,11,12,13,14]
                let yesterdayIndex = 6
                
                // Primer intento inmediato
                DispatchQueue.main.async {
                    proxy.scrollTo(yesterdayIndex, anchor: .leading)
                }
                
                // Segundo intento con delay para asegurar el posicionamiento
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        proxy.scrollTo(yesterdayIndex, anchor: .leading)
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
        // El primer día visible será 7 días atrás, pero ayer seguirá siendo prominente
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

struct ClassCardView: View {
    @EnvironmentObject var themeManager: ThemeManager
    let session: SessionWithClass
    @EnvironmentObject var classService: ClassService
    @State private var trainerImage: String = ""
    
    var body: some View {
        ZStack {
            // Fondo de la tarjeta
            RoundedRectangle(cornerRadius: 20)
                .fill(Color.dynamicSurface(theme: themeManager.currentTheme))
            
            HStack(spacing: 0) {
                // Línea de acento lateral
                Rectangle()
                    .fill(classAccentColor)
                    .frame(width: 6)
                
                // Contenido principal
                VStack(alignment: .leading, spacing: 12) {
                    // Class Name
                    Text(session.classInfo.name)
                        .font(.system(size: 22, weight: .bold))
                        .foregroundColor(Color.dynamicText(theme: themeManager.currentTheme))
                        .lineLimit(1)
                    
                    // Time and duration
                    HStack(spacing: 12) {
                        HStack(spacing: 4) {
                            Image(systemName: "clock")
                                .font(.system(size: 14))
                                .foregroundColor(Color.dynamicAccent(theme: themeManager.currentTheme))
                            Text(session.formattedTime)
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(Color.dynamicText(theme: themeManager.currentTheme))
                        }
                        
                        Text("• \(formattedDuration)")
                            .font(.system(size: 14))
                            .foregroundColor(Color.dynamicTextSecondary(theme: themeManager.currentTheme))
                    }
                    
                    // Badges
                    HStack(spacing: 6) {
                        Text(difficultyText.uppercased())
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundColor(Color(red: 0.18, green: 0.35, blue: 0.18))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 3)
                            .background(
                                RoundedRectangle(cornerRadius: 6)
                                    .fill(Color(red: 0.91, green: 0.96, blue: 0.91))
                            )
                        
                        Text(spotsText.uppercased())
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundColor(spotsTextColor)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 3)
                            .background(
                                RoundedRectangle(cornerRadius: 6)
                                    .fill(spotsBadgeBackground)
                            )
                    }
                    
                    // Instructor and action button
                    HStack(spacing: 0) {
                        HStack(spacing: 10) {
                            Image("trainer_placeholder")
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                                .frame(width: 50, height: 50)
                                .clipShape(Circle())
                                .overlay(
                                    Circle()
                                        .stroke(Color(red: 0.94, green: 0.94, blue: 0.94), lineWidth: 2)
                                )
                            
                            VStack(alignment: .leading, spacing: 2) {
                                Text(session.trainerName)
                                    .font(.system(size: 15, weight: .semibold))
                                    .foregroundColor(Color.dynamicText(theme: themeManager.currentTheme))
                                    .lineLimit(1)
                                
                            }
                        }
                        
                        Spacer()
                        
                        // Action button
                        Group {
                            if session.session.status == .completed {
                                HStack(spacing: 6) {
                                    Image(systemName: "lock.fill")
                                        .font(.system(size: 14, weight: .bold))
                                    Text("Complete")
                                        .font(.system(size: 16, weight: .bold))
                                }
                                .foregroundColor(.white)
                                .padding(.horizontal, 20)
                                .padding(.vertical, 12)
                                .background(
                                    RoundedRectangle(cornerRadius: 8)
                                        .fill(Color.dynamicTextSecondary(theme: themeManager.currentTheme))
                                )
                            } else if session.session.status == .cancelled {
                                Text("Cancelled")
                                    .font(.system(size: 12, weight: .semibold))
                                    .foregroundColor(.red)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 6)
                                    .background(
                                        RoundedRectangle(cornerRadius: 8)
                                            .fill(Color.red.opacity(0.1))
                                    )
                            } else if classService.isUserRegistered(sessionId: session.session.id) {
                                Button(action: {
                                    Task {
                                        await classService.cancelClassRegistration(sessionId: session.session.id, reason: "User cancelled from app")
                                    }
                                }) {
                                    if classService.cancellingClassIds.contains(session.session.id) {
                                        ProgressView()
                                            .progressViewStyle(CircularProgressViewStyle(tint: .red))
                                            .scaleEffect(0.8)
                                    } else {
                                        Text("Cancel")
                                            .font(.system(size: 16, weight: .bold))
                                    }
                                }
                                .foregroundColor(.red)
                                .padding(.horizontal, 20)
                                .padding(.vertical, 12)
                                .background(
                                    RoundedRectangle(cornerRadius: 8)
                                        .fill(Color.red.opacity(0.1))
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 8)
                                                .stroke(Color.red, lineWidth: 1)
                                        )
                                )
                                .disabled(classService.cancellingClassIds.contains(session.session.id))
                            } else if session.isFullyBooked {
                                Text("Full")
                                    .font(.system(size: 12, weight: .semibold))
                                    .foregroundColor(Color(red: 0.59, green: 0.65, blue: 0.65))
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 8)
                                    .background(
                                        RoundedRectangle(cornerRadius: 8)
                                            .fill(Color(red: 0.96, green: 0.96, blue: 0.96))
                                    )
                            } else {
                                Button(action: {
                                    Task {
                                        await classService.joinClass(sessionId: session.session.id)
                                    }
                                }) {
                                    if classService.joiningClassIds.contains(session.session.id) {
                                        ProgressView()
                                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                            .scaleEffect(0.8)
                                    } else {
                                        Text("Join")
                                            .font(.system(size: 16, weight: .bold))
                                    }
                                }
                                .foregroundColor(.white)
                                .padding(.horizontal, 20)
                                .padding(.vertical, 12)
                                .background(
                                    RoundedRectangle(cornerRadius: 8)
                                        .fill(Color.dynamicAccent(theme: themeManager.currentTheme))
                                )
                                .disabled(classService.joiningClassIds.contains(session.session.id))
                            }
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 16)
            }
            
            // Status indicator
            VStack {
                HStack {
                    Spacer()
                    Circle()
                        .fill(statusIndicatorColor)
                        .frame(width: 6, height: 6)
                }
                .padding(.trailing, 12)
                .padding(.top, 12)
                Spacer()
            }
        }
        .frame(maxWidth: .infinity)
        .clipShape(RoundedRectangle(cornerRadius: 20))
    }
    
    // MARK: - Computed Properties
    private var classAccentColor: Color {
        return Color.dynamicAccent(theme: themeManager.currentTheme)
    }
    
    private var formattedDuration: String {
        let minutes = session.classInfo.duration
        if minutes >= 60 {
            let hours = minutes / 60
            let remainingMinutes = minutes % 60
            if remainingMinutes == 0 {
                return "\(hours)h"
            } else {
                return "\(hours)h \(remainingMinutes)m"
            }
        } else {
            return "\(minutes)m"
        }
    }
    
    private var statusIndicatorColor: Color {
        if session.isFullyBooked {
            return .red
        } else if session.availableSpots <= 3 {
            return .orange
        } else {
            return .green
        }
    }
    
    private var difficultyText: String {
        switch session.classInfo.difficultyLevel {
        case .beginner: return "Beginner"
        case .intermediate: return "Intermediate"
        case .advanced: return "Advanced"
        }
    }
    
    private var spotsText: String {
        if session.isFullyBooked {
            return "Full"
        } else {
            return "\(session.availableSpots) spots"
        }
    }
    
    private var spotsTextColor: Color {
        if session.isFullyBooked {
            return Color(red: 0.4, green: 0.4, blue: 0.4)
        } else if session.availableSpots <= 3 {
            return Color(red: 0.78, green: 0.16, blue: 0.16)
        } else {
            return Color(red: 0.90, green: 0.38, blue: 0.0)
        }
    }
    
    private var spotsBadgeBackground: Color {
        if session.isFullyBooked {
            return Color(red: 0.96, green: 0.96, blue: 0.96)
        } else if session.availableSpots <= 3 {
            return Color(red: 1.0, green: 0.92, blue: 0.93)
        } else {
            return Color(red: 1.0, green: 0.95, blue: 0.88)
        }
    }
}

struct LoadingClassesView: View {
    @EnvironmentObject var themeManager: ThemeManager
    
    var body: some View {
        VStack(spacing: 20) {
            ProgressView()
                .progressViewStyle(CircularProgressViewStyle(tint: Color.dynamicText(theme: themeManager.currentTheme)))
                .scaleEffect(1.5)
            
            Text("Cargando clases...")
                .font(.system(size: 16))
                .foregroundColor(Color.dynamicText(theme: themeManager.currentTheme))
        }
    }
}

struct ErrorClassesView: View {
    @EnvironmentObject var themeManager: ThemeManager
    let message: String
    let onRetry: () -> Void
    
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 48))
                .foregroundColor(themeManager.currentTheme == .dark ? .orange : .red)
            
            Text("Error")
                .font(.system(size: 24, weight: .bold))
                .foregroundColor(Color.dynamicText(theme: themeManager.currentTheme))
            
            Text(message)
                .font(.system(size: 16))
                .foregroundColor(Color.dynamicTextSecondary(theme: themeManager.currentTheme))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
            
            Button("Reintentar") {
                onRetry()
            }
            .font(.system(size: 16, weight: .semibold))
            .foregroundColor(.white)
            .padding(.horizontal, 24)
            .padding(.vertical, 12)
            .background(Color.dynamicAccent(theme: themeManager.currentTheme))
            .clipShape(RoundedRectangle(cornerRadius: 8))
        }
    }
}

// MARK: - Color Extension for Hex Support
extension Color {
    init?(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            return nil
        }
        
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}

// MARK: - Chat Views

struct ChatFilterHeader: View {
    @Binding var selectedChatType: ChatType?
    let themeManager: ThemeManager
    
    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                // Opción "Todos"
                ChatFilterButton(
                    title: "Todos",
                    isSelected: selectedChatType == nil,
                    themeManager: themeManager
                ) {
                    selectedChatType = nil
                }
                
                // Filtros por tipo
                ForEach(ChatType.allCases, id: \.self) { chatType in
                    ChatFilterButton(
                        title: chatType.displayName,
                        isSelected: selectedChatType == chatType,
                        themeManager: themeManager
                    ) {
                        selectedChatType = chatType
                    }
                }
            }
            .padding(.horizontal, 16)
        }
        .padding(.vertical, 12)
        .background(Color.dynamicSurface(theme: themeManager.currentTheme))
    }
}

struct ChatFilterButton: View {
    let title: String
    let isSelected: Bool
    let themeManager: ThemeManager
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(isSelected ? .white : Color.dynamicText(theme: themeManager.currentTheme))
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(
                    RoundedRectangle(cornerRadius: 20)
                        .fill(isSelected ? Color.dynamicAccent(theme: themeManager.currentTheme) : Color.clear)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(Color.dynamicBorder(theme: themeManager.currentTheme), lineWidth: isSelected ? 0 : 1)
                )
        }
        .animation(.smooth(duration: 0.2), value: isSelected)
    }
}

struct LoadingChatsView: View {
    let themeManager: ThemeManager
    
    var body: some View {
        VStack(spacing: 20) {
            Spacer()
            
            ProgressView()
                .progressViewStyle(CircularProgressViewStyle(tint: Color.dynamicAccent(theme: themeManager.currentTheme)))
                .scaleEffect(1.2)
            
            Text("Cargando chats...")
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(Color.dynamicTextSecondary(theme: themeManager.currentTheme))
            
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

struct ErrorChatsView: View {
    let message: String
    let themeManager: ThemeManager
    let onRetry: () -> Void
    
    var body: some View {
        VStack(spacing: 20) {
            Spacer()
            
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 48))
                .foregroundColor(.orange)
            
            Text("Error al cargar chats")
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(Color.dynamicText(theme: themeManager.currentTheme))
            
            Text(message)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(Color.dynamicTextSecondary(theme: themeManager.currentTheme))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 20)
            
            Button(action: onRetry) {
                Text("Reintentar")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 12)
                    .background(Color.dynamicAccent(theme: themeManager.currentTheme))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            }
            
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

struct EmptyChatsView: View {
    let themeManager: ThemeManager
    
    var body: some View {
        VStack(spacing: 32) {
            Spacer()
            
            Image(systemName: "bubble.left.and.bubble.right")
                .font(.system(size: 80))
                .foregroundColor(Color.dynamicAccent(theme: themeManager.currentTheme).opacity(0.6))
            
            VStack(spacing: 12) {
                Text("Sin chats")
                    .font(.system(size: 24, weight: .bold))
                    .foregroundColor(Color.dynamicText(theme: themeManager.currentTheme))
                
                Text("Únete a eventos para comenzar a chatear")
                    .font(.system(size: 16))
                    .foregroundColor(Color.dynamicTextSecondary(theme: themeManager.currentTheme))
                    .multilineTextAlignment(.center)
            }
            
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.horizontal, 24)
    }
}

struct ChatRoomsList: View {
    let chatRooms: [ChatRoom]
    let themeManager: ThemeManager
    let onChatSelected: (ChatRoom) -> Void
    
    var body: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                ForEach(chatRooms) { chatRoom in
                    ChatRoomRow(
                        chatRoom: chatRoom,
                        themeManager: themeManager,
                        onTap: { onChatSelected(chatRoom) }
                    )
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
    }
}

struct ChatRoomRow: View {
    let chatRoom: ChatRoom
    let themeManager: ThemeManager
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                // Icono del chat
                Circle()
                    .fill(Color.dynamicAccent(theme: themeManager.currentTheme))
                    .frame(width: 48, height: 48)
                    .overlay(
                        Image(systemName: chatRoom.iconName)
                            .font(.system(size: 20, weight: .medium))
                            .foregroundColor(.white)
                    )
                
                // Información del chat
                VStack(alignment: .leading, spacing: 4) {
                    Text(chatRoom.displayName)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(Color.dynamicText(theme: themeManager.currentTheme))
                        .lineLimit(1)
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text(chatRoom.chatType.displayName)
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(Color.dynamicTextSecondary(theme: themeManager.currentTheme))
                        
                        if chatRoom.chatType == .event {
                            Text(chatRoom.formattedDate)
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(Color.dynamicAccent(theme: themeManager.currentTheme))
                        }
                    }
                }
                
                Spacer()
                
                // Indicador de navegación
                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(Color.dynamicTextSecondary(theme: themeManager.currentTheme))
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(Color.dynamicSurface(theme: themeManager.currentTheme))
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(PlainButtonStyle())
    }
}

#Preview {
    MainTabView()
        .environmentObject(AuthServiceDirect())
        .environmentObject(EventService())
        .environmentObject(ClassService())
        .environmentObject(ThemeManager())
} 
