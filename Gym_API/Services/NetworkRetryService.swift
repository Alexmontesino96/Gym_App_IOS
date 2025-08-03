//
//  NetworkRetryService.swift
//  Gym_API
//
//  Created by Assistant on 8/3/25.
//
//  Network retry service with exponential backoff and circuit breaker pattern
//  Provides robust network request handling with intelligent retry logic

import Foundation
import Auth0

/// Service for handling network requests with retry logic and exponential backoff
@MainActor
class NetworkRetryService {
    static let shared = NetworkRetryService()
    
    private init() {}
    
    // MARK: - Configuration
    private let maxRetries = 3
    private let baseDelay: TimeInterval = 1.0
    private let maxDelay: TimeInterval = 30.0
    private let backoffMultiplier: Double = 2.0
    
    // MARK: - Error Types
    enum RetryError: LocalizedError {
        case maxRetriesExceeded
        case nonRetryableError(Error)
        case circuitBreakerOpen
        
        var errorDescription: String? {
            switch self {
            case .maxRetriesExceeded:
                return "Se agotaron los intentos de conexión"
            case .nonRetryableError(let error):
                return "Error no recuperable: \(error.localizedDescription)"
            case .circuitBreakerOpen:
                return "Servicio temporalmente no disponible"
            }
        }
    }
    
    // MARK: - Circuit Breaker State
    private enum CircuitBreakerState {
        case closed    // Normal operation
        case open      // Failing, stop requests
        case halfOpen  // Testing if service recovered
    }
    
    private var circuitBreakerState: CircuitBreakerState = .closed
    private var failureCount = 0
    private var lastFailureTime: Date?
    private let failureThreshold = 5
    private let recoveryTimeout: TimeInterval = 60.0 // 1 minute
    
    // MARK: - Public Methods
    
    /// Execute a network request with retry logic
    /// - Parameters:
    ///   - operation: The async operation to execute
    ///   - retryCondition: Custom condition to determine if error should be retried
    /// - Returns: The result of the operation
    func executeWithRetry<T>(
        operation: @escaping () async throws -> T,
        retryCondition: ((Error) -> Bool)? = nil
    ) async throws -> T {
        
        // Check circuit breaker
        try checkCircuitBreaker()
        
        // Intentar ejecutar operación con retry logic
        
        for attempt in 0...maxRetries {
            do {
                let result = try await operation()
                
                // Success - reset circuit breaker
                onSuccess()
                return result
                
            } catch {
                print("🔄 NetworkRetryService: Intento \(attempt + 1) falló: \(error.localizedDescription)")
                
                // Check if this error should be retried
                if !shouldRetry(error: error, attempt: attempt, customCondition: retryCondition) {
                    onFailure()
                    throw RetryError.nonRetryableError(error)
                }
                
                // Don't delay after the last attempt
                if attempt < maxRetries {
                    let delay = calculateDelay(for: attempt)
                    print("⏳ NetworkRetryService: Esperando \(delay)s antes del siguiente intento...")
                    try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                }
            }
        }
        
        // All retries exhausted
        onFailure()
        throw RetryError.maxRetriesExceeded
    }
    
    /// Execute Auth0 token refresh with specific retry logic
    /// - Parameter refreshToken: The refresh token to use
    /// - Returns: New credentials
    func executeTokenRefresh(refreshToken: String) async throws -> Auth0.Credentials {
        return try await executeWithRetry(
            operation: {
                try await Auth0
                    .authentication()
                    .renew(withRefreshToken: refreshToken)
                    .start()
            },
            retryCondition: { error in
                // Retry on network errors, but not on invalid_grant (bad refresh token)
                if let urlError = error as? URLError {
                    return self.isRetryableURLError(urlError)
                }
                
                // Check if it's an Auth0 error
                if let authError = error as? Auth0.AuthenticationError {
                    return self.isRetryableAuth0Error(authError)
                }
                
                return false
            }
        )
    }
    
    // MARK: - Private Methods
    
