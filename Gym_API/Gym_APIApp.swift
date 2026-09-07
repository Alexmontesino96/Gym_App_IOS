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
            rootView
                .withServiceContainer()
                .trainingMotionEnvironment(forced: forcedReduceMotion)
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

                    // Después de OneSignal: encadena su delegado para enrutar los deep links de
                    // entrenamiento y la acción «Add 30s» del cronómetro de descanso.
                    TrainingNotificationRouter.shared.install()

                    // Verificar estado de autenticación
                    serviceContainer.authService.checkAuthStatus()
                }
        }
        // .modelContainer(sharedModelContainer) // Comentado temporalmente
    }

    /// `-reduce-motion 1` de la galería de revisión. En Release siempre es falso: el ajuste del
    /// sistema es el único que cuenta.
    private var forcedReduceMotion: Bool {
        #if DEBUG
        return TrainingGalleryScenario.forcesReduceMotion()
        #else
        return false
        #endif
    }

    /// Raíz de la app. En DEBUG, `-training-gallery <pantalla>` arranca directamente en una
    /// pantalla del módulo de entrenamiento con los fixtures del contrato y sin login, que es lo
    /// que usa `PLAN_MODULO_ENTRENAMIENTO_REPORTES/tools/screenshots.sh` para la revisión visual.
    @ViewBuilder
    private var rootView: some View {
        #if DEBUG
        if let scenario = TrainingGalleryScenario.fromLaunchArguments() {
            TrainingGalleryView(scenario: scenario)
        } else {
            AuthenticatedView()
        }
        #else
        AuthenticatedView()
        #endif
    }
}
