//
//  TrainingStyle.swift
//  Gym_API
//
//  Contrato visual del módulo de entrenamiento (plan §2.2, UX §3).
//
//  Existe para que quince vistas no repitan quince veces la misma tarjeta y los mismos tamaños
//  de letra. Todo lo que hay aquí es una traducción literal de la especificación:
//
//  - Los tokens tipográficos de UX §3, cada uno con su tope de Dynamic Type. Ningún tamaño fijo
//    entra en una vista del módulo sin pasar por aquí.
//  - La tarjeta canónica de `CoachHomeView.swift:253-259`, que es la que ya usa el resto de la
//    app: superficie, radio 22 y borde al 15 %, que sigue viéndose en tema claro.
//  - Los colores salen SIEMPRE de `ThemeManager`. Ni un literal.
//

import SwiftUI

// MARK: - Tipografía (UX §3)

/// Los tokens de la especificación, con su tope para que en `xxxLarge` no se rompa ningún botón.
///
/// El tope no es opcional: `type/mono-xl` a 40 pt escalado por `accessibility5` mide 96 pt y una
/// cifra de cinco dígitos ya no cabe en un iPhone. Con tope crece hasta donde entra y para.
enum TrainingType {

    static func display() -> Font { .cappedDynamicSystem(size: 34, weight: .semibold, maxSize: 44) }
    static func title1() -> Font { .cappedDynamicSystem(size: 28, weight: .semibold, maxSize: 38) }
    static func title2() -> Font { .cappedDynamicSystem(size: 22, weight: .semibold, maxSize: 32) }
    static func headline() -> Font { .cappedDynamicSystem(size: 17, weight: .semibold, maxSize: 26) }
    static func body() -> Font { .cappedDynamicSystem(size: 16, weight: .regular, maxSize: 24) }
    static func subhead() -> Font { .cappedDynamicSystem(size: 15, weight: .regular, maxSize: 23) }
    static func caption() -> Font { .cappedDynamicSystem(size: 13, weight: .regular, maxSize: 20) }
    static func label() -> Font { .cappedDynamicSystem(size: 11, weight: .semibold, maxSize: 17) }

    /// Cifras: monoespaciadas y tabulares, que es lo que permite alinearlas por la coma.
    static func monoXL() -> Font { .system(size: cap(40, 52), weight: .bold, design: .monospaced) }
    static func monoL() -> Font { .system(size: cap(28, 38), weight: .bold, design: .monospaced) }
    static func monoM() -> Font { .system(size: cap(17, 26), weight: .semibold, design: .monospaced) }
    static func monoS() -> Font { .system(size: cap(13, 20), weight: .medium, design: .monospaced) }

    /// El mismo cálculo que `cappedDynamicSystem`, pero devolviendo el tamaño para poder pedir
    /// `design: .monospaced`, que la extensión de accesibilidad no expone.
    private static func cap(_ size: CGFloat, _ maxSize: CGFloat) -> CGFloat {
        min(UIFontMetrics.default.scaledValue(for: size), maxSize)
    }

    /// Alto de la fila de serie, que crece con el tipo pero no sin fin.
    static func rowHeight(_ base: CGFloat = 56) -> CGFloat {
        min(UIFontMetrics.default.scaledValue(for: base), base * 1.6)
    }

    /// Alto reservado para la cifra de una métrica. Sin él, tres cifras de anchos distintos se
    /// escalan de forma distinta y las etiquetas de debajo dejan de estar alineadas.
    static func metricValueHeight(large: Bool) -> CGFloat {
        large ? cap(40, 52) * 1.15 : cap(28, 38) * 1.15
    }
}

// MARK: - Tarjeta canónica

extension View {

    /// Tarjeta del módulo: superficie, radio 22 y borde visible en claro (plan §2.2).
    func trainingCard(theme: ThemeManager.AppTheme, padding: CGFloat = 16) -> some View {
        self
            .padding(padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.dynamicSurface(theme: theme))
            .clipShape(RoundedRectangle(cornerRadius: 22))
            .overlay(
                RoundedRectangle(cornerRadius: 22)
                    .stroke(Color.dynamicBorder(theme: theme).opacity(0.15), lineWidth: 1)
            )
    }

