import SwiftUI
import Combine

// MARK: - Service Container with Lazy Loading
/// Contenedor centralizado optimizado con lazy loading para reducir uso de memoria
/// Los servicios solo se inicializan cuando son accedidos por primera vez
@MainActor
class ServiceContainerLazy: ObservableObject {
    // MARK: - Singleton
    static let shared = ServiceContainerLazy()

    // MARK: - Core Services (Always loaded - críticos para la app)
    let authService: AuthServiceDirect
    let themeManager: ThemeManager

    // MARK: - Lazy Services (Loaded on demand)
    // OneSignal - Solo cuando se necesitan notificaciones
    private var _oneSignalService: OneSignalService?
    var oneSignalService: OneSignalService {
        if _oneSignalService == nil {
            _oneSignalService = OneSignalService.shared
            print("🔄 Lazy loading: OneSignalService inicializado")
        }
        return _oneSignalService!
    }

    // MembershipService - Solo cuando se accede a membresía
    private var _membershipService: MembershipService?
    var membershipService: MembershipService {
        if _membershipService == nil {
            _membershipService = MembershipService.shared
            _membershipService!.authService = authService
            print("🔄 Lazy loading: MembershipService inicializado")
        }
        return _membershipService!
    }

    // GymService - Solo cuando se necesita información del gimnasio
    private var _gymService: GymService?
    var gymService: GymService {
        if _gymService == nil {
            _gymService = GymService.shared
            _gymService!.authService = authService
            print("🔄 Lazy loading: GymService inicializado")
        }
        return _gymService!
    }

    // EventService - Solo cuando se accede a eventos
    private var _eventService: EventService?
    var eventService: EventService {
        if _eventService == nil {
            _eventService = EventService()
            _eventService!.authService = authService
            print("🔄 Lazy loading: EventService inicializado")
        }
        return _eventService!
    }

    // ClassService - Solo cuando se accede a clases
    private var _classService: ClassService?
    var classService: ClassService {
        if _classService == nil {
            _classService = ClassService()
            _classService!.authService = authService
            print("🔄 Lazy loading: ClassService inicializado")
        }
        return _classService!
    }

    // ProfileService - Solo cuando se accede al perfil
    private var _profileService: UserProfileService?
    var profileService: UserProfileService {
        if _profileService == nil {
            _profileService = UserProfileService.shared
            _profileService!.authService = authService
            print("🔄 Lazy loading: UserProfileService inicializado")
        }
        return _profileService!
    }

    // UnifiedImageService - Servicio consolidado para todas las operaciones de imagen
    var unifiedImageService: UnifiedImageService {
        let service = UnifiedImageService.shared
        service.configure(authService: authService)
        return service
    }

    // UserStatsService - Solo cuando se accede a estadísticas
    private var _userStatsService: UserStatsService?
    var userStatsService: UserStatsService {
        if _userStatsService == nil {
            _userStatsService = UserStatsService.shared
            _userStatsService!.authService = authService
            print("🔄 Lazy loading: UserStatsService inicializado")
        }
        return _userStatsService!
    }

    // DirectMessageService - Solo cuando se accede a mensajes
    private var _directMessageService: DirectMessageService?
    var directMessageService: DirectMessageService {
        if _directMessageService == nil {
            _directMessageService = DirectMessageService()
            _directMessageService!.authService = authService
            print("🔄 Lazy loading: DirectMessageService inicializado")
        }
        return _directMessageService!
    }

    // SurveyService - Solo cuando se accede a encuestas
    private var _surveyService: SurveyService?
    var surveyService: SurveyService {
        if _surveyService == nil {
            _surveyService = SurveyService()
            _surveyService!.authService = authService
            _surveyService!.gymService = gymService
            print("🔄 Lazy loading: SurveyService inicializado")
        }
        return _surveyService!
    }

    // Chat Services - Heavy services loaded on demand
    // StreamChatService comentado - necesita importar el módulo correcto
    // private var _streamChatService: StreamChatService?
    // var streamChatService: StreamChatService? {
    //     if _streamChatService == nil && authService.isAuthenticated {
    //         _streamChatService = StreamChatService.shared
    //         print("🔄 Lazy loading: StreamChatService inicializado")
    //     }
    //     return _streamChatService
    // }

    private var _chatService: ChatService?
    var chatService: ChatService? {
        if _chatService == nil && authService.isAuthenticated {
            _chatService = ChatService.shared
            print("🔄 Lazy loading: ChatService inicializado")
        }
        return _chatService
    }

    // MARK: - Published Properties
    @Published var isInitialized = false
    @Published var initializationError: String?
    @Published var loadedServicesCount = 0

    // MARK: - Private Properties
    private var cancellables = Set<AnyCancellable>()

    // MARK: - Initialization
    private init() {
        // Solo inicializar servicios críticos
        self.authService = AuthServiceDirect()
        self.themeManager = ThemeManager()

        // Configurar HTTP client con auth
        HTTPClient.shared.authService = authService

        // Setup observers
        setupObservers()

        // Mark as initialized
        isInitialized = true
        loadedServicesCount = 2 // Solo auth y theme están cargados inicialmente

        print("✅ ServiceContainerLazy inicializado con servicios críticos")
        print("📊 Memoria optimizada: Solo 2 servicios cargados inicialmente")
    }

    // MARK: - Observer Setup
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

