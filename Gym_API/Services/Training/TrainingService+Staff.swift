//
//  TrainingService+Staff.swift
//  Gym_API
//
//  Los endpoints del ENTRENADOR del módulo (plan §6.2, contrato final en WP2-informe §4).
//
//  Extensión y no servicio aparte porque el estado publicado, el descarte por cambio de espacio
//  (`stillCurrent`) y el transporte son los mismos: dos servicios contra el mismo prefijo
//  acabarían con dos ideas distintas de qué es un 404.
//
//  Lo que se repite en cada método, y por qué:
//
//  - **Lecturas** dejan su `LoadState` en `.failed` y no tocan `saveErrorMessage`: que no cargue
//    la lista de programas no es un error de escritura y no debe pintar la pantalla de rojo.
//  - **Escrituras** ponen `isSaving = true` ANTES del primer `await` (plan §8.1): entre el toque
//    y la primera suspensión el botón seguiría activo y un segundo toque duplicaría la petición.
//  - Ninguna respuesta repuebla el estado si el espacio cambió mientras viajaba.
//

import Foundation
import TrainingCore

extension TrainingService {

    // MARK: - Programas

    /// `GET /training/programs?status=&skip=&limit=`. Lista **plana** de plantillas.
    func fetchPrograms(status: TrainingProgramStatus? = nil, limit: Int = 50, expecting gymId: Int? = nil) async {
        #if DEBUG
        // La galería ya tiene el fixture puesto; salir a la red lo machacaría con un error.
        if isGalleryMode { return }
        #endif
        let expected = gymId ?? GymService.shared.currentGymId
        programsState = .loading
        var path = "/training/programs?limit=\(limit)"
        if let status { path += "&status=\(status.rawValue)" }

        guard let data = await get(path) else {
            if stillCurrent(expected) { programsState = .failed }
            return
        }
        guard stillCurrent(expected) else { return }
        do {
            programs = try decoder.decode([TrainingProgram].self, from: data)
            programsState = .loaded
        } catch {
            programsState = .failed
            report(error, endpoint: "programs")
        }
    }

    /// `GET /training/programs/{id}`. El programa con `blocks` embebidos y sin días.
    @discardableResult
    func fetchProgramDetail(_ programId: Int, expecting gymId: Int? = nil) async -> TrainingProgramDetail? {
        #if DEBUG
        // La galería ya tiene el fixture puesto; salir a la red lo machacaría con un error.
        if isGalleryMode { return programDetail }
        #endif
        let expected = gymId ?? GymService.shared.currentGymId
        programDetailState = .loading
        guard let data = await get("/training/programs/\(programId)") else {
            if stillCurrent(expected) { programDetailState = .failed }
            return nil
        }
        guard stillCurrent(expected) else { return nil }
        do {
            let detail = try decoder.decode(TrainingProgramDetail.self, from: data)
            programDetail = detail
            programDetailState = .loaded
            return detail
        } catch {
            programDetailState = .failed
            report(error, endpoint: "programs/\(programId)")
            return nil
        }
    }

    /// `POST /training/programs`.
    func createProgram(_ request: ProgramCreateRequest) async -> TrainingProgram? {
        guard !isSaving else { return nil }
        isSaving = true
        saveErrorMessage = nil
        defer { isSaving = false }

        guard let data = await send("/training/programs", method: "POST", body: request) else { return nil }
        do {
            let program = try decoder.decode(TrainingProgram.self, from: data)
            programs.insert(program, at: 0)
            return program
        } catch {
            saveErrorMessage = "Couldn't read the new program."
            Logger.shared.error("TrainingService decode programs POST: \(error)", category: .training)
            return nil
        }
    }

    /// `POST /training/programs/{id}/duplicate`. Devuelve la copia como borrador.
    func duplicateProgram(_ programId: Int) async -> TrainingProgram? {
        guard !isSaving else { return nil }
        isSaving = true
        saveErrorMessage = nil
        defer { isSaving = false }

        guard let data = await post("/training/programs/\(programId)/duplicate") else { return nil }
        return try? decoder.decode(TrainingProgram.self, from: data)
    }

