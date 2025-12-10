import SwiftUI

// MARK: - Member Profile Preview Sheet
/// Sheet que muestra el perfil del miembro antes de confirmar check-in
struct MemberProfilePreviewSheet: View {
    let profile: UserPublicProfile
    let availableSessions: [SessionWithClass]
    let preSelectedSessionId: Int?
    let onConfirm: (Int?) -> Void
    let onCancel: () -> Void

    @EnvironmentObject var themeManager: ThemeManager
    @State private var selectedSessionId: Int?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // Avatar
                    MemberAvatarView(
                        pictureURL: profile.picture,
                        initials: profile.initials,
                        size: 120,
                        color: profile.color
                    )

                    // Nombre
                    VStack(spacing: 8) {
                        Text(profile.fullName)
                            .font(.system(size: 24, weight: .bold))
                            .foregroundColor(Color.dynamicText(theme: themeManager.currentTheme))

                        if let bio = profile.bio, !bio.isEmpty {
                            Text(bio)
                                .font(.system(size: 15))
                                .foregroundColor(Color.dynamicTextSecondary(theme: themeManager.currentTheme))
                                .multilineTextAlignment(.center)
                                .lineLimit(2)
                        }
                    }
                    .padding(.horizontal, 32)

                    // Info Card
                    VStack(spacing: 16) {
                        InfoRow(
                            icon: "person.circle.fill",
                            text: "ID: U\(profile.id)",
                            theme: themeManager.currentTheme
                        )

                        InfoRow(
                            icon: "checkmark.shield.fill",
                            text: profile.statusText,
                            iconColor: profile.statusColor == "green" ? .green : .gray,
                            theme: themeManager.currentTheme
                        )

                        InfoRow(
                            icon: "star.circle.fill",
                            text: profile.displayRole,
                            theme: themeManager.currentTheme
                        )
                    }
                    .padding(20)
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(Color.dynamicCard(theme: themeManager.currentTheme))
                    )
                    .padding(.horizontal, 20)

                    // Pregunta de confirmación
                    Text("¿Hacer check-in para esta persona?")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundColor(Color.dynamicText(theme: themeManager.currentTheme))
                        .padding(.top, 8)

                    // Session selector (si hay 2 sesiones Y no hay pre-selección)
                    if availableSessions.count == 2 && preSelectedSessionId == nil {
                        VStack(spacing: 12) {
                            Text("Selecciona la clase:")
                                .font(.system(size: 15, weight: .medium))
                                .foregroundColor(Color.dynamicTextSecondary(theme: themeManager.currentTheme))

                            ForEach(availableSessions) { session in
                                SessionRadioButton(
                                    session: session,
                                    isSelected: selectedSessionId == session.session.id,
                                    onSelect: { selectedSessionId = session.session.id }
                                )
                            }
                        }
                        .padding(16)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color.dynamicSurface(theme: themeManager.currentTheme))
                        )
                        .padding(.horizontal, 20)
                    }

                    // Botones
                    VStack(spacing: 12) {
                        // Confirmar
                        Button(action: {
                            let sessionId = preSelectedSessionId ?? selectedSessionId
                            onConfirm(sessionId)
                        }) {
                            Text("Confirmar Check-in")
                                .font(.system(size: 17, weight: .semibold))
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 16)
                                .background(
                                    RoundedRectangle(cornerRadius: 12)
                                        .fill(Color.dynamicAccent(theme: themeManager.currentTheme))
                                )
                        }
                        .disabled(availableSessions.count == 2 && preSelectedSessionId == nil && selectedSessionId == nil)
                        .opacity((availableSessions.count == 2 && preSelectedSessionId == nil && selectedSessionId == nil) ? 0.5 : 1.0)

                        // Cancelar
                        Button(action: onCancel) {
                            Text("Cancelar")
                                .font(.system(size: 17, weight: .medium))
                                .foregroundColor(Color.dynamicTextSecondary(theme: themeManager.currentTheme))
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 16)
                                .background(
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(Color.dynamicTextSecondary(theme: themeManager.currentTheme), lineWidth: 1)
                                )
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 32)
                }
                .padding(.top, 20)
            }
            .background(Color.dynamicBackground(theme: themeManager.currentTheme))
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }
}

