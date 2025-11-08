import SwiftUI
import Combine

// MARK: - Service Container
/// Contenedor centralizado para la inyección de dependencias
/// Elimina la necesidad de configurar manualmente authService en múltiples servicios
@MainActor
class ServiceContainer: ObservableObject {
    // MARK: - Singleton
    static let shared = ServiceContainer()
    
    // MARK: - Core Services
    let authService: AuthServiceDirect
    let themeManager: ThemeManager
    let oneSignalService: OneSignalService
    
    // MARK: - Feature Services
    let membershipService: MembershipService
    let gymService: GymService
    let eventService: EventService
    let eventPaymentService: EventPaymentService
    let classService: ClassService
    let profileService: UserProfileService
    let unifiedImageService = UnifiedImageService.shared // Singleton, no need to initialize
    let userStatsService: UserStatsService
    let directMessageService: DirectMessageService
    let surveyService: SurveyService
    let workspaceContextService: WorkspaceContextService
    let storyService: StoryService

    // MARK: - Published Properties
    @Published var isInitialized = false
    @Published var initializationError: String?
    
    // MARK: - Private Properties
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Initialization
    private init() {
        do {
            // Initialize core services first with error handling
            self.authService = AuthServiceDirect()
            self.themeManager = ThemeManager()
            self.oneSignalService = OneSignalService.shared
            
            // Initialize feature services
            self.membershipService = MembershipService.shared
            self.gymService = GymService.shared
            self.eventService = EventService()
            self.eventPaymentService = EventPaymentService.shared
            self.classService = ClassService()
            self.profileService = UserProfileService.shared
            // UnifiedImageService is a singleton, already initialized
            self.userStatsService = UserStatsService.shared
            self.directMessageService = DirectMessageService()
            self.surveyService = SurveyService()
            self.workspaceContextService = WorkspaceContextService.shared
            self.storyService = StoryService()

            // Configure dependencies automatically
            setupDependencies()
            
            // Setup observers
            setupObservers()
            
            print("✅ ServiceContainer inicializado con todas las dependencias configuradas")
        } catch {
            print("❌ Error crítico al inicializar ServiceContainer: \(error)")
            self.initializationError = "Error al inicializar servicios: \(error.localizedDescription)"
            // Inicializar servicios mínimos para evitar crash
            fatalError("No se pudo inicializar ServiceContainer: \(error)")
        }
    }
    
    // MARK: - Dependency Configuration
    
    /// Configura automáticamente las dependencias entre servicios
    private func setupDependencies() {
        // Configure AuthService dependencies for all services that need it
        membershipService.authService = authService
        gymService.authService = authService
        eventService.authService = authService
        eventPaymentService.authService = authService
        classService.authService = authService
        profileService.authService = authService
        unifiedImageService.configure(authService: authService)
        userStatsService.authService = authService
        directMessageService.authService = authService
        surveyService.authService = authService
        surveyService.gymService = gymService
        workspaceContextService.authService = authService
        storyService.authService = authService

        print("🔧 Dependencias de AuthService configuradas automáticamente en todos los servicios")

        // Mark as initialized
        isInitialized = true

        // Configure HTTP client auth dependency
        HTTPClient.shared.authService = authService
    }
    
    // MARK: - Observer Setup
    
    /// Configura observadores para cambios en el estado de autenticación
    private func setupObservers() {
        // Observe authentication state changes
        authService.$isAuthenticated
            .sink { [weak self] isAuthenticated in
                self?.handleAuthenticationStateChange(isAuthenticated)
            }
            .store(in: &cancellables)
        
        // Observe user changes
        authService.$user
            .sink { [weak self] user in
                self?.handleUserChange(user)
            }
            .store(in: &cancellables)
    }
    
    // MARK: - Event Handlers
    
    /// Maneja cambios en el estado de autenticación
    private func handleAuthenticationStateChange(_ isAuthenticated: Bool) {
        print("🔄 ServiceContainer detectó cambio de autenticación: \(isAuthenticated)")
        
        if isAuthenticated {
            // Configure OneSignal with authenticated user
            if let user = authService.user {
                oneSignalService.setExternalUserId(user.id)
                oneSignalService.sendTag(key: "user_type", value: "authenticated")
                oneSignalService.sendTag(key: "user_email", value: user.email)
                print("✅ OneSignal configurado para usuario autenticado")
            }
            
            // Load initial data for authenticated user
            Task {
                await loadInitialData()
            }
        } else {
            // Logout from OneSignal when user logs out
            oneSignalService.logout()
            print("🚪 OneSignal logout completado")
            
            // Clear any cached data
            clearUserData()
        }
    }
    
    /// Maneja cambios en el usuario
    private func handleUserChange(_ user: AuthUser?) {
        guard let user = user else { return }
        
        print("👤 ServiceContainer detectó cambio de usuario: \(user.email)")
        
        // Update OneSignal user info
        oneSignalService.setExternalUserId(user.id)
        oneSignalService.sendTag(key: "user_email", value: user.email)
    }
    
