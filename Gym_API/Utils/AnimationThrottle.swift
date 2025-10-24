//
//  AnimationThrottle.swift
//  Gym_API
//
//  Sistema para limitar y controlar animaciones simultáneas
//  Created as part of performance optimization phase
//

import SwiftUI
import Combine

// MARK: - Animation Priority
enum AnimationPriority: Int, Comparable {
    case low = 0
    case medium = 1
    case high = 2
    case critical = 3

    static func < (lhs: AnimationPriority, rhs: AnimationPriority) -> Bool {
        return lhs.rawValue < rhs.rawValue
    }
}

// MARK: - Animation Request
struct AnimationRequest: Identifiable {
    let id = UUID()
    let priority: AnimationPriority
    let duration: TimeInterval
    let animation: Animation
    let execute: () -> Void
    let completion: (() -> Void)?
    let timestamp = Date()
}

// MARK: - Animation Throttle Manager
@MainActor
class AnimationThrottleManager: ObservableObject {

    // MARK: - Singleton
    static let shared = AnimationThrottleManager()

    // MARK: - Configuration
    struct Configuration {
        var maxSimultaneousAnimations: Int = 3
        var queueTimeout: TimeInterval = 5.0
        var enableThrottling: Bool = true
        var enablePerformanceMode: Bool = false // Reduces all animations
        var enableDebugMode: Bool = false
    }

    // MARK: - Published Properties
    @Published var activeAnimationsCount: Int = 0
    @Published var queuedAnimationsCount: Int = 0
    @Published var isPerformanceModeActive: Bool = false
    @Published var totalAnimationsExecuted: Int = 0
    @Published var totalAnimationsDropped: Int = 0

    // MARK: - Private Properties
    private var configuration = Configuration()
    private var activeAnimations: Set<UUID> = []
    private var animationQueue: [AnimationRequest] = []
    private var cancellables = Set<AnyCancellable>()
    private let animationSubject = PassthroughSubject<AnimationRequest, Never>()

    // Performance monitoring
    private var frameRateMonitor: CADisplayLink?
    private var lastFrameTime: CFTimeInterval = 0
    private var currentFPS: Double = 60

    private init() {
        setupAnimationProcessor()
        setupPerformanceMonitoring()

        Logger.shared.info("AnimationThrottleManager initialized", category: .performance)
    }

    // MARK: - Configuration
    func configure(_ configuration: Configuration) {
        self.configuration = configuration
        isPerformanceModeActive = configuration.enablePerformanceMode

        Logger.shared.debug("Animation throttle configured", category: .performance, metadata: [
            "maxSimultaneous": "\(configuration.maxSimultaneousAnimations)",
            "performanceMode": "\(configuration.enablePerformanceMode)"
        ])
    }

    // MARK: - Main Animation Interface
    func animate(
        priority: AnimationPriority = .medium,
        duration: TimeInterval = 0.3,
        animation: Animation = .default,
        execute: @escaping () -> Void,
        completion: (() -> Void)? = nil
    ) {
        // Check if throttling is enabled
        guard configuration.enableThrottling else {
            // Execute immediately without throttling
            withAnimation(animation) {
                execute()
            }
            completion?()
            return
        }

        // In performance mode, skip low priority animations
        if configuration.enablePerformanceMode && priority == .low {
            totalAnimationsDropped += 1
            if configuration.enableDebugMode {
                Logger.shared.debug("Low priority animation dropped (performance mode)", category: .performance)
            }
            return
        }

        // Create animation request
        let request = AnimationRequest(
            priority: priority,
            duration: duration,
            animation: animation,
            execute: execute,
            completion: completion
        )

        // Check if can execute immediately
        if canExecuteNow() || priority == .critical {
            executeAnimation(request)
        } else {
            queueAnimation(request)
        }
    }

    // MARK: - Queue Management
    private func canExecuteNow() -> Bool {
        return activeAnimations.count < configuration.maxSimultaneousAnimations
    }

    private func queueAnimation(_ request: AnimationRequest) {
        // Add to queue sorted by priority
        animationQueue.append(request)
        animationQueue.sort { $0.priority > $1.priority }

        // Limit queue size
        if animationQueue.count > 20 {
            // Drop oldest low priority animations
            animationQueue = Array(animationQueue.prefix(20))
            totalAnimationsDropped += 1
        }

        queuedAnimationsCount = animationQueue.count

        if configuration.enableDebugMode {
            Logger.shared.debug("Animation queued", category: .performance, metadata: [
                "priority": "\(request.priority)",
                "queueSize": "\(animationQueue.count)"
            ])
        }

        // Try to process queue
        processQueue()
    }

