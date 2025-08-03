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
    
    // MARK: - Private Properties
    private var trainerMap: [Int: UserPublicProfile] = [:]
    
    // MARK: - Date Range Caching
    private var loadedStartDate: Date?
    private var loadedEndDate: Date?
    
    // MARK: - Task Management
    private var currentSessionTask: Task<Void, Never>?
    private var currentMyClassesTask: Task<Void, Never>?
    
    private let baseURL = "https://gymapi-eh6m.onrender.com/api/v1"
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
    
    // Función utilitaria para configurar JSONDecoder con formato de fecha correcto
    private func configuredJSONDecoder() -> JSONDecoder {
        let decoder = JSONDecoder()
        
        decoder.dateDecodingStrategy = .custom { decoder in
            let container = try decoder.singleValueContainer()
            let dateString = try container.decode(String.self)
            
            // Solución para iOS 18.6+ usando Date.ISO8601FormatStyle
            if #available(iOS 15.0, *) {
                // Intentar con diferentes configuraciones de ISO8601FormatStyle
                let formatStyles: [Date.ISO8601FormatStyle] = [
                    // Formato con fracciones de segundo
                    Date.ISO8601FormatStyle(includingFractionalSeconds: true),
                    // Formato estándar sin fracciones
                    Date.ISO8601FormatStyle(includingFractionalSeconds: false),
                    // Formato con zona horaria UTC
                    Date.ISO8601FormatStyle(timeZone: TimeZone(secondsFromGMT: 0)!),
                ]
                
                for formatStyle in formatStyles {
                    do {
                        let date = try formatStyle.parse(dateString)
                        return date
                    } catch {
                        continue
                    }
                }
                
                // Intentar agregando 'Z' al final si no la tiene
                if !dateString.hasSuffix("Z") && !dateString.contains("+") && !dateString.dropFirst(10).contains("-") {
                    let dateStringWithZ = dateString + "Z"
                    for formatStyle in formatStyles {
                        do {
                            let date = try formatStyle.parse(dateStringWithZ)
                            return date
                        } catch {
                            continue
                        }
                    }
                }
            }
            
            // Fallback para versiones anteriores de iOS o si ISO8601FormatStyle falla
            let formatter = DateFormatter()
            formatter.locale = Locale(identifier: "en_US_POSIX")
            formatter.timeZone = TimeZone(secondsFromGMT: 0) // Las fechas del servidor vienen en UTC
            
            let dateFormats = [
                "yyyy-MM-dd'T'HH:mm:ss'Z'",
                "yyyy-MM-dd'T'HH:mm:ss",
                "yyyy-MM-dd'T'HH:mm:ss.SSSSSS'Z'",
                "yyyy-MM-dd'T'HH:mm:ss.SSS'Z'",
                "yyyy-MM-dd'T'HH:mm:ss.SSSSSS",
                "yyyy-MM-dd'T'HH:mm:ss.SSS"
            ]
            
            for format in dateFormats {
                formatter.dateFormat = format
                if let date = formatter.date(from: dateString) {
                    return date
                }
            }
            
            // Último intento: agregar Z si no existe
            if !dateString.hasSuffix("Z") && !dateString.contains("+") && !dateString.dropFirst(10).contains("-") {
                let dateStringWithZ = dateString + "Z"
                for format in dateFormats {
                    formatter.dateFormat = format
                    if let date = formatter.date(from: dateStringWithZ) {
                        return date
                    }
                }
            }
            
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "Cannot decode date string '\(dateString)'. This appears to be an iOS 18.6 date decoding issue. Tried multiple formats including ISO8601FormatStyle.")
        }
        
        return decoder
    }
    
    // MARK: - Get Auth Token
    private func getAuthToken() async -> String? {
        guard let authService = authService else {
            print("⚠️ AuthService no disponible")
            return nil
        }
        
        return await authService.getValidAccessToken()
    }
    
    // MARK: - Force Refresh
    func forceRefreshSessions(date: Date) async {
        // Cancelar tasks anteriores
        currentSessionTask?.cancel()
        
        // Limpiar el cache para forzar recarga
        loadedStartDate = nil
        loadedEndDate = nil
        
        // Crear nueva task y cargar de nuevo
        currentSessionTask = Task {
            await loadSessionsForDateIfNeeded(date: date)
        }
        await currentSessionTask?.value
    }
    
    // MARK: - Force Refresh My Classes
    func forceRefreshMyClasses() async {
        // Cancelar task anterior
        currentMyClassesTask?.cancel()
        
        // Crear nueva task
        currentMyClassesTask = Task {
            await fetchMyClasses()
        }
        await currentMyClassesTask?.value
    }
    
    // MARK: - Smart Date Range Loading
    func loadSessionsForDateIfNeeded(date: Date) async {
        let calendar = Calendar.current
        
        // Verificar si la fecha está dentro del rango cargado
        if let loadedStart = loadedStartDate,
           let loadedEnd = loadedEndDate,
           date >= loadedStart && date <= loadedEnd {
            // Ya tenemos los datos para esta fecha
            return
        }
        
        // Calcular el nuevo rango necesario
        let today = Date()
        let selectedDayOffset = calendar.dateComponents([.day], from: today, to: date).day ?? 0
        
        var newStartDate: Date
        var newEndDate: Date
        
        if selectedDayOffset < -3 {
            // Usuario seleccionó fecha muy antigua, extender hacia atrás
            newStartDate = calendar.date(byAdding: .day, value: selectedDayOffset - 3, to: today) ?? date
            newEndDate = calendar.date(byAdding: .day, value: 7, to: today) ?? date
        } else if selectedDayOffset > 7 {
            // Usuario seleccionó fecha muy futura, extender hacia adelante
            newStartDate = calendar.date(byAdding: .day, value: -3, to: today) ?? date
            newEndDate = calendar.date(byAdding: .day, value: selectedDayOffset + 7, to: today) ?? date
        } else {
            // Rango estándar inicial
            newStartDate = calendar.date(byAdding: .day, value: -3, to: today) ?? date
            newEndDate = calendar.date(byAdding: .day, value: 7, to: today) ?? date
        }
        
        // Si ya tenemos datos, expandir el rango existente en lugar de reemplazar
        if let existingStart = loadedStartDate, let existingEnd = loadedEndDate {
            newStartDate = min(newStartDate, existingStart)
            newEndDate = max(newEndDate, existingEnd)
        }
        
        await fetchSessionsByDateRange(startDate: newStartDate, endDate: newEndDate)
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
            
            var request = URLRequest(url: url)
            request.httpMethod = "GET"
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.setValue("application/json", forHTTPHeaderField: "accept")
            
            // Agregar header X-Gym-ID
            let gymId = GymService.shared.currentGymId ?? 4
            request.setValue("\(gymId)", forHTTPHeaderField: "X-Gym-ID")
            
            // Agregar token de autorización
            if let token = await getAuthToken() {
                request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
                print("🔑 Token incluido en petición de sesiones por rango de fecha")
            } else {
                print("⚠️ No se encontró token de autorización válido para sesiones")
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
            let gymId = GymService.shared.currentGymId ?? 4
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
        
        // Validar si la sesión está disponible antes de enviar la petición
        let sessionWithClass = await MainActor.run { 
            self.sessions.first(where: { $0.session.id == sessionId }) 
        }
        
        if let sessionWithClass = sessionWithClass {
            if !sessionWithClass.canJoinNow {
                let errorMessage = "No se puede unir a esta clase en este momento. " + sessionWithClass.timeUntilClass
                _ = await MainActor.run {
                    self.joinClassErrorMessages[sessionId] = errorMessage
                    self.joiningClassIds.remove(sessionId)
                }
                print("❌ Validación local falló: \(errorMessage)")
                return
            }
        }
        
        do {
            guard let url = URL(string: "\(baseURL)/schedule/participation/register/\(sessionId)") else {
                throw ClassServiceError.invalidURL
            }
            
            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.setValue("application/json", forHTTPHeaderField: "accept")
            let gymId = GymService.shared.currentGymId ?? 4
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
            if let sessionWithClass = sessionWithClass {
                let now = Date()
                let formatter = DateFormatter()
                formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
                formatter.timeZone = TimeZone.current
                
                print("🕐 Debugging zona horaria:")
                print("🕐 Hora actual local: \(formatter.string(from: now))")
                print("🕐 Inicio clase local: \(formatter.string(from: sessionWithClass.session.startTime))")
                print("🕐 Zona horaria actual: \(TimeZone.current.identifier)")
                print("🕐 canJoinNow: \(sessionWithClass.canJoinNow)")
                print("🕐 timeUntilClass: \(sessionWithClass.timeUntilClass)")
            }
            
            let (data, response) = try await session.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                throw ClassServiceError.invalidResponse
            }
            
            print("📡 Response status for registration: \(httpResponse.statusCode)")
            
            if httpResponse.statusCode == 200 {
                _ = try configuredJSONDecoder().decode(ClassParticipation.self, from: data)
                print("✅ Successfully registered for class session \(sessionId)")
                
                _ = await MainActor.run {
                    self.userRegistrationStatus[sessionId] = true
                    print("🔄 Estado de registro actualizado para sesión \(sessionId)")
                }
            } else {
                let errorMessage = try? JSONDecoder().decode(APIError.self, from: data)
                let message = errorMessage?.detail ?? "Error del servidor: \(httpResponse.statusCode)"
                print("❌ \(message)")
                
                // Si el error es que ya está registrado, actualizar el estado
                if httpResponse.statusCode == 400 && message.contains("Ya estás registrado") {
                    _ = await MainActor.run {
                        self.userRegistrationStatus[sessionId] = true
                        print("🔄 Usuario ya registrado en sesión \(sessionId), actualizando estado")
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
            let gymId = GymService.shared.currentGymId ?? 4
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
                
                _ = await MainActor.run {
                    self.userRegistrationStatus[sessionId] = false
                    print("🔄 Estado de registro actualizado para sesión \(sessionId) - Cancelado")
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
            
            var request = URLRequest(url: url)
            request.httpMethod = "GET"
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.setValue("application/json", forHTTPHeaderField: "accept")
            
            // Agregar header X-Gym-ID
            let gymId = GymService.shared.currentGymId ?? 4
            request.setValue("\(gymId)", forHTTPHeaderField: "X-Gym-ID")
            
            // Agregar token de autorización
            if let token = await getAuthToken() {
                request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
                print("🔑 Token incluido en petición de mis clases:")
                print("🔑 - Primeros 50 chars: \(token.prefix(50))...")
            } else {
                print("⚠️ No se encontró token de autorización válido para mis clases")
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
                
                _ = await MainActor.run {
                    // Actualizar el estado de registro basado en la respuesta simple
                    for myClass in myClassesResponse {
                        self.userRegistrationStatus[myClass.sessionId] = (myClass.participationStatus == "registered")
                        print("🔄 Marcando sesión \(myClass.sessionId) como \(myClass.participationStatus)")
                    }
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
        do {
            guard let url = URL(string: "\(baseURL)/users/p/gym-participants?role=TRAINER&skip=0&limit=100") else {
                throw ClassServiceError.invalidURL
            }
            
            var request = URLRequest(url: url)
            request.httpMethod = "GET"
            
            // Agregar headers de autorización
            if let token = UserDefaults.standard.string(forKey: "auth0_access_token") {
                request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
                print("🔑 Token agregado: Bearer \(token.prefix(20))...")
            } else {
                print("❌ No se encontró token en auth0_access_token")
            }
            
            // Agregar header del gym
            let gymId = GymService.shared.currentGymId ?? 4
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
                    self.trainerMap = Dictionary(uniqueKeysWithValues: loadedTrainers.map { ($0.id, $0) })
                }
            } else {
                print("❌ Error loading trainers: HTTP \(httpResponse.statusCode)")
            }
            
        } catch {
            print("❌ Error loading trainers: \(error)")
        }
    }
    
    // MARK: - Helper Methods
    func isUserRegistered(sessionId: Int) -> Bool {
        return userRegistrationStatus[sessionId] == true
    }
    
    func getTrainerName(trainerId: Int) -> String {
        if let trainer = trainerMap[trainerId] {
            return trainer.fullName
        }
        return "Coach \(trainerId)"
    }
    
    func getTrainer(trainerId: Int) -> UserPublicProfile? {
        return trainerMap[trainerId]
    }
    
    // MARK: - Clear Cache
    
    /// Limpia todos los datos de clases en cache
    func clearCache() {
        print("🧹 Limpiando cache de clases...")
        
        // Limpiar arrays
        sessions = []
        trainers = []
        joiningClassIds = []
        cancellingClassIds = []
        userRegistrationStatus = [:]
        joinClassErrorMessages = [:]
        cancelClassErrorMessages = [:]
        
        // Resetear estados
        isLoading = false
        isLoadingMyClasses = false
        errorMessage = nil
        myClassesErrorMessage = nil
        
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
                
                print("🏗️ ClassService: Parsed iso_with_timezone for class \(sessionWithClass.session.id)")
                print("🏗️ ISO string: \(sessionWithClass.session.timeInfo.isoWithTimezone)")
                print("🏗️ Parsed date: \(preciseDate)")
            } else {
                print("⚠️ ClassService: Failed to parse iso_with_timezone, using original dates")
            }
            
            return GymClass(
                id: sessionWithClass.session.id,
                name: sessionWithClass.classInfo.name,
                description: sessionWithClass.classInfo.description,
                instructor: sessionWithClass.trainerName,
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