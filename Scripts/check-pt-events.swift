import Foundation

/// Runs against the app's actual Foundation models, without signing or a simulator test bundle.
@main
enum PTEventsContractChecks {
    static func main() throws {
        let us = Locale(identifier: "en_US")
        let es = Locale(identifier: "es_ES")
        let amounts: [(String, Locale, Int?)] = [
            ("25", us, 2500), ("25.5", us, 2550), ("25.50", us, 2550),
            (" 0.01 ", us, 1), ("25,50", es, 2550), ("999999.99", us, 99_999_999),
            ("0", us, nil), ("-1", us, nil), ("1.001", us, nil), ("25abc", us, nil),
            ("1,000.00", us, nil), ("25,50", us, nil), ("25.50", es, nil),
            ("1e3", us, nil), ("NaN", us, nil), ("99999999999999999999", us, nil),
            ("1000000", us, nil), ("", us, nil)
        ]
        for (text, locale, expected) in amounts {
            precondition(EventTicketAmount.cents(from: text, locale: locale) == expected, "Amount: \(text)")
        }

        let state = try JSONDecoder().decode(PTEventsState.self, from: Data("""
        {"gym_id":7,"available":true,"enabled":false,"can_manage":true,"can_sell_tickets":false,"currency":"USD"}
        """.utf8))
        precondition(state.gymId == 7 && state.available && !state.enabled && state.canManage && !state.canSellTickets)
        let decodedState = try JSONDecoder().decode(PTEventsState.self, from: JSONEncoder().encode(state))
        precondition(decodedState == state)

        let event = EventInParticipation(title: "Workshop", description: "A shared session",
                                         startTime: Date(), endTime: Date(), location: "Studio",
                                         maxParticipants: 12, status: .scheduled)
        let bookings: [(String, PaymentStatus?, Bool, Bool)] = [
            ("REGISTERED", nil, true, true), ("REGISTERED", .paid, true, true),
            ("REGISTERED", .pending, false, true), ("PENDING_PAYMENT", .pending, false, true),
            ("WAITLIST", nil, false, true), ("ATTENDED", .paid, true, true),
            ("CANCELLED", .refunded, false, false), ("CANCELLED", nil, false, false)
        ]
        for (status, payment, confirmed, active) in bookings {
            let booking = EventParticipationWithEvent(id: 1, eventId: 2, memberId: 3, status: status,
                attended: false, registeredAt: Date(), updatedAt: Date(), event: event, paymentStatus: payment)
            let decoded = try JSONDecoder().decode(EventParticipationWithEvent.self, from: JSONEncoder().encode(booking))
            precondition(decoded.isConfirmed == confirmed, "Confirmation: \(status)")
            precondition(decoded.hasActiveBooking == active, "Booking: \(status)")
        }
        print("PT Events: 18 ticket amounts, workspace contract and 8 booking states passed.")
    }
}