// MARK: - Supporting Views

struct InfoRow: View {
    let icon: String
    let text: String
    var iconColor: Color?
    let theme: ThemeManager.AppTheme

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 18))
                .foregroundColor(iconColor ?? Color.dynamicAccent(theme: theme))

            Text(text)
                .font(.system(size: 15, weight: .medium))
                .foregroundColor(Color.dynamicText(theme: theme))

            Spacer()
        }
    }
}

struct SessionRadioButton: View {
    let session: SessionWithClass
    let isSelected: Bool
    let onSelect: () -> Void

    @EnvironmentObject var themeManager: ThemeManager

    var body: some View {
        Button(action: onSelect) {
            HStack(spacing: 12) {
                // Radio circle
                ZStack {
                    Circle()
                        .stroke(
                            isSelected
                                ? Color.dynamicAccent(theme: themeManager.currentTheme)
                                : Color.dynamicTextSecondary(theme: themeManager.currentTheme),
                            lineWidth: 2
                        )
                        .frame(width: 20, height: 20)

                    if isSelected {
                        Circle()
                            .fill(Color.dynamicAccent(theme: themeManager.currentTheme))
                            .frame(width: 12, height: 12)
                    }
                }

                // Session info
                VStack(alignment: .leading, spacing: 4) {
                    Text(session.classInfo.name)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(Color.dynamicText(theme: themeManager.currentTheme))

                    Text(session.formattedTime)
                        .font(.system(size: 14))
                        .foregroundColor(Color.dynamicTextSecondary(theme: themeManager.currentTheme))
                }

                Spacer()
            }
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(
                        isSelected
                            ? Color.dynamicAccent(theme: themeManager.currentTheme).opacity(0.1)
                            : Color.clear
                    )
            )
        }
    }
}

// MARK: - Member Avatar View
struct MemberAvatarView: View {
    let pictureURL: String?
    let initials: String
    let size: CGFloat
    let color: String?

    var body: some View {
        ZStack {
            if let urlString = pictureURL, let url = URL(string: urlString) {
                // Avatar con foto
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .empty:
                        Circle()
                            .fill(Color(hex: color ?? "#D93333") ?? Color.gray)
                            .overlay(
                                ProgressView()
                                    .tint(.white)
                            )
                    case .success(let image):
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                    case .failure:
                        // Fallback a iniciales
                        Circle()
                            .fill(Color(hex: color ?? "#D93333") ?? Color.gray)
                            .overlay(
                                Text(initials)
                                    .font(.system(size: size * 0.4, weight: .bold))
                                    .foregroundColor(.white)
                            )
                    @unknown default:
                        EmptyView()
                    }
                }
                .frame(width: size, height: size)
                .clipShape(Circle())
            } else {
                // Avatar con iniciales
                Circle()
                    .fill(Color(hex: color ?? "#D93333") ?? Color.gray)
                    .overlay(
                        Text(initials)
                            .font(.system(size: size * 0.4, weight: .bold))
                            .foregroundColor(.white)
                    )
                    .frame(width: size, height: size)
            }
        }
        .shadow(color: Color.black.opacity(0.1), radius: 8, x: 0, y: 4)
    }
}

// MARK: - Previews
#if DEBUG
struct MemberProfilePreviewSheet_Previews: PreviewProvider {
    static var previews: some View {
        MemberProfilePreviewSheet(
            profile: UserPublicProfile.preview,
            availableSessions: [],
            preSelectedSessionId: nil,
            onConfirm: { _ in },
            onCancel: { }
        )
        .environmentObject(ThemeManager())
    }
}
#endif
