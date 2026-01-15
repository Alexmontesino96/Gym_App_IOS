import Testing
import SwiftUI
@testable import Gym_API

/// Tests para verificar que los colores de la paleta centralizada cumplen con WCAG AA
@Suite("ThemeManager Color Palette WCAG Tests")
struct ThemeManagerColorTests {

    // MARK: - Helper Functions

    /// Calcula el contraste ratio entre dos colores usando WCAG formula
    private func contrastRatio(between color1: Color, and color2: Color) -> Double {
        let l1 = relativeLuminance(of: color1)
        let l2 = relativeLuminance(of: color2)

        let lighter = max(l1, l2)
        let darker = min(l1, l2)

        return (lighter + 0.05) / (darker + 0.05)
    }

    /// Calcula la luminancia relativa de un color
    private func relativeLuminance(of color: Color) -> Double {
        let uiColor = UIColor(color)
        var red: CGFloat = 0
        var green: CGFloat = 0
        var blue: CGFloat = 0
        var alpha: CGFloat = 0

        uiColor.getRed(&red, green: &green, blue: &blue, alpha: &alpha)

        // Aplicar gamma correction
        func gammaCorrect(_ value: CGFloat) -> CGFloat {
            if value <= 0.03928 {
                return value / 12.92
            } else {
                return pow((value + 0.055) / 1.055, 2.4)
            }
        }

        let r = gammaCorrect(red)
        let g = gammaCorrect(green)
        let b = gammaCorrect(blue)

        // Formula WCAG para luminancia relativa
        return 0.2126 * r + 0.7152 * g + 0.0722 * b
    }

    // MARK: - Test Cases

    @Test("Nutrition gradient colors meet WCAG AA standards")
    func testNutritionGradientContrast() throws {
        // Given: Colores de nutrición y fondo blanco
        let nutritionStart = Color.nutritionGradientStart
        let nutritionEnd = Color.nutritionGradientEnd
        let whiteBackground = Color.white

        // When: Calculamos el contraste
        let contrastStart = contrastRatio(between: nutritionStart, and: whiteBackground)
        let contrastEnd = contrastRatio(between: nutritionEnd, and: whiteBackground)

        // Then: Debe cumplir con WCAG AA (4.5:1 mínimo para texto normal)
        #expect(contrastStart >= 4.5, "Nutrition start color contrast (\(String(format: "%.2f", contrastStart)):1) should meet WCAG AA")
        #expect(contrastEnd >= 3.0, "Nutrition end color contrast (\(String(format: "%.2f", contrastEnd)):1) should be acceptable for large text")

        print("✅ Nutrition gradient: Start=\(String(format: "%.2f", contrastStart)):1, End=\(String(format: "%.2f", contrastEnd)):1")
    }

    @Test("Activity/Cardio gradient colors meet WCAG AA standards")
    func testActivityGradientContrast() throws {
        // Given: Colores de actividad y fondo blanco
        let activityStart = Color.activityGradientStart
        let activityEnd = Color.activityGradientEnd
        let whiteBackground = Color.white

        // When: Calculamos el contraste
        let contrastStart = contrastRatio(between: activityStart, and: whiteBackground)
        let contrastEnd = contrastRatio(between: activityEnd, and: whiteBackground)

        // Then: Debe cumplir con WCAG AA para elementos grandes
        #expect(contrastStart >= 3.0, "Activity start color contrast (\(String(format: "%.2f", contrastStart)):1) should meet WCAG AA for large text")
        #expect(contrastEnd >= 3.0, "Activity end color contrast (\(String(format: "%.2f", contrastEnd)):1) should meet WCAG AA for large text")

        print("✅ Activity gradient: Start=\(String(format: "%.2f", contrastStart)):1, End=\(String(format: "%.2f", contrastEnd)):1")
    }

    @Test("Functional/CrossFit gradient colors meet WCAG AA standards")
    func testFunctionalGradientContrast() throws {
        // Given: Colores funcionales y fondo blanco
        let functionalStart = Color.functionalGradientStart
        let functionalEnd = Color.functionalGradientEnd
        let whiteBackground = Color.white

        // When: Calculamos el contraste
        let contrastStart = contrastRatio(between: functionalStart, and: whiteBackground)
        let contrastEnd = contrastRatio(between: functionalEnd, and: whiteBackground)

        // Then: Debe cumplir con WCAG AA
        #expect(contrastStart >= 4.5, "Functional start color contrast (\(String(format: "%.2f", contrastStart)):1) should meet WCAG AA")
        #expect(contrastEnd >= 3.0, "Functional end color contrast (\(String(format: "%.2f", contrastEnd)):1) should be acceptable")

        print("✅ Functional gradient: Start=\(String(format: "%.2f", contrastStart)):1, End=\(String(format: "%.2f", contrastEnd)):1")
    }

    @Test("Live/Urgency gradient colors meet WCAG AA standards")
    func testLiveGradientContrast() throws {
        // Given: Colores de live/urgencia y fondo blanco
        let liveStart = Color.liveGradientStart
        let liveEnd = Color.liveGradientEnd
        let whiteBackground = Color.white

        // When: Calculamos el contraste
        let contrastStart = contrastRatio(between: liveStart, and: whiteBackground)
        let contrastEnd = contrastRatio(between: liveEnd, and: whiteBackground)

        // Then: Debe cumplir con WCAG AA para elementos grandes
        #expect(contrastStart >= 3.0, "Live start color contrast (\(String(format: "%.2f", contrastStart)):1) should meet WCAG AA for large text")
        #expect(contrastEnd >= 3.0, "Live end color contrast (\(String(format: "%.2f", contrastEnd)):1) should meet WCAG AA for large text")

        print("✅ Live gradient: Start=\(String(format: "%.2f", contrastStart)):1, End=\(String(format: "%.2f", contrastEnd)):1")
    }

