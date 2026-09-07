import SwiftUI

struct EventsView: View {
    @EnvironmentObject var authService: AuthServiceDirect
    @EnvironmentObject var eventService: EventService
    @EnvironmentObject var themeManager: ThemeManager
    @EnvironmentObject var paymentService: EventPaymentService
    @StateObject private var gymService = GymService.shared

    @State private var searchText = ""
    @State private var selectedCategory: EventCategory?
    @State private var showingCreateEvent = false
    @State private var selectedEvent: Event?

    // Payment states
    @State private var currentPaymentIntent: PaymentIntent?
    @State private var currentParticipationId: Int?
    @State private var currentPaymentEvent: Event?

    // MARK: - Computed

    private var upcomingEvents: [Event] {
        let now = Date()
        var events = eventService.events
            .filter { $0.endTime > now && ($0.status == .scheduled || $0.status == .active) }

        // Filter by search
        if !searchText.isEmpty {
            events = events.filter {
                $0.title.localizedCaseInsensitiveContains(searchText) ||
                $0.description.localizedCaseInsensitiveContains(searchText) ||
                $0.location.localizedCaseInsensitiveContains(searchText)
            }
        }

        // Filter by category
        if let cat = selectedCategory {
            events = events.filter { EventCategoryHelper.category(for: $0) == cat }
        }

        return events.sorted { $0.startTime < $1.startTime }
    }

    private var pastEvents: [Event] {
        let now = Date()
        return eventService.events
            .filter { $0.endTime <= now || $0.status == .completed }
            .sorted { $0.startTime > $1.startTime }
            .prefix(10)
            .map { $0 }
    }

    private var featuredEvent: Event? {
        upcomingEvents.first
    }

    private var listEvents: [Event] {
        Array(upcomingEvents.dropFirst())
    }

    // MARK: - Body

    var body: some View {
        NavigationStack {
            ZStack {
                Color.dynamicBackground(theme: themeManager.currentTheme).ignoresSafeArea()

                ScrollView(.vertical, showsIndicators: false) {
                    VStack(spacing: 20) {
                        // Header
                        headerSection

                        // Featured card
                        if let featured = featuredEvent {
                            EventFeaturedCard(event: featured) {
                                HapticManager.shared.buttonTap()
                                selectedEvent = featured
                            }
                            .environmentObject(themeManager)
                            .padding(.horizontal, 20)
                        }

                        // Category filter
                        EventCategoryFilter(selectedCategory: $selectedCategory)
                            .environmentObject(themeManager)

                        // Upcoming events
                        if !listEvents.isEmpty {
                            upcomingSection
                        }

                        // Past events / Memories
                        if !pastEvents.isEmpty {
                            memoriesSection
                        }

                        Spacer(minLength: 100)
                    }
                }
                .refreshable {
                    await eventService.fetchEvents()
                    await eventService.fetchUserParticipations()
                }

                // FAB
                if RolePermissions.canCreateEvents(gymService.currentGym?.userRoleInGym) {
                    VStack {
                        Spacer()
                        HStack {
                            Spacer()
                            Button(action: { showingCreateEvent = true }) {
                                Image(systemName: "plus")
                                    .font(.system(size: 22, weight: .semibold))
                                    .foregroundColor(Color.accentInk)
                                    .frame(width: 56, height: 56)
                                    .background(Color(hex: "#D4FF3F")!)
                                    .clipShape(Circle())
                                    .shadow(color: Color(hex: "#D4FF3F")!.opacity(0.3), radius: 8, y: 4)
                            }
                            .padding(.trailing, 20)
                            .padding(.bottom, 20)
                        }
                    }
                }
            }
            .navigationTitle("")
            .navigationBarHidden(true)
            .navigationDestination(item: $selectedEvent) { event in
                EventDetailView(eventId: event.id)
                    .environmentObject(themeManager)
                    .environmentObject(eventService)
                    .environmentObject(authService)
                    .environmentObject(paymentService)
            }
        }
        .onAppear {
            Task {
                await eventService.fetchEvents()
                await eventService.fetchUserParticipations()
            }
        }
        .sheet(isPresented: $showingCreateEvent) {
            CreateEventView()
                .environmentObject(themeManager)
                .environmentObject(authService)
                .environmentObject(eventService)
        }
        .sheet(item: Binding(
            get: { currentPaymentIntent },
            set: { currentPaymentIntent = $0 }
        )) { paymentIntent in
            EventPaymentView(
                paymentIntent: paymentIntent,
                participationId: currentParticipationId,
                event: currentPaymentEvent,
                onPaymentComplete: { _ in
                    currentPaymentIntent = nil
                    currentParticipationId = nil
                    currentPaymentEvent = nil
                }
            )
            .environmentObject(themeManager)
            .environmentObject(paymentService)
            .environmentObject(eventService)
        }
    }

    // MARK: - Header

