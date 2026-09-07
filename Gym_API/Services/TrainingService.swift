//
//  TrainingService.swift
//  Gym_API
//
//  Cliente del módulo /api/v1/training del backend (plan §6.1).
//
//  Copia el patrón de `HealthService`: `LoadState` por sección para poder distinguir «todavía no
//  hay datos» de «no se pudieron cargar», errores de lectura y de escritura separados, descarte
//  de respuestas del gimnasio anterior y transporte en tres capas sobre `HTTPClient`.
//
//  Lo que este servicio NO hace:
//    - No decide marcas personales. Las calcula el servidor al sincronizar un registro cerrado
//      (plan §4.5); aquí solo se leen.
//    - No guarda el registro en curso. Eso es del outbox (`TrainingOutboxStore`) y del
//      coordinador (`TrainingSyncCoordinator`), que son los que hacen que la sesión sobreviva
//      a un sótano sin cobertura.
//

import Foundation
import Combine
import TrainingCore

@MainActor
final class TrainingService: ObservableObject {

    // MARK: - Singleton
    static let shared = TrainingService()
    private init() {}

    // MARK: - Published · datos

    /// `GET /me/program`: alimenta W4, W6, W8 y el acuse del coach de una sola llamada.
    @Published private(set) var myProgram: MyProgramResponse?
    /// `GET /me/week`: la semana que el cliente esté mirando, que no tiene por qué ser la actual.
    @Published private(set) var week: TrainingWeek?
    /// `GET /me/days/{id}`: el día abierto en S17 o precargado para S11.
    @Published private(set) var day: TrainingDay?
    /// `GET /me/today`: el día de hoy, o nulo si toca descanso o no hay programa.
    @Published private(set) var today: TrainingDay?
    @Published private(set) var logs: [TrainingWorkoutLogSummary] = []
    @Published private(set) var selectedLog: TrainingWorkoutLog?
    @Published private(set) var records: [TrainingPersonalRecord] = []
    @Published private(set) var strengthSummary: [StrengthSummaryItem] = []
    @Published private(set) var exerciseHistory: ExerciseHistory?
    @Published private(set) var groupToday: GroupToday?
    @Published private(set) var exercises: [ExerciseCatalogItem] = []

    // MARK: - Published · estado

    @Published private(set) var programState: LoadState = .idle
    @Published private(set) var weekState: LoadState = .idle
    @Published private(set) var dayState: LoadState = .idle
    @Published private(set) var logsState: LoadState = .idle
    @Published private(set) var recordsState: LoadState = .idle
    @Published private(set) var strengthState: LoadState = .idle
    @Published private(set) var exerciseHistoryState: LoadState = .idle
    @Published private(set) var groupState: LoadState = .idle
    @Published private(set) var exercisesState: LoadState = .idle

    @Published private(set) var isLoading = false
    @Published var isSaving = false
    /// Error de LECTURA. La escritura tiene el suyo para que un fallo al dar las gracias no
    /// pinte la pantalla entera como rota.
    @Published var errorMessage: String?
    @Published var saveErrorMessage: String?

    // MARK: - Dependencias
    weak var authService: AuthServiceDirect?
    weak var gymService: GymService?

    // MARK: - Privado

    private let session = URLSession.shared
    private lazy var decoder = BackendJSON.decoder()
    private lazy var encoder = BackendJSON.encoder()
    /// Evita que la respuesta de un gimnasio repueble el estado después de cambiar a otro.
    private var loadedForGymId: Int?
    private var isLoadingHome = false

    func configure(authService: AuthServiceDirect?, gymService: GymService?) {
        self.authService = authService
        self.gymService = gymService
    }

    // MARK: - Derivados para la interfaz

    var hasActiveProgram: Bool { myProgram?.hasActiveProgram == true }

    /// El programa activo enseña comunidad solo si es compartido y de grupo (plan §4.3).
    var showsGroupFeatures: Bool { myProgram?.program?.showsGroupFeatures == true }

    var coach: TrainingPerson? { myProgram?.coach }

    /// Acuse pendiente de responder: la tarjeta de la home solo aparece si hay algo que decir.
    var pendingCoachAcknowledgement: TrainingCoachActivity? {
        guard let activity = myProgram?.coachActivity, activity.reviewedAt != nil else { return nil }
        return activity
    }

    // MARK: - Lectura · home del cliente

