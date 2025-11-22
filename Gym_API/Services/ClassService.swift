import Foundation
import Combine

// MARK: - User Public Profile Model
struct UserPublicProfile: Codable, Identifiable, Equatable {
    let id: Int
    let firstName: String
    let lastName: String
    let picture: String?
    let role: String
    let bio: String?
    let isActive: Bool
    
    enum CodingKeys: String, CodingKey {
        case id, picture, role, bio
        case firstName = "first_name"
        case lastName = "last_name"
        case isActive = "is_active"
    }
    
    var fullName: String {
        return "\(firstName) \(lastName)".trimmingCharacters(in: .whitespaces)
    }
}

// MARK: - Class Service
class ClassService: ObservableObject {
    // MARK: - Singleton
    static var shared: ClassService?
    
    // MARK: - Published Properties
    @Published var sessions: [SessionWithClass] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var joiningClassIds: Set<Int> = []
    @Published var joinClassErrorMessages: [Int: String] = [:]
    @Published var userRegistrationStatus: [Int: Bool] = [:]
    @Published var cancellingClassIds: Set<Int> = []
    @Published var cancelClassErrorMessages: [Int: String] = [:]
    @Published var isLoadingMyClasses = false
    @Published var myClassesErrorMessage: String?
    @Published var trainers: [UserPublicProfile] = []
    @Published var isLoadingTrainers = false
    @Published var trainersErrorMessage: String?
    @Published var authenticationError = false
    @Published var trainersLastUpdated: Date = Date()
    
    // Cache TTL para trainers (5 minutos)
    private let trainersCacheTTL: TimeInterval = 300
    
    // MARK: - Optimized Participation Status Properties
    @Published var userParticipations: [Int: UserParticipation] = [:]
    @Published var isLoadingParticipationStatus = false
    @Published var participationStatusErrorMessage: String?
    @Published var lastParticipationStatusUpdate: Date?
    
    // MARK: - Private Properties
    // MIGRADO A UserDataCacheService - caché de trainers centralizado
    private let userCache = UserDataCacheService.shared

    // Caché local thread-safe de nombres de trainers para uso síncrono
    private var trainerNamesCache: [Int: String] = [:]
    
    // MARK: - Date Range Caching
    private var loadedStartDate: Date?
    private var loadedEndDate: Date?
    
    // MARK: - Task Management
    private var currentSessionTask: Task<Void, Never>?
    private var currentMyClassesTask: Task<Void, Never>?
    private var currentTrainersTask: Task<Void, Never>?
    
    private let baseURL = apiBaseURL
    private let session = URLSession.shared
    weak var authService: AuthServiceDirect?
    
    init(authService: AuthServiceDirect? = nil) {
        self.authService = authService
        ClassService.shared = self
        print("🏗️ ClassService initialized")
    }
    
    deinit {
        print("🗑️ ClassService deinitialized")
    }
    
    // Shared decoder using centralized utility
    private func configuredJSONDecoder() -> JSONDecoder {
        DateDecoding.serverDecoder()
    }
    
    // MARK: - Get Auth Token
    private func getAuthToken() async -> String? {
        guard let authService = authService else {
            debugLog("⚠️ AuthService no disponible")
            return nil
        }
        return await authService.getValidAccessToken()
    }
    
    // MARK: - Force Refresh (2-Phase Strategy)
    func forceRefreshSessions(date: Date) async {
        // Cancelar tasks anteriores
        currentSessionTask?.cancel()
        
        // Limpiar el cache para forzar recarga
        loadedStartDate = nil
        loadedEndDate = nil
        lastParticipationStatusUpdate = nil // Forzar recarga de participaciones también
        
        // Crear nueva task y cargar de nuevo
        currentSessionTask = Task {
            await loadSessionsForDateIfNeeded(date: date)
        }
        await currentSessionTask?.value
    }
    
    // MARK: - Force Refresh My Classes (Legacy)
    func forceRefreshMyClasses() async {
        // Cancelar task anterior
        currentMyClassesTask?.cancel()
        
        // Crear nueva task
        currentMyClassesTask = Task {
            await fetchMyClasses()
        }
        await currentMyClassesTask?.value
    }
    
    // MARK: - Force Refresh Participation Status (Optimized)
    func forceRefreshParticipationStatus(startDate: Date, endDate: Date) async {
        print("🔄 Forzando recarga de estados de participación...")
        lastParticipationStatusUpdate = nil // Invalidar cache
        await fetchMyParticipationStatus(startDate: startDate, endDate: endDate)
    }
    