    /// Variante «esto todavía no existe»: mismo bloque con el borde discontinuo, como el hueco
    /// que sustituye (`CoachHomeView.swift:294`).
    func trainingDashedCard(theme: ThemeManager.AppTheme, padding: CGFloat = 16) -> some View {
        self
            .padding(padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.dynamicSurface(theme: theme))
            .clipShape(RoundedRectangle(cornerRadius: 22))
            .overlay(
                RoundedRectangle(cornerRadius: 22)
                    .stroke(
                        Color.dynamicBorder(theme: theme).opacity(0.15),
                        style: StrokeStyle(lineWidth: 1, dash: [4, 4])
                    )
            )
    }

    /// Objetivo táctil real de 44 pt sin agrandar el dibujo (checklist §10.6).
    func trainingTouchTarget(minWidth: CGFloat = 44, minHeight: CGFloat = 44) -> some View {
        frame(minWidth: minWidth, minHeight: minHeight)
            .contentShape(Rectangle())
    }
}

// MARK: - Piezas repetidas

/// Encabezado de sección: `THIS WEEK`, `BEST SETS`, `SHARE`…
struct TrainingEyebrow: View {
    let text: String
    var trailing: String?

    @EnvironmentObject var themeManager: ThemeManager

    private var theme: ThemeManager.AppTheme { themeManager.currentTheme }

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Text(text.uppercased())
                .font(TrainingType.label())
                .tracking(0.8)
                .foregroundColor(Color.dynamicTextTertiary(theme: theme))
                .lineLimit(1)
                .minimumScaleFactor(0.7)

            if let trailing {
                Spacer(minLength: 4)
                Text(trailing)
                    .font(TrainingType.caption())
                    .foregroundColor(Color.dynamicTextTertiary(theme: theme))
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityAddTraits(.isHeader)
    }
}

/// Una cifra grande con su etiqueta debajo, la unidad de composición de W8 y S18.
struct TrainingMetricView: View {
    let value: String
    let label: String
    /// Tamaño grande (S18) o mediano (W8).
    var large: Bool = false
    /// Lo que dice VoiceOver: «52 minutes 10 seconds, duration».
    var spoken: String?

    @EnvironmentObject var themeManager: ThemeManager

    private var theme: ThemeManager.AppTheme { themeManager.currentTheme }

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(value)
                .font(large ? TrainingType.monoXL() : TrainingType.monoL())
                .monospacedDigit()
                .foregroundColor(Color.dynamicText(theme: theme))
                .lineLimit(1)
                .minimumScaleFactor(0.5)
                .frame(height: TrainingType.metricValueHeight(large: large), alignment: .bottomLeading)

            Text(label)
                .font(TrainingType.label())
                .tracking(0.8)
                .foregroundColor(Color.dynamicTextTertiary(theme: theme))
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(spoken ?? "\(value), \(label)")
    }
}

/// Fila de reintento de una sección que no cargó. No ocupa la pantalla entera: la tarjeta de al
/// lado puede seguir teniendo datos buenos.
struct TrainingRetryRow: View {
    let message: String
    let retryTitle: String
    let onRetry: () -> Void

    @EnvironmentObject var themeManager: ThemeManager

    private var theme: ThemeManager.AppTheme { themeManager.currentTheme }

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "arrow.clockwise")
                .font(TrainingType.caption())
                .foregroundColor(Color.dynamicTextSecondary(theme: theme))

            Text(message)
                .font(TrainingType.caption())
                .foregroundColor(Color.dynamicTextSecondary(theme: theme))
                .fixedSize(horizontal: false, vertical: true)

            Spacer(minLength: 8)

            Button(action: onRetry) {
                Text(retryTitle)
                    .font(TrainingType.caption())
                    .fontWeight(.semibold)
                    .foregroundColor(Color.dynamicText(theme: theme))
                    .padding(.horizontal, 12)
                    .frame(minHeight: 44)
            }
            .buttonStyle(.plain)
            .overlay(
                Capsule().stroke(Color.dynamicBorder(theme: theme).opacity(0.4), lineWidth: 1)
            )
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

