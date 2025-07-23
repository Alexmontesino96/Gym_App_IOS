import Foundation
import Combine

// MARK: - Event Service
@MainActor
class EventService: ObservableObject {
    // MARK: - Published Properties
    @Published var events: [Event] = []
    @Published var eventDetail: EventDetail?
    @Published var eventParticipations: [EventParticipation] = []
    @Published var isLoading = false
    @Published var isLoadingDetail = false
    @Published var isLoadingParticipations = false
    @Published var errorMessage: String?
    @Published var detailErrorMessage: String?
    @Published var participationsErrorMessage: String?
    @Published var joinEventErrorMessage: String?
    @Published var isJoiningEvent = false
    @Published var userRegistrationStatus: [Int: Bool] = [:]
    @Published var userProfiles: [Int: UserProfile] = [:]
    
    private let baseURL = "https://gymapi-eh6m.onrender.com/api/v1"
    private let session = URLSession.shared
    weak var authService: AuthServiceDirect?
    
    // Para manejar cancelación de peticiones
    private var currentTask: URLSessionDataTask?
    
    // Función utilitaria para asegurar que las actualizaciones se hagan en el main thread
    private func updateOnMainThread(_ action: @escaping () -> Void) {
        if Thread.isMainThread {
            action()
        } else {
            DispatchQueue.main.async {
                action()
            }
        }
    }
    
    init(authService: AuthServiceDirect? = nil) {
        self.authService = authService
    }
    
    // MARK: - Force Refresh
    func forceRefresh() async {
        let refreshID = UUID().uuidString
        print("🔄 Force refresh initiated [\(refreshID)]")
        
        // Cancelar cualquier tarea pendiente
        currentTask?.cancel()
        
        // Esperar a que las tareas pendientes se cancelen
        do {
            try await Task.sleep(nanoseconds: 100_000_000) // 0.1 segundos
        } catch {
            print("⚠️ Sleep interrupted, continuing anyway [\(refreshID)]")
        }
        
        // Limpiar datos en el main thread
        _ = await MainActor.run {
            print("🧹 Clearing cached data [\(refreshID)]")
            self.events.removeAll()
            self.eventDetail = nil
            self.userRegistrationStatus.removeAll()
            self.userProfiles.removeAll()
            self.errorMessage = nil
            self.detailErrorMessage = nil
            self.joinEventErrorMessage = nil
            self.isLoading = true
        }
        
        // Crear una nueva task para el fetch
        let fetchTask = Task {
            print("🔄 Starting fresh fetch [\(refreshID)]")
            await fetchEvents()
            print("✅ Fresh fetch completed successfully [\(refreshID)]")
        }
        
        await fetchTask.value
        _ = await MainActor.run {
            self.isLoading = false
        }
    }
    
