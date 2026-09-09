//
//  HealthService.swift
//  Gym_API
//
//  Cliente del módulo /api/v1/health del backend: mediciones corporales y objetivos.
//
//  Alimenta el widget de check-in semanal (peso y variación) y el de progreso hacia un
//  objetivo. Sigue el patrón de servicio de la casa, con una desviación deliberada:
//  construye las peticiones con HTTPClient en lugar de a mano, como manda CLAUDE.md.
//

import Foundation
import Combine

/// Distingue «todavía no hay datos» de «no se pudieron cargar». Sin esto, un fallo de red se
/// pinta en la UI como si el cliente nunca se hubiera pesado, que es una mentira distinta.
enum LoadState: Equatable {
    case idle
    case loading
    case loaded
    case failed
}

@MainActor
final class HealthService: ObservableObject {

    // MARK: - Singleton
    static let shared = HealthService()
    private init() {}

    // MARK: - Published
    @Published var latestMeasurement: HealthMeasurement?
    @Published var weightHistory: WeightHistory = .empty
    @Published var goals: [HealthGoal] = []
    @Published var weightState: LoadState = .idle
    @Published var goalsState: LoadState = .idle
    @Published var isLoading = false
    @Published var isSaving = false
    /// Error de LECTURA. La pantalla de guardado usa `saveErrorMessage` para no mezclarlos.
    @Published var errorMessage: String?
    @Published var saveErrorMessage: String?

    /// Último check-in semanal, para saber si la semana ya está enviada.
    @Published var latestCheckIn: WeeklyCheckIn?
    @Published var checkInState: LoadState = .idle

    /// Intake del propio cliente (8.4). `nil` con `intakeState == .loaded` es «no lo ha
    /// rellenado todavía»; `nil` con `.failed` es «no se pudo consultar», y son cosas
    /// distintas: la tarjeta «Tell your coach about you» solo se enseña en el primer caso.
    @Published var myIntake: ClientIntake?
    @Published var intakeState: LoadState = .idle

    /// Intake de UN cliente, visto por el personal en su ficha. Un solo hueco, como
    /// `clientPrograms` en `TrainingService`: la pantalla pide uno cada vez que abre a alguien.
    @Published var clientIntake: ClientIntake?
    @Published var clientIntakeState: LoadState = .idle

    // MARK: - Dependencias
    weak var authService: AuthServiceDirect?
    weak var gymService: GymService?

    // MARK: - Privado
    private let baseURL = apiBaseURL
    private let session = URLSession.shared
    private lazy var decoder = BackendJSON.decoder()
    private lazy var encoder = BackendJSON.encoder()
    /// Evita que la respuesta de un gimnasio repueble el estado después de cambiar a otro.
    private var loadedForGymId: Int?
    private var isLoadingAll = false

    func configure(authService: AuthServiceDirect?, gymService: GymService?) {
        self.authService = authService
        self.gymService = gymService
    }

    // MARK: - Derivados para la UI

    /// Objetivo de fuerza activo más reciente, que es el que pinta el widget de progreso.
    var strengthGoal: HealthGoal? {
        goals.first { $0.isStrength }
    }

    /// Peso más reciente conocido. `weightHistory` está acotado a una ventana, así que si el
    /// cliente lleva meses sin pesarse la serie viene vacía pero la última medición sigue existiendo.
    var currentWeight: Double? {
        weightHistory.currentWeight ?? latestMeasurement?.weight
    }

    /// Fecha del último pesaje conocido, de cualquiera de las dos fuentes.
    var lastWeighInDate: Date? {
        let fromHistory = weightHistory.points.last?.recordedAt
        let fromLatest = latestMeasurement?.recordedAt
        switch (fromHistory, fromLatest) {
        case let (a?, b?): return max(a, b)
        case let (a?, nil): return a
        case let (nil, b?): return b
        default: return nil
        }
    }

