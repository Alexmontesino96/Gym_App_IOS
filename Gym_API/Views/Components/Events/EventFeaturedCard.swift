import SwiftUI

// MARK: - EventFeaturedCard
/// Large featured event hero card (220px) matching prototype exactly
struct EventFeaturedCard: View {
    let event: Event
    let onTap: () -> Void

    @EnvironmentObject var themeManager: ThemeManager

    private let accentColor = Color(hex: "#D4FF3F")!

    private var category: EventCategory {
        EventCategoryHelper.category(for: event)
    }

    private var heroColor: Color { category.color }

    private var isFree: Bool {
        !(event.isPaid ?? false) || (event.priceCents ?? 0) == 0
    }

    private var priceText: String {
        if isFree { return "GRATIS" }
        let cents = event.priceCents ?? 0
        let currency = event.currency ?? "EUR"
        if currency.uppercased() == "EUR" {
            return "€\(cents / 100)"
        }
        return "\(cents / 100) \(currency)"
    }

    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 0) {
                // Hero area (220px)
                ZStack {
                    // Gradient background
                    LinearGradient(
                        colors: [heroColor, heroColor.opacity(0.6), Color(hex: "#0A0A0A")!.opacity(0.8)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )

                    // Decorative elements
                    Circle()
                        .fill(RadialGradient(colors: [.white.opacity(0.15), .clear], center: .center, startRadius: 0, endRadius: 80))
                        .frame(width: 160, height: 160)
                        .offset(x: -40, y: -30)

                    Circle()
                        .fill(RadialGradient(colors: [heroColor.opacity(0.3), .clear], center: .center, startRadius: 0, endRadius: 60))
                        .frame(width: 120, height: 120)
                        .offset(x: 60, y: 40)

                    // Top badges
                    VStack {
                        HStack(alignment: .top) {
                            // Left badges
                            VStack(alignment: .leading, spacing: 6) {
                                // Featured badge
                                Text("DESTACADO")
                                    .font(.system(size: 9, weight: .bold))
                                    .tracking(1.1)
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 4)
                                    .background(Color.black.opacity(0.7))
                                    .clipShape(Capsule())

                                // Category badge
                                Text(category.label)
                                    .font(.system(size: 9, weight: .bold))
                                    .tracking(0.8)
                                    .foregroundColor(heroColor)
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 4)
                                    .background(Color.black.opacity(0.7))
                                    .clipShape(Capsule())
                            }

                            Spacer()

                            // Price badge
                            Text(priceText)
                                .font(.system(size: isFree ? 9 : 11, weight: isFree ? .heavy : .bold, design: isFree ? .default : .monospaced))
                                .foregroundColor(isFree ? accentColor : .white)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 5)
                                .background(Color(hex: "#0A0A0A")!)
                                .clipShape(Capsule())
                        }

                        Spacer()

                        // Bottom: date block + action button
                        HStack(alignment: .bottom) {
                            // Date block
                            dateBlock

                            Spacer()

                            // Action button
                            Image(systemName: "arrow.right")
                                .font(.system(size: 18, weight: .semibold))
                                .foregroundColor(Color.accentInk)
                                .frame(width: 44, height: 44)
                                .background(accentColor)
                                .clipShape(Circle())
                        }
                    }
                    .padding(16)
                }
                .frame(height: 220)
                .clipShape(UnevenRoundedRectangle(topLeadingRadius: 22, topTrailingRadius: 22))

                // Bottom info card
                VStack(alignment: .leading, spacing: 8) {
                    // Title
                    Text(event.title)
                        .font(.system(size: 19, weight: .semibold))
                        .tracking(-0.28)
                        .foregroundColor(Color.dynamicText(theme: themeManager.currentTheme))
                        .lineLimit(2)

                    // Location + time
                    HStack(spacing: 8) {
                        HStack(spacing: 4) {
                            Image(systemName: "mappin")
                                .font(.system(size: 11))
                            Text(event.location)
                                .lineLimit(1)
                        }
                        .font(.system(size: 12))
                        .foregroundColor(Color.dynamicText(theme: themeManager.currentTheme).opacity(0.5))

                        Text("·")
                            .foregroundColor(Color.dynamicText(theme: themeManager.currentTheme).opacity(0.3))

                        Text(eventTimeString)
                            .font(.system(size: 12, design: .monospaced))
                            .foregroundColor(Color.dynamicText(theme: themeManager.currentTheme).opacity(0.5))
                    }

                    // Attendees
                    HStack(spacing: -6) {
                        ForEach(0..<min(3, event.participantsCount), id: \.self) { i in
                            Circle()
                                .fill(attendeeColors[i % attendeeColors.count])
                                .frame(width: 24, height: 24)
                                .overlay(Circle().stroke(Color.dynamicSurface(theme: themeManager.currentTheme), lineWidth: 2))
                        }

                        if event.participantsCount > 3 {
                            Text("+\(event.participantsCount - 3)")
                                .font(.system(size: 10, weight: .semibold, design: .monospaced))
                                .foregroundColor(Color.dynamicText(theme: themeManager.currentTheme).opacity(0.5))
                                .padding(.leading, 10)
                        }
                    }
                }
                .padding(16)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.dynamicSurface(theme: themeManager.currentTheme))
                .clipShape(UnevenRoundedRectangle(bottomLeadingRadius: 22, bottomTrailingRadius: 22))
            }
            .overlay(
                RoundedRectangle(cornerRadius: 22)
                    .stroke(Color.white.opacity(0.08), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Date Block

    private var dateBlock: some View {
        VStack(spacing: 2) {
            Text(dayLabel)
                .font(.system(size: 9, weight: .semibold))
                .tracking(0.5)
            Text(dateNumber)
                .font(.system(size: 28, weight: .bold, design: .monospaced))
                .tracking(-0.6)
            Text(monthLabel)
                .font(.system(size: 9, weight: .semibold))
                .tracking(0.5)
        }
        .foregroundColor(.white)
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(Color.black.opacity(0.85))
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }

    // MARK: - Helpers

    private var eventTimeString: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: event.startTime)
    }

    private var dayLabel: String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "es_ES")
        formatter.dateFormat = "EEE"
        return formatter.string(from: event.startTime).uppercased()
    }

    private var dateNumber: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "dd"
        return formatter.string(from: event.startTime)
    }

    private var monthLabel: String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "es_ES")
        formatter.dateFormat = "MMM"
        return formatter.string(from: event.startTime).uppercased()
    }

    private let attendeeColors: [Color] = [
        Color(hex: "#FF5A1F")!,
        Color(hex: "#A78BFA")!,
        Color(hex: "#3B82F6")!,
        Color(hex: "#4ADE80")!,
        Color(hex: "#F472B6")!,
    ]
}