    private func executeAnimation(_ request: AnimationRequest) {
        activeAnimations.insert(request.id)
        activeAnimationsCount = activeAnimations.count
        totalAnimationsExecuted += 1

        // Apply animation
        let animation = adjustAnimationForPerformance(request.animation)

        withAnimation(animation) {
            request.execute()
        }

        // Schedule cleanup after animation duration
        DispatchQueue.main.asyncAfter(deadline: .now() + request.duration) { [weak self] in
            self?.completeAnimation(request)
        }

        if configuration.enableDebugMode {
            Logger.shared.debug("Animation executing", category: .performance, metadata: [
                "id": "\(request.id)",
                "priority": "\(request.priority)",
                "activeCount": "\(activeAnimationsCount)"
            ])
        }
    }

    private func completeAnimation(_ request: AnimationRequest) {
        activeAnimations.remove(request.id)
        activeAnimationsCount = activeAnimations.count

        request.completion?()

        // Process next in queue
        processQueue()
    }

    private func processQueue() {
        while canExecuteNow() && !animationQueue.isEmpty {
            let request = animationQueue.removeFirst()
            queuedAnimationsCount = animationQueue.count

            // Check if request is still valid (not timed out)
            if Date().timeIntervalSince(request.timestamp) < configuration.queueTimeout {
                executeAnimation(request)
            } else {
                totalAnimationsDropped += 1
                if configuration.enableDebugMode {
                    Logger.shared.debug("Animation timed out in queue", category: .performance)
                }
            }
        }
    }

    // MARK: - Performance Adjustments
    private func adjustAnimationForPerformance(_ animation: Animation) -> Animation {
        if configuration.enablePerformanceMode {
            // Reduce animation duration and remove spring effects
            return .linear(duration: 0.2)
        }

        // Adjust based on current FPS
        if currentFPS < 30 {
            // Very poor performance - use minimal animation
            return .linear(duration: 0.1)
        } else if currentFPS < 50 {
            // Poor performance - reduce animation
            return animation.speed(1.5)
        }

        return animation
    }

    // MARK: - Performance Monitoring
    private func setupAnimationProcessor() {
        animationSubject
            .throttle(for: .milliseconds(16), scheduler: DispatchQueue.main, latest: true) // 60 FPS
            .sink { [weak self] request in
                self?.executeAnimation(request)
            }
            .store(in: &cancellables)
    }

    private func setupPerformanceMonitoring() {
        frameRateMonitor = CADisplayLink(target: self, selector: #selector(updateFrameRate))
        frameRateMonitor?.add(to: .main, forMode: .common)
    }

    @objc private func updateFrameRate(displayLink: CADisplayLink) {
        if lastFrameTime == 0 {
            lastFrameTime = displayLink.timestamp
            return
        }

        let delta = displayLink.timestamp - lastFrameTime
        lastFrameTime = displayLink.timestamp

        currentFPS = 1.0 / delta

        // Auto-enable performance mode if FPS drops
        if currentFPS < 25 && !configuration.enablePerformanceMode {
            enablePerformanceMode(true)
            Logger.shared.warning("Low FPS detected (\(Int(currentFPS))), enabling performance mode", category: .performance)
        }
    }

    // MARK: - Public Control Methods
    func enablePerformanceMode(_ enable: Bool) {
        configuration.enablePerformanceMode = enable
        isPerformanceModeActive = enable

        if enable {
            // Clear low priority animations from queue
            animationQueue = animationQueue.filter { $0.priority >= .medium }
            queuedAnimationsCount = animationQueue.count
        }

        Logger.shared.info("Performance mode \(enable ? "enabled" : "disabled")", category: .performance)
    }

    func clearAnimationQueue() {
        let dropped = animationQueue.count
        animationQueue.removeAll()
        queuedAnimationsCount = 0
        totalAnimationsDropped += dropped

        Logger.shared.debug("\(dropped) animations cleared from queue", category: .performance)
    }

    func pauseAllAnimations() {
        configuration.enableThrottling = false
        clearAnimationQueue()
    }

    func resumeAnimations() {
        configuration.enableThrottling = true
    }

    // MARK: - Statistics
    var statistics: AnimationStatistics {
        AnimationStatistics(
            activeAnimations: activeAnimationsCount,
            queuedAnimations: queuedAnimationsCount,
            totalExecuted: totalAnimationsExecuted,
            totalDropped: totalAnimationsDropped,
            currentFPS: currentFPS,
            performanceMode: isPerformanceModeActive
        )
    }

    deinit {
        frameRateMonitor?.invalidate()
        // No podemos llamar a Logger desde deinit en una clase @MainActor
        #if DEBUG
        print("🗑️ AnimationThrottleManager deinitialized")
        #endif
    }
}

// MARK: - Animation Statistics
struct AnimationStatistics {
    let activeAnimations: Int
    let queuedAnimations: Int
    let totalExecuted: Int
    let totalDropped: Int
    let currentFPS: Double
    let performanceMode: Bool