    /// `POST /training/programs/{id}/publish`. 422 si el programa no tiene ningún día con
    /// ejercicios; el mensaje del servidor llega ya en `saveErrorMessage`.
    func publishProgram(_ programId: Int) async -> TrainingProgram? {
        guard !isSaving else { return nil }
        isSaving = true
        saveErrorMessage = nil
        defer { isSaving = false }

        guard let data = await post("/training/programs/\(programId)/publish") else { return nil }
        guard let program = try? decoder.decode(TrainingProgram.self, from: data) else { return nil }
        if let index = programs.firstIndex(where: { $0.id == program.id }) {
            programs[index] = program
        }
        return program
    }

    // MARK: - Bloques

    /// `POST /training/programs/{id}/blocks`.
    func createBlock(programId: Int, _ request: BlockRequest) async -> TrainingBlock? {
        guard !isSaving else { return nil }
        isSaving = true
        saveErrorMessage = nil
        defer { isSaving = false }

        guard let data = await send("/training/programs/\(programId)/blocks", method: "POST", body: request) else {
            return nil
        }
        return try? decoder.decode(TrainingBlock.self, from: data)
    }

    /// `PUT /training/programs/{id}/blocks/{block_id}`.
    func updateBlock(programId: Int, blockId: Int, _ request: BlockRequest) async -> TrainingBlock? {
        guard !isSaving else { return nil }
        isSaving = true
        saveErrorMessage = nil
        defer { isSaving = false }

        guard let data = await send(
            "/training/programs/\(programId)/blocks/\(blockId)",
            method: "PUT",
            body: request
        ) else { return nil }
        return try? decoder.decode(TrainingBlock.self, from: data)
    }

    /// `DELETE /training/programs/{id}/blocks/{block_id}`. No borra los días del bloque.
    @discardableResult
    func deleteBlock(programId: Int, blockId: Int) async -> Bool {
        guard !isSaving else { return false }
        isSaving = true
        saveErrorMessage = nil
        defer { isSaving = false }

        return await delete("/training/programs/\(programId)/blocks/\(blockId)")
    }

    // MARK: - Días

    /// `GET /training/programs/{id}/days?week=`.
    ///
    /// Devuelve **siempre siete días**: los que no existen en base llegan con `id: null` e
    /// `is_rest: true`. La vista los pinta como descanso y el editor los crea al guardar.
    func fetchProgramDays(programId: Int, week: Int, expecting gymId: Int? = nil) async {
        #if DEBUG
        // La galería ya tiene el fixture puesto; salir a la red lo machacaría con un error.
        if isGalleryMode { return }
        #endif
        let expected = gymId ?? GymService.shared.currentGymId
        // Igual que `fetchWeek`: `stillCurrent` vigila el gimnasio, no la semana. Cambiar de
        // semana varias veces seguidas —o volver del duplicador— podía dejar en pantalla los
        // ejercicios de una semana que ya no es la seleccionada, y el entrenador editaría o
        // duplicaría sobre el día equivocado sin ver ningún aviso.
        programDaysRequestToken &+= 1
        let token = programDaysRequestToken
        programDaysState = .loading
        guard let data = await get("/training/programs/\(programId)/days?week=\(week)") else {
            if stillCurrent(expected), token == programDaysRequestToken { programDaysState = .failed }
            return
        }
        guard stillCurrent(expected), token == programDaysRequestToken else { return }
        do {
            programDays = try decoder
                .decode([TrainingDay].self, from: data)
                .sorted { $0.dayNumber < $1.dayNumber }
            programDaysState = .loaded
        } catch {
            programDaysState = .failed
            report(error, endpoint: "programs/\(programId)/days")
        }
    }

    /// `PUT /training/programs/{id}/days/{day_number}`. **Reemplazo completo del día.**
    ///
    /// Lo que no viaje en `exercises` deja de existir. Devuelve el día con los ids nuevos para
    /// que la pantalla que llamó pueda seguir editando sin recargar.
    func saveDay(programId: Int, dayNumber: Int, _ request: DayUpsertRequest) async -> TrainingDay? {
        guard !isSaving else { return nil }
        isSaving = true
        saveErrorMessage = nil
        defer { isSaving = false }

        guard let data = await send(
            "/training/programs/\(programId)/days/\(dayNumber)",
            method: "PUT",
            body: request
        ) else { return nil }

        do {
            let day = try decoder.decode(TrainingDay.self, from: data)
            if let index = programDays.firstIndex(where: { $0.dayNumber == day.dayNumber }) {
                programDays[index] = day
            }
            return day
        } catch {
            // El día se guardó (2xx) pero no se pudo leer la respuesta. Se dice, en vez de
            // dejar la pantalla con un error de guardado que no ocurrió.
            Logger.shared.error("TrainingService decode days PUT: \(error)", category: .training)
            return nil
        }
    }

