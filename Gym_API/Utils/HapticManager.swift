import UIKit

/// Centralized haptic feedback manager for consistent tactile responses across the app
final class HapticManager {
    static let shared = HapticManager()

    /// Cache generators for better performance
    private let lightGenerator = UIImpactFeedbackGenerator(style: .light)
    private let mediumGenerator = UIImpactFeedbackGenerator(style: .medium)
    private let heavyGenerator = UIImpactFeedbackGenerator(style: .heavy)
    private let notificationGenerator = UINotificationFeedbackGenerator()
    private let selectionGenerator = UISelectionFeedbackGenerator()

    private init() {
        // Pre-prepare generators for instant feedback
        prepareGenerators()
    }

    /// Pre-prepare generators for reduced latency
    private func prepareGenerators() {
        lightGenerator.prepare()
        mediumGenerator.prepare()
        heavyGenerator.prepare()
        notificationGenerator.prepare()
        selectionGenerator.prepare()
    }

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
            // Skip haptic if reduced haptics should be used
            guard !HapticManager.shared.shouldUseReducedHaptics else { return }

            switch self {
            case .success:
                HapticManager.shared.notificationGenerator.notificationOccurred(.success)

            case .warning:
                HapticManager.shared.notificationGenerator.notificationOccurred(.warning)

            case .error:
                HapticManager.shared.notificationGenerator.notificationOccurred(.error)

            case .light:
                HapticManager.shared.lightGenerator.impactOccurred()

            case .medium:
                HapticManager.shared.mediumGenerator.impactOccurred()

            case .heavy:
                HapticManager.shared.heavyGenerator.impactOccurred()

            case .selection:
                HapticManager.shared.selectionGenerator.selectionChanged()

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

    // MARK: - Degradation Support

    /// Determine if haptics should be reduced based on system state
    var shouldUseReducedHaptics: Bool {
        // Check accessibility setting
        if UIAccessibility.isReduceMotionEnabled {
            return true
        }

        // Check device battery level
        UIDevice.current.isBatteryMonitoringEnabled = true
        let batteryLevel = UIDevice.current.batteryLevel
        let batteryState = UIDevice.current.batteryState

        // Reduce haptics if battery is low (below 20%) and not charging
        if batteryLevel > 0 && batteryLevel < 0.2 && batteryState != .charging {
            return true
        }

        // Check thermal state (reduce haptics if device is hot)
        if ProcessInfo.processInfo.thermalState == .critical ||
           ProcessInfo.processInfo.thermalState == .serious {
            return true
        }

        return false
    }

    /// Generate a specific haptic pattern
    func play(_ pattern: HapticPattern) {
        pattern.generate()
    }

    /// Generate impact with custom intensity (0.0 - 1.0)
    func playImpact(intensity: CGFloat = 1.0) {
        guard !shouldUseReducedHaptics else { return }
        mediumGenerator.impactOccurred(intensity: intensity)
    }

    /// Generate a sequence of haptic feedback with delays
    func playSequence(_ patterns: [(pattern: HapticPattern, delay: TimeInterval)]) {
        guard !shouldUseReducedHaptics else {
            // In reduced mode, only play the final success haptic
            if let lastItem = patterns.last, lastItem.pattern == .success {
                lastItem.pattern.generate()
            }
            return
        }

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
        prepareGenerators()
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

    // MARK: - Optimized Class Registration Haptics

    /// Optimized haptic sequence for successful class registration
    /// Synchronized with Liquid Morph animation phases
    func classRegistrationSuccess() {
        // Reduced delays for more responsive feedback
        // Pattern matches the visual morphing animation
        playSequence([
            (.light, 0),      // Initial tap feedback
            (.medium, 0.10),  // Morph phase complete (reduced from 0.15)
            (.success, 0.25)  // Final confirmation (reduced from 0.3)
        ])
    }

    /// Enhanced elastic bounce pattern for class registration
    /// Provides tactile feedback that matches the visual bounce animation
    func elasticBounce() {
        guard !shouldUseReducedHaptics else {
            // In reduced mode, play single success haptic
            play(.success)
            return
        }

        // Pre-prepare for instant feedback
        mediumGenerator.prepare()

        // Phase 1: Initial compression (matching visual squash)
        playImpact(intensity: 0.6)

        // Phase 2: Primary bounce (matching visual stretch)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.10) { [weak self] in
            self?.playImpact(intensity: 0.9)
        }

        // Phase 3: Secondary bounce (elastic rebound)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.20) { [weak self] in
            self?.playImpact(intensity: 0.4)
        }

        // Phase 4: Settle (final micro-bounce)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.28) { [weak self] in
            self?.playImpact(intensity: 0.2)
        }
    }

    /// Play haptic for achievement unlocked
    func achievementUnlocked() {
        playSequence([
            (.medium, 0),
            (.light, 0.08),   // Reduced from 0.1
            (.success, 0.08)  // Reduced from 0.1
        ])
    }

    /// Play haptic for goal completed with celebration
    func goalCompleted() {
        playSequence([
            (.heavy, 0),
            (.medium, 0.12),  // Reduced from 0.15
            (.light, 0.12),   // Reduced from 0.15
            (.success, 0.16)  // Reduced from 0.2
        ])
    }

    /// Play haptic for streak milestone
    func streakMilestone() {
        playSequence([
            (.heavy, 0),
            (.medium, 0.08),  // Reduced from 0.1
            (.medium, 0.08),  // Reduced from 0.1
            (.success, 0.12)  // Reduced from 0.15
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
        self.onChange(of: trigger) { _, _ in
            HapticManager.shared.play(pattern)
        }
    }
}
