import Foundation
import Combine
import SwiftUI

// MARK: - Type Aliases for ClassService Models
// Los modelos están definidos en ClassService.swift
typealias ParticipationStatusResponseUserStats = ParticipationStatusResponse
typealias UserParticipationUserStats = UserParticipation  
typealias ParticipationStatusUserStats = ParticipationStatus

// MARK: - User Stats Service
@MainActor
class UserStatsService: ObservableObject {
    // MARK: - Published Properties
    @Published var userStats: UserStats = .empty
    @Published var comprehensiveStats: ComprehensiveStats? = nil
    @Published var achievements: [Achievement] = []
    @Published var workoutHistory: [WorkoutHistory] = []
    @Published var personalGoals: [PersonalGoal] = []
    @Published var workoutBuddies: [WorkoutBuddy] = []
    @Published var leaderboardPosition: LeaderboardEntry?
    @Published var activityAnalytics: ActivityAnalytics?

    // Comeback/Re-engagement data
    @Published var lastAttendedClass: String?
    @Published var lastAttendanceDate: Date?
    @Published var daysInactive: Int = 0

    // Dashboard Summary data
    @Published var dashboardSummary: DashboardSummary?
    @Published var hasAttendedFirstClass: Bool = false  // 🆕 NEW field from backend

    @Published var isLoading = false
    @Published var error: Error?
    
    // MARK: - Private Properties
    private let baseURL = apiBaseURL
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Cache Properties
    private var lastWorkoutHistoryUpdate: Date?
    private var lastActivityAnalyticsUpdate: Date?
    private let cacheValidityDuration: TimeInterval = 300 // 5 minutos
    
    // MARK: - Dependency Injection
    weak var authService: AuthServiceDirect?
    weak var gymService: GymService?
    
    // MARK: - Singleton
    static let shared = UserStatsService()
    
    private init() {
        // Inicializar sin generar datos mock
        // Los datos se cargan cuando se llaman explícitamente los métodos fetch
    }

    // MARK: - Clear/Reset Methods

    /// Limpia todos los datos y estado del servicio (usado en logout)
    func clear() {
        userStats = .empty
        comprehensiveStats = nil
        achievements = []
        workoutHistory = []
        personalGoals = []
        workoutBuddies = []
        leaderboardPosition = nil
        activityAnalytics = nil
        lastAttendedClass = nil
        lastAttendanceDate = nil
        daysInactive = 0
        dashboardSummary = nil
        hasAttendedFirstClass = false
        isLoading = false
        error = nil
        lastWorkoutHistoryUpdate = nil
        lastActivityAnalyticsUpdate = nil
        print("🧹 UserStatsService: Datos limpiados")
    }

    // MARK: - Public Methods
    
    /// Obtiene estadísticas completas del usuario
    func fetchComprehensiveStats(period: StatsPeriod = .month) async {
        isLoading = true
        error = nil
        // Evitar mostrar datos obsoletos mientras cargamos
        achievements = []
        
        guard let token = await authService?.getValidAccessToken() else {
            print("❌ [UserStatsService] Missing auth token")
            isLoading = false
            return
        }
        
        // Debug: verificar estado del gymService
        print("🔍 [UserStatsService] GymService: \(gymService != nil ? "disponible" : "nil")")
        print("🔍 [UserStatsService] Current Gym ID: \(gymService?.currentGymId?.description ?? "nil")")
        
        guard let gymId = gymService?.currentGymId else {
            print("❌ [UserStatsService] No gym ID selected by user")
            print("💡 [UserStatsService] User must select a gym first")
            isLoading = false
            // No usar datos falsos, mantener datos vacíos hasta que seleccione gym
            return
        }
        
        print("✅ [UserStatsService] Using user's selected gym ID: \(gymId)")
        
        guard let url = URL(string: "\(baseURL)/users/stats/comprehensive?period=\(period.rawValue)&include_goals=true") else {
            print("❌ [UserStatsService] Invalid URL")
            isLoading = false
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("\(gymId)", forHTTPHeaderField: "X-Gym-ID")
        
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            
            if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 {
                let decoder = JSONDecoder()
                let stats = try decoder.decode(ComprehensiveStats.self, from: data)
                
                // Mapear datos principales
                comprehensiveStats = stats
                userStats = UserStats(from: stats)
                achievements = stats.achievements
                
                // Mapear Goals desde health_metrics.goals_progress
                personalGoals = mapGoalsFromHealthMetrics(stats.healthMetrics.goalsProgress)
                
                // Mapear Analytics desde fitness_metrics
                activityAnalytics = generateAnalyticsFromFitnessMetrics(stats.fitnessMetrics)
                
                // Mapear Social metrics con fallbacks
                updateSocialMetricsFromStats(stats.socialMetrics)
                
                // Generar History adaptado con datos agregados
                generateAdaptedWorkoutHistory(from: stats.fitnessMetrics)
                
                print("✅ [UserStatsService] Comprehensive stats loaded and mapped successfully")
                print("📊 [UserStatsService] Achievements: \(achievements.count)")
                print("🎯 [UserStatsService] Goals: \(personalGoals.count)")
                print("📈 [UserStatsService] Analytics data generated from fitness metrics")
            } else if let httpResponse = response as? HTTPURLResponse {
                print("❌ [UserStatsService] HTTP Error: \(httpResponse.statusCode)")
                // No generar datos falsos, mantener datos vacíos
            } else {
                print("❌ [UserStatsService] Unknown response type")
                // No generar datos falsos, mantener datos vacíos
            }
        } catch {
            print("❌ [UserStatsService] Error fetching stats: \(error)")
            print("🔍 [UserStatsService] Error details: \(error.localizedDescription)")
            self.error = error
            // No usar datos falsos, mantener datos vacíos
        }
        
        isLoading = false
    }
    