    private var headerSection: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 6) {
                Text("Eventos")
                    .font(.system(size: 28, weight: .bold))
                    .tracking(-0.8)
                    .foregroundColor(Color.dynamicText(theme: themeManager.currentTheme))

                Text("Vive el gimnasio fuera del gimnasio")
                    .font(.system(size: 14))
                    .foregroundColor(Color.dynamicText(theme: themeManager.currentTheme).opacity(0.5))
            }

            Spacer()

            HStack(spacing: 8) {
                Button(action: {}) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 18))
                        .foregroundColor(Color.dynamicText(theme: themeManager.currentTheme))
                        .frame(width: 40, height: 40)
                        .background(Color.dynamicSurface(theme: themeManager.currentTheme))
                        .clipShape(Circle())
                        .overlay(Circle().stroke(Color.white.opacity(0.08), lineWidth: 1))
                }

                Button(action: {}) {
                    Image(systemName: "bookmark")
                        .font(.system(size: 18))
                        .foregroundColor(Color.dynamicText(theme: themeManager.currentTheme))
                        .frame(width: 40, height: 40)
                        .background(Color.dynamicSurface(theme: themeManager.currentTheme))
                        .clipShape(Circle())
                        .overlay(Circle().stroke(Color.white.opacity(0.08), lineWidth: 1))
                }
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 16)
    }

    // MARK: - Upcoming Section

    private var upcomingSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("PRÓXIMOS EVENTOS")
                    .font(.system(size: 9, weight: .bold))
                    .tracking(1.0)
                    .foregroundColor(Color.dynamicText(theme: themeManager.currentTheme).opacity(0.5))

                Text("\(listEvents.count)")
                    .font(.system(size: 9, weight: .bold, design: .monospaced))
                    .foregroundColor(Color.dynamicText(theme: themeManager.currentTheme).opacity(0.35))

                Spacer()
            }
            .padding(.horizontal, 20)

            LazyVStack(spacing: 12) {
                ForEach(listEvents, id: \.id) { event in
                    let isRegistered = eventService.userRegistrationStatus[event.id] ?? false
                    EventEditorialCard(event: event, isRegistered: isRegistered) {
                        HapticManager.shared.buttonTap()
                        selectedEvent = event
                    }
                    .environmentObject(themeManager)
                }
            }
            .padding(.horizontal, 20)
        }
    }

    // MARK: - Memories Section

    private var memoriesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("RECUERDOS")
                    .font(.system(size: 9, weight: .bold))
                    .tracking(1.0)
                    .foregroundColor(Color.dynamicText(theme: themeManager.currentTheme).opacity(0.5))

                Spacer()

                Image(systemName: "arrow.right")
                    .font(.system(size: 12))
                    .foregroundColor(Color.dynamicText(theme: themeManager.currentTheme).opacity(0.35))
            }
            .padding(.horizontal, 20)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(pastEvents, id: \.id) { event in
                        pastEventCard(event)
                    }
                }
                .padding(.horizontal, 20)
            }
        }
    }

    // Random gradient pairs matching prototype past events
    private let pastGradients: [(Color, Color)] = [
        (Color(hex: "#FF5A1F")!, Color(hex: "#FFB347")!),
        (Color(hex: "#A78BFA")!, Color(hex: "#D4FF3F")!),
        (Color(hex: "#4ADE80")!, Color(hex: "#3B82F6")!),
        (Color(hex: "#F472B6")!, Color(hex: "#FFB347")!),
        (Color(hex: "#3B82F6")!, Color(hex: "#A78BFA")!),
        (Color(hex: "#D4FF3F")!, Color(hex: "#4ADE80")!),
        (Color(hex: "#FF5A1F")!, Color(hex: "#F472B6")!),
    ]

    private func pastEventCard(_ event: Event) -> some View {
        let gradientPair = pastGradients[abs(event.id) % pastGradients.count]
        return VStack(spacing: 0) {
            // Image area
            ZStack(alignment: .bottomLeading) {
                LinearGradient(
                    colors: [gradientPair.0, gradientPair.1],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )

                // Date badge
                Text(pastDateLabel(event))
                    .font(.system(size: 9, weight: .bold, design: .monospaced))
                    .foregroundColor(.white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.black.opacity(0.65))
                    .clipShape(Capsule())
                    .padding(8)
            }
            .frame(height: 100)

            // Title
            Text(event.title)
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(Color.dynamicText(theme: themeManager.currentTheme))
                .lineLimit(2)
                .padding(10)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(width: 130)
        .background(Color.dynamicSurface(theme: themeManager.currentTheme))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.white.opacity(0.08), lineWidth: 1)
        )
    }

    private func pastDateLabel(_ event: Event) -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "es_ES")
        f.dateFormat = "dd MMM"
        return f.string(from: event.startTime).uppercased()
    }
}

// MARK: - Event Equatable for navigationDestination

extension Event: @retroactive Hashable {
    public func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}

#Preview {
    EventsView()
        .environmentObject(AuthServiceDirect())
        .environmentObject(EventService())
        .environmentObject(ThemeManager())
        .environmentObject(EventPaymentService.shared)
}
