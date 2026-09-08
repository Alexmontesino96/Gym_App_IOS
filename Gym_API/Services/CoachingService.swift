//
//  CoachingService.swift
//  Gym_API
//
//  Resuelve quién es el entrenador personal del cliente.
//
//  No existe un endpoint "mi coach". Se compone de dos llamadas que cualquier miembro del
//  gimnasio puede hacer:
//    1. GET /gyms/users?role=OWNER          -> identidad garantizada (id y nombre completo)
//    2. GET /users/p/gym-participants/{id}  -> foto y bio
//
//  Por qué no se usa GET /relationships/my-trainers, que sería lo natural:
//    - exige que el rol GLOBAL del usuario sea MEMBER y devuelve 400 en cualquier otro caso
//    - lee una tabla sin gym_id, así que no está acotada por gimnasio
//    - esa tabla solo la escribe POST /relationships, al que no llama ningún flujo de alta
//  Queda como mejora cuando el backend la arregle.
//
//  Por qué tampoco sirve ChatService.getAvailableCoaches(): filtra por textos "coach" y
//  "trainer" en el rol, y en un espacio de entrenador personal el entrenador es OWNER,
//  así que devuelve cero resultados.
//

import Foundation
import Combine

@MainActor
final class CoachingService: ObservableObject {

    // MARK: - Singleton
    static let shared = CoachingService()
    private init() {}

    // MARK: - Published
    @Published var coach: CoachSummary?
    @Published var isLoadingCoach = false
    @Published var errorMessage: String?
    /// Distingue «este espacio no tiene entrenador» de «no se pudo consultar». Sin esto, un
    /// fallo de red se pintaba como ausencia de entrenador, que en un workspace de entrenador
    /// personal es imposible por definición.
    @Published var coachState: LoadState = .idle

    /// Clientes del espacio de trabajo. Solo tiene sentido para el ENTRENADOR.
    @Published var clients: [ClientSummary] = []
    @Published var clientsState: LoadState = .idle

    /// Última nota del entrenador en la conversación 1:1.
    @Published var coachNote: CoachNote?
    @Published var coachNoteState: LoadState = .idle

    // MARK: Lo que ve el ENTRENADOR en su panel

    /// Las sesiones de hoy con quién viene a cada una.
    @Published var todayRoster: [SessionRosterEntry] = []
    @Published var rosterState: LoadState = .idle

    /// El check-in de esta semana de cada cliente que lo haya hecho, el más reciente primero.
    /// Es la primera vez que iOS consume las rutas de salud para el equipo, que existían desde
    /// la fase 2 y hasta ahora solo leía el panel web.
    @Published var recentCheckIns: [ClientCheckIn] = []
    @Published var checkInsState: LoadState = .idle

    // MARK: - Dependencias
    weak var authService: AuthServiceDirect?
    weak var gymService: GymService?

    // MARK: - Privado
    private let baseURL = apiBaseURL
    private let session = URLSession.shared
    private lazy var decoder = BackendJSON.decoder()
    private var loadedForGymId: Int?
    private var loadedClientsForGymId: Int?
    /// Canal 1:1 ya resuelto, para no volver a pedirlo en cada carga de la home.
    private var coachChannelId: String?
    private var coachChannelForCoachId: Int?

    func configure(authService: AuthServiceDirect?, gymService: GymService?) {
        self.authService = authService
        self.gymService = gymService
    }

    // MARK: - Resolución del coach

