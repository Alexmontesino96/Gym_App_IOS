//
//  StripeService.swift
//  Gym_API
//
//  Servicio para gestionar la integración con Stripe SDK
//

import Foundation
import UIKit
@_spi(STP) import StripePayments
@_spi(STP) import StripePaymentSheet
@_spi(STP) import StripeCore

@MainActor
class StripeService: ObservableObject {
    static let shared = StripeService()

    @Published var isPaymentReady = false
    @Published var paymentError: String?
    @Published var paymentStatus: PaymentStatus = .idle
    @Published var paymentSheet: PaymentSheet?

    enum PaymentStatus {
        case idle
        case processing
        case succeeded
        case failed(Error)
        case cancelled
    }

    // MARK: - Initialization
    init() {
        configure()
    }

    private func configure() {
        // Configure Stripe with publishable key
        if StripeConfig.isConfigured() {
            STPAPIClient.shared.publishableKey = StripeConfig.publishableKey
            print("✅ Stripe SDK configured with publishable key")
        } else {
            print("⚠️ Stripe SDK not configured - missing publishable key")
        }
    }

    // MARK: - Payment Sheet Configuration
    func configurePaymentSheet(
        clientSecret: String,
        merchantDisplayName: String,
        stripeAccountId: String? = nil,  // Stripe Connect Account ID for multi-tenant
        applePay: Bool = true
    ) async throws {
        paymentStatus = .processing
        paymentError = nil

        do {
            var configuration = PaymentSheet.Configuration()
            configuration.merchantDisplayName = merchantDisplayName
            configuration.allowsDelayedPaymentMethods = false

            // Configure appearance
            var appearance = PaymentSheet.Appearance()
            appearance.colors.primary = UIColor.red // Use your app's accent color
            appearance.font.base = .systemFont(ofSize: 16)
            appearance.cornerRadius = 12
            configuration.appearance = appearance

            // Configure Apple Pay if available and requested
            print("💳 [StripeService] Apple Pay configuration:")
            print("   - Apple Pay requested: \(applePay)")
            print("   - Device supports Apple Pay: \(StripeAPI.deviceSupportsApplePay())")
            print("   - Merchant ID: \(StripeConfig.merchantIdentifier)")

            if applePay {
                if StripeAPI.deviceSupportsApplePay() {
                    configuration.applePay = .init(
                        merchantId: StripeConfig.merchantIdentifier,
                        merchantCountryCode: "US"
                    )
                    print("✅ [StripeService] Apple Pay configured successfully")
                } else {
                    print("⚠️ [StripeService] Device does not support Apple Pay")
                    print("   Possible reasons:")
                    print("   - No cards added to Apple Wallet")
                    print("   - Device not configured for Apple Pay")
                    print("   - Region restrictions")
                }
            } else {
                print("ℹ️ [StripeService] Apple Pay not requested")
            }

            // CRITICAL: Set Stripe Connect Account ID for multi-tenant
            if let accountId = stripeAccountId {
                print("💳 [StripeService] Using Stripe Connect Account: \(accountId)")
                STPAPIClient.shared.stripeAccount = accountId
            } else {
                print("⚠️ [StripeService] No Stripe Account ID provided - using platform account")
            }

            // Create payment sheet
            paymentSheet = PaymentSheet(
                paymentIntentClientSecret: clientSecret,
                configuration: configuration
            )

            isPaymentReady = true
            paymentStatus = .idle
            print("✅ Payment sheet configured successfully")
        } catch {
            paymentStatus = .failed(error)
            paymentError = error.localizedDescription
            print("❌ Error configuring payment sheet: \(error)")
            throw error
        }
    }

    // MARK: - Present Payment Sheet
    func presentPaymentSheet(
        from viewController: UIViewController? = nil,
        completion: @escaping (PaymentSheetResult) -> Void
    ) {
        guard let paymentSheet = paymentSheet else {
            paymentError = "Payment sheet not configured"
            paymentStatus = .failed(NSError(domain: "StripeService", code: -1))
            completion(.failed(error: NSError(domain: "StripeService", code: -1)))
            return
        }

        // Find the topmost presented view controller
        let presenter: UIViewController? = {
            if let provided = viewController {
                print("💳 [StripeService] Using provided viewController: \(provided)")
                return provided
            }

            guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                  let rootViewController = windowScene.windows.first?.rootViewController else {
                print("❌ [StripeService] Could not find rootViewController")
                return nil
            }

            // Find the topmost presented view controller
            var topController = rootViewController
            while let presented = topController.presentedViewController {
                print("💳 [StripeService] Found presented VC: \(presented)")
                topController = presented
            }

            print("💳 [StripeService] Using topmost viewController: \(topController)")
            return topController
        }()

        guard let presenter = presenter else {
            paymentError = "No view controller available to present payment sheet"
            paymentStatus = .failed(NSError(domain: "StripeService", code: -2))
            completion(.failed(error: NSError(domain: "StripeService", code: -2)))
            return
        }

        paymentStatus = .processing
        print("💳 [StripeService] Presenting PaymentSheet from: \(presenter)")

        paymentSheet.present(from: presenter) { [weak self] paymentResult in
            switch paymentResult {
            case .completed:
                self?.paymentStatus = .succeeded
                self?.paymentError = nil
                completion(.completed)
                print("✅ Payment completed successfully")

            case .canceled:
                self?.paymentStatus = .cancelled
                self?.paymentError = nil
                completion(.canceled)
                print("ℹ️ Payment cancelled by user")

            case .failed(let error):
                self?.paymentStatus = .failed(error)
                self?.paymentError = error.localizedDescription
                completion(.failed(error: error))
                print("❌ Payment failed: \(error)")
            }
        }
    }

    // MARK: - Handle Payment Result
    private func handlePaymentResult(_ result: PaymentSheetResult) {
        switch result {
        case .completed:
            paymentStatus = .succeeded
            paymentError = nil
            print("✅ Payment completed successfully")

        case .canceled:
            paymentStatus = .cancelled
            paymentError = nil
            print("ℹ️ Payment cancelled by user")

        case .failed(let error):
            paymentStatus = .failed(error)
            paymentError = error.localizedDescription
            print("❌ Payment failed: \(error)")
        }
    }

    // MARK: - Validate Setup
    func validateSetup() async throws {
        guard StripeConfig.isConfigured() else {
            throw StripeError.notConfigured
        }

        // Test connectivity
        // This could be expanded to actually verify with Stripe's API
        print("✅ Stripe setup validated")
    }

    // MARK: - Reset
    func reset() {
        paymentSheet = nil
        isPaymentReady = false
        paymentStatus = .idle
        paymentError = nil
    }

    deinit {
        print("♻️ StripeService deinitialized")
    }
}

// MARK: - Custom Errors
enum StripeError: LocalizedError {
    case notConfigured
    case invalidClientSecret
    case paymentFailed(String)

    var errorDescription: String? {
        switch self {
        case .notConfigured:
            return "Stripe SDK no está configurado. Verifica la clave pública."
        case .invalidClientSecret:
            return "El client secret del pago es inválido."
        case .paymentFailed(let message):
            return "Error en el pago: \(message)"
        }
    }
}

// MARK: - Payment Sheet Result Extension
enum PaymentSheetResult {
    case completed
    case canceled
    case failed(error: Error)

    var isSuccess: Bool {
        switch self {
        case .completed:
            return true
        case .canceled, .failed:
            return false
        }
    }
}