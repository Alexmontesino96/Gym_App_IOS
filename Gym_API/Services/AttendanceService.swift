//
//  AttendanceService.swift
//  Gym_API
//
//  Created by Claude Code on 12/1/25.
//

import Foundation
import Combine

/// Servicio para gestionar check-in de asistencia con código QR
@MainActor
class AttendanceService: ObservableObject {

    // MARK: - Published Properties

    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var lastCheckInResponse: AttendanceCheckInResponse?
    @Published var availableSessions: [SessionWithClass] = []
    @Published var isLoadingAvailableSessions = false
    @Published var memberProfile: UserPublicProfile?
    @Published var isLoadingProfile = false

    // MARK: - Private Properties

    private let baseURL = apiBaseURL
    weak var authService: AuthServiceDirect?
    private let classService: ClassService
    private let httpClient = HTTPClient.shared

    // MARK: - Initialization

    init(authService: AuthServiceDirect? = nil, classService: ClassService) {
        self.authService = authService
        self.classService = classService
        print("🏗️ AttendanceService initialized")
    }

    deinit {
        #if DEBUG
        print("🗑️ AttendanceService deinitialized")
        #endif
    }

    // MARK: - Check-in Methods

    /// Realiza check-in con código QR sin especificar sesión
    /// El backend decidirá automáticamente a qué clase hacer check-in
    /// - Parameter qrCode: Código QR escaneado del miembro
    /// - Returns: Respuesta del check-in
    /// - Throws: AttendanceCheckInError
    func checkIn(qrCode: String) async throws -> AttendanceCheckInResponse {
        return try await performCheckIn(qrCode: qrCode, sessionId: nil)
    }

    /// Realiza check-in con código QR y sesión específica
    /// Usado cuando hay múltiples clases activas y el usuario selecciona una
    /// - Parameters:
    ///   - qrCode: Código QR escaneado del miembro
    ///   - sessionId: ID de la sesión seleccionada
    /// - Returns: Respuesta del check-in
    /// - Throws: AttendanceCheckInError
    func checkIn(qrCode: String, sessionId: Int) async throws -> AttendanceCheckInResponse {
        return try await performCheckIn(qrCode: qrCode, sessionId: sessionId)
    }

    // MARK: - Available Sessions

    /// Obtiene las sesiones disponibles para check-in en este momento
    /// Filtra sesiones dentro de la ventana de ±30 minutos
    func getAvailableSessionsForCheckIn() async {
        isLoadingAvailableSessions = true
        defer { isLoadingAvailableSessions = false }

        let now = Date()
        let sessions = classService.sessions

        // Filtrar sesiones dentro de la ventana de ±30 minutos
        availableSessions = sessions.filter { sessionWithClass in
            let startTime = sessionWithClass.session.startTime
            let timeDifference = abs(startTime.timeIntervalSince(now))
            let thirtyMinutes: TimeInterval = 30 * 60

            let isWithinWindow = timeDifference <= thirtyMinutes
            let isValidStatus = sessionWithClass.session.status == .scheduled ||
                                sessionWithClass.session.status == .active

            return isWithinWindow && isValidStatus
        }.sorted { session1, session2 in
            // Ordenar por proximidad a la hora actual
            let diff1 = abs(session1.session.startTime.timeIntervalSince(now))
            let diff2 = abs(session2.session.startTime.timeIntervalSince(now))
            return diff1 < diff2
        }

        Logger.shared.info("📋 Sesiones disponibles para check-in: \(availableSessions.count)", category: .network)
    }

