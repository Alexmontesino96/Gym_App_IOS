//
//  AccentContrast.swift
//  TrainingCore
//
//  Contraste WCAG del acento cuando se usa como TINTA, no como relleno.
//
//  El problema que resuelve: el acento por defecto de la app es lima (`#D4FF3F`), y un lima sobre
//  una superficie clara (`#F6F7FA`) da 1,2:1. Como relleno de un botón funciona —la tinta encima
//  la decide `accentInkForCurrentAccent`—, pero como color de un glifo o de un texto es
//  prácticamente invisible: el check de un día hecho, el rombo de una marca, el «Done ✓» de la
//  semana. Incumple los puntos 5 y 7 del checklist de la UX.
//
//  La solución no puede ser un hex fijo: el acento es configurable (29 opciones en
//  `ThemeManager.lightAccentOptions`). Hay que **oscurecer el acento actual** hasta que se lea,
//  conservando su tono: el lima se vuelve oliva, el rojo se vuelve granate, y la identidad que
//  eligió el espacio se mantiene.
//
//  Vive en el paquete y no en `ThemeManager` porque es aritmética pura y este es el único sitio
//  del repositorio con tests. `ThemeManager` la llama; nada de aquí sabe qué es una vista.
//

import Foundation

public enum AccentContrast {

    /// Mínimo de WCAG 2.1 AA para texto normal (checklist §10.7).
    public static let minimumTextContrast: Double = 4.5

    /// Hasta dónde se puede oscurecer antes de rendirse. Con 40 pasos de 0,025 se llega al negro.
    private static let maximumSteps = 40

    // MARK: - WCAG

    /// Luminancia relativa de un color en hexadecimal (`#RRGGBB` o `RRGGBB`).
    public static func relativeLuminance(hex: String) -> Double {
        guard let rgb = components(hex: hex) else { return 0 }
        func channel(_ raw: Double) -> Double {
            raw <= 0.03928 ? raw / 12.92 : pow((raw + 0.055) / 1.055, 2.4)
        }
        return 0.2126 * channel(rgb.r) + 0.7152 * channel(rgb.g) + 0.0722 * channel(rgb.b)
    }

    /// Ratio de contraste entre dos colores, de 1:1 a 21:1.
    public static func contrastRatio(_ first: String, _ second: String) -> Double {
        let a = relativeLuminance(hex: first)
        let b = relativeLuminance(hex: second)
        let lighter = max(a, b)
        let darker = min(a, b)
        return (lighter + 0.05) / (darker + 0.05)
    }

    // MARK: - Tinta legible

    /// El acento oscurecido lo justo para leerse sobre `surface`.
    ///
    /// Si el acento ya contrasta, se devuelve **tal cual**: un acento oscuro sobre fondo claro, o
    /// el mismo lima sobre el fondo negro del tema oscuro, no se tocan. Si no, se baja el brillo
    /// en HSB de 0,025 en 0,025 conservando tono y saturación, y se devuelve el primero que
    /// alcanza el ratio. Si ni el negro llega (superficie muy oscura y a la vez muy clara no
    /// existe, pero el bucle tiene tope), se devuelve el más contrastado que se encontró.
    public static func readableHex(
        accent: String,
        onSurface surface: String,
        minimumRatio: Double = minimumTextContrast
    ) -> String {
        guard let base = components(hex: accent) else { return accent }
        if contrastRatio(accent, surface) >= minimumRatio { return normalized(accent) }

        var color = hsb(from: base)
        var best = normalized(accent)
        var bestRatio = contrastRatio(accent, surface)

        for _ in 0..<maximumSteps {
            color.brightness = max(0, color.brightness - 0.025)
            let candidate = hex(from: rgb(from: color))
            let ratio = contrastRatio(candidate, surface)
            if ratio > bestRatio {
                bestRatio = ratio
                best = candidate
            }
            if ratio >= minimumRatio { return candidate }
            if color.brightness == 0 { break }
        }
        return best
    }

    // MARK: - Conversión

    private struct RGB { var r: Double; var g: Double; var b: Double }
    private struct HSB { var hue: Double; var saturation: Double; var brightness: Double }

    private static func components(hex: String) -> RGB? {
        let clean = hex.hasPrefix("#") ? String(hex.dropFirst()) : hex
        guard clean.count == 6, let value = UInt32(clean, radix: 16) else { return nil }
        return RGB(
            r: Double((value >> 16) & 0xFF) / 255,
            g: Double((value >> 8) & 0xFF) / 255,
            b: Double(value & 0xFF) / 255
        )
    }

    private static func normalized(_ hex: String) -> String {
        guard let rgb = components(hex: hex) else { return hex }
        return self.hex(from: rgb)
    }

    private static func hex(from rgb: RGB) -> String {
        func byte(_ value: Double) -> Int { Int((max(0, min(1, value)) * 255).rounded()) }
        return String(format: "#%02X%02X%02X", byte(rgb.r), byte(rgb.g), byte(rgb.b))
    }

    private static func hsb(from rgb: RGB) -> HSB {
        let maximum = max(rgb.r, rgb.g, rgb.b)
        let minimum = min(rgb.r, rgb.g, rgb.b)
        let delta = maximum - minimum

        var hue: Double = 0
        if delta > 0 {
            if maximum == rgb.r {
                hue = 60 * (((rgb.g - rgb.b) / delta).truncatingRemainder(dividingBy: 6))
            } else if maximum == rgb.g {
                hue = 60 * (((rgb.b - rgb.r) / delta) + 2)
            } else {
                hue = 60 * (((rgb.r - rgb.g) / delta) + 4)
            }
        }
        if hue < 0 { hue += 360 }

        return HSB(
            hue: hue,
            saturation: maximum == 0 ? 0 : delta / maximum,
            brightness: maximum
        )
    }

    private static func rgb(from hsb: HSB) -> RGB {
        let c = hsb.brightness * hsb.saturation
        let x = c * (1 - abs((hsb.hue / 60).truncatingRemainder(dividingBy: 2) - 1))
        let m = hsb.brightness - c

        let (r, g, b): (Double, Double, Double)
        switch hsb.hue {
        case ..<60: (r, g, b) = (c, x, 0)
        case ..<120: (r, g, b) = (x, c, 0)
        case ..<180: (r, g, b) = (0, c, x)
        case ..<240: (r, g, b) = (0, x, c)
        case ..<300: (r, g, b) = (x, 0, c)
        default: (r, g, b) = (c, 0, x)
        }
        return RGB(r: r + m, g: g + m, b: b + m)
    }
}
