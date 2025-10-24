//
//  NetworkRetryManager.swift
//  Gym_API
//
//  Sistema de retry logic con exponential backoff y políticas configurables
//  Created as part of error handling optimization phase
//

import Foundation
import Combine

// MARK: - Retry Policy
struct RetryPolicy {
    /// Maximum number of retry attempts
    let maxAttempts: Int

    /// Initial delay before first retry
    let initialDelay: TimeInterval

    /// Maximum delay between retries
    let maxDelay: TimeInterval

    /// Factor to multiply delay by after each attempt
    let backoffMultiplier: Double

    /// Add randomness to delays to prevent thundering herd
    let jitterFactor: Double

    /// Conditions that should trigger a retry
    let retryableConditions: Set<RetryCondition>

    /// Whether to use exponential backoff
    let useExponentialBackoff: Bool

    /// Timeout for each attempt
    let attemptTimeout: TimeInterval?

    // Predefined policies
    static let standard = RetryPolicy(
        maxAttempts: 3,
        initialDelay: 1.0,
        maxDelay: 30.0,
        backoffMultiplier: 2.0,
        jitterFactor: 0.2,
        retryableConditions: [.networkError, .serverError, .timeout],
        useExponentialBackoff: true,
        attemptTimeout: 30.0
    )

    static let aggressive = RetryPolicy(
        maxAttempts: 5,
        initialDelay: 0.5,
        maxDelay: 60.0,
        backoffMultiplier: 1.5,
        jitterFactor: 0.1,
        retryableConditions: [.networkError, .serverError, .timeout, .rateLimited],
        useExponentialBackoff: true,
        attemptTimeout: 45.0
    )

    static let conservative = RetryPolicy(
        maxAttempts: 2,
        initialDelay: 2.0,
        maxDelay: 10.0,
        backoffMultiplier: 2.0,
        jitterFactor: 0.3,
        retryableConditions: [.networkError, .serverError],
        useExponentialBackoff: false,
        attemptTimeout: 20.0
    )

    static let noRetry = RetryPolicy(
        maxAttempts: 1,
        initialDelay: 0,
        maxDelay: 0,
        backoffMultiplier: 1.0,
        jitterFactor: 0,
        retryableConditions: [],
        useExponentialBackoff: false,
        attemptTimeout: 30.0
    )
}

// MARK: - Retry Condition
enum RetryCondition: Hashable {
    case networkError
    case serverError  // 5xx errors
    case timeout
    case rateLimited  // 429 error
    case specificStatusCodes(Set<Int>)
    case custom(String) // Changed to String identifier for Hashable conformance

    static func == (lhs: RetryCondition, rhs: RetryCondition) -> Bool {
        switch (lhs, rhs) {
        case (.networkError, .networkError),
             (.serverError, .serverError),
             (.timeout, .timeout),
             (.rateLimited, .rateLimited):
            return true
        case (.specificStatusCodes(let codes1), .specificStatusCodes(let codes2)):
            return codes1 == codes2
        case (.custom(let id1), .custom(let id2)):
            return id1 == id2
        default:
            return false
        }
    }

    func hash(into hasher: inout Hasher) {
        switch self {
        case .networkError:
            hasher.combine(0)
        case .serverError:
            hasher.combine(1)
        case .timeout:
            hasher.combine(2)
        case .rateLimited:
            hasher.combine(3)
        case .specificStatusCodes(let codes):
            hasher.combine(4)
            hasher.combine(codes)
        case .custom(let id):
            hasher.combine(5)
            hasher.combine(id)
        }
    }
}

// MARK: - Retry Result
enum RetryResult<Success> {
    case success(Success)
    case failure(Error, attempts: Int)
}

// MARK: - Retry State
struct RetryState {
    let attempt: Int
    let totalAttempts: Int
    let nextDelay: TimeInterval?
    let lastError: Error?

    var progress: Double {
        Double(attempt) / Double(totalAttempts)
    }
}

// MARK: - Network Retry Manager
@MainActor
class NetworkRetryManager: ObservableObject {

    // MARK: - Singleton
    static let shared = NetworkRetryManager()

    // MARK: - Published Properties
    @Published var activeRetries: [UUID: RetryState] = [:]
    @Published var totalRetryCount: Int = 0
    @Published var successfulRetries: Int = 0
    @Published var failedRetries: Int = 0

    // MARK: - Private Properties
    private var cancellables = Set<AnyCancellable>()
    private let retryQueue = DispatchQueue(label: "com.gymapi.retry", qos: .userInitiated)

    private init() {
        #if DEBUG
        print("✅ NetworkRetryManager initialized")
        #endif
    }