    /// `POST /training/programs/{id}/weeks/{week}/duplicate`. Reemplaza el destino.
    func duplicateWeek(programId: Int, week: Int, _ request: DuplicateWeekRequest) async -> DuplicateResult? {
        guard !isSaving else { return nil }
        isSaving = true
        saveErrorMessage = nil
        defer { isSaving = false }

        guard let data = await send(
            "/training/programs/\(programId)/weeks/\(week)/duplicate",
            method: "POST",
            body: request
        ) else { return nil }
        return try? decoder.decode(DuplicateResult.self, from: data)
    }

    /// `POST /training/programs/{id}/days/{n}/duplicate`. Reemplaza el destino.
    func duplicateDay(programId: Int, dayNumber: Int, _ request: DuplicateDayRequest) async -> DuplicateResult? {
        guard !isSaving else { return nil }
        isSaving = true
        saveErrorMessage = nil
        defer { isSaving = false }

        guard let data = await send(
            "/training/programs/\(programId)/days/\(dayNumber)/duplicate",
            method: "POST",
            body: request
        ) else { return nil }
        return try? decoder.decode(DuplicateResult.self, from: data)
    }

    // MARK: - Asignación

    /// `POST /training/programs/{id}/assign`.
    ///
    /// El 409 —el cliente ya tiene un programa activo— no es un fallo del que informar y punto:
    /// es la pregunta «¿lo reemplazo?». Por eso se distingue con un tipo de resultado en vez de
    /// devolver `nil` y dejar que la pantalla adivine qué pasó leyendo un texto.
    func assignProgram(programId: Int, _ request: AssignProgramRequest) async -> AssignmentOutcome {
        guard !isSaving else { return .cancelled }
        isSaving = true
        saveErrorMessage = nil
        defer { isSaving = false }

        guard let response = await sendReportingStatus(
            "/training/programs/\(programId)/assign",
            method: "POST",
            body: request
        ) else {
            return .cancelled
        }

        if (200...299).contains(response.status) {
            let assignments = (try? decoder.decode(AssignmentsResponse.self, from: response.data))?.assignments ?? []
            Analytics.track(Analytics.Event.programAssigned, [
                Analytics.Property.programId: programId,
                Analytics.Property.mode: request.mode.rawValue,
                Analytics.Property.clientCount: request.userIds.count
            ])
            return .assigned(assignments)
        }

        if response.status == 409 {
            return .alreadyAssigned(message: detailMessage(from: response.data))
        }

        saveErrorMessage = detailMessage(from: response.data) ?? "Couldn't assign the program."
        Logger.shared.error("TrainingService assign -> \(response.status)", category: .training)
        return .cancelled
    }

    /// `DELETE /training/assignments/{id}`. Pone `status = ended`; nunca borra.
    @discardableResult
    func endAssignment(_ assignmentId: Int) async -> Bool {
        guard !isSaving else { return false }
        isSaving = true
        saveErrorMessage = nil
        defer { isSaving = false }

        return await delete("/training/assignments/\(assignmentId)")
    }

    // MARK: - Ficha del cliente

    /// `GET /training/clients/{user_id}/programs` → `{active, past}`.
    func fetchClientPrograms(userId: Int, expecting gymId: Int? = nil) async {
        #if DEBUG
        // La galería ya tiene el fixture puesto; salir a la red lo machacaría con un error.
        if isGalleryMode { return }
        #endif
        let expected = gymId ?? GymService.shared.currentGymId
        clientProgramsState = .loading
        guard let data = await get("/training/clients/\(userId)/programs") else {
            if stillCurrent(expected) { clientProgramsState = .failed }
            return
        }
        guard stillCurrent(expected) else { return }
        do {
            clientPrograms = try decoder.decode(ClientProgramsResponse.self, from: data)
            clientProgramsState = .loaded
        } catch {
            clientProgramsState = .failed
            report(error, endpoint: "clients/\(userId)/programs")
        }
    }

