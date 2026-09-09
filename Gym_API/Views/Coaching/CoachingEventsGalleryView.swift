#if DEBUG
import SwiftUI

/// Visual QA of the production views. No authentication, network writes or persistent fixtures.
struct CoachingEventsGalleryView: View {
    static var scenario: String? {
        let args = CommandLine.arguments
        guard let index = args.firstIndex(of: "-coaching-events-gallery"), args.indices.contains(index + 1) else {
            return nil
        }
        return args[index + 1]
    }
    static var isActive: Bool { scenario != nil }

    @EnvironmentObject var themeManager: ThemeManager
    @EnvironmentObject var eventService: EventService
    @EnvironmentObject var workspace: WorkspaceContextService
    @Environment(\.colorScheme) private var colorScheme
    @State private var ready = false
    @State private var tab = 2

    var body: some View {
        Group {
            if ready { content } else { Color.clear }
        }
        .onAppear {
            themeManager.currentTheme = colorScheme == .dark ? .dark : .light
            workspace.galleryPTEvents = PTEventsState(
                gymId: -1, available: Self.scenario != "unavailable", enabled: Self.scenario != "settings-off",
                canManage: Self.scenario != "client", canSellTickets: true, currency: "USD"
            )
            if Self.scenario == "settings-error" {
                workspace.eventsSettingsError = "Finish or cancel your upcoming events before turning Events off."
            }
            ready = true
        }
        .onChange(of: colorScheme) { _, scheme in
            themeManager.currentTheme = scheme == .dark ? .dark : .light
        }
    }

    @ViewBuilder
    private var content: some View {
        switch Self.scenario {
        case "settings", "settings-off", "settings-error", "unavailable":
            NavigationStack { CoachingEventsSettingsView() }
        case "create":
            CoachingCreateEventView()
        case "detail":
            NavigationStack { CoachingEventDetailView(event: Self.events[0], isCoach: false) }
        default:
            TabView(selection: $tab) {
                Color.clear.tabItem { Label("Home", systemImage: "house") }.tag(0)
                Color.clear.tabItem {
                    Label(Self.scenario == "client" ? "Sessions" : "Clients", systemImage: "person.2")
                }.tag(1)
                CoachingEventsView(isCoach: Self.scenario != "client")
                    .tabItem { Label("Events", systemImage: "calendar.circle.fill") }.tag(2)
                Color.clear.tabItem { Label("Messages", systemImage: "message") }.tag(3)
                NavigationStack { CoachingEventsSettingsView() }
                    .tabItem { Label("Profile", systemImage: "person") }.tag(4)
            }
            .tint(Color.dynamicAccentText(theme: themeManager.currentTheme))
        }
    }

    static var events: [Event] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        return [
            makeEvent(id: -101, title: "Saturday strength club", location: "Riverside Park · North lawn",
                      start: today.addingTimeInterval(3 * 86_400 + 9 * 3600), count: 8, price: nil),
            makeEvent(id: -102, title: "The art of a better squat", location: "Coach's studio",
                      start: today.addingTimeInterval(7 * 86_400 + 10 * 3600), count: 6, price: 2500)
        ]
    }

    private static func makeEvent(id: Int, title: String, location: String, start: Date, count: Int, price: Int?) -> Event {
        Event(id: id, title: title,
              description: "A little fresh air, a shared workout and a chance to connect. We'll warm up together, move through a full-body strength session and finish with time to catch up. Bring water and a mat — all levels welcome.",
              startTime: start, endTime: start.addingTimeInterval(3600), location: location,
              maxParticipants: 12, status: .scheduled, creatorId: -1, createdAt: Date(), updatedAt: Date(),
              participantsCount: count, isPaid: price != nil, priceCents: price, currency: "USD",
              refundPolicy: price == nil ? nil : .fullRefund, refundDeadlineHours: 24,
              partialRefundPercentage: nil, stripeProductId: nil, stripePriceId: nil)
    }
}
#endif