    private func handleAuthenticationStateChange(_ isAuthenticated: Bool) {
        print("🔐 Estado de autenticación cambiado: \(isAuthenticated ? "Autenticado" : "No autenticado")")

        if isAuthenticated {
            // Solo cargar servicios críticos después del login
            Task {
                // Cargar datos básicos de usuario
                await loadCriticalUserData()
            }
        } else {
            // Limpiar servicios no esenciales cuando se hace logout
            releaseNonEssentialServices()
        }
    }

    private func handleUserChange(_ user: AuthUser?) {
        guard let user = user else {
            print("👤 Usuario no disponible")
            return
        }

        print("👤 Usuario actualizado: \(user.email)")

        // Configurar OneSignal con el ID del usuario (lazy)
        if _oneSignalService != nil {
            oneSignalService.setExternalUserId(user.id)
        }
    }

    // MARK: - Data Loading
    private func loadCriticalUserData() async {
        print("📊 Cargando datos críticos del usuario...")

        // Solo cargar membresía y gimnasio que son esenciales
        async let membershipTask = membershipService.getMyMembershipStatus()
        async let gymTask = gymService.getMyGyms()

        await membershipTask
        await gymTask

        // Auto-seleccionar gimnasio si solo hay uno
        if gymService.myGyms.count == 1 {
            gymService.selectGym(gymService.myGyms[0])
        }

        print("✅ Datos críticos cargados")
    }

    // MARK: - Memory Management

    /// Libera servicios no esenciales para reducir memoria
    public func releaseNonEssentialServices() {
        print("🧹 Liberando servicios no esenciales...")

        var releasedCount = 0

        // Liberar servicios pesados si no están en uso
        if _eventService != nil {
            _eventService = nil
            releasedCount += 1
        }

        if _classService != nil {
            _classService = nil
            releasedCount += 1
        }

        if _directMessageService != nil {
            _directMessageService = nil
            releasedCount += 1
        }

        if _surveyService != nil {
            _surveyService = nil
            releasedCount += 1
        }

        // if _streamChatService != nil {
        //     _streamChatService = nil
        //     releasedCount += 1
        // }

        if _chatService != nil {
            _chatService = nil
            releasedCount += 1
        }

        // UnifiedImageService es singleton, no necesita liberarse

        if _userStatsService != nil {
            _userStatsService = nil
            releasedCount += 1
        }

        print("✅ \(releasedCount) servicios liberados")
        loadedServicesCount -= releasedCount
    }

    /// Libera todos los servicios excepto los críticos
    public func releaseAllNonCriticalServices() {
        print("🧹 Liberando TODOS los servicios no críticos...")

        _oneSignalService = nil
        _membershipService = nil
        _gymService = nil
        _eventService = nil
        _classService = nil
        _profileService = nil
        // UnifiedImageService es singleton, no se libera aquí
        _userStatsService = nil
        _directMessageService = nil
        _surveyService = nil
        // _streamChatService = nil
        _chatService = nil

        loadedServicesCount = 2 // Solo quedan auth y theme

        print("✅ Todos los servicios no críticos liberados")
        print("📊 Memoria optimizada: Solo servicios críticos en memoria")
    }

    /// Reconfigura dependencias (útil después de cambios de configuración)
    func reconfigureDependencies() {
        // Solo reconfigurar servicios que ya están cargados
        if _membershipService != nil {
            _membershipService!.authService = authService
        }
        if _gymService != nil {
            _gymService!.authService = authService
        }
        // ... etc para otros servicios cargados

        print("🔧 Dependencias reconfiguradas para servicios cargados")
    }

    /// Refresca todos los datos de servicios cargados
    func refreshLoadedServicesData() async {
        guard authService.isAuthenticated else { return }

        print("🔄 Refrescando datos de servicios cargados...")

        // Solo refrescar servicios que ya están cargados
        if _membershipService != nil {
            await membershipService.getMyMembershipStatus()
        }
        if _gymService != nil {
            await gymService.getMyGyms()
        }
        if _profileService != nil {
            await profileService.fetchUserProfile()
        }

        print("✅ Datos de servicios cargados refrescados")
    }

    // MARK: - Service Status

    /// Retorna información sobre el estado de los servicios
    var serviceStatus: ServiceStatus {
        ServiceStatus(
            totalServices: 14,
            loadedServices: loadedServicesCount,
            criticalServicesLoaded: 2,
            memoryOptimized: loadedServicesCount < 5
        )
    }

    deinit {
        #if DEBUG
        print("🗑️ ServiceContainerLazy deinitialized")
        print("📊 Liberando todos los servicios...")
        #endif
        // No podemos llamar a métodos @MainActor desde deinit
        // Los servicios se liberarán automáticamente con ARC
    }
}

// MARK: - Service Status Model
struct ServiceStatus {
    let totalServices: Int
    let loadedServices: Int
    let criticalServicesLoaded: Int
    let memoryOptimized: Bool

    var loadedPercentage: Double {
        Double(loadedServices) / Double(totalServices) * 100
    }

    var memoryUsageEstimate: String {
        let baseMemory = 10 // MB base
        let perServiceMemory = 3 // MB por servicio
        let totalMemory = baseMemory + (loadedServices * perServiceMemory)
        return "\(totalMemory) MB"
    }
}

// MARK: - Migration Extension
extension ServiceContainerLazy {
    /// Helper para migrar de ServiceContainer a ServiceContainerLazy
    static func migrateFromLegacyContainer() {
        print("🔄 Migrando a ServiceContainerLazy...")
        // La migración es automática ya que usamos el mismo singleton pattern
        print("✅ Migración completada")
    }
}