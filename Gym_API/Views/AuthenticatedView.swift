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
    @State private var appReady = false
    @State private var hasCheckedAuth = false
    @State private var needsManualGymSelection = false
    
    var body: some View {
        return Group {
            if let error = initializationError {
                // Error de conexión
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
                        initializationError = nil
                        appReady = false
                        hasCheckedAuth = false
                        profileCheckCompleted = false
                        startFullInitialization()
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
            } else if !appReady {
                // Show loading screen until EVERYTHING is ready
                // (auth check, profile, gym selection, workspace context)
                if hasCheckedAuth && !authService.isAuthenticated {
                    // Not authenticated → landing page
                    OnboardingScreenView()
                        .environmentObject(authService)
                        .environmentObject(themeManager)
                } else if showingProfileCompletion {
                    // Profile incomplete → completion flow
                    ProfileCompletionView {
                        showingProfileCompletion = false
                        startFullInitialization()
                    }
                    .environmentObject(authService)
                    .environmentObject(themeManager)
                } else if needsManualGymSelection {
                    // Multiple gyms → user must choose
                    GymSelectionView { selectedGym in
                        gymService.selectGym(selectedGym)
                        startFullInitialization()
                    }
                    .environmentObject(themeManager)
                    .environmentObject(authService)
                } else {
                    // Loading screen for everything else
                    AppLoadingView()
                        .environmentObject(themeManager)
                }
            } else {
                // Everything ready → show app
                rootForCurrentUser
            }
        }
        .animation(.easeInOut(duration: 0.3), value: hasCheckedAuth)
        .animation(.easeInOut(duration: 0.3), value: authService.isAuthenticated)
        .animation(.easeInOut(duration: 0.3), value: appReady)
        .animation(.easeInOut(duration: 0.3), value: showingProfileCompletion)
        .onAppear {
            setupServices()
            if !authService.isAuthenticated && onboardingManager.isFirstLaunch {
                onboardingManager.checkOnboardingStatus()
                showOnboarding = onboardingManager.showOnboarding
            }
            startFullInitialization()
        }
        .onChange(of: authService.isAuthenticated) { newValue in
            if newValue {
                if !onboardingManager.isFirstLaunch || !onboardingManager.showOnboarding {
                    showOnboarding = false
                    onboardingManager.showOnboarding = false
                }
                // Re-run full initialization
                startFullInitialization()
            } else {
                // Reset on logout
                profileCheckCompleted = false
                showingProfileCompletion = false
                contextLoaded = false
                appReady = false
                hasCheckedAuth = false
                needsManualGymSelection = false
                showOnboarding = false
                onboardingManager.showOnboarding = false
                // Show loading briefly then reveal login
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    hasCheckedAuth = true
                }
            }
        }
        .onChange(of: gymService.hasCompletedGymSelection) { newValue in
            // If gym was just selected (from GymSelectionView), restart init
            if newValue && !appReady {
                needsManualGymSelection = false
                startFullInitialization()
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
    
    // MARK: - Root Routing

    /// Raíz de la app, decidida por DOS ejes: tipo de workspace y rol del usuario en él.
    ///
    /// El entrenador personal y sus clientes comparten el mismo gym, así que el tipo de workspace
    /// por sí solo no los distingue: antes de esto, un cliente aterrizaba en la vista del entrenador.
    ///
    /// El rol se lee de `GymInfo.userRoleInGym` (viene de `GET /gyms/my`, y `GymService` lo decodifica
    /// con un JSONDecoder plano). NO se usa `user_context.role` de `/context/workspace`: ese campo
    /// devuelve siempre "MEMBER" porque el middleware de tenant nunca llega a poblarlo.
    ///
    /// Ante la duda (gym sin cargar o rol vacío) se cae al camino menos privilegiado, el de cliente.
    @ViewBuilder
    private var rootForCurrentUser: some View {
        // Ojo con el respaldo: el backend NO serializa `is_personal_trainer` en /gyms/my
        // (en app/schemas/gym.py es una @property de Python sin @computed_field), así que
        // `GymInfo.isPersonalTrainer` llega siempre nil. `type` sí viaja, y es el que vale.
        let gymType = gymService.currentGym?.type?.lowercased()
        let isPersonalTrainerWorkspace = workspaceContext.isPersonalTrainer
            || (gymService.currentGym?.isPersonalTrainer ?? false)
            || gymType == "personal_trainer"
        let roleInGym = gymService.currentGym?.userRoleInGym

        if isPersonalTrainerWorkspace {
            if RolePermissions.isWorkspaceStaff(roleInGym) {
                // Entrenador, asistente o dueño del espacio de trabajo
                TrainerMainTabView()
                    .environmentObject(themeManager)
            } else {
                // Cliente del entrenador personal
                ClientMainTabView()
                    .environmentObject(themeManager)
            }
        } else {
            // Gimnasio tradicional: sin cambios
            MainTabView()
                .environmentObject(themeManager)
        }
    }

    // MARK: - Full Initialization (single pipeline)

    private func startFullInitialization() {
        Task {
            // Step 1: Check if user has a valid token
            let isAuthenticated = authService.isAuthenticated

            await MainActor.run {
                hasCheckedAuth = true
            }

            guard isAuthenticated else { return }

            // Step 2+3: Load profile AND gyms IN PARALLEL (they don't depend on each other)
            // Use cache when available (don't force refresh on every launch)
            async let profileTask: () = profileService.fetchUserProfileIfStale()
            async let gymsTask: () = gymService.getMyGyms(forceRefresh: false, autoSelectIfSingle: true)
            let (_, _) = await (profileTask, gymsTask)

            // Check profile result
            await MainActor.run {
                if profileService.lastLoadAttemptFailed {
                    initializationError = "No se pudo cargar tu perfil. Verifica tu conexión a internet e intenta de nuevo."
                    profileCheckCompleted = true
                    return
                }

                if let _ = profileService.userProfile {
                    let isComplete = profileService.isProfileComplete()
                    showingProfileCompletion = !isComplete
                    profileCheckCompleted = true
                } else {
                    showingProfileCompletion = true
                    profileCheckCompleted = true
                }
            }

            guard !showingProfileCompletion else { return }

            // If auto-select didn't work (multiple gyms), show manual selection
            guard gymService.hasCompletedGymSelection else {
                await MainActor.run {
                    needsManualGymSelection = true
                }
                return
            }

            // Step 4+5: Load workspace context AND home data IN PARALLEL
            async let wsTask: () = loadWorkspaceContext()
            async let homeTask: () = preloadHomeData()
            let (_, _) = await (wsTask, homeTask)

            // Step 6: Mark app as ready — this will dismiss loading and show Home
            await MainActor.run {
                withAnimation(.easeInOut(duration: 0.3)) {
                    appReady = true
                }
            }
        }
    }

    private func setupServices() {
        // Only configure auth references — NO network calls here
        // All network calls happen in startFullInitialization()
        gymService.authService = authService
        profileService.authService = authService
    }
    
    // checkUserProfile removed — handled by startFullInitialization step 2

    private func preloadHomeData() async {
        let isPersonalTrainerWorkspace = workspaceContext.isPersonalTrainer
            || gymService.currentGym?.type?.lowercased() == "personal_trainer"
        let eventService = ServiceContainer.shared.eventService
        let classService = ServiceContainer.shared.classService
        let userStatsService = UserStatsService.shared
        let storyService = ServiceContainer.shared.storyService
        let activityService = ServiceContainer.shared.activityService
        let nutritionService = NutritionService.shared

        // Configure services once
        eventService.authService = authService
        classService.authService = authService
        userStatsService.authService = authService
        userStatsService.gymService = gymService
        storyService.authService = authService
        nutritionService.configure(authService: authService, gymService: gymService)

        // CRITICAL: Load only what's visible on Home first screen
        await withTaskGroup(of: Void.self) { group in
            // Visible immediately on Home
            group.addTask { await eventService.fetchEvents() }
            group.addTask { await classService.loadSessionsForDateIfNeeded(date: Date()) }
            // Historias y actividad viven en módulos que nacen desactivados en los espacios
            // de entrenador personal, así que allí estas dos llamadas son dos 403 garantizados
            // en cada arranque. Ninguna pantalla del cliente las consume ya.
            if !isPersonalTrainerWorkspace {
                group.addTask { await storyService.fetchStoriesFeed() }
                group.addTask { await activityService.fetchAllData() }
            }
            group.addTask { await userStatsService.fetchDashboardSummary() }
            group.addTask { await nutritionService.getDashboard() }
        }

        // DEFERRED: Load after app is shown (not visible on first screen)
        Task.detached(priority: .utility) { [authService, gymService] in
            let eventService = await ServiceContainer.shared.eventService
            let classService = await ServiceContainer.shared.classService
            let userStatsService = await UserStatsService.shared

            await eventService.fetchUserParticipations()
            await classService.fetchMyClasses()
            await classService.loadTrainers()
            await userStatsService.fetchComprehensiveStats()
            await userStatsService.fetchWorkoutHistory()
        }

        // Mark that home data is preloaded so HomeView skips re-loading
        await MainActor.run {
            UserDefaults.standard.set(true, forKey: "home_data_preloaded")
        }

        print("✅ [AuthenticatedView] Home data preloaded")
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