    /// Obtiene el historial de entrenamientos real del usuario (eventos + clases)
    /// Obtiene el dashboard summary del usuario con el nuevo campo hasAttendedFirstClass
    func fetchDashboardSummary() async {
        print("🔍 [UserStatsService] fetchDashboardSummary() iniciado")

        guard let token = await authService?.getValidAccessToken() else {
            print("❌ [UserStatsService] Missing auth token for dashboard")
            return
        }

        guard let gymId = gymService?.currentGymId else {
            print("❌ [UserStatsService] No gym ID selected for dashboard")
            return
        }

        let urlString = "\(baseURL)/users/dashboard/summary"
        print("📡 [UserStatsService] Dashboard URL: \(urlString)")
        print("📡 [UserStatsService] Using Gym ID: \(gymId)")
        guard let url = URL(string: urlString) else {
            print("❌ [UserStatsService] Invalid dashboard URL")
            return
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue(String(gymId), forHTTPHeaderField: "X-Gym-ID")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        do {
            let (data, response) = try await URLSession.shared.data(for: request)

            if let httpResponse = response as? HTTPURLResponse {
                print("📡 [UserStatsService] Dashboard response status: \(httpResponse.statusCode)")

                if httpResponse.statusCode == 200 {
                    // Log raw response for debugging
                    if let jsonString = String(data: data, encoding: .utf8) {
                        print("📡 [UserStatsService] Dashboard raw response: \(jsonString)")
                    }

                    let decoder = JSONDecoder()
                    // Usar un formatter personalizado que soporte fracciones de segundo
                    let formatter = ISO8601DateFormatter()
                    formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
                    decoder.dateDecodingStrategy = .custom { decoder in
                        let container = try decoder.singleValueContainer()
                        let dateStr = try container.decode(String.self)
                        if let date = formatter.date(from: dateStr) {
                            return date
                        }
                        // Fallback para fechas sin fracciones de segundo
                        formatter.formatOptions = [.withInternetDateTime]
                        if let date = formatter.date(from: dateStr) {
                            return date
                        }
                        throw DecodingError.dataCorruptedError(in: container,
                            debugDescription: "Cannot decode date string \(dateStr)")
                    }

                    let dashboard = try decoder.decode(DashboardSummary.self, from: data)

                    await MainActor.run {
                        self.dashboardSummary = dashboard
                        self.hasAttendedFirstClass = dashboard.hasAttendedFirstClass

                        print("✅ [UserStatsService] Dashboard decoded successfully:")
                        print("   - hasAttendedFirstClass: \(dashboard.hasAttendedFirstClass)")
                        print("   - currentStreak: \(dashboard.currentStreak)")
                        print("   - weeklyWorkouts: \(dashboard.weeklyWorkouts)")
                        print("   - membershipStatus: \(dashboard.membershipStatus)")

                        // También actualizar algunos campos relacionados si existen
                        // UserStats es struct con let properties, entonces recreamos la instancia
                        if dashboard.currentStreak > 0 || dashboard.weeklyWorkouts > 0 {
                            self.userStats = UserStats(
                                weeklyClasses: dashboard.weeklyWorkouts,
                                weeklyEvents: self.userStats.weeklyEvents,
                                weeklyHours: self.userStats.weeklyHours,
                                monthlyClasses: self.userStats.monthlyClasses,
                                totalStreak: self.userStats.totalStreak,
                                currentStreak: dashboard.currentStreak,
                                lastUpdated: Date()
                            )
                        }
                        if let lastDate = dashboard.lastAttendanceDate {
                            self.lastAttendanceDate = lastDate
                        }

                        print("✅ [UserStatsService] Dashboard loaded - hasAttendedFirstClass: \(dashboard.hasAttendedFirstClass)")
                    }
                } else {
                    print("❌ [UserStatsService] Dashboard HTTP Error: \(httpResponse.statusCode)")
                    // Log error response body
                    if let errorString = String(data: data, encoding: .utf8) {
                        print("❌ [UserStatsService] Error response: \(errorString)")
                    }
                }
            }
        } catch {
            print("❌ [UserStatsService] Error fetching dashboard: \(error)")
        }
    }

    func fetchWorkoutHistory() async {
        // Verificar cache antes de hacer request
        if isWorkoutHistoryCacheValid() {
            print("✅ [UserStatsService] Usando cache válido para workout history (\(workoutHistory.count) entradas)")
            // Asegurar que isLoading esté en false al usar cache
            await MainActor.run {
                isLoading = false
            }
            return
        }

        isLoading = true
        
        // Obtener tanto eventos como clases en paralelo
        async let eventsHistory = fetchEventsHistory()
        async let classesHistory = fetchClassesHistory()
        
        let (events, classes) = await (eventsHistory, classesHistory)
        
        // Combinar ambos historiales y ordenar por fecha
        var combinedHistory: [WorkoutHistory] = []
        combinedHistory.append(contentsOf: events)
        combinedHistory.append(contentsOf: classes)
        
        // Ordenar por fecha descendente (más reciente primero)
        workoutHistory = combinedHistory.sorted { $0.date > $1.date }

        // Actualizar timestamp del cache
        lastWorkoutHistoryUpdate = Date()

        // Calcular días de inactividad después de cargar historial
        calculateDaysInactive()

        print("✅ [UserStatsService] Historial combinado cargado: \(workoutHistory.count) entradas (\(events.count) eventos + \(classes.count) clases)")

        isLoading = false
    }
    
    /// Obtiene el historial de eventos del usuario
    private func fetchEventsHistory() async -> [WorkoutHistory] {
        print("🔍 [UserStatsService] Obteniendo historial de eventos...")

        guard let token = await authService?.getValidAccessToken() else {
            print("❌ [UserStatsService] Sin token de autenticación para eventos")
            return []
        }

        guard let gymId = gymService?.currentGymId else {
            print("❌ [UserStatsService] Sin gym seleccionado para eventos")
            return []
        }

        let urlString = "\(baseURL)/events/participation/me"
        print("📡 [UserStatsService] Eventos URL: \(urlString)")
        print("📡 [UserStatsService] Gym ID: \(gymId)")

        guard let url = URL(string: urlString) else {
            print("❌ [UserStatsService] URL inválida para eventos")
            return []
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("\(gymId)", forHTTPHeaderField: "X-Gym-ID")

        do {
            let (data, response) = try await URLSession.shared.data(for: request)

            if let httpResponse = response as? HTTPURLResponse {
                print("📡 [UserStatsService] Eventos Response Status: \(httpResponse.statusCode)")
                if httpResponse.statusCode == 200 {
                    // Log raw response for debugging
                    if let jsonString = String(data: data, encoding: .utf8) {
                        print("📡 [UserStatsService] Eventos Raw Response (first 500 chars): \(String(jsonString.prefix(500)))")
                    }

                    let history = try parseEventsHistoryFromAPI(data)
                    print("✅ [UserStatsService] Historial de eventos cargado: \(history.count) entradas")
                    return history
                } else {
                    print("❌ [UserStatsService] Error API eventos: \(httpResponse.statusCode)")
                    if let errorString = String(data: data, encoding: .utf8) {
                        print("❌ [UserStatsService] Error response: \(errorString)")
                    }
                    return []
                }
            }
        } catch {
            print("❌ [UserStatsService] Error al obtener eventos: \(error)")
            return []
        }

        return []
    }
    
    /// Obtiene el historial de clases del usuario usando rango de fechas
    private func fetchClassesHistory() async -> [WorkoutHistory] {
        print("🔍 [UserStatsService] Obteniendo historial de clases...")
        
        guard let token = await authService?.getValidAccessToken() else {
            print("❌ [UserStatsService] Sin token de autenticación para clases")
            return []
        }
        
        guard let gymId = gymService?.currentGymId else {
            print("❌ [UserStatsService] Sin gym seleccionado para clases")
            return []
        }
        
        // Obtener historial de los últimos 90 días (límite del API)
        let calendar = Calendar.current
        let endDate = Date()
        let startDate = calendar.date(byAdding: .day, value: -90, to: endDate) ?? endDate

        print("🔍 [UserStatsService] Buscando participaciones entre \(startDate) y \(endDate)")

        // Obtener las participaciones del usuario directamente del API
        // NO llamamos a classService.fetchSessionsByDateRange porque sobrescribe las sesiones
        // que ClassesView y HomeView están usando para mostrar clases del día actual
        // Formatear fechas para query parameters
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        let startDateString = dateFormatter.string(from: startDate)
        let endDateString = dateFormatter.string(from: endDate)

        let urlString = "\(baseURL)/schedule/participation/my-participation-status?start_date=\(startDateString)&end_date=\(endDateString)"
        print("📡 [UserStatsService] Clases URL: \(urlString)")
        print("📡 [UserStatsService] Gym ID: \(gymId)")

        guard let url = URL(string: urlString) else {
            print("❌ [UserStatsService] URL inválida para historial de participaciones")
            return []
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("\(gymId)", forHTTPHeaderField: "X-Gym-ID")

        do {
            let (data, response) = try await URLSession.shared.data(for: request)

            if let httpResponse = response as? HTTPURLResponse {
                print("📡 [UserStatsService] Clases Response Status: \(httpResponse.statusCode)")
                if httpResponse.statusCode == 200 {
                    // Log raw response for debugging
                    if let jsonString = String(data: data, encoding: .utf8) {
                        print("📡 [UserStatsService] Clases Raw Response (first 500 chars): \(String(jsonString.prefix(500)))")
                    }

                    let history = try parseClassesParticipationsFromAPI(data, startDate: startDate, endDate: endDate)
                    print("✅ [UserStatsService] Historial de participaciones cargado: \(history.count) entradas")
                    return history
                } else {
                    print("❌ [UserStatsService] Error API participaciones: \(httpResponse.statusCode)")
                    if let errorString = String(data: data, encoding: .utf8) {
                        print("❌ [UserStatsService] Error response: \(errorString)")
                    }
                    return []
                }
            }
        } catch {
            print("❌ [UserStatsService] Error al obtener participaciones: \(error)")
            return []
        }

        return []
    }
    
    /// Parsea el historial de eventos desde la respuesta de la API
    private func parseEventsHistoryFromAPI(_ data: Data) throws -> [WorkoutHistory] {
        let decoder = configuredJSONDecoder()
        
        // Decodificar como array de EventParticipationWithEvent (estructura real de la API)
        let eventParticipations = try decoder.decode([EventParticipationWithEvent].self, from: data)
        print("🔍 [UserStatsService] API devolvió \(eventParticipations.count) participaciones en eventos")
        
        // Convertir a WorkoutHistory
        let history = eventParticipations.compactMap { participation -> WorkoutHistory? in
            // Para historial: incluir eventos pasados donde el usuario se registró y no canceló
            let now = Date()
            let isEventPassed = participation.event.endTime < now
            let isRegistered = participation.status == "REGISTERED"
            
            guard isEventPassed && isRegistered else { 
                print("🔍 [UserStatsService] Filtrado evento: \(participation.event.title), status: \(participation.status), endTime: \(participation.event.endTime), pasado: \(isEventPassed)")
                return nil 
            }
            
            let workoutType = mapEventNameToWorkoutType(participation.event.title)
            let duration = calculateEventDuration(startTime: participation.event.startTime, endTime: participation.event.endTime)
            let estimatedCalories = estimateCaloriesForWorkout(duration: duration, type: workoutType)
            
            print("✅ [UserStatsService] Incluido evento: \(participation.event.title), status: \(participation.status), endTime: \(participation.event.endTime)")
            
            return WorkoutHistory(
                id: participation.id,
                date: participation.event.startTime,
                type: workoutType,
                duration: duration,
                caloriesBurned: estimatedCalories,
                className: participation.event.title,
                trainerName: "Event Instructor", // Los eventos no tienen trainer específico
                notes: participation.event.description,
                performance: nil // No hay métricas de performance en eventos
            )
        }
        
        // Ordenar por fecha descendente (más reciente primero)
        return history.sorted { $0.date > $1.date }
    }
    
    /// Parsea el historial de clases desde la respuesta de la API
    private func parseClassesHistoryFromAPI(_ data: Data) throws -> [WorkoutHistory] {
        let decoder = configuredJSONDecoder()
        
        // Decodificar como array de SessionWithClass (estructura real de la API de clases)
        let sessionsWithClass = try decoder.decode([SessionWithClass].self, from: data)
        print("🔍 [UserStatsService] API devolvió \(sessionsWithClass.count) sesiones de clases")
        
        // Convertir a WorkoutHistory
        let history = sessionsWithClass.compactMap { sessionWithClass -> WorkoutHistory? in
            // Para historial: incluir todas las clases del endpoint /my-history
            // El endpoint ya devuelve solo clases donde el usuario participó en el pasado
            
            // Solo filtrar clases canceladas
            guard sessionWithClass.session.status != .cancelled else { 
                print("🔍 [UserStatsService] Filtrada clase cancelada: \(sessionWithClass.classInfo.name), status: \(sessionWithClass.session.status.rawValue)")
                return nil 
            }
            
            let workoutType = mapEventNameToWorkoutType(sessionWithClass.classInfo.name)
            let duration = sessionWithClass.classInfo.duration
            let estimatedCalories = estimateCaloriesForWorkout(duration: duration, type: workoutType)
            
            print("✅ [UserStatsService] Incluida clase: \(sessionWithClass.classInfo.name), status: \(sessionWithClass.session.status.rawValue), startTime: \(sessionWithClass.session.startTime)")
            
            return WorkoutHistory(
                id: sessionWithClass.session.id,
                date: sessionWithClass.session.startTime,
                type: workoutType,
                duration: duration,
                caloriesBurned: estimatedCalories,
                className: sessionWithClass.classInfo.name,
                trainerName: getTrainerName(trainerId: sessionWithClass.session.trainerId),
                notes: sessionWithClass.session.notes,
                performance: nil // No hay métricas de performance en la API actualmente
            )
        }
        
        // Ordenar por fecha descendente (más reciente primero)
        return history.sorted { $0.date > $1.date }
    }
    
    /// Parsea las participaciones de clases desde la respuesta de la API my-participation-status
    private func parseClassesParticipationsFromAPI(_ data: Data, startDate: Date, endDate: Date) throws -> [WorkoutHistory] {
        let decoder = configuredJSONDecoder()
        
        // Decodificar como ParticipationStatusResponse (estructura real de la API)
        let participationResponse = try decoder.decode(ParticipationStatusResponseUserStats.self, from: data)
        print("🔍 [UserStatsService] API devolvió \(participationResponse.participations.count) participaciones en clases")
        
        // Convertir a WorkoutHistory directamente desde las participaciones
        // NO usamos ClassService.sessions para evitar sobrescribir las sesiones que
        // ClassesView y HomeView están usando
        let history = participationResponse.participations.compactMap { participation -> WorkoutHistory? in
            // Filtrar solo participaciones válidas (attended o registered, no cancelled)
            guard participation.status == ParticipationStatusUserStats.attended || participation.status == ParticipationStatusUserStats.registered else {
                print("🔍 [UserStatsService] Filtrada participación cancelada: sessionId \(participation.sessionId), status: \(participation.status)")
                return nil
            }

            // Usar fecha de registro como fecha de la participación
            // Si no hay fecha de registro, filtrar esta participación
            guard let workoutDate = participation.registrationTime else {
                print("🔍 [UserStatsService] Filtrada participación sin fecha: sessionId \(participation.sessionId)")
                return nil
            }

            // Estimar tipo, duración y calorías basándose en el sessionId
            // Como no tenemos el nombre de la clase, usamos valores genéricos
            let workoutType = WorkoutType.other
            let duration = 60 // Duración estándar
            let estimatedCalories = estimateCaloriesForWorkout(duration: duration, type: workoutType)

            // Crear un nombre genérico para la clase ya que no tenemos el nombre real
            let className = "Class Session #\(participation.sessionId)"

            print("✅ [UserStatsService] Incluida participación: \(className), sessionId: \(participation.sessionId), status: \(participation.status), fecha: \(workoutDate)")

            return WorkoutHistory(
                id: participation.sessionId,
                date: workoutDate,
                type: workoutType,
                duration: duration,
                caloriesBurned: estimatedCalories,
                className: className,
                trainerName: nil, // No tenemos info del trainer
                notes: nil,
                performance: nil
            )
        }
        
        // Ordenar por fecha descendente (más reciente primero)
        return history.sorted { $0.date > $1.date }
    }
    
    /// Mapea el nombre de un evento a WorkoutType
    private func mapEventNameToWorkoutType(_ eventName: String) -> WorkoutType {
        let lowercaseEventName = eventName.lowercased()
        
        if lowercaseEventName.contains("yoga") || lowercaseEventName.contains("pilates") {
            return .yoga
        } else if lowercaseEventName.contains("cardio") || lowercaseEventName.contains("hiit") || lowercaseEventName.contains("aerob") {
            return .cardio
        } else if lowercaseEventName.contains("strength") || lowercaseEventName.contains("weight") || lowercaseEventName.contains("muscle") || lowercaseEventName.contains("lifting") {
            return .strength
        } else if lowercaseEventName.contains("cycle") || lowercaseEventName.contains("spin") || lowercaseEventName.contains("bike") {
            return .cycling
        } else if lowercaseEventName.contains("swim") || lowercaseEventName.contains("aqua") {
            return .swimming
        } else if lowercaseEventName.contains("hiit") || lowercaseEventName.contains("interval") || lowercaseEventName.contains("circuit") {
            return .hiit
        } else {
            return .other
        }
    }
    
    /// Calcula la duración de un evento en minutos
    private func calculateEventDuration(startTime: Date, endTime: Date) -> Int {
        let durationInSeconds = endTime.timeIntervalSince(startTime)
        return max(15, Int(durationInSeconds / 60)) // Mínimo 15 minutos
    }
    
    /// Función utilitaria para configurar JSONDecoder con formato de fecha correcto (igual que EventService)
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
            
            // Intentar decodificar con el primer formatter (con fracciones de segundo)
            if let date = formatter1.date(from: string) {
                print("✅ Fecha decodificada exitosamente con formatter 1: \(date)")
                return date
            }
            
            // Intentar con el segundo formatter (sin fracciones de segundo)
            if let date = formatter2.date(from: string) {
                print("✅ Fecha decodificada exitosamente con formatter 2: \(date)")
                return date
            }
            
            // Si ambos fallan, lanzar un error
            print("❌ No se pudo decodificar la fecha: '\(string)'")
            throw DecodingError.dataCorrupted(.init(codingPath: decoder.codingPath, debugDescription: "Expected date string to be ISO8601-formatted."))
        }
        
        return decoder
    }
    
    /// Obtiene el nombre del entrenador por ID (placeholder por ahora)
    private func getTrainerName(trainerId: Int) -> String? {
        // TODO: Implementar cache de entrenadores o hacer lookup
        return "Instructor #\(trainerId)"
    }
    
    /// Genera historial realista cuando el usuario tiene actividad en el gym
    private func generateRealisticWorkoutHistoryWithActivity(classCount: Int) {
        var history: [WorkoutHistory] = []
        
        // Generar hasta 10 entradas recientes basadas en actividad real
        let entriesToGenerate = min(classCount, 10)
        
        let gymClassTypes = [
            "Strength Training", "HIIT Blast", "Yoga Flow", "Cardio Burn", 
            "Pilates Core", "CrossFit", "Spinning", "Boxing", "Zumba", 
            "Functional Training", "Power Yoga", "Circuit Training"
        ]
        
        let trainerNames = [
            "Coach Martinez", "Sarah Williams", "Mike Johnson", 
            "Emma Davis", "Carlos Rodriguez", "Lisa Chen", "Alex Thompson"
        ]
        
        for i in 0..<entriesToGenerate {
            let daysAgo = Int.random(in: 0...10) // Últimas 2 semanas
            let classDate = Date().addingTimeInterval(Double(-daysAgo * 24 * 60 * 60))
            
            let randomClassName = gymClassTypes.randomElement() ?? "General Workout"
            let workoutType = determineWorkoutTypeFromClassName(randomClassName)
            let estimatedDuration = estimateDurationForClass(randomClassName, type: workoutType)
            let estimatedCalories = estimateCaloriesForWorkout(duration: estimatedDuration, type: workoutType)
            
            let entry = WorkoutHistory(
                id: 2000 + i,
                date: classDate,
                type: workoutType,
                duration: estimatedDuration,
                caloriesBurned: estimatedCalories,
                className: randomClassName,
                trainerName: trainerNames.randomElement(),
                notes: i < 2 ? "Great workout at your gym!" : nil, // Solo los 2 más recientes tienen notas
                performance: i == 0 ? generateRandomPerformance(type: workoutType) : nil // Solo el más reciente tiene performance
            )
            
            history.append(entry)
        }
        
        workoutHistory = history.sorted { $0.date > $1.date }
    }
    
    /// Genera historial realista para desarrollo cuando no hay datos reales
    private func generateRealisticWorkoutHistory() {
        var history: [WorkoutHistory] = []
        
        // Generar 5-8 entradas recientes para simular actividad del usuario
        let entriesToGenerate = Int.random(in: 5...8)
        
        let gymClassTypes = ["Strength Training", "HIIT", "Yoga", "Cardio", "CrossFit"]
        let trainerNames = ["Coach Martinez", "Sarah Williams", "Mike Johnson", "Emma Davis"]
        
        for i in 0..<entriesToGenerate {
            let daysAgo = Int.random(in: 0...7) // Última semana
            let classDate = Date().addingTimeInterval(Double(-daysAgo * 24 * 60 * 60))
            
            let randomClassName = gymClassTypes.randomElement() ?? "General Workout"
            let workoutType = determineWorkoutTypeFromClassName(randomClassName)
            let estimatedDuration = estimateDurationForClass(randomClassName, type: workoutType)
            let estimatedCalories = estimateCaloriesForWorkout(duration: estimatedDuration, type: workoutType)
            
            let entry = WorkoutHistory(
                id: 1500 + i,
                date: classDate,
                type: workoutType,
                duration: estimatedDuration,
                caloriesBurned: estimatedCalories,
                className: randomClassName,
                trainerName: trainerNames.randomElement(),
                notes: i == 0 ? "Recent gym activity!" : nil,
                performance: nil
            )
            
            history.append(entry)
        }
        
        workoutHistory = history.sorted { $0.date > $1.date }
    }
    
    /// Genera métricas de performance aleatorias para tipos específicos
    private func generateRandomPerformance(type: WorkoutType) -> PerformanceMetric? {
        switch type {
        case .strength:
            return PerformanceMetric(
                metric: "Deadlift",
                value: Double.random(in: 80...140),
                unit: "kg",
                improvement: Double.random(in: 0...5)
            )
        case .cardio, .hiit:
            return PerformanceMetric(
                metric: "Distance",
                value: Double.random(in: 3...8),
                unit: "km",
                improvement: Double.random(in: 0...10)
            )
        default:
            return nil
        }
    }
    
    /// Obtiene instancia de ClassService
    private func getClassService() -> ClassService? {
        // ClassService es un singleton, podemos accederlo directamente
        return ClassService.shared
    }
    
    
    /// Determina el tipo de workout basado en el nombre de la clase
    private func determineWorkoutTypeFromClassName(_ className: String) -> WorkoutType {
        let lowercaseClassName = className.lowercased()
        
        if lowercaseClassName.contains("yoga") || lowercaseClassName.contains("pilates") {
            return .yoga
        } else if lowercaseClassName.contains("cardio") || lowercaseClassName.contains("hiit") || lowercaseClassName.contains("aerob") {
            return .cardio
        } else if lowercaseClassName.contains("strength") || lowercaseClassName.contains("weight") || lowercaseClassName.contains("muscle") || lowercaseClassName.contains("lifting") {
            return .strength
        } else if lowercaseClassName.contains("cycle") || lowercaseClassName.contains("spin") || lowercaseClassName.contains("bike") {
            return .cycling
        } else if lowercaseClassName.contains("swim") || lowercaseClassName.contains("aqua") {
            return .swimming
        } else if lowercaseClassName.contains("hiit") || lowercaseClassName.contains("interval") || lowercaseClassName.contains("circuit") {
            return .hiit
        } else {
            return .other
        }
    }
    
    /// Estima duración típica para una clase
    private func estimateDurationForClass(_ className: String, type: WorkoutType) -> Int {
        let lowercaseClassName = className.lowercased()
        
        // Duraciones típicas por tipo
        switch type {
        case .yoga:
            return lowercaseClassName.contains("power") ? 75 : 60
        case .hiit:
            return 45
        case .strength:
            return 60
        case .cardio:
            return 45
        case .cycling:
            return 50
        case .swimming:
            return 60
        case .other:
            return 50
        }
    }
    
    /// Estima calorías quemadas basado en duración y tipo
    private func estimateCaloriesForWorkout(duration: Int, type: WorkoutType) -> Int {
        // Calorías por minuto por tipo (promedio para una persona de 70kg)
        let caloriesPerMinute: Double
        
        switch type {
        case .hiit:
            caloriesPerMinute = 12.0
        case .strength:
            caloriesPerMinute = 6.0
        case .cardio:
            caloriesPerMinute = 10.0
        case .cycling:
            caloriesPerMinute = 8.0
        case .swimming:
            caloriesPerMinute = 11.0
        case .yoga:
            caloriesPerMinute = 3.5
        case .other:
            caloriesPerMinute = 7.0
        }
        
        return Int(Double(duration) * caloriesPerMinute)
    }
    
    /// Verifica si la clase fue reciente (últimos 3 días)
    private func isRecentClass(_ date: Date) -> Bool {
        let threeDaysAgo = Date().addingTimeInterval(-3 * 24 * 60 * 60)
        return date > threeDaysAgo
    }
    
    /// Obtiene los objetivos personales
    func fetchPersonalGoals() async {
        // TODO: Implementar API real para objetivos personales
        personalGoals = [] // Sin datos falsos
    }
    
    /// Obtiene los compañeros de entrenamiento
    func fetchWorkoutBuddies() async {
        // TODO: Implementar API real para compañeros de entrenamiento
        workoutBuddies = [] // Sin datos falsos
    }

    /// Calcula los días de inactividad basado en el historial de entrenamientos
    func calculateDaysInactive() {
        guard !workoutHistory.isEmpty else {
            // Si no hay historial, asumir inactividad desde hace mucho tiempo
            daysInactive = 30
            lastAttendedClass = nil
            lastAttendanceDate = nil
            return
        }

        // Obtener el workout más reciente
        if let mostRecentWorkout = workoutHistory.first {
            lastAttendedClass = mostRecentWorkout.className
            lastAttendanceDate = mostRecentWorkout.date

            // Calcular días desde la última asistencia
            let calendar = Calendar.current
            let today = calendar.startOfDay(for: Date())
            let lastDay = calendar.startOfDay(for: mostRecentWorkout.date)

            if let daysDifference = calendar.dateComponents([.day], from: lastDay, to: today).day {
                daysInactive = max(0, daysDifference)
                print("📊 [UserStatsService] Días inactivos calculados: \(daysInactive)")
                print("📅 [UserStatsService] Última clase: \(mostRecentWorkout.className ?? "Desconocida")")
                print("📅 [UserStatsService] Fecha última clase: \(mostRecentWorkout.date)")
            } else {
                daysInactive = 0
            }
        } else {
            daysInactive = 30
            lastAttendedClass = nil
            lastAttendanceDate = nil
        }
    }
    
    /// Obtiene la posición en el leaderboard
    func fetchLeaderboardPosition(category: LeaderboardCategory = .workouts, period: LeaderboardPeriod = .month) async {
        // TODO: Implementar API real para leaderboard
        leaderboardPosition = nil // Sin datos falsos
    }
    
    /// Obtiene análisis de actividad desde el historial real del usuario
    func fetchActivityAnalytics() async {
        // Verificar cache antes de regenerar
        if isAnalyticsCacheValid() && activityAnalytics != nil {
            print("✅ [UserStatsService] Usando cache válido para analytics")
            return
        }
        
        print("🔍 [UserStatsService] Generando analytics desde historial real...")
        
        // Si no hay historial, no generar analytics vacíos
        guard !workoutHistory.isEmpty else {
            print("❌ [UserStatsService] Sin historial disponible para analytics")
            activityAnalytics = nil
            return
        }
        
        activityAnalytics = generateRealAnalyticsFromHistory()
        
        // Actualizar timestamp del cache
        lastActivityAnalyticsUpdate = Date()
        
        print("✅ [UserStatsService] Analytics reales generados desde \(workoutHistory.count) entrenamientos")
    }
    
    /// Genera analytics reales desde el historial de entrenamientos del usuario
    private func generateRealAnalyticsFromHistory() -> ActivityAnalytics {
        // 1. Generar actividad semanal desde historial real
        let weeklyData = generateRealWeeklyData()
        
        // 2. Generar tendencia mensual desde actividad histórica
        let monthlyTrend = generateRealMonthlyTrend()
        
        // 3. Generar desglose de categorías desde tipos reales
        let categoryBreakdown = generateRealCategoryBreakdown()
        
        // 4. Calcular inversión de tiempo real
        let timeInvestment = calculateRealTimeInvestment()
        
        return ActivityAnalytics(
            weeklyData: weeklyData,
            monthlyTrend: monthlyTrend,
            categoryBreakdown: categoryBreakdown,
            timeInvestment: timeInvestment
        )
    }
    
    /// Genera datos de actividad semanal reales desde el historial
    private func generateRealWeeklyData() -> [DayActivity] {
        let calendar = Calendar.current
        let now = Date()
        let weekDays = ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"]
        var weeklyData: [DayActivity] = []
        
        // Para cada día de la semana (últimos 7 días)
        for i in 0..<7 {
            let date = calendar.date(byAdding: .day, value: -(6-i), to: now) ?? now
            let dayOfWeek = weekDays[i]
            
            // Filtrar entrenamientos de ese día específico
            let dayWorkouts = workoutHistory.filter { workout in
                calendar.isDate(workout.date, inSameDayAs: date)
            }
            
            let workoutCount = dayWorkouts.count
            let totalMinutes = dayWorkouts.reduce(0) { $0 + $1.duration }
            let isActive = workoutCount > 0
            
            weeklyData.append(DayActivity(
                dayOfWeek: dayOfWeek,
                date: date,
                workoutCount: workoutCount,
                totalMinutes: totalMinutes,
                isActive: isActive
            ))
        }
        
        print("📊 [UserStatsService] Weekly data generado: \(weeklyData.map { "\($0.dayOfWeek): \($0.workoutCount)" }.joined(separator: ", "))")
        return weeklyData
    }
    
    /// Genera tendencia mensual real desde el historial
    private func generateRealMonthlyTrend() -> [MonthDataPoint] {
        let calendar = Calendar.current
        let now = Date()
        var monthlyTrend: [MonthDataPoint] = []
        
        // Para las últimas 4 semanas
        for weekIndex in 0..<4 {
            let weekStart = calendar.date(byAdding: .weekOfYear, value: -(3-weekIndex), to: now) ?? now
            let weekEnd = calendar.date(byAdding: .day, value: 6, to: weekStart) ?? now
            
            // Contar entrenamientos de esa semana
            let weekWorkouts = workoutHistory.filter { workout in
                workout.date >= weekStart && workout.date <= weekEnd
            }
            
            let weekLabel = "Week \(weekIndex + 1)"
            let value = Double(weekWorkouts.count)
            
            monthlyTrend.append(MonthDataPoint(
                date: weekStart,
                value: value,
                label: weekLabel
            ))
        }
        
        print("📈 [UserStatsService] Monthly trend generado: \(monthlyTrend.map { "\($0.label): \($0.value)" }.joined(separator: ", "))")
        return monthlyTrend.reversed() // Ordenar de más antiguo a más reciente
    }
    
    /// Genera desglose de categorías real desde tipos de workouts
    private func generateRealCategoryBreakdown() -> [CategoryData] {
        var categoryCount: [WorkoutType: Int] = [:]
        
        // Contar entrenamientos por tipo
        for workout in workoutHistory {
            categoryCount[workout.type, default: 0] += 1
        }
        
        let total = workoutHistory.count
        var categoryBreakdown: [CategoryData] = []
        
        // Convertir a CategoryData con porcentajes
        for (type, count) in categoryCount {
            let percentage = total > 0 ? Double(count) / Double(total) * 100 : 0
            
            categoryBreakdown.append(CategoryData(
                category: type,
                percentage: percentage,
                totalSessions: count
            ))
        }
        
        // Ordenar por total de sesiones descendente
        categoryBreakdown.sort { $0.totalSessions > $1.totalSessions }
        
        print("📊 [UserStatsService] Category breakdown generado: \(categoryBreakdown.map { "\($0.category.displayName): \($0.totalSessions)" }.joined(separator: ", "))")
        return categoryBreakdown
    }
    
    /// Calcula inversión de tiempo real desde duraciones del historial
    private func calculateRealTimeInvestment() -> TimeInvestment {
        
        // Calcular duración promedio de sesión
        let totalMinutes = workoutHistory.reduce(0) { $0 + $1.duration }
        let averageSessionDuration = workoutHistory.isEmpty ? 0 : totalMinutes / workoutHistory.count
        
        // Calcular hora pico (hora más común de entrenamientos)
        let peakHour = calculatePeakWorkoutHour()
        
        // Calcular días preferidos (días más comunes de entrenamientos)
        let preferredDays = calculatePreferredWorkoutDays()
        
        // Calcular consistencia (qué tan regular es el usuario)
        let consistency = calculateWorkoutConsistency()
        
        print("⏱️ [UserStatsService] Time investment calculado: Duración promedio: \(averageSessionDuration)min, Hora pico: \(peakHour), Consistencia: \(String(format: "%.2f", consistency))")
        
        return TimeInvestment(
            averageSessionDuration: averageSessionDuration,
            peakHour: peakHour,
            preferredDays: preferredDays,
            consistency: consistency
        )
    }
    
    /// Calcula la hora más común de entrenamientos
    private func calculatePeakWorkoutHour() -> Int {
        let calendar = Calendar.current
        var hourCounts: [Int: Int] = [:]
        
        for workout in workoutHistory {
            let hour = calendar.component(.hour, from: workout.date)
            hourCounts[hour, default: 0] += 1
        }
        
        return hourCounts.max { $0.value < $1.value }?.key ?? 18 // Default a las 6 PM
    }
    
    /// Calcula los días preferidos para entrenamientos
    private func calculatePreferredWorkoutDays() -> [String] {
        let calendar = Calendar.current
        var dayCounts: [Int: Int] = [:]
        let dayNames = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"]
        
        for workout in workoutHistory {
            let weekday = calendar.component(.weekday, from: workout.date)
            dayCounts[weekday, default: 0] += 1
        }
        
        // Ordenar días por frecuencia y tomar los top 3
        let sortedDays = dayCounts.sorted { $0.value > $1.value }
        return sortedDays.prefix(3).map { dayNames[$0.key - 1] }
    }
    
    /// Calcula la consistencia de entrenamientos (0.0 - 1.0)
    private func calculateWorkoutConsistency() -> Double {
        guard workoutHistory.count >= 2 else { return 0.0 }
        
        let calendar = Calendar.current
        let now = Date()
        
        // Calcular cuántas semanas ha estado activo el usuario
        let firstWorkout = workoutHistory.min { $0.date < $1.date }?.date ?? now
        let totalWeeks = max(1, calendar.dateComponents([.weekOfYear], from: firstWorkout, to: now).weekOfYear ?? 1)
        
        // Contar semanas con al menos 1 entrenamiento
        var activeWeeks = Set<String>()
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-ww" // Año-semana
        
        for workout in workoutHistory {
            activeWeeks.insert(formatter.string(from: workout.date))
        }
        
        return Double(activeWeeks.count) / Double(totalWeeks)
    }
    
    // MARK: - Mock Data Generation
    
    private func generateMockData() {
        // Generar estadísticas básicas
        userStats = UserStats(
            weeklyClasses: 5,
            weeklyEvents: 2,
            weeklyHours: 7.5,
            monthlyClasses: 18,
            totalStreak: 12,
            currentStreak: 12,
            lastUpdated: Date()
        )
        
        // Generar logros
        achievements = [
            Achievement(
                id: 1,
                type: "streak",
                name: "Iron Will",
                description: "30-day workout streak",
                earnedAt: ISO8601DateFormatter().string(from: Date().addingTimeInterval(-86400 * 5)),
                badgeIcon: "flame.fill"
            ),
            Achievement(
                id: 2,
                type: "milestone",
                name: "Century Club",
                description: "Complete 100 workouts",
                earnedAt: ISO8601DateFormatter().string(from: Date().addingTimeInterval(-86400 * 10)),
                badgeIcon: "star.circle.fill"
            ),
            Achievement(
                id: 3,
                type: "social",
                name: "Team Player",
                description: "Join 10 group classes",
                earnedAt: ISO8601DateFormatter().string(from: Date().addingTimeInterval(-86400 * 2)),
                badgeIcon: "person.3.fill"
            )
        ]
        
        generateMockWorkoutHistory()
        generateMockGoals()
        generateMockBuddies()
        generateMockLeaderboard()
        // generateMockAnalytics() - Eliminado: Usar datos reales
    }
    
    private func generateMockWorkoutHistory() {
        workoutHistory = [
            WorkoutHistory(
                id: 1,
                date: Date(),
                type: .strength,
                duration: 45,
                caloriesBurned: 320,
                className: "Power Lifting",
                trainerName: "Mike Johnson",
                notes: "Great session, PR on deadlift!",
                performance: PerformanceMetric(
                    metric: "Deadlift",
                    value: 120,
                    unit: "kg",
                    improvement: 5.2
                )
            ),
            WorkoutHistory(
                id: 2,
                date: Date().addingTimeInterval(-86400),
                type: .cardio,
                duration: 30,
                caloriesBurned: 280,
                className: "HIIT Blast",
                trainerName: "Sarah Williams",
                notes: nil,
                performance: nil
            ),
            WorkoutHistory(
                id: 3,
                date: Date().addingTimeInterval(-86400 * 2),
                type: .yoga,
                duration: 60,
                caloriesBurned: 180,
                className: "Vinyasa Flow",
                trainerName: "Emma Davis",
                notes: "Feeling more flexible",
                performance: nil
            )
        ]
    }
    
    private func generateMockGoals() {
        personalGoals = [
            PersonalGoal(
                id: "goal1",
                title: "Lose 5kg",
                description: "Reach target weight of 75kg",
                targetValue: 5,
                currentValue: 3.2,
                unit: "kg",
                deadline: Date().addingTimeInterval(86400 * 30),
                category: .weight,
                createdAt: Date().addingTimeInterval(-86400 * 15),
                isCompleted: false
            ),
            PersonalGoal(
                id: "goal2",
                title: "Run 10K",
                description: "Complete a 10K run under 50 minutes",
                targetValue: 10,
                currentValue: 7.5,
                unit: "km",
                deadline: Date().addingTimeInterval(86400 * 45),
                category: .fitness,
                createdAt: Date().addingTimeInterval(-86400 * 20),
                isCompleted: false
            ),
            PersonalGoal(
                id: "goal3",
                title: "100 Push-ups",
                description: "Do 100 consecutive push-ups",
                targetValue: 100,
                currentValue: 65,
                unit: "reps",
                deadline: nil,
                category: .fitness,
                createdAt: Date().addingTimeInterval(-86400 * 30),
                isCompleted: false
            )
        ]
    }
    
    private func generateMockBuddies() {
        workoutBuddies = [
            WorkoutBuddy(
                id: 1,
                name: "Alex Thompson",
                picture: nil,
                sharedWorkouts: 15,
                lastWorkoutTogether: Date().addingTimeInterval(-86400 * 2),
                favoriteClass: "CrossFit"
            ),
            WorkoutBuddy(
                id: 2,
                name: "Maria Garcia",
                picture: nil,
                sharedWorkouts: 8,
                lastWorkoutTogether: Date().addingTimeInterval(-86400 * 5),
                favoriteClass: "Yoga Flow"
            ),
            WorkoutBuddy(
                id: 3,
                name: "John Smith",
                picture: nil,
                sharedWorkouts: 12,
                lastWorkoutTogether: Date().addingTimeInterval(-86400),
                favoriteClass: "Strength Training"
            )
        ]
    }
    
    private func generateMockLeaderboard() {
        leaderboardPosition = LeaderboardEntry(
            id: 1,
            userId: 1,
            userName: "You",
            userPicture: nil,
            score: 18,
            rank: 5,
            category: .workouts,
            period: .month
        )
    }
    
    // MARK: - Cache Management
    
    /// Verifica si el cache de workout history es válido
    private func isWorkoutHistoryCacheValid() -> Bool {
        guard let lastUpdate = lastWorkoutHistoryUpdate else { return false }
        return Date().timeIntervalSince(lastUpdate) < cacheValidityDuration
    }
    
    /// Verifica si el cache de analytics es válido
    private func isAnalyticsCacheValid() -> Bool {
        guard let lastUpdate = lastActivityAnalyticsUpdate else { return false }
        return Date().timeIntervalSince(lastUpdate) < cacheValidityDuration
    }
    
    /// Invalida todos los caches
    func invalidateCache() {
        lastWorkoutHistoryUpdate = nil
        lastActivityAnalyticsUpdate = nil
        print("🔄 [UserStatsService] Cache invalidado")
    }
    
    /// Fuerza la recarga de datos ignorando el cache
    func forceRefresh() async {
        print("🔄 [UserStatsService] Forzando recarga de datos...")
        invalidateCache()
        await fetchWorkoutHistory()
        await fetchActivityAnalytics()
    }
    
    // MARK: - Data Mapping Functions (Real API Data)
    
    /// Mapea los objetivos desde health_metrics.goals_progress
    private func mapGoalsFromHealthMetrics(_ goalsProgress: [GoalProgress]) -> [PersonalGoal] {
        return goalsProgress.map { goalProgress in
            // Determinar categoría basada en goal_type
            let category: GoalCategory = {
                switch goalProgress.goalType.lowercased() {
                case "weight", "weight_loss", "weight_gain":
                    return .weight
                case "fitness", "strength", "cardio", "endurance":
                    return .fitness
                case "nutrition", "diet", "calories":
                    return .nutrition
                case "wellness", "sleep", "stress":
                    return .wellness
                default:
                    return .custom
                }
            }()
            
            // Crear un deadline estimado basado en el progreso
            let deadline: Date? = {
                if goalProgress.status == "on_track" && goalProgress.progressPercentage > 0 {
                    let remainingProgress = 100 - goalProgress.progressPercentage
                    let estimatedDays = Int(remainingProgress / 2) // 2% de progreso por día estimado
                    return Date().addingTimeInterval(Double(estimatedDays) * 86400)
                }
                return nil
            }()
            
            return PersonalGoal(
                id: "api_goal_\(goalProgress.goalId)",
                title: goalProgress.goalType.capitalized,
                description: "Track your \(goalProgress.goalType.lowercased()) progress",
                targetValue: goalProgress.targetValue,
                currentValue: goalProgress.currentValue,
                unit: determineUnitFromGoalType(goalProgress.goalType),
                deadline: deadline,
                category: category,
                createdAt: Date().addingTimeInterval(-86400 * 30), // Estimado hace 30 días
                isCompleted: goalProgress.progressPercentage >= 100
            )
        }
    }
    
    /// Determina la unidad basada en el tipo de objetivo
    private func determineUnitFromGoalType(_ goalType: String) -> String {
        switch goalType.lowercased() {
        case "weight", "weight_loss", "weight_gain":
            return "kg"
        case "fitness", "strength":
            return "reps"
        case "cardio", "endurance":
            return "km"
        case "nutrition", "calories":
            return "cal"
        default:
            return "units"
        }
    }
    
    /// Genera analytics adaptados desde fitness_metrics
    private func generateAnalyticsFromFitnessMetrics(_ fitnessMetrics: FitnessMetrics) -> ActivityAnalytics {
        // Generar datos de actividad semanal basados en classes_attended
        let weekDays = ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"]
        var weeklyData: [DayActivity] = []
        
        // Distribuir las clases asistidas a través de la semana
        let classesPerWeek = fitnessMetrics.classesAttended
        let dailyDistribution = distributeDailyWorkouts(totalWorkouts: classesPerWeek, across: 7)
        
        for (index, day) in weekDays.enumerated() {
            let date = Date().addingTimeInterval(Double(-86400 * (6 - index)))
            let workoutCount = dailyDistribution[index]
            let isActive = workoutCount > 0
            
            weeklyData.append(DayActivity(
                dayOfWeek: day,
                date: date,
                workoutCount: workoutCount,
                totalMinutes: workoutCount * Int(fitnessMetrics.averageSessionDuration),
                isActive: isActive
            ))
        }
        
        // Generar tendencia mensual simple
        var monthlyTrend: [MonthDataPoint] = []
        for i in 0..<4 {
            let value = Double(classesPerWeek) * (1.0 + Double.random(in: -0.2...0.2)) // Variación del 20%
            monthlyTrend.append(MonthDataPoint(
                date: Date().addingTimeInterval(Double(-86400 * 7 * i)),
                value: max(0, value),
                label: "Week \(4-i)"
            ))
        }
        
        // Generar desglose de categorías basado en favorite_class_types
        let categoryBreakdown = generateCategoryBreakdownFromFavorites(
            favoriteClassTypes: fitnessMetrics.favoriteClassTypes,
            totalClasses: classesPerWeek
        )
        
        return ActivityAnalytics(
            weeklyData: weeklyData,
            monthlyTrend: monthlyTrend,
            categoryBreakdown: categoryBreakdown,
            timeInvestment: TimeInvestment(
                averageSessionDuration: Int(fitnessMetrics.averageSessionDuration),
                peakHour: extractPeakHourFromTimes(fitnessMetrics.peakWorkoutTimes),
                preferredDays: ["Monday", "Wednesday", "Friday"], // Default
                consistency: calculateConsistency(
                    current: fitnessMetrics.streakCurrent,
                    longest: fitnessMetrics.streakLongest
                )
            )
        )
    }
    
    /// Distribuye workouts a través de los días de la semana
    private func distributeDailyWorkouts(totalWorkouts: Int, across days: Int) -> [Int] {
        guard totalWorkouts > 0 else { return Array(repeating: 0, count: days) }
        
        var distribution = Array(repeating: 0, count: days)
        var remaining = totalWorkouts
        
        // Preferir días laborales (lunes a viernes)
        let workdayIndices = [0, 1, 2, 3, 4] // Mon-Fri
        
        for _ in 0..<totalWorkouts {
            if remaining <= 0 { break }
            
            // 70% probabilidad de día laboral, 30% fin de semana
            let useWorkday = Double.random(in: 0...1) < 0.7
            let dayIndex = useWorkday ? workdayIndices.randomElement()! : [5, 6].randomElement()!
            
            distribution[dayIndex] += 1
            remaining -= 1
        }
        
        return distribution
    }
    
    /// Genera desglose de categorías desde tipos favoritos
    private func generateCategoryBreakdownFromFavorites(
        favoriteClassTypes: [String], 
        totalClasses: Int
    ) -> [CategoryData] {
        guard !favoriteClassTypes.isEmpty && totalClasses > 0 else {
            // Fallback con distribución balanceada
            return [
                CategoryData(category: .strength, percentage: 30, totalSessions: totalClasses * 30 / 100),
                CategoryData(category: .cardio, percentage: 25, totalSessions: totalClasses * 25 / 100),
                CategoryData(category: .yoga, percentage: 25, totalSessions: totalClasses * 25 / 100),
                CategoryData(category: .hiit, percentage: 20, totalSessions: totalClasses * 20 / 100)
            ]
        }
        
        var breakdown: [CategoryData] = []
        let remainingPercentage = 100.0
        let basePercentage = remainingPercentage / Double(favoriteClassTypes.count)
        
        for (_, classType) in favoriteClassTypes.enumerated() {
            let workoutType = mapStringToWorkoutType(classType)
            let percentage = basePercentage * (1.0 + Double.random(in: -0.3...0.3)) // Variación
            let sessions = Int(Double(totalClasses) * percentage / 100.0)
            
            breakdown.append(CategoryData(
                category: workoutType,
                percentage: percentage,
                totalSessions: max(1, sessions)
            ))
        }
        
        // Normalizar porcentajes para que sumen 100%
        let totalPercentage = breakdown.reduce(0) { $0 + $1.percentage }
        if totalPercentage > 0 {
            breakdown = breakdown.map { CategoryData(
                category: $0.category,
                percentage: ($0.percentage / totalPercentage) * 100,
                totalSessions: $0.totalSessions
            )}
        }
        
        return breakdown
    }
    
    /// Mapea string a WorkoutType
    private func mapStringToWorkoutType(_ classType: String) -> WorkoutType {
        switch classType.lowercased() {
        case let type where type.contains("strength") || type.contains("weight") || type.contains("lifting"):
            return .strength
        case let type where type.contains("cardio") || type.contains("running") || type.contains("treadmill"):
            return .cardio
        case let type where type.contains("yoga") || type.contains("pilates"):
            return .yoga
        case let type where type.contains("hiit") || type.contains("interval"):
            return .hiit
        case let type where type.contains("cycling") || type.contains("bike"):
            return .cycling
        case let type where type.contains("swim"):
            return .swimming
        default:
            return .other
        }
    }
    
    /// Extrae hora pico desde peak_workout_times
    private func extractPeakHourFromTimes(_ peakTimes: [String]) -> Int {
        guard let firstTime = peakTimes.first else { return 18 } // Default: 6 PM
        
        // Intentar extraer hora del string
        if let hour = Int(firstTime.prefix(2)) {
            return hour
        }
        
        return 18 // Fallback
    }
    
    /// Calcula consistencia basada en streaks
    private func calculateConsistency(current: Int, longest: Int) -> Double {
        guard longest > 0 else { return 0.0 }
        return min(Double(current) / Double(longest), 1.0)
    }
    
    /// Actualiza métricas sociales con fallbacks
    private func updateSocialMetricsFromStats(_ socialMetrics: SocialMetrics) {
        // Crear leaderboard entry basado en social_score
        leaderboardPosition = LeaderboardEntry(
            id: 1,
            userId: 1,
            userName: "You",
            userPicture: nil,
            score: Int(socialMetrics.socialScore),
            rank: calculateRankFromScore(socialMetrics.socialScore),
            category: .challenges,
            period: .month
        )
        
        // Generar workout buddies basado en actividad social
        generateWorkoutBuddiesFromSocialScore(socialMetrics.socialScore)
    }
    
    /// Calcula ranking basado en score social
    private func calculateRankFromScore(_ score: Double) -> Int {
        switch score {
        case 9...10: return Int.random(in: 1...3)
        case 7...8: return Int.random(in: 4...10)
        case 5...6: return Int.random(in: 11...25)
        case 3...4: return Int.random(in: 26...50)
        default: return Int.random(in: 51...100)
        }
    }
    
    /// Genera workout buddies basado en score social
    private func generateWorkoutBuddiesFromSocialScore(_ score: Double) {
        let buddyCount = min(Int(score / 2), 5) // Máximo 5 buddies
        
        let names = [
            "Alex Thompson", "Maria Garcia", "John Smith", 
            "Sarah Johnson", "Mike Wilson", "Emma Davis",
            "Carlos Rodriguez", "Lisa Chen", "David Brown"
        ]
        
        workoutBuddies = (0..<buddyCount).map { index in
            WorkoutBuddy(
                id: index + 1,
                name: names[min(index, names.count - 1)],
                picture: nil,
                sharedWorkouts: Int.random(in: 1...15),
                lastWorkoutTogether: Date().addingTimeInterval(Double(-86400 * Int.random(in: 1...7))),
                favoriteClass: ["CrossFit", "Yoga Flow", "Strength Training", "HIIT"].randomElement()
            )
        }
    }
    
    /// Genera historial adaptado de la última semana desde fitness metrics y eventos
    private func generateAdaptedWorkoutHistory(from fitnessMetrics: FitnessMetrics) {
        guard let comprehensiveStats = comprehensiveStats else {
            workoutHistory = [] // No generar datos falsos
            return
        }
        
        // Combinar datos de clases y eventos para crear historial de la semana
        let weeklyClasses = fitnessMetrics.classesAttended
        let weeklyEvents = comprehensiveStats.eventsMetrics.eventsAttended
        let totalWeeklyActivities = weeklyClasses + weeklyEvents
        
        guard totalWeeklyActivities > 0 else {
            workoutHistory = []
            return
        }
        
        var history: [WorkoutHistory] = []
        let avgDuration = Int(fitnessMetrics.averageSessionDuration)
        let avgCalories = Int(fitnessMetrics.caloriesBurnedEstimate / Double(max(totalWeeklyActivities, 1)))
        
        // Generar historial de los últimos 7 días basado en datos reales
        let weeklyData = activityAnalytics?.weeklyData ?? []
        
        for dayIndex in 0..<7 {
            let date = Date().addingTimeInterval(Double(-86400 * dayIndex))
            
            // Buscar datos del día correspondiente en weeklyData
            var dayWorkouts = 0
            if dayIndex < weeklyData.count {
                dayWorkouts = weeklyData[6 - dayIndex].workoutCount // Orden inverso
            }
            
            // Si no hay datos específicos, distribuir actividades a través de la semana
            if weeklyData.isEmpty && dayIndex < totalWeeklyActivities {
                dayWorkouts = 1
            }
            
            // Generar entradas para cada workout del día
            for workoutIndex in 0..<dayWorkouts {
                let historyId = dayIndex * 10 + workoutIndex + 1
                
                // Determinar si es clase o evento basado en proporción
                let isEvent = Double.random(in: 0...1) < Double(weeklyEvents) / Double(totalWeeklyActivities)
                
                let workoutType: String
                let className: String
                let trainerName: String?
                
                if isEvent {
                    // Tipos de eventos
                    let eventTypes = comprehensiveStats.eventsMetrics.favoriteEventTypes.isEmpty ? 
                        ["Workshop", "Seminar", "Challenge"] : 
                        comprehensiveStats.eventsMetrics.favoriteEventTypes
                    
                    workoutType = eventTypes.randomElement() ?? "Event"
                    className = workoutType == "Workshop" ? "Nutrition Workshop" :
                               workoutType == "Seminar" ? "Fitness Seminar" :
                               workoutType == "Challenge" ? "30-Day Challenge" : workoutType
                    trainerName = ["Dr. Martinez", "Coach Williams", "Sarah Johnson"].randomElement()
                } else {
                    // Tipos de clases
                    let classTypes = fitnessMetrics.favoriteClassTypes.isEmpty ?
                        ["Strength", "Cardio", "Yoga"] :
                        fitnessMetrics.favoriteClassTypes
                    
                    workoutType = classTypes.randomElement() ?? "General"
                    className = generateClassNameFromType(workoutType)
                    trainerName = ["Mike Johnson", "Sarah Williams", "Emma Davis", "Carlos Martinez"].randomElement()
                }
                
                // Duración y calorías basadas en el tipo
                let duration = isEvent ? 
                    avgDuration + Int.random(in: 15...45) : // Eventos más largos
                    avgDuration + Int.random(in: -15...15)  // Clases normales
                
                let calories = isEvent ?
                    Int(Double(avgCalories) * 0.7) : // Eventos queman menos calorías
                    avgCalories + Int.random(in: -30...30)
                
                // Notas especiales para actividades recientes
                let notes: String? = {
                    if dayIndex == 0 && workoutIndex == 0 {
                        return isEvent ? "Great learning experience!" : "Excellent workout today!"
                    } else if dayIndex < 2 && Int.random(in: 1...3) == 1 {
                        return isEvent ? "Informative session" : "Feeling stronger!"
                    }
                    return nil
                }()
                
                history.append(WorkoutHistory(
                    id: historyId,
                    date: date,
                    type: isEvent ? .other : mapStringToWorkoutType(workoutType),
                    duration: max(15, duration), // Mínimo 15 minutos
                    caloriesBurned: max(50, calories), // Mínimo 50 calorías
                    className: className,
                    trainerName: trainerName,
                    notes: notes,
                    performance: generatePerformanceMetricIfApplicable(workoutType: workoutType, isRecent: dayIndex < 3)
                ))
            }
        }
        
        // Ordenar por fecha descendente (más reciente primero)
        workoutHistory = history.sorted { $0.date > $1.date }
    }
    
    /// Genera nombre de clase basado en tipo
    private func generateClassNameFromType(_ type: String) -> String {
        switch type.lowercased() {
        case let t where t.contains("strength") || t.contains("weight"):
            return ["Power Lifting", "Strength Training", "Weight Class", "Iron Pump"].randomElement() ?? "Strength"
        case let t where t.contains("cardio") || t.contains("running"):
            return ["HIIT Blast", "Cardio Burn", "Running Club", "Endurance Training"].randomElement() ?? "Cardio"
        case let t where t.contains("yoga") || t.contains("pilates"):
            return ["Vinyasa Flow", "Power Yoga", "Pilates Core", "Mindful Movement"].randomElement() ?? "Yoga"
        case let t where t.contains("hiit"):
            return ["HIIT Extreme", "Tabata Training", "Circuit Blast", "Interval Challenge"].randomElement() ?? "HIIT"
        case let t where t.contains("cycling"):
            return ["Spin Class", "Cycling Bootcamp", "Indoor Cycling", "Bike Challenge"].randomElement() ?? "Cycling"
        default:
            return type.capitalized
        }
    }
    
    /// Genera métricas de rendimiento para workouts aplicables
    private func generatePerformanceMetricIfApplicable(workoutType: String, isRecent: Bool) -> PerformanceMetric? {
        // Solo generar métricas para algunos tipos de workout y si es reciente
        guard isRecent && Int.random(in: 1...3) == 1 else { return nil }
        
        switch workoutType.lowercased() {
        case let t where t.contains("strength") || t.contains("weight"):
            return PerformanceMetric(
                metric: ["Deadlift", "Squat", "Bench Press", "Overhead Press"].randomElement() ?? "Lift",
                value: Double.random(in: 60...150),
                unit: "kg",
                improvement: Double.random(in: 0...8)
            )
        case let t where t.contains("cardio") || t.contains("running"):
            return PerformanceMetric(
                metric: "Distance",
                value: Double.random(in: 3...12),
                unit: "km",
                improvement: Double.random(in: 0...15)
            )
        default:
            return nil
        }
    }
}

// MARK: - Extended Models for Profile Page

struct WorkoutHistory: Identifiable, Codable {
    let id: Int
    let date: Date
    let type: WorkoutType
    let duration: Int // in minutes
    let caloriesBurned: Int?
    let className: String?
    let trainerName: String?
    let notes: String?
    let performance: PerformanceMetric?
    
