//
//  MeasurementFormatting.swift
//  Gym_API
//
//  Unidades y formato numérico según el sitio donde está quien usa la app.
//
//  El backend guarda el peso SIEMPRE en kilos (app/models/health.py: "Peso en kg", y el
//  esquema valida 0 < weight <= 500). Esto no cambia. Lo único que cambia es lo que se
//  enseña y lo que se teclea: con el lanzamiento en Estados Unidos, quien se pesa piensa en
//  libras, y una app que le pide "75,0 kg" le está pidiendo que haga la cuenta él.
//
//  Dos cosas que se arreglan aquí de una vez:
//    - la conversión, en el borde de la interfaz y solo ahí
//    - el separador decimal, que hasta ahora se forzaba a coma a mano
//

import Foundation

// MARK: - Unidad de peso

enum WeightUnit {
    case kilograms
    case pounds

    private static let poundsPerKilogram = 2.204622621848776

    /// Lo que espera ver quien tiene el teléfono en la mano.
    /// Estados Unidos y Reino Unido pesan en libras; el resto, en kilos.
    static var preferred: WeightUnit {
        switch Locale.current.measurementSystem {
        case .us, .uk: return .pounds
        default: return .kilograms
        }
    }

    var symbol: String {
        switch self {
        case .kilograms: return "kg"
        case .pounds: return "lb"
        }
    }

    /// Paso del stepper. En libras se sube de 0,2 en 0,2 porque el escalón equivalente en
    /// kilos (0,1) son 0,22 lb: con 0,1 lb harían falta el doble de toques para el mismo cambio.
    var step: Double {
        switch self {
        case .kilograms: return 0.1
        case .pounds: return 0.2
        }
    }

    /// Rango editable en la unidad mostrada. El tope sale del límite del backend (500 kg).
    var editableRange: ClosedRange<Double> {
        switch self {
        case .kilograms: return 30...300
        case .pounds: return 66...660
        }
    }

    /// Punto de partida del CONTROL cuando no hay medición previa. **No es un dato**: nunca se
    /// debe guardar sin que la persona lo confirme. El nombre anterior, «peso por defecto»,
    /// invitaba justo a lo contrario, y así se escribieron 165 lb en un histórico real.
    var stepperStartValue: Double {
        switch self {
        case .kilograms: return 75
        case .pounds: return 165
        }
    }

    /// De lo que guarda el servidor a lo que se pinta.
    func fromKilograms(_ kilograms: Double) -> Double {
        switch self {
        case .kilograms: return kilograms
        case .pounds: return kilograms * Self.poundsPerKilogram
        }
    }

    /// De lo que teclea la persona a lo que se envía al servidor.
    func toKilograms(_ value: Double) -> Double {
        switch self {
        case .kilograms: return value
        case .pounds: return value / Self.poundsPerKilogram
        }
    }
}

// MARK: - Formato numérico

enum NumberFormat {

    /// Marcador para un valor que no se puede pintar (infinito o NaN).
    static let placeholder = "—"

    /// Decimal con el separador del sitio: 75.5 en Estados Unidos, 75,5 en España.
    /// Sustituye al viejo `String(format:)` seguido de cambiar el punto por una coma a mano,
    /// que dejaba comas a un público que escribe puntos.
    static func decimal(_ value: Double, digits: Int = 1) -> String {
        guard value.isFinite else { return placeholder }
        return String(format: "%.\(digits)f", locale: Locale.current, value)
    }

    /// Decimal con signo delante, para variaciones. El menos es el signo tipográfico (−),
    /// no el guion del teclado.
    static func signedDecimal(_ value: Double, digits: Int = 1) -> String {
        guard value.isFinite else { return placeholder }
        let sign = value > 0 ? "+" : "−"
        return sign + decimal(abs(value), digits: digits)
    }