    /// `GET /training/clients/{user_id}/logs?limit=&before=`.
    func fetchClientLogs(userId: Int, limit: Int = 20, before: Int? = nil, expecting gymId: Int? = nil) async {
        #if DEBUG
        // La galería ya tiene el fixture puesto; salir a la red lo machacaría con un error.
        if isGalleryMode { return }
        #endif
        let expected = gymId ?? GymService.shared.currentGymId
        clientLogsState = .loading
        var path = "/training/clients/\(userId)/logs?limit=\(limit)"
        if let before { path += "&before=\(before)" }

        guard let data = await get(path) else {
            if stillCurrent(expected) { clientLogsState = .failed }
            return
        }
        guard stillCurrent(expected) else { return }
        do {
            let page = try decoder.decode([TrainingWorkoutLogSummary].self, from: data)
            clientLogs = before == nil ? page : InboxCursor.capped(InboxCursor.merge(clientLogs, with: page))
            clientLogsState = .loaded
        } catch {
            clientLogsState = .failed
            report(error, endpoint: "clients/\(userId)/logs")
        }
    }

    /// `GET /training/clients/{user_id}/records`.
    func fetchClientRecords(userId: Int, expecting gymId: Int? = nil) async {
        #if DEBUG
        // La galería ya tiene el fixture puesto; salir a la red lo machacaría con un error.
        if isGalleryMode { return }
        #endif
        let expected = gymId ?? GymService.shared.currentGymId
        clientRecordsState = .loading
        guard let data = await get("/training/clients/\(userId)/records") else {
            if stillCurrent(expected) { clientRecordsState = .failed }
            return
        }
        guard stillCurrent(expected) else { return }
        do {
            clientRecords = try decoder.decode([TrainingPersonalRecord].self, from: data)
            clientRecordsState = .loaded
        } catch {
            clientRecordsState = .failed
            report(error, endpoint: "clients/\(userId)/records")
        }
    }

    /// `GET /training/clients/{user_id}/exercises/{key}/history?range=`.
    ///
    /// Escribe en `exerciseHistory`, el mismo sitio que la del cliente: S15 es la misma pantalla
    /// en modo lectura (UX §2) y tener dos copias del historial garantiza que una se quede vieja.
    func fetchClientExerciseHistory(
        userId: Int,
        exerciseKey: String,
        range: String = "8w",
        expecting gymId: Int? = nil
    ) async {
        #if DEBUG
        // La galería ya tiene el fixture puesto; salir a la red lo machacaría con un error.
        if isGalleryMode { return }
        #endif
        let expected = gymId ?? GymService.shared.currentGymId
        exerciseHistoryState = .loading
        let path = "/training/clients/\(userId)/exercises/\(escape(exerciseKey))/history?range=\(range)"
        guard let data = await get(path) else {
            if stillCurrent(expected) { exerciseHistoryState = .failed }
            return
        }
        guard stillCurrent(expected) else { return }
        do {
            exerciseHistory = try decoder.decode(ExerciseHistory.self, from: data)
            exerciseHistoryState = .loaded
        } catch {
            exerciseHistoryState = .failed
            report(error, endpoint: "clients/\(userId)/exercises/history")
        }
    }

    /// `GET /training/clients/{user_id}/exercises/{key}/last-performance`.
    ///
    /// No se publica: la usa el editor de día para sugerir una carga y solo importa mientras esa
    /// hoja está abierta.
    func fetchClientLastPerformance(userId: Int, exerciseKey: String) async -> ClientLastPerformance? {
        #if DEBUG
        // La galería no tiene backend al que preguntar la última carga.
        if isGalleryMode { return nil }
        #endif
        let path = "/training/clients/\(userId)/exercises/\(escape(exerciseKey))/last-performance"
        guard let data = await get(path), !isNullBody(data) else { return nil }
        return try? decoder.decode(ClientLastPerformance.self, from: data)
    }

    // MARK: - Revisión

