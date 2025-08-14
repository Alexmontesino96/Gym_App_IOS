import Foundation

enum DateDecoding {
    /// Shared JSONDecoder for server dates with multiple ISO8601 variants.
    static func serverDecoder() -> JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .custom { decoder in
            let container = try decoder.singleValueContainer()
            let dateString = try container.decode(String.self)

            if #available(iOS 15.0, *) {
                let styles: [Date.ISO8601FormatStyle] = [
                    .init(includingFractionalSeconds: true),
                    .init(includingFractionalSeconds: false),
                    .init(timeZone: TimeZone(secondsFromGMT: 0)!)
                ]
                for style in styles {
                    if let date = try? style.parse(dateString) { return date }
                    if !dateString.hasSuffix("Z") {
                        if let date = try? style.parse(dateString + "Z") { return date }
                    }
                }
            }

            let formatter = DateFormatter()
            formatter.locale = Locale(identifier: "en_US_POSIX")
            formatter.timeZone = TimeZone(secondsFromGMT: 0)
            let formats = [
                "yyyy-MM-dd'T'HH:mm:ss.SSSSSS'Z'",
                "yyyy-MM-dd'T'HH:mm:ss.SSS'Z'",
                "yyyy-MM-dd'T'HH:mm:ss'Z'",
                "yyyy-MM-dd'T'HH:mm:ss.SSSSSS",
                "yyyy-MM-dd'T'HH:mm:ss.SSS",
                "HH:mm:ss.SSS'Z'",
                "HH:mm:ss'Z'"
            ]
            for f in formats {
                formatter.dateFormat = f
                if let d = formatter.date(from: dateString) { return d }
                if !dateString.hasSuffix("Z"), let d = formatter.date(from: dateString + "Z") { return d }
            }
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "Cannot decode date string: \(dateString)")
        }
        return decoder
    }
}