    // MARK: - Smart Date Range Loading (2-Phase Strategy)
    func loadSessionsForDateIfNeeded(date: Date) async {
        let calendar = Calendar.current
        
        // Verificar si la fecha está dentro del rango cargado
        if let loadedStart = loadedStartDate,
           let loadedEnd = loadedEndDate,
           date >= loadedStart && date <= loadedEnd {
            // Ya tenemos los datos para esta fecha, pero verificar si necesitamos actualizar participaciones
            await loadParticipationStatusIfNeeded(startDate: loadedStart, endDate: loadedEnd)
            return
        }
        
        // Calcular el nuevo rango necesario (siempre 10 días: -3 a +7)
        let today = Date()

        let newStartDate = calendar.date(byAdding: .day, value: -3, to: today) ?? date
        let newEndDate = calendar.date(byAdding: .day, value: 7, to: today) ?? date
        
        // Fase 1: Cargar sesiones (datos principales)
        await fetchSessionsByDateRange(startDate: newStartDate, endDate: newEndDate)
        
        // Fase 2: Cargar estados de participación optimizados (paralelo)
        await loadParticipationStatusIfNeeded(startDate: newStartDate, endDate: newEndDate)
    }
    
    // MARK: - Load Participation Status If Needed
    private func loadParticipationStatusIfNeeded(startDate: Date, endDate: Date) async {
        // Solo cargar si no tenemos datos recientes (cache de 5 minutos)
        if !shouldUseOptimizedParticipationData() {
            await fetchMyParticipationStatus(startDate: startDate, endDate: endDate)
        }
    }
    
    // MARK: - Fetch Sessions by Date Range
    func fetchSessionsByDateRange(startDate: Date, endDate: Date, skip: Int = 0, limit: Int = 100) async {
        _ = await MainActor.run {
            self.isLoading = true
            self.errorMessage = nil
        }
        
        do {
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "yyyy-MM-dd"
            let startDateString = dateFormatter.string(from: startDate)
            let endDateString = dateFormatter.string(from: endDate)
            
            guard let url = URL(string: "\(baseURL)/schedule/sessions/date-range-with-timezone?start_date=\(startDateString)&end_date=\(endDateString)&skip=\(skip)&limit=\(limit)") else {
                throw ClassServiceError.invalidURL
            }
            
            guard let request = await HTTPClient.shared.makeRequest(url: url, method: "GET", includeGymHeader: true) else {
                debugLog("⚠️ No se encontró token de autorización válido para sesiones")
                _ = await MainActor.run {
                    self.errorMessage = "No se encontró token de autorización válido"
                    self.isLoading = false
                }
                return
            }
            
            print("🔍 Fetching sessions from: \(url)")
            print("📅 Date range: \(startDateString) to \(endDateString)")
            
            // Verificar si la task fue cancelada antes de hacer la request
            try Task.checkCancellation()
            
            let (data, response) = try await session.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                throw ClassServiceError.invalidResponse
            }
            
            print("📡 Response status for sessions: \(httpResponse.statusCode)")
            
            if httpResponse.statusCode == 200 {
                // El nuevo endpoint devuelve la estructura completa SessionWithClass con timezone info
                let sessions = try configuredJSONDecoder().decode([SessionWithClass].self, from: data)
                
                print("✅ Successfully decoded \(sessions.count) sessions with complete class info")
                for session in sessions.prefix(2) {
                    print("🔍 Session \(session.session.id): \(session.classInfo.name)")
                    print("🔍 Timezone info: \(session.session.timeInfo.isoWithTimezone)")
                }
                
                print("✅ Successfully fetched \(sessions.count) sessions for date range")
                
                _ = await MainActor.run {
                    self.sessions = sessions
                    // Actualizar el rango cargado
                    self.loadedStartDate = startDate
                    self.loadedEndDate = endDate
                }
            } else {
                let errorMessage = "Error del servidor: \(httpResponse.statusCode)"
                print("❌ \(errorMessage)")
                _ = await MainActor.run {
                    self.errorMessage = errorMessage
                }
            }
            
        } catch {
            // No mostrar error si la task fue cancelada intencionalmente
            if error is CancellationError || (error as NSError).code == -999 {
                print("🔄 Fetch sessions cancelado intencionalmente")
                return
            }
            
            print("❌ Error fetching sessions by date range: \(error)")
            _ = await MainActor.run {
                self.errorMessage = "Error cargando clases: \(error.localizedDescription)"
            }
        }
        
