import UIKit

/// Centralized haptic feedback manager for consistent tactile responses across the app
final class HapticManager {
    static let shared = HapticManager()

    private init() {}

    /// Different haptic feedback patterns for various interactions
    enum HapticPattern {
        case success    // Al completar acciones exitosamente
        case warning    // Alertas suaves o precauciones
        case error      // Errores o acciones fallidas
        case light      // Taps normales y interacciones ligeras
        case medium     // Acciones importantes
        case heavy      // Confirmaciones críticas o acciones significativas
        case selection  // Cambios de selección en pickers/segmented controls
        case rigid      // Feedback rígido para límites alcanzados
        case soft       // Feedback suave para interacciones delicadas

        func generate() {
            switch self {
            case .success:
                let generator = UINotificationFeedbackGenerator()
                generator.prepare()
                generator.notificationOccurred(.success)

            case .warning:
                let generator = UINotificationFeedbackGenerator()
                generator.prepare()
                generator.notificationOccurred(.warning)

            case .error:
                let generator = UINotificationFeedbackGenerator()
                generator.prepare()
                generator.notificationOccurred(.error)

            case .light:
                let generator = UIImpactFeedbackGenerator(style: .light)
                generator.prepare()
                generator.impactOccurred()

            case .medium:
                let generator = UIImpactFeedbackGenerator(style: .medium)
                generator.prepare()
                generator.impactOccurred()

            case .heavy:
                let generator = UIImpactFeedbackGenerator(style: .heavy)
                generator.prepare()
                generator.impactOccurred()

            case .selection:
                let generator = UISelectionFeedbackGenerator()
                generator.prepare()
                generator.selectionChanged()

            case .rigid:
                let generator = UIImpactFeedbackGenerator(style: .rigid)
                generator.prepare()
                generator.impactOccurred()

            case .soft:
                let generator = UIImpactFeedbackGenerator(style: .soft)
                generator.prepare()
                generator.impactOccurred()
            }
        }
    }

    /// Generate a specific haptic pattern
    func play(_ pattern: HapticPattern) {
        pattern.generate()
    }

    /// Generate impact with custom intensity (0.0 - 1.0)
    func playImpact(intensity: CGFloat = 1.0) {
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.prepare()
        generator.impactOccurred(intensity: intensity)
    }

    /// Generate a sequence of haptic feedback with delays
    func playSequence(_ patterns: [(pattern: HapticPattern, delay: TimeInterval)]) {
        var currentDelay: TimeInterval = 0

        for item in patterns {
            DispatchQueue.main.asyncAfter(deadline: .now() + currentDelay) {
                item.pattern.generate()
            }
            currentDelay += item.delay
        }
    }

    /// Prepare multiple generators for upcoming haptic feedback
    /// Call this before showing views that will need haptic feedback
    func prepare() {
        UIImpactFeedbackGenerator(style: .light).prepare()
        UIImpactFeedbackGenerator(style: .medium).prepare()
        UISelectionFeedbackGenerator().prepare()
    }

    deinit {
        debugLog("🎮 HapticManager deinit")
    }
}

// MARK: - Convenience Methods

extension HapticManager {
    /// Play haptic for button tap
    func buttonTap() {
        play(.light)
    }

    /// Play haptic for toggle switch
    func toggleSwitch() {
        play(.selection)
    }

    /// Play haptic for achievement unlocked
    func achievementUnlocked() {
        playSequence([
            (.medium, 0),
            (.light, 0.1),
            (.success, 0.1)
        ])
    }

    /// Play haptic for goal completed with celebration
    func goalCompleted() {
        playSequence([
            (.heavy, 0),
            (.medium, 0.15),
            (.light, 0.15),
            (.success, 0.2)
        ])
    }

    /// Play haptic for streak milestone
    func streakMilestone() {
        playSequence([
            (.heavy, 0),
            (.medium, 0.1),
            (.medium, 0.1),
            (.success, 0.15)
        ])
    }

    /// Play haptic for pull-to-refresh trigger
    func refreshTriggered() {
        play(.medium)
    }

    /// Play haptic for swipe gesture detected
    func swipeDetected() {
        play(.selection)
    }

    /// Play haptic for long press detected
    func longPressDetected() {
        play(.medium)
    }

    /// Play haptic for boundary reached (e.g., scroll limit)
    func boundaryReached() {
        play(.rigid)
    }
}

// MARK: - SwiftUI View Extension

import SwiftUI

extension View {
    /// Add haptic feedback to a view
    func hapticFeedback(_ pattern: HapticManager.HapticPattern, trigger: some Equatable) -> some View {
        self.onChange(of: trigger) { _ in
            HapticManager.shared.play(pattern)
        }
    }
}
