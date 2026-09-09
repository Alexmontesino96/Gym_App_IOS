import Foundation

/// Converts a complete, localized ticket amount without rounding or accepting trailing text.
enum EventTicketAmount {
    static func cents(from text: String, locale: Locale = .current) -> Int? {
        let value = text.trimmingCharacters(in: .whitespacesAndNewlines)
        let separator = locale.decimalSeparator ?? "."
        let parts = value.components(separatedBy: separator)
        guard (1...2).contains(parts.count),
              parts.allSatisfy({ !$0.isEmpty && $0.utf8.allSatisfy { (48...57).contains($0) } }),
              parts.count == 1 || parts[1].count <= 2,
              let whole = Int(parts[0]), whole <= 999_999 else { return nil }
        let fraction = parts.count == 2 ? Int(parts[1])! * (parts[1].count == 1 ? 10 : 1) : 0
        let amount = whole * 100 + fraction
        return (1...99_999_999).contains(amount) ? amount : nil
    }
}
