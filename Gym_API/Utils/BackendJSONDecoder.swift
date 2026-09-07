//
//  BackendJSONDecoder.swift
//  Gym_API
//
//  Decodificador compartido para las respuestas del backend.
//
//  Dos reglas que conviene no perder de vista:
//
//  1. NUNCA se usa `keyDecodingStrategy = .convertFromSnakeCase`. Los modelos del proyecto
//     declaran sus `CodingKeys` en snake_case, así que activar la conversión transforma la
//     clave del JSON y luego no encuentra la declarada. Ese fue el fallo que dejaba el
//     contexto de workspace nulo en todos los arranques.
//  2. El backend emite fechas en varios formatos según el endpoint (microsegundos, milisegundos,
//     sin fracciones, y `date` a secas en los campos de tipo fecha). Se prueban en orden.
//

import Foundation

enum BackendJSON {

    /// Decodificador estándar para respuestas del backend.
    static func decoder() -> JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .custom { decoder in
            let container = try decoder.singleValueContainer()
            let raw = try container.decode(String.self)

            if let date = parseDate(raw) { return date }

            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "No se pudo interpretar la fecha '\(raw)'"
            )
        }
        return decoder
    }

    /// Codificador para los cuerpos de petición. Fechas en ISO 8601.
    static func encoder() -> JSONEncoder {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }

    // MARK: - Fechas

    private static let formats = [
        "yyyy-MM-dd'T'HH:mm:ss.SSSSSSZ",   // microsegundos, el habitual del backend
        "yyyy-MM-dd'T'HH:mm:ss.SSSZ",      // milisegundos
        "yyyy-MM-dd'T'HH:mm:ssZ",          // sin fracciones
        "yyyy-MM-dd'T'HH:mm:ss.SSSSSS",    // sin zona horaria
        "yyyy-MM-dd'T'HH:mm:ss",
        "yyyy-MM-dd"                       // campos de tipo date, p. ej. target_date
    ]

    private static let isoOptions: [ISO8601DateFormatter.Options] = [
        [.withInternetDateTime, .withFractionalSeconds],
        [.withInternetDateTime],
        [.withFullDate]
    ]

    static func parseDate(_ raw: String) -> Date? {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)

        for format in formats {
            formatter.dateFormat = format
            if let date = formatter.date(from: raw) { return date }
        }

        let iso = ISO8601DateFormatter()
        for option in isoOptions {
            iso.formatOptions = option
            if let date = iso.date(from: raw) { return date }
        }

        return nil
    }
}