    // Función utilitaria para configurar JSONDecoder con formato de fecha correcto
    private func configuredJSONDecoder() -> JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .custom { decoder in
            let container = try decoder.singleValueContainer()
            let string = try container.decode(String.self)
            
            print("📅 Intentando decodificar fecha: '\(string)'")
            
            // Formatters para diferentes formatos de fecha
            let formatter1 = ISO8601DateFormatter()
            formatter1.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            formatter1.timeZone = TimeZone(secondsFromGMT: 0)
            
            let formatter2 = ISO8601DateFormatter()
            formatter2.formatOptions = [.withInternetDateTime]
            formatter2.timeZone = TimeZone(secondsFromGMT: 0)
            
            let formatters = [formatter1, formatter2]
            
            for (index, formatter) in formatters.enumerated() {
                if let date = formatter.date(from: string) {
                    print("✅ Fecha decodificada exitosamente con formatter \(index + 1): \(date)")
                    return date
                }
            }
            
            print("❌ No se pudo decodificar la fecha: '\(string)'")
            throw DecodingError.dataCorrupted(DecodingError.Context(codingPath: decoder.codingPath, debugDescription: "Invalid date: \(string)"))
        }
        return decoder
    }
    
    // Función para obtener el token de Auth0 válido
    private func getAuthToken() async -> String? {
        guard let authService = authService else {
            // Fallback a obtener el token directamente de UserDefaults
            return UserDefaults.standard.string(forKey: "auth0_access_token")
        }
        return await authService.getValidAccessToken()
    }
    
    // MARK: - Fetch Events
    func fetchEvents(
        skip: Int = 0,
        limit: Int = 50,
        status: EventStatus? = nil,
        startDate: Date? = nil,
        endDate: Date? = nil,
        titleContains: String? = nil,
        locationContains: String? = nil,
        createdBy: Int? = nil,
        onlyAvailable: Bool = false
    ) async {
        // Crear un Task ID único para esta operación
        let taskID = UUID().uuidString
        print("🔄 Starting fetch operation [\(taskID)]")
        
        updateOnMainThread {
            self.isLoading = true
            self.errorMessage = nil
        }
        
        do {
            // Crear una task dedicada para el fetch de eventos
            let eventsTask = Task {
                print("📡 [\(taskID)] Fetching events data...")
                return try await fetchEventsData(
                    skip: skip,
                    limit: limit,
                    status: status,
                    startDate: startDate,
                    endDate: endDate,
                    titleContains: titleContains,
                    locationContains: locationContains,
                    createdBy: createdBy,
                    onlyAvailable: onlyAvailable
                )
            }
            
            // Esperar por los eventos con manejo de cancelación
            let events = try await eventsTask.value
            
            // Verificar cancelación antes de continuar
            if Task.isCancelled {
                print("⚠️ [\(taskID)] Task cancelled after events fetch")
                throw CancellationError()
            }
            
            // Crear una task dedicada para las participaciones
            let participationsTask = Task {
                print("📡 [\(taskID)] Fetching user participations...")
                return await fetchUserParticipationsData()
            }
            
            // Esperar por las participaciones con manejo de cancelación
            let participations = try await participationsTask.value
            
            // Actualizar los eventos
            if let fetchedEvents = events {
                updateOnMainThread {
                    // Forzar la actualización completa de la lista
                    let sortedEvents = fetchedEvents.sorted { $0.startTime < $1.startTime }
                    self.events = sortedEvents
                    print("📱 UI updated with \(sortedEvents.count) events")
                }
                print("✅ Successfully fetched \(fetchedEvents.count) events from API")
            } else {
                print("⚠️ No events received from API")
            }
            
            // Actualizar las participaciones
            if let userParticipations = participations {
                updateUserRegistrationStatus(from: userParticipations)
            }
            
        } catch {
            if (error as NSError).code == NSURLErrorCancelled {
                print("⚠️ Fetch operation cancelled [\(taskID)]")
            } else {
                print("❌ Error fetching events [\(taskID)]: \(error)")
                updateOnMainThread {
                    self.errorMessage = "Error cargando eventos: \(error.localizedDescription)"
                }
            }
        }
        
        if !Task.isCancelled {
            updateOnMainThread {
                self.isLoading = false
                print("✅ Fetch operation completed [\(taskID)]")
            }
        } else {
            print("⚠️ Task cancelled, skipping UI update [\(taskID)]")
        }
    }
    
    // MARK: - Fetch Events Data (Private)
    private func fetchEventsData(
        skip: Int = 0,
        limit: Int = 50,
        status: EventStatus? = nil,
        startDate: Date? = nil,
        endDate: Date? = nil,
        titleContains: String? = nil,
        locationContains: String? = nil,
        createdBy: Int? = nil,
        onlyAvailable: Bool = false
    ) async throws -> [Event]? {
        
        do {
            // Construir URL con parámetros
            var urlComponents = URLComponents(string: "\(baseURL)/events/")!
            var queryItems: [URLQueryItem] = []
            
            queryItems.append(URLQueryItem(name: "skip", value: String(skip)))
            queryItems.append(URLQueryItem(name: "limit", value: String(limit)))
            
            if let status = status {
                queryItems.append(URLQueryItem(name: "status", value: status.rawValue))
            }
            
            if let startDate = startDate {
                let formatter = ISO8601DateFormatter()
                formatter.timeZone = TimeZone(secondsFromGMT: 0)
                queryItems.append(URLQueryItem(name: "start_date", value: formatter.string(from: startDate)))
            }
            
            if let endDate = endDate {
                let formatter = ISO8601DateFormatter()
                formatter.timeZone = TimeZone(secondsFromGMT: 0)
                queryItems.append(URLQueryItem(name: "end_date", value: formatter.string(from: endDate)))
            }
            
            if let titleContains = titleContains, !titleContains.isEmpty {
                queryItems.append(URLQueryItem(name: "title_contains", value: titleContains))
            }
            
            if let locationContains = locationContains, !locationContains.isEmpty {
                queryItems.append(URLQueryItem(name: "location_contains", value: locationContains))
            }
            
            if let createdBy = createdBy {
                queryItems.append(URLQueryItem(name: "created_by", value: String(createdBy)))
            }
            
            if onlyAvailable {
                queryItems.append(URLQueryItem(name: "only_available", value: "true"))
            }
            
            urlComponents.queryItems = queryItems
            
            guard let url = urlComponents.url else {
                throw EventServiceError.invalidURL
            }
            
            var request = URLRequest(url: url)
            request.httpMethod = "GET"
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.setValue("application/json", forHTTPHeaderField: "accept")
            
            // Agregar header X-Gym-ID 
            request.setValue("4", forHTTPHeaderField: "X-Gym-ID")
            
            // Agregar token de autorización
            if let token = await getAuthToken() {
                request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
                print("🔑 Token incluido en petición:")
                print("🔑 - Tipo: \(token.contains(".") ? (token.components(separatedBy: ".").count == 3 ? "JWT" : "JWE") : "Unknown")")
                print("🔑 - Primeros 50 chars: \(token.prefix(50))...")
                print("🔑 - Total length: \(token.count)")
            } else {
                print("⚠️ No se encontró token de autorización válido")
                // Si no hay token válido, mostrar datos mock
                return createMockEvents()
            }
            
            let task = session.dataTask(with: request)
            currentTask = task
            
            let (data, response) = try await session.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                throw EventServiceError.invalidResponse
            }
            
            print("📡 Response status: \(httpResponse.statusCode)")
            
            if httpResponse.statusCode == 200 {
                let fetchedEvents = try configuredJSONDecoder().decode([Event].self, from: data)
                return fetchedEvents
                
            } else {
                // Manejo específico de errores de autorización
                if httpResponse.statusCode == 401 {
                    print("❌ Error 401: Token expirado o inválido")
                    // Intentar renovar el token automáticamente solo si hay authService disponible
                    if let authService = authService,
                       let renewedToken = await authService.getValidAccessToken() {
                        print("🔄 Token renovado, reintentando petición...")
                        // Crear nueva petición con el token renovado
                        var retryRequest = request
                        retryRequest.setValue("Bearer \(renewedToken)", forHTTPHeaderField: "Authorization")
                        
                        do {
                            // Actualizar la tarea para el retry
                            let retryTask = session.dataTask(with: retryRequest)
                            currentTask = retryTask
                            
                            let (retryData, retryResponse) = try await session.data(for: retryRequest)
                            if let retryHttpResponse = retryResponse as? HTTPURLResponse,
                               retryHttpResponse.statusCode == 200 {
                                let events = try configuredJSONDecoder().decode([Event].self, from: retryData)
                                return events
                            }
                        } catch {
                            // Verificar si el error del retry es por cancelación
                            if let urlError = error as? URLError, urlError.code == .cancelled {
                                print("⚠️ Petición de eventos cancelada durante retry")
                                return nil
                            }
                            throw error
                        }
                    } else {
                        print("⚠️ No se pudo renovar token o no hay authService disponible")
                        // Si no hay authService, mostrar datos mock
                        return createMockEvents()
                    }
                }
                
                print("❌ Error \(httpResponse.statusCode)")
                throw EventServiceError.serverError(httpResponse.statusCode)
            }
            
        } catch {
            // Verificar si el error es por cancelación
            if let urlError = error as? URLError, urlError.code == .cancelled {
                print("⚠️ Petición de eventos cancelada")
                return nil
            }
            throw error
        }
    }
    
    // MARK: - Fetch User Participations Data (Private)
    private func fetchUserParticipationsData() async -> [EventParticipationWithEvent]? {
        // Verificar que tengamos token de autorización
        guard let token = await getAuthToken() else {
            print("⚠️ No se encontró token de autorización válido para participaciones")
            return nil
        }
        
        // Construir URL
        guard let url = URL(string: "\(baseURL)/events/participation/me") else {
            print("❌ URL inválida para participaciones de usuario")
            return nil
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "accept")
        
        // Agregar header X-Gym-ID
        request.setValue("4", forHTTPHeaderField: "X-Gym-ID")
        
        // Agregar token de autorización
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        
        print("🔍 Fetching user participations from: \(url)")
        
        do {
            let (data, response) = try await session.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                print("❌ Invalid response for user participations")
                return nil
            }
            
            print("📡 Response status for user participations: \(httpResponse.statusCode)")
            
            if httpResponse.statusCode == 200 {
                let participationsWithEvents = try configuredJSONDecoder().decode([EventParticipationWithEvent].self, from: data)
                print("✅ Successfully fetched \(participationsWithEvents.count) user participations")
                return participationsWithEvents
            } else {
                print("❌ Error \(httpResponse.statusCode) fetching user participations")
                return nil
            }
            
        } catch {
            print("❌ Error fetching user participations: \(error)")
            return nil
        }
    }
    
    // MARK: - Update User Registration Status (Private)
    private func updateUserRegistrationStatus(from participations: [EventParticipationWithEvent]) {
        updateOnMainThread {
            // Actualizar el estado de registro para cada evento
            self.userRegistrationStatus.removeAll()
            
            for participation in participations {
                // Solo considerar participaciones activas (no canceladas)
                let isRegistered = participation.status == "REGISTERED"
                self.userRegistrationStatus[participation.eventId] = isRegistered
                
                print("📝 User participation - Event ID: \(participation.eventId), Status: \(participation.status), Registered: \(isRegistered)")
            }
            
            print("🔍 Updated userRegistrationStatus: \(self.userRegistrationStatus)")
        }
    }

    // MARK: - Fetch User Participations (Mantener compatibilidad)
    func fetchUserParticipations() async {
        if let participations = await fetchUserParticipationsData() {
            updateUserRegistrationStatus(from: participations)
        }
    }
    
    // MARK: - Fetch Event Detail Data (Optimized)
    func fetchEventDetailData(eventId: Int) async {
        updateOnMainThread {
            self.isLoadingDetail = true
        }
        
        // Ejecutar las 3 llamadas simultáneamente
        async let eventDetailTask: () = fetchEventDetail(eventId: eventId)
        async let eventParticipationsTask: () = fetchEventParticipations(eventId: eventId)
        async let userParticipationsResult = fetchUserParticipationsData()
        
        // Esperar a que todas las llamadas terminen
        let (_, _, userParticipations) = await (eventDetailTask, eventParticipationsTask, userParticipationsResult)
        
        // Actualizar las participaciones del usuario
        if let participations = userParticipations {
            updateUserRegistrationStatus(from: participations)
        }
        
        updateOnMainThread {
            self.isLoadingDetail = false
        }
    }
    
    // MARK: - Fetch Event Detail
    func fetchEventDetail(eventId: Int) async {
        
        updateOnMainThread {
            self.isLoadingDetail = true
            self.detailErrorMessage = nil
            self.eventDetail = nil
        }
        
        do {
            // Construir URL
            guard let url = URL(string: "\(baseURL)/events/\(eventId)") else {
                throw EventServiceError.invalidURL
            }
            
            var request = URLRequest(url: url)
            request.httpMethod = "GET"
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.setValue("application/json", forHTTPHeaderField: "accept")
            
            // Agregar header X-Gym-ID
            request.setValue("4", forHTTPHeaderField: "X-Gym-ID")
            
            // Agregar token de autorización
            if let token = await getAuthToken() {
                request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
                print("🔑 Token incluido en petición de detalle:")
                print("🔑 - Tipo: \(token.contains(".") ? (token.components(separatedBy: ".").count == 3 ? "JWT" : "JWE") : "Unknown")")
                print("🔑 - Primeros 50 chars: \(token.prefix(50))...")
            } else {
                print("⚠️ No se encontró token de autorización válido para detalle")
                updateOnMainThread {
                    self.detailErrorMessage = "No se encontró token de autorización válido"
                }
                updateOnMainThread {
                    self.isLoadingDetail = false
                }
                return
            }
            
            print("🔍 Fetching event detail from: \(url)")
            
            let (data, response) = try await session.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                throw EventServiceError.invalidResponse
            }
            
            print("📡 Response status for detail: \(httpResponse.statusCode)")
            
            if httpResponse.statusCode == 200 {
                // Agregar logging detallado de la respuesta
                print("🔍 Raw response data for event detail:")
                if let jsonString = String(data: data, encoding: .utf8) {
                    print("📄 JSON Response: \(jsonString)")
                }
                
                // Intentar parsear como JSON para ver la estructura
                if let jsonObject = try? JSONSerialization.jsonObject(with: data, options: []),
                   let jsonData = try? JSONSerialization.data(withJSONObject: jsonObject, options: [.prettyPrinted]),
                   let prettyString = String(data: jsonData, encoding: .utf8) {
                    print("📄 Formatted JSON Response:\n\(prettyString)")
                }
                
                let eventDetail = try configuredJSONDecoder().decode(EventDetail.self, from: data)
                updateOnMainThread {
                    self.eventDetail = eventDetail
                }
                
                print("✅ Successfully fetched event detail: \(eventDetail.title)")
                
            } else if httpResponse.statusCode == 401 {
                print("❌ Error 401: Token expirado o inválido en detalle")
                // Intentar renovar el token automáticamente
                if let authService = authService,
                   let renewedToken = await authService.getValidAccessToken() {
                    print("🔄 Token renovado, reintentando petición de detalle...")
                    // Crear nueva petición con el token renovado
                    var retryRequest = request
                    retryRequest.setValue("Bearer \(renewedToken)", forHTTPHeaderField: "Authorization")
                    
                    do {
                        let (retryData, retryResponse) = try await session.data(for: retryRequest)
                        if let retryHttpResponse = retryResponse as? HTTPURLResponse,
                           retryHttpResponse.statusCode == 200 {
                            let eventDetail = try configuredJSONDecoder().decode(EventDetail.self, from: retryData)
                            updateOnMainThread {
                                self.eventDetail = eventDetail
                            }
                            print("✅ Event detail obtenido exitosamente después de renovar token")
                            return
                        }
                    } catch {
                        print("❌ Error en reintento de detalle después de renovar token: \(error)")
                    }
                }
                
                updateOnMainThread {
                    self.detailErrorMessage = "Token de autorización inválido o expirado"
                }
                
            } else if httpResponse.statusCode == 404 {
                print("❌ Error 404: Evento no encontrado")
                updateOnMainThread {
                    self.detailErrorMessage = "Evento no encontrado"
                }
                
            } else {
                // Intentar parsear error
                if let errorData = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let detail = errorData["detail"] as? String {
                    updateOnMainThread {
                        self.detailErrorMessage = detail
                    }
                } else {
                    updateOnMainThread {
                        self.detailErrorMessage = "Error del servidor: \(httpResponse.statusCode)"
                    }
                }
            }
            
        } catch {
            print("❌ Error fetching event detail: \(error)")
            updateOnMainThread {
                self.detailErrorMessage = "Error al cargar detalles del evento: \(error.localizedDescription)"
            }
        }
        
        updateOnMainThread {
            self.isLoadingDetail = false
        }
    }
    
    // MARK: - Fetch Event Participations
    func fetchEventParticipations(eventId: Int) async {
        updateOnMainThread {
            self.isLoadingParticipations = true
            self.participationsErrorMessage = nil
            self.eventParticipations = []
        }
        
        do {
            // Construir URL
            guard let url = URL(string: "\(baseURL)/events/participation/event/\(eventId)") else {
                throw EventServiceError.invalidURL
            }
            
            var request = URLRequest(url: url)
            request.httpMethod = "GET"
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.setValue("application/json", forHTTPHeaderField: "accept")
            
            // Agregar header X-Gym-ID
            request.setValue("4", forHTTPHeaderField: "X-Gym-ID")
            
            // Agregar token de autorización
            if let token = await getAuthToken() {
                request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
                print("🔑 Token incluido en petición de participaciones")
            } else {
                print("⚠️ No se encontró token de autorización válido para participaciones")
                updateOnMainThread {
                    self.participationsErrorMessage = "No se encontró token de autorización válido"
                }
                updateOnMainThread {
                    self.isLoadingParticipations = false
                }
                return
            }
            
            print("🔍 Fetching event participations from: \(url)")
            
            let (data, response) = try await session.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                throw EventServiceError.invalidResponse
            }
            
            print("📡 Response status for participations: \(httpResponse.statusCode)")
            
            if httpResponse.statusCode == 200 {
                // Logging de la respuesta
                if let jsonString = String(data: data, encoding: .utf8) {
                    print("📄 Participations Response: \(jsonString)")
                }
                
                let participations = try configuredJSONDecoder().decode([EventParticipation].self, from: data)
                updateOnMainThread {
                    self.eventParticipations = participations
                }
                
                print("✅ Successfully fetched \(participations.count) participations")
                
                // Verificar el estado de registro del usuario actual
                checkUserRegistrationFromParticipations(eventId: eventId)
                
                // Obtener perfiles de usuarios para cada participación
                await fetchUserProfilesForParticipations(participations)
                
            } else if httpResponse.statusCode == 401 {
                print("❌ Error 401: Token expirado o inválido en participaciones")
                updateOnMainThread {
                    self.participationsErrorMessage = "Token de autorización inválido o expirado"
                }
                
            } else if httpResponse.statusCode == 403 {
                print("❌ Error 403: Permisos insuficientes para ver participaciones")
                updateOnMainThread {
                    self.participationsErrorMessage = "Permisos insuficientes para ver participaciones"
                }
                
            } else if httpResponse.statusCode == 404 {
                print("❌ Error 404: Evento no encontrado para participaciones")
                updateOnMainThread {
                    self.participationsErrorMessage = "Evento no encontrado"
                }
                
            } else {
                // Intentar parsear error
                if let errorData = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let detail = errorData["detail"] as? String {
                    updateOnMainThread {
                        self.participationsErrorMessage = detail
                    }
                } else {
                    updateOnMainThread {
                        self.participationsErrorMessage = "Error del servidor: \(httpResponse.statusCode)"
                    }
                }
            }
            
        } catch {
            print("❌ Error fetching event participations: \(error)")
            updateOnMainThread {
                self.participationsErrorMessage = "Error al cargar participaciones: \(error.localizedDescription)"
            }
        }
        
        updateOnMainThread {
            self.isLoadingParticipations = false
        }
    }
    
    // MARK: - Fetch User Profile
    func fetchUserProfile(userId: Int) async -> UserProfile? {
        // Verificar si ya tenemos el perfil en cache
        if let cachedProfile = userProfiles[userId] {
            print("📋 Using cached profile for user \(userId)")
            return cachedProfile
        }
        
        do {
            // Construir URL
            guard let url = URL(string: "\(baseURL)/users/profile/\(userId)") else {
                throw EventServiceError.invalidURL
            }
            
            var request = URLRequest(url: url)
            request.httpMethod = "GET"
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.setValue("application/json", forHTTPHeaderField: "accept")
            
            // Agregar header X-Gym-ID
            request.setValue("4", forHTTPHeaderField: "X-Gym-ID")
            
            // Agregar token de autorización
            if let token = await getAuthToken() {
                request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
            } else {
                print("⚠️ No se encontró token de autorización válido para perfil de usuario")
                return nil
            }
            
            print("🔍 Fetching user profile from: \(url)")
            
            let (data, response) = try await session.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                throw EventServiceError.invalidResponse
            }
            
            print("📡 Response status for user profile \(userId): \(httpResponse.statusCode)")
            
            if httpResponse.statusCode == 200 {
                let userProfile = try configuredJSONDecoder().decode(UserProfile.self, from: data)
                
                // Guardar en cache
                userProfiles[userId] = userProfile
                
                print("✅ Successfully fetched profile for user \(userId): \(userProfile.fullName)")
                return userProfile
                
            } else {
                print("❌ Error \(httpResponse.statusCode) fetching profile for user \(userId)")
                return nil
            }
            
        } catch {
            print("❌ Error fetching user profile \(userId): \(error)")
            return nil
        }
    }
    
    // MARK: - Fetch User Profiles for Participations
    private func fetchUserProfilesForParticipations(_ participations: [EventParticipation]) async {
        print("🔍 Fetching user profiles for \(participations.count) participations")
        
        // Obtener perfiles de forma concurrente
        await withTaskGroup(of: Void.self) { group in
            for participation in participations {
                group.addTask {
                    _ = await self.fetchUserProfile(userId: participation.memberId)
                }
            }
        }
        
        print("✅ Finished fetching user profiles for participations")
    }
    
    // MARK: - User Registration Status
    func isUserRegistered(eventId: Int) -> Bool {
        let isRegistered = userRegistrationStatus[eventId] ?? false
        print("🔍 isUserRegistered for event \(eventId): \(isRegistered)")
        return isRegistered
    }
    
    private func updateUserRegistrationStatus(eventId: Int, isRegistered: Bool) {
        updateOnMainThread {
            self.userRegistrationStatus[eventId] = isRegistered
        }
    }
    
    private func checkUserRegistrationFromParticipations(eventId: Int) {
        guard let user = authService?.user else { return }
        
        // Convertir el ID del usuario de string a int si es necesario
        let userId = Int(user.id) ?? 0
        
        // Verificar si el usuario ya está registrado en las participaciones
        let isRegistered = eventParticipations.contains { participation in
            participation.eventId == eventId && participation.memberId == userId
        }
        
        updateUserRegistrationStatus(eventId: eventId, isRegistered: isRegistered)
    }
    
    // MARK: - Join Event
    func joinEvent(eventId: Int) async {
        updateOnMainThread {
            self.isJoiningEvent = true
            self.joinEventErrorMessage = nil
        }
        
        guard let url = URL(string: "\(baseURL)/events/participation") else {
            updateOnMainThread {
                self.joinEventErrorMessage = "URL inválida"
            }
            updateOnMainThread {
                self.isJoiningEvent = false
            }
            return
        }
        
        guard let authService = authService else {
            updateOnMainThread {
                self.joinEventErrorMessage = "No se encontró servicio de autenticación"
            }
            updateOnMainThread {
                self.isJoiningEvent = false
            }
            return
        }
        
        guard let token = await authService.getValidAccessToken() else {
            updateOnMainThread {
                self.joinEventErrorMessage = "No se encontró token de autorización válido"
            }
            updateOnMainThread {
                self.isJoiningEvent = false
            }
            return
        }
        
        // Preparar el body de la petición
        let requestBody = ["event_id": eventId]
        
        do {
            print("🔗 Joining event: \(eventId) at: \(url)")
            
            let jsonData = try JSONSerialization.data(withJSONObject: requestBody)
            
            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
            request.setValue("4", forHTTPHeaderField: "X-Gym-ID")
            request.httpBody = jsonData
            
            let (data, response) = try await session.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                updateOnMainThread {
                    self.joinEventErrorMessage = "Respuesta inválida del servidor"
                }
                updateOnMainThread {
                    self.isJoiningEvent = false
                }
                return
            }
            
            print("📡 Response status for join event: \(httpResponse.statusCode)")
            
            if let jsonString = String(data: data, encoding: .utf8) {
                print("📄 Join Event Response: \(jsonString)")
            }
            
            if httpResponse.statusCode == 201 {
                // Éxito - parsear la respuesta
                let participation = try configuredJSONDecoder().decode(EventParticipation.self, from: data)
                
                print("✅ Successfully joined event: \(eventId)")
                print("📝 Participation status: \(participation.status)")
                
                // Actualizar el estado local sin recargar la página
                updateOnMainThread {
                    // Agregar la nueva participación a la lista
                    self.eventParticipations.append(participation)
                    
                    // Actualizar el estado de registro del usuario
                    self.updateUserRegistrationStatus(eventId: eventId, isRegistered: true)
                    
                    // Actualizar el contador de participantes en la lista de eventos
                    if let eventIndex = self.events.firstIndex(where: { $0.id == eventId }) {
                        self.events[eventIndex].participantsCount += 1
                    }
                    
                    // Actualizar el contador de participantes localmente en el detalle
                    if let eventDetail = self.eventDetail, eventDetail.id == eventId {
                        // Crear una copia actualizada del eventDetail
                        let updatedDetail = EventDetail(
                            id: eventDetail.id,
                            title: eventDetail.title,
                            description: eventDetail.description,
                            startTime: eventDetail.startTime,
                            endTime: eventDetail.endTime,
                            location: eventDetail.location,
                            maxParticipants: eventDetail.maxParticipants,
                            status: eventDetail.status,
                            creatorId: eventDetail.creatorId,
                            createdAt: eventDetail.createdAt,
                            updatedAt: eventDetail.updatedAt,
                            participantsCount: eventDetail.participantsCount + 1
                        )
                        self.eventDetail = updatedDetail
                    }
                }
                
                // Obtener el perfil del usuario para mostrarlo en la lista
                if let auth = self.authService,
                   let user = auth.user,
                   let userId = Int(user.id) {
                    _ = await fetchUserProfile(userId: userId)
                }
                
            } else if httpResponse.statusCode == 400 {
                // Error de solicitud malformada
                if let errorData = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let detail = errorData["detail"] as? String {
                    updateOnMainThread {
                        self.joinEventErrorMessage = detail
                    }
                } else {
                    updateOnMainThread {
                        self.joinEventErrorMessage = "Solicitud malformada"
                    }
                }
            } else if httpResponse.statusCode == 401 {
                updateOnMainThread {
                    self.joinEventErrorMessage = "Token de autorización inválido o expirado"
                }
            } else if httpResponse.statusCode == 403 {
                updateOnMainThread {
                    self.joinEventErrorMessage = "Permisos insuficientes para unirse al evento"
                }
            } else if httpResponse.statusCode == 404 {
                updateOnMainThread {
                    self.joinEventErrorMessage = "Evento no encontrado"
                }
            } else if httpResponse.statusCode == 422 {
                // Error de validación
                if let errorData = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let detail = errorData["detail"] as? String {
                    updateOnMainThread {
                        self.joinEventErrorMessage = detail
                    }
                } else {
                    updateOnMainThread {
                        self.joinEventErrorMessage = "Error de validación en los datos"
                    }
                }
            } else {
                updateOnMainThread {
                    self.joinEventErrorMessage = "Error del servidor: \(httpResponse.statusCode)"
                }
            }
            
        } catch {
            print("❌ Error joining event: \(error)")
            updateOnMainThread {
                self.joinEventErrorMessage = "Error al unirse al evento: \(error.localizedDescription)"
            }
        }
        
        updateOnMainThread {
            self.isJoiningEvent = false
        }
    }
    
    // MARK: - Cancel Event Participation
    func cancelEvent(eventId: Int) async {
        updateOnMainThread {
            self.isJoiningEvent = true
            self.joinEventErrorMessage = nil
        }
        
        guard let url = URL(string: "\(baseURL)/events/participation/\(eventId)") else {
            updateOnMainThread {
                self.joinEventErrorMessage = "URL inválida"
            }
            updateOnMainThread {
                self.isJoiningEvent = false
            }
            return
        }
        
        guard let authService = authService else {
            updateOnMainThread {
                self.joinEventErrorMessage = "No se encontró servicio de autenticación"
            }
            updateOnMainThread {
                self.isJoiningEvent = false
            }
            return
        }
        
        guard let token = await authService.getValidAccessToken() else {
            updateOnMainThread {
                self.joinEventErrorMessage = "No se encontró token de autorización válido"
            }
            updateOnMainThread {
                self.isJoiningEvent = false
            }
            return
        }
        
        do {
            print("🚫 Canceling event participation: \(eventId) at: \(url)")
            
            var request = URLRequest(url: url)
            request.httpMethod = "DELETE"
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
            request.setValue("4", forHTTPHeaderField: "X-Gym-ID")
            
            let (_, response) = try await session.data(for: request)
            
            if let httpResponse = response as? HTTPURLResponse {
                print("📡 Cancel response status: \(httpResponse.statusCode)")
                
                if httpResponse.statusCode == 204 {
                    print("✅ Successfully canceled event participation")
                    
                    // Actualizar el estado local
                    updateOnMainThread {
                        // Actualizar el estado de registro del usuario
                        self.updateUserRegistrationStatus(eventId: eventId, isRegistered: false)
                        
                        // Actualizar el contador de participantes en la lista de eventos
                        if let eventIndex = self.events.firstIndex(where: { $0.id == eventId }) {
                            self.events[eventIndex].participantsCount = max(0, self.events[eventIndex].participantsCount - 1)
                        }
                        
                        // Actualizar el contador de participantes localmente en el detalle
                        if let eventDetail = self.eventDetail, eventDetail.id == eventId {
                            // Crear una copia actualizada del eventDetail
                            let updatedDetail = EventDetail(
                                id: eventDetail.id,
                                title: eventDetail.title,
                                description: eventDetail.description,
                                startTime: eventDetail.startTime,
                                endTime: eventDetail.endTime,
                                location: eventDetail.location,
                                maxParticipants: eventDetail.maxParticipants,
                                status: eventDetail.status,
                                creatorId: eventDetail.creatorId,
                                createdAt: eventDetail.createdAt,
                                updatedAt: eventDetail.updatedAt,
                                participantsCount: max(0, eventDetail.participantsCount - 1)
                            )
                            self.eventDetail = updatedDetail
                        }
                        
                        // Remover la participación de la lista local
                        self.eventParticipations.removeAll { $0.eventId == eventId }
                    }
                    
                } else {
                    updateOnMainThread {
                        self.joinEventErrorMessage = "Error al cancelar participación: \(httpResponse.statusCode)"
                    }
                }
            }
            
        } catch {
            updateOnMainThread {
                self.joinEventErrorMessage = "Error al cancelar participación: \(error.localizedDescription)"
            }
            print("❌ Error canceling event: \(error)")
        }
        
        updateOnMainThread {
            self.isJoiningEvent = false
        }
    }
    
    // MARK: - Mock Data para desarrollo
    private func createMockEvents() -> [Event] {
        let calendar = Calendar.current
        let now = Date()
        
        return [
            Event(
                id: 1,
                title: "Training Run",
                description: "Sesión de entrenamiento al aire libre con técnicas de running avanzadas",
                startTime: calendar.date(byAdding: .hour, value: 2, to: now) ?? now,
                endTime: calendar.date(byAdding: .hour, value: 3, to: now) ?? now,
                location: "Venetian Bridge",
                maxParticipants: 20,
                status: .scheduled,
                creatorId: 1,
                createdAt: calendar.date(byAdding: .day, value: -1, to: now) ?? now,
                updatedAt: calendar.date(byAdding: .day, value: -1, to: now) ?? now,
                participantsCount: 12
            ),
            Event(
                id: 2,
                title: "Torneo Interno - Nivel Intermedio",
                description: "Competencia interna para miembros de nivel intermedio",
                startTime: calendar.date(byAdding: .day, value: 2, to: now) ?? now,
                endTime: calendar.date(byAdding: .day, value: 2, to: calendar.date(byAdding: .hour, value: 3, to: now) ?? now) ?? now,
                location: "Gimnasio Principal",
                maxParticipants: 16,
                status: .scheduled,
                creatorId: 2,
                createdAt: calendar.date(byAdding: .day, value: -2, to: now) ?? now,
                updatedAt: calendar.date(byAdding: .day, value: -2, to: now) ?? now,
                participantsCount: 8
            ),
            Event(
                id: 3,
                title: "Clase en la Playa - Miami Beach",
                description: "Entrenamiento especial en la playa con ejercicios funcionales",
                startTime: calendar.date(byAdding: .day, value: 8, to: now) ?? now,
                endTime: calendar.date(byAdding: .day, value: 8, to: calendar.date(byAdding: .hour, value: 2, to: now) ?? now) ?? now,
                location: "Miami Beach",
                maxParticipants: 25,
                status: .scheduled,
                creatorId: 3,
                createdAt: calendar.date(byAdding: .day, value: -3, to: now) ?? now,
                updatedAt: calendar.date(byAdding: .day, value: -3, to: now) ?? now,
                participantsCount: 15
            )
        ]
    }
    
    // MARK: - Refresh Data (Optimized)
    func refreshData() async {
        print("🔄 Refreshing all data...")
        await fetchEvents()
    }
    
    // MARK: - Refresh Event Detail Data (Optimized)
    func refreshEventDetailData(eventId: Int) async {
        print("🔄 Refreshing event detail data for event \(eventId)...")
        await fetchEventDetailData(eventId: eventId)
    }
}

// MARK: - Event Service Errors
enum EventServiceError: LocalizedError {
    case invalidURL
    case invalidResponse
    case httpError(Int)
    case apiError(String)
    case authError(String)
    case decodingError
    case networkError
    case serverError(Int)
    
    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "URL inválida"
        case .invalidResponse:
            return "Respuesta inválida del servidor"
        case .httpError(let code):
            return "Error HTTP: \(code)"
        case .apiError(let message):
            return "Error de API: \(message)"
        case .authError(let message):
            return "Error de autorización: \(message)"
        case .decodingError:
            return "Error al procesar datos"
        case .networkError:
            return "Error de conexión"
        case .serverError(let code):
            return "Error del servidor: \(code)"
        }
    }
} 