        _ = await MainActor.run {
            self.isLoading = false
        }
    }
    
    // MARK: - Fetch Sessions (Legacy - keeping for compatibility)
    func fetchSessions(skip: Int = 0, limit: Int = 100) async {
        _ = await MainActor.run {
            self.isLoading = true
            self.errorMessage = nil
        }
        
        do {
            guard let url = URL(string: "\(baseURL)/schedule/sessions/sessions?skip=\(skip)&limit=\(limit)") else {
                throw ClassServiceError.invalidURL
            }
            
            var request = URLRequest(url: url)
            request.httpMethod = "GET"
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.setValue("application/json", forHTTPHeaderField: "accept")
            
            // Agregar header X-Gym-ID
            let gymId = await GymService.shared.currentGymId ?? 4
            request.setValue("\(gymId)", forHTTPHeaderField: "X-Gym-ID")
            
            // Agregar token de autorización
            if let token = await getAuthToken() {
                request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
                print("🔑 Token incluido en petición de sesiones:")
                print("🔑 - Primeros 50 chars: \(token.prefix(50))...")
            } else {
                print("⚠️ No se encontró token de autorización válido para sesiones")
                _ = await MainActor.run {
                    self.errorMessage = "No se encontró token de autorización válido"
                    self.isLoading = false
                }
                return
            }
            
            print("🔍 Fetching sessions from: \(url)")
            
            let (data, response) = try await session.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                throw ClassServiceError.invalidResponse
            }
            
            print("📡 Response status for sessions: \(httpResponse.statusCode)")
            
            if httpResponse.statusCode == 200 {
                let sessions = try configuredJSONDecoder().decode([SessionWithClass].self, from: data)
                
                print("✅ Successfully fetched \(sessions.count) sessions")
                
                _ = await MainActor.run {
                    self.sessions = sessions
                }
            } else {
                let errorMessage = "Error del servidor: \(httpResponse.statusCode)"
                print("❌ \(errorMessage)")
                _ = await MainActor.run {
                    self.errorMessage = errorMessage
                }
            }
            
        } catch {
            print("❌ Error fetching sessions: \(error)")
            _ = await MainActor.run {
                self.errorMessage = "Error cargando clases: \(error.localizedDescription)"
            }
        }
        
        _ = await MainActor.run {
            self.isLoading = false
        }
    }
    
    // MARK: - Join Class
    func joinClass(sessionId: Int) async {
        _ = await MainActor.run {
            self.joiningClassIds.insert(sessionId)
            self.joinClassErrorMessages[sessionId] = nil
        }
        
        // El backend manejará las validaciones de tiempo y disponibilidad
        // Removemos validación local para evitar conflictos con la lógica del servidor
        print("🔍 Enviando petición de join al backend para validación de disponibilidad")
        
        do {
            guard let url = URL(string: "\(baseURL)/schedule/participation/register/\(sessionId)") else {
                throw ClassServiceError.invalidURL
            }
            
            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.setValue("application/json", forHTTPHeaderField: "accept")
            let gymId = await GymService.shared.currentGymId ?? 4
        request.setValue("\(gymId)", forHTTPHeaderField: "X-Gym-ID")
            
            // Agregar token de autorización
            if let token = await getAuthToken() {
                request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
                print("🔑 Token incluido en petición de registro:")
                print("🔑 - Primeros 50 chars: \(token.prefix(50))...")
            } else {
                print("⚠️ No se encontró token de autorización válido para registro")
                _ = await MainActor.run {
                    self.joinClassErrorMessages[sessionId] = "No se encontró token de autorización válido"
                    self.joiningClassIds.remove(sessionId)
                }
                return
            }
            
            print("🔍 Registering for class session: \(sessionId)")
            
            // Logging para debuggear zona horaria
            let now = Date()
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
            formatter.timeZone = TimeZone.current
            
            print("🕐 Debugging zona horaria:")
            print("🕐 Hora actual local: \(formatter.string(from: now))")
            print("🕐 Zona horaria actual: \(TimeZone.current.identifier)")
            print("🕐 Enviando petición de join para sesión: \(sessionId)")
            
            let (data, response) = try await session.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                throw ClassServiceError.invalidResponse
            }
            
            print("📡 Response status for registration: \(httpResponse.statusCode)")
            
            if httpResponse.statusCode == 200 {
                _ = try configuredJSONDecoder().decode(ClassParticipation.self, from: data)
                print("✅ Successfully registered for class session \(sessionId)")

                await MainActor.run {
                    let oldStatus = self.userRegistrationStatus[sessionId] ?? false
                    var updatedStatus = self.userRegistrationStatus
                    updatedStatus[sessionId] = true
                    self.userRegistrationStatus = updatedStatus

                    // Invalidar cache de participaciones para forzar recarga optimizada
                    self.lastParticipationStatusUpdate = nil

                    print("✅ Estado de registro actualizado para sesión \(sessionId): \(oldStatus) -> true")
                    print("📊 Estado completo de registros: \(self.userRegistrationStatus)")
                    // Forzar actualización de las published properties para UI
                    self.objectWillChange.send()
                    print("🔄 ObjectWillChange enviado para forzar actualización de UI")

                    // Emitir notificación de agendamiento exitoso para ComebackView
                    NotificationCenter.default.post(
                        name: .classScheduledSuccessfully,
                        object: nil,
                        userInfo: ["sessionId": sessionId]
                    )
                    debugLog("✅ [ClassService] Clase agendada - Notificación enviada a ComebackView")
                }
            } else {
                let errorMessage = try? JSONDecoder().decode(APIError.self, from: data)
                let message = errorMessage?.detail ?? "Error del servidor: \(httpResponse.statusCode)"
                print("❌ \(message)")
                
                // Si el error es que ya está registrado, actualizar el estado
                if httpResponse.statusCode == 400 && message.contains("Ya estás registrado") {
                    await MainActor.run {
                        let oldStatus = self.userRegistrationStatus[sessionId] ?? false
                        var updatedStatus = self.userRegistrationStatus
                        updatedStatus[sessionId] = true
                        self.userRegistrationStatus = updatedStatus
                        
                        // Invalidar cache de participaciones
                        self.lastParticipationStatusUpdate = nil
                        
                        print("✅ Usuario ya registrado - Estado actualizado para sesión \(sessionId): \(oldStatus) -> true")
                        print("📊 Estado completo de registros: \(self.userRegistrationStatus)")
                        // Forzar actualización de las published properties para UI
                        self.objectWillChange.send()
                        print("🔄 ObjectWillChange enviado para forzar actualización de UI")
                    }
                } else {
                    _ = await MainActor.run {
                        self.joinClassErrorMessages[sessionId] = message
                    }
                }
            }
            
        } catch {
            print("❌ Error registering for class: \(error)")
            _ = await MainActor.run {
                self.joinClassErrorMessages[sessionId] = "Error registrándose para la clase: \(error.localizedDescription)"
            }
        }
        
        _ = await MainActor.run {
            self.joiningClassIds.remove(sessionId)
        }
    }
    
    // MARK: - Cancel Class Registration
    func cancelClassRegistration(sessionId: Int, reason: String? = nil) async {
        _ = await MainActor.run {
            self.cancellingClassIds.insert(sessionId)
            self.cancelClassErrorMessages[sessionId] = nil
        }
        
        do {
            var urlString = "\(baseURL)/schedule/participation/cancel-registration/\(sessionId)"
            
            // Agregar reason como query parameter si se proporciona
            if let reason = reason, !reason.isEmpty {
                urlString += "?reason=\(reason.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? reason)"
            }
            
            guard let url = URL(string: urlString) else {
                throw ClassServiceError.invalidURL
            }
            
            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.setValue("application/json", forHTTPHeaderField: "accept")
            let gymId = await GymService.shared.currentGymId ?? 4
        request.setValue("\(gymId)", forHTTPHeaderField: "X-Gym-ID")
            
            // Agregar token de autorización
            if let token = await getAuthToken() {
                request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
                print("🔑 Token incluido en petición de cancelación:")
                print("🔑 - Primeros 50 chars: \(token.prefix(50))...")
            } else {
                print("⚠️ No se encontró token de autorización válido para cancelación")
                _ = await MainActor.run {
                    self.cancelClassErrorMessages[sessionId] = "No se encontró token de autorización válido"
                    self.cancellingClassIds.remove(sessionId)
                }
                return
            }
            
            print("🔍 Cancelling registration for class session: \(sessionId)")
            if let reason = reason {
                print("📝 Reason: \(reason)")
            }
            
            let (data, response) = try await session.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                throw ClassServiceError.invalidResponse
            }
            
            print("📡 Response status for cancellation: \(httpResponse.statusCode)")
            
            if httpResponse.statusCode == 200 {
                _ = try configuredJSONDecoder().decode(ClassParticipation.self, from: data)
                print("✅ Successfully cancelled registration for class session \(sessionId)")
                
                await MainActor.run {
                    var updatedStatus = self.userRegistrationStatus
                    updatedStatus[sessionId] = false
                    self.userRegistrationStatus = updatedStatus
                    
                    // Invalidar cache de participaciones para forzar recarga optimizada
                    self.lastParticipationStatusUpdate = nil
                    
                    print("🔄 Estado de registro actualizado para sesión \(sessionId) - Cancelado")
                    // Forzar actualización de las published properties para UI
                    self.objectWillChange.send()
                }
            } else {
                let errorMessage = try? JSONDecoder().decode(APIError.self, from: data)
                let message = errorMessage?.detail ?? "Error del servidor: \(httpResponse.statusCode)"
                print("❌ \(message)")
                
                _ = await MainActor.run {
                    self.cancelClassErrorMessages[sessionId] = message
                }
            }
            
        } catch {
            print("❌ Error cancelling class registration: \(error)")
            _ = await MainActor.run {
                self.cancelClassErrorMessages[sessionId] = "Error cancelando registro: \(error.localizedDescription)"
            }
        }
        
        _ = await MainActor.run {
            self.cancellingClassIds.remove(sessionId)
        }
    }
    
    // MARK: - Fetch My Participation Status (Optimized)
    func fetchMyParticipationStatus(startDate: Date, endDate: Date) async {
        _ = await MainActor.run {
            self.isLoadingParticipationStatus = true
            self.participationStatusErrorMessage = nil
        }
        
        do {
            // Formatear fechas para query parameters
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "yyyy-MM-dd"
            let startDateString = dateFormatter.string(from: startDate)
            let endDateString = dateFormatter.string(from: endDate)
            
            guard let url = URL(string: "\(baseURL)/schedule/participation/my-participation-status?start_date=\(startDateString)&end_date=\(endDateString)") else {
                throw ClassServiceError.invalidURL
            }
            
            guard let request = await HTTPClient.shared.makeRequest(url: url, method: "GET", includeGymHeader: true) else {
                debugLog("⚠️ No se encontró token de autorización válido para participation status")
                _ = await MainActor.run {
                    self.participationStatusErrorMessage = "No se encontró token de autorización válido"
                    self.isLoadingParticipationStatus = false
                }
                return
            }
            
            print("🔍 Fetching participation status from: \(url)")
            print("📅 Date range: \(startDateString) to \(endDateString)")
            
            // Verificar si la task fue cancelada antes de hacer la request
            try Task.checkCancellation()
            
            let (data, response) = try await session.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                throw ClassServiceError.invalidResponse
            }
            
            print("📡 Response status for participation status: \(httpResponse.statusCode)")
            
            if httpResponse.statusCode == 200 {
                let participationResponse = try configuredJSONDecoder().decode(ParticipationStatusResponse.self, from: data)
                
                print("✅ Successfully fetched \(participationResponse.participations.count) participation statuses")
                
                await MainActor.run {
                    // Limpiar estado anterior
                    self.userParticipations.removeAll()
                    var newUserRegistrationStatus: [Int: Bool] = [:]
                    
                    // Actualizar con nuevos datos
                    for participation in participationResponse.participations {
                        self.userParticipations[participation.sessionId] = participation
                        
                        // Actualizar el estado booleano legacy para compatibilidad
                        newUserRegistrationStatus[participation.sessionId] = participation.status.isActiveParticipation
                    }
                    
                    self.userRegistrationStatus = newUserRegistrationStatus
                    self.lastParticipationStatusUpdate = Date()
                    print("📊 Total participaciones cargadas: \(self.userParticipations.count)")
                    print("📊 Estado de participación actualizado con \(self.userParticipations.count) entradas")
                }
            } else {
                let errorMessage = "Error del servidor: \(httpResponse.statusCode)"
                print("❌ \(errorMessage)")
                _ = await MainActor.run {
                    self.participationStatusErrorMessage = errorMessage
                }
            }
            
        } catch {
            // No mostrar error si la task fue cancelada intencionalmente
            if error is CancellationError || (error as NSError).code == -999 {
                print("🔄 Fetch participation status cancelado intencionalmente")
                return
            }
            
            print("❌ Error fetching participation status: \(error)")
            _ = await MainActor.run {
                self.participationStatusErrorMessage = "Error cargando estados de participación: \(error.localizedDescription)"
            }
        }
        
        _ = await MainActor.run {
            self.isLoadingParticipationStatus = false
        }
    }
    
    // MARK: - Fetch My Classes
    func fetchMyClasses(skip: Int = 0, limit: Int = 100) async {
        _ = await MainActor.run {
            self.isLoadingMyClasses = true
            self.myClassesErrorMessage = nil
        }
        
        do {
            guard let url = URL(string: "\(baseURL)/schedule/participation/my-classes-simple?skip=\(skip)&limit=\(limit)") else {
                throw ClassServiceError.invalidURL
            }
            
            guard let request = await HTTPClient.shared.makeRequest(url: url, method: "GET", includeGymHeader: true) else {
                debugLog("⚠️ No se encontró token de autorización válido para mis clases")
                _ = await MainActor.run {
                    self.myClassesErrorMessage = "No se encontró token de autorización válido"
                    self.isLoadingMyClasses = false
                }
                return
            }
            
            print("🔍 Fetching my classes from: \(url)")
            
            // Verificar si la task fue cancelada antes de hacer la request
            try Task.checkCancellation()
            
            let (data, response) = try await session.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                throw ClassServiceError.invalidResponse
            }
            
            print("📡 Response status for my classes: \(httpResponse.statusCode)")
            
            if httpResponse.statusCode == 200 {
                let myClassesResponse = try configuredJSONDecoder().decode([MyClassSimpleResponse].self, from: data)
                
                print("✅ Successfully fetched \(myClassesResponse.count) registered classes")
                
                await MainActor.run {
                    // Actualizar el estado de registro basado en la respuesta simple
                    var newRegistrationStatus = self.userRegistrationStatus
                    for myClass in myClassesResponse {
                        newRegistrationStatus[myClass.sessionId] = (myClass.participationStatus == "registered")
                        print("🔄 Marcando sesión \(myClass.sessionId) como \(myClass.participationStatus)")
                    }
                    self.userRegistrationStatus = newRegistrationStatus
                    print("📊 Estado de registro actualizado: \(self.userRegistrationStatus)")
                }
            } else {
                let errorMessage = "Error del servidor: \(httpResponse.statusCode)"
                print("❌ \(errorMessage)")
                _ = await MainActor.run {
                    self.myClassesErrorMessage = errorMessage
                }
            }
            
        } catch {
            // No mostrar error si la task fue cancelada intencionalmente
            if error is CancellationError || (error as NSError).code == -999 {
                print("🔄 Fetch my classes cancelado intencionalmente")
                return
            }
            
            print("❌ Error fetching my classes: \(error)")
            _ = await MainActor.run {
                self.myClassesErrorMessage = "Error cargando mis clases: \(error.localizedDescription)"
            }
        }
        
        _ = await MainActor.run {
            self.isLoadingMyClasses = false
        }
    }
    
    // MARK: - Load Trainers
    func loadTrainers() async {
        // Verificar si los datos están frescos
        let now = Date()
        let timeSinceLastUpdate = now.timeIntervalSince(trainersLastUpdated)
        
        if !trainers.isEmpty && timeSinceLastUpdate < trainersCacheTTL && !authenticationError {
            print("🔍 Trainers cache still valid (updated \(Int(timeSinceLastUpdate))s ago), skipping request")
            return
        }
        
        print("🔍 Loading trainers (cache expired or empty)")
        
        // Cancelar task anterior si existe
        currentTrainersTask?.cancel()
        
        currentTrainersTask = Task {
            await performLoadTrainers()
        }
        
        await currentTrainersTask?.value
    }
    
    /// Fuerza la recarga de trainers ignorando el cache
    func forceReloadTrainers() async {
        print("🔄 Forcing trainers reload...")
        
        // Invalidar cache
        await MainActor.run {
            self.trainersLastUpdated = Date(timeIntervalSince1970: 0) // Fecha muy antigua
        }
        
        await loadTrainers()
    }
    
    private func performLoadTrainers() async {
        _ = await MainActor.run {
            self.isLoadingTrainers = true
            self.trainersErrorMessage = nil
            self.authenticationError = false
        }
        
        do {
            // Verificar si la task fue cancelada
            try Task.checkCancellation()
            
            guard let url = URL(string: "\(baseURL)/users/p/gym-participants?role=TRAINER&skip=0&limit=100") else {
                throw ClassServiceError.invalidURL
            }
            
            var request = URLRequest(url: url)
            request.httpMethod = "GET"
            
            // Agregar token de autorización usando el método seguro
            if let token = await getAuthToken() {
                request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
                print("🔑 Token agregado para trainers: Bearer \(token.prefix(20))...")
            } else {
                print("❌ No se encontró token de autorización válido para trainers")
                _ = await MainActor.run {
                    self.trainersErrorMessage = "Error de autenticación. Inicia sesión nuevamente."
                    self.authenticationError = true
                    self.isLoadingTrainers = false
                }
                return
            }
            
            // Verificar cancelación antes de continuar
            try Task.checkCancellation()
            
            // Agregar header del gym
            let gymId = await GymService.shared.currentGymId ?? 4
            request.setValue("\(gymId)", forHTTPHeaderField: "X-Gym-ID")
            
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            
            print("🔍 Loading trainers from: \(url)")
            
            let (data, response) = try await URLSession.shared.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                throw ClassServiceError.invalidResponse
            }
            
            print("📡 Response status for trainers: \(httpResponse.statusCode)")
            
            if httpResponse.statusCode == 200 {
                let loadedTrainers = try configuredJSONDecoder().decode([UserPublicProfile].self, from: data)
                
                print("✅ Successfully loaded \(loadedTrainers.count) trainers")
                
                _ = await MainActor.run {
                    self.trainers = loadedTrainers
                    // Crear mapeo de ID a trainer
                    // Actualizar caché centralizado con los trainers
                    for trainer in loadedTrainers {
                        self.userCache.updatePublicProfile(trainer.id, profile: trainer)
                        // También actualizar caché local thread-safe
                        self.trainerNamesCache[trainer.id] = trainer.fullName
                    }
                    self.trainersErrorMessage = nil
                    self.authenticationError = false
                    self.trainersLastUpdated = Date() // Actualizar timestamp para forzar refresh
                }
            } else {
                print("❌ Error loading trainers: HTTP \(httpResponse.statusCode)")
                
                _ = await MainActor.run {
                    if httpResponse.statusCode == 403 {
                        print("⚠️ Error 403: Problema de autenticación. Verificar token y permisos.")
                        self.trainersErrorMessage = "Error de autenticación. Inicia sesión nuevamente."
                        self.authenticationError = true
                    } else if httpResponse.statusCode == 401 {
                        self.trainersErrorMessage = "Sesión expirada. Inicia sesión nuevamente."
                        self.authenticationError = true
                    } else {
                        self.trainersErrorMessage = "Error del servidor: \(httpResponse.statusCode)"
                    }
                }
            }
            
        } catch {
            // No reportar errores de cancelación como errores reales
            if error is CancellationError {
                print("🔄 Trainers request cancelled - this is normal")
                return
            }
            
            print("❌ Error loading trainers: \(error)")
            _ = await MainActor.run {
                self.trainersErrorMessage = "Error cargando trainers: \(error.localizedDescription)"
            }
        }
        
        _ = await MainActor.run {
            self.isLoadingTrainers = false
        }
    }
    
    // MARK: - Helper Methods
    func isUserRegistered(sessionId: Int) -> Bool {
        return userRegistrationStatus[sessionId] == true
    }
    
    // MARK: - Optimized Helper Methods
    func getParticipationStatus(sessionId: Int) -> ParticipationStatus? {
        return userParticipations[sessionId]?.status
    }
    
    func getParticipation(sessionId: Int) -> UserParticipation? {
        return userParticipations[sessionId]
    }
    
    func hasAttended(sessionId: Int) -> Bool {
        return getParticipationStatus(sessionId: sessionId) == .attended
    }
    
    func wasCancelled(sessionId: Int) -> Bool {
        return getParticipationStatus(sessionId: sessionId) == .cancelled
    }
    
    func isActivelyRegistered(sessionId: Int) -> Bool {
        guard let status = getParticipationStatus(sessionId: sessionId) else { return false }
        return status.isActiveParticipation
    }
    
    func shouldUseOptimizedParticipationData() -> Bool {
        // Usar datos optimizados si fueron cargados en los últimos 5 minutos
        guard let lastUpdate = lastParticipationStatusUpdate else { 
            return false 
        }
        let cacheValidityDuration: TimeInterval = 5 * 60 // 5 minutos
        return Date().timeIntervalSince(lastUpdate) < cacheValidityDuration
    }
    
    func getTrainerName(trainerId: Int) async -> String {
        return await userCache.getUserName(trainerId)
    }

    func getTrainer(trainerId: Int) async -> UserPublicProfile? {
        return await userCache.getTrainer(trainerId)
    }
    
    // MARK: - Clear Cache
    
    /// Limpia todos los datos de clases en cache
    func clearCache() {
        print("🧹 Limpiando cache de clases...")

        // Limpiar arrays
        sessions = []
        trainers = []
        joiningClassIds = Set<Int>()
        cancellingClassIds = Set<Int>()
        userRegistrationStatus = [:]
        joinClassErrorMessages = [:]
        cancelClassErrorMessages = [:]
        // Caché de trainers manejado por UserDataCacheService

        // Limpiar caché local de nombres de trainers
        trainerNamesCache = [:]

        // Limpiar nuevos datos optimizados
        userParticipations = [:]
        lastParticipationStatusUpdate = nil

        // Resetear estados
        isLoading = false
        isLoadingMyClasses = false
        isLoadingTrainers = false
        isLoadingParticipationStatus = false
        errorMessage = nil
        myClassesErrorMessage = nil
        trainersErrorMessage = nil
        participationStatusErrorMessage = nil
        authenticationError = false

        print("✅ Cache de clases limpiado")
    }
}

