import SwiftUI

// MARK: - ClassDetailView
/// Detailed class view matching prototype: hero gradient, stats card, instructor, CTA
struct ClassDetailView: View {
    let gymClass: GymClass

    @EnvironmentObject var themeManager: ThemeManager
    @EnvironmentObject var classService: ClassService
    @EnvironmentObject var gymService: GymService
    @Environment(\.dismiss) private var dismiss

    @State private var isJoining = false
    @State private var isCancelling = false

    private let accentColor = Color(hex: "#D4FF3F")!

    // MARK: - Computed

    private var category: ClassCategory {
        ClassCategoryHelper.category(for: gymClass)
    }

    private var categoryColor: Color {
        category.color
    }

    private var isRegistered: Bool {
        classService.userRegistrationStatus[gymClass.id] ?? false
    }

    private var isFull: Bool {
        gymClass.currentParticipants >= gymClass.maxParticipants
    }

    private var durationMinutes: Int {
        let interval = gymClass.endTime.timeIntervalSince(gymClass.startTime)
        return max(Int(interval / 60), 1)
    }

    private var timeRange: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return "\(formatter.string(from: gymClass.startTime)) – \(formatter.string(from: gymClass.endTime))"
    }

    private var instructorInitials: String {
        let parts = gymClass.instructor.components(separatedBy: " ")
        return parts.prefix(2).compactMap { $0.first }.map { String($0).uppercased() }.joined()
    }

    private var difficultyLabel: String {
        switch gymClass.difficulty {
        case .beginner: return "Principiante"
        case .intermediate: return "Intermedio"
        case .advanced: return "Avanzado"
        }
    }

    // MARK: - Body

    var body: some View {
        ZStack(alignment: .bottom) {
            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: 0) {
                    // Hero
                    heroSection

                    // Stats card (overlapping)
                    statsCard
                        .padding(.horizontal, 20)
                        .offset(y: -32)

                    // Instructor
                    instructorSection
                        .padding(.horizontal, 20)
                        .padding(.top, -8)

                    // Description
                    if let description = gymClass.description, !description.isEmpty {
                        descriptionSection(description)
                            .padding(.horizontal, 20)
                            .padding(.top, 24)
                    }

                    // Schedule info
                    scheduleSection
                        .padding(.horizontal, 20)
                        .padding(.top, 24)

                    Spacer(minLength: 120)
                }
            }

            // CTA
            ctaButton
        }
        .background(Color.dynamicBackground(theme: themeManager.currentTheme))
        .navigationBarHidden(true)
    }

    // MARK: - Hero Section

    private var heroSection: some View {
        ZStack(alignment: .top) {
            // Gradient background
            LinearGradient(
                colors: [categoryColor, categoryColor.opacity(0.4), Color(hex: "#0A0A0A")!],
                startPoint: UnitPoint(x: 0, y: 0),
                endPoint: UnitPoint(x: 1, y: 1)
            )
            .frame(height: 280)
            .clipShape(
                UnevenRoundedRectangle(bottomLeadingRadius: 32, bottomTrailingRadius: 32)
            )

            // Top buttons
            HStack {
                Button(action: { dismiss() }) {
                    Image(systemName: "arrow.left")
                        .font(.system(size: 18))
                        .foregroundColor(.white)
                        .frame(width: 40, height: 40)
                        .background(Color.black.opacity(0.3))
                        .clipShape(Circle())
                }

                Spacer()

                Button(action: {}) {
                    Image(systemName: "bookmark")
                        .font(.system(size: 18))
                        .foregroundColor(.white)
                        .frame(width: 40, height: 40)
                        .background(Color.black.opacity(0.3))
                        .clipShape(Circle())
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 8)

            // Bottom content on hero
            VStack(alignment: .leading, spacing: 0) {
                Spacer()

                // Chips
                HStack(spacing: 6) {
                    Text(category.label)
                        .font(.system(size: 10, weight: .bold))
                        .tracking(0.8)
                        .foregroundColor(categoryColor)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(Color.black.opacity(0.5))
                        .clipShape(Capsule())

                    Text(difficultyLabel.uppercased())
                        .font(.system(size: 10, weight: .bold))
                        .tracking(0.6)
                        .foregroundColor(.white.opacity(0.8))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(Color.black.opacity(0.5))
                        .clipShape(Capsule())
                }
                .padding(.bottom, 12)

                // Title
                Text(gymClass.name)
                    .font(.system(size: 36, weight: .bold))
                    .tracking(-1.4)
                    .foregroundColor(Color(hex: "#0A0A0A")!)
                    .padding(.bottom, 48)
            }
            .padding(.horizontal, 20)
            .frame(height: 280, alignment: .bottom)
        }
    }

    // MARK: - Stats Card

    private var statsCard: some View {
        HStack(spacing: 0) {
            // Duration
            statColumn(value: "\(durationMinutes)", label: "min", icon: "clock")

            // Divider
            Rectangle()
                .fill(Color.white.opacity(0.08))
                .frame(width: 1, height: 40)

            // Capacity
            statColumn(value: "\(gymClass.currentParticipants)/\(gymClass.maxParticipants)", label: "plazas", icon: "person.2")

            // Divider
            Rectangle()
                .fill(Color.white.opacity(0.08))
                .frame(width: 1, height: 40)

            // Time
            statColumn(value: timeRange, label: "horario", icon: "calendar")
        }
        .padding(.vertical, 16)
        .background(Color.dynamicSurface(theme: themeManager.currentTheme))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.white.opacity(0.08), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.4), radius: 16, y: 6)
    }

    private func statColumn(value: String, label: String, icon: String) -> some View {
        VStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 14))
                .foregroundColor(accentColor)

            Text(value)
                .font(.system(size: 14, weight: .bold, design: .monospaced))
                .foregroundColor(Color.dynamicText(theme: themeManager.currentTheme))
                .lineLimit(1)
                .minimumScaleFactor(0.7)

            Text(label)
                .font(.system(size: 10))
                .foregroundColor(Color.dynamicText(theme: themeManager.currentTheme).opacity(0.5))
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Instructor Section

    private var instructorSection: some View {
        HStack(spacing: 14) {
            // Avatar
            Text(instructorInitials)
                .font(.system(size: 18, weight: .bold))
                .foregroundColor(.white)
                .frame(width: 48, height: 48)
                .background(
                    LinearGradient(
                        colors: [categoryColor, categoryColor.opacity(0.6)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .clipShape(Circle())

            VStack(alignment: .leading, spacing: 4) {
                Text(gymClass.instructor)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(Color.dynamicText(theme: themeManager.currentTheme))

                Text("Instructor")
                    .font(.system(size: 12))
                    .foregroundColor(Color.dynamicText(theme: themeManager.currentTheme).opacity(0.5))
            }

            Spacer()
        }
        .padding(16)
        .background(Color.dynamicSurface(theme: themeManager.currentTheme))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.white.opacity(0.08), lineWidth: 1)
        )
    }

    // MARK: - Description

    private func descriptionSection(_ text: String) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("DESCRIPCIÓN")
                .font(.system(size: 9, weight: .bold))
                .tracking(1.0)
                .foregroundColor(Color.dynamicText(theme: themeManager.currentTheme).opacity(0.5))

            Text(text)
                .font(.system(size: 14))
                .foregroundColor(Color.dynamicText(theme: themeManager.currentTheme).opacity(0.7))
                .lineSpacing(4)
        }
    }

    // MARK: - Schedule Info

    private var scheduleSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("HORARIO")
                .font(.system(size: 9, weight: .bold))
                .tracking(1.0)
                .foregroundColor(Color.dynamicText(theme: themeManager.currentTheme).opacity(0.5))

            VStack(spacing: 0) {
                scheduleRow(icon: "clock", label: "Hora", value: timeRange)
                scheduleRow(icon: "timer", label: "Duración", value: "\(durationMinutes) min")
                scheduleRow(icon: "person.2", label: "Capacidad", value: "\(gymClass.currentParticipants)/\(gymClass.maxParticipants)", isLast: true)
            }
            .background(Color.dynamicSurface(theme: themeManager.currentTheme))
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(Color.white.opacity(0.08), lineWidth: 1)
            )
        }
    }

    private func scheduleRow(icon: String, label: String, value: String, isLast: Bool = false) -> some View {
        VStack(spacing: 0) {
            HStack {
                Image(systemName: icon)
                    .font(.system(size: 14))
                    .foregroundColor(accentColor)
                    .frame(width: 24)

                Text(label)
                    .font(.system(size: 13))
                    .foregroundColor(Color.dynamicText(theme: themeManager.currentTheme).opacity(0.5))

                Spacer()

                Text(value)
                    .font(.system(size: 13, weight: .semibold, design: .monospaced))
                    .foregroundColor(Color.dynamicText(theme: themeManager.currentTheme))
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)

            if !isLast {
                Rectangle()
                    .fill(Color.white.opacity(0.08))
                    .frame(height: 1)
            }
        }
    }

    // MARK: - CTA Button

    private var ctaButton: some View {
        VStack {
            if isRegistered {
                // Show QR / Cancel
                HStack(spacing: 12) {
                    Button(action: {}) {
                        HStack(spacing: 8) {
                            Image(systemName: "qrcode")
                                .font(.system(size: 18))
                            Text("Mostrar QR")
                                .font(.system(size: 16, weight: .semibold))
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .foregroundColor(Color.accentInk)
                        .background(accentColor)
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                    }

                    Button(action: cancelRegistration) {
                        Image(systemName: "xmark")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(Color(hex: "#FF5A5A")!)
                            .frame(width: 52, height: 52)
                            .background(Color.dynamicSurface(theme: themeManager.currentTheme))
                            .overlay(
                                RoundedRectangle(cornerRadius: 14)
                                    .stroke(Color(hex: "#FF5A5A")!.opacity(0.3), lineWidth: 1)
                            )
                            .clipShape(RoundedRectangle(cornerRadius: 14))
                    }
                    .disabled(isCancelling)
                }
            } else if isFull {
                Text("Clase completa")
                    .font(.system(size: 16, weight: .semibold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .foregroundColor(Color.dynamicText(theme: themeManager.currentTheme).opacity(0.5))
                    .background(Color.dynamicSurface(theme: themeManager.currentTheme))
                    .overlay(
                        RoundedRectangle(cornerRadius: 14)
                            .stroke(Color.white.opacity(0.08), lineWidth: 1)
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 14))
            } else {
                Button(action: joinClass) {
                    HStack(spacing: 8) {
                        Image(systemName: "checkmark")
                            .font(.system(size: 18, weight: .semibold))
                        Text("Confirmar Reserva")
                            .font(.system(size: 16, weight: .semibold))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .foregroundColor(Color.accentInk)
                    .background(accentColor)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                }
                .disabled(isJoining)
            }
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 32)
        .padding(.top, 16)
        .background(
            LinearGradient(
                colors: [
                    Color.dynamicBackground(theme: themeManager.currentTheme),
                    Color.dynamicBackground(theme: themeManager.currentTheme),
                    Color.dynamicBackground(theme: themeManager.currentTheme).opacity(0)
                ],
                startPoint: .bottom,
                endPoint: .top
            )
        )
    }

    // MARK: - Actions

    private func joinClass() {
        HapticManager.shared.buttonTap()
        isJoining = true
        Task {
            await classService.joinClass(sessionId: gymClass.id)
            isJoining = false
            HapticManager.shared.play(.success)
        }
    }

    private func cancelRegistration() {
        HapticManager.shared.buttonTap()
        isCancelling = true
        Task {
            await classService.cancelClassRegistration(sessionId: gymClass.id, reason: nil)
            isCancelling = false
        }
    }
}