    /// Quita los decimales cuando el número es redondo: 100 en vez de 100.0.
    static func trimmedDecimal(_ value: Double, maxDigits: Int = 1) -> String {
        guard value.isFinite else { return placeholder }
        let factor = pow(10.0, Double(maxDigits))
        let rounded = (value * factor).rounded() / factor
        return decimal(rounded, digits: rounded == rounded.rounded() ? 0 : maxDigits)
    }
}

// MARK: - Fechas

extension DateFormatter {

    /// Formateador con la plantilla adaptada al sitio: "EEE" da "Mon" o "lun",
    /// "jmm" da "6:30 PM" o "18:30" según corresponda.
    ///
    /// Antes había formatos fijos ("HH:mm") y un locale clavado a es_ES, que a un público
    /// estadounidense le enseña el reloj y los días equivocados.
    static func localized(template: String) -> DateFormatter {
        let formatter = DateFormatter()
        formatter.locale = Locale.current
        formatter.setLocalizedDateFormatFromTemplate(template)
        return formatter
    }
}

// MARK: - Unidad de altura

/// El servidor guarda la altura en centímetros (app/models/user.py: "altura en cm").
/// En Estados Unidos se piensa en pies y pulgadas, así que la conversión vive aquí igual
/// que la del peso.
enum HeightUnit {
    case centimeters
    case feetAndInches

    private static let centimetersPerInch = 2.54

    static var preferred: HeightUnit {
        switch Locale.current.measurementSystem {
        case .us, .uk: return .feetAndInches
        default: return .centimeters
        }
    }

    /// Valores seleccionables, en centímetros, que es lo que se guarda.
    /// En pies y pulgadas se recorre pulgada a pulgada, que es el escalón con el que se habla.
    var selectableCentimeters: [Int] {
        switch self {
        case .centimeters:
            return Array(100...220)
        case .feetAndInches:
            // De 3'3" a 7'2", el mismo tramo que el rango métrico.
            return (39...86).map { Int((Double($0) * Self.centimetersPerInch).rounded()) }
        }
    }

    /// Etiqueta de un valor guardado: "175 cm" o "5' 9\"".
    func label(centimeters: Int) -> String {
        switch self {
        case .centimeters:
            return "\(centimeters) cm"
        case .feetAndInches:
            let totalInches = Int((Double(centimeters) / Self.centimetersPerInch).rounded())
            return "\(totalInches / 12)' \(totalInches % 12)\""
        }
    }

    var sectionTitle: String {
        switch self {
        case .centimeters: return "Measurements"
        case .feetAndInches: return "Measurements"
        }
    }
}

// MARK: - Unidad de carga del módulo de entrenamiento

//  El check-in de peso corporal y el registro de una serie no se teclean igual. Uno sube de
//  0,1 kg en 0,1 kg porque la báscula lo permite; el otro sube de disco en disco: 5 lb o 2,5 kg
//  (plan §2.2). Por eso la carga tiene su propio paso y su propio formato, y no reutiliza los
//  de `WeightUnit.step`.

import TrainingCore

extension WeightUnit {

    /// Puente con `TrainingCore`, que tiene su propia unidad porque el paquete no puede ver la app.
    var trainingUnit: TrainingWeightUnit {
        switch self {
        case .kilograms: return .kilograms
        case .pounds: return .pounds
        }
    }

    init(training: TrainingWeightUnit) {
        switch training {
        case .kilograms: self = .kilograms
        case .pounds: self = .pounds
        }
    }

    /// Escalón de carga: 5 lb o 2,5 kg. Es lo que cabe en la barra, no lo que cabe en la pantalla.
    var loadStep: Double { trainingUnit.loadStep }

    /// De kilos guardados a la cifra que se teclea, ya cuadrada al escalón.
    /// 83,9 kg → 185 lb, no 184,9.
    func loadValue(kilograms: Double) -> Double {
        guard kilograms.isFinite else { return 0 }
        let converted = fromKilograms(kilograms)
        return (converted / loadStep).rounded() * loadStep
    }

