//
//  EventPill.swift
//  Gym_API
//
//  Componente Activity Card para mostrar evento etiquetado en posts
//

import SwiftUI
import Foundation

// MARK: - EventPillContainer

/// Container view que carga y muestra un evento etiquetado
struct EventPillContainer: View {
    @EnvironmentObject var themeManager: ThemeManager

    let eventTag: PostTag
    @State private var event: Event?
    @State private var isLoading = true
    @State private var loadError = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if isLoading {
                // Skeleton loader que replica la forma del card
                HStack(spacing: 10) {
                    Circle()
                        .fill(Color.gray.opacity(0.2))
                        .frame(width: 40, height: 40)

                    VStack(alignment: .leading, spacing: 6) {
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color.gray.opacity(0.2))
                            .frame(width: 140, height: 12)
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color.gray.opacity(0.15))
                            .frame(width: 100, height: 10)
                    }
                    Spacer()
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(Color.dynamicSurface(theme: themeManager.currentTheme).opacity(0.85))
                .sessionShimmering()
            } else if let event = event {
                EventPillCompact(event: event)
                    .environmentObject(themeManager)
                    .transition(.opacity.combined(with: .move(edge: .leading)))
            } else if loadError {
                EventPillFallback(taggedEvent: eventTag.taggedEvent)
                    .environmentObject(themeManager)
            }
        }
        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: isLoading)
        .onAppear {
            loadEventAsync()
        }
    }

    private func loadEventAsync() {
        Task { @MainActor in
            let cacheService = EventCacheService.shared

            if let realEvent = await cacheService.getEvent(id: eventTag.tagId) {
                self.event = realEvent
            } else {
                self.loadError = true
            }

            self.isLoading = false
        }
    }
}

// MARK: - EventPillCompact

/// Event Activity Card - diseño con más peso visual y contexto
struct EventPillCompact: View {
    let event: Event
    @EnvironmentObject var themeManager: ThemeManager
    @State private var livePulse = false

    private var gradientColors: [Color] {
        switch event.status {
        case .active:
            return [Color(hex: "#FF9500") ?? .orange, Color(hex: "#FF6B35") ?? .orange]
        case .cancelled, .completed:
            return [Color.gray.opacity(0.5), Color.gray.opacity(0.3)]
        case .scheduled:
            return Color.classGradient(for: event.title)
        }
    }

    private var iconShadowColor: Color {
        gradientColors.first ?? Color(hex: "#4776E6") ?? .blue
    }

    var body: some View {
        HStack(spacing: 10) {
            // Icono circular con gradiente por status
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: gradientColors,
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 40, height: 40)
                    .shadow(color: iconShadowColor.opacity(0.3), radius: 4, x: 0, y: 2)

                Image(systemName: iconForEvent(event))
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(.white)
            }
            .scaleEffect(event.status == .active ? (livePulse ? 1.05 : 1.0) : 1.0)

