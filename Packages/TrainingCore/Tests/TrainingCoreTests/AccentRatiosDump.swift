//
//  AccentRatiosDump.swift
//  TrainingCoreTests
//
//  Imprime la tabla de ratios del acento como tinta. No es una comprobación: es la evidencia que
//  pide la revisión, y se ejecuta con el resto de la suite para que no se quede obsoleta.
//

import Testing
import Foundation
@testable import TrainingCore

@Suite("Tabla de contraste del acento")
struct AccentRatiosDump {

    @Test("Ratios del acento como tinta sobre las superficies claras")
    func printRatios() {
        let surfaces = [("tarjeta #F6F7FA", "#F6F7FA"), ("superficie/2 #F7F7F7", "#F7F7F7"), ("fondo #FFFFFF", "#FFFFFF")]
        let accents = ["#D4FF3F", "#6FCF3F", "#FFD54F", "#4DB6AC", "#FF6B6B", "#C43421", "#5C6AC4", "#F06292"]

        print("\n| acento | tinta en claro | " + surfaces.map(\.0).joined(separator: " | ") + " |")
        for accent in accents {
            let readable = AccentContrast.readableHex(accent: accent, onSurface: "#F6F7FA")
            let ratios = surfaces.map { String(format: "%.2f:1", AccentContrast.contrastRatio(readable, $0.1)) }
            print("| \(accent) | \(readable) | " + ratios.joined(separator: " | ") + " |")
            #expect(AccentContrast.contrastRatio(readable, "#F6F7FA") >= 4.5)
        }

        print("\nEn oscuro (#1A1A1A) el acento no se toca:")
        for accent in ["#D4FF3F", "#FF6B6B"] {
            let readable = AccentContrast.readableHex(accent: accent, onSurface: "#1A1A1A")
            let ratio = AccentContrast.contrastRatio(readable, "#1A1A1A")
            print("  \(accent) -> \(readable)  \(String(format: "%.2f:1", ratio))")
            #expect(readable == accent)
        }
    }
}