    // MARK: - Main Retry Function
    func retry<T>(
        operation: @escaping () async throws -> T,
        policy: RetryPolicy = .standard,
        context: String? = nil
    ) async throws -> T {
        let operationId = UUID()
        var lastError: Error?
        var attempt = 0

        #if DEBUG
        print("🔄 Starting retry operation - context: \(context ?? "Unknown"), maxAttempts: \(policy.maxAttempts)")
        #endif

        while attempt < policy.maxAttempts {
            attempt += 1

            // Update state
            await updateRetryState(
                id: operationId,
                state: RetryState(
                    attempt: attempt,
                    totalAttempts: policy.maxAttempts,
                    nextDelay: calculateDelay(attempt: attempt, policy: policy),
                    lastError: lastError
                )
            )

            do {
                // Execute operation with timeout if specified
                let result: T
                if let timeout = policy.attemptTimeout {
                    result = try await withTimeout(seconds: timeout) {
                        try await operation()
                    }
                } else {
                    result = try await operation()
                }

                // Success!
                await handleSuccess(operationId: operationId, attempts: attempt, context: context)
                return result

            } catch {
                lastError = error

                // Check if we should retry
                let shouldRetry = shouldRetry(error: error, policy: policy, attempt: attempt)

                #if DEBUG
                print("⚠️ Operation failed - attempt: \(attempt)/\(policy.maxAttempts), willRetry: \(shouldRetry)")
                #endif

                if !shouldRetry {
                    // Simplify for compiler
                    let currentAttempts = attempt
                    let currentContext = context
                    await handleFailure(
                        operationId: operationId,
                        error: error,
                        attempts: currentAttempts,
                        context: currentContext
                    )
                    throw error
                }

                // Calculate and apply delay
                if attempt < policy.maxAttempts {
                    let delay = calculateDelay(attempt: attempt, policy: policy)
                    #if DEBUG
                    print("⏱️ Waiting \(delay) seconds before retry")
                    #endif
                    try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                }
            }
        }

        // Max attempts reached
        let finalError = lastError ?? NetworkError.timeout(policy.attemptTimeout ?? 30)
        // Simplify for compiler
        let finalAttempts = attempt
        let finalContext = context
        await handleFailure(
            operationId: operationId,
            error: finalError,
            attempts: finalAttempts,
            context: finalContext
        )
        throw finalError
    }

    // MARK: - Combine Support
    func retryPublisher<T>(
        publisher: AnyPublisher<T, Error>,
        policy: RetryPolicy = .standard,
        context: String? = nil
    ) -> AnyPublisher<T, Error> {
        publisher
            .tryCatch { [weak self] error -> AnyPublisher<T, Error> in
                guard let self = self,
                      self.shouldRetry(error: error, policy: policy, attempt: 1) else {
                    throw error
                }

                return publisher
                    .retry(policy.maxAttempts - 1)
                    .delay(for: .seconds(policy.initialDelay), scheduler: RunLoop.main)
                    .eraseToAnyPublisher()
            }
            .handleEvents(
                receiveCompletion: { [weak self] completion in
                    Task { @MainActor in
                        if case .failure(let error) = completion {
                            self?.failedRetries += 1
                            #if DEBUG
                            print("❌ Retry publisher failed: \(error.localizedDescription)")
                            #endif
                        }
                    }
                }
            )
            .eraseToAnyPublisher()
    }

    // MARK: - URLSession Extension Support
    func retryableDataTask(
        with request: URLRequest,
        policy: RetryPolicy = .standard,
        context: String? = nil
    ) async throws -> (Data, URLResponse) {
        return try await retry(
            operation: {
                try await URLSession.shared.data(for: request)
            },
            policy: policy,
            context: context
        )
    }

    // MARK: - Helper Methods
    private func shouldRetry(error: Error, policy: RetryPolicy, attempt: Int) -> Bool {
        // Check max attempts
        guard attempt < policy.maxAttempts else {
            return false
        }

        // Check if error is retryable
        for condition in policy.retryableConditions {
            if isRetryable(error: error, condition: condition) {
                return true
            }
        }

        return false
    }

