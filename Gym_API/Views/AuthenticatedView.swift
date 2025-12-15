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
    @EnvironmentObject var workspaceContext: WorkspaceContextService
    @StateObject private var gymService = GymService.shared
    @StateObject private var profileService = UserProfileService.shared
    @StateObject private var onboardingManager = OnboardingManager()

    @State private var showingProfileCompletion = false
    @State private var profileCheckCompleted = false
    @State private var initializationError: String?
    @State private var showOnboarding = false
    @State private var contextLoaded = false
    
    var body: some View {
        let _ = print("🔍 AuthenticatedView.body evaluado")
        let _ = print("🔍 isAuthenticated: \(authService.isAuthenticated)")
        
        return Group {
            if let error = initializationError {
                // Mostrar error de conexión
                VStack(spacing: 20) {
                    Image(systemName: "wifi.slash")
                        .font(.system(size: 60))
                        .foregroundColor(.red.opacity(0.6))

                    Text("Error de Conexión")
                        .font(.title)
                        .fontWeight(.bold)

                    Text(error)
                        .font(.body)
                        .multilineTextAlignment(.center)
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 40)

                    Button(action: {
                        // Reintentar carga de perfil
                        initializationError = nil
                        profileCheckCompleted = false
                        checkUserProfile()
                    }) {
                        Text("Reintentar")
                            .font(.headline)
                            .foregroundColor(.white)
                            .frame(width: 200, height: 50)
                            .background(Color.blue)
                            .cornerRadius(10)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color(.systemBackground))
                .transition(.opacity)
            } else if authService.isAuthenticated {
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
                            if !contextLoaded {
                                // Mostrar loading mientras carga el contexto
                                let _ = print("⏳ Cargando workspace context...")
                                VStack(spacing: 16) {
                                    ProgressView()
                                        .scaleEffect(1.2)
                                        .tint(.blue)

                                    Text("Loading workspace...")
                                        .font(.system(size: 16, weight: .medium))
                                        .foregroundColor(.secondary)
                                }
                                .frame(maxWidth: .infinity, maxHeight: .infinity)
                                .background(Color(.systemBackground))
                            } else {
                                // Routing based on workspace type
                                let _ = print("✅ Context loaded - Workspace type: \(workspaceContext.workspaceType)")
                                let _ = print("✅ Is Personal Trainer: \(workspaceContext.isPersonalTrainer)")

                                if workspaceContext.isPersonalTrainer {
                                    let _ = print("✅ Mostrando TrainerMainTabView para Personal Trainer")
                                    TrainerMainTabView()
                                        .environmentObject(themeManager)
                                } else {
                                    let _ = print("✅ Mostrando MainTabView para Gym tradicional")
                                    MainTabView()
                                        .environmentObject(themeManager)
                                }
                            }
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
                let _ = print("🔍 Usuario NO autenticado - Mostrando LoginViewDirect")
                // Mostrar pantalla de login directamente
                LoginViewDirect()
                    .environmentObject(authService)
                    .environmentObject(themeManager)
            }
        }
        .animation(.easeInOut(duration: 0.3), value: authService.isAuthenticated)
        .animation(.easeInOut(duration: 0.3), value: gymService.hasCompletedGymSelection)
        .animation(.easeInOut(duration: 0.3), value: showingProfileCompletion)
        .animation(.easeInOut(duration: 0.3), value: contextLoaded)
        .onAppear {
            setupServices()
            checkUserProfile()
            // Solo mostrar onboarding completo en primer lanzamiento (isFirstLaunch)
            // En logout, se muestra LoginViewDirect directamente
            if !authService.isAuthenticated && onboardingManager.isFirstLaunch {
                onboardingManager.checkOnboardingStatus()
                showOnboarding = onboardingManager.showOnboarding
            }
        }
        .onChange(of: authService.isAuthenticated) { newValue in
            if newValue {
                // Usuario recién autenticado
                // IMPORTANTE: NO cerrar onboarding si está en progreso (nuevo flujo Auth-First)
                // Solo cerrar si NO es primer lanzamiento (i.e., login normal)
                if !onboardingManager.isFirstLaunch || !onboardingManager.showOnboarding {
                    // Login normal (no onboarding), cerrar cualquier onboarding
                    showOnboarding = false
                    onboardingManager.showOnboarding = false
                }
                // Si está en onboarding de primer lanzamiento, dejar que continúe

                // Verificar perfil y recargar gyms con auto-selección
                checkUserProfile()
                Task {
                    await gymService.getMyGyms(forceRefresh: true, autoSelectIfSingle: true)
                }
            } else {
                // Reset states when user logs out
                profileCheckCompleted = false
                showingProfileCompletion = false
                contextLoaded = false

                // NO mostrar onboarding en logout - solo en primer lanzamiento
                // El LoginViewDirect se muestra directamente en el body
                showOnboarding = false
                onboardingManager.showOnboarding = false
            }
        }
        .onChange(of: gymService.hasCompletedGymSelection) { newValue in
            if newValue {
                // When gym selection is completed, load workspace context
                Task {
                    await loadWorkspaceContext()
                }
            }
        }
        .onChange(of: onboardingManager.showOnboarding) { newValue in
            // Mostrar onboarding según OnboardingManager
            // IMPORTANTE: En nuevo flujo Auth-First, el usuario puede estar autenticado
            // durante el onboarding, así que NO verificar !authService.isAuthenticated
            showOnboarding = newValue
        }
        // Present onboarding on first launch (new Auth-First flow: user authenticates during onboarding)
        .fullScreenCover(isPresented: $showOnboarding) {
            MainOnboardingView()
                .environmentObject(onboardingManager)
                .environmentObject(themeManager)
                .environmentObject(authService)
                .environmentObject(gymService)
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
                        // Load workspace context if not already loaded
                        if !contextLoaded {
                            await loadWorkspaceContext()
                        }
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
            // Cargar el perfil del usuario (evitar recargas innecesarias)
            await profileService.fetchUserProfileIfStale()

            await MainActor.run {
                // Verificar si hubo error de red al cargar
                if profileService.lastLoadAttemptFailed {
                    print("⚠️ [AuthenticatedView] Error al cargar perfil - mostrando error de conexión")

                    // No forzar ProfileCompletion, mostrar error de conexión
                    initializationError = "No se pudo cargar tu perfil. Verifica tu conexión a internet e intenta de nuevo."
                    showingProfileCompletion = false
                    profileCheckCompleted = true
                    return
                }

                // Si se cargó correctamente, verificar si está completo
                if let profile = profileService.userProfile {
                    print("🔧 [AuthenticatedView] Perfil cargado desde servidor:")
                    print("🔧 [AuthenticatedView] - ID: \(profile.id)")
                    print("🔧 [AuthenticatedView] - Email: \(profile.email ?? "Sin email")")
                    print("🔧 [AuthenticatedView] - FirstName: '\(profile.firstName)'")
                    print("🔧 [AuthenticatedView] - LastName: '\(profile.lastName)'")
                    print("🔧 [AuthenticatedView] - Height: \(profile.height?.description ?? "nil")")
                    print("🔧 [AuthenticatedView] - Weight: \(profile.weight?.description ?? "nil")")
                    print("🔧 [AuthenticatedView] - BirthDate: \(profile.birthDate?.description ?? "nil")")
                    print("🔧 [AuthenticatedView] - Bio: \(profile.bio?.description ?? "nil")")
                    print("🔧 [AuthenticatedView] - Auth0ID: \(profile.auth0Id)")
                    print("🔧 [AuthenticatedView] - CreatedAt: \(profile.createdAt?.description ?? "nil")")
                    print("🔧 [AuthenticatedView] - UpdatedAt: \(profile.updatedAt?.description ?? "nil")")

                    let isComplete = profileService.isProfileComplete()
                    print("🔧 Profile complete: \(isComplete)")

                    showingProfileCompletion = !isComplete
                    profileCheckCompleted = true
                } else {
                    // userProfile es nil y NO fue error de red = perfil realmente incompleto
                    print("🔧 [AuthenticatedView] ❌ userProfile es nil - perfil incompleto")
                    showingProfileCompletion = true
                    profileCheckCompleted = true
                }

                print("🔧 showingProfileCompletion: \(showingProfileCompletion)")
                print("🔧 profileCheckCompleted: \(profileCheckCompleted)")
            }
        }
    }

    private func loadWorkspaceContext() async {
        print("🏢 Loading workspace context...")
        await workspaceContext.fetchContext()

        await MainActor.run {
            contextLoaded = true
            print("✅ Workspace context loaded successfully")
            print("🏢 Workspace type: \(workspaceContext.workspaceType)")
            print("🏢 Is Personal Trainer: \(workspaceContext.isPersonalTrainer)")
        }
    }
}

#Preview {
    AuthenticatedView()
        .environmentObject(AuthServiceDirect())
        .environmentObject(ThemeManager())
} 