    /// Filtra sesiones para check-in proactivo antes de escanear QR
    /// Configuración 2B: Incluye clases que empiezan en próximos 60 min + clases activas que empezaron hace <30 min
    /// - Parameter sessions: Lista de sesiones a filtrar
    /// - Returns: Sesiones filtradas y ordenadas por proximidad a la hora actual
    func filterSessionsForCheckIn(_ sessions: [SessionWithClass]) -> [SessionWithClass] {
        let now = Date()
        let oneHour: TimeInterval = 60 * 60
        let thirtyMinutes: TimeInterval = 30 * 60

        print("🔍 [AttendanceService] Filtrando sesiones para check-in:")
        print("   - Total sesiones recibidas: \(sessions.count)")
        print("   - Hora actual: \(now)")

        let filtered = sessions.filter { sessionWithClass in
            let startTime = sessionWithClass.session.startTime
            let timeDifference = startTime.timeIntervalSince(now)

            // Caso 1: Clases que empiezan en los próximos 60 minutos
            let isUpcoming = timeDifference >= 0 && timeDifference <= oneHour

            // Caso 2: Clases que empezaron hace menos de 30 min y están activas
            let isRecentlyStarted = timeDifference < 0 && abs(timeDifference) <= thirtyMinutes
            let isActive = sessionWithClass.session.status == .active

            // Validar status
            let isValidStatus = sessionWithClass.session.status == .scheduled || isActive

            let passes = (isUpcoming || (isRecentlyStarted && isActive)) && isValidStatus

            let minutesUntilStart = Int(timeDifference / 60)
            print("   📋 Clase '\(sessionWithClass.classInfo.name)':")
            print("      - Start: \(startTime)")
            print("      - Minutos hasta inicio: \(minutesUntilStart)")
            print("      - Status: \(sessionWithClass.session.status)")
            print("      - isUpcoming: \(isUpcoming)")
            print("      - isRecentlyStarted: \(isRecentlyStarted)")
            print("      - isActive: \(isActive)")
            print("      - ✅ Incluida: \(passes)")

            return passes
        }

        // Ordenar por proximidad a la hora actual
        let sorted = filtered.sorted { session1, session2 in
            let diff1 = abs(session1.session.startTime.timeIntervalSince(now))
            let diff2 = abs(session2.session.startTime.timeIntervalSince(now))
            return diff1 < diff2
        }

        print("✅ [AttendanceService] Filtrado completado:")
        print("   - Sesiones filtradas: \(sorted.count)")
        for (index, session) in sorted.enumerated() {
            let minutesUntil = Int(session.session.startTime.timeIntervalSince(now) / 60)
            print("   \(index + 1). \(session.classInfo.name) - \(minutesUntil) min")
        }

        return sorted
    }

    // MARK: - Private Methods

    private func performCheckIn(qrCode: String, sessionId: Int?) async throws -> AttendanceCheckInResponse {
        // Validar que hay token y gym
        guard await authService?.getValidAccessToken() != nil else {
            throw AttendanceCheckInError.networkError("No se pudo obtener token de autenticación")
        }

        guard GymService.shared.currentGymId != nil else {
            throw AttendanceCheckInError.networkError("No hay gimnasio seleccionado")
        }

        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        // Construir URL
        guard let url = URL(string: "\(baseURL)/attendance/check-in") else {
            throw AttendanceCheckInError.networkError("URL inválida")
        }

        // Crear request usando HTTPClient
        guard var request = await httpClient.makeRequest(url: url, method: "POST", includeGymHeader: true) else {
            throw AttendanceCheckInError.networkError("No se pudo crear el request")
        }

        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        // Crear request body
        let requestBody = AttendanceCheckInRequest(qrCode: qrCode, sessionId: sessionId)
        let encoder = JSONEncoder()
        encoder.keyEncodingStrategy = .convertToSnakeCase
        request.httpBody = try encoder.encode(requestBody)

        // Realizar request
        do {
            let (data, response) = try await URLSession.shared.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse else {
                throw AttendanceCheckInError.networkError("Respuesta inválida del servidor")
            }

            Logger.shared.info("Check-in response status: \(httpResponse.statusCode)", category: .network)

            if httpResponse.statusCode == 200 {
                let decoder = JSONDecoder()
                decoder.keyDecodingStrategy = .convertFromSnakeCase
                decoder.dateDecodingStrategy = .iso8601

                let checkInResponse = try decoder.decode(AttendanceCheckInResponse.self, from: data)
                lastCheckInResponse = checkInResponse

                Logger.shared.info("✅ Check-in exitoso para sesión \(checkInResponse.session?.id ?? 0)", category: .network)

                // Refrescar estado de participación después del check-in exitoso
                await refreshParticipationStatus()

                return checkInResponse

            } else if httpResponse.statusCode == 400 {
                // Error de validación del backend
                let errorResponse = try JSONDecoder().decode(AttendanceError.self, from: data)
                let error = parseError(from: errorResponse.detail)
                Logger.shared.warning("⚠️ Check-in error: \(errorResponse.detail)", category: .network)
                throw error

            } else if httpResponse.statusCode == 401 || httpResponse.statusCode == 403 {
                throw AttendanceCheckInError.unauthorized

            } else {
                throw AttendanceCheckInError.networkError("Error del servidor: \(httpResponse.statusCode)")
            }

        } catch let error as AttendanceCheckInError {
            errorMessage = error.errorDescription
            Logger.shared.error("Check-in error: \(error.errorDescription ?? "Unknown")", category: .network)
            throw error
        } catch {
            let networkError = AttendanceCheckInError.networkError(error.localizedDescription)
            errorMessage = networkError.errorDescription
            Logger.shared.error("Network error during check-in: \(error)", category: .network)
            throw networkError
        }
    }