            // Textos: título + subtítulo
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(event.title)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(
                            event.status == .cancelled
                            ? .dynamicTextTertiary(theme: themeManager.currentTheme)
                            : .dynamicText(theme: themeManager.currentTheme)
                        )
                        .strikethrough(event.status == .cancelled)
                        .lineLimit(1)
                }

                HStack(spacing: 4) {
                    Image(systemName: "mappin")
                        .font(.system(size: 10))

                    Text(event.location)
                        .lineLimit(1)

                    Circle()
                        .fill(Color.dynamicTextSecondary(theme: themeManager.currentTheme).opacity(0.5))
                        .frame(width: 3, height: 3)

                    Image(systemName: "person.2.fill")
                        .font(.system(size: 10))

                    Text("\(event.participantsCount)/\(event.maxParticipants)")
                }
                .font(.system(size: 13))
                .foregroundColor(.dynamicTextSecondary(theme: themeManager.currentTheme))
                .lineLimit(1)
            }

            Spacer()

            // Badge de fecha/hora o status
            if event.status == .active {
                liveBadge
            } else if event.status == .cancelled {
                cancelledBadge
            } else if event.status == .completed || event.startTime < Date() {
                // Evento pasado - mostrar tiempo relativo
                Text(relativeTimeAgo)
                    .font(.system(size: 12))
                    .foregroundColor(.dynamicTextSecondary(theme: themeManager.currentTheme))
            } else {
                // Evento futuro - fecha y hora
                VStack(alignment: .trailing, spacing: 2) {
                    Text(eventDateLabel)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.dynamicText(theme: themeManager.currentTheme))
                    Text(eventTimeLabel)
                        .font(.system(size: 12))
                        .foregroundColor(.dynamicTextSecondary(theme: themeManager.currentTheme))
                }
            }

            // Chevron
            Image(systemName: "chevron.right")
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(.dynamicTextTertiary(theme: themeManager.currentTheme).opacity(0.6))
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color.dynamicSurface(theme: themeManager.currentTheme).opacity(0.85))
        .onAppear {
            if event.status == .active {
                withAnimation(.easeInOut(duration: 1.0).repeatForever(autoreverses: true)) {
                    livePulse = true
                }
            }
        }
    }

    // MARK: - Live Badge

    private var liveBadge: some View {
        HStack(spacing: 4) {
            Circle()
                .fill(Color.red)
                .frame(width: 6, height: 6)
                .scaleEffect(livePulse ? 1.2 : 0.8)

            Text("EN VIVO")
                .font(.system(size: 10, weight: .bold))
                .foregroundColor(.white)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(
            Capsule()
                .fill(Color.red)
        )
        .shadow(color: Color.red.opacity(0.4), radius: livePulse ? 6 : 3, x: 0, y: 0)
    }

    // MARK: - Cancelled Badge

    private var cancelledBadge: some View {
        Text("CANCELADO")
            .font(.system(size: 10, weight: .bold))
            .foregroundColor(.white)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(
                Capsule()
                    .fill(Color.gray)
            )
    }

    // MARK: - Date/Time Helpers

    private var relativeTimeAgo: String {
        let now = Date()
        let interval = now.timeIntervalSince(event.startTime)

        let minutes = Int(interval / 60)
        let hours = Int(interval / 3600)
        let days = Int(interval / 86400)
        let weeks = Int(interval / 604800)

        if minutes < 1 {
            return "Ahora"
        } else if minutes < 60 {
            return "Hace \(minutes) min"
        } else if hours < 24 {
            return hours == 1 ? "Hace 1 hora" : "Hace \(hours) horas"
        } else if days < 7 {
            return days == 1 ? "Hace 1 día" : "Hace \(days) días"
        } else if weeks < 5 {
            return weeks == 1 ? "Hace 1 semana" : "Hace \(weeks) semanas"
        } else {
            let formatter = DateFormatter()
            formatter.locale = Locale(identifier: "es_ES")
            formatter.dateFormat = "d MMM"
            return formatter.string(from: event.startTime)
        }
    }

    private var eventDateLabel: String {
        if Calendar.current.isDateInToday(event.startTime) {
            return "Hoy"
        } else if Calendar.current.isDateInTomorrow(event.startTime) {
            return "Mañana"
        } else {
            let formatter = DateFormatter()
            formatter.locale = Locale(identifier: "es_ES")
            formatter.dateFormat = "EEE d"
            return formatter.string(from: event.startTime).capitalized
        }
    }

    private var eventTimeLabel: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: event.startTime)
    }

    // MARK: - Icon

    private func iconForEvent(_ event: Event) -> String {
        let title = event.title.lowercased()

        if title.contains("yoga") { return "figure.yoga" }
        if title.contains("run") || title.contains("carrera") { return "figure.run" }
        if title.contains("swim") || title.contains("natacion") { return "figure.pool.swim" }
        if title.contains("bike") || title.contains("cycling") || title.contains("ciclismo") { return "figure.outdoor.cycle" }
        if title.contains("box") || title.contains("boxing") { return "figure.boxing" }
        if title.contains("dance") || title.contains("baile") { return "figure.dance" }
        if title.contains("fitness") || title.contains("gym") || title.contains("crossfit") { return "figure.strengthtraining.functional" }
        if title.contains("workshop") || title.contains("taller") { return "person.3.fill" }
        if title.contains("competicion") || title.contains("competition") || title.contains("torneo") { return "trophy.fill" }
        if title.contains("outdoor") || title.contains("exterior") { return "sun.max.fill" }
        if title.contains("pilates") { return "figure.pilates" }
        if title.contains("hiit") || title.contains("cardio") { return "figure.highintensity.intervaltraining" }
        if title.contains("stretch") || title.contains("estiramiento") { return "figure.cooldown" }

        return "calendar.circle.fill"
    }
}

// MARK: - EventPillFallback

/// Fallback cuando los datos completos del evento no están disponibles
struct EventPillFallback: View {
    let taggedEvent: TaggedEvent?
    @EnvironmentObject var themeManager: ThemeManager

    private let fallbackAccent = Color(hex: "#4776E6") ?? .blue