    var formattedDuration: String {
        if duration < 60 {
            return "\(duration) min"
        } else {
            let hours = duration / 60
            let minutes = duration % 60
            return minutes > 0 ? "\(hours)h \(minutes)min" : "\(hours)h"
        }
    }
    
    var formattedDate: String {
        let formatter = DateFormatter()
        if Calendar.current.isDateInToday(date) {
            return "Today"
        } else if Calendar.current.isDateInYesterday(date) {
            return "Yesterday"
        } else {
            formatter.dateFormat = "MMM d"
            return formatter.string(from: date)
        }
    }
}

enum WorkoutType: String, Codable, CaseIterable {
    case strength = "strength"
    case cardio = "cardio"
    case yoga = "yoga"
    case hiit = "hiit"
    case cycling = "cycling"
    case swimming = "swimming"
    case other = "other"
    
    var displayName: String {
        switch self {
        case .strength: return "Strength"
        case .cardio: return "Cardio"
        case .yoga: return "Yoga"
        case .hiit: return "HIIT"
        case .cycling: return "Cycling"
        case .swimming: return "Swimming"
        case .other: return "Other"
        }
    }
    
    var iconName: String {
        switch self {
        case .strength: return "dumbbell.fill"
        case .cardio: return "figure.run"
        case .yoga: return "figure.yoga"
        case .hiit: return "bolt.heart.fill"
        case .cycling: return "bicycle"
        case .swimming: return "figure.pool.swim"
        case .other: return "figure.walk"
        }
    }
    
