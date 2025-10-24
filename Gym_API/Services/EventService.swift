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
    // MIGRADO A UserDataCacheService - ya no se necesita caché local
    @Published var userParticipations: [EventParticipation] = []
    @Published var isCreatingEvent = false
    @Published var createEventErrorMessage: String?
    @Published var deleteEventSuccessMessage: String?
    
    private let baseURL = "https://gymapi-eh6m.onrender.com/api/v1"
    private let session = URLSession.shared
    weak var authService: AuthServiceDirect?
    private let userCache = UserDataCacheService.shared
    
    // Para manejar cancelación de peticiones
    private var currentTask: URLSessionDataTask?
    // Coalesce in-flight user participations request to avoid cancellations
    private var userParticipationsTask: Task<[EventParticipationWithEvent]?, Never>?
    // Controla el backoff de reintentos cuando una carga se cancela
    private var lastEventsRetryAt: Date?
    
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
        
        // Escuchar notificación de logout para limpiar datos
        NotificationCenter.default.addObserver(
            forName: .userDidLogout,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.clearEventsOnLogout()
        }
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
            // Caché limpiado por UserDataCacheService cuando sea necesario
            self.errorMessage = nil
            self.detailErrorMessage = nil
            self.joinEventErrorMessage = nil
            self.isLoading = true
            
            // Clear UserDefaults cache as well
            self.clearEventsCache()
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
            
            // Removed verbose date parsing logs - parsing date silently
            
            // Formatters para diferentes formatos de fecha
            let formatter1 = ISO8601DateFormatter()
            formatter1.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            formatter1.timeZone = TimeZone(secondsFromGMT: 0)
            
            let formatter2 = ISO8601DateFormatter()
            formatter2.formatOptions = [.withInternetDateTime]
            formatter2.timeZone = TimeZone(secondsFromGMT: 0)
            
            let formatters = [formatter1, formatter2]
            
            for formatter in formatters {
                if let date = formatter.date(from: string) {
                    return date
                }
            }
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
        limit: Int = 100,
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
            // 1) Obtener eventos
            print("📡 [\(taskID)] Fetching events data...")
            let events = try await fetchEventsData(
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
            
            // 2) Actualizar UI con eventos inmediatamente
            if let fetchedEvents = events {
                updateOnMainThread {
                    let sortedEvents = fetchedEvents.sorted { $0.startTime < $1.startTime }
                    self.events = sortedEvents
                    print("📱 Events in memory: \(sortedEvents.count)")
                }
                print("✅ Fetch completed: \(fetchedEvents.count) events")
            } else {
                print("⚠️ No events received from API")
            }
            
            // 3) Lanzar carga de participaciones en paralelo (coalesced)
            Task { [weak self] in
                guard let self = self else { return }
                print("📡 [\(taskID)] Fetching user participations (coalesced)...")
                await self.fetchUserParticipations()
            }
            
        } catch {
            if (error as NSError).code == NSURLErrorCancelled {
                print("⚠️ Fetch operation cancelled [\(taskID)]")
                // Programar un reintento ligero si no hay datos actualmente
                if self.events.isEmpty {
                    let now = Date()
                    let minInterval: TimeInterval = 1.0
                    let canRetry: Bool
                    if let last = lastEventsRetryAt {
                        canRetry = now.timeIntervalSince(last) > minInterval
                    } else {
                        canRetry = true
                    }
                    if canRetry {
                        lastEventsRetryAt = now
                        Task { [weak self] in
                            try? await Task.sleep(nanoseconds: 300_000_000) // 0.3s
                            await self?.fetchEvents(
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
                    } else {
                        print("⏭️ Skipping immediate retry (recent attempt)")
                    }
                }
            } else {
                print("❌ Error fetching events [\(taskID)]: \(error)")
                updateOnMainThread {
                    self.errorMessage = "Error cargando eventos: \(error.localizedDescription)"
                }
            }
        }
        
        // Finalizar estado de carga incluso si hubo cancelación de sub-tareas
        updateOnMainThread {
            self.isLoading = false
            print("✅ Fetch operation completed [\(taskID)]")
        }
    }
    
    // MARK: - Fetch Events Data (Private)
    private func fetchEventsData(
        skip: Int = 0,
        limit: Int = 100,
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
            // Solo agregar header X-Gym-ID si hay un gym seleccionado
            if let gymId = GymService.shared.currentGym?.id {
                print("🏋️ Using X-Gym-ID: \(gymId)")
                request.setValue("\(gymId)", forHTTPHeaderField: "X-Gym-ID")
            } else {
                print("⚠️ No hay gym seleccionado, omitiendo header X-Gym-ID")
            }
            
            // Agregar token de autorización
            if let token = await getAuthToken() {
                request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
                // Token included in request
            } else {
                print("⚠️ No se encontró token de autorización válido")
                // Esperar un poco más por el token después del login
                try? await Task.sleep(nanoseconds: 1_000_000_000) // 1 segundo
                if let delayedToken = await getAuthToken() {
                    request.setValue("Bearer \(delayedToken)", forHTTPHeaderField: "Authorization")
                    print("🔑 Token obtenido después de espera")
                } else {
                    print("❌ Sin token después de espera - mostrando datos mock temporalmente")
                    return createMockEvents()
                }
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
                
                // Log API response summary
                print("📊 API Response: \(fetchedEvents.count) events received")
                print("📊 Event IDs: \(fetchedEvents.map { $0.id }.sorted())")
                if fetchedEvents.count > 0 {
                    print("📊 Latest events: \(fetchedEvents.suffix(5).map { "[\($0.id)] \($0.title)" }.joined(separator: ", "))")
                }
                
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
                        // Esperar un poco más e intentar de nuevo después del login
                        try? await Task.sleep(nanoseconds: 1_500_000_000) // 1.5 segundos
                        if let authService = authService,
                           let retryToken = await authService.getValidAccessToken() {
                            print("🔄 Token obtenido después de espera en retry")
                            var finalRetryRequest = request
                            finalRetryRequest.setValue("Bearer \(retryToken)", forHTTPHeaderField: "Authorization")
                            
                            do {
                                let finalRetryTask = session.dataTask(with: finalRetryRequest)
                                currentTask = finalRetryTask
                                let (finalData, finalResponse) = try await session.data(for: finalRetryRequest)
                                if let finalHttpResponse = finalResponse as? HTTPURLResponse,
                                   finalHttpResponse.statusCode == 200 {
                                    let events = try configuredJSONDecoder().decode([Event].self, from: finalData)
                                    return events
                                }
                            } catch {
                                print("❌ Error en retry final: \(error)")
                            }
                        }
                        print("❌ Sin authService después de espera - mostrando datos mock temporalmente")
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
                // Propagar cancelación para que el caller pueda decidir un reintento
                throw urlError
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
        
        // Agregar header X-Gym-ID si hay un gym seleccionado
        if let gymId = GymService.shared.currentGym?.id {
            request.setValue("\(gymId)", forHTTPHeaderField: "X-Gym-ID")
        } else {
            print("⚠️ No hay gym seleccionado, omitiendo header X-Gym-ID")
        }
        
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
            if let urlError = error as? URLError, urlError.code == .cancelled {
                print("⚠️ User participations request cancelled (overlap/refresh)")
                return nil
            }
            print("❌ Error fetching user participations: \(error)")
            return nil
        }
    }
    
    // MARK: - Update User Registration Status (Private)
    private func updateUserRegistrationStatus(from participations: [EventParticipationWithEvent]) {
        updateOnMainThread {
            // Actualizar el estado de registro para cada evento
            self.userRegistrationStatus.removeAll()
            
            // Update registration status for all participations
            var registeredEvents: [Int] = []
            for participation in participations {
                // Solo considerar participaciones activas (no canceladas)
                let isRegistered = participation.status == "REGISTERED"
                self.userRegistrationStatus[participation.eventId] = isRegistered
                if isRegistered {
                    registeredEvents.append(participation.eventId)
                }
            }
            
            print("📝 User registered for events: \(registeredEvents.sorted())")
            print("📝 Total registration map: \(self.userRegistrationStatus.count) events")
        }
    }

    // MARK: - Fetch User Participations (Mantener compatibilidad)
    func fetchUserParticipations() async {
        // Coalesce concurrent calls to avoid cancelling each other
        if let task = userParticipationsTask {
            print("🔄 Using in-flight user participations task")
            if let participations = await task.value {
                updateUserRegistrationStatus(from: participations)
            }
            return
        }
        let task = Task { [weak self] in
            return await self?.fetchUserParticipationsData()
        }
        userParticipationsTask = task
        let result = await task.value
        if let participations = result {
            updateUserRegistrationStatus(from: participations)
        }
        userParticipationsTask = nil
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
            
            // Agregar header X-Gym-ID si hay un gym seleccionado
            if let gymId = GymService.shared.currentGym?.id {
                request.setValue("\(gymId)", forHTTPHeaderField: "X-Gym-ID")
            } else {
                print("⚠️ No hay gym seleccionado, omitiendo header X-Gym-ID")
            }
            
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
            
            // Agregar header X-Gym-ID si hay un gym seleccionado
            if let gymId = GymService.shared.currentGym?.id {
                request.setValue("\(gymId)", forHTTPHeaderField: "X-Gym-ID")
            } else {
                print("⚠️ No hay gym seleccionado, omitiendo header X-Gym-ID")
            }
            
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
            
            if httpResponse.statusCode == 200 {
                let participations = try configuredJSONDecoder().decode([EventParticipation].self, from: data)
                updateOnMainThread {
                    self.eventParticipations = participations
                }
                
                print("✅ Participations: \(participations.count) found")
                
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
        // Usar UserDataCacheService para obtener perfil (con caché automático)
        if let cachedProfile = await userCache.getUserProfile(userId) {
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
            
            // Agregar header X-Gym-ID si hay un gym seleccionado
            if let gymId = GymService.shared.currentGym?.id {
                request.setValue("\(gymId)", forHTTPHeaderField: "X-Gym-ID")
            } else {
                print("⚠️ No hay gym seleccionado, omitiendo header X-Gym-ID")
            }
            
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
                // Guardar en caché centralizado
                userCache.updateUserProfile(userId, profile: userProfile)
                
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
        // Removed verbose registration check log
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
            // Agregar header X-Gym-ID si hay un gym seleccionado
            if let gymId = GymService.shared.currentGym?.id {
                request.setValue("\(gymId)", forHTTPHeaderField: "X-Gym-ID")
            } else {
                print("⚠️ No hay gym seleccionado, omitiendo header X-Gym-ID")
            }
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
                
                // Sincronizar participaciones del usuario para mantener consistencia global
                Task { [weak self] in
                    await self?.fetchUserParticipations()
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
            // Agregar header X-Gym-ID si hay un gym seleccionado
            if let gymId = GymService.shared.currentGym?.id {
                request.setValue("\(gymId)", forHTTPHeaderField: "X-Gym-ID")
            } else {
                print("⚠️ No hay gym seleccionado, omitiendo header X-Gym-ID")
            }
            
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
                    
                    // Refrescar participaciones del usuario para mantener consistencia global
                    Task { [weak self] in
                        await self?.fetchUserParticipations()
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
    
    // MARK: - Logout & Cleanup
    func clearEventsOnLogout() {
        print("🧹 Clearing events data on logout")
        updateOnMainThread {
            self.events = []
            self.userParticipations = []
            self.eventDetail = nil
            self.eventParticipations = []
            self.userRegistrationStatus = [:]
            // Caché manejado por UserDataCacheService
            
            // Resetear estados de loading
            self.isLoading = false
            self.isLoadingDetail = false
            self.isLoadingParticipations = false
            self.isJoiningEvent = false
            
            // Limpiar mensajes de error
            self.errorMessage = nil
            self.detailErrorMessage = nil
            self.participationsErrorMessage = nil
            self.joinEventErrorMessage = nil
            
            // Limpiar cache de UserDefaults
            self.clearEventsCache()
        }
    }
    
    /// Alias para mantener consistencia con otros servicios
    func clearAllData() {
        clearEventsOnLogout()
    }
    
    /// Limpia el cache de eventos de UserDefaults
    private func clearEventsCache() {
        let allKeys = UserDefaults.standard.dictionaryRepresentation().keys
        for key in allKeys {
            if key.contains("CachedEvents_") {
                UserDefaults.standard.removeObject(forKey: key)
            }
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
    
    // MARK: - Create Event
    func createEvent(_ request: CreateEventRequest) async -> Bool {
        updateOnMainThread {
            self.isCreatingEvent = true
            self.createEventErrorMessage = nil
        }
        
        print("🎉 Creating event: \(request.title)")
        
        guard let url = URL(string: "\(baseURL)/events/") else {
            updateOnMainThread {
                self.createEventErrorMessage = "URL inválida"
                self.isCreatingEvent = false
            }
            return false
        }
        
        // Create authenticated request
        guard let httpRequest = await HTTPClient.shared.makeRequest(
            url: url,
            method: "POST",
            includeGymHeader: true
        ) else {
            updateOnMainThread {
                self.createEventErrorMessage = "No se pudo crear la solicitud autenticada"
                self.isCreatingEvent = false
            }
            return false
        }
        
        // Configure request
        var urlRequest = httpRequest
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        // Encode request body
        do {
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            urlRequest.httpBody = try encoder.encode(request)
            
            print("🎉 Request body created successfully")
            
        } catch {
            updateOnMainThread {
                self.createEventErrorMessage = "Error al codificar los datos del evento: \(error.localizedDescription)"
                self.isCreatingEvent = false
            }
            return false
        }
        
        // Make API call
        do {
            let (data, response) = try await session.data(for: urlRequest)
            
            if let httpResponse = response as? HTTPURLResponse {
                print("🎉 API Response status: \(httpResponse.statusCode)")
                
                if httpResponse.statusCode == 200 || httpResponse.statusCode == 201 {
                    // Success - decode response (200 or 201 are both valid)
                    do {
                        let decoder = configuredJSONDecoder()
                        let eventResponse = try decoder.decode(CreateEventResponse.self, from: data)
                        
                        updateOnMainThread {
                            self.isCreatingEvent = false
                        }
                        
                        print("✅ Event created successfully: \(eventResponse.title) (ID: \(eventResponse.id))")
                        
                        // Force refresh events list to clear cache and get latest data
                        await forceRefresh()
                        await fetchUserParticipations()
                        
                        return true
                        
                    } catch {
                        updateOnMainThread {
                            self.createEventErrorMessage = "Error al procesar la respuesta del servidor: \(error.localizedDescription)"
                            self.isCreatingEvent = false
                        }
                        print("❌ Error decoding event response: \(error)")
                        return false
                    }
                    
                } else {
                    // Handle different error status codes
                    let errorMessage = await handleCreateEventAPIError(data: data, statusCode: httpResponse.statusCode)
                    
                    updateOnMainThread {
                        self.createEventErrorMessage = errorMessage
                        self.isCreatingEvent = false
                    }
                    
                    return false
                }
            }
            
        } catch {
            updateOnMainThread {
                self.createEventErrorMessage = "Error de conexión: \(error.localizedDescription)"
                self.isCreatingEvent = false
            }
            print("❌ Network error creating event: \(error)")
            return false
        }
        
        updateOnMainThread {
            self.createEventErrorMessage = "Error desconocido"
            self.isCreatingEvent = false
        }
        return false
    }
    
    // MARK: - Handle Create Event API Error
    private func handleCreateEventAPIError(data: Data, statusCode: Int) async -> String {
        // Try to decode error response
        if let errorString = String(data: data, encoding: .utf8) {
            print("❌ Create Event API Error (\(statusCode)): \(errorString)")
        }
        
        switch statusCode {
        case 400:
            return "Datos del evento inválidos. Verifica que todos los campos estén correctos."
        case 401:
            return "No tienes autorización. Inicia sesión nuevamente."
        case 403:
            return "No tienes permisos para crear eventos. Contacta al administrador."
        case 409:
            return "Ya existe un evento con estas características."
        case 422:
            return "Datos del evento inválidos."
        case 500:
            return "Error del servidor. Intenta nuevamente en unos minutos."
        default:
            return "Error inesperado (\(statusCode)). Contacta al soporte."
        }
    }
    
    // MARK: - Update Event
    func updateEvent(eventId: Int, request: UpdateEventRequest) async -> Bool {
        updateOnMainThread {
            self.isCreatingEvent = true
            self.createEventErrorMessage = nil
        }
        
        print("🔄 Updating event: \(eventId)")
        
        guard let url = URL(string: "\(baseURL)/events/\(eventId)") else {
            updateOnMainThread {
                self.createEventErrorMessage = "URL inválida"
                self.isCreatingEvent = false
            }
            return false
        }
        
        // Create authenticated request
        guard let httpRequest = await HTTPClient.shared.makeRequest(
            url: url,
            method: "PUT",
            includeGymHeader: true
        ) else {
            updateOnMainThread {
                self.createEventErrorMessage = "No se pudo crear la solicitud autenticada"
                self.isCreatingEvent = false
            }
            return false
        }
        
        // Configure request
        var urlRequest = httpRequest
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        // Encode request body
        do {
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            urlRequest.httpBody = try encoder.encode(request)
            
            print("🔄 Update request body created successfully")
            
        } catch {
            updateOnMainThread {
                self.createEventErrorMessage = "Error al codificar los datos del evento: \(error.localizedDescription)"
                self.isCreatingEvent = false
            }
            return false
        }
        
        // Make API call
        do {
            let (data, response) = try await session.data(for: urlRequest)
            
            if let httpResponse = response as? HTTPURLResponse {
                print("🔄 Update API Response status: \(httpResponse.statusCode)")
                
                if httpResponse.statusCode == 200 {
                    // Success - decode response
                    do {
                        let decoder = configuredJSONDecoder()
                        let eventResponse = try decoder.decode(CreateEventResponse.self, from: data)
                        
                        updateOnMainThread {
                            self.isCreatingEvent = false
                        }
                        
                        print("✅ Event updated successfully: \(eventResponse.title) (ID: \(eventResponse.id))")
                        
                        // Update the event in the local list
                        updateOnMainThread {
                            if let index = self.events.firstIndex(where: { $0.id == eventId }) {
                                let updatedEvent = Event(
                                    id: eventResponse.id,
                                    title: eventResponse.title,
                                    description: eventResponse.description,
                                    startTime: eventResponse.startTime,
                                    endTime: eventResponse.endTime,
                                    location: eventResponse.location,
                                    maxParticipants: eventResponse.maxParticipants,
                                    status: EventStatus(rawValue: eventResponse.status) ?? .scheduled,
                                    creatorId: eventResponse.creatorId,
                                    createdAt: eventResponse.createdAt,
                                    updatedAt: eventResponse.updatedAt,
                                    participantsCount: eventResponse.participantsCount
                                )
                                self.events[index] = updatedEvent
                            }
                            
                            // Update event detail if it's the same event
                            if let eventDetail = self.eventDetail, eventDetail.id == eventId {
                                let updatedDetail = EventDetail(
                                    id: eventResponse.id,
                                    title: eventResponse.title,
                                    description: eventResponse.description,
                                    startTime: eventResponse.startTime,
                                    endTime: eventResponse.endTime,
                                    location: eventResponse.location,
                                    maxParticipants: eventResponse.maxParticipants,
                                    status: EventStatus(rawValue: eventResponse.status) ?? .scheduled,
                                    creatorId: eventResponse.creatorId,
                                    createdAt: eventResponse.createdAt,
                                    updatedAt: eventResponse.updatedAt,
                                    participantsCount: eventResponse.participantsCount
                                )
                                self.eventDetail = updatedDetail
                            }
                        }
                        
                        return true
                        
                    } catch {
                        updateOnMainThread {
                            self.createEventErrorMessage = "Error al procesar la respuesta del servidor: \(error.localizedDescription)"
                            self.isCreatingEvent = false
                        }
                        print("❌ Error decoding update event response: \(error)")
                        return false
                    }
                    
                } else {
                    // Handle different error status codes
                    let errorMessage = await handleUpdateEventAPIError(data: data, statusCode: httpResponse.statusCode)
                    
                    updateOnMainThread {
                        self.createEventErrorMessage = errorMessage
                        self.isCreatingEvent = false
                    }
                    
                    return false
                }
            }
            
        } catch {
            updateOnMainThread {
                self.createEventErrorMessage = "Error de conexión: \(error.localizedDescription)"
                self.isCreatingEvent = false
            }
            print("❌ Network error updating event: \(error)")
            return false
        }
        
        updateOnMainThread {
            self.createEventErrorMessage = "Error desconocido"
            self.isCreatingEvent = false
        }
        return false
    }
    
    // MARK: - Delete Event
    func deleteEvent(eventId: Int) async -> Bool {
        updateOnMainThread {
            self.isCreatingEvent = true
            self.createEventErrorMessage = nil
        }
        
        print("🗑️ Deleting event: \(eventId)")
        
        guard let url = URL(string: "\(baseURL)/events/\(eventId)") else {
            updateOnMainThread {
                self.createEventErrorMessage = "URL inválida"
                self.isCreatingEvent = false
            }
            return false
        }
        
        // Create authenticated request
        guard let httpRequest = await HTTPClient.shared.makeRequest(
            url: url,
            method: "DELETE",
            includeGymHeader: true
        ) else {
            updateOnMainThread {
                self.createEventErrorMessage = "No se pudo crear la solicitud autenticada"
                self.isCreatingEvent = false
            }
            return false
        }
        
        // Make API call
        do {
            let (_, response) = try await session.data(for: httpRequest)
            
            if let httpResponse = response as? HTTPURLResponse {
                print("🗑️ Delete API Response status: \(httpResponse.statusCode)")
                
                if httpResponse.statusCode == 204 {
                    // Success - event deleted
                    updateOnMainThread {
                        self.isCreatingEvent = false
                    }
                    
                    print("✅ Event deleted successfully: \(eventId)")
                    
                    // Remove event from local list and clear detail if needed
                    updateOnMainThread {
                        self.events.removeAll { $0.id == eventId }
                        
                        if let eventDetail = self.eventDetail, eventDetail.id == eventId {
                            self.eventDetail = nil
                        }
                        
                        // Remove all participations for this event
                        self.eventParticipations.removeAll { $0.eventId == eventId }
                        self.userRegistrationStatus.removeValue(forKey: eventId)
                    }
                    
                    return true
                    
                } else {
                    // Handle different error status codes
                    let errorMessage = await handleDeleteEventAPIError(statusCode: httpResponse.statusCode)
                    
                    updateOnMainThread {
                        self.createEventErrorMessage = errorMessage
                        self.isCreatingEvent = false
                    }
                    
                    return false
                }
            }
            
        } catch {
            updateOnMainThread {
                self.createEventErrorMessage = "Error de conexión: \(error.localizedDescription)"
                self.isCreatingEvent = false
            }
            print("❌ Network error deleting event: \(error)")
            return false
        }
        
        updateOnMainThread {
            self.createEventErrorMessage = "Error desconocido"
            self.isCreatingEvent = false
        }
        return false
    }
    
    // MARK: - Handle Update Event API Error
    private func handleUpdateEventAPIError(data: Data, statusCode: Int) async -> String {
        // Try to decode error response
        if let errorString = String(data: data, encoding: .utf8) {
            print("❌ Update Event API Error (\(statusCode)): \(errorString)")
        }
        
        switch statusCode {
        case 400:
            return "Datos del evento inválidos. Verifica que todos los campos estén correctos."
        case 401:
            return "No tienes autorización. Inicia sesión nuevamente."
        case 403:
            return "No tienes permisos para editar este evento."
        case 404:
            return "El evento no fue encontrado."
        case 422:
            return "Datos del evento inválidos."
        case 500:
            return "Error del servidor. Intenta nuevamente en unos minutos."
        default:
            return "Error inesperado (\(statusCode)). Contacta al soporte."
        }
    }
    
    // MARK: - Handle Delete Event API Error
    private func handleDeleteEventAPIError(statusCode: Int) async -> String {
        print("❌ Delete Event API Error (\(statusCode))")
        
        switch statusCode {
        case 401:
            return "No tienes autorización. Inicia sesión nuevamente."
        case 403:
            return "No tienes permisos para eliminar este evento."
        case 404:
            return "El evento no fue encontrado."
        case 500:
            return "Error del servidor. Intenta nuevamente en unos minutos."
        default:
            return "Error inesperado (\(statusCode)). Contacta al soporte."
        }
    }
    
    // MARK: - Bulk Registration Methods
    
    /// Registra múltiples usuarios en un evento (solo ADMIN/OWNER)
    func bulkRegisterUsersToEvent(eventId: Int, userIds: [Int]) async -> Bool {
        print("🔄 Iniciando registro masivo para evento \(eventId) con \(userIds.count) usuarios")

        // Verificación defensiva de permisos en cliente (el backend seguirá validando)
        if !RolePermissions.canBulkRegisterUsers(GymService.shared.currentGym?.userRoleInGym) {
            await updateOnMainThread {
                self.joinEventErrorMessage = "Permisos insuficientes para realizar el registro masivo"
            }
            return false
        }
        
        // Validar que hay usuarios para registrar
        guard !userIds.isEmpty else {
            await updateOnMainThread {
                self.joinEventErrorMessage = "No hay usuarios seleccionados para registrar"
            }
            return false
        }
        
        // Validar que el URL es válido
        guard let url = URL(string: "\(baseURL)/events/participation/bulk") else {
            await updateOnMainThread {
                self.joinEventErrorMessage = "URL inválida"
            }
            return false
        }
        
        // Validar que tenemos AuthService
        guard let authService = authService else {
            await updateOnMainThread {
                self.joinEventErrorMessage = "No se encontró servicio de autenticación"
            }
            return false
        }
        
        // Validar que tenemos token
        guard let token = await authService.getValidAccessToken() else {
            await updateOnMainThread {
                self.joinEventErrorMessage = "No se encontró token de autorización válido"
            }
            return false
        }
        
        // Validar que tenemos gym ID
        guard let gymId = GymService.shared.currentGymId else {
            await updateOnMainThread {
                self.joinEventErrorMessage = "No se encontró ID del gimnasio"
            }
            return false
        }
        
        await updateOnMainThread {
            self.isJoiningEvent = true
            self.joinEventErrorMessage = nil
        }
        
        do {
            // Crear el request body
            let requestBody = BulkEventRegistrationRequest(eventId: eventId, userIds: userIds)
            let jsonData = try JSONEncoder().encode(requestBody)
            
            // Debug: imprimir el JSON que se está enviando
            if let jsonString = String(data: jsonData, encoding: .utf8) {
                print("📋 Request JSON: \(jsonString)")
            }
            
            // Configurar la petición
            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
            request.setValue("\(gymId)", forHTTPHeaderField: "X-Gym-ID")
            request.httpBody = jsonData
            
            print("📤 Enviando petición de registro masivo...")
            print("🎯 URL: \(url)")
            print("🏢 Gym ID: \(gymId)")
            print("👥 User IDs: \(userIds)")
            
            let (data, response) = try await session.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                await updateOnMainThread {
                    self.joinEventErrorMessage = "Respuesta inválida del servidor"
                    self.isJoiningEvent = false
                }
                return false
            }
            
            print("📥 Respuesta recibida con código: \(httpResponse.statusCode)")
            
            switch httpResponse.statusCode {
            case 201:
                // Registro exitoso
                do {
                    // Debug: mostrar respuesta cruda del servidor para verificar formato
                    if let rawResponse = String(data: data, encoding: .utf8) {
                        print("✅ Respuesta 201 del servidor: \(rawResponse)")
                    }
                    
                    let registrations = try configuredJSONDecoder().decode([EventParticipation].self, from: data)
                    await updateOnMainThread {
                        self.isJoiningEvent = false
                        self.joinEventErrorMessage = nil
                        print("✅ Registro masivo exitoso: \(registrations.count) usuarios registrados")
                        
                        // Actualizar las participaciones del evento actual (si están cargadas)
                        for registration in registrations {
                            if !self.eventParticipations.contains(where: { $0.id == registration.id }) {
                                self.eventParticipations.append(registration)
                            }
                        }

                        // Actualizar contadores locales del evento
                        if let index = self.events.firstIndex(where: { $0.id == eventId }) {
                            self.events[index].participantsCount += registrations.count
                        }
                        if let detail = self.eventDetail, detail.id == eventId {
                            let newCount = detail.participantsCount + registrations.count
                            self.eventDetail = EventDetail(
                                id: detail.id,
                                title: detail.title,
                                description: detail.description,
                                startTime: detail.startTime,
                                endTime: detail.endTime,
                                location: detail.location,
                                maxParticipants: detail.maxParticipants,
                                status: detail.status,
                                creatorId: detail.creatorId,
                                createdAt: detail.createdAt,
                                updatedAt: detail.updatedAt,
                                participantsCount: newCount
                            )
                        }

                        // Si el usuario actual fue parte del registro masivo, actualizar su estado para este evento
                        if let currentUserIdString = self.authService?.user?.id, let currentUserId = Int(currentUserIdString) {
                            if userIds.contains(currentUserId) {
                                self.updateUserRegistrationStatus(eventId: eventId, isRegistered: true)
                            }
                        }
                    }

                    // Refrescar participaciones desde el servidor para asegurar consistencia
                    await self.fetchEventParticipations(eventId: eventId)
                    return true
                } catch {
                    print("❌ Error decodificando respuesta del servidor: \(error)")
                    if let decodingError = error as? DecodingError {
                        print("❌ DecodingError details: \(decodingError)")
                    }
                    await updateOnMainThread {
                        self.joinEventErrorMessage = "Error al procesar la respuesta del servidor: \(error.localizedDescription)"
                        self.isJoiningEvent = false
                    }
                    return false
                }
                
            case 400:
                // Debug: mostrar respuesta cruda del servidor
                if let rawResponse = String(data: data, encoding: .utf8) {
                    print("❌ Error 400 - Respuesta del servidor: \(rawResponse)")
                }
                let errorMessage = await handleBulkRegistrationAPIError(data: data, statusCode: httpResponse.statusCode)
                await updateOnMainThread {
                    self.joinEventErrorMessage = errorMessage
                    self.isJoiningEvent = false
                }
                return false
                
            case 401:
                await updateOnMainThread {
                    self.joinEventErrorMessage = "Token de autorización inválido o expirado"
                    self.isJoiningEvent = false
                }
                return false
                
            case 403:
                await updateOnMainThread {
                    self.joinEventErrorMessage = "Permisos insuficientes para realizar el registro masivo"
                    self.isJoiningEvent = false
                }
                return false
                
            case 404:
                await updateOnMainThread {
                    self.joinEventErrorMessage = "Evento no encontrado"
                    self.isJoiningEvent = false
                }
                return false
                
            case 422:
                let errorMessage = await handleBulkRegistrationAPIError(data: data, statusCode: httpResponse.statusCode)
                await updateOnMainThread {
                    self.joinEventErrorMessage = errorMessage
                    self.isJoiningEvent = false
                }
                return false
                
            default:
                await updateOnMainThread {
                    self.joinEventErrorMessage = "Error del servidor: \(httpResponse.statusCode)"
                    self.isJoiningEvent = false
                }
                return false
            }
            
        } catch {
            await updateOnMainThread {
                self.joinEventErrorMessage = "Error al realizar el registro masivo: \(error.localizedDescription)"
                self.isJoiningEvent = false
            }
            return false
        }
    }
    
    /// Maneja errores específicos de la API de registro masivo
    private func handleBulkRegistrationAPIError(data: Data, statusCode: Int) async -> String {
        print("🔍 Intentando decodificar error del servidor...")
        
        // Intentar formato de error simple con "detail"
        do {
            let decoder = JSONDecoder()
            if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
               let detail = json["detail"] as? String {
                print("✅ Error decodificado con detail: \(detail)")
                return detail
            }
        } catch {
            print("⚠️ No se pudo decodificar JSON simple: \(error)")
        }
        
        // Mostrar respuesta cruda para debugging
        if let rawResponse = String(data: data, encoding: .utf8) {
            print("📄 Respuesta cruda del servidor: \(rawResponse)")
        }
        
        // Fallback a mensajes por defecto basados en código de estado
        switch statusCode {
        case 400:
            return "Solicitud malformada o datos inválidos. Verifique que los usuarios pertenezcan al gimnasio."
        case 422:
            return "Error de validación en los datos proporcionados"
        default:
            return "Error inesperado (\(statusCode))"
        }
    }

    deinit {
        #if DEBUG
        print("🗑️ EventService deinitialized")
        #endif
        // Los arrays se limpiarán automáticamente con ARC
        // No podemos modificar propiedades @Published desde deinit en una clase @MainActor
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