// MARK: - Error Types

enum ClassServiceError: Error {
    case invalidURL
    case invalidResponse
    case noData
    case decodingError(String)
    
    var localizedDescription: String {
        switch self {
        case .invalidURL:
            return "URL inválida"
        case .invalidResponse:
            return "Respuesta inválida del servidor"
        case .noData:
            return "No se recibieron datos"
        case .decodingError(let message):
            return "Error decodificando datos: \(message)"
        }
    }
}

// MARK: - API Error Model
struct APIError: Codable {
    let detail: String
}

// MARK: - My Class Simple Response Model
struct MyClassSimpleResponse: Codable {
    let sessionId: Int
    let className: String
    let startTime: Date
    let participationStatus: String
    let room: String?
    let currentParticipants: Int
    let maxCapacity: Int
    
    enum CodingKeys: String, CodingKey {
        case sessionId = "session_id"
        case className = "class_name"
        case startTime = "start_time"
        case participationStatus = "participation_status"
        case room
        case currentParticipants = "current_participants"
        case maxCapacity = "max_capacity"
    }
}

// MARK: - Participation Status Models (Optimized)
struct ParticipationStatusResponse: Codable {
    let participations: [UserParticipation]
    let totalCount: Int
    
    enum CodingKeys: String, CodingKey {
        case participations
        case totalCount = "total_count"
    }
}

