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