    /// Variación respecto al pesaje anterior a la última semana.
    ///
    /// No se comparan dos puntos DENTRO de los últimos 7 días: con una cadencia semanal de
    /// check-in casi nunca hay dos, y la cápsula desaparecía justo en el caso normal. Se compara
    /// el último pesaje contra el más reciente que sea al menos 5 días anterior.
    var weeklyWeightChange: Double? {
        let points = weightHistory.points
        guard let last = points.last, points.count >= 2 else { return nil }
        guard let cutoff = Calendar.current.date(byAdding: .day, value: -5, to: last.recordedAt) else { return nil }
        let previous = points.dropLast().last { $0.recordedAt <= cutoff } ?? points.dropLast().last
        guard let previous else { return nil }
        return (last.weight - previous.weight).rounded(toPlaces: 1)
    }

    /// Si el cliente ya ha registrado peso en los últimos 7 días.
    /// Ventana móvil en vez de semana natural: la semana natural depende del primer día que tenga
    /// configurado el dispositivo y haría que el estado cambiara solo al pasar de domingo a lunes.
    var hasCheckedInThisWeek: Bool {
        // Un check-in cuenta aunque no lleve peso: alguien puede puntuar cómo ha dormido y no
        // subirse a la báscula, y decirle que sigue pendiente sería falso.
        if let checkIn = latestCheckIn,
           Calendar.current.isDate(checkIn.weekStart, equalTo: Date(), toGranularity: .weekOfYear) {
            return true
        }
        guard let last = lastWeighInDate else { return false }
        return Date().timeIntervalSince(last) < 7 * 24 * 3600
    }

    // MARK: - Lectura

    /// Carga en paralelo lo que necesita la home del cliente.
    func loadAll(days: Int = 90) async {
        guard !isLoadingAll else { return }
        isLoadingAll = true
        isLoading = true
        errorMessage = nil
        defer {
            isLoadingAll = false
            isLoading = false
        }

        let gymId = GymService.shared.currentGymId
        loadedForGymId = gymId

        async let latest: Void = fetchLatestMeasurement(expecting: gymId)
        async let history: Void = fetchWeightHistory(days: days, expecting: gymId)
        async let goalsTask: Void = fetchGoals(expecting: gymId)
        async let checkIn: Void = fetchLatestCheckIn()
        _ = await (latest, history, goalsTask, checkIn)
    }

