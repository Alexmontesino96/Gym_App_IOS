//
//  MinimalClassCardView.swift
//  Gym_API
//
//  Diseño minimalista inspirado en Mindbody para tarjetas de clases
//

import SwiftUI

// MARK: - Simplified Class States
enum MinimalClassState {
    case available
    case booked
    case full
    case live

    var buttonText: String {
        switch self {
        case .available: return "Book"
        case .booked: return "Booked"
        case .full: return "Full"
        case .live: return "Join"
        }
    }

    var buttonIcon: String? {
        switch self {
        case .booked: return "checkmark"
        case .live: return "dot.radiowaves.left.and.right"
        default: return nil
        }
    }

    var isActionable: Bool {
        switch self {
        case .available, .live, .booked: return true
        case .full: return false
        }
    }
}

// MARK: - Instructor Avatar Component
struct MinimalInstructorAvatar: View {
    let imageURL: String?
    let size: CGFloat
    @EnvironmentObject var themeManager: ThemeManager

    var body: some View {
        AsyncImage(url: URL(string: imageURL ?? "")) { phase in
            switch phase {
            case .success(let image):
                image
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: size, height: size)
                    .clipShape(Circle())
            case .failure(_), .empty:
                Circle()
                    .fill(Color.dynamicSurface(theme: themeManager.currentTheme))
                    .frame(width: size, height: size)
                    .overlay(
                        Image(systemName: "person.fill")
                            .font(.system(size: size * 0.4))
                            .foregroundColor(Color.dynamicTextSecondary(theme: themeManager.currentTheme))
                    )
            @unknown default:
                ProgressView()
                    .frame(width: size, height: size)
            }
        }
        .overlay(
            Circle()
                .stroke(Color.dynamicBorder(theme: themeManager.currentTheme).opacity(0.2), lineWidth: 1)
        )
    }
}

// MARK: - Simplified Book Button
struct MinimalBookButton: View {
    let state: MinimalClassState
    let isLoading: Bool
    let action: () -> Void
    @EnvironmentObject var themeManager: ThemeManager
    @State private var isPressed = false

    private var backgroundColor: Color {
        if !state.isActionable {
            return Color.dynamicSurface(theme: themeManager.currentTheme)
        }

        switch state {
        case .available, .live:
            return Color(red: 0.44, green: 0.81, blue: 0.25) // Verde Mindbody #6FCF3F
        case .booked:
            return Color.dynamicSurface(theme: themeManager.currentTheme)
        default:
            return Color.dynamicSurface(theme: themeManager.currentTheme)
        }
    }

    private var foregroundColor: Color {
        switch state {
        case .available, .live:
            return .white
        case .booked:
            return Color(red: 0.44, green: 0.81, blue: 0.25) // Verde para estado booked
        case .full:
            return Color.dynamicTextSecondary(theme: themeManager.currentTheme)
        }
    }

    private var borderColor: Color {
        switch state {
        case .booked:
            return Color(red: 0.44, green: 0.81, blue: 0.25).opacity(0.3)
        case .full:
            return Color.dynamicBorder(theme: themeManager.currentTheme).opacity(0.2)
        default:
            return Color.clear
        }
    }

    var body: some View {
        Button(action: {
            if state.isActionable && !isLoading {
                action()
            }
        }) {
            HStack(spacing: 4) {
                if isLoading {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle())
                        .tint(foregroundColor)
                        .scaleEffect(0.8)
                } else if let icon = state.buttonIcon {
                    Image(systemName: icon)
                        .font(.system(size: 12, weight: .semibold))
                }

                Text(isLoading ? "Loading..." : state.buttonText)
                    .font(.system(size: 15, weight: .semibold))
            }
            .foregroundColor(foregroundColor)
            .frame(width: 85, height: 34)
            .background(backgroundColor)
            .overlay(
                RoundedRectangle(cornerRadius: 17)
                    .stroke(borderColor, lineWidth: borderColor == .clear ? 0 : 1.5)
            )
            .cornerRadius(17)
            .scaleEffect(isPressed ? 0.95 : 1.0)
        }
        .disabled(!state.isActionable || isLoading)
        .onLongPressGesture(minimumDuration: 0, maximumDistance: .infinity, pressing: { pressing in
            withAnimation(.easeInOut(duration: 0.1)) {
                isPressed = pressing
            }
        }, perform: {})
    }
}

