import SwiftUI

/// PT presentation over the existing participation, ticketing and event-chat services.
struct CoachingEventDetailView: View {
    let event: Event
    let isCoach: Bool
    @EnvironmentObject var themeManager: ThemeManager
    @EnvironmentObject var authService: AuthServiceDirect
    @EnvironmentObject var workspaceContext: WorkspaceContextService
    @StateObject private var service = EventService()
    @StateObject private var payments = EventPaymentService()
    @State private var showingEdit = false
    @State private var showingCancellation = false
    @State private var paymentIntent: PaymentIntent?
    @State private var participationId: Int?
    @State private var chatRoom: ChatRoomSchema?
    @State private var error: String?
    @State private var isWorking = false
    @State private var loaded = false

    private var theme: ThemeManager.AppTheme { themeManager.currentTheme }
    private var current: Event { service.eventDetail?.asEvent ?? event }
    private var canManage: Bool { isCoach && workspaceContext.ptEvents?.canManage == true }
    private var participation: EventParticipationWithEvent? {
        service.myEventParticipations.first { $0.eventId == event.id }
    }
    private var booked: Bool { service.isUserRegistered(eventId: event.id) }
    private var waiting: Bool { participation?.isWaitlisted == true }
    private var pendingPayment: Bool {
        current.isPaid == true && participation?.needsPayment == true
    }
    private var ended: Bool { current.endTime <= Date() || current.status == .completed || current.status == .cancelled }
    private var full: Bool { current.maxParticipants > 0 && current.participantsCount >= current.maxParticipants }

    var body: some View {
        detailContent
            .sheet(isPresented: $showingEdit, onDismiss: { Task { await load() } }) {
                CoachingCreateEventView(editing: current).environmentObject(service)
            }
            .sheet(item: $paymentIntent, onDismiss: { Task { await load() } }) { intent in
                EventPaymentView(paymentIntent: intent, participationId: participationId, event: current) { _ in
                    paymentIntent = nil
                }
            }
            .navigationDestination(isPresented: Binding(
                get: { chatRoom != nil }, set: { if !$0 { chatRoom = nil } }
            )) {
                if let room = chatRoom {
                    EventChatView(eventId: String(event.id), eventTitle: current.title,
                                  streamChannelId: room.streamChannelId, authService: authService)
                }
            }
            .confirmationDialog("Cancel your booking?", isPresented: $showingCancellation, titleVisibility: .visible) {
                Button("Cancel booking", role: .destructive) { Task { await cancelBooking() } }
            } message: {
                Text(current.isPaid == true ? refundDescription : "Your place will be released for another client.")
            }
    }