    /// Carga en paralelo lo que necesita la home. Una sola entrada para `.task` y `.refreshable`.
    func loadHome() async {
        guard !isLoadingHome else { return }
        isLoadingHome = true
        isLoading = true
        errorMessage = nil
        defer {
            isLoadingHome = false
            isLoading = false
        }

        let gymId = GymService.shared.currentGymId
        loadedForGymId = gymId

        async let program: Void = fetchMyProgram(expecting: gymId)
        async let strength: Void = fetchStrengthSummary(expecting: gymId)
        async let recent: Void = fetchMyLogs(limit: 5, expecting: gymId)
        _ = await (program, strength, recent)
    }

    /// `GET /training/me/program`
    func fetchMyProgram(expecting gymId: Int? = nil) async {
        let expected = gymId ?? GymService.shared.currentGymId
        programState = .loading
        guard let data = await get("/training/me/program") else {
            if stillCurrent(expected) { programState = .failed }
            return
        }
        guard stillCurrent(expected) else { return }

        // El endpoint devuelve el literal `null` cuando el cliente no tiene programa, y eso no
        // es un error: es el hueco honesto de la home.
        if isNullBody(data) {
            myProgram = nil
            programState = .loaded
            return
        }
        do {
            myProgram = try decoder.decode(MyProgramResponse.self, from: data)
            programState = .loaded
        } catch {
            programState = .failed
            report(error, endpoint: "me/program")
        }
    }

    /// `GET /training/me/week?week_number=`
    func fetchWeek(_ weekNumber: Int, expecting gymId: Int? = nil) async {
        let expected = gymId ?? GymService.shared.currentGymId
        weekState = .loading
        guard let data = await get("/training/me/week?week_number=\(weekNumber)") else {
            if stillCurrent(expected) { weekState = .failed }
            return
        }
        guard stillCurrent(expected) else { return }
        do {
            week = try decoder.decode(TrainingWeek.self, from: data)
            weekState = .loaded
        } catch {
            weekState = .failed
            report(error, endpoint: "me/week")
        }
    }

    /// `GET /training/me/days/{day_id}`
    func fetchDay(_ dayId: Int, expecting gymId: Int? = nil) async {
        let expected = gymId ?? GymService.shared.currentGymId
        dayState = .loading
        guard let data = await get("/training/me/days/\(dayId)") else {
            if stillCurrent(expected) { dayState = .failed }
            return
        }
        guard stillCurrent(expected) else { return }
        do {
            day = try decoder.decode(TrainingDay.self, from: data)
            dayState = .loaded
        } catch {
            dayState = .failed
            report(error, endpoint: "me/days")
        }
    }

    /// `GET /training/me/today`. Devuelve el día para poder arrancar S11 sin esperar a la home.
    @discardableResult
    func fetchToday(expecting gymId: Int? = nil) async -> TrainingDay? {
        let expected = gymId ?? GymService.shared.currentGymId
        guard let data = await get("/training/me/today") else { return nil }
        guard stillCurrent(expected) else { return nil }

        if isNullBody(data) {
            today = nil
            return nil
        }
        do {
            let decoded = try decoder.decode(TrainingDay.self, from: data)
            today = decoded
            return decoded
        } catch {
            report(error, endpoint: "me/today")
            return nil
        }
    }

    /// `GET /training/me/logs?limit=&before=`. Sin `before` reemplaza la lista; con `before`
    /// añade la página siguiente, que es como pagina el contrato (cursor por id).
    func fetchMyLogs(limit: Int = 20, before: Int? = nil, expecting gymId: Int? = nil) async {
        let expected = gymId ?? GymService.shared.currentGymId
        logsState = .loading
        var path = "/training/me/logs?limit=\(limit)"
        if let before { path += "&before=\(before)" }

        guard let data = await get(path) else {
            if stillCurrent(expected) { logsState = .failed }
            return
        }
        guard stillCurrent(expected) else { return }
        do {
            let page = try decoder.decode([TrainingWorkoutLogSummary].self, from: data)
            if before == nil {
                logs = page
            } else {
                let known = Set(logs.map(\.id))
                logs.append(contentsOf: page.filter { !known.contains($0.id) })
            }
            logsState = .loaded
        } catch {
            logsState = .failed
            report(error, endpoint: "me/logs")
        }
    }

    /// `GET /training/logs/{id}`. Propietario o personal.
    @discardableResult
    func fetchLog(_ logId: Int, expecting gymId: Int? = nil) async -> TrainingWorkoutLog? {
        let expected = gymId ?? GymService.shared.currentGymId
        guard let data = await get("/training/logs/\(logId)") else { return nil }
        guard stillCurrent(expected) else { return nil }
        do {
            let log = try decoder.decode(TrainingWorkoutLog.self, from: data)
            selectedLog = log
            return log
        } catch {
            report(error, endpoint: "logs/\(logId)")
            return nil
        }
    }

