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
    let activityService: ActivityService
    let postService: PostService
    let attendanceService: AttendanceService
    let unreadCountService = UnreadCountService.shared // Singleton for unread message tracking
    let chatManagementService = ChatManagementService.shared // Singleton for chat management (hide, leave, delete)

    // MARK: - Published Properties
    @Published var isInitialized = false
    @Published var initializationError: String?
    
    // MARK: - Private Properties
    private var cancellables = Set<AnyCancellable>()
    private var isChatInitialized = false  // ✅ Evitar inicializaciones duplicadas
    
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
            self.activityService = ActivityService()
            self.postService = PostService()
            self.attendanceService = AttendanceService(classService: self.classService)

            // Configure dependencies automatically
            setupDependencies()
            
            // Setup observers
            setupObservers()
            
            print("✅ ServiceContainer inicializado con todas las dependencias configuradas")
        } catch {
            print("❌ Error al inicializar ServiceContainer: \(error)")
            self.initializationError = "Error al inicializar servicios: \(error.localizedDescription)"

            // En lugar de crashear, inicializar servicios mínimos para continuar
            #if DEBUG
            print("❌ DEBUG: ServiceContainer tuvo errores al inicializar: \(error)")
            print("❌ DEBUG: La app continuará con funcionalidad limitada")
            #else
            // En producción, log silencioso y continuar con servicios mínimos
            print("⚠️ ServiceContainer: Algunos servicios no pudieron inicializarse correctamente")
            #endif

            // Inicializar servicios críticos con valores por defecto si fallan
            self.authService = self.authService ?? AuthServiceDirect()
            self.themeManager = self.themeManager ?? ThemeManager()
            self.oneSignalService = self.oneSignalService ?? OneSignalService.shared

            // Marcar como inicializado con errores
            self.isInitialized = true
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
        activityService.authService = authService
        attendanceService.authService = authService

        print("🔧 Dependencias de AuthService configuradas automáticamente en todos los servicios")

        // Configure UnreadCountService (uses ChatProviderManager.shared internally)
        unreadCountService.configure()

        // ✅ NUEVO: Configurar ChatProviderManager para inicialización automática
        configureChatProvider()

        // Mark as initialized
        isInitialized = true

        // Configure HTTP client auth dependency
        HTTPClient.shared.authService = authService
    }

    // MARK: - Chat Provider Configuration

    /// Configura ChatProviderManager para inicialización automática
    private func configureChatProvider() {
        print("💬 Configurando ChatProviderManager...")

        // Observar cambios de autenticación para conectar/desconectar
        authService.$isAuthenticated
            .dropFirst() // Ignorar valor inicial
            .sink { [weak self] isAuthenticated in
                guard let self = self else { return }

                if isAuthenticated {
                    Task {
                        await self.initializeChatProvider()
                    }
                } else {
                    Task {
                        await self.disconnectChatProvider()
                    }
                }
            }
            .store(in: &cancellables)

        print("✅ ChatProviderManager configurado para inicialización automática")
    }

    /// Inicializa el ChatProvider con el usuario autenticado
    private func initializeChatProvider() async {
        // ✅ Evitar inicializaciones duplicadas
        guard !isChatInitialized else {
            print("⚠️ ChatProvider ya está inicializado, omitiendo...")
            return
        }

        guard let user = authService.user else {
            print("⚠️ No se puede inicializar chat: usuario no autenticado")
            return
        }

        // ✅ NUEVO: Verificar que existe un gymId antes de inicializar
        guard gymService.currentGymId != nil else {
            print("⚠️ No se puede inicializar chat: gym no seleccionado aún")
            print("💡 El chat se inicializará automáticamente cuando se seleccione un gym")
            return
        }

        print("🔄 Inicializando ChatProvider automáticamente...")
        print("   - User ID: \(user.id)")
        print("   - User Name: \(user.name)")
        print("   - Gym ID: \(gymService.currentGymId ?? -1)")

        // Inicializar provider con authService
        await ChatProviderManager.shared.initializeProvider(authService: authService)

        // ✅ NUEVO: Obtener token de Stream y conectar
        print("🔑 Obteniendo token de GetStream...")

        do {
            // Obtener token de acceso
            guard let accessToken = await authService.getValidAccessToken() else {
                print("❌ No se pudo obtener access token")
                return
            }

            // Obtener token de Stream desde la API
            let streamTokenResponse = try await fetchStreamToken(accessToken: accessToken)
            print("✅ Token de Stream obtenido")
            print("   - API Key: \(streamTokenResponse.apiKey)")
            print("   - Internal User ID: \(streamTokenResponse.internalUserId)")

            // Crear credenciales para conectar
            let credentials = ChatCredentials(
                token: streamTokenResponse.token,
                apiKey: streamTokenResponse.apiKey,
                userId: "user_\(streamTokenResponse.internalUserId)",
                userInfo: ChatUser(
                    id: "user_\(streamTokenResponse.internalUserId)",
                    name: user.name,
                    avatarURL: user.picture,
                    metadata: [
                        "email": user.email,
                        "internalId": streamTokenResponse.internalUserId
                    ]
                )
            )

            // Conectar al chat
            print("🔌 Conectando a GetStream...")
            try await ChatProviderManager.shared.connect(credentials: credentials)
            print("✅ ChatProvider conectado exitosamente")

            // ✅ Marcar como inicializado
            isChatInitialized = true

        } catch {
            print("❌ Error inicializando ChatProvider: \(error)")
            print("❌ Error localizedDescription: \(error.localizedDescription)")
            // No marcar como inicializado si falla
        }
    }

    /// Obtiene el token de Stream desde la API
    private func fetchStreamToken(accessToken: String) async throws -> StreamTokenResponse {
        let urlString = "https://gymapi-eh6m.onrender.com/api/v1/chat/token"
        guard let url = URL(string: urlString) else {
            throw NSError(domain: "ServiceContainer", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid URL"])
        }

        guard let request = await HTTPClient.shared.makeRequest(url: url, method: "GET") else {
            throw NSError(domain: "ServiceContainer", code: -1, userInfo: [NSLocalizedDescriptionKey: "No se pudo crear request"])
        }

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw NSError(domain: "ServiceContainer", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid response"])
        }

        guard httpResponse.statusCode == 200 else {
            throw NSError(domain: "ServiceContainer", code: httpResponse.statusCode, userInfo: [NSLocalizedDescriptionKey: "HTTP \(httpResponse.statusCode)"])
        }

        let decoder = JSONDecoder()
        // ✅ No usar keyDecodingStrategy porque StreamTokenResponse ya tiene CodingKeys definidos
        return try decoder.decode(StreamTokenResponse.self, from: data)
    }

    /// Desconecta el ChatProvider al hacer logout
    private func disconnectChatProvider() async {
        print("🔌 Desconectando ChatProvider...")
        await ChatProviderManager.shared.reset()
        isChatInitialized = false  // ✅ Resetear bandera para permitir reinicialización
        print("✅ ChatProvider desconectado")
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

        // Observe gym selection changes - preload stories when gym is selected
        gymService.$currentGym
            .dropFirst() // Ignore initial nil value
            .sink { [weak self] gym in
                self?.handleGymSelectionChange(gym?.id)
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

    /// Maneja cambios en la selección de gym - precarga datos del nuevo gym
    private func handleGymSelectionChange(_ gymId: Int?) {
        guard let gymId = gymId else {
            print("🏋️ ServiceContainer: Gym deseleccionado, limpiando datos")
            storyService.feedStories = []
            storyService.myStories = []
            classService.clearCache()
            eventService.clearEventsOnLogout()
            return
        }

        print("🏋️ ServiceContainer detectó selección de gym: \(gymId)")
        print("📸 Limpiando datos del gym anterior y precargando del nuevo...")

        // Limpiar datos del gym anterior
        classService.clearCache()
        eventService.clearEventsOnLogout()
        storyService.clearCache()

        // ✅ NUEVO: Inicializar ChatProvider cuando se selecciona gym
        // (solo si el usuario está autenticado)
        if authService.isAuthenticated {
            Task {
                await initializeChatProvider()
            }
        }

        // Precargar datos del nuevo gym
        Task {
            async let storiesTask = storyService.fetchStoriesFeed()
            async let eventsTask = eventService.fetchEvents()
            async let sessionsTask = classService.loadSessionsForDateIfNeeded(date: Date())

            await storiesTask
            await eventsTask
            await sessionsTask

            await MainActor.run {
                print("✅ Datos del gym \(gymId) precargados:")
                print("   - Stories: \(storyService.feedStories.count) usuarios")
                print("   - Eventos: \(eventService.events.count)")
                print("   - Sesiones: \(classService.sessions.count)")
            }
        }
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
        print("📸 Stories se cargarán automáticamente cuando se seleccione un gym")
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

        // Clear stories data
        storyService.clearCache()
        storyService.feedStories = []
        storyService.myStories = []

        // Clear events data and cache
        eventService.clearEventsOnLogout()

        // Clear classes/sessions data
        classService.clearCache()

        // Clear activity feed data
        activityService.activities = []
        activityService.currentRankings = []
        activityService.insights = []
        activityService.realtimeStats = nil

        // Clear unread message counts
        unreadCountService.clearAll()

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
            .environmentObject(serviceContainer.storyService)
            .environmentObject(serviceContainer.membershipService)
            .environmentObject(serviceContainer.gymService)
            .environmentObject(serviceContainer.eventService)
            .environmentObject(serviceContainer.eventPaymentService)
            .environmentObject(serviceContainer.classService)
            .environmentObject(serviceContainer.profileService)
            .environmentObject(serviceContainer.surveyService)
            .environmentObject(serviceContainer.workspaceContextService)
            .environmentObject(serviceContainer.activityService)
            .environmentObject(serviceContainer.postService)
            .environmentObject(serviceContainer.attendanceService)
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
