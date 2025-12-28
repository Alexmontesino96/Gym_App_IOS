import SwiftUI

// MARK: - ParticipantAvatarStack

/// Stack de avatares para mostrar participantes de un challenge
/// Muestra hasta N avatares superpuestos y un contador para el resto
struct ParticipantAvatarStack: View {
    // MARK: - Properties

    let participantsCount: Int
    let avatarUrls: [String]?
    let maxAvatars: Int
    let avatarSize: CGFloat

    @EnvironmentObject var themeManager: ThemeManager

    // MARK: - Initialization

    init(
        participantsCount: Int,
        avatarUrls: [String]? = nil,
        maxAvatars: Int = 3,
        avatarSize: CGFloat = 32
    ) {
        self.participantsCount = participantsCount
        self.avatarUrls = avatarUrls
        self.maxAvatars = maxAvatars
        self.avatarSize = avatarSize
    }

    // MARK: - Body

    var body: some View {
        HStack(spacing: -avatarSize * 0.25) {
            // Mostrar avatares
            ForEach(0..<min(maxAvatars, participantsCount), id: \.self) { index in
                avatarView(at: index)
            }

            // Mostrar contador si hay mas participantes
            if participantsCount > maxAvatars {
                counterView
            }
        }
    }

    // MARK: - Private Views

    @ViewBuilder
    private func avatarView(at index: Int) -> some View {
        if let urls = avatarUrls, index < urls.count, !urls[index].isEmpty {
            // Avatar con imagen
            AsyncImage(url: URL(string: urls[index])) { phase in
                switch phase {
                case .success(let image):
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                case .failure, .empty:
                    placeholderAvatar(index: index)
                @unknown default:
                    placeholderAvatar(index: index)
                }
            }
            .frame(width: avatarSize, height: avatarSize)
            .clipShape(Circle())
            .overlay(
                Circle()
                    .stroke(Color.dynamicBackground(theme: themeManager.currentTheme), lineWidth: 2)
            )
        } else {
            // Avatar placeholder
            placeholderAvatar(index: index)
        }
    }

    private func placeholderAvatar(index: Int) -> some View {
        Circle()
            .fill(avatarColor(for: index))
            .frame(width: avatarSize, height: avatarSize)
            .overlay(
                Image(systemName: "person.fill")
                    .font(.system(size: avatarSize * 0.4))
                    .foregroundColor(.white.opacity(0.8))
            )
            .overlay(
                Circle()
                    .stroke(Color.dynamicBackground(theme: themeManager.currentTheme), lineWidth: 2)
            )
    }

    private var counterView: some View {
        ZStack {
            Circle()
                .fill(Color.dynamicSurface(theme: themeManager.currentTheme))

            Text("+\(participantsCount - maxAvatars)")
                .font(.system(size: avatarSize * 0.35, weight: .semibold))
                .foregroundColor(Color.dynamicText(theme: themeManager.currentTheme))
        }
        .frame(width: avatarSize, height: avatarSize)
        .overlay(
            Circle()
                .stroke(Color.dynamicBackground(theme: themeManager.currentTheme), lineWidth: 2)
        )
    }

    // MARK: - Helpers

    private func avatarColor(for index: Int) -> Color {
        let colors: [Color] = [
            Color.dynamicAccent(theme: themeManager.currentTheme),
            .blue,
            .green,
            .orange,
            .purple
        ]
        return colors[index % colors.count]
    }
}

// MARK: - ParticipantCountLabel

/// Etiqueta que muestra el numero de participantes con icono
struct ParticipantCountLabel: View {
    let count: Int
    let showIcon: Bool

    @EnvironmentObject var themeManager: ThemeManager

    init(count: Int, showIcon: Bool = true) {
        self.count = count
        self.showIcon = showIcon
    }

    var body: some View {
        HStack(spacing: 4) {
            if showIcon {
                Image(systemName: "person.2.fill")
                    .font(.system(size: 12, weight: .medium))
            }
            Text("\(count)")
                .font(.system(size: 14, weight: .semibold))
        }
        .foregroundColor(Color.dynamicTextSecondary(theme: themeManager.currentTheme))
    }
}

// MARK: - ParticipantsRow

/// Fila completa con avatares y contador de participantes
struct ParticipantsRow: View {
    let participantsCount: Int
    let avatarUrls: [String]?
    let text: String?

    @EnvironmentObject var themeManager: ThemeManager

    init(
        participantsCount: Int,
        avatarUrls: [String]? = nil,
        text: String? = nil
    ) {
        self.participantsCount = participantsCount
        self.avatarUrls = avatarUrls
        self.text = text
    }

    var body: some View {
        HStack(spacing: 12) {
            ParticipantAvatarStack(
                participantsCount: participantsCount,
                avatarUrls: avatarUrls
            )
            .environmentObject(themeManager)

            if let text = text {
                Text(text)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(Color.dynamicTextSecondary(theme: themeManager.currentTheme))
            } else {
                Text("\(participantsCount) participante\(participantsCount == 1 ? "" : "s")")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(Color.dynamicTextSecondary(theme: themeManager.currentTheme))
            }
        }
    }
}

// MARK: - Preview

#Preview {
    VStack(spacing: 30) {
        // Avatar Stack variations
        VStack(spacing: 16) {
            Text("Avatar Stacks")
                .font(.headline)
                .foregroundColor(.white)

            HStack(spacing: 40) {
                ParticipantAvatarStack(participantsCount: 2)
                ParticipantAvatarStack(participantsCount: 5)
                ParticipantAvatarStack(participantsCount: 150)
            }

            ParticipantAvatarStack(
                participantsCount: 10,
                maxAvatars: 5,
                avatarSize: 40
            )
        }

        Divider()

        // Count Labels
        VStack(spacing: 12) {
            Text("Count Labels")
                .font(.headline)
                .foregroundColor(.white)

            HStack(spacing: 20) {
                ParticipantCountLabel(count: 5)
                ParticipantCountLabel(count: 128)
                ParticipantCountLabel(count: 1000, showIcon: false)
            }
        }

        Divider()

        // Participants Row
        VStack(spacing: 12) {
            Text("Participants Row")
                .font(.headline)
                .foregroundColor(.white)

            ParticipantsRow(participantsCount: 45)
            ParticipantsRow(participantsCount: 128, text: "personas activas")
        }
    }
    .padding()
    .background(Color.black)
    .environmentObject(ThemeManager())
}