    /// `GET /training/me/exercises/{key}/history?range=8w|6m|all`
    func fetchExerciseHistory(
        exerciseKey: String,
        range: String = "8w",
        expecting gymId: Int? = nil
    ) async {
        let expected = gymId ?? GymService.shared.currentGymId
        exerciseHistoryState = .loading
        let key = escape(exerciseKey)
        guard let data = await get("/training/me/exercises/\(key)/history?range=\(range)") else {
            if stillCurrent(expected) { exerciseHistoryState = .failed }
            return
        }
        guard stillCurrent(expected) else { return }
        do {
            exerciseHistory = try decoder.decode(ExerciseHistory.self, from: data)
            exerciseHistoryState = .loaded
        } catch {
            exerciseHistoryState = .failed
            report(error, endpoint: "me/exercises/history")
        }
    }

    /// `GET /training/me/records`
    func fetchRecords(expecting gymId: Int? = nil) async {
        let expected = gymId ?? GymService.shared.currentGymId
        recordsState = .loading
        guard let data = await get("/training/me/records") else {
            if stillCurrent(expected) { recordsState = .failed }
            return
        }
        guard stillCurrent(expected) else { return }
        do {
            records = try decoder.decode([TrainingPersonalRecord].self, from: data)
            recordsState = .loaded
        } catch {
            recordsState = .failed
            report(error, endpoint: "me/records")
        }
    }

    /// `GET /training/me/strength-summary`
    func fetchStrengthSummary(expecting gymId: Int? = nil) async {
        let expected = gymId ?? GymService.shared.currentGymId
        strengthState = .loading
        guard let data = await get("/training/me/strength-summary") else {
            if stillCurrent(expected) { strengthState = .failed }
            return
        }
        guard stillCurrent(expected) else { return }
        do {
            strengthSummary = try decoder.decode([StrengthSummaryItem].self, from: data)
            strengthState = .loaded
        } catch {
            strengthState = .failed
            report(error, endpoint: "me/strength-summary")
        }
    }

    /// `GET /training/exercises?q=&muscle=&limit=`. Catálogo global más los del espacio.
    func fetchExercises(
        query: String? = nil,
        muscle: String? = nil,
        limit: Int = 50,
        expecting gymId: Int? = nil
    ) async {
        let expected = gymId ?? GymService.shared.currentGymId
        exercisesState = .loading
        var path = "/training/exercises?limit=\(limit)"
        if let query, !query.isEmpty { path += "&q=\(escape(query))" }
        if let muscle, !muscle.isEmpty { path += "&muscle=\(escape(muscle))" }

        guard let data = await get(path) else {
            if stillCurrent(expected) { exercisesState = .failed }
            return
        }
        guard stillCurrent(expected) else { return }
        do {
            exercises = try decoder.decode([ExerciseCatalogItem].self, from: data)
            exercisesState = .loaded
        } catch {
            exercisesState = .failed
            report(error, endpoint: "exercises")
        }
    }

    /// `GET /training/programs/{id}/group/today`. Solo en programas de grupo.
    ///
    /// Este endpoint devuelve nombre, foto, si entrenó hoy y el nombre del día. Nunca series ni
    /// pesos de otro cliente (plan §4.8), y el modelo que lo decodifica tampoco tiene sitio
    /// para guardarlos.
    func fetchGroupToday(programId: Int, expecting gymId: Int? = nil) async {
        let expected = gymId ?? GymService.shared.currentGymId
        groupState = .loading
        guard let data = await get("/training/programs/\(programId)/group/today") else {
            if stillCurrent(expected) { groupState = .failed }
            return
        }
        guard stillCurrent(expected) else { return }
        do {
            groupToday = try decoder.decode(GroupToday.self, from: data)
            groupState = .loaded
        } catch {
            groupState = .failed
            report(error, endpoint: "group/today")
        }
    }

    // MARK: - Escritura