    /// De lo que teclea la persona a los kilos que se envían al servidor.
    func kilograms(fromLoad value: Double) -> Double {
        toKilograms(value)
    }

    /// «185 lb» / «84 kg». Sin decimales cuando la cifra es redonda, que es casi siempre.
    func loadLabel(kilograms: Double) -> String {
        guard kilograms.isFinite else { return NumberFormat.placeholder }
        return "\(NumberFormat.trimmedDecimal(loadValue(kilograms: kilograms))) \(symbol)"
    }

    /// «12,480 lb»: el volumen de una sesión es un número grande y sin separador no se lee.
    func volumeLabel(kilograms: Double) -> String {
        guard kilograms.isFinite else { return NumberFormat.placeholder }
        let converted = fromKilograms(kilograms).rounded()
        return "\(NumberFormat.grouped(converted)) \(symbol)"
    }

    /// «+10 lb» / «−2,5 kg», para los deltas de una marca.
    func signedLoadLabel(kilograms: Double) -> String {
        guard kilograms.isFinite else { return NumberFormat.placeholder }
        let converted = loadValue(kilograms: kilograms)
        return "\(NumberFormat.signedDecimal(converted, digits: converted == converted.rounded() ? 0 : 1)) \(symbol)"
    }
}

extension NumberFormat {

    /// Entero con el separador de miles del sitio: 12,480 en Estados Unidos, 12.480 en España.
    static func grouped(_ value: Double) -> String {
        guard value.isFinite else { return placeholder }
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.locale = Locale.current
        formatter.maximumFractionDigits = 0
        return formatter.string(from: NSNumber(value: value)) ?? String(Int(value))
    }
}

// MARK: - Preferencia de unidad

/// Resuelve la unidad de peso UNA sola vez y la conserva.
///
/// Orden: lo que el usuario haya elegido en la app > `preferred_weight_unit` de su perfil >
/// el sistema de medida de su sitio. Recalcularlo en cada vista es la vía rápida a que media
/// pantalla diga libras y la otra media kilos.
enum WeightUnitPreference {

    private static let storageKey = "training.preferredWeightUnit"
    private static var cached: WeightUnit?

    /// La unidad que ve el usuario en toda la app.
    static var current: WeightUnit {
        if let cached { return cached }
        let resolved = stored ?? WeightUnit.preferred
        cached = resolved
        return resolved
    }

    /// Unidad guardada en el dispositivo, si el usuario la eligió alguna vez.
    static var stored: WeightUnit? {
        guard let raw = UserDefaults.standard.string(forKey: storageKey) else { return nil }
        return TrainingWeightUnit(rawValue: raw).map(WeightUnit.init(training:))
    }

    /// Incorpora la preferencia del perfil. Solo manda si el usuario no ha elegido ya en el
    /// dispositivo: lo que se toca en Ajustes gana a lo que dice el servidor.
    @discardableResult
    static func resolve(profileUnit: String?) -> WeightUnit {
        if let stored {
            cached = stored
            return stored
        }
        if let profileUnit, let unit = TrainingWeightUnit(rawValue: profileUnit) {
            let resolved = WeightUnit(training: unit)
            cached = resolved
            return resolved
        }
        return current
    }

    /// El usuario cambia la unidad en Ajustes. WP4 escribe además el perfil en el servidor.
    static func set(_ unit: WeightUnit) {
        cached = unit
        UserDefaults.standard.set(unit.trainingUnit.rawValue, forKey: storageKey)
        Task { @MainActor in
            Logger.shared.info("Unidad de peso: \(unit.symbol)", category: .training)
        }
    }

    /// Se llama al cerrar sesión: la unidad es de la persona, no del dispositivo.
    static func clear() {
        cached = nil
        UserDefaults.standard.removeObject(forKey: storageKey)
    }
}