    private func parseError(from detail: String) -> AttendanceCheckInError {
        let lowercased = detail.lowercased()

        if lowercased.contains("no hay clases disponibles") {
            return .noClassesAvailable
        } else if lowercased.contains("sesión no encontrada") || lowercased.contains("no pertenece") {
            return .sessionNotFound
        } else if lowercased.contains("fuera del horario") || lowercased.contains("±30") {
            return .outsideCheckInWindow
        } else if lowercased.contains("ya has hecho check-in") || lowercased.contains("already checked") {
            return .alreadyCheckedIn
        } else if lowercased.contains("qr") && lowercased.contains("inválido") {
            return .invalidQRCode
        } else {
            return .networkError(detail)
        }
    }

    private func refreshParticipationStatus() async {
        let now = Date()
        let calendar = Calendar.current
        let startDate = calendar.date(byAdding: .day, value: -1, to: now) ?? now
        let endDate = calendar.date(byAdding: .day, value: 1, to: now) ?? now

        await classService.forceRefreshParticipationStatus(startDate: startDate, endDate: endDate)
        Logger.shared.info("🔄 Participation status refreshed after check-in", category: .network)
    }

    // MARK: - Member Profile Methods (v2.0)

    /// Obtiene el perfil público de un miembro del gimnasio
    /// - Parameter userId: ID del usuario extraído del QR
    /// - Returns: Perfil público del miembro
    /// - Throws: AttendanceCheckInError
    func fetchMemberProfile(userId: Int) async throws -> UserPublicProfile {
        guard await authService?.getValidAccessToken() != nil else {
            throw AttendanceCheckInError.networkError("No se pudo obtener token de autenticación")
        }

        guard GymService.shared.currentGymId != nil else {
            throw AttendanceCheckInError.networkError("No hay gimnasio seleccionado")
        }

        isLoadingProfile = true
        defer { isLoadingProfile = false }

        // Construir URL
        guard let url = URL(string: "\(baseURL)/users/p/gym-participants/\(userId)") else {
            throw AttendanceCheckInError.networkError("URL inválida")
        }

        // Crear request usando HTTPClient
        guard let request = await httpClient.makeRequest(url: url, method: "GET", includeGymHeader: true) else {
            throw AttendanceCheckInError.networkError("No se pudo crear el request")
        }

        do {
            let (data, response) = try await URLSession.shared.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse else {
                throw AttendanceCheckInError.networkError("Respuesta inválida del servidor")
            }

            Logger.shared.info("Member profile response status: \(httpResponse.statusCode)", category: .network)

            if httpResponse.statusCode == 200 {
                let decoder = JSONDecoder()
                decoder.keyDecodingStrategy = .convertFromSnakeCase
                let profile = try decoder.decode(UserPublicProfile.self, from: data)
                self.memberProfile = profile
                Logger.shared.info("✅ Perfil obtenido: \(profile.fullName)", category: .network)
                return profile

            } else if httpResponse.statusCode == 404 {
                Logger.shared.warning("⚠️ Usuario no encontrado: \(userId)", category: .network)
                throw AttendanceCheckInError.invalidQRCode

            } else if httpResponse.statusCode == 401 || httpResponse.statusCode == 403 {
                throw AttendanceCheckInError.unauthorized

            } else {
                throw AttendanceCheckInError.networkError("Error del servidor: \(httpResponse.statusCode)")
            }

        } catch let error as AttendanceCheckInError {
            Logger.shared.error("Member profile error: \(error.errorDescription ?? "Unknown")", category: .network)
            throw error
        } catch {
            let networkError = AttendanceCheckInError.networkError(error.localizedDescription)
            Logger.shared.error("Network error fetching profile: \(error)", category: .network)
            throw networkError
        }
    }

    /// Extrae el user_id de un código QR con formato U{id}_{hash}
    /// - Parameter qrCode: Código QR escaneado
    /// - Returns: User ID si es válido, nil si el formato es inválido
    func extractUserId(from qrCode: String) -> Int? {
        // Formato esperado: "U123_a1b2c3d4"
        let components = qrCode.components(separatedBy: "_")
        guard components.count == 2,
              let userIdString = components.first?.dropFirst(), // Quita "U"
              let userId = Int(userIdString) else {
            Logger.shared.warning("⚠️ QR code format invalid: \(qrCode)", category: .network)
            return nil
        }
        Logger.shared.info("✅ User ID extraído: \(userId)", category: .network)
        return userId
    }

    /// Realiza check-in después de confirmar perfil del miembro
    /// - Parameters:
    ///   - userId: ID del usuario confirmado
    ///   - sessionId: ID de la sesión (opcional si hay solo 1 disponible)
    /// - Returns: Respuesta del check-in
    /// - Throws: AttendanceCheckInError
    func confirmCheckIn(userId: Int, sessionId: Int?) async throws -> AttendanceCheckInResponse {
        // Construir QR code desde userId
        // El backend solo necesita el user_id, el hash no es validado
        let qrCode = "U\(userId)_confirmed"
        Logger.shared.info("🎯 Confirmando check-in para usuario \(userId), sesión: \(sessionId?.description ?? "auto")", category: .network)
        return try await performCheckIn(qrCode: qrCode, sessionId: sessionId)
    }