struct UserParticipation: Codable, Identifiable {
    let sessionId: Int
    let status: ParticipationStatus
    let registrationTime: Date?
    let attendanceTime: Date?
    let cancellationTime: Date?
    
    var id: Int { sessionId }
    
    enum CodingKeys: String, CodingKey {
        case sessionId = "session_id"
        case status
        case registrationTime = "registration_time"
        case attendanceTime = "attendance_time"
        case cancellationTime = "cancellation_time"
    }
}

enum ParticipationStatus: String, Codable, CaseIterable {
    case registered = "registered"
    case attended = "attended"
    case cancelled = "cancelled"
    
    var isActiveParticipation: Bool {
        switch self {
        case .registered, .attended:
            return true
        case .cancelled:
            return false
        }
    }
    
    var displayName: String {
        switch self {
        case .registered: return "Registered"
        case .attended: return "Attended"
        case .cancelled: return "Cancelled"
        }
    }
}

// MARK: - Class Participation Model
struct ClassParticipation: Codable {
    let sessionId: Int
    let memberId: Int
    let status: String
    let id: Int
    let gymId: Int
    let registrationTime: Date?
    let attendanceTime: Date?
    let cancellationTime: Date?
    let cancellationReason: String?
    let createdAt: Date?
    let updatedAt: Date?
    