    private func isRetryable(error: Error, condition: RetryCondition) -> Bool {
        switch condition {
        case .networkError:
            if error is URLError {
                return true
            }
            if let networkError = error as? NetworkError {
                return networkError.isRecoverable
            }
            return false

        case .serverError:
            if let networkError = error as? NetworkError,
               case .httpError(let statusCode, _) = networkError {
                return statusCode >= 500 && statusCode < 600
            }
            return false

        case .timeout:
            if let urlError = error as? URLError {
                return urlError.code == .timedOut
            }
            if let networkError = error as? NetworkError,
               case .timeout = networkError {
                return true
            }
            return false

        case .rateLimited:
            if let networkError = error as? NetworkError,
               case .httpError(let statusCode, _) = networkError {
                return statusCode == 429
            }
            if case NetworkError.rateLimited = error {
                return true
            }
            return false

        case .specificStatusCodes(let codes):
            if let networkError = error as? NetworkError,
               case .httpError(let statusCode, _) = networkError {
                return codes.contains(statusCode)
            }
            return false

        case .custom:
            // Custom conditions need to be implemented separately
            return false
        }
    }

    private func calculateDelay(attempt: Int, policy: RetryPolicy) -> TimeInterval {
        let baseDelay: TimeInterval

        if policy.useExponentialBackoff {
            // Exponential backoff: delay = initialDelay * (multiplier ^ (attempt - 1))
            baseDelay = policy.initialDelay * pow(policy.backoffMultiplier, Double(attempt - 1))
        } else {
            // Linear backoff
            baseDelay = policy.initialDelay * Double(attempt)
        }

        // Apply max delay cap
        let cappedDelay = min(baseDelay, policy.maxDelay)

        // Add jitter to prevent thundering herd
        let jitter = cappedDelay * policy.jitterFactor * Double.random(in: -1...1)
        let finalDelay = max(0, cappedDelay + jitter)

        return finalDelay
    }

    private func withTimeout<T>(
        seconds: TimeInterval,
        operation: @escaping () async throws -> T
    ) async throws -> T {
        try await withThrowingTaskGroup(of: T.self) { group in
            group.addTask {
                try await operation()
            }

            group.addTask {
                try await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
                throw NetworkError.timeout(seconds)
            }

            let result = try await group.next()!
            group.cancelAll()
            return result
        }
    }

    // MARK: - State Management
    private func updateRetryState(id: UUID, state: RetryState) {
        activeRetries[id] = state
    }

    private func handleSuccess(operationId: UUID, attempts: Int, context: String?) {
        activeRetries.removeValue(forKey: operationId)
        successfulRetries += 1
        totalRetryCount += 1

        Task { @MainActor in
            Logger.shared.info("Retry operation succeeded", category: .network, metadata: [
                "context": context ?? "Unknown",
                "attempts": "\(attempts)"
            ])
        }
    }

    private func handleFailure(operationId: UUID, error: Error, attempts: Int, context: String?) {
        activeRetries.removeValue(forKey: operationId)
        failedRetries += 1
        totalRetryCount += 1

        Task { @MainActor in
            Logger.shared.error("Retry operation failed after \(attempts) attempts", category: .network, metadata: [
                "context": context ?? "Unknown",
                "error": error.localizedDescription
            ])
        }
    }

    // MARK: - Statistics
    var statistics: RetryStatistics {
        RetryStatistics(
            activeRetries: activeRetries.count,
            totalAttempts: totalRetryCount,
            successfulRetries: successfulRetries,
            failedRetries: failedRetries,
            successRate: totalRetryCount > 0 ? Double(successfulRetries) / Double(totalRetryCount) : 0
        )
    }

    func resetStatistics() {
        totalRetryCount = 0
        successfulRetries = 0
        failedRetries = 0
        #if DEBUG
        print("📊 Retry statistics reset")
        #endif
    }

    deinit {
        #if DEBUG
        print("🗑️ NetworkRetryManager deinitialized")
        #endif
    }
}

// MARK: - Retry Statistics
struct RetryStatistics {
    let activeRetries: Int
    let totalAttempts: Int
    let successfulRetries: Int
    let failedRetries: Int
    let successRate: Double

    var formattedSuccessRate: String {
        "\(Int(successRate * 100))%"
    }

    var summary: String {
        """
        📊 Retry Statistics:
        Active Retries: \(activeRetries)
        Total Attempts: \(totalAttempts)
        Successful: \(successfulRetries)
        Failed: \(failedRetries)
        Success Rate: \(formattedSuccessRate)
        """
    }
}

// MARK: - URLSession Extension
extension URLSession {
    func dataWithRetry(
        for request: URLRequest,
        policy: RetryPolicy = .standard,
        context: String? = nil
    ) async throws -> (Data, URLResponse) {
        return try await NetworkRetryManager.shared.retryableDataTask(
            with: request,
            policy: policy,
            context: context
        )
    }
}

// MARK: - Convenience Functions
func withRetry<T>(
    policy: RetryPolicy = .standard,
    context: String? = nil,
    operation: @escaping () async throws -> T
) async throws -> T {
    return try await NetworkRetryManager.shared.retry(
        operation: operation,
        policy: policy,
        context: context
    )
}