// MARK: - Live Indicator Badge
struct MinimalLiveIndicator: View {
    @State private var isPulsing = false

    var body: some View {
        HStack(spacing: 3) {
            Circle()
                .fill(Color.red)
                .frame(width: 6, height: 6)
                .scaleEffect(isPulsing ? 1.2 : 1.0)
                .opacity(isPulsing ? 0.7 : 1.0)

            Text("LIVE")
                .font(.system(size: 10, weight: .bold))
                .foregroundColor(.red)
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 2)
        .background(
            Capsule()
                .fill(Color.red.opacity(0.1))
        )
        .onAppear {
            withAnimation(.easeInOut(duration: 1.0).repeatForever(autoreverses: true)) {
                isPulsing = true
            }
        }
    }
}

// MARK: - Main Minimal Class Card View
struct MinimalClassCardView: View {
    let gymClass: GymClass
    @EnvironmentObject var themeManager: ThemeManager
    @EnvironmentObject var classService: ClassService
    @StateObject private var gymService = GymService.shared

    @State private var trainerImageURL: String = ""
    @State private var isLoading = false

    // Computed properties
    private var currentState: MinimalClassState {
        let now = Date()

        // Check if class is cancelled
        if gymClass.status == .cancelled {
            return .full // Treat cancelled as full/unavailable
        }

        // Check if class is live
        if now >= gymClass.startTime && now <= gymClass.endTime {
            return .live
        }

        // Check if user is registered
        if classService.isUserRegistered(classId: gymClass.id) {
            return .booked
        }

        // Check if class is full
        if gymClass.currentParticipants >= gymClass.maxParticipants {
            return .full
        }

        return .available
    }

    private var formattedTime: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mma"
        formatter.amSymbol = "am"
        formatter.pmSymbol = "pm"

        let start = formatter.string(from: gymClass.startTime).lowercased()
        let end = formatter.string(from: gymClass.endTime).lowercased()