    /// `POST /training/logs/{id}/review`. Devuelve el registro ya revisado.
    ///
    /// Una sola llamada para comentario y felicitación: el contrato los acepta juntos y separarlos
    /// mandaría dos push al cliente por el mismo gesto.
    func reviewLog(_ logId: Int, comment: String?, congratulate: Bool) async -> TrainingWorkoutLog? {
        guard !isSaving else { return nil }
        isSaving = true
        saveErrorMessage = nil
        defer { isSaving = false }

        let trimmed = comment?.trimmingCharacters(in: .whitespacesAndNewlines)
        let body = LogReviewRequest(
            comment: (trimmed?.isEmpty ?? true) ? nil : trimmed,
            congratulate: congratulate
        )
        guard let data = await send("/training/logs/\(logId)/review", method: "POST", body: body) else {
            return nil
        }

        Analytics.track(Analytics.Event.coachReview, [Analytics.Property.logId: logId])
        if congratulate {
            Analytics.track(Analytics.Event.coachCongratulate, [Analytics.Property.logId: logId])
        }

        guard let log = try? decoder.decode(TrainingWorkoutLog.self, from: data) else { return nil }
        selectedLog = log
        // El registro sale del buzón en cuanto se revisa: dejarlo ahí invita a revisarlo dos veces.
        inbox.removeAll { $0.id == logId }
        if let index = clientLogs.firstIndex(where: { $0.id == logId }) {
            clientLogs[index] = summary(from: log, keeping: clientLogs[index])
        }
        return log
    }

    /// `GET /training/inbox?limit=&before=`. Registros completados y sin revisar del espacio.
    func fetchInbox(limit: Int = 20, before: Int? = nil, expecting gymId: Int? = nil) async {
        #if DEBUG
        // La galería ya tiene el fixture puesto; salir a la red lo machacaría con un error.
        if isGalleryMode { return }
        #endif
        let expected = gymId ?? GymService.shared.currentGymId
        inboxState = .loading
        var path = "/training/inbox?limit=\(limit)"
        if let before { path += "&before=\(before)" }

        guard let data = await get(path) else {
            if stillCurrent(expected) { inboxState = .failed }
            return
        }
        guard stillCurrent(expected) else { return }
        do {
            let page = try decoder.decode([TrainingWorkoutLogSummary].self, from: data)
            inbox = before == nil ? page : InboxCursor.capped(InboxCursor.merge(inbox, with: page))
            inboxHasMore = InboxCursor.hasMore(page: page, limit: limit)
            inboxState = .loaded
        } catch {
            inboxState = .failed
            report(error, endpoint: "inbox")
        }
    }

    /// Pide la página siguiente del buzón. Sin más páginas no hace nada.
    func fetchMoreInbox(limit: Int = 20) async {
        #if DEBUG
        // La galería ya tiene el fixture puesto; salir a la red lo machacaría con un error.
        if isGalleryMode { return }
        #endif
        guard inboxHasMore, let cursor = InboxCursor.next(after: inbox) else { return }
        await fetchInbox(limit: limit, before: cursor)
    }

    // MARK: - Notas del día

    /// `GET /training/clients/{user_id}/day-notes/{date}`. Sin nota devuelve `null` con 200.
    func fetchDayNote(userId: Int, date: CalendarDate) async -> TrainingClientDayNote? {
        #if DEBUG
        // La galería ya tiene el fixture puesto; salir a la red lo machacaría con un error.
        if isGalleryMode { return nil }
        #endif
        guard let data = await get("/training/clients/\(userId)/day-notes/\(date.iso)"),
              !isNullBody(data) else { return nil }
        return try? decoder.decode(TrainingClientDayNote.self, from: data)
    }

    /// `GET /training/clients/{user_id}/day-notes?recent=`. La lista RECENT de S23.
    func fetchRecentDayNotes(userId: Int, count: Int = 5, expecting gymId: Int? = nil) async {
        #if DEBUG
        // La galería ya tiene el fixture puesto; salir a la red lo machacaría con un error.
        if isGalleryMode { return }
        #endif
        let expected = gymId ?? GymService.shared.currentGymId
        guard let data = await get("/training/clients/\(userId)/day-notes?recent=\(count)") else { return }
        guard stillCurrent(expected) else { return }
        recentDayNotes = (try? decoder.decode([TrainingClientDayNote].self, from: data)) ?? []
    }

    /// `PUT /training/clients/{user_id}/day-notes/{date}`. Upsert, máximo 280 caracteres.
    func saveDayNote(userId: Int, date: CalendarDate, text: String) async -> TrainingClientDayNote? {
        guard !isSaving else { return nil }
        isSaving = true
        saveErrorMessage = nil
        defer { isSaving = false }

        guard let data = await send(
            "/training/clients/\(userId)/day-notes/\(date.iso)",
            method: "PUT",
            body: DayNoteRequest(text: text)
        ) else { return nil }

        Analytics.track(Analytics.Event.dayNoteSent, [
            Analytics.Property.clientId: userId,
            Analytics.Property.date: date.iso
        ])

        guard let note = try? decoder.decode(TrainingClientDayNote.self, from: data) else { return nil }
        // La nota recién enviada encabeza RECENT sin esperar a otra petición.
        recentDayNotes.removeAll { $0.id == note.id }
        recentDayNotes.insert(note, at: 0)
        return note
    }