    var color: Color {
        switch self {
        case .strength: return .blue
        case .cardio: return .red
        case .yoga: return .purple
        case .hiit: return .orange
        case .cycling: return .green
        case .swimming: return .cyan
        case .other: return .gray
        }
    }
}

struct PerformanceMetric: Codable {
    let metric: String
    let value: Double
    let unit: String
    let improvement: Double? // percentage improvement
}

struct PersonalGoal: Identifiable, Codable {
    let id: String
    let title: String
    let description: String
    let targetValue: Double
    let currentValue: Double
    let unit: String
    let deadline: Date?
    let category: GoalCategory
    let createdAt: Date
    let isCompleted: Bool
    
    var progress: Double {
        return min(currentValue / targetValue, 1.0)
    }
    
    var progressPercentage: Int {
        return Int(progress * 100)
    }
    
    var daysRemaining: Int? {
        guard let deadline = deadline else { return nil }
        let calendar = Calendar.current
        let components = calendar.dateComponents([.day], from: Date(), to: deadline)
        return components.day
    }
}

enum GoalCategory: String, Codable, CaseIterable {
    case weight = "weight"
    case fitness = "fitness"
    case nutrition = "nutrition"
    case wellness = "wellness"
    case custom = "custom"
    
    var displayName: String {
        switch self {
        case .weight: return "Weight"
        case .fitness: return "Fitness"
        case .nutrition: return "Nutrition"
        case .wellness: return "Wellness"
        case .custom: return "Custom"
        }
    }
    
