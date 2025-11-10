import SwiftUI

/// Compact event card redesigned for the Social page carousel
struct CompactEventCard: View {
    @EnvironmentObject var themeManager: ThemeManager
    let event: Event
    @State private var navigateToDetail = false
    @GestureState private var isPressed: Bool = false

    var body: some View {
        ZStack {
            // Hidden NavigationLink
            NavigationLink(destination: EventDetailView(eventId: event.id), isActive: $navigateToDetail) {
                EmptyView()
            }
            .opacity(0)

            // Card content
            cardContent
                .scaleEffect(isPressed ? 0.98 : 1.0)
                .animation(.spring(response: 0.25, dampingFraction: 0.8), value: isPressed)
                .onTapGesture {
                    navigateToDetail = true
                }
                .simultaneousGesture(
                    LongPressGesture(minimumDuration: 0.02)
                        .updating($isPressed) { current, state, _ in
                            state = current
                        }
                )
        }
    }

    private var cardContent: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top) {
                datePill
                Spacer()
                pricePill
            }

            Text(event.title)
                .font(.system(size: 16, weight: .bold))
                .foregroundColor(Color.dynamicText(theme: themeManager.currentTheme))
                .lineLimit(2)
                .multilineTextAlignment(.leading)

            HStack(spacing: 6) {
                Image(systemName: "location.fill")
                    .font(.system(size: 12))
                    .foregroundColor(Color.dynamicAccent(theme: themeManager.currentTheme))
                Text(event.location)
                    .font(.system(size: 12, weight: .regular))
                    .foregroundColor(Color.dynamicTextSecondary(theme: themeManager.currentTheme))
                    .lineLimit(1)
            }

            Spacer(minLength: 6)

            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 8) {
                    capacityBar
                    Text("\(event.participantsCount)/\(event.maxParticipants)")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(Color.dynamicTextSecondary(theme: themeManager.currentTheme))
                }

                HStack(spacing: 6) {
                    statusChip
                    if remainingSpots <= 5 && remainingSpots > 0 {
                        chip(text: "Quedan \(remainingSpots)", color: .orange)
                    }
                    coachChip
                }
            }
        }
        .padding(12)
        .frame(width: 250, height: 180)
        .background(
            ZStack {
                Color.dynamicSurface(theme: themeManager.currentTheme)
                LinearGradient(
                    gradient: Gradient(colors: [
                        Color.dynamicAccent(theme: themeManager.currentTheme).opacity(themeManager.currentTheme == .dark ? 0.06 : 0.1),
                        .clear
                    ]),
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            }
        )
        .cornerRadius(16)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.dynamicBorder(theme: themeManager.currentTheme).opacity(themeManager.currentTheme == .dark ? 0.6 : 0.8), lineWidth: 0.5)
        )
        .shadow(
            color: Color.black.opacity(themeManager.currentTheme == .dark ? 0.3 : 0.08),
            radius: 10,
            x: 0,
            y: 6
        )
    }

    // MARK: - Helper Views

    private var datePill: some View {
        let comps = Calendar.current.dateComponents([.day, .month], from: event.startTime)
        let day = comps.day ?? 0
        let month = shortMonthUpper(event.startTime)
        let isToday = Calendar.current.isDateInToday(event.startTime)
        let isTomorrow = Calendar.current.isDateInTomorrow(event.startTime)
        let accent = Color.dynamicAccent(theme: themeManager.currentTheme)

        return VStack(spacing: 2) {
            Text("\(day)")
                .font(.system(size: 18, weight: .heavy))
                .foregroundColor(accent)
            Text(month)
                .font(.system(size: 11, weight: .bold))
                .foregroundColor(Color.dynamicTextSecondary(theme: themeManager.currentTheme))
            Text(timeString(event.startTime))
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(Color.dynamicTextSecondary(theme: themeManager.currentTheme))
        }
        .padding(.vertical, 6)
        .padding(.horizontal, 10)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color.dynamicSurface(theme: themeManager.currentTheme).opacity(0.8))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(accent.opacity(0.25), lineWidth: 1)
        )
        .overlay(
            Group {
                if isToday { chip(text: "Hoy", color: .green).offset(y: -28) }
                else if isTomorrow { chip(text: "Mañana", color: .blue).offset(y: -28) }
            }, alignment: .top
        )
    }

    private var pricePill: some View {
        Group {
            if event.isPaid == true, let price = event.formattedPrice {
                chip(text: price, color: Color.dynamicAccent(theme: themeManager.currentTheme))
            } else {
                chip(text: "Gratis", color: .green)
            }
        }
    }

    private var statusChip: some View {
        if event.participantsCount >= event.maxParticipants {
            return AnyView(chip(text: "Lleno", color: .red))
        } else if event.status == .active {
            return AnyView(chip(text: "Activo", color: .green))
        } else {
            return AnyView(chip(text: formatCompactDate(event.startTime), color: Color.gray.opacity(0.6)))
        }
    }

    private var capacityBar: some View {
        let ratio = max(0, min(1, Double(event.participantsCount) / Double(event.maxParticipants)))
        let color: Color = ratio >= 1 ? .red : (ratio >= 0.75 ? .orange : Color.dynamicAccent(theme: themeManager.currentTheme))
        return GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(Color.dynamicBorder(theme: themeManager.currentTheme).opacity(0.35))
                Capsule()
                    .fill(color)
                    .frame(width: geo.size.width * ratio)
                    .animation(.easeInOut(duration: 0.3), value: event.participantsCount)
            }
        }
        .frame(height: 6)
    }

    @ViewBuilder
    private var coachChip: some View {
        if let coach = extractCoach(from: event.description) {
            chip(text: coach, color: Color.gray.opacity(0.6))
        }
    }

    private func statusBadge(text: String, color: Color) -> some View {
        Text(text)
            .font(.system(size: 10, weight: .bold))
            .foregroundColor(.white)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(
                Capsule()
                    .fill(color)
            )
            .padding(8)
    }

    // MARK: - Helper Methods

    private func formatCompactDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "es_ES")

        if Calendar.current.isDateInToday(date) {
            formatter.dateFormat = "'Hoy' HH:mm"
        } else if Calendar.current.isDateInTomorrow(date) {
            formatter.dateFormat = "'Mañana' HH:mm"
        } else {
            formatter.dateFormat = "dd MMM, HH:mm"
        }

        return formatter.string(from: date)
    }

    private func shortMonthUpper(_ date: Date) -> String {
        let fmt = DateFormatter()
        fmt.locale = Locale(identifier: "es_ES")
        fmt.dateFormat = "LLL"
        return fmt.string(from: date).uppercased()
    }

    private func timeString(_ date: Date) -> String {
        let fmt = DateFormatter()
        fmt.locale = Locale(identifier: "es_ES")
        fmt.dateFormat = "HH:mm"
        return fmt.string(from: date)
    }

    private var remainingSpots: Int {
        max(0, event.maxParticipants - event.participantsCount)
    }

    @ViewBuilder
    private func chip(text: String, color: Color) -> some View {
        Text(text)
            .font(.system(size: 11, weight: .bold))
            .foregroundColor(.white)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(
                Capsule().fill(color)
            )
    }

    private func extractCoach(from description: String) -> String? {
        // Attempt to parse coach/instructor from description
        // Patterns supported: "Coach: Name", "Instructor: Name"
        let patterns = ["Coach:", "COACH:", "Instructor:", "INSTRUCTOR:"]
        for key in patterns {
            if let range = description.range(of: key) {
                let rest = description[range.upperBound...]
                let name = rest.split(separator: "\n").first?.trimmingCharacters(in: .whitespacesAndNewlines)
                if let name, !name.isEmpty { return name }
            }
        }
        return nil
    }
}

// MARK: - Preview
#Preview {
    let sampleEvent = Event(
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
    )

    return CompactEventCard(event: sampleEvent)
        .environmentObject(ThemeManager())
        .frame(width: 250, height: 180)
        .padding()
}
