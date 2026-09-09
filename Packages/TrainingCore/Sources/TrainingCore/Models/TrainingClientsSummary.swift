//
//  TrainingClientsSummary.swift
//  TrainingCore
//
//  El triage del entrenador: `GET /training/clients/summary` (visión §8.3).
//
//  Es la respuesta a la primera promesa del producto —«el coach lo ve todo de un vistazo»— y por
//  eso el modelo tiene dos reglas que no se parecen a las del resto de `Models/`:
//
//  1. **`attention` es `[String]`, no un enum.** El servidor emite razones parametrizadas
//     (`missed_3`, `silent_7d`) y la lista crecerá antes que la app instalada en el teléfono de
//     nadie. Un enum obligaría a elegir entre tragarse una razón nueva o pintar un `fallback`
//     falso; con cadenas, lo que no se reconoce se enseña TAL CUAL, que es peor tipografía y
//     mejor información.
//  2. **La traducción a texto humano vive aquí y se prueba aquí.** «missed_1» → «Missed 1» no es
//     una decisión de la vista: es contrato, y una vista no se puede probar sin simulador.
//
//  Todo lo demás decodifica tolerante (contadores ausentes = 0, objetos ausentes = nulo) porque
//  esta pantalla es la primera que abre el entrenador cada mañana: un campo que falte no puede
//  dejarla en blanco.
//

import Foundation

// MARK: - Razones de atención

/// Traducción de las razones de `attention` al inglés que lee el entrenador.
///
/// Las razones con número (`missed_{n}`, `silent_{n}d`) se parsean por prefijo; las fijas están
/// en la tabla. Lo desconocido se devuelve intacto: es información del servidor y esconderla
/// sería peor que enseñarla sin maquillar.
public enum TrainingAttentionReason {

    /// «missed_1» → «Missed 1», «silent_5d» → «Silent 5 days», «unreviewed» → «To review».
    public static func humanText(for raw: String) -> String {
        let key = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !key.isEmpty else { return raw }

        switch key {
        case "checkin_pending":
            return "Check-in pending"
        case "unreviewed":
            return "To review"
        case "no_program":
            return "No program"
        default:
            break
        }

        if let count = number(in: key, prefix: "missed_") {
            return "Missed \(count)"
        }
        // El sufijo `d` de `silent_5d` es del contrato; sin él no es una razón conocida.
        if key.hasSuffix("d"), let days = number(in: String(key.dropLast()), prefix: "silent_") {
            return "Silent \(days) day\(days == 1 ? "" : "s")"
        }

        return raw
    }

    /// Las razones ya traducidas y unidas como las pinta la interfaz: «Missed 1 · To review».
    public static func humanText(for reasons: [String]) -> String {
        reasons.map { humanText(for: $0) }.joined(separator: " · ")
    }

    private static func number(in key: String, prefix: String) -> Int? {
        guard key.hasPrefix(prefix) else { return nil }
        let digits = key.dropFirst(prefix.count)
        guard !digits.isEmpty, digits.allSatisfy(\.isNumber) else { return nil }
        return Int(digits)
    }
}

// MARK: - Piezas de la fila

/// El programa activo del cliente dentro del resumen. Nulo cuando no hay asignación.
public struct TrainingClientProgramRef: Codable, Hashable, Identifiable, Sendable {

    public let id: Int
    public let name: String
    /// Registros completados ÷ días de entreno transcurridos, como en `GET /clients/{id}/programs`.
    public let adherencePct: Double?

    public enum CodingKeys: String, CodingKey {
        case id, name
        case adherencePct = "adherence_pct"
    }

    public init(id: Int, name: String, adherencePct: Double? = nil) {
        self.id = id
        self.name = name
        self.adherencePct = adherencePct
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decodeIfPresent(Int.self, forKey: .id) ?? 0
        name = try container.decodeIfPresent(String.self, forKey: .name) ?? ""
        adherencePct = try container.decodeIfPresent(Double.self, forKey: .adherencePct)
    }

    /// «71% adherence». Nulo cuando el servidor no la ha podido calcular todavía.
    public var adherenceText: String? {
        guard let adherencePct else { return nil }
        return "\(Int(adherencePct.rounded()))% adherence"
    }
}

/// Los cuatro contadores de la semana en curso. Sin programa, todo cero.
public struct TrainingClientWeekCounts: Codable, Hashable, Sendable {

