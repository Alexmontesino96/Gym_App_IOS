//
//  Gym_APIApp.swift
//  Gym_API
//
//  Created by Alex Montesino on 7/14/25.
//

import SwiftUI
import SwiftData

@main
struct Gym_APIApp: App {
    @StateObject private var authService = AuthServiceDirect()
    @StateObject private var eventService = EventService()
    @StateObject private var classService = ClassService()
    @StateObject private var themeManager = ThemeManager()
    @StateObject private var oneSignalService = OneSignalService.shared
    
    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            User.self,
        ])
        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)

        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

    var body: some Scene {
        WindowGroup {
            Group {
                if authService.isAuthenticated {
                    MainTabView()
                        .environmentObject(authService)
                        .environmentObject(eventService)
                        .environmentObject(classService)
                        .environmentObject(themeManager)
                        .environmentObject(oneSignalService)
                } else {
                    LoginViewDirect()
                        .environmentObject(authService)
                        .environmentObject(themeManager)
                }
            }
            .preferredColorScheme(themeManager.currentTheme == .dark ? .dark : .light)
            .onAppear {
                // Inicializar OneSignal primero
                oneSignalService.initialize()
                
                authService.checkAuthStatus()
                eventService.authService = authService
                classService.authService = authService
            }
            .onChange(of: authService.isAuthenticated) {
                if authService.isAuthenticated {
                    // Configurar OneSignal con el usuario autenticado
                    if let user = authService.user {
                        oneSignalService.setExternalUserId(user.id)
                        oneSignalService.sendTag(key: "user_type", value: "authenticated")
                        oneSignalService.sendTag(key: "user_email", value: user.email)
                    }
                    
                    // Cargar trainers solo después de la autenticación
                    Task {
                        await classService.loadTrainers()
                    }
                } else {
                    // Logout de OneSignal cuando el usuario cierra sesión
                    oneSignalService.logout()
                }
            }
        }
        .modelContainer(sharedModelContainer)
    }
}