    /// Resuelve el entrenador del espacio de trabajo actual.
    /// - Parameter forceRefresh: ignora el resultado ya cargado para este gimnasio.
    func loadCoach(forceRefresh: Bool = false) async {
        let gymId = GymService.shared.currentGymId

        if !forceRefresh, coach != nil, loadedForGymId == gymId {
            return
        }

        isLoadingCoach = true
        errorMessage = nil
        coachState = .loading
        defer { isLoadingCoach = false }

        // Paso 1: identidad. OWNER primero; si el espacio tiene asistentes, TRAINER como respaldo.
        let owners = await gymUsers(role: "OWNER")
        var row = owners.rows.first
        var failed = owners.failed

        if row == nil {
            let trainers = await gymUsers(role: "TRAINER")
            row = trainers.rows.first
            failed = failed || trainers.failed
        }

        // Si la consulta se cayó no se puede afirmar que no haya entrenador: se deja el estado
        // en fallo y se conserva el coach anterior si lo había.
        guard let row else {
            coachState = failed ? .failed : .loaded
            if failed {
                errorMessage = "Could not load your trainer"
            } else {
                coach = nil
            }
            loadedForGymId = GymService.shared.currentGymId
            return
        }

        // Paso 2: foto y bio. Es opcional: si falla, el coach se pinta con sus iniciales.
        let profile = await publicProfile(userId: row.id)

        // El nombre puede venir vacío en /gyms/users si el perfil no tiene nombre ni apellido.
        // Se compone con lo mejor disponible antes que descartar al entrenador.
        // El correo ya no viaja en la respuesta cuando quien pregunta es un cliente, así que
        // no sirve de respaldo. Antes de dejar la tarjeta sin nombre, se pone un genérico.
        let candidates = [
            profile?.fullName,
            row.fullName?.trimmingCharacters(in: .whitespaces),
            "Tu entrenador"
        ]
        let name = candidates.compactMap { $0 }.first { !$0.isEmpty } ?? "Tu entrenador"

        coach = CoachSummary(
            id: row.id,
            fullName: name,
            email: row.email,
            pictureURL: profile?.picture,
            bio: profile?.bio
        )
        coachState = .loaded
        // Se sella con el gimnasio VIGENTE al terminar, no con el capturado al empezar: si el
        // usuario cambió de gym durante la petición, este resultado ya no vale para el nuevo.
        loadedForGymId = GymService.shared.currentGymId
    }

    // MARK: - Clientes del entrenador

    /// Carga los clientes del espacio de trabajo actual.
    ///
    /// La lista sale de `role=MEMBER` sobre la pertenencia al gimnasio, que es el dato
    /// autoritativo. Las fotos se piden aparte en una sola llamada al listado público y se cruzan
    /// por id; si esa segunda llamada falla, los clientes se pintan con sus iniciales.
    func loadClients(forceRefresh: Bool = false) async {
        let gymId = GymService.shared.currentGymId

        if !forceRefresh, !clients.isEmpty, loadedClientsForGymId == gymId {
            return
        }

        clientsState = .loading
        let result = await gymUsers(role: "MEMBER", limit: 200)

        guard !result.failed else {
            clientsState = .failed
            return
        }

        let pictures = await pictureMap()

        guard GymService.shared.currentGymId == gymId else { return }

        clients = result.rows
            .map { row in
                ClientSummary(
                    id: row.id,
                    fullName: row.fullName?.trimmingCharacters(in: .whitespaces) ?? "",
                    email: row.email,
                    pictureURL: pictures[row.id],
                    joinedAt: row.joinedAt
                )
            }
            .sorted { $0.displayName.localizedCaseInsensitiveCompare($1.displayName) == .orderedAscending }

        clientsState = .loaded
        loadedClientsForGymId = gymId
    }

    /// Mapa id -> foto, en una sola llamada. Best effort: si falla, se devuelve vacío.
    private func pictureMap() async -> [Int: String] {
        guard let data = await get("/users/p/gym-participants?skip=0&limit=200") else { return [:] }
        guard let rows = try? decoder.decode([PublicProfileRow].self, from: data) else { return [:] }
        return rows.reduce(into: [Int: String]()) { map, row in
            if let picture = row.picture, !picture.isEmpty { map[row.id] = picture }
        }
    }

    /// Devuelve las filas y si la consulta falló, que no es lo mismo que venir vacía.
    private func gymUsers(role: String, limit: Int = 20) async -> (rows: [GymUserRow], failed: Bool) {
        guard let data = await get("/gyms/users?role=\(role)&skip=0&limit=\(limit)") else {
            return ([], true)
        }
        do {
            return (try decoder.decode([GymUserRow].self, from: data), false)
        } catch {
            Logger.shared.error("CoachingService decode /gyms/users?role=\(role): \(error)", category: .network)
            return ([], true)
        }
    }

