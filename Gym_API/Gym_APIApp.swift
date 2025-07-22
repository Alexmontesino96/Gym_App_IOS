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
                } else {
                    LoginViewDirect()
                        .environmentObject(authService)
                        .environmentObject(themeManager)
                }
            }
            .preferredColorScheme(themeManager.currentTheme == .dark ? .dark : .light)
            .onAppear {
                authService.checkAuthStatus()
                eventService.authService = authService
                classService.authService = authService
            }
            .onChange(of: authService.isAuthenticated) { isAuthenticated in
                if isAuthenticated {
                    // Cargar trainers solo después de la autenticación
                    Task {
                        await classService.loadTrainers()
                    }
                }
            }
        }
        .modelContainer(sharedModelContainer)
    }
}
