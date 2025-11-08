//
//  EventPaymentService.swift
//  Gym_API
//
//  Servicio dedicado para gestionar pagos de eventos con Stripe
//

import Foundation
import Combine

// MARK: - Payment Models
struct PaymentIntent: Codable, Identifiable {
    let clientSecret: String
    let paymentIntentId: String
    let stripeAccountId: String?  // Stripe Connect Account ID for multi-tenant
    let amount: Int
    let currency: String
    let paymentDeadline: Date?

    // Identifiable conformance
    var id: String { paymentIntentId }

    enum CodingKeys: String, CodingKey {
        case clientSecret = "client_secret"
        case paymentIntentId = "payment_intent_id"
        case stripeAccountId = "stripe_account_id"
        case amount
        case currency
        case paymentDeadline = "payment_deadline"
    }
}

struct RefundResult: Codable {
    let success: Bool
    let refundAmount: Int?
    let refundType: String?
    let message: String?

    enum CodingKeys: String, CodingKey {
        case success
        case refundAmount = "refund_amount"
        case refundType = "refund_type"
        case message
    }
}

// MARK: - Event Payment Service
@MainActor
class EventPaymentService: ObservableObject {
    // MARK: - Singleton
    static let shared = EventPaymentService()

    // MARK: - Published Properties
    @Published var isProcessingPayment = false
    @Published var isProcessingRefund = false
    @Published var paymentError: String?
    @Published var paymentSuccessMessage: String?
    @Published var currentPaymentIntent: PaymentIntent?
    @Published var lastRefundResult: RefundResult?

    // MARK: - Properties
    private let baseURL = apiBaseURL
    weak var authService: AuthServiceDirect?
    private var currentTask: Task<Void, Never>?

    // MARK: - Initialization
    init(authService: AuthServiceDirect? = nil) {
        self.authService = authService
    }

    // MARK: - Register for Paid Event
    /// Registers user for a paid event and returns payment intent
    func registerForPaidEvent(eventId: Int) async -> EventParticipation? {
        print("🔵 [EventPaymentService] registerForPaidEvent iniciado para evento \(eventId)")
        isProcessingPayment = true
        paymentError = nil

        defer { isProcessingPayment = false }

        guard let authService = authService,
              let token = await authService.getValidAccessToken() else {
            print("❌ [EventPaymentService] No se encontró token de autorización")
            paymentError = "No se encontró token de autorización"
            return nil
        }
        print("✅ [EventPaymentService] Token obtenido")

        guard let gymId = GymService.shared.currentGymId else {
            print("❌ [EventPaymentService] No se encontró gimnasio seleccionado")
            paymentError = "No se encontró gimnasio seleccionado"
            return nil
        }
        print("✅ [EventPaymentService] Gym ID: \(gymId)")

        guard let url = URL(string: "\(baseURL)/events/participation") else {
            print("❌ [EventPaymentService] URL inválida")
            paymentError = "URL inválida"
            return nil
        }
        print("✅ [EventPaymentService] URL: \(url.absoluteString)")

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("\(gymId)", forHTTPHeaderField: "X-Gym-ID")
        request.timeoutInterval = 30 // 30 segundos timeout

        let body = ["event_id": eventId]
        print("📤 [EventPaymentService] Enviando request con body: \(body)")

        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: body)

            print("⏳ [EventPaymentService] Esperando respuesta del servidor...")
            let (data, response) = try await URLSession.shared.data(for: request)
            print("✅ [EventPaymentService] Respuesta recibida")

            guard let httpResponse = response as? HTTPURLResponse else {
                print("❌ [EventPaymentService] Respuesta inválida del servidor - no es HTTPURLResponse")
                paymentError = "Respuesta inválida del servidor"
                return nil
            }

            print("📊 [EventPaymentService] HTTP Status Code: \(httpResponse.statusCode)")