    public let planned: Int
    public let done: Int
    public let missed: Int
    public let pending: Int

    public enum CodingKeys: String, CodingKey {
        case planned, done, missed, pending
    }

    public init(planned: Int = 0, done: Int = 0, missed: Int = 0, pending: Int = 0) {
        self.planned = planned
        self.done = done
        self.missed = missed
        self.pending = pending
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        planned = try container.decodeIfPresent(Int.self, forKey: .planned) ?? 0
        done = try container.decodeIfPresent(Int.self, forKey: .done) ?? 0
        missed = try container.decodeIfPresent(Int.self, forKey: .missed) ?? 0
        pending = try container.decodeIfPresent(Int.self, forKey: .pending) ?? 0
    }

    /// «2 of 4 this week». Nulo cuando no hay nada planificado: un «0 of 0» no dice nada.
    public var progressText: String? {
        guard planned > 0 else { return nil }
        return "\(done) of \(planned) this week"
    }
}

public enum TrainingCheckinStatus: String, TrainingCodableEnum {
    case pending
    case submitted

    /// Falla cerrado: lo que no se reconoce se trata como pendiente, que es lo que hace mirar.
    public static var fallback: TrainingCheckinStatus { .pending }
}

/// `checkin`: el estado del check-in semanal del cliente para `week_start`.
public struct TrainingClientCheckinState: Codable, Hashable, Sendable {

    public let status: TrainingCheckinStatus
    public let weekStart: Date?

    public enum CodingKeys: String, CodingKey {
        case status
        case weekStart = "week_start"
    }

    public init(status: TrainingCheckinStatus = .pending, weekStart: Date? = nil) {
        self.status = status
        self.weekStart = weekStart
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        status = try container.decodeIfPresent(TrainingCheckinStatus.self, forKey: .status) ?? .pending
        weekStart = try container.decodeIfPresent(Date.self, forKey: .weekStart)
    }

    public var isSubmitted: Bool { status == .submitted }
}

// MARK: - La fila

/// Un cliente en el triage: quién es, qué programa lleva, cómo va la semana y por qué mirarlo.
public struct TrainingClientSummary: Codable, Hashable, Identifiable, Sendable {

    public let userId: Int
    public let fullName: String
    public let pictureURL: String?
    public let joinedAt: Date?
    public let program: TrainingClientProgramRef?
    public let lastLoggedAt: Date?
    /// Días completos desde el último registro `completed`; sin registros, desde `joined_at`.
    public let daysSilent: Int
    public let thisWeek: TrainingClientWeekCounts
    public let unreviewedLogs: Int
    public let checkin: TrainingClientCheckinState?
    /// Razones crudas, en el orden de severidad del servidor. Vacío = va bien.
    public let attention: [String]

    public var id: Int { userId }

    public enum CodingKeys: String, CodingKey {
        case program, checkin, attention
        case userId = "user_id"
        case fullName = "full_name"
        case pictureURL = "picture_url"
        case joinedAt = "joined_at"
        case lastLoggedAt = "last_logged_at"
        case daysSilent = "days_silent"
        case thisWeek = "this_week"
        case unreviewedLogs = "unreviewed_logs"
    }

    public init(
        userId: Int,
        fullName: String,
        pictureURL: String? = nil,
        joinedAt: Date? = nil,
        program: TrainingClientProgramRef? = nil,
        lastLoggedAt: Date? = nil,
        daysSilent: Int = 0,
        thisWeek: TrainingClientWeekCounts = TrainingClientWeekCounts(),
        unreviewedLogs: Int = 0,
        checkin: TrainingClientCheckinState? = nil,
        attention: [String] = []
    ) {
        self.userId = userId
        self.fullName = fullName
        self.pictureURL = pictureURL
        self.joinedAt = joinedAt
        self.program = program
        self.lastLoggedAt = lastLoggedAt
        self.daysSilent = daysSilent
        self.thisWeek = thisWeek
        self.unreviewedLogs = unreviewedLogs
        self.checkin = checkin
        self.attention = attention
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        userId = try container.decodeIfPresent(Int.self, forKey: .userId) ?? 0
        fullName = try container.decodeIfPresent(String.self, forKey: .fullName) ?? ""
        pictureURL = try container.decodeIfPresent(String.self, forKey: .pictureURL)
        joinedAt = try container.decodeIfPresent(Date.self, forKey: .joinedAt)
        program = try container.decodeIfPresent(TrainingClientProgramRef.self, forKey: .program)
        lastLoggedAt = try container.decodeIfPresent(Date.self, forKey: .lastLoggedAt)
        daysSilent = try container.decodeIfPresent(Int.self, forKey: .daysSilent) ?? 0
        thisWeek = try container.decodeIfPresent(TrainingClientWeekCounts.self, forKey: .thisWeek)
            ?? TrainingClientWeekCounts()
        unreviewedLogs = try container.decodeIfPresent(Int.self, forKey: .unreviewedLogs) ?? 0
        checkin = try container.decodeIfPresent(TrainingClientCheckinState.self, forKey: .checkin)
        attention = try container.decodeIfPresent([String].self, forKey: .attention) ?? []
    }

