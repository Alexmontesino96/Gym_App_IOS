//
//  Gym_APIApp.swift
//  Gym_API
//
//  Created by Alex Montesino on 7/14/25.
//

import SwiftUI

@main
struct Gym_APIApp: App {
    let serviceContainer = ServiceContainer.shared
    
    // Temporalmente comentado - usando AuthUser en lugar de User de SwiftData
    // para evitar error "failed to find a currently active container for User"
    /*
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
    */

    var body: some Scene {
        WindowGroup {
            AuthenticatedView()
                .withServiceContainer()
                .preferredColorScheme(serviceContainer.themeManager.currentTheme == .dark ? .dark : .light)
                .onAppear {
                    // Deja escrito en la consola contra qué backend habla la app. En DEBUG avisa
                    // además si `API_BASE_URL_OVERRIDE` está apuntando a otro sitio: un override
                    // olvidado explica media hora de depuración.
                    AppEnvironment.validateConfiguration()

                    // Vigilancia de red: el outbox de entrenamiento se drena cuando vuelve.
                    NetworkMonitor.shared.start()

                    // Inicializar OneSignal
                    serviceContainer.oneSignalService.initialize()

                    // Verificar estado de autenticación
                    serviceContainer.authService.checkAuthStatus()
                }
        }
        // .modelContainer(sharedModelContainer) // Comentado temporalmente
    }
}