    private func checkCircuitBreaker() throws {
        switch circuitBreakerState {
        case .closed:
            return
            
        case .open:
            guard let lastFailure = lastFailureTime,
                  Date().timeIntervalSince(lastFailure) > recoveryTimeout else {
                throw RetryError.circuitBreakerOpen
            }
            // Try to recover
            circuitBreakerState = .halfOpen
            print("🔄 NetworkRetryService: Circuit breaker pasando a half-open")
            
        case .halfOpen:
            return // Allow one request to test
        }
    }
    
    private func onSuccess() {
        if circuitBreakerState != .closed {
            print("✅ NetworkRetryService: Circuit breaker cerrado - servicio recuperado")
        }
        
        circuitBreakerState = .closed
        failureCount = 0
        lastFailureTime = nil
    }
    
    private func onFailure() {
        failureCount += 1
        lastFailureTime = Date()
        
        if failureCount >= failureThreshold && circuitBreakerState == .closed {
            circuitBreakerState = .open
            print("🚨 NetworkRetryService: Circuit breaker abierto - demasiados fallos")
        } else if circuitBreakerState == .halfOpen {
            circuitBreakerState = .open
            print("🚨 NetworkRetryService: Circuit breaker vuelve a abierto")
        }
    }
    
    private func shouldRetry(error: Error, attempt: Int, customCondition: ((Error) -> Bool)?) -> Bool {
        // Don't retry if we've reached max attempts
        guard attempt < maxRetries else { return false }
        
        // Use custom condition if provided
        if let customCondition = customCondition {
            return customCondition(error)
        }
        
        // Default retry logic
        if let urlError = error as? URLError {
            return isRetryableURLError(urlError)
        }
        
        return true // Retry other errors by default
    }
    
    private func isRetryableURLError(_ error: URLError) -> Bool {
        switch error.code {
        case .timedOut,
             .cannotConnectToHost,
             .cannotFindHost,
             .dnsLookupFailed,
             .networkConnectionLost,
             .notConnectedToInternet:
            return true
            
        case .badServerResponse,
             .cannotDecodeContentData,
             .cannotDecodeRawData,
             .cannotParseResponse:
            return false // Don't retry parsing errors
            
        case .userAuthenticationRequired,
             .userCancelledAuthentication:
            return false // Don't retry auth errors
            
        default:
            return true // Retry unknown errors
        }
    }
    
    private func isRetryableAuth0Error(_ error: Auth0.AuthenticationError) -> Bool {
        // Check if it's an invalid_grant error (bad refresh token)
        if error.localizedDescription.contains("invalid_grant") {
            return false
        }
        
        // Don't retry other specific authentication errors
        if error.localizedDescription.contains("unauthorized") {
            return false
        }
        
        // Retry network-related Auth0 errors
        return true
    }
    
    private func calculateDelay(for attempt: Int) -> TimeInterval {
        let exponentialDelay = baseDelay * pow(backoffMultiplier, Double(attempt))
        let jitteredDelay = exponentialDelay * (0.5 + Double.random(in: 0...0.5)) // Add jitter
        return min(jitteredDelay, maxDelay)
    }
    
    // MARK: - Public Status Methods
    
    var isCircuitBreakerOpen: Bool {
        return circuitBreakerState == .open
    }
    
    var failureRate: Double {
        return failureCount > 0 ? Double(failureCount) / Double(failureThreshold) : 0.0
    }
    
    func resetCircuitBreaker() {
        circuitBreakerState = .closed
        failureCount = 0
        lastFailureTime = nil
        print("🔄 NetworkRetryService: Circuit breaker reseteado manualmente")
    }
    
    #if DEBUG
    func debugStatus() {
        print("\n🔍 NetworkRetryService Debug Status:")
        print("================================")
        print("Circuit Breaker: \(circuitBreakerState)")
        print("Failure Count: \(failureCount)/\(failureThreshold)")
        print("Failure Rate: \(String(format: "%.1f", failureRate * 100))%")
        if let lastFailure = lastFailureTime {
            print("Last Failure: \(lastFailure)")
        }
        print("================================\n")
    }
    #endif
}