        return "\(start) - \(end)"
    }

    private var availabilityText: String {
        let spotsOpen = max(0, gymClass.maxParticipants - gymClass.currentParticipants)
        return "\(spotsOpen) of \(gymClass.maxParticipants) open"
    }

    private var availabilityColor: Color {
        let percentage = Double(gymClass.currentParticipants) / Double(gymClass.maxParticipants)

        if percentage >= 1.0 {
            return Color.gray
        } else if percentage >= 0.8 {
            return Color.red
        } else if percentage >= 0.5 {
            return Color.orange
        } else {
            return Color.green.opacity(0.8)
        }
    }

    var body: some View {
        HStack(spacing: 12) {
            // Instructor Avatar (left)
            MinimalInstructorAvatar(
                imageURL: trainerImageURL,
                size: 44
            )

            // Class Information (center)
            VStack(alignment: .leading, spacing: 3) {
                // Time row with live indicator
                HStack(spacing: 8) {
                    Text(formattedTime)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(Color.dynamicTextSecondary(theme: themeManager.currentTheme))

                    if currentState == .live {
                        MinimalLiveIndicator()
                    }
                }

                // Class name
                Text(gymClass.name)
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundColor(Color.dynamicText(theme: themeManager.currentTheme))
                    .lineLimit(1)

                // Instructor and availability
                HStack {
                    Text("w/ \(gymClass.instructor)")
                        .font(.system(size: 14))
                        .foregroundColor(Color.dynamicTextSecondary(theme: themeManager.currentTheme))
                        .lineLimit(1)

                    Spacer()

                    if currentState != .full {
                        Text(availabilityText)
                            .font(.system(size: 14))
                            .foregroundColor(availabilityColor)
                    }
                }
            }
            .frame(maxWidth: .infinity)

            // Action Button (right)
            MinimalBookButton(
                state: currentState,
                isLoading: isLoading || classService.joiningClassIds.contains(gymClass.id),
                action: handleButtonAction
            )
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 16)
        .background(Color.dynamicSurface(theme: themeManager.currentTheme))
        .onAppear {
            updateTrainerImage()
        }
        .onChange(of: classService.trainers.count) { _, _ in
            updateTrainerImage()
        }
    }

    // MARK: - Actions

    private func handleButtonAction() {
        switch currentState {
        case .available, .live:
            joinClass()
        case .booked:
            // Show action sheet for cancel option
            showBookedOptions()
        case .full:
            // No action
            break
        }
    }

    private func joinClass() {
        isLoading = true
        Task {
            await classService.joinClass(classId: gymClass.id)
            await MainActor.run {
                isLoading = false

                // Haptic feedback
                if #available(iOS 13.0, *) {
                    let impactFeedback = UIImpactFeedbackGenerator(style: .light)
                    impactFeedback.impactOccurred()
                }
            }
        }
    }

    private func cancelClass() {
        isLoading = true
        Task {
            await classService.cancelClassRegistration(
                classId: gymClass.id,
                reason: "User cancelled from app"
            )
            await MainActor.run {
                isLoading = false
            }
        }
    }

    private func showBookedOptions() {
        // In a real implementation, this would show an action sheet
        // For now, we'll just toggle the registration
        cancelClass()
    }

    private func updateTrainerImage() {
        Task {
            if let trainer = await classService.getTrainer(trainerId: gymClass.trainerId) {
                let pictureURL = trainer.picture ?? ""
                if !pictureURL.isEmpty, URL(string: pictureURL) != nil {
                    await MainActor.run {
                        self.trainerImageURL = pictureURL
                    }
                }
            }
        }
    }
}

// MARK: - Divider for List
struct MinimalClassDivider: View {
    @EnvironmentObject var themeManager: ThemeManager

    var body: some View {
        Rectangle()
            .fill(Color.dynamicBorder(theme: themeManager.currentTheme).opacity(0.15))
            .frame(height: 1)
            .padding(.leading, 72) // Align with content (16 + 44 + 12)
    }
}

// MARK: - Preview
#Preview {
    let sampleClass = GymClass(
        id: 1,
        name: "Lower Body",
        description: "Strength training focused on lower body",
        instructor: "Fabianna C.",
        trainerId: 1,
        startTime: Date().addingTimeInterval(3600),
        endTime: Date().addingTimeInterval(6300), // 1h 45min later
        maxParticipants: 36,
        currentParticipants: 30,
        difficulty: .intermediate,
        status: .available
    )

    VStack(spacing: 0) {
        MinimalClassCardView(gymClass: sampleClass)
        MinimalClassDivider()
        MinimalClassCardView(gymClass: GymClass(
            id: 2,
            name: "HIIT Training",
            description: "High intensity interval training",
            instructor: "Mike Johnson",
            trainerId: 2,
            startTime: Date().addingTimeInterval(-1800), // Live now
            endTime: Date().addingTimeInterval(1800),
            maxParticipants: 20,
            currentParticipants: 15,
            difficulty: .advanced,
            status: .available
        ))
        MinimalClassDivider()
        MinimalClassCardView(gymClass: GymClass(
            id: 3,
            name: "Yoga Flow",
            description: "Relaxing yoga session",
            instructor: "Sarah Lee",
            trainerId: 3,
            startTime: Date().addingTimeInterval(7200),
            endTime: Date().addingTimeInterval(10800),
            maxParticipants: 15,
            currentParticipants: 15, // Full
            difficulty: .beginner,
            status: .available
        ))
    }
    .background(Color(white: 0.95))
    .environmentObject(ThemeManager())
    .environmentObject(ClassService())
}