            switch httpResponse.statusCode {
            case 200, 201:
                print("✅ [EventPaymentService] Status 200/201 - Intentando decodificar respuesta")

                // Log raw response for debugging
                if let jsonString = String(data: data, encoding: .utf8) {
                    print("📥 [EventPaymentService] Raw backend response:")
                    print(jsonString)
                }

                let participation = try configuredJSONDecoder().decode(EventParticipation.self, from: data)
                print("✅ [EventPaymentService] Participación decodificada: ID=\(participation.id), paymentRequired=\(participation.paymentRequired ?? false)")

                // If payment is required, store the payment intent
                if participation.paymentRequired == true,
                   let clientSecret = participation.paymentClientSecret {
                    print("💳 [EventPaymentService] Payment details from backend:")
                    print("   - clientSecret: \(clientSecret)")
                    print("   - paymentIntentId: \(participation.paymentIntentId ?? "nil")")
                    print("   - stripeAccountId: \(participation.stripeAccountId ?? "nil")")
                    print("   - amount: \(participation.paymentAmount ?? 0)")
                    print("   - currency: \(participation.paymentCurrency ?? "nil")")

                    // Extract paymentIntentId from clientSecret if not provided by backend
                    // Format: "pi_xxxxx_secret_yyyyy" -> "pi_xxxxx"
                    let extractedPaymentIntentId: String
                    if let backendPaymentIntentId = participation.paymentIntentId, !backendPaymentIntentId.isEmpty {
                        extractedPaymentIntentId = backendPaymentIntentId
                        print("✅ [EventPaymentService] Using paymentIntentId from backend: \(extractedPaymentIntentId)")
                    } else {
                        // Extract from client secret
                        let components = clientSecret.components(separatedBy: "_secret_")
                        extractedPaymentIntentId = components.first ?? ""
                        print("⚠️ [EventPaymentService] Backend did not provide paymentIntentId")
                        print("✅ [EventPaymentService] Extracted from clientSecret: \(extractedPaymentIntentId)")
                    }

                    currentPaymentIntent = PaymentIntent(
                        clientSecret: clientSecret,
                        paymentIntentId: extractedPaymentIntentId,
                        stripeAccountId: participation.stripeAccountId,
                        amount: participation.paymentAmount ?? 0,
                        currency: participation.paymentCurrency ?? "EUR",
                        paymentDeadline: participation.paymentDeadline
                    )
                    print("✅ [EventPaymentService] Payment intent created successfully with ID: \(extractedPaymentIntentId)")
                } else {
                    print("ℹ️ [EventPaymentService] No payment required or missing client secret")
                    print("   - paymentRequired: \(participation.paymentRequired ?? false)")
                    print("   - clientSecret exists: \(participation.paymentClientSecret != nil)")
                }

                return participation

            case 400:
                print("❌ [EventPaymentService] Status 400 - Ya registrado")
                paymentError = "Ya estás registrado en este evento"
            case 401:
                print("❌ [EventPaymentService] Status 401 - Token inválido")
                paymentError = "Token de autorización inválido"
            case 404:
                print("❌ [EventPaymentService] Status 404 - Evento no encontrado")
                paymentError = "Evento no encontrado"
            case 409:
                print("❌ [EventPaymentService] Status 409 - Evento lleno")
                paymentError = "El evento está lleno o no disponible"
            case 422:
                print("❌ [EventPaymentService] Status 422 - Pagos no configurados")
                paymentError = "El sistema de pagos no está configurado para este gimnasio"
            default:
                print("❌ [EventPaymentService] Status \(httpResponse.statusCode) - Error desconocido")
                paymentError = "Error del servidor: \(httpResponse.statusCode)"
            }

        } catch {
            print("❌ [EventPaymentService] Exception capturada")
            print("❌ [EventPaymentService] Error type: \(type(of: error))")
            print("❌ [EventPaymentService] Error localizedDescription: \(error.localizedDescription)")
            print("❌ [EventPaymentService] Error detail: \(error)")
            paymentError = "Error de red: \(error.localizedDescription)"
        }

        return nil
    }

    // MARK: - Confirm Payment
    /// Confirms that a payment has been processed successfully with Stripe
    func confirmPayment(participationId: Int, paymentIntentId: String) async -> Bool {
        print("🔵 [EventPaymentService] confirmPayment iniciado")
        print("   - participationId: \(participationId)")
        print("   - paymentIntentId: \(paymentIntentId)")

        isProcessingPayment = true
        paymentError = nil
        paymentSuccessMessage = nil

        defer { isProcessingPayment = false }

        guard let authService = authService,
              let token = await authService.getValidAccessToken() else {
            print("❌ [EventPaymentService] No se encontró token de autorización")
            paymentError = "No se encontró token de autorización"
            return false
        }
        print("✅ [EventPaymentService] Token obtenido")

        guard let gymId = GymService.shared.currentGymId else {
            print("❌ [EventPaymentService] No se encontró gimnasio seleccionado")
            paymentError = "No se encontró gimnasio seleccionado"
            return false
        }
        print("✅ [EventPaymentService] Gym ID: \(gymId)")

        guard let url = URL(string: "\(baseURL)/events/participation/\(participationId)/confirm-payment") else {
            print("❌ [EventPaymentService] URL inválida")
            paymentError = "URL inválida"
            return false
        }
        print("✅ [EventPaymentService] URL: \(url.absoluteString)")

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("\(gymId)", forHTTPHeaderField: "X-Gym-ID")

        let body = ["payment_intent_id": paymentIntentId]
        print("📤 [EventPaymentService] Enviando request con body: \(body)")

        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: body)

            print("⏳ [EventPaymentService] Esperando respuesta del servidor...")
            let (data, response) = try await URLSession.shared.data(for: request)
            print("✅ [EventPaymentService] Respuesta recibida")

            guard let httpResponse = response as? HTTPURLResponse else {
                print("❌ [EventPaymentService] Respuesta inválida del servidor")
                paymentError = "Respuesta inválida del servidor"
                return false
            }

            print("📊 [EventPaymentService] HTTP Status Code: \(httpResponse.statusCode)")

            // Log response body for debugging
            if let responseString = String(data: data, encoding: .utf8) {
                print("📥 [EventPaymentService] Response body: \(responseString)")
            }

            switch httpResponse.statusCode {
            case 200:
                print("✅ [EventPaymentService] Pago confirmado exitosamente")
                paymentSuccessMessage = "¡Pago confirmado exitosamente!"
                currentPaymentIntent = nil
                print("✅ Payment confirmed successfully")
                return true

            case 400:
                print("❌ [EventPaymentService] Status 400 - Pago ya confirmado")
                paymentError = "El pago ya fue confirmado anteriormente"
            case 401:
                print("❌ [EventPaymentService] Status 401 - Token inválido")
                paymentError = "Token de autorización inválido"
            case 404:
                print("❌ [EventPaymentService] Status 404 - Participación no encontrada")
                paymentError = "Participación no encontrada"
            case 422:
                print("❌ [EventPaymentService] Status 422 - Error validando con Stripe")
                paymentError = "Error validando el pago con Stripe"
            default:
                print("❌ [EventPaymentService] Status \(httpResponse.statusCode) - Error desconocido")
                paymentError = "Error del servidor: \(httpResponse.statusCode)"
            }

        } catch {
            print("❌ [EventPaymentService] Exception capturada en confirmPayment")
            print("❌ [EventPaymentService] Error type: \(type(of: error))")
            print("❌ [EventPaymentService] Error localizedDescription: \(error.localizedDescription)")
            print("❌ [EventPaymentService] Error detail: \(error)")
            paymentError = "Error de red: \(error.localizedDescription)"
        }

        print("❌ [EventPaymentService] confirmPayment retornando false")
        return false
    }

    // MARK: - Get Payment Intent for Waitlist
    /// Gets a new payment intent for users promoted from waitlist
    func getPaymentIntentForWaitlist(participationId: Int) async -> PaymentIntent? {
        isProcessingPayment = true
        paymentError = nil

        defer { isProcessingPayment = false }

        guard let authService = authService,
              let token = await authService.getValidAccessToken() else {
            paymentError = "No se encontró token de autorización"
            return nil
        }

        guard let url = URL(string: "\(baseURL)/events/participation/\(participationId)/payment-intent") else {
            paymentError = "URL inválida"
            return nil
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

        do {
            let (data, response) = try await URLSession.shared.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse else {
                paymentError = "Respuesta inválida del servidor"
                return nil
            }

            switch httpResponse.statusCode {
            case 200:
                let paymentIntent = try configuredJSONDecoder().decode(PaymentIntent.self, from: data)
                currentPaymentIntent = paymentIntent
                print("✅ Payment intent retrieved for waitlist user")
                return paymentIntent

            case 400:
                paymentError = "No estás en lista de espera o el pago no es requerido"
            case 401:
                paymentError = "Token de autorización inválido"
            case 404:
                paymentError = "Participación no encontrada"
            case 422:
                paymentError = "El plazo de pago ha expirado"
            default:
                paymentError = "Error del servidor: \(httpResponse.statusCode)"
            }

        } catch {
            paymentError = "Error de red: \(error.localizedDescription)"
            print("❌ Error getting payment intent: \(error)")
        }

        return nil
    }

    // MARK: - Cancel with Refund
    /// Cancels event participation and processes refund if applicable
    func cancelWithRefund(eventId: Int) async -> RefundResult? {
        isProcessingRefund = true
        paymentError = nil

        defer { isProcessingRefund = false }

        guard let authService = authService,
              let token = await authService.getValidAccessToken() else {
            paymentError = "No se encontró token de autorización"
            return nil
        }

        guard let url = URL(string: "\(baseURL)/events/participation/\(eventId)") else {
            paymentError = "URL inválida"
            return nil
        }

        var request = URLRequest(url: url)
        request.httpMethod = "DELETE"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

        do {
            let (data, response) = try await URLSession.shared.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse else {
                paymentError = "Respuesta inválida del servidor"
                return nil
            }

            switch httpResponse.statusCode {
            case 200:
                // Try to parse refund result
                if let refundResult = try? configuredJSONDecoder().decode(RefundResult.self, from: data) {
                    lastRefundResult = refundResult
                    print("✅ Cancellation processed with refund: \(refundResult.refundAmount ?? 0)")
                    return refundResult
                } else {
                    // Simple success without refund
                    let result = RefundResult(
                        success: true,
                        refundAmount: nil,
                        refundType: nil,
                        message: "Cancelación exitosa"
                    )
                    lastRefundResult = result
                    return result
                }

            case 400:
                paymentError = "No puedes cancelar en este momento"
            case 401:
                paymentError = "Token de autorización inválido"
            case 404:
                paymentError = "Participación no encontrada"
            case 422:
                paymentError = "Error procesando el reembolso"
            default:
                paymentError = "Error del servidor: \(httpResponse.statusCode)"
            }

        } catch {
            paymentError = "Error de red: \(error.localizedDescription)"
            print("❌ Error cancelling with refund: \(error)")
        }

        return nil
    }

    // MARK: - Calculate Refund
    /// Calculates the refund amount based on event policy
    func calculateRefund(event: Event, participation: EventParticipation) -> (amount: Int, percentage: Int) {
        guard participation.isPaid,
              let amountPaid = participation.amountPaidCents,
              let policy = event.refundPolicy else {
            return (0, 0)
        }

        let hoursUntilEvent = event.hoursUntilEvent
        let deadlineHours = Double(event.refundDeadlineHours ?? 24)

        guard hoursUntilEvent > deadlineHours else {
            return (0, 0)
        }

        switch policy {
        case .fullRefund:
            return (amountPaid, 100)

        case .partialRefund:
            let percentage = event.partialRefundPercentage ?? 50
            let refundAmount = (amountPaid * percentage) / 100
            return (refundAmount, percentage)

        case .credit:
            // Credit returns full value but not as money
            return (amountPaid, 100)

        case .noRefund:
            return (0, 0)
        }
    }

    // MARK: - Clear Data
    func clearData() {
        currentPaymentIntent = nil
        lastRefundResult = nil
        paymentError = nil
        paymentSuccessMessage = nil
        currentTask?.cancel()
    }

    deinit {
        currentTask?.cancel()
        print("♻️ EventPaymentService deinitialized")
    }
}

// MARK: - Helper Functions
private func configuredJSONDecoder() -> JSONDecoder {
    let decoder = JSONDecoder()
    decoder.dateDecodingStrategy = .custom { decoder in
        let container = try decoder.singleValueContainer()
        let dateString = try container.decode(String.self)

        // Try ISO8601 with fractional seconds first
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = formatter.date(from: dateString) {
            return date
        }

        // Try without fractional seconds
        formatter.formatOptions = [.withInternetDateTime]
        if let date = formatter.date(from: dateString) {
            return date
        }

        throw DecodingError.dataCorruptedError(in: container, debugDescription: "Cannot decode date string \(dateString)")
    }
    return decoder
}