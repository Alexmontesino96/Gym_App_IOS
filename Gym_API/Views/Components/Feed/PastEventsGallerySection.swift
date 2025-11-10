import SwiftUI

/// Section showing past events in a 2x2 grid gallery for the social feed
struct PastEventsGallerySection: View {
    @EnvironmentObject var themeManager: ThemeManager
    @EnvironmentObject var eventService: EventService
    @State private var isLoading = false
    @State private var pastEvents: [Event] = []

    // Grid layout: 2 columns
    private let columns = [
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12)
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Section header
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Eventos Recientes")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundColor(Color.dynamicText(theme: themeManager.currentTheme))

                    Text("Revive los mejores momentos")
                        .font(.system(size: 13, weight: .regular))
                        .foregroundColor(Color.dynamicTextSecondary(theme: themeManager.currentTheme))
                }

                Spacer()

                // See all button
                NavigationLink(destination: EventsView()) {
                    HStack(spacing: 4) {
                        Text("Ver más")
                            .font(.system(size: 14, weight: .semibold))
                        Image(systemName: "chevron.right")
                            .font(.system(size: 12, weight: .semibold))
                    }
                    .foregroundColor(Color.dynamicAccent(theme: themeManager.currentTheme))
                }
            }
            .padding(.horizontal, 16)

            // Gallery grid
            if isLoading {
                loadingView
            } else if pastEvents.isEmpty {
                emptyStateView
            } else {
                galleryGridView
            }
        }
        .onAppear {
            loadPastEvents()
        }
    }

    // MARK: - Subviews

    private var loadingView: some View {
        LazyVGrid(columns: columns, spacing: 12) {
            ForEach(0..<4, id: \.self) { _ in
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.dynamicSurface(theme: themeManager.currentTheme).opacity(0.3))
                    .aspectRatio(1.0, contentMode: .fit)
                    .shimmer()
            }
        }
        .padding(.horizontal, 16)
    }

    private var emptyStateView: some View {
        VStack(spacing: 12) {
            Image(systemName: "photo.stack")
                .font(.system(size: 40))
                .foregroundColor(Color.dynamicTextSecondary(theme: themeManager.currentTheme).opacity(0.5))

            Text("No hay eventos recientes")
                .font(.system(size: 15, weight: .medium))
                .foregroundColor(Color.dynamicTextSecondary(theme: themeManager.currentTheme))
        }
        .frame(maxWidth: .infinity)
        .frame(height: 200)
    }

    private var galleryGridView: some View {
        LazyVGrid(columns: columns, spacing: 12) {
            ForEach(pastEvents.prefix(4)) { event in
                EventGalleryCard(event: event)
                    .environmentObject(themeManager)
            }
        }
        .padding(.horizontal, 16)
    }

    // MARK: - Methods

    private func loadPastEvents() {
        guard !isLoading else { return }

        isLoading = true

        Task {
            // Get completed events from eventService
            let allEvents = eventService.events
            let completedEvents = allEvents.filter { event in
                event.status == .completed
            }
            let sortedEvents = completedEvents.sorted { event1, event2 in
                event1.startTime > event2.startTime // Most recent first
            }
            let limitedEvents = Array(sortedEvents.prefix(4))

            await MainActor.run {
                pastEvents = limitedEvents
                isLoading = false
            }
        }
    }
}

// MARK: - Event Gallery Card
struct EventGalleryCard: View {
    @EnvironmentObject var themeManager: ThemeManager
    let event: Event
    @State private var navigateToDetail = false

    var body: some View {
        ZStack {
            // Hidden NavigationLink
            NavigationLink(destination: EventDetailView(eventId: event.id), isActive: $navigateToDetail) {
                EmptyView()
            }
            .opacity(0)

            // Card content
            cardContent
                .onTapGesture {
                    navigateToDetail = true
                }
        }
    }

