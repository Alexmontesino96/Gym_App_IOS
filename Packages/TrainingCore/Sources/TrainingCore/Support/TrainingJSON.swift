//
//  TrainingJSON.swift
//  TrainingCore
//
//  Decodificador y codificador del paquete.
//
//  Espeja `Gym_API/Utils/BackendJSONDecoder.swift` (`BackendJSON`) porque un paquete no puede
//  importar el target de la app. Las dos reglas duras de allí siguen valiendo aquí:
//
//  1. NUNCA `keyDecodingStrategy = .convertFromSnakeCase`. Todos los modelos declaran sus
//     `CodingKeys` en snake_case.
//  2. El backend emite fechas en varios formatos según el endpoint; se prueban en orden.
//
//  En la app, `TrainingService` decodifica con `BackendJSON.decoder()` (lo exige el plan §8.1);
//  este tipo existe para que los tests del paquete decodifiquen los mismos fixtures sin la app.
//  Si uno de los dos cambia su política de fechas, el otro tiene que cambiar igual.
//

import Foundation

public enum TrainingJSON {

    public static func decoder() -> JSONDecoder {
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

    public static func encoder() -> JSONEncoder {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }

    // MARK: - Fechas

    private static let formats = [
        "yyyy-MM-dd'T'HH:mm:ss.SSSSSSZ",
        "yyyy-MM-dd'T'HH:mm:ss.SSSZ",
        "yyyy-MM-dd'T'HH:mm:ssZ",
        "yyyy-MM-dd'T'HH:mm:ss.SSSSSS",
        "yyyy-MM-dd'T'HH:mm:ss",
        "yyyy-MM-dd"
    ]

    private static let isoOptions: [ISO8601DateFormatter.Options] = [
        [.withInternetDateTime, .withFractionalSeconds],
        [.withInternetDateTime],
        [.withFullDate]
    ]

    public static func parseDate(_ raw: String) -> Date? {
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
