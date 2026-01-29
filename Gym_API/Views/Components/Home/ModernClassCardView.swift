import SwiftUI

// MARK: - Modern Class Card View (Inspired by Reference Design)
struct ModernClassCardView: View {
    @EnvironmentObject var themeManager: ThemeManager
    @EnvironmentObject var gymService: GymService
    let gymClass: GymClass

    @State private var trainerImageURL: String = ""
    @State private var isLoading = false

    // Access classService from environment
    @EnvironmentObject private var classService: ClassService

    // Computed state
    private var currentState: ClassActionState {
        let now = Date()

        // Check if class is cancelled
        if gymClass.status == .cancelled {
            return .cancelled
        }

        // Check if class is in the past
        if now > gymClass.endTime {
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
        formatter.dateFormat = "h:mm a"
        formatter.amSymbol = "AM"
        formatter.pmSymbol = "PM"
        return formatter.string(from: gymClass.startTime)
    }

    var body: some View {
        HStack(spacing: 16) {
            // Left side content
            VStack(alignment: .leading, spacing: 8) {
                // Class name
                Text(gymClass.name)
                    .font(.system(size: 24, weight: .semibold))
                    .foregroundColor(Color.dynamicText(theme: themeManager.currentTheme))
                    .lineLimit(1)

                // Time
                Text(formattedTime)
                    .font(.system(size: 18, weight: .regular))
                    .foregroundColor(Color.dynamicTextSecondary(theme: themeManager.currentTheme))

                // Instructor
                Text("\(gymClass.instructor.hasPrefix("Coach") || gymClass.instructor.hasPrefix("Manager") ? "" : "Coach ")\(gymClass.instructor)")
                    .font(.system(size: 16, weight: .regular))
                    .foregroundColor(Color.dynamicTextSecondary(theme: themeManager.currentTheme).opacity(0.9))
                    .lineLimit(1)

                // Location if available
                if let location = gymService.currentGym?.address {
                    Text(location)
                        .font(.system(size: 14, weight: .regular))
                        .foregroundColor(Color.dynamicTextSecondary(theme: themeManager.currentTheme).opacity(0.7))
                        .lineLimit(1)
                }

                Spacer(minLength: 8)

                // Action button or status
                actionView
            }

            Spacer()

            // Right side - Trainer image (square)
            trainerAvatar
        }
        .padding(20)
        .frame(height: 160)
        .background(Color.dynamicCard(theme: themeManager.currentTheme))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .onAppear {
            updateTrainerImage()
        }
        .onChange(of: classService.trainers.count) { _, _ in
            updateTrainerImage()
        }
    }

    @ViewBuilder
    private var actionView: some View {
        switch currentState {
        case .registered:
            // Green checkmark for registered
            HStack {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 24, weight: .medium))
                    .foregroundColor(Color.green)
                Text("Registered")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(Color.green)
            }

        case .available:
            // Join button
            HStack {
                Spacer()
                Button(action: joinClass) {
                    Text("Join")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(width: 100, height: 44)
                        .background(Color.red.opacity(0.9))
                        .clipShape(RoundedRectangle(cornerRadius: 22))
                }
                .disabled(isLoading)
            }

        case .full:
            // Full status
            HStack {
                Image(systemName: "exclamationmark.circle.fill")
                    .font(.system(size: 20, weight: .medium))
                    .foregroundColor(Color.orange)
                Text("Full")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(Color.orange)
            }

        case .live:
            // Live indicator
            HStack {
                LivePulse()
                Text("Live Now")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(Color.red)
            }

        case .completed(let wasRegistered):
            // Completed status
            HStack {
                Image(systemName: wasRegistered ? "checkmark.circle" : "clock")
                    .font(.system(size: 20, weight: .medium))
                    .foregroundColor(Color.gray)
                Text(wasRegistered ? "Attended" : "Past")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(Color.gray)
            }

        case .cancelled:
            // Cancelled status
            HStack {
                Image(systemName: "xmark.circle")
                    .font(.system(size: 20, weight: .medium))
                    .foregroundColor(Color.red.opacity(0.7))
                Text("Cancelled")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(Color.red.opacity(0.7))
            }

        default:
            EmptyView()
        }
    }

    private var trainerAvatar: some View {
        Group {
            if let url = URL(string: trainerImageURL), !trainerImageURL.isEmpty {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: 100, height: 100) // Square frame
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                    case .failure(_), .empty:
                        defaultAvatar
                    @unknown default:
                        defaultAvatar
                    }
                }
            } else {
                defaultAvatar
            }
        }
    }

    private var defaultAvatar: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.dynamicSurface(theme: themeManager.currentTheme))
                .frame(width: 100, height: 100) // Square frame

            Image(systemName: "person.fill")
                .font(.system(size: 40))
                .foregroundColor(Color.dynamicTextSecondary(theme: themeManager.currentTheme).opacity(0.5))
        }
    }


    // MARK: - Actions

    private func joinClass() {
        guard !isLoading else { return }
        isLoading = true

        Task {
            await classService.joinClass(classId: gymClass.id)
            await MainActor.run {
                isLoading = false

                // Haptic feedback
                let impactFeedback = UIImpactFeedbackGenerator(style: .light)
                impactFeedback.impactOccurred()
            }
        }
    }

    private func updateTrainerImage() {
        // First try to find trainer in loaded trainers
        if let trainer = classService.trainers.first(where: { $0.id == gymClass.trainerId }) {
            if let picture = trainer.picture, !picture.isEmpty {
                trainerImageURL = picture
                return
            }
        }

        // Otherwise fetch trainer info
        Task {
            if let trainer = await classService.getTrainer(trainerId: gymClass.trainerId) {
                await MainActor.run {
                    if let picture = trainer.picture, !picture.isEmpty {
                        trainerImageURL = picture
                    }
                }
            }
        }
    }
}

// MARK: - Live Pulse Animation
struct LivePulse: View {
    @State private var isPulsing = false

    var body: some View {
        Circle()
            .fill(Color.red)
            .frame(width: 8, height: 8)
            .scaleEffect(isPulsing ? 1.3 : 1.0)
            .opacity(isPulsing ? 0.6 : 1.0)
            .animation(.easeInOut(duration: 1.0).repeatForever(autoreverses: true), value: isPulsing)
            .onAppear {
                isPulsing = true
            }
    }
}