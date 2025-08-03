//
//  AuthenticatedView.swift
//  Gym_API
//
//  Created by Alex Montesino on 7/14/25.
//

import SwiftUI

struct AuthenticatedView: View {
    @EnvironmentObject var authService: AuthServiceDirect
    @EnvironmentObject var themeManager: ThemeManager
    @StateObject private var gymService = GymService.shared
    
    var body: some View {
        let _ = print("🔍 AuthenticatedView.body evaluado")
        let _ = print("🔍 isAuthenticated: \(authService.isAuthenticated)")
        
        return Group {
            if authService.isAuthenticated {
                let _ = print("🔍 Usuario autenticado, verificando gym selection...")
                let _ = print("🔍 hasCompletedGymSelection: \(gymService.hasCompletedGymSelection)")
                let _ = print("🔍 hasSelectedGym: \(gymService.hasSelectedGym)")
                let _ = print("🔍 currentGym: \(gymService.currentGym?.name ?? "ninguno")")
                
                if gymService.hasCompletedGymSelection {
                    let _ = print("✅ Mostrando MainTabView porque hasCompletedGymSelection = true")
                    MainTabView()
                        .environmentObject(themeManager)
                } else {
                    let _ = print("✅ Mostrando GymSelectionView porque hasCompletedGymSelection = false")
                    GymSelectionView { selectedGym in
                        gymService.selectGym(selectedGym)
                    }
                    .environmentObject(themeManager)
                    .environmentObject(authService)
                }
            } else {
                let _ = print("🔍 Usuario NO autenticado, mostrando login")
                LoginViewDirect()
                    .environmentObject(themeManager)
            }
        }
        .animation(.easeInOut(duration: 0.3), value: authService.isAuthenticated)
        .animation(.easeInOut(duration: 0.3), value: gymService.hasCompletedGymSelection)
        .onAppear {
            setupGymService()
        }
        .onChange(of: authService.isAuthenticated) { newValue in
            if newValue {
                // Usuario recién autenticado, recargar gyms
                Task {
                    await gymService.getMyGyms(forceRefresh: true)
                }
            }
        }
    }
    
    private func setupGymService() {
        print("🔧 AuthenticatedView.setupGymService() iniciado")
        print("🔧 isAuthenticated: \(authService.isAuthenticated)")
        print("🔧 hasSelectedGym: \(gymService.hasSelectedGym)")
        print("🔧 hasCompletedGymSelection: \(gymService.hasCompletedGymSelection)")
        print("🔧 currentGym: \(gymService.currentGym?.name ?? "ninguno")")
        
        gymService.authService = authService
        
        // Si el usuario está autenticado, validar estado del gym
        if authService.isAuthenticated {
            // Si no hay gym seleccionado, cargar inmediatamente
            if !gymService.hasSelectedGym {
                print("🔧 No hay gym seleccionado, cargando gyms...")
                Task {
                    await gymService.getMyGyms(forceRefresh: true)
                }
            } else {
                print("🔧 Hay gym seleccionado, validando membresía...")
                // Si hay gym seleccionado, validar en background
                Task {
                    // Primero validar el gym actual
                    let isValid = await gymService.validateCurrentGymMembership()
                    if !isValid {
                        print("🔧 Gym no válido, limpiando selección...")
                        // El gym ya no es válido, limpiar selección
                        await MainActor.run {
                            gymService.clearGymSelection()
                        }
                    } else {
                        print("🔧 Gym válido pero NO debería completar selección automáticamente")
                        // IMPORTANTE: No marcar como completada la selección aquí
                        // El usuario debe pasar por el flujo de selección
                    }
                }
            }
        }
        
        print("🔧 setupGymService() terminado")
    }
}

#Preview {
    AuthenticatedView()
        .environmentObject(AuthServiceDirect())
        .environmentObject(ThemeManager())
} 