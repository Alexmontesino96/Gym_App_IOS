import SwiftUI

struct CoachingEventsView: View {
    let isCoach: Bool
    @EnvironmentObject var themeManager: ThemeManager
    @EnvironmentObject var eventService: EventService
    @EnvironmentObject var workspaceContext: WorkspaceContextService
    @State private var selection: EventFilter = .upcoming
    @State private var showingCreate = false
    @State private var hasLoaded = false

    private enum EventFilter: String, CaseIterable {
        case upcoming = "Upcoming", booked = "My bookings", past = "Past"
    }
    private var theme: ThemeManager.AppTheme { themeManager.currentTheme }
    private var canCreate: Bool { isCoach && workspaceContext.ptEvents?.canManage == true }
    private var sourceEvents: [Event] {
        #if DEBUG
        if CoachingEventsGalleryView.isActive {
            return CoachingEventsGalleryView.scenario == "empty" ? [] : CoachingEventsGalleryView.events
        }
        #endif
        return eventService.events
    }
    private var loadError: String? {
        #if DEBUG
        if CoachingEventsGalleryView.isActive { return nil }
        #endif
        return eventService.errorMessage
    }
    private func isBooked(_ event: Event) -> Bool {
        #if DEBUG
        if CoachingEventsGalleryView.isActive { return !isCoach && event.id == -102 }
        #endif
        return eventService.isUserRegistered(eventId: event.id)
    }
    private func hasBooking(_ event: Event) -> Bool {
        #if DEBUG
        if CoachingEventsGalleryView.isActive { return isBooked(event) }
        #endif
        return eventService.myEventParticipations.contains { $0.eventId == event.id && $0.hasActiveBooking }
    }
    private var events: [Event] {
        let now = Date()
        return sourceEvents.filter { event in
            switch selection {
            case .upcoming: return event.endTime > now && event.status != .cancelled && event.status != .completed
            case .booked:
                return event.endTime > now && hasBooking(event)
            case .past: return event.endTime <= now || event.status == .completed || event.status == .cancelled
            }
        }.sorted { selection == .past ? $0.startTime > $1.startTime : $0.startTime < $1.startTime }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    header
                    if hasLoaded || !sourceEvents.isEmpty {
                        filters
                    }
                    if let error = loadError, sourceEvents.isEmpty {
                        ContentUnavailableView {
                            Label("Couldn't load events", systemImage: "wifi.exclamationmark")
                        } description: {
                            Text(error)
                        } actions: {
                            Button("Try again") { Task { await load() } }
                        }
                    } else if !hasLoaded && sourceEvents.isEmpty {
                        ProgressView("Loading events…")
                            .frame(maxWidth: .infinity, minHeight: 220)
                    } else if events.isEmpty {
                        emptyState
                    } else {
                        if loadError != nil {
                            Label("Couldn't refresh. Showing your last saved events.", systemImage: "wifi.exclamationmark")
                                .font(TrainingType.caption())
                                .foregroundStyle(Color.dynamicWarningText(theme: theme))
                        }
                        LazyVStack(spacing: 14) {
                            ForEach(Array(events.enumerated()), id: \.element.id) { index, event in
                                NavigationLink {
                                    CoachingEventDetailView(event: event, isCoach: isCoach)
                                } label: {
                                    CoachingEventCard(
                                        event: event,
                                        isBooked: isBooked(event),
                                        featured: index == 0 && selection == .upcoming
                                    )
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                }
                .padding(20)
                .padding(.bottom, 24)
            }
            .background(Color.dynamicBackground(theme: theme))
            .toolbar(.hidden, for: .navigationBar)
            .refreshable { await load(refresh: true) }
            .onAppear { Task { await load() } }
            .sheet(isPresented: $showingCreate, onDismiss: { Task { await load(refresh: true) } }) {
                CoachingCreateEventView()
            }
        }
        .tint(Color.dynamicAccentText(theme: theme))
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .center) {
                Text("Events").font(TrainingType.display()).tracking(-1)
                    .foregroundStyle(Color.dynamicText(theme: theme))
                Spacer()
                if canCreate {
                    Button { showingCreate = true } label: {
                        Image(systemName: "plus").font(TrainingType.icon(18))
                            .foregroundStyle(ThemeManager.accentInkForCurrentAccent(theme: theme))
                            .frame(width: 46, height: 46)
                            .background(Color.dynamicAccent(theme: theme), in: Circle())
                    }
                    .accessibilityLabel("Create event")
                    .accessibilityIdentifier("pt.events.create")
                }
            }
            Text(isCoach ? "Shared experiences. Stronger connections." : "Train, learn and connect with your coach's community.")
                .font(TrainingType.subhead())
                .foregroundStyle(Color.dynamicTextSecondary(theme: theme))
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var filters: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(EventFilter.allCases.filter { !isCoach || $0 != .booked }, id: \.self) { filter in
                    Button { selection = filter } label: {
                        Text(filter.rawValue).font(TrainingType.caption().weight(.semibold))
                            .padding(.horizontal, 17).frame(minHeight: 44)
                            .foregroundStyle(selection == filter
                                ? ThemeManager.accentInkForCurrentAccent(theme: theme)
                                : Color.dynamicTextSecondary(theme: theme))
                            .background(selection == filter
                                ? Color.dynamicAccent(theme: theme) : Color.dynamicSurface(theme: theme), in: Capsule())
                    }
                    .buttonStyle(.plain)
                    .accessibilityAddTraits(selection == filter ? .isSelected : [])
                }
            }
        }
    }

    private var emptyState: some View {
        VStack(alignment: .leading, spacing: 20) {
            if selection == .upcoming { CoachingGatheringArtwork().frame(height: 165).accessibilityHidden(true) }
            Text(emptyTitle).font(TrainingType.title1()).tracking(-0.7)
                .foregroundStyle(Color.dynamicText(theme: theme))
            Text(emptyMessage).font(TrainingType.body())
                .foregroundStyle(Color.dynamicTextSecondary(theme: theme))
                .fixedSize(horizontal: false, vertical: true)
            if canCreate && selection == .upcoming {
                Button { showingCreate = true } label: {
                    Label("Create your first event", systemImage: "plus")
                        .font(TrainingType.headline()).frame(maxWidth: .infinity, minHeight: 52)
                }
                .buttonStyle(CoachingEventButtonStyle())
            }
        }
        .padding(.top, 8)
    }

    private var emptyTitle: String {
        switch selection {
        case .upcoming: return canCreate ? "Your community starts here." : "Good things are on the way."
        case .booked: return "Your next experience awaits."
        case .past: return "Memories start with a first event."
        }
    }

    private var emptyMessage: String {
        switch selection {
        case .upcoming: return canCreate
            ? "A Saturday workout, a technique workshop or a monthly meetup. Give your clients a reason to come together."
            : "When your coach shares an event, you'll find the details and a place to join right here."
        case .booked: return "Explore upcoming events and reserve your place. Your bookings will appear here."
        case .past: return "Completed and cancelled events will stay here for reference."
        }
    }

    private func load(refresh: Bool = false) async {
        #if DEBUG
        if CoachingEventsGalleryView.isActive { hasLoaded = true; return }
        #endif
        guard workspaceContext.showsPTEvents else { return }
        if refresh { await eventService.forceRefresh() } else { await eventService.fetchEvents() }
        await eventService.fetchUserParticipations()
        hasLoaded = true
    }
}