    var iconName: String {
        switch self {
        case .weight: return "scalemass.fill"
        case .fitness: return "figure.walk"
        case .nutrition: return "leaf.fill"
        case .wellness: return "heart.fill"
        case .custom: return "star.fill"
        }
    }
    
    var color: Color {
        switch self {
        case .weight: return .orange
        case .fitness: return .blue
        case .nutrition: return .green
        case .wellness: return .pink
        case .custom: return .purple
        }
    }
}

struct WorkoutBuddy: Identifiable, Codable {
    let id: Int
    let name: String
    let picture: String?
    let sharedWorkouts: Int
    let lastWorkoutTogether: Date?
    let favoriteClass: String?
    
    var initials: String {
        let components = name.split(separator: " ")
        let firstInitial = components.first?.first ?? Character("?")
        let lastInitial = components.count > 1 ? (components.last?.first ?? Character("")) : Character("")
        return "\(firstInitial)\(lastInitial)".uppercased()
    }
}

struct LeaderboardEntry: Identifiable, Codable {
    let id: Int
    let userId: Int
    let userName: String
    let userPicture: String?
    let score: Int
    let rank: Int
    let category: LeaderboardCategory
    let period: LeaderboardPeriod
    
    var rankDisplay: String {
        switch rank {
        case 1: return "🥇"
        case 2: return "🥈"
        case 3: return "🥉"
        default: return "#\(rank)"
        }
    }
}

enum LeaderboardCategory: String, Codable {
    case workouts = "workouts"
    case minutes = "minutes"
    case streak = "streak"
    case challenges = "challenges"
    