    private func publicProfile(userId: Int) async -> PublicProfileRow? {
        guard let data = await get("/users/p/gym-participants/\(userId)") else { return nil }
        return try? decoder.decode(PublicProfileRow.self, from: data)
    }

    // MARK: - Transporte

    // MARK: - Nota del entrenador

    /// Carga el último mensaje que el entrenador haya escrito en la conversación 1:1.
    ///
    /// Va en dos pasos porque el último mensaje NO viaja por nuestra API: el esquema
    /// `ChatRoom` del backend solo devuelve identificadores del canal. Así que se resuelve el
    /// canal por HTTP y el mensaje se lee de Stream, que es donde vive.
    ///
    /// Es deliberadamente silenciosa: si el chat no está conectado todavía, o el canal no
    /// tiene mensajes, la tarjeta del coach se queda como estaba. No es un error que merezca
    /// pantalla.
    func loadCoachNote(forceRefresh: Bool = false) async {
        guard let coach else { return }
        if !forceRefresh, coachNote != nil, coachChannelForCoachId == coach.id { return }

        coachNoteState = .loading

        guard let channelId = await resolveCoachChannel(coachId: coach.id) else {
            coachNoteState = .failed
            return
        }

        guard let provider = ChatProviderManager.shared.currentProvider,
              ChatProviderManager.shared.isReady else {
            // El chat se conecta al autenticar; si todavía no está listo no se insiste.
            coachNoteState = .failed
            return
        }

        do {
            let messages = try await provider.getMessages(for: channelId, limit: 20, before: nil)
            // No se asume el orden que devuelve el proveedor: se ordena por fecha.
            let fromCoach = messages
                .filter { !$0.isFromCurrentUser }
                .filter { !$0.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
                .sorted { $0.timestamp > $1.timestamp }

            if let latest = fromCoach.first {
                coachNote = CoachNote(text: latest.text, sentAt: latest.timestamp)
            } else {
                coachNote = nil
            }
            coachNoteState = .loaded
        } catch {
            coachNoteState = .failed
            Logger.shared.error("CoachingService nota del coach: \(error.localizedDescription)", category: .network)
        }
    }

    /// Devuelve el canal 1:1 con el entrenador. El endpoint es get-or-create, así que la
    /// primera llamada abre la conversación: es la única que el producto contempla, y el
    /// diseño la da por existente.
    private func resolveCoachChannel(coachId: Int) async -> String? {
        if let coachChannelId, coachChannelForCoachId == coachId { return coachChannelId }

        guard let data = await get("/chat/rooms/direct/\(coachId)") else { return nil }
        do {
            let room = try decoder.decode(DirectChatRoomRef.self, from: data)
            coachChannelId = room.streamChannelId
            coachChannelForCoachId = coachId
            return room.streamChannelId
        } catch {
            Logger.shared.error("CoachingService canal 1:1: \(error)", category: .network)
            return nil
        }
    }

    // MARK: - Panel del entrenador

    /// Quién viene hoy. Recibe las sesiones ya cargadas por `ClassService` y resuelve, para cada
    /// una del día de hoy EN LA ZONA DEL ESPACIO, quién está inscrito.
    ///
    /// Requiere `clients` cargados: la foto y el nombre salen de ahí. Si no lo están, los pide.
    func loadTodayRoster(from sessions: [SessionWithClass]) async {
        if clients.isEmpty { await loadClients() }

        let hoy: [SessionWithClass] = sessions.filter { item in
            let tz = TimeZone(identifier: item.session.timeInfo.gymTimezone) ?? .current
            var cal = Calendar.current
            cal.timeZone = tz
            return cal.isDateInToday(item.session.startTime)
                && item.session.status != .cancelled
        }
        .sorted { $0.session.startTime < $1.session.startTime }

        guard !hoy.isEmpty else {
            todayRoster = []
            rosterState = .loaded
            return
        }

        rosterState = .loading
        let porId = Dictionary(uniqueKeysWithValues: clients.map { ($0.id, $0) })

        // Una peticion por sesion, en paralelo. Son una, dos, tres al dia.
        let entradas: [SessionRosterEntry] = await withTaskGroup(of: (Int, SessionRosterEntry).self) { group in
            for (i, item) in hoy.enumerated() {
                group.addTask { [self] in
                    let filas = await self.participants(sessionId: item.session.id)
                    let activo = filas.first { $0.isActive }
                    let cliente = activo.flatMap { porId[$0.memberId] }
                    return (i, SessionRosterEntry(session: item.session,
                                                  className: item.classInfo.name,
                                                  client: cliente))
                }
            }
            var acc: [(Int, SessionRosterEntry)] = []
            for await r in group { acc.append(r) }
            return acc.sorted { $0.0 < $1.0 }.map { $0.1 }
        }

        todayRoster = entradas
        rosterState = .loaded
    }

    /// Los check-ins de esta semana de toda la cartera. Uno por cliente, el mas reciente.
    ///
    /// `GET /health/clients/{id}/check-ins?weeks=1` esta limitado a 60 peticiones por minuto, asi
    /// que se corta la cartera a 50. Con mas clientes, lo honesto es un endpoint agregado, no
    /// pedir de uno en uno; se anota y no se disimula.
    func loadRecentCheckIns() async {
        if clients.isEmpty { await loadClients() }
        guard !clients.isEmpty else {
            recentCheckIns = []
            checkInsState = clientsState == .failed ? .failed : .loaded
            return
        }

        checkInsState = .loading
        let objetivo = Array(clients.prefix(50))
        if clients.count > objetivo.count {
            Logger.shared.info("CoachingService: cartera de \(clients.count), check-ins solo de los 50 primeros",
                               category: .network)
        }

        let resultados: [ClientCheckIn] = await withTaskGroup(of: ClientCheckIn?.self) { group in
            for cliente in objetivo {
                group.addTask { [self] in
                    guard let data = await self.get("/health/clients/\(cliente.id)/check-ins?weeks=1"),
                          let lista = try? BackendJSON.decoder().decode([WeeklyCheckIn].self, from: data),
                          let ultimo = lista.first else { return nil }
                    let entrada = ClientCheckIn(client: cliente, checkIn: ultimo)
                    return entrada.hasSomethingToSay ? entrada : nil
                }
            }
            var acc: [ClientCheckIn] = []
            for await r in group { if let r { acc.append(r) } }
            return acc
        }

        recentCheckIns = resultados.sorted { $0.checkIn.createdAt > $1.checkIn.createdAt }
        checkInsState = .loaded
    }

    private func participants(sessionId: Int) async -> [SessionParticipantRow] {
        guard let data = await get("/schedule/participation/participants/\(sessionId)") else { return [] }
        return (try? decoder.decode([SessionParticipantRow].self, from: data)) ?? []
    }

    private func get(_ path: String) async -> Data? {
        guard let url = URL(string: baseURL + path),
              let request = await HTTPClient.shared.makeRequest(url: url, method: "GET") else {
            return nil
        }
        do {
            let (data, response) = try await session.data(for: request)
            guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
                let code = (response as? HTTPURLResponse)?.statusCode ?? -1
                Logger.shared.error("CoachingService \(path) -> \(code)", category: .network)
                return nil
            }
            return data
        } catch {
            Logger.shared.error("CoachingService \(path): \(error.localizedDescription)", category: .network)
            return nil
        }
    }

    #if DEBUG
    /// Solo para la galería de revisión: sin sesión no hay check-ins que pedir y la ficha del
    /// cliente se capturaría con la sección vacía, que no es el estado que hay que revisar.
    func setCheckInsForGallery(_ items: [ClientCheckIn]) {
        recentCheckIns = items
        checkInsState = .loaded
    }
    #endif

    // MARK: - Ciclo de vida

    func clearData() {
        todayRoster = []
        rosterState = .idle
        recentCheckIns = []
        checkInsState = .idle
        coachNote = nil
        coachNoteState = .idle
        coachChannelId = nil
        coachChannelForCoachId = nil
        coach = nil
        clients = []
        clientsState = .idle
        loadedClientsForGymId = nil
        loadedForGymId = nil
        errorMessage = nil
        isLoadingCoach = false
        coachState = .idle
    }

    deinit {
        #if DEBUG
        print("🗑️ CoachingService deinitialized")
        #endif
    }
}