    /// `POST /training/logs/sync`. Upsert idempotente por `client_uuid` (plan §4.7).
    ///
    /// Lo llama el coordinador de sincronización, no las vistas: la pantalla de sesión escribe
    /// en el outbox y sigue funcionando sin red. `throws` a propósito, porque quien lo llama
    /// necesita distinguir «no hay red, reintenta» de «el servidor lo rechazó».
    func syncLog(_ request: WorkoutLogSyncRequest) async throws -> TrainingWorkoutLog {
        guard let url = URL(string: apiBaseURL + "/training/logs/sync"),
              var urlRequest = await HTTPClient.shared.makeRequest(url: url, method: "POST") else {
            throw TrainingServiceError.couldNotPrepareRequest
        }
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        urlRequest.httpBody = try encoder.encode(request)

        let (data, response) = try await session.data(for: urlRequest)
        guard let http = response as? HTTPURLResponse else {
            throw TrainingServiceError.invalidResponse
        }
        guard (200...299).contains(http.statusCode) else {
            throw TrainingServiceError.server(
                status: http.statusCode,
                message: detailMessage(from: data)
            )
        }
        return try decoder.decode(TrainingWorkoutLog.self, from: data)
    }

    /// `POST /training/logs/{id}/thank`. Solo el propietario y solo sobre una revisión existente.
    @discardableResult
    func thank(logId: Int) async -> Bool {
        guard !isSaving else { return false }
        // Antes de cualquier await: entre el toque y el primer suspend el botón seguiría
        // habilitado y un segundo toque mandaría dos gracias.
        isSaving = true
        saveErrorMessage = nil
        defer { isSaving = false }

        guard await post("/training/logs/\(logId)/thank") != nil else { return false }

        Analytics.track(Analytics.Event.clientThanks, [Analytics.Property.logId: logId])
        // El servidor ya lo tiene: se refleja en local sin esperar a recargar la home entera.
        markThanked(logId: logId)
        return true
    }

    /// `POST /training/logs/{id}/kudos`. Solo en programas de grupo, nunca sobre un registro
    /// propio, uno por día y usuario (409 si repite).
    @discardableResult
    func sendKudos(logId: Int) async -> Bool {
        guard !isSaving else { return false }
        isSaving = true
        saveErrorMessage = nil
        defer { isSaving = false }

        guard await post("/training/logs/\(logId)/kudos") != nil else { return false }

        Analytics.track(Analytics.Event.kudosSent, [Analytics.Property.logId: logId])
        markKudosGiven(logId: logId)
        return true
    }

    // MARK: - Reflejo local de una escritura

    private func markThanked(logId: Int) {
        guard let program = myProgram,
              let activity = program.coachActivity,
              activity.logId == logId else { return }
        myProgram = MyProgramResponse(
            assignment: program.assignment,
            program: program.program,
            current: program.current,
            week: program.week,
            coach: program.coach,
            lastLog: program.lastLog,
            coachActivity: TrainingCoachActivity(
                logId: activity.logId,
                reviewedAt: activity.reviewedAt,
                comment: activity.comment,
                congratulated: activity.congratulated,
                clientThanked: true,
                coach: activity.coach
            ),
            focusLifts: program.focusLifts
        )
    }

    private func markKudosGiven(logId: Int) {
        guard let group = groupToday else { return }
        groupToday = GroupToday(
            trainedToday: group.trainedToday.map { member in
                guard member.logId == logId else { return member }
                return GroupTodayMember(
                    userId: member.userId,
                    name: member.name,
                    pictureURL: member.pictureURL,
                    dayName: member.dayName,
                    logId: member.logId,
                    kudosGiven: true
                )
            },
            trainedCount: group.trainedCount,
            totalMembers: group.totalMembers,
            week: group.week,
            consistencyPct: group.consistencyPct,
            isNew: group.isNew
        )
    }

    // MARK: - Transporte

    private func stillCurrent(_ expected: Int?) -> Bool {
        GymService.shared.currentGymId == expected
    }

    private func get(_ path: String) async -> Data? {
        guard let url = URL(string: apiBaseURL + path),
              let request = await HTTPClient.shared.makeRequest(url: url, method: "GET") else {
            errorMessage = "Could not prepare the request"
            return nil
        }
        return await perform(request, path: path, isWrite: false)
    }

    private func send<T: Encodable>(_ path: String, method: String, body: T) async -> Data? {
        guard let url = URL(string: apiBaseURL + path),
              var request = await HTTPClient.shared.makeRequest(url: url, method: method) else {
            saveErrorMessage = "Could not prepare the request"
            return nil
        }
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        do {
            request.httpBody = try encoder.encode(body)
        } catch {
            saveErrorMessage = "Could not prepare the data"
            Logger.shared.error("TrainingService encode \(path): \(error)", category: .training)
            return nil
        }
        return await perform(request, path: path, isWrite: true)
    }

    /// Escritura sin cuerpo (`thank`, `kudos`): el contrato solo pide el id en la ruta.
    private func post(_ path: String) async -> Data? {
        guard let url = URL(string: apiBaseURL + path),
              let request = await HTTPClient.shared.makeRequest(url: url, method: "POST") else {
            saveErrorMessage = "Could not prepare the request"
            return nil
        }
        return await perform(request, path: path, isWrite: true)
    }