    private var cardContent: some View {
        ZStack(alignment: .bottomLeading) {
            // Background gradient (simulating event photo)
            LinearGradient(
                gradient: Gradient(colors: [
                    Color.dynamicAccent(theme: themeManager.currentTheme).opacity(0.7),
                    Color.dynamicAccent(theme: themeManager.currentTheme).opacity(0.3)
                ]),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            // Event icon as placeholder
            VStack {
                Image(systemName: "figure.run")
                    .font(.system(size: 40, weight: .light))
                    .foregroundColor(.white.opacity(0.3))
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            // Gradient overlay for text readability
            LinearGradient(
                gradient: Gradient(colors: [
                    .clear,
                    .black.opacity(0.7)
                ]),
                startPoint: .center,
                endPoint: .bottom
            )

            // Event info
            VStack(alignment: .leading, spacing: 4) {
                Text(event.title)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(.white)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)

                HStack(spacing: 4) {
                    Image(systemName: "calendar")
                        .font(.system(size: 10))
                    Text(formatCompactDate(event.startTime))
                        .font(.system(size: 11, weight: .medium))
                }
                .foregroundColor(.white.opacity(0.9))
            }
            .padding(10)
        }
        .aspectRatio(1.0, contentMode: .fit)
        .cornerRadius(12)
        .shadow(
            color: Color.black.opacity(themeManager.currentTheme == .dark ? 0.3 : 0.15),
            radius: 6,
            x: 0,
            y: 3
        )
    }

    // MARK: - Helper Methods

    private func formatCompactDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "es_ES")
        formatter.dateFormat = "dd MMM"
        return formatter.string(from: date)
    }
}

// MARK: - Preview
#Preview {
    let sampleEvents = [
        Event(
            id: 1,
            title: "Yoga Matinal Especial",
            description: "Sesión completada",
            startTime: Date().addingTimeInterval(-86400 * 7),
            endTime: Date().addingTimeInterval(-86400 * 7 + 3600),
            location: "Sala Principal",
            maxParticipants: 20,
            status: .completed,
            creatorId: 1,
            createdAt: Date(),
            updatedAt: Date(),
            participantsCount: 18,
            isPaid: false,
            priceCents: nil,
            currency: nil,
            refundPolicy: nil,
            refundDeadlineHours: nil,
            partialRefundPercentage: nil,
            stripeProductId: nil,
            stripePriceId: nil
        ),
        Event(
            id: 2,
            title: "Spinning Extremo",
            description: "Sesión completada",
            startTime: Date().addingTimeInterval(-86400 * 5),
            endTime: Date().addingTimeInterval(-86400 * 5 + 3600),
            location: "Sala de Cardio",
            maxParticipants: 15,
            status: .completed,
            creatorId: 1,
            createdAt: Date(),
            updatedAt: Date(),
            participantsCount: 15,
            isPaid: true,
            priceCents: 1000,
            currency: "EUR",
            refundPolicy: nil,
            refundDeadlineHours: nil,
            partialRefundPercentage: nil,
            stripeProductId: nil,
            stripePriceId: nil
        ),
        Event(
            id: 3,
            title: "CrossFit Workshop",
            description: "Sesión completada",
            startTime: Date().addingTimeInterval(-86400 * 3),
            endTime: Date().addingTimeInterval(-86400 * 3 + 3600),
            location: "Zona Funcional",
            maxParticipants: 12,
            status: .completed,
            creatorId: 1,
            createdAt: Date(),
            updatedAt: Date(),
            participantsCount: 12,
            isPaid: false,
            priceCents: nil,
            currency: nil,
            refundPolicy: nil,
            refundDeadlineHours: nil,
            partialRefundPercentage: nil,
            stripeProductId: nil,
            stripePriceId: nil
        ),
        Event(
            id: 4,
            title: "Zumba Party",
            description: "Sesión completada",
            startTime: Date().addingTimeInterval(-86400 * 1),
            endTime: Date().addingTimeInterval(-86400 * 1 + 3600),
            location: "Sala de Baile",
            maxParticipants: 25,
            status: .completed,
            creatorId: 1,
            createdAt: Date(),
            updatedAt: Date(),
            participantsCount: 22,
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
            PastEventsGallerySection()
                .environmentObject(ThemeManager())
                .environmentObject(eventService)
        }
    }
}