    func fetchLatestMeasurement(expecting gymId: Int? = nil) async {
        let expected = gymId ?? GymService.shared.currentGymId
        guard let data = await get("/health/measurements/latest") else { return }
        guard stillCurrent(expected) else { return }

        // El endpoint devuelve el literal `null` cuando el usuario no tiene ninguna medición.
        let body = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines)
        if data.isEmpty || body == "null" {
            latestMeasurement = nil
            return
        }
        do {
            latestMeasurement = try decoder.decode(HealthMeasurement.self, from: data)
        } catch {
            report(error, endpoint: "measurements/latest")
        }
    }

    func fetchWeightHistory(days: Int = 90, expecting gymId: Int? = nil) async {
        let expected = gymId ?? GymService.shared.currentGymId
        weightState = .loading
        guard let data = await get("/health/measurements/weight-history?days=\(days)") else {
            if stillCurrent(expected) { weightState = .failed }
            return
        }
        guard stillCurrent(expected) else { return }
        do {
            weightHistory = try decoder.decode(WeightHistory.self, from: data)
            weightState = .loaded
        } catch {
            weightState = .failed
            report(error, endpoint: "measurements/weight-history")
        }
    }

    func fetchGoals(status: String? = nil, expecting gymId: Int? = nil) async {
        let expected = gymId ?? GymService.shared.currentGymId
        goalsState = .loading
        let path = status.map { "/health/goals?status=\($0)" } ?? "/health/goals"
        guard let data = await get(path) else {
            if stillCurrent(expected) { goalsState = .failed }
            return
        }
        guard stillCurrent(expected) else { return }
        do {
            goals = try decoder.decode([HealthGoal].self, from: data)
            goalsState = .loaded
        } catch {
            goalsState = .failed
            report(error, endpoint: "goals")
        }
    }

    // MARK: - Escritura

    /// Registra el peso del check-in. Devuelve true si se guardó.
    @discardableResult
    func recordWeight(_ weight: Double, notes: String? = nil) async -> Bool {
        guard !isSaving else { return false }
        // Se marca ANTES de cualquier await: si se hiciera dentro de `send`, entre el toque y el
        // primer suspend el botón seguiría habilitado y un segundo toque duplicaría la medición.
        isSaving = true
        saveErrorMessage = nil
        defer { isSaving = false }

        let trimmedNotes = notes.map { String($0.prefix(HealthService.maxNotesLength)) }
        let body = HealthMeasurementRequest(weight: weight, notes: trimmedNotes)

        guard let data = await send("/health/measurements", method: "POST", body: body) else {
            return false
        }

        // El POST ya está confirmado en servidor. Si el eco no decodifica, sigue siendo un éxito:
        // devolver false aquí llevaría al cliente a guardar dos veces el mismo peso.
        if let measurement = try? decoder.decode(HealthMeasurement.self, from: data) {
            latestMeasurement = measurement
        } else {
            Logger.shared.error("HealthService: 201 de measurements con cuerpo no decodificable", category: .network)
        }
        await fetchWeightHistory(days: weightHistory.days == 0 ? 90 : weightHistory.days)
        return true
    }

    /// Envía el check-in de la semana: peso, las tres escalas y la nota.
    ///
    /// Sustituye a `recordWeight` en la hoja de check-in. El servidor crea la medición de peso
    /// además del check-in, así que la serie que alimenta el widget de la home se sigue llenando
    /// por el mismo sitio de siempre. Por eso al terminar se refresca la serie: sin ese refresco,
    /// la tarjeta seguiría enseñando el peso de la semana pasada.
    @discardableResult
    func submitWeeklyCheckIn(
        weightKilograms: Double?,
        energy: Int?,
        sleep: Int?,
        soreness: Int?,
        notes: String?
    ) async -> Bool {
        guard !isSaving else { return false }
        // Antes de cualquier await, por lo mismo que en recordWeight.
        isSaving = true
        saveErrorMessage = nil
        defer { isSaving = false }

        let trimmedNotes = notes.map { String($0.prefix(HealthService.maxNotesLength)) }
        let body = WeeklyCheckInRequest(
            weight: weightKilograms,
            energy: energy,
            sleep: sleep,
            soreness: soreness,
            notes: trimmedNotes
        )

        guard let data = await send("/health/check-ins", method: "POST", body: body) else {
            return false
        }

        // Igual que en recordWeight: el servidor ya lo tiene. Un eco ilegible no convierte el
        // envío en un fallo, o el cliente acabaría mandando el check-in dos veces.
        if let checkIn = try? decoder.decode(WeeklyCheckIn.self, from: data) {
            latestCheckIn = checkIn
            checkInState = .loaded
        } else {
            Logger.shared.error("HealthService: check-in guardado con cuerpo no decodificable", category: .network)
        }

        await fetchWeightHistory(days: weightHistory.days == 0 ? 90 : weightHistory.days)
        return true
    }

    /// Carga el último check-in. Silencioso: que no haya ninguno es lo normal al empezar.
    func fetchLatestCheckIn() async {
        checkInState = .loading
        guard let data = await get("/health/check-ins/latest") else {
            checkInState = .failed
            return
        }
        // El servidor devuelve `null` cuando no hay ninguno, y eso no es un error.
        latestCheckIn = try? decoder.decode(WeeklyCheckIn.self, from: data)
        checkInState = .loaded
    }

    // MARK: - Intake del cliente (8.4)

    /// Carga el intake del cliente autenticado. Un 404 es «no lo ha rellenado» y se guarda como
    /// éxito con `myIntake = nil`; solo un fallo de transporte deja `intakeState = .failed`, que
    /// es lo que decide si `CoachHomeView` enseña la tarjeta de invitación.
    func fetchMyIntake() async {
        intakeState = .loading
        let result = await getIntake(path: "/health/intake")
        switch result {
        case .notFound:
            myIntake = nil
            intakeState = .loaded
        case .loaded(let intake):
            myIntake = intake
            intakeState = .loaded
        case .failed:
            intakeState = .failed
        }
    }

    /// Envía (o reemplaza) el intake del cliente autenticado. `PUT` es upsert en el servidor.
    @discardableResult
    func submitIntake(_ request: ClientIntakeRequest) async -> Bool {
        guard !isSaving else { return false }
        isSaving = true
        saveErrorMessage = nil
        defer { isSaving = false }

        guard let data = await send("/health/intake", method: "PUT", body: request) else {
            return false
        }
        if let intake = try? decoder.decode(ClientIntake.self, from: data) {
            myIntake = intake
            intakeState = .loaded
        } else {
            Logger.shared.error("HealthService: intake guardado con cuerpo no decodificable", category: .network)
        }
        return true
    }

    /// Carga el intake de UN cliente, para la ficha del entrenador. Mismo tratamiento del 404
    /// que `fetchMyIntake`: «no lo ha rellenado» no es un error.
    func fetchClientIntake(userId: Int) async {
        clientIntakeState = .loading
        let result = await getIntake(path: "/health/clients/\(userId)/intake")
        switch result {
        case .notFound:
            clientIntake = nil
            clientIntakeState = .loaded
        case .loaded(let intake):
            clientIntake = intake
            clientIntakeState = .loaded
        case .failed:
            clientIntakeState = .failed
        }
    }

    private enum IntakeFetch {
        case loaded(ClientIntake)
        case notFound
        case failed
    }

    /// `get()` no distingue «404» de «fallo de red»: los dos devuelven `nil`. Aquí sí hace
    /// falta la diferencia, así que este va directo contra `perform` en vez de reutilizarlo.
    private func getIntake(path: String) async -> IntakeFetch {
        guard let url = URL(string: baseURL + path),
              let request = await HTTPClient.shared.makeRequest(url: url, method: "GET") else {
            return .failed
        }
        do {
            let (data, response) = try await session.data(for: request)
            guard let http = response as? HTTPURLResponse else { return .failed }
            if http.statusCode == 404 { return .notFound }
            guard (200...299).contains(http.statusCode) else {
                Logger.shared.error("HealthService \(path) -> \(http.statusCode)", category: .network)
                return .failed
            }
            guard let intake = try? decoder.decode(ClientIntake.self, from: data) else {
                Logger.shared.error("HealthService decode \(path): cuerpo no decodificable", category: .network)
                return .failed
            }
            return .loaded(intake)
        } catch {
            if (error as NSError).code == NSURLErrorCancelled { return .failed }
            Logger.shared.error("HealthService \(path): \(error.localizedDescription)", category: .network)
            return .failed
        }
    }

    // MARK: - Respuesta al check-in (8.5)

    /// Responde al check-in de un cliente. Sobrescribir está permitido por el servidor, así
    /// que se puede llamar más de una vez sobre el mismo check-in. Devuelve el check-in
    /// actualizado para que quien llama (la ficha del cliente, el panel) refresque su copia en
    /// memoria; `HealthService` solo actualiza la suya si coincide con `latestCheckIn`.
    @discardableResult
    func replyToCheckIn(userId: Int, checkInId: Int, text: String) async -> WeeklyCheckIn? {
        guard !isSaving else { return nil }
        isSaving = true
        saveErrorMessage = nil
        defer { isSaving = false }

        let trimmed = String(text.trimmingCharacters(in: .whitespacesAndNewlines).prefix(HealthService.maxReplyLength))
        guard !trimmed.isEmpty else { return nil }

        let body = CheckInReplyRequest(text: trimmed)
        guard let data = await send(
            "/health/clients/\(userId)/check-ins/\(checkInId)/reply",
            method: "POST",
            body: body
        ) else {
            return nil
        }
        guard let updated = try? decoder.decode(WeeklyCheckIn.self, from: data) else {
            Logger.shared.error("HealthService: respuesta a check-in con cuerpo no decodificable", category: .network)
            return nil
        }
        if latestCheckIn?.id == updated.id { latestCheckIn = updated }
        return updated
    }

    static let maxReplyLength = 500

    @discardableResult
    func updateGoalProgress(goalId: Int, currentValue: Double) async -> Bool {
        guard !isSaving else { return false }
        isSaving = true
        saveErrorMessage = nil
        defer { isSaving = false }

        let body = HealthGoalProgressRequest(currentValue: currentValue)
        guard let data = await send("/health/goals/\(goalId)/progress", method: "PATCH", body: body) else {
            return false
        }
        if let updated = try? decoder.decode(HealthGoal.self, from: data) {
            if let index = goals.firstIndex(where: { $0.id == updated.id }) {
                goals[index] = updated
            } else {
                goals.append(updated)
            }
        }
        return true
    }

    static let maxNotesLength = 1000

    // MARK: - Transporte

    private func stillCurrent(_ expected: Int?) -> Bool {
        GymService.shared.currentGymId == expected
    }

    private func get(_ path: String) async -> Data? {
        guard let url = URL(string: baseURL + path),
              let request = await HTTPClient.shared.makeRequest(url: url, method: "GET") else {
            errorMessage = "Could not prepare the request"
            return nil
        }
        return await perform(request, path: path, isWrite: false)
    }

    private func send<T: Encodable>(_ path: String, method: String, body: T) async -> Data? {
        guard let url = URL(string: baseURL + path),
              var request = await HTTPClient.shared.makeRequest(url: url, method: method) else {
            saveErrorMessage = "Could not prepare the request"
            return nil
        }
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        do {
            request.httpBody = try encoder.encode(body)
        } catch {
            saveErrorMessage = "Could not prepare the data"
            Logger.shared.error("HealthService encode \(path): \(error)", category: .network)
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
            case 404:
                // Recurso ausente no es un error que enseñar: la home lo pinta vacío.
                return nil
            case 422:
                message = detailMessage(from: data) ?? "Those values are not valid"
            default:
                message = detailMessage(from: data) ?? "Server error (\(http.statusCode))"
            }
            assign(message, isWrite: isWrite)
            Logger.shared.error("HealthService \(path) -> \(http.statusCode)", category: .network)
            return nil
        } catch {
            // Una petición cancelada (la vista desapareció) no es un fallo que mostrar.
            if (error as NSError).code == NSURLErrorCancelled { return nil }
            assign("Could not connect", isWrite: isWrite)
            Logger.shared.error("HealthService \(path): \(error.localizedDescription)", category: .network)
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

    private func report(_ error: Error, endpoint: String) {
        errorMessage = "Could not read your health data"
        Logger.shared.error("HealthService decode \(endpoint): \(error)", category: .network)
    }

    // MARK: - Ciclo de vida

    func clearData() {
        latestMeasurement = nil
        latestCheckIn = nil
        checkInState = .idle
        myIntake = nil
        intakeState = .idle
        clientIntake = nil
        clientIntakeState = .idle
        weightHistory = .empty
        goals = []
        weightState = .idle
        goalsState = .idle
        errorMessage = nil
        saveErrorMessage = nil
        isLoading = false
        isSaving = false
        isLoadingAll = false
        loadedForGymId = nil
    }

    deinit {
        #if DEBUG
        print("🗑️ HealthService deinitialized")
        #endif
    }
}

// MARK: - Utilidad

extension Double {
    func rounded(toPlaces places: Int) -> Double {
        guard isFinite else { return self }
        let divisor = pow(10.0, Double(places))
        return (self * divisor).rounded() / divisor
    }
}