    private var detailContent: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 25) {
                hero
                scheduleCard

                VStack(alignment: .leading, spacing: 10) {
                    Text("THE EXPERIENCE").font(TrainingType.label()).tracking(1)
                        .foregroundStyle(Color.dynamicTextTertiary(theme: theme))
                    Text(current.description).font(TrainingType.body())
                        .foregroundStyle(Color.dynamicTextSecondary(theme: theme))
                        .fixedSize(horizontal: false, vertical: true)
                }

                if current.isPaid == true {
                    VStack(alignment: .leading, spacing: 8) {
                        Label("Tickets & cancellations", systemImage: "ticket").font(TrainingType.headline())
                        Text(refundDescription).font(TrainingType.caption())
                            .foregroundStyle(Color.dynamicTextSecondary(theme: theme))
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .trainingCard(theme: theme, padding: 20)
                }

                if booked || canManage {
                    chatButton
                }

                if let message = error ?? service.detailErrorMessage {
                    Label(message, systemImage: "exclamationmark.circle")
                        .font(TrainingType.caption()).foregroundStyle(Color.dynamicWarningText(theme: theme))
                    if !loaded { Button("Try again") { Task { await load() } } }
                }
                if !canManage && (booked || waiting || pendingPayment) && !ended {
                    Button("Cancel my booking", role: .destructive) { showingCancellation = true }
                        .font(TrainingType.caption()).frame(minHeight: 44)
                        .disabled(isWorking || !loaded)
                }
            }
            .padding(20)
        }
        .background(Color.dynamicBackground(theme: theme))
        .foregroundStyle(Color.dynamicText(theme: theme))
        .navigationTitle("Event")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if canManage && !ended {
                ToolbarItem(placement: .primaryAction) {
                    Button("Edit") { showingEdit = true }.disabled(!loaded)
                }
            }
        }
        .safeAreaInset(edge: .bottom) { bookingBar }
        .task { await load() }
        .refreshable { await load() }
    }

    private var scheduleCard: some View {
        VStack(alignment: .leading, spacing: 20) {
            Label {
                VStack(alignment: .leading, spacing: 4) {
                    Text(current.startTime, format: .dateTime.weekday(.wide).month(.wide).day())
                        .font(TrainingType.headline())
                    Text(timeDescription)
                        .font(TrainingType.caption())
                        .foregroundStyle(Color.dynamicTextSecondary(theme: theme))
                }
            } icon: { Image(systemName: "calendar").frame(width: 28) }
            Divider()
            Label(current.location, systemImage: "mappin.and.ellipse").font(TrainingType.subhead())
            if let link = meetingURL {
                Link("Open meeting link", destination: link)
                    .font(TrainingType.caption()).foregroundStyle(Color.dynamicAccentText(theme: theme))
            }
        }
        .trainingCard(theme: theme, padding: 20)
    }

    private var timeDescription: String {
        let start = current.startTime.formatted(date: .omitted, time: .shortened)
        let end = current.endTime.formatted(date: .omitted, time: .shortened)
        return "\(start) – \(end) · \(TimeZone.current.abbreviation() ?? "")"
    }

    private var chatButton: some View {
        Button { Task { await openChat() } } label: {
            HStack(spacing: 13) {
                Image(systemName: "bubble.left.and.bubble.right").font(TrainingType.icon(23))
                VStack(alignment: .leading, spacing: 4) {
                    Text("Event conversation").font(TrainingType.headline())
                    Text("Keep the details and the people together.").font(TrainingType.caption())
                        .foregroundStyle(Color.dynamicTextSecondary(theme: theme))
                }
                Spacer(minLength: 0)
                Image(systemName: "chevron.right").font(TrainingType.icon(12))
            }
            .trainingCard(theme: theme, padding: 20)
        }
        .buttonStyle(.plain).disabled(isWorking || !loaded)
    }

    private var hero: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack {
                CoachingEventDateTile(date: current.startTime, featured: true)
                Spacer()
                Text(current.ticketPriceText).font(TrainingType.headline())
                    .foregroundStyle(Color.dynamicAccentText(theme: theme))
            }
            Text(current.title).font(TrainingType.display()).tracking(-1)
                .fixedSize(horizontal: false, vertical: true)
            HStack(spacing: 7) {
                Image(systemName: "person.2")
                Text(current.maxParticipants > 0
                    ? "\(current.participantsCount) of \(current.maxParticipants) places booked"
                    : "\(current.participantsCount) going")
            }
            .font(TrainingType.caption())
            .foregroundStyle(Color.dynamicTextSecondary(theme: theme))
            if current.maxParticipants > 0 {
                ProgressView(value: min(Double(current.participantsCount), Double(current.maxParticipants)),
                             total: Double(current.maxParticipants))
                    .tint(Color.dynamicAccent(theme: theme))
            }
        }
        .padding(.vertical, 8)
    }

    private var bookingBar: some View {
        VStack(spacing: 8) {
            if canManage {
                Label("Your clients can book from their Events tab.", systemImage: "person.2")
                    .font(TrainingType.caption())
                    .foregroundStyle(Color.dynamicTextSecondary(theme: theme))
            } else {
                Button { Task { await reserve() } } label: {
                    HStack(spacing: 9) {
                        if isWorking || !loaded { ProgressView() }
                        Text(bookingLabel).font(TrainingType.headline())
                    }
                    .frame(maxWidth: .infinity, minHeight: 54)
                }
                .buttonStyle(CoachingEventButtonStyle())
                .disabled(isWorking || !loaded || ended || booked || waiting)
                .opacity(ended ? 0.55 : 1)
            }
        }
        .padding(.horizontal, 20).padding(.vertical, 12)
        .frame(maxWidth: .infinity)
        .background(Color.dynamicBackground(theme: theme))
    }

    private var bookingLabel: String {
        if current.status == .cancelled { return "Event cancelled" }
        if ended { return "Event ended" }
        if booked { return "You're going" }
        if waiting { return "You're on the waitlist" }
        if pendingPayment { return "Complete payment" }
        if full { return "Join the waitlist" }
        return current.isPaid == true ? "Reserve · \(current.ticketPriceText)" : "Reserve your place"
    }

    private var meetingURL: URL? {
        guard let url = URL(string: current.location.trimmingCharacters(in: .whitespacesAndNewlines)),
              ["https", "http"].contains(url.scheme?.lowercased() ?? ""), url.host != nil else { return nil }
        return url
    }

    private var refundDescription: String {
        let hours = current.refundDeadlineHours ?? 24
        switch current.refundPolicy {
        case .fullRefund: return "Full refund when you cancel at least \(hours) hours before the event."
        case .partialRefund:
            return "\(current.partialRefundPercentage ?? 50)% refund when you cancel at least \(hours) hours before the event."
        case .credit: return "Eligible cancellations receive credit for a future event. Cancel at least \(hours) hours before it starts."
        case .noRefund: return "Tickets are non-refundable. Cancelling releases your place."
        case nil: return "Contact your coach for the cancellation policy before booking."
        }
    }

    private func load() async {
        #if DEBUG
        if CoachingEventsGalleryView.isActive { loaded = true; return }
        #endif
        service.authService = authService
        payments.authService = authService
        async let details: Void = service.fetchEventDetail(eventId: event.id)
        async let bookings: Void = service.fetchUserParticipations()
        _ = await (details, bookings)
        loaded = service.eventDetail?.id == event.id && service.detailErrorMessage == nil
            && (isCoach || service.myParticipationsLoaded)
        if !isCoach && !service.myParticipationsLoaded {
            error = "Couldn't verify your booking. Check your connection and try again."
        }
    }

    private func reserve() async {
        #if DEBUG
        if CoachingEventsGalleryView.isActive { error = "Preview only. No place was reserved."; return }
        #endif
        guard loaded, !isWorking, !ended, !booked, !waiting else { return }
        isWorking = true; error = nil
        defer { isWorking = false }
        if current.isPaid == true {
            if let participation, pendingPayment {
                participationId = participation.id
                paymentIntent = await payments.getPaymentIntentForWaitlist(participationId: participation.id)
            } else if let result = await payments.registerForPaidEvent(eventId: event.id) {
                participationId = result.id
                paymentIntent = result.paymentRequired == true ? payments.currentPaymentIntent : nil
            }
            error = payments.paymentError
        } else {
            await service.joinEvent(eventId: event.id)
            error = service.joinEventErrorMessage
        }
        await load()
    }

    private func cancelBooking() async {
        #if DEBUG
        if CoachingEventsGalleryView.isActive { return }
        #endif
        guard !isWorking else { return }
        isWorking = true; error = nil
        defer { isWorking = false }
        if current.isPaid == true {
            _ = await payments.cancelWithRefund(eventId: event.id)
            error = payments.paymentError
        } else {
            await service.cancelEvent(eventId: event.id)
            error = service.joinEventErrorMessage
        }
        await load()
    }

    private func openChat() async {
        #if DEBUG
        if CoachingEventsGalleryView.isActive { error = "The conversation is available in your workspace."; return }
        #endif
        guard !isWorking else { return }
        isWorking = true; error = nil
        defer { isWorking = false }
        chatRoom = await ChatService.shared.getEventChatRoom(eventId: event.id)
        if chatRoom != nil { await ChatService.shared.getMyRooms() }
        if chatRoom == nil { error = "The event conversation isn't available yet. Please try again." }
    }
}

extension EventDetail {
    var asEvent: Event {
        Event(id: id, title: title, description: description, startTime: startTime, endTime: endTime,
              location: location, maxParticipants: maxParticipants, status: status, creatorId: creatorId,
              createdAt: createdAt, updatedAt: updatedAt, participantsCount: participantsCount,
              isPaid: isPaid, priceCents: priceCents, currency: currency, refundPolicy: refundPolicy,
              refundDeadlineHours: refundDeadlineHours, partialRefundPercentage: partialRefundPercentage,
              stripeProductId: stripeProductId, stripePriceId: stripePriceId)
    }
}