    private func perform(_ request: URLRequest, path: String, isWrite: Bool) async -> Data? {
        do {
            let (data, response) = try await session.data(for: request)
            guard let http = response as? HTTPURLResponse else { return nil }

            if (200...299).contains(http.statusCode) { return data }

            let message: String?
            switch http.statusCode {
            case 401:
                message = "Your session has expired"
            case 403:
                // Módulo apagado o rol insuficiente. No se enseña «no tienes permiso»: la vista
                // simplemente no debería estar ahí.
                message = detailMessage(from: data) ?? "This is not available in your space"
            case 404:
                // Recurso ausente no es un error que enseñar: la pantalla lo pinta vacío.
                return nil
            case 409:
                message = detailMessage(from: data) ?? "Already sent"
            case 422:
                message = detailMessage(from: data) ?? "Those values are not valid"
            default:
                message = detailMessage(from: data) ?? "Server error (\(http.statusCode))"
            }
            assign(message, isWrite: isWrite)
            Logger.shared.error("TrainingService \(path) -> \(http.statusCode)", category: .training)
            return nil
        } catch {
            // Una petición cancelada (la vista desapareció) no es un fallo que mostrar.
            if (error as NSError).code == NSURLErrorCancelled { return nil }
            assign("Could not connect", isWrite: isWrite)
            Logger.shared.error("TrainingService \(path): \(error.localizedDescription)", category: .training)
            return nil
        }
    }

    private func assign(_ message: String?, isWrite: Bool) {
        if isWrite { saveErrorMessage = message } else { errorMessage = message }
    }

    /// Extrae el `detail` de un error de FastAPI, que puede ser texto o una lista de validación.
    private func detailMessage(from data: Data) -> String? {
        guard let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return nil }
        if let text = object["detail"] as? String { return text }
        if let items = object["detail"] as? [[String: Any]] {
            let messages = items.compactMap { $0["msg"] as? String }
            if !messages.isEmpty { return messages.joined(separator: ". ") }
        }
        if let dict = object["detail"] as? [String: Any], let message = dict["message"] as? String {
            return message
        }
        return nil
    }

    /// El backend devuelve el literal `null` cuando no hay recurso, y eso no es un error.
    private func isNullBody(_ data: Data) -> Bool {
        if data.isEmpty { return true }
        let body = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines)
        return body == "null"
    }

    private func escape(_ value: String) -> String {
        value.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? value
    }

    private func report(_ error: Error, endpoint: String) {
        errorMessage = "Could not read your training data"
        Logger.shared.error("TrainingService decode \(endpoint): \(error)", category: .training)
    }

    // MARK: - Ciclo de vida

    func clearData() {
        myProgram = nil
        week = nil
        day = nil
        today = nil
        logs = []
        selectedLog = nil
        records = []
        strengthSummary = []
        exerciseHistory = nil
        groupToday = nil
        exercises = []

        programState = .idle
        weekState = .idle
        dayState = .idle
        logsState = .idle
        recordsState = .idle
        strengthState = .idle
        exerciseHistoryState = .idle
        groupState = .idle
        exercisesState = .idle

        errorMessage = nil
        saveErrorMessage = nil
        isLoading = false
        isSaving = false
        isLoadingHome = false
        loadedForGymId = nil
    }

    deinit {
        #if DEBUG
        print("🗑️ TrainingService deinitialized")
        #endif
    }
}

// MARK: - Errores

/// Solo los usa `syncLog`, que es la única llamada que necesita propagar el fallo hacia arriba
/// para que el outbox decida si reintenta o se rinde.
enum TrainingServiceError: LocalizedError {
    case couldNotPrepareRequest
    case invalidResponse
    case server(status: Int, message: String?)

    var errorDescription: String? {
        switch self {
        case .couldNotPrepareRequest:
            return "Could not prepare the request"
        case .invalidResponse:
            return "Unexpected response from the server"
        case .server(let status, let message):
            return message ?? "Server error (\(status))"
        }
    }

    /// Un 4xx que no sea 408 o 429 no mejora reintentando: el cuerpo está mal o no hay permiso.
    var isRetryable: Bool {
        switch self {
        case .couldNotPrepareRequest:
            return true
        case .invalidResponse:
            return true
        case .server(let status, _):
            if status == 408 || status == 429 { return true }
            return !(400...499).contains(status)
        }
    }
}