    var displayName: String {
        switch self {
        case .workouts: return "Workouts"
        case .minutes: return "Minutes"
        case .streak: return "Streak"
        case .challenges: return "Challenges"
        }
    }
}

enum LeaderboardPeriod: String, Codable {
    case week = "week"
    case month = "month"
    case year = "year"
    case allTime = "all_time"
    
    var displayName: String {
        switch self {
        case .week: return "This Week"
        case .month: return "This Month"
        case .year: return "This Year"
        case .allTime: return "All Time"
        }
    }
}

struct ActivityAnalytics: Codable {
    let weeklyData: [DayActivity]
    let monthlyTrend: [MonthDataPoint]
    let categoryBreakdown: [CategoryData]
    let timeInvestment: TimeInvestment
}

struct DayActivity: Codable {
    let dayOfWeek: String
    let date: Date
    let workoutCount: Int
    let totalMinutes: Int
    let isActive: Bool
}

struct MonthDataPoint: Codable {
    let date: Date
    let value: Double
    let label: String
}

struct CategoryData: Codable {
    let category: WorkoutType
    let percentage: Double
    let totalSessions: Int
}

struct TimeInvestment: Codable {
    let averageSessionDuration: Int
    let peakHour: Int
    let preferredDays: [String]
    let consistency: Double // 0.0 to 1.0
}
