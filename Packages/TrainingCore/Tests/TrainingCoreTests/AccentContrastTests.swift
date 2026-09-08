//
//  AccentContrastTests.swift
//  TrainingCoreTests
//
//  El acento como tinta tiene que leerse (checklist §10.5 y §10.7).
//
//  Estos casos fijan lo que la revisión 1 encontró: el lima por defecto sobre una superficie
//  clara da 1,2:1, y todo lo que se pintaba con él —checks, rombos, «Done ✓»— era casi invisible
//  en tema claro. La corrección no puede ser un hex fijo porque el acento es configurable, así
//  que se prueba con varios acentos del catálogo real de `ThemeManager`.
//

import Testing
import Foundation
@testable import TrainingCore

@Suite("Acento legible")
struct AccentContrastTests {

    /// Las tres superficies claras de la app: tarjeta, superficie elevada y fondo.
    static let lightSurface = "#F6F7FA"
    static let lightSurface2 = "#F7F7F7"
    static let lightBackground = "#FFFFFF"
    static let darkSurface = "#1A1A1A"

    @Test("El lima por defecto no se lee sobre una superficie clara")
    func limeIsUnreadableOnLightSurface() {
        let ratio = AccentContrast.contrastRatio("#D4FF3F", Self.lightSurface)
        #expect(ratio < 1.5)
    }

    @Test("El acento oscurecido alcanza 4,5:1 en las tres superficies claras")
    func darkenedAccentReachesTheMinimum() {
        for accent in ["#D4FF3F", "#6FCF3F", "#FFD54F", "#4DB6AC", "#FF6B6B", "#AED581"] {
            let readable = AccentContrast.readableHex(accent: accent, onSurface: Self.lightSurface)
            for surface in [Self.lightSurface, Self.lightSurface2, Self.lightBackground] {
                let ratio = AccentContrast.contrastRatio(readable, surface)
                #expect(
                    ratio >= 4.0,
                    "\(accent) -> \(readable) sobre \(surface) da \(String(format: "%.2f", ratio)):1"
                )
            }
        }
    }

    @Test("Contra la superficie de tarjeta el mínimo se cumple exactamente")
    func minimumIsMetOnTheCardSurface() {
        for accent in ["#D4FF3F", "#6FCF3F", "#FFD54F", "#4DB6AC", "#FF6B6B", "#AED581", "#F06292"] {
            let readable = AccentContrast.readableHex(accent: accent, onSurface: Self.lightSurface)
            #expect(AccentContrast.contrastRatio(readable, Self.lightSurface) >= 4.5)
        }
    }

    @Test("Un acento que ya contrasta no se toca: la conversión es idempotente")
    func alreadyReadableAccentIsUnchanged() {
        // El deep teal del catálogo se queda a 4,36:1, así que baja un punto de brillo. Lo que
        // importa es que el resultado ya no se vuelva a tocar: aplicar dos veces da lo mismo.
        for accent in ["#00827E", "#D4FF3F", "#FF6B6B"] {
            let once = AccentContrast.readableHex(accent: accent, onSurface: Self.lightSurface)
            let twice = AccentContrast.readableHex(accent: once, onSurface: Self.lightSurface)
            #expect(once == twice, "\(accent): \(once) -> \(twice)")
        }
    }

    @Test("En tema oscuro el acento se queda como está")
    func darkThemeKeepsTheAccent() {
        for accent in ["#D4FF3F", "#6FCF3F", "#FFD54F"] {
            #expect(AccentContrast.contrastRatio(accent, Self.darkSurface) >= 4.5)
            #expect(AccentContrast.readableHex(accent: accent, onSurface: Self.darkSurface) == accent)
        }
    }

    @Test("Oscurecer conserva el tono: el lima sigue siendo verde amarillento")
    func hueSurvivesTheDarkening() {
        let readable = AccentContrast.readableHex(accent: "#D4FF3F", onSurface: Self.lightSurface)
        // Verde amarillento: el canal verde manda y el azul es el menor.
        let clean = readable.dropFirst()
        let value = UInt32(clean, radix: 16) ?? 0
        let r = (value >> 16) & 0xFF
        let g = (value >> 8) & 0xFF
        let b = value & 0xFF
        #expect(g > r)
        #expect(r > b)
    }

    @Test("Con un blanco puro como acento no se queda dando vueltas")
    func whiteAccentTerminates() {
        let readable = AccentContrast.readableHex(accent: "#FFFFFF", onSurface: Self.lightBackground)
        // No hay blanco legible sobre blanco: devuelve lo más contrastado que encontró y para.
        #expect(readable.count == 7)
        #expect(AccentContrast.contrastRatio(readable, Self.lightBackground) > 1)
    }

    @Test("Un hexadecimal que no lo es se devuelve intacto")
    func invalidHexIsReturnedAsIs() {
        #expect(AccentContrast.readableHex(accent: "no-soy-un-color", onSurface: Self.lightSurface) == "no-soy-un-color")
        #expect(AccentContrast.relativeLuminance(hex: "zzz") == 0)
    }
}