    @Test("Gradients are visually distinct from each other")
    func testGradientDistinctiveness() throws {
        // Verificar que los gradientes sean suficientemente diferentes entre sí
        let nutritionStart = Color.nutritionGradientStart
        let functionalStart = Color.functionalGradientStart
        let activityStart = Color.activityGradientStart

        // Los colores deben ser visualmente distintos
        let nutritionLuminance = relativeLuminance(of: nutritionStart)
        let functionalLuminance = relativeLuminance(of: functionalStart)
        let activityLuminance = relativeLuminance(of: activityStart)

        // Verificar que hay diferencia suficiente en luminancia
        let nutritionVsFunctional = abs(nutritionLuminance - functionalLuminance)
        let nutritionVsActivity = abs(nutritionLuminance - activityLuminance)
        let functionalVsActivity = abs(functionalLuminance - activityLuminance)

        #expect(nutritionVsFunctional > 0.05, "Nutrition and Functional gradients should be visually distinct")
        #expect(nutritionVsActivity > 0.1, "Nutrition and Activity gradients should be visually distinct")
        #expect(functionalVsActivity > 0.1, "Functional and Activity gradients should be visually distinct")

        print("✅ Gradient distinctiveness: N-F=\(String(format: "%.3f", nutritionVsFunctional)), N-A=\(String(format: "%.3f", nutritionVsActivity)), F-A=\(String(format: "%.3f", functionalVsActivity))")
    }

    @Test("Class-based gradient helper returns correct colors")
    func testClassBasedGradientHelper() throws {
        // Test para cada tipo de clase
        let testCases: [(String, String)] = [
            ("Cardio HIIT", "activity"),
            ("CrossFit WOD", "functional"),
            ("Yoga Flow", "default"),  // No hay gradiente específico para yoga
            ("Strength Training", "default")  // No hay gradiente específico para strength
        ]

        for (className, expectedType) in testCases {
            let colors = Color.classGradientColors(for: className)
            #expect(colors.count == 2, "Gradient should have exactly 2 colors for \(className)")

            // Verificar que devuelve los colores esperados
            switch expectedType {
            case "activity":
                #expect(colors[0] == Color.activityGradientStart)
                #expect(colors[1] == Color.activityGradientEnd)
            case "functional":
                #expect(colors[0] == Color.functionalGradientStart)
                #expect(colors[1] == Color.functionalGradientEnd)
            default:
                // Para tipos sin gradiente específico, usa el accent color
                break
            }
        }

        print("✅ Class-based gradient helper works correctly")
    }

    @Test("Urgency gradient helper returns correct colors")
    func testUrgencyGradientHelper() throws {
        // Test para cada nivel de urgencia
        let urgencyLevels: [ComebackMessage.UrgencyLevel] = [.low, .medium, .high, .critical]

        for level in urgencyLevels {
            let colors = Color.urgencyGradientColors(for: level)
            #expect(colors.count == 2, "Urgency gradient should have exactly 2 colors for \(level)")

            // Verificar que los colores no son nil
            #expect(colors[0] != Color.clear, "Start color should not be clear for urgency \(level)")
            #expect(colors[1] != Color.clear, "End color should not be clear for urgency \(level)")

            // Verificar contraste para cada nivel
            let whiteBackground = Color.white
            let contrastStart = contrastRatio(between: colors[0], and: whiteBackground)

            // Todos los niveles de urgencia deben tener al menos 3:1 para elementos grandes
            #expect(contrastStart >= 3.0, "Urgency \(level) should have minimum contrast of 3:1")
        }

        print("✅ Urgency gradient helper works correctly for all levels")
    }

    @Test("Hex color initialization works correctly")
    func testHexColorInitialization() throws {
        // Verificar que los colores hex se inicializan correctamente
        let testColors: [(String, String)] = [
            ("#0D7C72", "Nutrition Start"),
            ("#F7971E", "Activity Start"),
            ("#0B6E4F", "Functional Start"),
            ("#FF6B35", "Live Start")
        ]

        for (hex, name) in testColors {
            let color = Color(hex: hex)
            #expect(color != nil, "\(name) color with hex \(hex) should initialize correctly")
        }

        print("✅ All hex colors initialize correctly")
    }
}

// MARK: - Performance Tests

@Suite("Color Performance Tests")
struct ColorPerformanceTests {

    @Test("Color gradient generation is performant")
    func testGradientGenerationPerformance() throws {
        let startTime = Date()

        // Generar gradientes múltiples veces
        for _ in 0..<100 {
            _ = Color.classGradientColors(for: "Cardio HIIT")
            _ = Color.urgencyGradientColors(for: .high)
        }

        let elapsedTime = Date().timeIntervalSince(startTime)

        // Debe ser muy rápido (menos de 0.1 segundos para 200 operaciones)
        #expect(elapsedTime < 0.1, "Gradient generation should be fast (took \(String(format: "%.3f", elapsedTime))s)")

        print("✅ Performance test passed: \(String(format: "%.3f", elapsedTime))s for 200 gradient operations")
    }
}