    // MARK: - Data Management
    
    /// Carga datos iniciales después de la autenticación
    private func loadInitialData() async {
        print("📊 Cargando datos iniciales...")

        async let membershipTask = membershipService.getMyMembershipStatus()
        // NOTA: No cargar gyms aquí para no interferir con la lógica de auto-selección en AuthenticatedView
        // async let gymTask = gymService.getMyGyms()
        async let trainersTask = classService.loadTrainers()
        async let contextTask = workspaceContextService.fetchContext()

        await membershipTask
        // await gymTask
        await trainersTask
        await contextTask

        print("✅ Datos iniciales cargados (sin gyms - se cargan en AuthenticatedView)")
    }
    
    /// Limpia datos del usuario después del logout
    private func clearUserData() {
        print("🧹 Limpiando datos de usuario...")

        // Clear gym selection
        gymService.clearGymSelection()

        // Clear membership data
        membershipService.clearMembershipData()

        // Clear workspace context
        workspaceContextService.clearContext()

        print("✅ Datos de usuario limpiados")
    }
    
    // MARK: - Public Methods
    
    /// Re-configura las dependencias si es necesario
    func reconfigureDependencies() {
        setupDependencies()
        print("🔄 Dependencias reconfiguradas")
    }
    
    /// Fuerza la recarga de todos los datos
    func refreshAllData() async {
        guard authService.isAuthenticated else { return }
        
        print("🔄 Refrescando todos los datos...")
        
        async let membershipTask = membershipService.getMyMembershipStatus()
        async let gymTask = gymService.getMyGyms()
        async let profileTask = profileService.fetchUserProfile()
        
        await membershipTask
        await gymTask
        await profileTask
        
        print("✅ Todos los datos refrescados")
    }

    deinit {
        #if DEBUG
        print("🗑️ ServiceContainer deinitialized")
        print("📊 Liberando todos los servicios...")
        #endif
        // ServiceContainer es singleton, pero si se desinicializa
        // debemos asegurar cleanup de recursos críticos
        // Todos los servicios se liberarán automáticamente con ARC
    }
}

// MARK: - ServiceContainer Environment Key
struct ServiceContainerEnvironmentKey: EnvironmentKey {
    @MainActor static let defaultValue = ServiceContainer.shared
}

extension EnvironmentValues {
    var serviceContainer: ServiceContainer {
        get { self[ServiceContainerEnvironmentKey.self] }
        set { self[ServiceContainerEnvironmentKey.self] = newValue }
    }
}

// MARK: - ServiceContainer View Modifier
struct ServiceContainerModifier: ViewModifier {
    let serviceContainer = ServiceContainer.shared

    func body(content: Content) -> some View {
        content
            .environmentObject(serviceContainer.authService)
            .environmentObject(serviceContainer.themeManager)
            .environmentObject(serviceContainer.oneSignalService)
            .environmentObject(serviceContainer.membershipService)
            .environmentObject(serviceContainer.gymService)
            .environmentObject(serviceContainer.eventService)
            .environmentObject(serviceContainer.eventPaymentService)
            .environmentObject(serviceContainer.classService)
            .environmentObject(serviceContainer.profileService)
            .environmentObject(serviceContainer.surveyService)
            .environmentObject(serviceContainer.workspaceContextService)
            .environment(\.serviceContainer, serviceContainer)
    }
}

extension View {
    /// Aplica el ServiceContainer con todas las dependencias configuradas
    func withServiceContainer() -> some View {
        self.modifier(ServiceContainerModifier())
    }
}


// MARK: - ServiceContainer Convenience Extensions
extension ServiceContainer {
    /// Configuración rápida para preview
    static func preview() -> ServiceContainer {
        let container = ServiceContainer.shared
        // Configure any preview-specific setup here
        return container
    }
}

// MARK: - Usage Examples
/*
 
 // En Gym_APIApp.swift:
 
 @main
 struct Gym_APIApp: App {
     let serviceContainer = ServiceContainer.shared
     
     var body: some Scene {
         WindowGroup {
             AuthenticatedView()
                 .withServiceContainer()
                 .preferredColorScheme(serviceContainer.themeManager.currentTheme == .dark ? .dark : .light)
                 .onAppear {
                     serviceContainer.oneSignalService.initialize()
                     serviceContainer.authService.checkAuthStatus()
                 }
         }
     }
 }
 
 // En cualquier vista:
 
 struct SomeView: View {
     @Environment(\.serviceContainer) var serviceContainer
     // O usar directamente:
     @EnvironmentObject var authService: AuthServiceDirect
     @EnvironmentObject var membershipService: MembershipService
     
     var body: some View {
         // La vista tendrá acceso automático a todos los servicios
         // sin necesidad de configurar manualmente las dependencias
     }
 }
 
 */