struct CoachingEventCard: View {
    let event: Event
    var isBooked = false
    var featured = false
    @EnvironmentObject var themeManager: ThemeManager
    private var theme: ThemeManager.AppTheme { themeManager.currentTheme }

    var body: some View {
        VStack(alignment: .leading, spacing: featured ? 22 : 16) {
            HStack(alignment: .top) {
                CoachingEventDateTile(date: event.startTime, featured: featured)
                Spacer()
                Text(isBooked ? "You're going" : event.ticketPriceText)
                    .font(TrainingType.caption().weight(.semibold))
                    .foregroundStyle(Color.dynamicAccentText(theme: theme))
                    .padding(.horizontal, 12).padding(.vertical, 7)
                    .background(Color.dynamicAccent(theme: theme).opacity(0.10), in: Capsule())
            }
            VStack(alignment: .leading, spacing: 10) {
                if featured {
                    Text("NEXT TOGETHER").font(TrainingType.label()).tracking(1)
                        .foregroundStyle(Color.dynamicAccentText(theme: theme))
                }
                Text(event.title).font(featured ? TrainingType.title1() : TrainingType.title2())
                    .tracking(-0.6)
                    .foregroundStyle(Color.dynamicText(theme: theme))
                    .fixedSize(horizontal: false, vertical: true)
                Label(event.location, systemImage: "mappin.and.ellipse")
                    .font(TrainingType.caption())
                    .foregroundStyle(Color.dynamicTextSecondary(theme: theme))
                    .lineLimit(2)
            }
            HStack {
                Text(event.startTime, format: .dateTime.weekday(.abbreviated).hour().minute())
                Spacer(minLength: 4)
                if event.status == .cancelled {
                    Text("Cancelled")
                } else {
                    Label("\(event.participantsCount) going", systemImage: "person.2")
                }
                Image(systemName: "arrow.up.right").font(TrainingType.icon(12))
            }
            .font(TrainingType.caption())
            .foregroundStyle(Color.dynamicTextSecondary(theme: theme))
        }
        .trainingCard(theme: theme, padding: 22)
        .overlay {
            if featured {
                RoundedRectangle(cornerRadius: 22)
                    .stroke(Color.dynamicAccent(theme: theme).opacity(0.32), lineWidth: 1)
            }
        }
        .accessibilityElement(children: .combine)
    }
}

struct CoachingEventDateTile: View {
    let date: Date
    var featured = false
    @EnvironmentObject var themeManager: ThemeManager
    var body: some View {
        VStack(spacing: 2) {
            Text(date, format: .dateTime.month(.abbreviated))
                .textCase(.uppercase).font(TrainingType.label()).tracking(1)
            Text(date, format: .dateTime.day())
                .font(TrainingType.monoL())
        }
        .foregroundStyle(Color.dynamicText(theme: themeManager.currentTheme))
        .frame(width: 66, height: 73)
        .background(Color.dynamicAccent(theme: themeManager.currentTheme).opacity(featured ? 0.16 : 0.07),
                    in: RoundedRectangle(cornerRadius: 17))
    }
}

struct CoachingEventButtonStyle: ButtonStyle {
    @EnvironmentObject var themeManager: ThemeManager
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundStyle(ThemeManager.accentInkForCurrentAccent(theme: themeManager.currentTheme))
            .background(Color.dynamicAccent(theme: themeManager.currentTheme), in: RoundedRectangle(cornerRadius: 17))
            .opacity(configuration.isPressed ? 0.8 : 1)
    }
}

extension Event {
    var ticketPriceText: String {
        guard isPaid == true, let cents = priceCents else { return "Free" }
        return (Decimal(cents) / 100).formatted(.currency(code: currency ?? "USD"))
    }
}
