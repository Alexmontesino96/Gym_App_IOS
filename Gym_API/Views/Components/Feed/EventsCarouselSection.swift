import SwiftUI

/// Section showing upcoming events in a horizontal carousel for the social feed
struct EventsCarouselSection: View {
    @EnvironmentObject var themeManager: ThemeManager
    @EnvironmentObject var eventService: EventService
    @State private var isLoading = false
    @State private var upcomingEvents: [Event] = []

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Section header
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Próximos Eventos")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundColor(Color.dynamicText(theme: themeManager.currentTheme))

                    Text("No te pierdas nuestras actividades")
                        .font(.system(size: 13, weight: .regular))
                        .foregroundColor(Color.dynamicTextSecondary(theme: themeManager.currentTheme))
                }

                Spacer()

                // See all button
                NavigationLink(destination: EventsView()) {
                    HStack(spacing: 4) {
                        Text("Ver todos")
                            .font(.system(size: 14, weight: .semibold))
                        Image(systemName: "chevron.right")
                            .font(.system(size: 12, weight: .semibold))
                    }
                    .foregroundColor(Color.dynamicAccent(theme: themeManager.currentTheme))
                }
            }
            .padding(.horizontal, 16)

            // Events carousel
            if isLoading {
                loadingView
            } else if upcomingEvents.isEmpty {
                emptyStateView
            } else {
                eventsScrollView
            }
        }
        .onAppear {
            loadUpcomingEvents()
        }
    }

    // MARK: - Subviews

    private var loadingView: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 16) {
                ForEach(0..<3, id: \.self) { _ in
                    RoundedRectangle(cornerRadius: 16)
                        .fill(Color.dynamicSurface(theme: themeManager.currentTheme).opacity(0.3))
                        .frame(width: 250, height: 180)
                        .shimmer()
                }
            }
            .padding(.horizontal, 16)
        }
        .frame(height: 180)
    }

    private var emptyStateView: some View {
        VStack(spacing: 12) {
            Image(systemName: "calendar.badge.exclamationmark")
                .font(.system(size: 40))
                .foregroundColor(Color.dynamicTextSecondary(theme: themeManager.currentTheme).opacity(0.5))

            Text("No hay eventos próximos")
                .font(.system(size: 15, weight: .medium))
                .foregroundColor(Color.dynamicTextSecondary(theme: themeManager.currentTheme))
        }
        .frame(maxWidth: .infinity)
        .frame(height: 180)
    }

    private var eventsScrollView: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 16) {
                ForEach(upcomingEvents) { event in
                    CompactEventCard(event: event)
                        .environmentObject(themeManager)
                }
            }
            .padding(.horizontal, 16)
        }
        .frame(height: 180)
    }

    // MARK: - Methods

    private func loadUpcomingEvents() {
        guard !isLoading else { return }

        isLoading = true

        Task {
            // Use existing events from eventService if available
            let allEvents = eventService.events
            let activeEvents = allEvents.filter { event in
                event.status == .scheduled || event.status == .active
            }
            let sortedEvents = activeEvents.sorted { event1, event2 in
                event1.startTime < event2.startTime
            }
            let limitedEvents = Array(sortedEvents.prefix(10))

            await MainActor.run {
                upcomingEvents = limitedEvents
                isLoading = false
            }
        }
    }
}

// MARK: - Shimmer Effect Extension
extension View {
    func shimmer() -> some View {
        self.modifier(ShimmerModifier())
    }
}

struct ShimmerModifier: ViewModifier {
    @State private var phase: CGFloat = 0

    func body(content: Content) -> some View {
        content
            .overlay(
                GeometryReader { geometry in
                    Rectangle()
                        .fill(
                            LinearGradient(
                                gradient: Gradient(colors: [
                                    .clear,
                                    .white.opacity(0.3),
                                    .clear
                                ]),
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: geometry.size.width * 2)
                        .offset(x: phase * geometry.size.width * 3 - geometry.size.width * 2)
                }
            )
            .mask(content)
            .onAppear {
                withAnimation(Animation.linear(duration: 1.5).repeatForever(autoreverses: false)) {
                    phase = 1
                }
            }
    }
}

// MARK: - Preview
#Preview {
    let sampleEvents = [
        Event(
            id: 1,
            title: "Yoga Matinal",
            description: "Sesión de yoga para comenzar el día",
            startTime: Date().addingTimeInterval(86400),
            endTime: Date().addingTimeInterval(90000),
            location: "Sala Principal",
            maxParticipants: 20,
            status: .scheduled,
            creatorId: 1,
            createdAt: Date(),
            updatedAt: Date(),
            participantsCount: 15,
            isPaid: true,
            priceCents: 1500,
            currency: "EUR",
            refundPolicy: .fullRefund,
            refundDeadlineHours: 24,
            partialRefundPercentage: nil,
            stripeProductId: nil,
            stripePriceId: nil
        ),
        Event(
            id: 2,
            title: "Spinning Intenso",
            description: "Clase de spinning de alta intensidad",
            startTime: Date().addingTimeInterval(172800),
            endTime: Date().addingTimeInterval(176400),
            location: "Sala de Cardio",
            maxParticipants: 15,
            status: .scheduled,
            creatorId: 1,
            createdAt: Date(),
            updatedAt: Date(),
            participantsCount: 10,
            isPaid: false,
            priceCents: nil,
            currency: nil,
            refundPolicy: nil,
            refundDeadlineHours: nil,
            partialRefundPercentage: nil,
            stripeProductId: nil,
            stripePriceId: nil
        )
    ]

    let eventService = EventService()
    eventService.events = sampleEvents

    return NavigationStack {
        ScrollView {
            EventsCarouselSection()
                .environmentObject(ThemeManager())
                .environmentObject(eventService)
        }
    }
}
