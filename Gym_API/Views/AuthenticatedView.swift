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
    @StateObject private var profileService = UserProfileService.shared
    
    @State private var showingProfileCompletion = false
    @State private var profileCheckCompleted = false
    
    var body: some View {
        let _ = print("🔍 AuthenticatedView.body evaluado")
        let _ = print("🔍 isAuthenticated: \(authService.isAuthenticated)")
        
        return Group {
            if authService.isAuthenticated {
                let _ = print("🔍 Usuario autenticado, verificando profile completion...")
                
                if profileCheckCompleted {
                    if showingProfileCompletion {
                        let _ = print("✅ Mostrando ProfileCompletionView")
                        ProfileCompletionView {
                            showingProfileCompletion = false
                            // Después de completar el perfil, continuar con gym selection
                        }
                        .environmentObject(authService)
                        .environmentObject(themeManager)
                    } else {
                        let _ = print("🔍 Profile completo, verificando gym selection...")
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
                    }
                } else {
                    // Mostrar loading mientras verificamos el perfil
                    VStack(spacing: 16) {
                        ProgressView()
                            .scaleEffect(1.2)
                            .tint(.blue)
                        
                        Text("Checking your profile...")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color(.systemBackground))
                }
            } else {
                let _ = print("🔍 Usuario NO autenticado, mostrando login")
                LoginViewDirect()
                    .environmentObject(themeManager)
            }
        }
        .animation(.easeInOut(duration: 0.3), value: authService.isAuthenticated)
        .animation(.easeInOut(duration: 0.3), value: gymService.hasCompletedGymSelection)
        .animation(.easeInOut(duration: 0.3), value: showingProfileCompletion)
        .onAppear {
            setupServices()
            checkUserProfile()
        }
        .onChange(of: authService.isAuthenticated) { newValue in
            if newValue {
                // Usuario recién autenticado, verificar perfil y recargar gyms con auto-selección
                checkUserProfile()
                Task {
                    await gymService.getMyGyms(forceRefresh: true, autoSelectIfSingle: true)
                }
            } else {
                // Reset states when user logs out
                profileCheckCompleted = false
                showingProfileCompletion = false
            }
        }
    }
    
    private func setupServices() {
        print("🔧 AuthenticatedView.setupServices() iniciado")
        print("🔧 isAuthenticated: \(authService.isAuthenticated)")
        print("🔧 hasSelectedGym: \(gymService.hasSelectedGym)")
        print("🔧 hasCompletedGymSelection: \(gymService.hasCompletedGymSelection)")
        print("🔧 currentGym: \(gymService.currentGym?.name ?? "ninguno")")
        
        gymService.authService = authService
        profileService.authService = authService
        
        // Si el usuario está autenticado, validar estado del gym
        if authService.isAuthenticated {
            // Si no se ha completado la selección de gym, cargar con auto-selección
            if !gymService.hasCompletedGymSelection {
                print("🔧 Selección de gym no completada, cargando gyms con auto-selección...")
                Task {
                    await gymService.getMyGyms(forceRefresh: true, autoSelectIfSingle: true)
                }
            } else if gymService.hasSelectedGym {
                print("🔧 Gym ya seleccionado y completado, validando membresía...")
                // Si hay gym seleccionado y completado, validar en background
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
                        print("🔧 Gym válido y selección completada")
                    }
                }
            }
        }
        
        print("🔧 setupServices() terminado")
    }
    
    private func checkUserProfile() {
        guard authService.isAuthenticated else {
            print("🔧 Usuario no autenticado, saltando verificación de perfil")
            return
        }
        
        print("🔧 Verificando completitud del perfil...")
        Task {
            // Cargar el perfil del usuario
            await profileService.fetchUserProfile()
            
            await MainActor.run {
                // Log detallado del perfil recibido
                if let profile = profileService.userProfile {
                    print("🔧 [AuthenticatedView] Perfil cargado desde servidor:")
                    print("🔧 [AuthenticatedView] - ID: \(profile.id)")
                    print("🔧 [AuthenticatedView] - Email: \(profile.email)")
                    print("🔧 [AuthenticatedView] - FirstName: '\(profile.firstName)'")
                    print("🔧 [AuthenticatedView] - LastName: '\(profile.lastName)'")
                    print("🔧 [AuthenticatedView] - Height: \(profile.height?.description ?? "nil")")
                    print("🔧 [AuthenticatedView] - Weight: \(profile.weight?.description ?? "nil")")
                    print("🔧 [AuthenticatedView] - BirthDate: \(profile.birthDate?.description ?? "nil")")
                    print("🔧 [AuthenticatedView] - Bio: \(profile.bio?.description ?? "nil")")
                    print("🔧 [AuthenticatedView] - Auth0ID: \(profile.auth0Id)")
                    print("🔧 [AuthenticatedView] - CreatedAt: \(profile.createdAt)")
                    print("🔧 [AuthenticatedView] - UpdatedAt: \(profile.updatedAt)")
                } else {
                    print("🔧 [AuthenticatedView] ❌ No se pudo cargar el perfil del usuario")
                }
                
                let isComplete = profileService.isProfileComplete()
                print("🔧 Profile complete: \(isComplete)")
                
                showingProfileCompletion = !isComplete
                profileCheckCompleted = true
                
                print("🔧 showingProfileCompletion: \(showingProfileCompletion)")
                print("🔧 profileCheckCompleted: \(profileCheckCompleted)")
            }
        }
    }
}

#Preview {
    AuthenticatedView()
        .environmentObject(AuthServiceDirect())
        .environmentObject(ThemeManager())
} 
