import SwiftUI

// MARK: - Upcoming Classes Section
/// Shows next 2 upcoming classes with time, name, instructor, and booking status
struct HomeUpcomingClassesSection: View {
    let classes: [GymClass]
    let registrationStatus: [Int: Bool] // classId -> isRegistered
    let onClassTap: (GymClass) -> Void
    let onSeeAllTap: () -> Void

    @EnvironmentObject var themeManager: ThemeManager

    var body: some View {
        VStack(spacing: 12) {
            // Section header
            HStack {
                Text("PRÓXIMAMENTE")
                    .font(.system(size: 11, weight: .semibold))
                    .tracking(0.8)
                    .foregroundColor(Color.dynamicTextTertiary(theme: themeManager.currentTheme))

                Spacer()

                Button(action: onSeeAllTap) {
                    HStack(spacing: 4) {
                        Text("Ver todo")
                            .font(.system(size: 13, weight: .medium))
                        Image(systemName: "chevron.right")
                            .font(.system(size: 12, weight: .medium))
                    }
                    .foregroundColor(Color.dynamicTextSecondary(theme: themeManager.currentTheme))
                }
            }
            .padding(.horizontal, 4)

            // Class cards (max 2)
            VStack(spacing: 10) {
                ForEach(classes.prefix(2)) { gymClass in
                    classCard(gymClass)
                }
            }
        }
    }

    // MARK: - Class Card
    private func classCard(_ gymClass: GymClass) -> some View {
        Button(action: { onClassTap(gymClass) }) {
            HStack(spacing: 14) {
                // Time box
                timeBox(for: gymClass)

                // Class info
                VStack(alignment: .leading, spacing: 2) {
                    Text(gymClass.name)
                        .font(.system(size: 15, weight: .medium))
                        .foregroundColor(Color.dynamicText(theme: themeManager.currentTheme))
                        .lineLimit(1)

                    HStack(spacing: 6) {
                        Text(gymClass.instructor)
                        Text("·")
                        Text("\(durationMinutes(gymClass)) min")
                    }
                    .font(.system(size: 12))
                    .foregroundColor(Color.dynamicTextTertiary(theme: themeManager.currentTheme))
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                // Status indicator
                statusView(for: gymClass)
            }
            .padding(14)
            .background(Color.dynamicSurface(theme: themeManager.currentTheme))
            .clipShape(RoundedRectangle(cornerRadius: 22))
            .overlay(
                RoundedRectangle(cornerRadius: 22)
                    .stroke(Color.dynamicBorder(theme: themeManager.currentTheme).opacity(0.15), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Time Box
    private func timeBox(for gymClass: GymClass) -> some View {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH"
        let hour = formatter.string(from: gymClass.startTime)
        formatter.dateFormat = "mm"
        let minute = formatter.string(from: gymClass.startTime)

        return VStack(spacing: 2) {
            Text(hour)
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(Color.dynamicTextTertiary(theme: themeManager.currentTheme))
            Text(minute)
                .font(.system(size: 16, weight: .bold, design: .monospaced))
                .foregroundColor(Color.dynamicText(theme: themeManager.currentTheme))
        }
        .frame(width: 56)
        .padding(.vertical, 8)
        .background(Color.dynamicSurface2(theme: themeManager.currentTheme))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    // MARK: - Status View
    @ViewBuilder
    private func statusView(for gymClass: GymClass) -> some View {
        let isFull = gymClass.currentParticipants >= gymClass.maxParticipants
        let isRegistered = registrationStatus[gymClass.id] ?? false

        if isFull {
            Text("Lleno")
                .font(.system(size: 10, weight: .medium))
                .foregroundColor(Color.dynamicTextTertiary(theme: themeManager.currentTheme))
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(Color.dynamicSurface2(theme: themeManager.currentTheme))
                .clipShape(Capsule())
        } else if isRegistered {
            HStack(spacing: 4) {
                Image(systemName: "checkmark")
                    .font(.system(size: 10, weight: .bold))
                Text("Reservado")
                    .font(.system(size: 10, weight: .semibold))
            }
            .foregroundColor(Color.dynamicAccent(theme: themeManager.currentTheme))
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(Color.dynamicAccent(theme: themeManager.currentTheme).opacity(0.15))
            .clipShape(Capsule())
        } else {
            let remaining = gymClass.maxParticipants - gymClass.currentParticipants
            Text("\(remaining)/\(gymClass.maxParticipants)")
                .font(.system(size: 13, weight: .semibold, design: .monospaced))
                .foregroundColor(Color.dynamicTextSecondary(theme: themeManager.currentTheme))
        }
    }

    private func durationMinutes(_ gymClass: GymClass) -> Int {
        let interval = gymClass.endTime.timeIntervalSince(gymClass.startTime)
        return max(Int(interval / 60), 1)
    }
}
