import SwiftUI

/// Card component for displaying live/upcoming events with pulsing animations and countdown
struct LiveActivityCard: View {
    @EnvironmentObject var eventService: EventService
    @EnvironmentObject var themeManager: ThemeManager

    @State private var currentTime = Date()
    @State private var pulseScale: CGFloat = 1.0
    @State private var animateIn = false

    private let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    private var liveOrUpcomingEvent: Event? {
        let now = Date()
        return eventService.events
            .filter { $0.status == .active || ($0.status == .scheduled && $0.startTime > now) }
            .sorted { $0.startTime < $1.startTime }
            .first
    }

    var body: some View {
        if let event = liveOrUpcomingEvent {
            eventCard(for: event)
                .opacity(animateIn ? 1 : 0)
                .offset(y: animateIn ? 0 : 20)
                .onAppear {
                    withAnimation(.easeOut(duration: 0.5)) {
                        animateIn = true
                    }
                }
                .onReceive(timer) { _ in
                    currentTime = Date()
                }
        }
    }

    // MARK: - Event Card

    @ViewBuilder
    private func eventCard(for event: Event) -> some View {
        VStack(spacing: 0) {
            // Header with live indicator or countdown
            headerSection(for: event)

            // Event details
            VStack(alignment: .leading, spacing: 12) {
                // Title and trainer
                HStack(alignment: .top, spacing: 12) {
                    // Event icon
                    ZStack {
                        Circle()
                            .fill(iconBackgroundColor(for: event.status).opacity(0.15))
                            .frame(width: 50, height: 50)

                        Image(systemName: iconName(for: event.status))
                            .font(.system(size: 24, weight: .semibold))
                            .foregroundColor(iconBackgroundColor(for: event.status))

                        if event.status == .active {
                            Circle()
                                .stroke(Color.red.opacity(0.3), lineWidth: 2)
                                .frame(width: 50, height: 50)
                                .scaleEffect(pulseScale)
                                .opacity(2 - pulseScale)
                                .onAppear {
                                    withAnimation(
                                        .easeOut(duration: 1.5)
                                        .repeatForever(autoreverses: false)
                                    ) {
                                        pulseScale = 1.5
                                    }
                                }
                        }
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        Text(event.title)
                            .font(.system(size: 18, weight: .bold))
                            .foregroundColor(Color.dynamicText(theme: themeManager.currentTheme))
                            .lineLimit(2)

                        if !event.description.isEmpty {
                            Text(event.description)
                                .font(.system(size: 13, weight: .medium))
                                .foregroundColor(Color.dynamicTextSecondary(theme: themeManager.currentTheme))
                                .lineLimit(2)
                        }
                    }

                    Spacer(minLength: 0)
                }

                // Participants preview
                if event.status == .active {
                    participantsStack(for: event)
                }

                // Action button
                actionButton(for: event)
            }
            .padding(16)
        }
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Color.dynamicSurface(theme: themeManager.currentTheme))
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(
                            event.status == .active ?
                                Color.red.opacity(0.3) :
                                Color.dynamicBorder(theme: themeManager.currentTheme),
                            lineWidth: event.status == .active ? 2 : 1
                        )
                )
                .shadow(
                    color: event.status == .active ?
                        Color.red.opacity(0.2) :
                        Color.black.opacity(themeManager.currentTheme == .dark ? 0.3 : 0.1),
                    radius: 12,
                    x: 0,
                    y: 4
                )
        )
        .padding(.horizontal, 0)
    }

    // MARK: - Header Section

    @ViewBuilder
    private func headerSection(for event: Event) -> some View {
        HStack {
            if event.status == .active {
                // Live indicator
                HStack(spacing: 6) {
                    Circle()
                        .fill(Color.red)
                        .frame(width: 8, height: 8)
                        .breathingEffect(minScale: 0.8, maxScale: 1.2, duration: 1.0)

                    Text("EN VIVO")
                        .font(.system(size: 12, weight: .black))
                        .foregroundColor(.red)
                }
            } else {
                // Countdown
                HStack(spacing: 6) {
                    Image(systemName: "clock.fill")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(Color.dynamicAccent(theme: themeManager.currentTheme))

                    Text(timeUntilEvent(event.startTime))
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(Color.dynamicAccent(theme: themeManager.currentTheme))
                }
            }

            Spacer()

            Text(formattedTime(event.startTime))
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(Color.dynamicTextSecondary(theme: themeManager.currentTheme))
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(
            event.status == .active ?
                Color.red.opacity(0.1) :
                Color.dynamicAccent(theme: themeManager.currentTheme).opacity(0.1)
        )
    }

    // MARK: - Participants Stack

    @ViewBuilder
    private func participantsStack(for event: Event) -> some View {
        HStack(spacing: 8) {
            // TODO: Replace with actual participant avatars from event
            HStack(spacing: -8) {
                ForEach(0..<min(3, 3), id: \.self) { index in
                    Circle()
                        .fill(
                            LinearGradient(
                                gradient: Gradient(colors: [
                                    Color.dynamicAccent(theme: themeManager.currentTheme),
                                    Color.dynamicAccent(theme: themeManager.currentTheme).opacity(0.7)
                                ]),
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 28, height: 28)
                        .overlay(
                            Circle()
                                .stroke(Color.dynamicSurface(theme: themeManager.currentTheme), lineWidth: 2)
                        )
                }
            }

            Text("12 personas participando")
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(Color.dynamicTextSecondary(theme: themeManager.currentTheme))

            Spacer()
        }
    }

    // MARK: - Action Button

    @ViewBuilder
    private func actionButton(for event: Event) -> some View {
        Button(action: {
            HapticManager.shared.buttonTap()
            Task {
                if eventService.isUserRegistered(eventId: event.id) {
                    await eventService.cancelEvent(eventId: event.id)
                } else {
                    await eventService.joinEvent(eventId: event.id)
                }
            }
        }) {
            HStack(spacing: 8) {
                if eventService.isJoiningEvent {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        .scaleEffect(0.8)
                } else {
                    Image(systemName: buttonIcon(for: event))
                        .font(.system(size: 14, weight: .semibold))

                    Text(buttonTitle(for: event))
                        .font(.system(size: 14, weight: .semibold))
                }
            }
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(buttonColor(for: event))
            )
        }
        .disabled(eventService.isJoiningEvent || event.status == .active)
    }

    // MARK: - Helper Methods

    private func iconName(for status: EventStatus) -> String {
        switch status {
        case .active: return "dot.radiowaves.left.and.right"
        case .scheduled: return "calendar.badge.clock"
        default: return "calendar"
        }
    }

    private func iconBackgroundColor(for status: EventStatus) -> Color {
        switch status {
        case .active: return .red
        default: return Color.dynamicAccent(theme: themeManager.currentTheme)
        }
    }

    private func timeUntilEvent(_ date: Date) -> String {
        let timeInterval = date.timeIntervalSince(currentTime)
        let hours = Int(timeInterval / 3600)
        let minutes = Int((timeInterval.truncatingRemainder(dividingBy: 3600)) / 60)

        if hours > 24 {
            let days = hours / 24
            return "En \(days) día\(days > 1 ? "s" : "")"
        } else if hours > 0 {
            return "En \(hours)h \(minutes)m"
        } else if minutes > 0 {
            return "En \(minutes)m"
        } else {
            return "Comienza pronto"
        }
    }

    private func formattedTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"
        return formatter.string(from: date)
    }

    private func buttonTitle(for event: Event) -> String {
        let isRegistered = eventService.isUserRegistered(eventId: event.id)

        if event.status == .active {
            return isRegistered ? "En sesión" : "En vivo ahora"
        } else {
            return isRegistered ? "Cancelar registro" : "Unirme"
        }
    }

    private func buttonIcon(for event: Event) -> String {
        let isRegistered = eventService.isUserRegistered(eventId: event.id)

        if event.status == .active {
            return "play.circle.fill"
        } else {
            return isRegistered ? "xmark.circle.fill" : "plus.circle.fill"
        }
    }

    private func buttonColor(for event: Event) -> LinearGradient {
        let isRegistered = eventService.isUserRegistered(eventId: event.id)

        if event.status == .active {
            return LinearGradient(
                gradient: Gradient(colors: [Color.red, Color.red.opacity(0.8)]),
                startPoint: .leading,
                endPoint: .trailing
            )
        } else if isRegistered {
            return LinearGradient(
                gradient: Gradient(colors: [Color.gray, Color.gray.opacity(0.8)]),
                startPoint: .leading,
                endPoint: .trailing
            )
        } else {
            return LinearGradient(
                gradient: Gradient(colors: [
                    Color.dynamicAccent(theme: themeManager.currentTheme),
                    Color.dynamicAccent(theme: themeManager.currentTheme).opacity(0.8)
                ]),
                startPoint: .leading,
                endPoint: .trailing
            )
        }
    }
}

// MARK: - Preview

#Preview {
    LiveActivityCard()
        .withServiceContainer()
        .padding()
        .background(Color.dynamicBackground(theme: .dark))
}