    // MARK: Texto

    public var needsAttention: Bool { !attention.isEmpty }

    /// Las razones traducidas, una a una, para pintarlas como chips.
    public var attentionTexts: [String] {
        attention.map { TrainingAttentionReason.humanText(for: $0) }
    }

    /// «Missed 1 · Check-in pending». Cadena vacía cuando el cliente va bien.
    public var attentionText: String {
        TrainingAttentionReason.humanText(for: attention)
    }

    /// El nombre de pila, que es como habla la interfaz del entrenador.
    public var firstName: String {
        let trimmed = fullName.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return "Client" }
        return trimmed.components(separatedBy: " ").first ?? trimmed
    }

    public var initials: String {
        let letters = fullName.split(separator: " ").prefix(2).compactMap(\.first).map { String($0).uppercased() }
        return letters.isEmpty ? "?" : letters.joined()
    }

    /// La segunda línea de la fila: «Trained yesterday · 71% adherence», «Silent 5 days»,
    /// «No program yet».
    ///
    /// Se calcula con `days_silent`, que ya viene contado por el servidor en la zona horaria del
    /// espacio: hacerlo aquí con el reloj del teléfono daría «yesterday» a las 00:30 de un
    /// cliente que entrenó hace veinte minutos.
    public var statusLine: String {
        var parts: [String] = []

        if program == nil {
            parts.append("No program yet")
        } else if lastLoggedAt == nil {
            parts.append("No sessions yet")
        } else if daysSilent >= Self.silentThreshold {
            parts.append("Silent \(daysSilent) days")
        } else {
            parts.append(trainedText)
        }

        if let adherenceText = program?.adherenceText {
            parts.append(adherenceText)
        }

        return parts.joined(separator: " · ")
    }

    /// A partir de aquí la línea deja de contar cuándo entrenó y cuenta cuánto lleva callado.
    /// Es el mismo umbral con el que el servidor emite `silent_{n}d` (visión §8.3).
    public static let silentThreshold = 4

    private var trainedText: String {
        switch daysSilent {
        case ..<1: return "Trained today"
        case 1: return "Trained yesterday"
        default: return "Trained \(daysSilent) days ago"
        }
    }
}

// MARK: - La respuesta

/// `GET /training/clients/summary`.
public struct TrainingClientsSummary: Codable, Hashable, Sendable {

    /// Lunes de la semana local del espacio.
    public let weekStart: Date?
    /// Ya ordenados por el servidor: número de razones ↓, `days_silent` ↓, nombre.
    public let clients: [TrainingClientSummary]

    public enum CodingKeys: String, CodingKey {
        case clients
        case weekStart = "week_start"
    }

    public init(weekStart: Date? = nil, clients: [TrainingClientSummary] = []) {
        self.weekStart = weekStart
        self.clients = clients
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        weekStart = try container.decodeIfPresent(Date.self, forKey: .weekStart)
        clients = try container.decodeIfPresent([TrainingClientSummary].self, forKey: .clients) ?? []
    }

    /// Los que hay que mirar, en el orden en que llegaron.
    public var needingAttention: [TrainingClientSummary] {
        clients.filter(\.needsAttention)
    }

    /// Búsqueda por id, para cruzar el resumen con la lista de clientes de `CoachingService`.
    public func client(withId id: Int) -> TrainingClientSummary? {
        clients.first { $0.userId == id }
    }
}
