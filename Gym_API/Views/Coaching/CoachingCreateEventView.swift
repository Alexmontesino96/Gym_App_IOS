import SwiftUI

/// Uses the existing event endpoints. Paid settings are only offered with connected payments.
struct CoachingCreateEventView: View {
    var editing: Event? = nil
    @EnvironmentObject var themeManager: ThemeManager
    @EnvironmentObject var eventService: EventService
    @EnvironmentObject var workspaceContext: WorkspaceContextService
    @Environment(\.dismiss) private var dismiss
    @State private var title = ""
    @State private var description = ""
    @State private var location = ""
    @State private var start = Date().addingTimeInterval(86_400)
    @State private var end = Date().addingTimeInterval(90_000)
    @State private var capacity = 12
    @State private var isPaid = false
    @State private var price = ""
    @State private var isSaving = false
    @State private var error: String?
    @State private var prepared = false

    private var theme: ThemeManager.AppTheme { themeManager.currentTheme }
    private var currency: String { workspaceContext.ptEvents?.currency ?? "USD" }
    private var cents: Int? { EventTicketAmount.cents(from: price) }
    private var capacityRange: ClosedRange<Int> {
        0...max(200, editing?.maxParticipants ?? 0, editing?.participantsCount ?? 0)
    }
    private var valid: Bool {
        !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && title.count <= 100
            && !description.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && !location.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && location.count <= 100
            && start > Date() && end > start
            && (capacity == 0 || capacity >= max(1, editing?.participantsCount ?? 0))
            && (editing != nil || !isPaid || (cents != nil && workspaceContext.ptEvents?.canSellTickets == true))
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(editing == nil ? "Make it a shared experience." : "The details make it happen.")
                            .font(TrainingType.title1()).tracking(-0.7)
                        Text("Visible to clients in your workspace. They'll reserve their place from Events.")
                            .font(TrainingType.subhead())
                            .foregroundStyle(Color.dynamicTextSecondary(theme: theme))
                    }
                    if editing == nil {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) {
                                template("Group workout", icon: "figure.strengthtraining.traditional")
                                template("Workshop", icon: "lightbulb")
                                template("Meetup", icon: "person.2")
                            }
                        }
                    }
                    VStack(alignment: .leading, spacing: 18) {
                        field("EVENT NAME") {
                            TextField("Saturday strength club", text: $title)
                                .accessibilityIdentifier("pt.event.title")
                        }
                        Divider()
                        field("WHAT TO EXPECT") {
                            TextField("What will you do together? What should clients bring?", text: $description, axis: .vertical)
                                .lineLimit(3...6)
                        }
                        Divider()
                        field("LOCATION OR MEETING LINK") {
                            TextField("Your studio, a park or an online link", text: $location)
                                .textInputAutocapitalization(.sentences)
                        }
                    }
                    .trainingCard(theme: theme, padding: 20)

                    VStack(spacing: 17) {
                        DatePicker("Starts", selection: $start, in: Date()...)
                        Divider()
                        DatePicker("Ends", selection: $end, in: start...)
                        Divider()
                        Stepper(value: $capacity, in: capacityRange) {
                            Label(capacity == 0 ? "Unlimited places" : "\(capacity) places", systemImage: "person.2")
                        }
                    }
                    .font(TrainingType.subhead())
                    .trainingCard(theme: theme, padding: 20)

                    ticketCard

                    if let error {
                        Label(error, systemImage: "exclamationmark.circle")
                            .font(TrainingType.caption())
                            .foregroundStyle(Color.dynamicWarningText(theme: theme))
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .padding(20)
            }
            .background(Color.dynamicBackground(theme: theme))
            .foregroundStyle(Color.dynamicText(theme: theme))
            .navigationTitle(editing == nil ? "New event" : "Edit event")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }.disabled(isSaving)
                }
            }
            .safeAreaInset(edge: .bottom) {
                Button { Task { await save() } } label: {
                    HStack(spacing: 8) {
                        if isSaving { ProgressView() }
                        Text(isSaving ? "Saving…" : editing == nil ? "Create event" : "Save changes")
                            .font(TrainingType.headline())
                    }
                    .frame(maxWidth: .infinity, minHeight: 54)
                }
                .buttonStyle(CoachingEventButtonStyle())
                .disabled(!valid || isSaving)
                .opacity(valid ? 1 : 0.45)
                .padding(.horizontal, 20).padding(.vertical, 12)
                .background(Color.dynamicBackground(theme: theme))
            }
            .interactiveDismissDisabled(isSaving)
            .onChange(of: start) { old, new in
                if end <= new { end = new.addingTimeInterval(max(1800, end.timeIntervalSince(old))) }
            }
            .onAppear {
                guard !prepared else { return }
                prepared = true
                guard let editing else { return }
                title = editing.title; description = editing.description; location = editing.location
                start = editing.startTime; end = editing.endTime; capacity = max(0, editing.maxParticipants)
            }
        }
        .tint(Color.dynamicAccentText(theme: theme))
    }

    private var ticketCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            if let editing {
                Label(editing.ticketPriceText, systemImage: "ticket")
                    .font(TrainingType.headline())
                Text("Ticket pricing stays the same for existing bookings.")
                    .font(TrainingType.caption())
                    .foregroundStyle(Color.dynamicTextSecondary(theme: theme))
            } else {
                Toggle("Paid tickets", isOn: $isPaid)
                    .font(TrainingType.headline())
                    .tint(Color.dynamicAccent(theme: theme))
                    .disabled(workspaceContext.ptEvents?.canSellTickets != true)
                if isPaid {
                    HStack {
                        Text("Price per person")
                        Spacer()
                        TextField("0.00", text: $price)
                            .keyboardType(.decimalPad).multilineTextAlignment(.trailing).frame(maxWidth: 90)
                        Text(currency).foregroundStyle(Color.dynamicTextSecondary(theme: theme))
                    }
                    .font(TrainingType.subhead())
                    Text("Full refund when cancelled at least 24 hours before the event. The policy is shown before booking.")
                        .font(TrainingType.caption())
                        .foregroundStyle(Color.dynamicTextSecondary(theme: theme))
                } else {
                    Text(workspaceContext.ptEvents?.canSellTickets == true
                        ? "Free for your clients. Turn on paid tickets to set a price."
                        : "Free for your clients. Connect payments in your coach dashboard to offer paid tickets.")
                        .font(TrainingType.caption())
                        .foregroundStyle(Color.dynamicTextSecondary(theme: theme))
                }
            }
        }
        .trainingCard(theme: theme, padding: 20)
    }

    private func template(_ name: String, icon: String) -> some View {
        Button { title = name } label: {
            Label(name, systemImage: icon)
                .font(TrainingType.caption()).padding(.horizontal, 13).frame(minHeight: 44)
                .background(Color.dynamicSurface(theme: theme), in: Capsule())
        }
        .buttonStyle(.plain)
    }

    private func field<Content: View>(_ label: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 9) {
            Text(label).font(TrainingType.label()).tracking(0.8)
                .foregroundStyle(Color.dynamicTextTertiary(theme: theme))
            content().font(TrainingType.body())
        }
    }

    private func save() async {
        #if DEBUG
        if CoachingEventsGalleryView.isActive {
            error = "Preview only. No event was saved."
            return
        }
        #endif
        guard valid, !isSaving else { return }
        isSaving = true
        error = nil
        defer { isSaving = false }
        let success: Bool
        if let editing {
            success = await eventService.updateEvent(eventId: editing.id, request: UpdateEventRequest(
                title: title.trimmingCharacters(in: .whitespacesAndNewlines), description: description,
                startTime: start, endTime: end, location: location, maxParticipants: capacity
            ))
            error = success ? nil : eventService.createEventErrorMessage ?? "Couldn't save this event. Please try again."
        } else {
            var request = CreateEventRequest(
                title: title.trimmingCharacters(in: .whitespacesAndNewlines), description: description,
                startTime: start, endTime: end, location: location, maxParticipants: capacity,
                firstMessageChat: "Welcome! Find the event details here and use this chat to stay in touch."
            )
            if isPaid {
                request.isPaid = true; request.priceCents = cents; request.currency = currency
                request.refundPolicy = .fullRefund; request.refundDeadlineHours = 24
            }
            success = await eventService.createEvent(request)
            error = success ? nil : eventService.createEventErrorMessage ?? "Couldn't create this event. Please try again."
        }
        if success { dismiss() }
    }
}
