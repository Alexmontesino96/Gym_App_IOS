import SwiftUI

// MARK: - Session Display State

/// Represents the visual state of a class session in the timeline
enum SessionDisplayState {
    case scheduled       // Future class, available or full
    case inProgress      // Currently happening
    case completedAttended  // Finished, user was present
    case completedNoShow    // Finished, user was registered but absent
    case cancelled       // Class was cancelled

    static func resolve(gymClass: GymClass, isRegistered: Bool) -> SessionDisplayState {
        switch gymClass.status {
        case .cancelled:
            return .cancelled
        case .completed:
            if gymClass.participation == .attended {
                return .completedAttended
            } else if gymClass.participation == .noShow {
                return .completedNoShow
            }
            return .completedAttended // Default for completed if no participation info
        case .inProgress:
            return .inProgress
        case .available:
            // Check if it should be in progress based on time
            let now = Date()
            if now >= gymClass.startTime && now <= gymClass.endTime {
                return .inProgress
            }
            return .scheduled
        }
    }
}

// MARK: - TimelineClassCard
/// Timeline-style class card with 5 session states:
/// scheduled, inProgress, completedAttended, completedNoShow, cancelled
struct TimelineClassCard: View {
    let gymClass: GymClass
    let isRegistered: Bool
    let onTap: () -> Void
    let onAction: () -> Void

    @EnvironmentObject var themeManager: ThemeManager

    private let accentColor = Color(hex: "#D4FF3F")!

    private var displayState: SessionDisplayState {
        SessionDisplayState.resolve(gymClass: gymClass, isRegistered: isRegistered)
    }

    private var category: ClassCategory {
        ClassCategoryHelper.category(for: gymClass)
    }

    private var categoryColor: Color {
        category.color
    }

    private var isFull: Bool {
        gymClass.currentParticipants >= gymClass.maxParticipants
    }

    private var durationMinutes: Int {
        let interval = gymClass.endTime.timeIntervalSince(gymClass.startTime)
        return max(Int(interval / 60), 1)
    }