    var body: some View {
        HStack(spacing: 10) {
            // Icono circular fallback
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [fallbackAccent, fallbackAccent.opacity(0.7)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 40, height: 40)

                Image(systemName: "calendar.circle.fill")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(.white)
            }

            VStack(alignment: .leading, spacing: 3) {
                Text(taggedEvent?.title ?? "Evento")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(.dynamicText(theme: themeManager.currentTheme))
                    .lineLimit(1)

                if let startDate = taggedEvent?.startDate {
                    Text(formatStartDate(startDate))
                        .font(.system(size: 13))
                        .foregroundColor(.dynamicTextSecondary(theme: themeManager.currentTheme))
                }
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(.dynamicTextTertiary(theme: themeManager.currentTheme).opacity(0.6))
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color.dynamicSurface(theme: themeManager.currentTheme).opacity(0.85))
    }

    private func formatStartDate(_ dateString: String) -> String {
        let formatter1 = ISO8601DateFormatter()
        formatter1.formatOptions = [.withInternetDateTime, .withFractionalSeconds]

        let formatter2 = ISO8601DateFormatter()
        formatter2.formatOptions = [.withInternetDateTime]

        var date: Date?
        if let parsed = formatter1.date(from: dateString) ?? formatter2.date(from: dateString) {
            date = parsed
        }

        guard let eventDate = date else {
            return dateString
        }

        let displayFormatter = DateFormatter()
        displayFormatter.locale = Locale(identifier: "es_ES")
        displayFormatter.timeZone = TimeZone.current

        if Calendar.current.isDateInToday(eventDate) {
            displayFormatter.dateFormat = "'Hoy', HH:mm"
        } else if Calendar.current.isDateInTomorrow(eventDate) {
            displayFormatter.dateFormat = "'Mañana', HH:mm"
        } else {
            displayFormatter.dateFormat = "d MMM, HH:mm"
        }

        return displayFormatter.string(from: eventDate)
    }
}

// MARK: - Preview

#if DEBUG
struct EventPill_Previews: PreviewProvider {
    static var previews: some View {
        VStack(spacing: 20) {
            // Evento programado
            EventPillCompact(event: Event(
                id: 1,
                title: "CrossFit Competition",
                description: "Annual competition",
                startTime: Date(),
                endTime: Date().addingTimeInterval(7200),
                location: "Main Gym",
                maxParticipants: 50,
                status: .scheduled,
                creatorId: 1,
                createdAt: Date(),
                updatedAt: Date(),
                participantsCount: 25,
                isPaid: false,
                priceCents: nil,
                currency: nil,
                refundPolicy: nil,
                refundDeadlineHours: nil,
                partialRefundPercentage: nil,
                stripeProductId: nil,
                stripePriceId: nil
            ))
            .environmentObject(ThemeManager())

            // Evento activo (en vivo)
            EventPillCompact(event: Event(
                id: 2,
                title: "Live Yoga Session",
                description: "Yoga flow",
                startTime: Date().addingTimeInterval(-1800),
                endTime: Date().addingTimeInterval(1800),
                location: "Studio A",
                maxParticipants: 20,
                status: .active,
                creatorId: 1,
                createdAt: Date(),
                updatedAt: Date(),
                participantsCount: 15,
                isPaid: nil,
                priceCents: nil,
                currency: nil,
                refundPolicy: nil,
                refundDeadlineHours: nil,
                partialRefundPercentage: nil,
                stripeProductId: nil,
                stripePriceId: nil
            ))
            .environmentObject(ThemeManager())

            // Evento cancelado
            EventPillCompact(event: Event(
                id: 3,
                title: "Boxing Workshop",
                description: "Boxing basics",
                startTime: Date().addingTimeInterval(86400),
                endTime: Date().addingTimeInterval(90000),
                location: "Ring Area",
                maxParticipants: 30,
                status: .cancelled,
                creatorId: 1,
                createdAt: Date(),
                updatedAt: Date(),
                participantsCount: 0,
                isPaid: nil,
                priceCents: nil,
                currency: nil,
                refundPolicy: nil,
                refundDeadlineHours: nil,
                partialRefundPercentage: nil,
                stripeProductId: nil,
                stripePriceId: nil
            ))
            .environmentObject(ThemeManager())

            // Fallback
            EventPillFallback(taggedEvent: TaggedEvent(id: 1, title: "Torneo Anual", startDate: "2025-11-15T10:00:00Z"))
                .environmentObject(ThemeManager())
        }
        .padding()
        .background(Color.black)
    }
}
#endif