    // MARK: - Catálogo propio del espacio

    /// `POST /training/exercises`. La clave (`g{gym_id}_{slug}`) la genera el servidor.
    func createExercise(_ request: ExerciseCatalogRequest) async -> ExerciseCatalogItem? {
        guard !isSaving else { return nil }
        isSaving = true
        saveErrorMessage = nil
        defer { isSaving = false }

        guard let data = await send("/training/exercises", method: "POST", body: request) else { return nil }
        guard let item = try? decoder.decode(ExerciseCatalogItem.self, from: data) else { return nil }
        exercises.insert(item, at: 0)
        return item
    }

    /// `PUT /training/exercises/{id}`. Un ejercicio global responde 403: renombrarlo cambiaría
    /// el catálogo de todos los espacios.
    func updateExercise(_ exerciseId: Int, _ request: ExerciseCatalogRequest) async -> ExerciseCatalogItem? {
        guard !isSaving else { return nil }
        isSaving = true
        saveErrorMessage = nil
        defer { isSaving = false }

        guard let data = await send("/training/exercises/\(exerciseId)", method: "PUT", body: request) else {
            return nil
        }
        guard let item = try? decoder.decode(ExerciseCatalogItem.self, from: data) else { return nil }
        if let index = exercises.firstIndex(where: { $0.id == item.id }) {
            exercises[index] = item
        }
        return item
    }

    /// `DELETE /training/exercises/{id}`. Baja lógica (`is_active = false`).
    @discardableResult
    func deleteExercise(_ exerciseId: Int) async -> Bool {
        guard !isSaving else { return false }
        isSaving = true
        saveErrorMessage = nil
        defer { isSaving = false }

        let ok = await delete("/training/exercises/\(exerciseId)")
        if ok { exercises.removeAll { $0.id == exerciseId } }
        return ok
    }

    // MARK: - Ciclo de vida

    /// Lo llama `clearData()` al cambiar de espacio o cerrar sesión.
    func clearStaffData() {
        programs = []
        programDetail = nil
        programDays = []
        clientPrograms = nil
        clientLogs = []
        clientRecords = []
        inbox = []
        inboxHasMore = false
        recentDayNotes = []

        programsState = .idle
        programDetailState = .idle
        programDaysState = .idle
        clientProgramsState = .idle
        clientLogsState = .idle
        clientRecordsState = .idle
        inboxState = .idle
    }

    // MARK: - Privado

    /// `DELETE` sin cuerpo. Responde 204, así que el cuerpo vacío es la respuesta correcta.
    private func delete(_ path: String) async -> Bool {
        guard let url = URL(string: apiBaseURL + path),
              let request = await HTTPClient.shared.makeRequest(url: url, method: "DELETE") else {
            saveErrorMessage = "Could not prepare the request"
            return false
        }
        return await perform(request, path: path, isWrite: true) != nil
    }

    /// Refleja en la lista lo que la revisión acaba de cambiar, sin volver a pedirla.
    private func summary(
        from log: TrainingWorkoutLog,
        keeping previous: TrainingWorkoutLogSummary
    ) -> TrainingWorkoutLogSummary {
        TrainingWorkoutLogSummary(
            id: log.id,
            title: log.title,
            completedAt: log.completedAt,
            durationSeconds: log.durationSeconds,
            totalSets: log.totalSets,
            totalVolumeKg: log.totalVolumeKg,
            prCount: log.prCount,
            isPartial: log.isPartial,
            reviewedAt: log.reviewedAt,
            userId: log.userId ?? previous.userId,
            userName: previous.userName,
            userPictureURL: previous.userPictureURL,
            topPR: previous.topPR
        )
    }
}

// MARK: - Resultado de asignar

/// Las tres únicas cosas que pueden pasar al asignar un programa.
enum AssignmentOutcome {
    case assigned([TrainingAssignment])
    /// 409: el cliente ya tiene un programa activo. Hay que preguntar antes de reemplazarlo.
    case alreadyAssigned(message: String?)
    /// Error ya escrito en `saveErrorMessage`, o petición que no llegó a salir.
    case cancelled
}