    enum CodingKeys: String, CodingKey {
        case sessionId = "session_id"
        case memberId = "member_id"
        case status
        case id
        case gymId = "gym_id"
        case registrationTime = "registration_time"
        case attendanceTime = "attendance_time"
        case cancellationTime = "cancellation_time"
        case cancellationReason = "cancellation_reason"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}

// MARK: - ClassService Extensions for New UI Components
extension ClassService {
    var classes: [GymClass] {
        // Convert SessionWithClass to GymClass for simplified UI
        return sessions.map { sessionWithClass in
            // Parsear la fecha del campo iso_with_timezone que tiene la información correcta
            let isoFormatter = ISO8601DateFormatter()
            isoFormatter.formatOptions = [.withInternetDateTime, .withDashSeparatorInDate, .withColonSeparatorInTime, .withTimeZone]
            
            var correctStartTime = sessionWithClass.session.startTime
            var correctEndTime = sessionWithClass.session.endTime
            
            // Usar iso_with_timezone que tiene la fecha con zona horaria correcta
            if let preciseDate = isoFormatter.date(from: sessionWithClass.session.timeInfo.isoWithTimezone) {
                correctStartTime = preciseDate
                // Calcular endTime basándose en la duración original
                let duration = sessionWithClass.session.endTime.timeIntervalSince(sessionWithClass.session.startTime)
                correctEndTime = preciseDate.addingTimeInterval(duration)
            } else {
                print("⚠️ ClassService: Failed to parse timezone for class \(sessionWithClass.session.id)")
            }
            
            // Obtener nombre del trainer del caché local thread-safe
            let trainerName = trainerNamesCache[sessionWithClass.session.trainerId]
                ?? "Coach \(sessionWithClass.session.trainerId)"

            return GymClass(
                id: sessionWithClass.session.id,
                name: sessionWithClass.classInfo.name,
                description: sessionWithClass.classInfo.description,
                instructor: trainerName,
                trainerId: sessionWithClass.session.trainerId,
                startTime: correctStartTime,
                endTime: correctEndTime,
                maxParticipants: sessionWithClass.classInfo.maxCapacity,
                currentParticipants: sessionWithClass.session.currentParticipants,
                difficulty: mapDifficulty(sessionWithClass.classInfo.difficultyLevel),
                status: mapStatus(sessionWithClass.session.status),
                gymTimezone: sessionWithClass.session.timeInfo.gymTimezone
            )
        }
    }
    
    func loadClasses() async {
        await fetchSessions()
    }
    
    func isUserRegistered(classId: Int) -> Bool {
        return isUserRegistered(sessionId: classId)
    }
    
    func joinClass(classId: Int) async {
        await joinClass(sessionId: classId)
    }
    
    func cancelClassRegistration(classId: Int, reason: String) async {
        await cancelClassRegistration(sessionId: classId, reason: reason)
    }
    
    private func mapDifficulty(_ difficulty: DifficultyLevel) -> ClassDifficulty {
        switch difficulty {
        case .beginner: return .beginner
        case .intermediate: return .intermediate
        case .advanced: return .advanced
        }
    }
    
    private func mapStatus(_ status: SessionStatus) -> ClassStatus {
        switch status {
        case .scheduled, .active, .inProgress: return .available
        case .completed: return .completed
        case .cancelled: return .cancelled
        }
    }
} 
