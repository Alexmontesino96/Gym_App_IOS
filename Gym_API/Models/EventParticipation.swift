//
//  EventParticipation.swift
//  Gym_API
//
//  Modelo para gestionar las participaciones en eventos con información de pago
//

import Foundation

// MARK: - EventParticipation
struct EventParticipation: Codable, Identifiable {
    let id: Int
    let eventId: Int
    let memberId: Int
    let status: EventParticipationStatus
    let joinedAt: Date
    let updatedAt: Date?  // Backend sends this field
    let attended: Bool?  // Backend sends "attended"
    let attendanceMarked: Bool?
    let attendanceMarkedAt: Date?

    // Payment related fields
    let paymentRequired: Bool?
    let paymentStatus: PaymentStatus?
    let paymentIntentId: String?
    let paymentClientSecret: String?
    let stripeAccountId: String?  // Stripe Connect Account ID for multi-tenant
    let paymentAmount: Int? // In cents
    let paymentCurrency: String?
    let paymentCompletedAt: Date?
    let paymentDeadline: Date?
    let amountPaidCents: Int?
    let paymentDate: Date?  // Backend sends payment_date
    let paymentExpiry: Date?  // Backend sends payment_expiry
    let refundedAmount: Int?
    let refundedAt: Date?
    let refundDate: Date?  // Backend sends refund_date
    let refundAmountCents: Int?  // Backend sends refund_amount_cents

    // Waitlist related
    let isOnWaitlist: Bool?
    let waitlistPosition: Int?
    let promotedFromWaitlist: Bool?
    let promotedAt: Date?

    enum CodingKeys: String, CodingKey {
        case id
        case eventId = "event_id"
        case memberId = "member_id"
        case status
        case joinedAt = "registered_at"  // Backend sends "registered_at" not "joined_at"
        case updatedAt = "updated_at"
        case attended
        case attendanceMarked = "attendance_marked"
        case attendanceMarkedAt = "attendance_marked_at"

        // Payment fields
        case paymentRequired = "payment_required"
        case paymentStatus = "payment_status"
        case paymentIntentId = "stripe_payment_intent_id"  // Backend sends with "stripe_" prefix
        case paymentClientSecret = "payment_client_secret"
        case stripeAccountId = "stripe_account_id"  // Stripe Connect Account ID
        case paymentAmount = "payment_amount"
        case paymentCurrency = "payment_currency"
        case paymentCompletedAt = "payment_completed_at"
        case paymentDeadline = "payment_deadline"
        case amountPaidCents = "amount_paid_cents"
        case paymentDate = "payment_date"
        case paymentExpiry = "payment_expiry"
        case refundedAmount = "refunded_amount"
        case refundedAt = "refunded_at"
        case refundDate = "refund_date"
        case refundAmountCents = "refund_amount_cents"

        // Waitlist fields
        case isOnWaitlist = "is_on_waitlist"
        case waitlistPosition = "waitlist_position"
        case promotedFromWaitlist = "promoted_from_waitlist"
        case promotedAt = "promoted_at"
    }

    // MARK: - Computed Properties
    var isPaid: Bool {
        return paymentStatus == .paid
    }

    var canRefund: Bool {
        return isPaid && refundedAmount == nil
    }

    var isWaitingPayment: Bool {
        return paymentRequired == true && paymentStatus == .pending
    }

    var paymentDeadlineExpired: Bool {
        if let deadline = paymentDeadline {
            return Date() > deadline
        }
        return false
    }
}

// MARK: - EventParticipationStatus
enum EventParticipationStatus: String, Codable, CaseIterable {
    case registered = "REGISTERED"
    case waitlist = "WAITLIST"
    case pendingPayment = "PENDING_PAYMENT"
    case cancelled = "CANCELLED"
    case attended = "ATTENDED"
    case noShow = "NO_SHOW"

    var displayName: String {
        switch self {
        case .registered: return "Registrado"
        case .waitlist: return "Lista de espera"
        case .pendingPayment: return "Pago pendiente"
        case .cancelled: return "Cancelado"
        case .attended: return "Asistió"
        case .noShow: return "No asistió"
        }
    }

    var icon: String {
        switch self {
        case .registered: return "checkmark.circle.fill"
        case .waitlist: return "clock.fill"
        case .pendingPayment: return "creditcard.fill"
        case .cancelled: return "xmark.circle.fill"
        case .attended: return "person.fill.checkmark"
        case .noShow: return "person.fill.xmark"
        }
    }

    var color: String {
        switch self {
        case .registered: return "green"
        case .waitlist: return "orange"
        case .pendingPayment: return "yellow"
        case .cancelled: return "red"
        case .attended: return "blue"
        case .noShow: return "gray"
        }
    }
}

// MARK: - EventParticipationList
struct EventParticipationList: Codable {
    let participations: [EventParticipation]
    let totalCount: Int
    let registeredCount: Int
    let waitlistCount: Int
    let paidCount: Int?
    let totalRevenueCents: Int?

    enum CodingKeys: String, CodingKey {
        case participations
        case totalCount = "total_count"
        case registeredCount = "registered_count"
        case waitlistCount = "waitlist_count"
        case paidCount = "paid_count"
        case totalRevenueCents = "total_revenue_cents"
    }
}

// MARK: - EventRegistrationResponse
struct EventRegistrationResponse: Codable {
    let success: Bool
    let participation: EventParticipation?
    let message: String?
    let requiresPayment: Bool?
    let paymentUrl: String?

    enum CodingKeys: String, CodingKey {
        case success
        case participation
        case message
        case requiresPayment = "requires_payment"
        case paymentUrl = "payment_url"
    }
}