    var dropRate: Double {
        let total = totalExecuted + totalDropped
        return total > 0 ? Double(totalDropped) / Double(total) : 0
    }

    var summary: String {
        """
        📊 Animation Statistics:
        Active: \(activeAnimations)
        Queued: \(queuedAnimations)
        Total Executed: \(totalExecuted)
        Total Dropped: \(totalDropped) (\(String(format: "%.1f%%", dropRate * 100)))
        Current FPS: \(String(format: "%.0f", currentFPS))
        Performance Mode: \(performanceMode ? "ON" : "OFF")
        """
    }
}

// MARK: - View Modifiers
struct ThrottledAnimationModifier: ViewModifier {
    let priority: AnimationPriority
    let duration: TimeInterval

    func body(content: Content) -> some View {
        content
            .transaction { transaction in
                if transaction.animation != nil {
                    // Replace with throttled animation
                    transaction.animation = nil
                    AnimationThrottleManager.shared.animate(
                        priority: priority,
                        duration: duration,
                        animation: .default,
                        execute: {}
                    )
                }
            }
    }
}

extension View {
    /// Apply throttled animation to view
    func throttledAnimation(
        priority: AnimationPriority = .medium,
        duration: TimeInterval = 0.3
    ) -> some View {
        modifier(ThrottledAnimationModifier(priority: priority, duration: duration))
    }

    /// Conditionally disable animations in performance mode
    func performanceSafeAnimation(_ animation: Animation? = .default) -> some View {
        self.animation(
            AnimationThrottleManager.shared.isPerformanceModeActive ? nil : animation
        )
    }
}

// MARK: - Convenience Functions
@MainActor
func withThrottledAnimation<Result>(
    priority: AnimationPriority = .medium,
    animation: Animation = .default,
    _ body: @escaping () throws -> Result,
    completion: @escaping (Result?, Error?) -> Void
) {
    if AnimationThrottleManager.shared.isPerformanceModeActive && priority == .low {
        // Skip animation in performance mode for low priority
        do {
            let result = try body()
            completion(result, nil)
        } catch {
            completion(nil, error)
        }
        return
    }

    AnimationThrottleManager.shared.animate(
        priority: priority,
        animation: animation,
        execute: {
            do {
                let result = try body()
                completion(result, nil)
            } catch {
                completion(nil, error)
            }
        }
    )
}

// MARK: - Batch Animation Support
struct BatchAnimationContext {
    private var animations: [() -> Void] = []
    private let priority: AnimationPriority
    private let animation: Animation

    init(priority: AnimationPriority = .medium, animation: Animation = .default) {
        self.priority = priority
        self.animation = animation
    }

    mutating func add(_ animation: @escaping () -> Void) {
        animations.append(animation)
    }

    @MainActor
    func execute() {
        AnimationThrottleManager.shared.animate(
            priority: priority,
            animation: animation,
            execute: {
                animations.forEach { $0() }
            }
        )
    }
}

// MARK: - Animation Presets
extension Animation {
    @MainActor
    static var throttledDefault: Animation {
        AnimationThrottleManager.shared.isPerformanceModeActive
            ? .linear(duration: 0.2)
            : .default
    }

    @MainActor
    static var throttledSpring: Animation {
        AnimationThrottleManager.shared.isPerformanceModeActive
            ? .linear(duration: 0.2)
            : .spring()
    }

    @MainActor
    static func throttledEaseInOut(duration: Double = 0.3) -> Animation {
        AnimationThrottleManager.shared.isPerformanceModeActive
            ? .linear(duration: min(duration, 0.2))
            : .easeInOut(duration: duration)
    }
}