    // MARK: - Validation

    /// Valida si el QR code tiene un formato válido
    /// - Parameter qrCode: Código QR a validar
    /// - Returns: true si el formato es válido
    func isValidQRCodeFormat(_ qrCode: String) -> Bool {
        // El formato esperado es: U{user_id}_{random_hash}
        // Ejemplo: U123_a1b2c3d4
        let pattern = "^U\\d+_[a-zA-Z0-9]+$"
        let regex = try? NSRegularExpression(pattern: pattern)
        let range = NSRange(location: 0, length: qrCode.utf16.count)
        return regex?.firstMatch(in: qrCode, range: range) != nil
    }

    // MARK: - Clear State

    /// Limpia el estado del servicio
    func clearState() {
        lastCheckInResponse = nil
        errorMessage = nil
        availableSessions = []
        memberProfile = nil
        Logger.shared.info("🧹 AttendanceService state cleared", category: .network)
    }

    // MARK: - Recent Attended Classes (para etiquetado de posts)

    /// Obtiene las clases a las que el usuario asistió en la última semana
    /// - Returns: Lista de clases asistidas en los últimos 7 días
    @MainActor
    func getRecentAttendedClasses() async throws -> [AttendedClass] {
        guard let token = await authService?.getValidAccessToken() else {
            throw AttendanceCheckInError.networkError("No se pudo obtener token de autenticación")
        }

        guard let gymId = GymService.shared.currentGymId else {
            throw AttendanceCheckInError.networkError("No hay gimnasio seleccionado")
        }

        // Fecha de hace 7 días
        let oneWeekAgo = Calendar.current.date(byAdding: .day, value: -7, to: Date()) ?? Date()

        // Formatear fechas en YYYY-MM-DD como espera el backend
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        dateFormatter.timeZone = TimeZone.current

        // Construir URL con parámetros - Usando el endpoint correcto según la documentación
        var components = URLComponents(string: "\(baseURL)/schedule/participation/my-history")
        components?.queryItems = [
            URLQueryItem(name: "start_date", value: dateFormatter.string(from: oneWeekAgo)),
            URLQueryItem(name: "end_date", value: dateFormatter.string(from: Date()))
        ]

        guard let url = components?.url else {
            throw AttendanceCheckInError.networkError("URL inválida")
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("\(gymId)", forHTTPHeaderField: "X-Gym-ID")

        do {
            let (data, response) = try await URLSession.shared.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse else {
                throw AttendanceCheckInError.networkError("Respuesta inválida del servidor")
            }

            if httpResponse.statusCode == 200 {
                // Log del JSON crudo para debugging
                if let jsonString = String(data: data, encoding: .utf8) {
                    Logger.shared.info("JSON Response: \(jsonString.prefix(1000))", category: .network)
                }

                let decoder = JSONDecoder()
                decoder.keyDecodingStrategy = .convertFromSnakeCase
                decoder.dateDecodingStrategy = .iso8601

                // Decodificar usando la estructura real del API (AttendanceHistoryItem)
                let attendanceHistory = try decoder.decode([AttendanceHistoryItem].self, from: data)

                Logger.shared.info("Obtenidos \(attendanceHistory.count) registros del historial", category: .network)

                // Convertir a AttendedClass
                let attendedClasses = attendanceHistory.compactMap { item in
                    item.toAttendedClass()
                }

                Logger.shared.info("Filtradas \(attendedClasses.count) clases asistidas", category: .network)

                // Filtrar solo las de la última semana y ordenar por más reciente
                return attendedClasses
                    .filter { $0.isWithinLastWeek }
                    .sorted { $0.checkinTime > $1.checkinTime }

            } else {
                Logger.shared.error("Error al obtener clases asistidas: \(httpResponse.statusCode)", category: .network)
                throw AttendanceCheckInError.networkError("Error al obtener historial de clases")
            }

        } catch {
            Logger.shared.error("Error fetching recent attended classes: \(error)", category: .network)
            throw error
        }
    }

    /// Obtiene la última clase a la que asistió el usuario (para sugerencias)
    /// - Returns: La clase más reciente si fue completada hace menos de 2 horas
    @MainActor
    func getLastAttendedClass() async -> AttendedClass? {
        do {
            let recentClasses = try await getRecentAttendedClasses()

            // Buscar la primera clase que fue completada recientemente
            return recentClasses.first { $0.isRecentlyCompleted }

        } catch {
            Logger.shared.error("Error getting last attended class: \(error)", category: .network)
            return nil
        }
    }
}