    private var timeString: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: gymClass.startTime)
    }

    private var instructorInitials: String {
        let parts = gymClass.instructor.components(separatedBy: " ")
        return parts.prefix(2).compactMap { $0.first }.map { String($0).uppercased() }.joined()
    }

    private var capacityFraction: CGFloat {
        guard gymClass.maxParticipants > 0 else { return 0 }
        return CGFloat(gymClass.currentParticipants) / CGFloat(gymClass.maxParticipants)
    }

    private var difficultyLabel: String {
        switch gymClass.difficulty {
        case .beginner: return "Principiante"
        case .intermediate: return "Intermedio"
        case .advanced: return "Avanzado"
        }
    }

    /// Whether this card should appear muted (completed/cancelled states)
    private var isMuted: Bool {
        switch displayState {
        case .completedAttended, .completedNoShow, .cancelled:
            return true
        default:
            return false
        }
    }

    // MARK: - In Progress Calculations

    private var progressFraction: CGFloat {
        let now = Date()
        let total = gymClass.endTime.timeIntervalSince(gymClass.startTime)
        let elapsed = now.timeIntervalSince(gymClass.startTime)
        guard total > 0 else { return 0 }
        return CGFloat(min(max(elapsed / total, 0), 1))
    }

    private var elapsedMinutes: Int {
        let now = Date()
        let elapsed = now.timeIntervalSince(gymClass.startTime)
        return max(Int(elapsed / 60), 0)
    }

    private var remainingMinutes: Int {
        let now = Date()
        let remaining = gymClass.endTime.timeIntervalSince(now)
        return max(Int(remaining / 60), 0)
    }

    /// Hours since class ended
    private var hoursSinceEnd: Int {
        let now = Date()
        let elapsed = now.timeIntervalSince(gymClass.endTime)
        return max(Int(elapsed / 3600), 0)
    }

    // MARK: - Body

    var body: some View {
        Button(action: onTap) {
            HStack(alignment: .top, spacing: 12) {
                // Time column
                timeColumn

                // Card
                cardContent
            }
        }
        .buttonStyle(.plain)
    }

    // MARK: - Time Column

    private var timeColumn: some View {
        VStack(spacing: 4) {
            Text(timeString)
                .font(.system(size: 13, weight: .bold, design: .monospaced))
                .tracking(-0.26)
                .foregroundColor(Color.dynamicText(theme: themeManager.currentTheme).opacity(isMuted ? 0.5 : 1.0))

            Text("+\(durationMinutes)m")
                .font(.system(size: 10, design: .monospaced))
                .foregroundColor(Color.dynamicText(theme: themeManager.currentTheme).opacity(isMuted ? 0.3 : 0.45))
        }
        .frame(width: 44)
        .padding(.top, 14)
    }

    // MARK: - Card Content

    private var cardContent: some View {
        ZStack(alignment: .leading) {
            // Color stripe
            colorStripe

            // Diagonal overlay for cancelled
            if displayState == .cancelled {
                diagonalOverlay
            }

            // Main content
            VStack(alignment: .leading, spacing: 0) {
                // Top: Category + Difficulty | Status Badge
                topRow
                    .padding(.bottom, 8)

                // Title
                titleRow
                    .padding(.bottom, 10)

                // Cancellation reason banner
                if displayState == .cancelled, let reason = gymClass.cancellationReason {
                    cancellationBanner(reason: reason)
                        .padding(.bottom, 10)
                }

                // Meta row: Instructor
                instructorRow
                    .padding(.bottom, 12)

                // Bottom row: State-specific footer
                footerRow
                    .padding(.top, 10)
                    .overlay(alignment: .top) {
                        Rectangle()
                            .fill(Color.white.opacity(0.08))
                            .frame(height: 1)
                    }
            }
            .padding(.top, 14)
            .padding(.bottom, 14)
            .padding(.leading, 18)
            .padding(.trailing, 14)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 22))
        .overlay(
            RoundedRectangle(cornerRadius: 22)
                .stroke(cardBorder, lineWidth: 1)
        )
    }

    // MARK: - Color Stripe

    @ViewBuilder
    private var colorStripe: some View {
        switch displayState {
        case .cancelled:
            // Diagonal stripe pattern
            CancelledStripePattern(color: categoryColor)
                .frame(width: 4)
        case .completedAttended, .completedNoShow:
            Rectangle()
                .fill(categoryColor.opacity(0.4))
                .frame(width: 4)
        default:
            Rectangle()
                .fill(categoryColor)
                .frame(width: 4)
                .opacity(isFull ? 0.4 : 1.0)
        }
    }

    // MARK: - Diagonal Overlay (Cancelled)

    private var diagonalOverlay: some View {
        GeometryReader { geo in
            CancelledDiagonalOverlay()
                .frame(width: geo.size.width, height: geo.size.height)
        }
        .allowsHitTesting(false)
    }

    // MARK: - Top Row

    private var topRow: some View {
        HStack {
            HStack(spacing: 6) {
                // Category tag
                Text(category.label)
                    .font(.system(size: 9, weight: .bold))
                    .tracking(0.7)
                    .foregroundColor(isMuted ? Color.dynamicText(theme: themeManager.currentTheme).opacity(0.5) : categoryColor)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(isMuted ? Color.dynamicText(theme: themeManager.currentTheme).opacity(0.08) : categoryColor.opacity(0.15))
                    .clipShape(RoundedRectangle(cornerRadius: 6))

                Text("\u{00B7}")
                    .font(.system(size: 10))
                    .foregroundColor(Color.dynamicText(theme: themeManager.currentTheme).opacity(0.3))

                // Difficulty
                Text(difficultyLabel.uppercased())
                    .font(.system(size: 10, weight: .semibold))
                    .tracking(0.5)
                    .foregroundColor(Color.dynamicText(theme: themeManager.currentTheme).opacity(0.45))
            }

            Spacer()

            // Status badge
            statusBadge
        }
    }

    // MARK: - Status Badge

    @ViewBuilder
    private var statusBadge: some View {
        switch displayState {
        case .scheduled:
            // Checkmark if registered
            if isRegistered {
                Image(systemName: "checkmark")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(Color.accentInk)
                    .frame(width: 22, height: 22)
                    .background(accentColor)
                    .clipShape(Circle())
            }

        case .inProgress:
            // "EN VIVO" pill with pulsing dot
            HStack(spacing: 5) {
                PulsingDot(color: Color(hex: "#0A0A0A")!)
                Text("EN VIVO")
                    .font(.system(size: 9, weight: .bold))
                    .tracking(0.5)
                    .foregroundColor(Color(hex: "#0A0A0A")!)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(accentColor)
            .clipShape(Capsule())

        case .completedAttended:
            // Green "ASISTIDO" badge
            HStack(spacing: 4) {
                Image(systemName: "checkmark")
                    .font(.system(size: 8, weight: .bold))
                Text("ASISTIDO")
                    .font(.system(size: 9, weight: .bold))
                    .tracking(0.5)
            }
            .foregroundColor(Color(hex: "#4ADE80")!)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Color(hex: "#4ADE80")!.opacity(0.14))
            .overlay(
                Capsule().stroke(Color(hex: "#4ADE80")!.opacity(0.4), lineWidth: 1)
            )
            .clipShape(Capsule())

        case .completedNoShow:
            // Red "NO SHOW" badge
            HStack(spacing: 4) {
                Image(systemName: "xmark")
                    .font(.system(size: 8, weight: .bold))
                Text("NO SHOW")
                    .font(.system(size: 9, weight: .bold))
                    .tracking(0.5)
            }
            .foregroundColor(Color(hex: "#FF5A5A")!)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Color(hex: "#FF5A5A")!.opacity(0.14))
            .overlay(
                Capsule().stroke(Color(hex: "#FF5A5A")!.opacity(0.4), lineWidth: 1)
            )
            .clipShape(Capsule())

        case .cancelled:
            // Gray "CANCELADA" badge
            Text("CANCELADA")
                .font(.system(size: 9, weight: .bold))
                .tracking(0.5)
                .foregroundColor(Color.dynamicText(theme: themeManager.currentTheme).opacity(0.5))
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color.dynamicText(theme: themeManager.currentTheme).opacity(0.08))
                .clipShape(Capsule())
        }
    }

    // MARK: - Title Row

    @ViewBuilder
    private var titleRow: some View {
        if displayState == .cancelled {
            Text(gymClass.name)
                .font(.system(size: 19, weight: .semibold))
                .tracking(-0.28)
                .foregroundColor(Color.dynamicText(theme: themeManager.currentTheme).opacity(0.5))
                .strikethrough(true, color: Color.dynamicText(theme: themeManager.currentTheme).opacity(0.3))
                .lineLimit(1)
        } else {
            Text(gymClass.name)
                .font(.system(size: 19, weight: .semibold))
                .tracking(-0.28)
                .foregroundColor(Color.dynamicText(theme: themeManager.currentTheme).opacity(isMuted ? 0.7 : 1.0))
                .lineLimit(1)
        }
    }

    // MARK: - Cancellation Banner

    private func cancellationBanner(reason: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: "info.circle.fill")
                .font(.system(size: 12))
                .foregroundColor(Color(hex: "#FF5A5A")!)

            Text(reason)
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(Color(hex: "#FF5A5A")!)
                .lineLimit(2)

            Spacer()

            if isRegistered {
                Text("Reembolsada")
                    .font(.system(size: 9, weight: .bold))
                    .tracking(0.3)
                    .foregroundColor(Color(hex: "#4ADE80")!)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color(hex: "#4ADE80")!.opacity(0.14))
                    .clipShape(Capsule())
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(Color(hex: "#FF5A5A")!.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    // MARK: - Instructor Row

    private var instructorRow: some View {
        HStack(spacing: 10) {
            // Instructor avatar
            Text(instructorInitials)
                .font(.system(size: 9, weight: .bold))
                .foregroundColor(Color(hex: "#0A0A0A")!)
                .frame(width: 22, height: 22)
                .background(isMuted ? Color.dynamicText(theme: themeManager.currentTheme).opacity(0.2) : categoryColor)
                .clipShape(Circle())
                .saturation(isMuted ? 0.3 : 1.0)

            Text(gymClass.instructor)
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(Color.dynamicText(theme: themeManager.currentTheme).opacity(isMuted ? 0.5 : 0.7))
        }
    }

    // MARK: - Footer Row

    @ViewBuilder
    private var footerRow: some View {
        switch displayState {
        case .scheduled:
            scheduledFooter
        case .inProgress:
            inProgressFooter
        case .completedAttended:
            completedAttendedFooter
        case .completedNoShow:
            completedNoShowFooter
        case .cancelled:
            cancelledFooter
        }
    }

    // MARK: - Scheduled Footer

    private var scheduledFooter: some View {
        HStack {
            // Capacity bar + text
            HStack(spacing: 8) {
                capacityBar

                HStack(spacing: 0) {
                    Text("\(gymClass.currentParticipants)")
                        .foregroundColor(Color.dynamicText(theme: themeManager.currentTheme).opacity(0.7))
                    Text("/\(gymClass.maxParticipants)")
                        .foregroundColor(Color.dynamicText(theme: themeManager.currentTheme).opacity(0.3))
                }
                .font(.system(size: 11, weight: .semibold, design: .monospaced))
            }

            Spacer()

            // CTA
            scheduledCTA
        }
    }

    @ViewBuilder
    private var scheduledCTA: some View {
        if isRegistered {
            Text("RESERVADO")
                .font(.system(size: 11, weight: .bold))
                .tracking(0.6)
                .foregroundColor(accentColor)
        } else if isFull {
            Text("LLENO")
                .font(.system(size: 11, weight: .bold))
                .tracking(0.6)
                .foregroundColor(Color(hex: "#FF5A5A")!)
        } else {
            Button(action: onAction) {
                Image(systemName: "plus")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(Color.dynamicBackground(theme: themeManager.currentTheme))
                    .frame(width: 28, height: 28)
                    .background(Color.dynamicText(theme: themeManager.currentTheme))
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: - In Progress Footer

    private var inProgressFooter: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Progress bar
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 3)
                        .fill(Color.dynamicText(theme: themeManager.currentTheme).opacity(0.1))

                    RoundedRectangle(cornerRadius: 3)
                        .fill(accentColor)
                        .frame(width: geo.size.width * progressFraction)
                }
            }
            .frame(height: 4)

            // Time info
            HStack {
                Text("Empez\u{00F3} hace \(elapsedMinutes) min")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(Color.dynamicText(theme: themeManager.currentTheme).opacity(0.6))

                Text("\u{00B7}")
                    .foregroundColor(Color.dynamicText(theme: themeManager.currentTheme).opacity(0.3))

                Text("\(remainingMinutes) min restantes")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(accentColor)

                Spacer()

                Text("\(Int(progressFraction * 100))%")
                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                    .foregroundColor(accentColor)
            }
        }
    }

    // MARK: - Completed Attended Footer

    private var completedAttendedFooter: some View {
        HStack {
            // Rating stars (empty)
            HStack(spacing: 2) {
                ForEach(0..<5, id: \.self) { _ in
                    Image(systemName: "star")
                        .font(.system(size: 12))
                        .foregroundColor(Color.dynamicText(theme: themeManager.currentTheme).opacity(0.3))
                }
            }

            Text("Sin calificar")
                .font(.system(size: 11))
                .foregroundColor(Color.dynamicText(theme: themeManager.currentTheme).opacity(0.4))

            Spacer()

            // Review button
            Button(action: onAction) {
                HStack(spacing: 4) {
                    Text("Dejar review")
                        .font(.system(size: 11, weight: .semibold))
                    Image(systemName: "chevron.right")
                        .font(.system(size: 9, weight: .bold))
                }
                .foregroundColor(accentColor)
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: - Completed No Show Footer

    private var completedNoShowFooter: some View {
        HStack {
            Text("Termin\u{00F3} hace \(hoursSinceEnd)h")
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(Color.dynamicText(theme: themeManager.currentTheme).opacity(0.5))

            Spacer()

            // "Reservar similar" button
            Button(action: onAction) {
                HStack(spacing: 4) {
                    Image(systemName: "arrow.triangle.2.circlepath")
                        .font(.system(size: 10, weight: .semibold))
                    Text("Reservar similar")
                        .font(.system(size: 11, weight: .semibold))
                }
                .foregroundColor(Color.dynamicText(theme: themeManager.currentTheme).opacity(0.7))
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: - Cancelled Footer

    private var cancelledFooter: some View {
        HStack {
            Text("Notificado a participantes")
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(Color.dynamicText(theme: themeManager.currentTheme).opacity(0.4))

            Spacer()

            if isRegistered {
                Text("Reembolsada")
                    .font(.system(size: 9, weight: .bold))
                    .tracking(0.3)
                    .foregroundColor(Color(hex: "#4ADE80")!)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color(hex: "#4ADE80")!.opacity(0.14))
                    .clipShape(Capsule())
            }
        }
    }

    // MARK: - Capacity Bar

    private var capacityBar: some View {
        HStack(spacing: 3) {
            ForEach(0..<8, id: \.self) { index in
                let cellPct = CGFloat(index + 1) / 8.0 * 100
                let pct = capacityFraction * 100
                let isFilled = cellPct <= pct + 6

                RoundedRectangle(cornerRadius: 1)
                    .fill(isFilled ? capacityCellColor : Color.dynamicSurface2(theme: themeManager.currentTheme))
                    .frame(height: 5)
            }
        }
        .frame(maxWidth: 120)
    }

    private var capacityCellColor: Color {
        if isFull { return Color(hex: "#FF5A5A")! }
        if capacityFraction > 0.85 { return Color(hex: "#FFB347")! }
        return categoryColor
    }

    // MARK: - Styles

    private var cardBackground: some ShapeStyle {
        switch displayState {
        case .inProgress:
            return AnyShapeStyle(
                LinearGradient(
                    colors: [
                        accentColor.opacity(0.08),
                        Color.dynamicSurface(theme: themeManager.currentTheme)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
        case .scheduled where isRegistered:
            return AnyShapeStyle(
                LinearGradient(
                    colors: [
                        accentColor.opacity(0.14),
                        Color.dynamicSurface(theme: themeManager.currentTheme)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
        default:
            return AnyShapeStyle(Color.dynamicSurface(theme: themeManager.currentTheme))
        }
    }

    private var cardBorder: Color {
        switch displayState {
        case .inProgress:
            return accentColor.opacity(0.4)
        case .scheduled where isRegistered:
            return accentColor.opacity(0.4)
        default:
            return Color.white.opacity(0.08)
        }
    }
}

// MARK: - Pulsing Dot (In Progress indicator)

private struct PulsingDot: View {
    let color: Color
    @State private var isAnimating = false

    var body: some View {
        Circle()
            .fill(color)
            .frame(width: 6, height: 6)
            .scaleEffect(isAnimating ? 1.3 : 1.0)
            .opacity(isAnimating ? 0.6 : 1.0)
            .animation(
                .easeInOut(duration: 1.0).repeatForever(autoreverses: true),
                value: isAnimating
            )
            .onAppear { isAnimating = true }
    }
}

// MARK: - Cancelled Stripe Pattern

private struct CancelledStripePattern: View {
    let color: Color

    var body: some View {
        GeometryReader { geo in
            Canvas { context, size in
                let stripeWidth: CGFloat = 3
                let spacing: CGFloat = 4
                let totalWidth = stripeWidth + spacing

                var y: CGFloat = -size.width
                while y < size.height + size.width {
                    var path = Path()
                    path.move(to: CGPoint(x: 0, y: y))
                    path.addLine(to: CGPoint(x: size.width, y: y + size.width))
                    path.addLine(to: CGPoint(x: size.width, y: y + size.width + stripeWidth))
                    path.addLine(to: CGPoint(x: 0, y: y + stripeWidth))
                    path.closeSubpath()

                    context.fill(path, with: .color(color.opacity(0.3)))
                    y += totalWidth
                }
            }
        }
    }
}

// MARK: - Cancelled Diagonal Overlay

private struct CancelledDiagonalOverlay: View {
    var body: some View {
        GeometryReader { geo in
            Canvas { context, size in
                let spacing: CGFloat = 12
                var y: CGFloat = -size.width
                while y < size.height + size.width {
                    var path = Path()
                    path.move(to: CGPoint(x: 0, y: y))
                    path.addLine(to: CGPoint(x: size.width, y: y + size.width))
                    context.stroke(
                        path,
                        with: .color(Color.white.opacity(0.03)),
                        lineWidth: 1
                    )
                    y += spacing
                }
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 22))
    }
}
