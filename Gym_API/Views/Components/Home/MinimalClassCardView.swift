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
    case registered  // Changed from booked for consistency
    case full
    case live
    case completed(wasRegistered: Bool)
    case attended
    case cancelled

    var buttonText: String {
        switch self {
        case .available: return "Join"
        case .registered: return "Registered"
        case .full: return "Full"
        case .live: return "Live"
        case .completed(let wasRegistered):
            return wasRegistered ? "Great Job!" : "Missed"
        case .attended: return "Attended"
        case .cancelled: return "Cancelled"
        }
    }

    var buttonIcon: String? {
        switch self {
        case .available: return "plus.circle.fill"
        case .registered: return "checkmark.circle.fill"
        case .full: return "person.2.fill"
        case .live: return "dot.radiowaves.left.and.right"
        case .completed(let wasRegistered):
            return wasRegistered ? "trophy.fill" : "clock.badge.xmark"
        case .attended: return "checkmark.seal.fill"
        case .cancelled: return "xmark.circle.fill"
        }
    }

    var isActionable: Bool {
        switch self {
        case .available, .live, .registered: return true
        case .full, .cancelled, .completed, .attended: return false
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
                    .fill(Color(white: 0.95))
                    .frame(width: size, height: size)
                    .overlay(
                        Image(systemName: "person.fill")
                            .font(.system(size: size * 0.45))
                            .foregroundColor(Color(white: 0.7))
                    )
            @unknown default:
                ProgressView()
                    .frame(width: size, height: size)
            }
        }
        .overlay(
            Circle()
                .stroke(Color(white: 0.9), lineWidth: 0.5)
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
            switch state {
            case .attended:
                return Color.green.opacity(0.1)
            case .completed(let wasRegistered):
                return wasRegistered ? Color.dynamicAccent(theme: themeManager.currentTheme).opacity(0.1) : Color.dynamicSurface(theme: themeManager.currentTheme)
            default:
                return Color.dynamicSurface(theme: themeManager.currentTheme)
            }
        }

        switch state {
        case .available, .live:
            return Color.dynamicAccent(theme: themeManager.currentTheme)
        case .registered:
            return Color.dynamicSurface(theme: themeManager.currentTheme)
        default:
            return Color.dynamicSurface(theme: themeManager.currentTheme)
        }
    }

    private var foregroundColor: Color {
        switch state {
        case .available, .live:
            return .white
        case .registered:
            return Color.dynamicAccent(theme: themeManager.currentTheme)
        case .attended:
            return Color.green
        case .completed(let wasRegistered):
            return wasRegistered ? Color.dynamicAccent(theme: themeManager.currentTheme) : Color.dynamicTextSecondary(theme: themeManager.currentTheme)
        case .full:
            return Color.dynamicTextSecondary(theme: themeManager.currentTheme)
        case .cancelled:
            return Color.red.opacity(0.8)
        }
    }

    private var borderColor: Color {
        switch state {
        case .registered:
            return Color.dynamicAccent(theme: themeManager.currentTheme).opacity(0.3)
        case .attended:
            return Color.green.opacity(0.3)
        case .completed(let wasRegistered):
            return wasRegistered ? Color.dynamicAccent(theme: themeManager.currentTheme).opacity(0.2) : Color.clear
        case .full:
            return Color.dynamicBorder(theme: themeManager.currentTheme).opacity(0.2)
        case .available, .live, .cancelled:
            return Color.clear
        }
    }

    var body: some View {
        Button(action: {
            if state.isActionable && !isLoading {
                // Haptic feedback based on action
                let impactStyle: UIImpactFeedbackGenerator.FeedbackStyle
                switch state {
                case .available, .live:
                    impactStyle = .medium
                case .registered:
                    impactStyle = .light
                default:
                    impactStyle = .soft
                }
                let impactFeedback = UIImpactFeedbackGenerator(style: impactStyle)
                impactFeedback.impactOccurred()

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
                        .font(.system(size: 14, weight: .semibold))
                }

                Text(isLoading ? "Loading..." : state.buttonText)
                    .font(.system(size: 16, weight: .semibold))
            }
            .foregroundColor(foregroundColor)
            .frame(width: 120, height: 44)
            .background(backgroundColor)
            .overlay(
                RoundedRectangle(cornerRadius: 22)
                    .stroke(borderColor, lineWidth: borderColor == .clear ? 0 : 1.5)
            )
            .cornerRadius(22)
            .scaleEffect(isPressed ? 0.94 : 1.0)
            .animation(.spring(response: 0.3, dampingFraction: 0.6), value: isPressed)
            .shadow(color: state.isActionable ? Color.black.opacity(0.08) : Color.clear, radius: 3, x: 0, y: 2)
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

        // Check if class is cancelled - Show explicitly
        if gymClass.status == .cancelled {
            return .cancelled
        }

        // Check if class is in the past
        if now > gymClass.endTime {
            // Check if user attended
            if classService.attendedClassIds.contains(gymClass.id) {
                return .attended
            }
            // Check if user was registered
            let wasRegistered = classService.isUserRegistered(classId: gymClass.id)
            return .completed(wasRegistered: wasRegistered)
        }

        // Check if class is live
        if now >= gymClass.startTime && now <= gymClass.endTime {
            return .live
        }

        // Check if user is registered
        if classService.isUserRegistered(classId: gymClass.id) {
            return .registered
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

    private var formattedTimeSimple: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mma"
        formatter.amSymbol = "am"
        formatter.pmSymbol = "pm"
        return formatter.string(from: gymClass.startTime).lowercased()
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

    private var difficultyColor: Color {
        switch gymClass.difficulty {
        case .beginner:
            return Color.green.opacity(0.8)
        case .intermediate:
            return Color.orange.opacity(0.8)
        case .advanced:
            return Color.red.opacity(0.8)
        }
    }

    private var difficultyText: String {
        switch gymClass.difficulty {
        case .beginner: return "Beginner level"
        case .intermediate: return "Intermediate level"
        case .advanced: return "Advanced level"
        }
    }

    var body: some View {
        HStack(spacing: 14) {
            // Instructor Avatar
            MinimalInstructorAvatar(
                imageURL: trainerImageURL,
                size: 56
            )

            // Class Information
            VStack(alignment: .leading, spacing: 3) {
                // Time row with live indicator
                HStack(spacing: 6) {
                    Text(formattedTime)
                        .font(.system(size: 15, weight: .medium))
                        .foregroundColor(Color.dynamicText(theme: themeManager.currentTheme))

                    if currentState == .live {
                        MinimalLiveIndicator()
                    }
                }

                // Class name with difficulty indicator
                HStack(spacing: 4) {
                    Text(gymClass.name)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(Color.dynamicText(theme: themeManager.currentTheme))
                        .lineLimit(1)
                        .truncationMode(.tail)

                    // Difficulty indicator
                    Circle()
                        .fill(difficultyColor)
                        .frame(width: 6, height: 6)
                        .accessibilityLabel(difficultyText)
                }

                // Location
                if let location = gymService.currentGym?.address {
                    Text(location)
                        .font(.system(size: 14, weight: .regular))
                        .foregroundColor(Color.dynamicTextSecondary(theme: themeManager.currentTheme).opacity(0.8))
                        .lineLimit(1)
                        .truncationMode(.tail)
                }

                // Availability info
                let spotsRemaining = max(0, gymClass.maxParticipants - gymClass.currentParticipants)
                switch currentState {
                case .full:
                    Text("Class Full")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(Color.red)
                case .available, .live, .registered:
                    HStack(spacing: 4) {
                        Text("\(spotsRemaining)")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(availabilityColor)
                        Text("spots available")
                            .font(.system(size: 14, weight: .regular))
                            .foregroundColor(Color.dynamicTextSecondary(theme: themeManager.currentTheme).opacity(0.8))
                    }
                case .attended:
                    Text("You attended this class")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(Color.green)
                case .completed(let wasRegistered):
                    if wasRegistered {
                        Text("Class completed")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(Color.dynamicTextSecondary(theme: themeManager.currentTheme))
                    }
                case .cancelled:
                    Text("Class was cancelled")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(Color.red.opacity(0.8))
                }

                // Instructor info
                Text("w/ \(gymClass.instructor)")
                    .font(.system(size: 14, weight: .regular))
                    .foregroundColor(Color.dynamicTextSecondary(theme: themeManager.currentTheme).opacity(0.8))
                    .lineLimit(1)
                    .truncationMode(.tail)
            }
            .frame(maxWidth: .infinity)

            // Action Button (right) - Más grande como en Mindbody
            MinimalBookButton(
                state: currentState,
                isLoading: isLoading || classService.joiningClassIds.contains(gymClass.id),
                action: handleButtonAction
            )
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 16)
        .background(Color.dynamicSurface(theme: themeManager.currentTheme))
        // Accessibility
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(gymClass.name) class with \(gymClass.instructor). \(difficultyText)")
        .accessibilityHint("\(availabilityText). Status: \(currentState.buttonText). \(currentState.isActionable ? "Tap to take action" : "Not available for booking")")
        .accessibilityAddTraits(currentState.isActionable ? .isButton : .isStaticText)
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
        case .registered:
            // Show action sheet for cancel option
            showBookedOptions()
        case .full, .cancelled, .completed, .attended:
            // No action for these states
            break
        }
    }

    private func joinClass() {
        isLoading = true
        Task {
            let success = await classService.joinClass(classId: gymClass.id)
            await MainActor.run {
                isLoading = false

                // Haptic feedback based on result
                if success {
                    let notificationFeedback = UINotificationFeedbackGenerator()
                    notificationFeedback.notificationOccurred(.success)
                } else {
                    let notificationFeedback = UINotificationFeedbackGenerator()
                    notificationFeedback.notificationOccurred(.error)
                }
            }
        }
    }

    private func cancelClass() {
        isLoading = true
        Task {
            let success = await classService.cancelClassRegistration(
                classId: gymClass.id,
                reason: "User cancelled from app"
            )
            await MainActor.run {
                isLoading = false

                // Haptic feedback for cancellation
                if success {
                    let notificationFeedback = UINotificationFeedbackGenerator()
                    notificationFeedback.notificationOccurred(.warning)
                }
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
            .fill(Color(white: 0.92))
            .frame(height: 0.5)
            .padding(.leading, 100) // Align with content after avatar (24 + 60 + 16)
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