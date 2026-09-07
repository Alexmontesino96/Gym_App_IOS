import SwiftUI

// MARK: - EventEditorialCard
/// Editorial-style event card: date column (76px) + gradient strip (60px) + content
struct EventEditorialCard: View {
    let event: Event
    let isRegistered: Bool
    let onTap: () -> Void

    @EnvironmentObject var themeManager: ThemeManager

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
        if currency.uppercased() == "EUR" { return "€\(cents / 100)" }
        return "\(cents / 100) \(currency)"
    }

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 0) {
                // Date column
                dateColumn

                // Gradient strip
                gradientStrip

                // Content
                contentSection
            }
            .frame(maxWidth: .infinity)
            .background(Color.dynamicSurface(theme: themeManager.currentTheme))
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(Color.white.opacity(0.08), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Date Column

    private var dateColumn: some View {
        VStack(spacing: 2) {
            Text(dayLabel)
                .font(.system(size: 9, weight: .semibold))
                .tracking(0.4)
                .foregroundColor(Color.dynamicText(theme: themeManager.currentTheme).opacity(0.5))

            Text(dateNumber)
                .font(.system(size: 26, weight: .bold, design: .monospaced))
                .tracking(-0.5)
                .foregroundColor(Color.dynamicText(theme: themeManager.currentTheme))

            Text(monthLabel)
                .font(.system(size: 9, weight: .semibold))
                .tracking(0.4)
                .foregroundColor(Color.dynamicText(theme: themeManager.currentTheme).opacity(0.5))
        }
        .frame(width: 76)
        .overlay(alignment: .trailing) {
            Rectangle()
                .fill(Color.white.opacity(0.08))
                .frame(width: 1)
        }
    }

    // MARK: - Gradient Strip

    private var gradientStrip: some View {
        ZStack(alignment: .bottomLeading) {
            // Gradient background
            LinearGradient(
                colors: [heroColor.opacity(0.8), heroColor.opacity(0.4)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            // Category icon badge
            Image(systemName: category.icon)
                .font(.system(size: 10))
                .foregroundColor(.white)
                .frame(width: 22, height: 22)
                .background(Color.black.opacity(0.7))
                .clipShape(Circle())
                .padding(8)
        }
        .frame(width: 60)
    }

    // MARK: - Content Section

    private var contentSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            // Category + price
            HStack {
                Text(category.label)
                    .font(.system(size: 9, weight: .bold))
                    .tracking(0.8)
                    .foregroundColor(heroColor)

                Spacer()

                Text(priceText)
                    .font(.system(size: 9, weight: .bold, design: .monospaced))
                    .foregroundColor(isFree ? Color(hex: "#D4FF3F")! : Color.dynamicText(theme: themeManager.currentTheme))
            }

            // Title
            Text(event.title)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(Color.dynamicText(theme: themeManager.currentTheme))
                .lineLimit(2)
                .lineSpacing(2)

            // Location + time
            HStack(spacing: 6) {
                HStack(spacing: 3) {
                    Image(systemName: "mappin")
                        .font(.system(size: 10))
                    Text(event.location)
                        .lineLimit(1)
                }
                .foregroundColor(Color.dynamicText(theme: themeManager.currentTheme).opacity(0.45))

                Text("·")
                    .foregroundColor(Color.dynamicText(theme: themeManager.currentTheme).opacity(0.3))

                Text(timeString)
                    .font(.system(size: 11, weight: .semibold, design: .monospaced))
                    .foregroundColor(Color.dynamicText(theme: themeManager.currentTheme).opacity(0.5))
            }
            .font(.system(size: 11))

            // Attendees + capacity
            HStack(spacing: 6) {
                // Mini avatars
                HStack(spacing: -4) {
                    ForEach(0..<min(3, event.participantsCount), id: \.self) { i in
                        Circle()
                            .fill(attendeeColors[i % attendeeColors.count])
                            .frame(width: 18, height: 18)
                            .overlay(Circle().stroke(Color.dynamicSurface(theme: themeManager.currentTheme), lineWidth: 1.5))
                    }
                }

                Text("\(event.participantsCount)/\(event.maxParticipants)")
                    .font(.system(size: 11, weight: .semibold, design: .monospaced))
                    .foregroundColor(Color.dynamicText(theme: themeManager.currentTheme).opacity(0.5))

                if isRegistered {
                    HStack(spacing: 3) {
                        Circle()
                            .fill(Color(hex: "#D4FF3F")!)
                            .frame(width: 5, height: 5)
                        Text("Vas")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundColor(Color(hex: "#D4FF3F")!)
                    }
                }
            }
        }
        .padding(14)
    }

    // MARK: - Helpers

    private var dayLabel: String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "es_ES")
        f.dateFormat = "EEE"
        return f.string(from: event.startTime).uppercased()
    }

    private var dateNumber: String {
        let f = DateFormatter()
        f.dateFormat = "dd"
        return f.string(from: event.startTime)
    }

    private var monthLabel: String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "es_ES")
        f.dateFormat = "MMM"
        return f.string(from: event.startTime).uppercased()
    }

    private var timeString: String {
        let f = DateFormatter()
        f.dateFormat = "HH:mm"
        return f.string(from: event.startTime)
    }

    private let attendeeColors: [Color] = [
        Color(hex: "#FF5A1F")!,
        Color(hex: "#A78BFA")!,
        Color(hex: "#3B82F6")!,
    ]
}