/// Rectángulo de carga. Se usa en vez de un spinner porque conserva la forma de lo que va a
/// llegar y no hace saltar el diseño (UX §4, estados de W4).
struct TrainingSkeletonBar: View {
    var width: CGFloat?
    var height: CGFloat = 12
    var cornerRadius: CGFloat = 6

    @EnvironmentObject var themeManager: ThemeManager

    var body: some View {
        RoundedRectangle(cornerRadius: cornerRadius)
            .fill(Color.dynamicSurface2(theme: themeManager.currentTheme))
            .frame(width: width, height: height)
            .accessibilityHidden(true)
    }
}

// MARK: - Formato de tiempo

enum TrainingFormat {

    /// «52:10» / «1:02:10». El reloj de una sesión, no el del cronómetro de descanso.
    static func duration(_ seconds: Int) -> String {
        let safe = max(0, seconds)
        let hours = safe / 3600
        let minutes = (safe % 3600) / 60
        let secs = safe % 60
        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, secs)
        }
        return String(format: "%d:%02d", minutes, secs)
    }

    /// «52 minutes 10 seconds», para VoiceOver.
    static func spokenDuration(_ seconds: Int) -> String {
        let safe = max(0, seconds)
        let minutes = safe / 60
        let secs = safe % 60
        var parts: [String] = []
        if minutes > 0 { parts.append("\(minutes) minute\(minutes == 1 ? "" : "s")") }
        if secs > 0 || parts.isEmpty { parts.append("\(secs) second\(secs == 1 ? "" : "s")") }
        return parts.joined(separator: " ")
    }

    /// «Tue, Sep 2»
    static func shortDate(_ date: Date) -> String {
        let formatter = DateFormatter.localized(template: "EEEdMMM")
        return formatter.string(from: date)
    }

    /// «Thursday, Sep 12»
    static func longDate(_ date: Date) -> String {
        let formatter = DateFormatter.localized(template: "EEEEMMMd")
        return formatter.string(from: date)
    }

    /// «Sep 2»
    static func dayMonth(_ date: Date) -> String {
        let formatter = DateFormatter.localized(template: "MMMd")
        return formatter.string(from: date)
    }

    /// «2h ago» / «just now». Sin exclamaciones y sin reproche.
    static func relative(_ date: Date, now: Date = Date()) -> String {
        let seconds = max(0, Int(now.timeIntervalSince(date)))
        if seconds < 60 { return "just now" }
        if seconds < 3600 { return "\(seconds / 60)m ago" }
        if seconds < 86400 { return "\(seconds / 3600)h ago" }
        return "\(seconds / 86400)d ago"
    }
}

// MARK: - Reduce Motion del módulo

/// Reduce Motion **efectivo**: el del sistema, o el forzado por la galería de revisión.
///
/// Existe por una razón muy concreta: `\.accessibilityReduceMotion` es de solo lectura, así que
/// no se puede simular desde un argumento de lanzamiento. El revisor necesita capturar la rama de
/// Reduce Motion sin tocar los ajustes del simulador (`-reduce-motion 1`), y las vistas necesitan
/// una sola fuente de verdad. Todas las del módulo leen esta.
private struct TrainingReduceMotionKey: EnvironmentKey {
    static let defaultValue = false
}

extension EnvironmentValues {
    var trainingReduceMotion: Bool {
        get { self[TrainingReduceMotionKey.self] }
        set { self[TrainingReduceMotionKey.self] = newValue }
    }
}

private struct TrainingMotionModifier: ViewModifier {
    @Environment(\.accessibilityReduceMotion) private var systemPreference
    let forced: Bool

    func body(content: Content) -> some View {
        content.environment(\.trainingReduceMotion, systemPreference || forced)
    }
}

extension View {
    /// Se aplica una vez, en la raíz de la app. El ajuste del sistema sigue mandando siempre: el
    /// argumento solo puede ENCENDER la rama reducida, nunca apagarla.
    func trainingMotionEnvironment(forced: Bool = false) -> some View {
        modifier(TrainingMotionModifier(forced: forced))
    }
}
