import SwiftUI

struct YourWeekSection: View {
    @EnvironmentObject var classService: ClassService
    @EnvironmentObject var eventService: EventService
    @EnvironmentObject var themeManager: ThemeManager

    private let maxItems = 3

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            HStack {
                Text("TU SEMANA")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(Color.dynamicText(theme: themeManager.currentTheme))

                Spacer()

                Button(action: {
                    // TODO: Navigate to calendar/schedule view
                    HapticManager.shared.buttonTap()
                }) {
                    Text("Ver todo →")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(Color.dynamicAccent(theme: themeManager.currentTheme))
                }
            }

            // Items
            if upcomingItems.isEmpty {
                emptyStateView
            } else {
                ForEach(Array(upcomingItems.enumerated()), id: \.element.id) { index, item in
                    WeekItemRow(item: item, themeManager: themeManager)
                        .transition(.asymmetric(
                            insertion: .move(edge: .trailing).combined(with: .opacity),
                            removal: .opacity
                        ))
                }
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Color.dynamicSurface(theme: themeManager.currentTheme))
        )
    }

    // MARK: - Empty State

    private var emptyStateView: some View {
        VStack(spacing: 12) {
            Image(systemName: "calendar.badge.plus")
                .font(.system(size: 40))
                .foregroundColor(Color.dynamicTextSecondary(theme: themeManager.currentTheme).opacity(0.5))

            Text("Tu semana está libre")
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(Color.dynamicText(theme: themeManager.currentTheme))

            Text("¡Agenda algo!")
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(Color.dynamicTextSecondary(theme: themeManager.currentTheme))

            Button(action: {
                // Navigate to classes tab
                NotificationCenter.default.post(name: .openClassesTab, object: nil)
            }) {
                Text("Explorar Clases")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 10)
                    .background(
                        Capsule()
                            .fill(Color.dynamicAccent(theme: themeManager.currentTheme))
                    )
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 24)
    }

    // MARK: - Computed Properties

    private var upcomingItems: [WeekItem] {
        var items: [WeekItem] = []

        // Obtener próximos eventos
        let upcomingEvents = eventService.events
            .filter { $0.startTime > Date() && $0.startTime < sevenDaysFromNow }
            .sorted { $0.startTime < $1.startTime }

        for event in upcomingEvents {
            let isRegistered = eventService.isUserRegistered(eventId: event.id)
            items.append(WeekItem(
                id: "event_\(event.id)",
                date: event.startTime,
                title: event.title,
                status: isRegistered ? "Registrado" : "Disponible",
                actionIcon: isRegistered ? "checkmark.circle.fill" : "arrow.right.circle",
                actionColor: isRegistered ? .green : Color.dynamicAccent(theme: themeManager.currentTheme),
                type: .event
            ))
        }

        // TODO: Agregar clases cuando tengamos acceso a classService.sessions
        // Por ahora solo mostramos eventos

        // Ordenar por fecha y limitar a 3 items
        return Array(items.sorted { $0.date < $1.date }.prefix(maxItems))
    }

    private var sevenDaysFromNow: Date {
        Calendar.current.date(byAdding: .day, value: 7, to: Date()) ?? Date()
    }
}

// MARK: - Week Item Model

struct WeekItem: Identifiable {
    let id: String
    let date: Date
    let title: String
    let status: String
    let actionIcon: String
    let actionColor: Color
    let type: ItemType

    enum ItemType {
        case event
        case gymClass
    }

    var dayName: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEE"
        formatter.locale = Locale(identifier: "es_ES")
        return formatter.string(from: date).uppercased()
    }

    var dayNumber: Int {
        Calendar.current.component(.day, from: date)
    }

    var time: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"
        return formatter.string(from: date)
    }
}

// MARK: - Week Item Row

struct WeekItemRow: View {
    let item: WeekItem
    let themeManager: ThemeManager

    var body: some View {
        HStack(spacing: 12) {
            // Date badge
            VStack(spacing: 2) {
                Text(item.dayName)
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(Color.dynamicAccent(theme: themeManager.currentTheme))

                Text("\(item.dayNumber)")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(Color.dynamicText(theme: themeManager.currentTheme))
            }
            .frame(width: 50)

            // Info
            VStack(alignment: .leading, spacing: 4) {
                Text(item.title)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(Color.dynamicText(theme: themeManager.currentTheme))
                    .lineLimit(1)

                Text(item.status)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(Color.dynamicTextSecondary(theme: themeManager.currentTheme))
            }

            Spacer()

            // Time + Action icon
            VStack(alignment: .trailing, spacing: 4) {
                Text(item.time)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(Color.dynamicText(theme: themeManager.currentTheme))

                Image(systemName: item.actionIcon)
                    .font(.system(size: 16))
                    .foregroundColor(item.actionColor)
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.dynamicSurface(theme: themeManager.currentTheme))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.dynamicBorder(theme: themeManager.currentTheme), lineWidth: 0.5)
                )
        )
    }
}

#Preview {
    YourWeekSection()
        .environmentObject(ClassService())
        .environmentObject(EventService())
        .environmentObject(ThemeManager())
        .padding()
}
