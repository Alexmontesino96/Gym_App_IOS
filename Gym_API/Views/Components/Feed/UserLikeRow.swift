import SwiftUI

/// Componente de fila para mostrar un usuario que dio like
struct UserLikeRow: View {
    @EnvironmentObject var themeManager: ThemeManager

    let likeItem: LikeItem

    var body: some View {
        HStack(spacing: 12) {
            // Avatar
            avatarView

            // Información del usuario
            VStack(alignment: .leading, spacing: 2) {
                Text(likeItem.user.fullName)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(Color.dynamicText(theme: themeManager.currentTheme))

                Text(likeItem.relativeTime)
                    .font(.system(size: 13))
                    .foregroundColor(Color.dynamicTextSecondary(theme: themeManager.currentTheme))
            }

            Spacer()

            // Indicador de like
            Image(systemName: "heart.fill")
                .font(.system(size: 16))
                .foregroundColor(.red)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .contentShape(Rectangle())
    }

    // MARK: - Avatar View

    private var avatarView: some View {
        Group {
            if let profilePictureURL = likeItem.user.profilePictureURL {
                AsyncImage(url: profilePictureURL) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } placeholder: {
                    Circle()
                        .fill(Color.gray.opacity(0.3))
                        .overlay(
                            Image(systemName: "person.fill")
                                .foregroundColor(.gray)
                                .font(.system(size: 16))
                        )
                }
                .frame(width: 40, height: 40)
                .clipShape(Circle())
            } else {
                Circle()
                    .fill(Color.gray.opacity(0.3))
                    .frame(width: 40, height: 40)
                    .overlay(
                        Image(systemName: "person.fill")
                            .foregroundColor(.gray)
                            .font(.system(size: 16))
                    )
            }
        }
    }
}

// MARK: - Preview

#Preview {
    let sampleLikeItem = LikeItem(
        id: 1,
        postId: 1,
        commentId: nil,
        userId: 1,
        createdAt: Date().addingTimeInterval(-3600),
        user: UserPreview(
            id: 1,
            fullName: "María García",
            profilePictureUrl: "https://picsum.photos/100/100",
            role: "member"
        )
    )

    ScrollView {
        VStack(spacing: 0) {
            UserLikeRow(likeItem: sampleLikeItem)
                .environmentObject(ThemeManager())

            Divider()

            UserLikeRow(
                likeItem: LikeItem(
                    id: 2,
                    postId: 1,
                    commentId: nil,
                    userId: 2,
                    createdAt: Date().addingTimeInterval(-7200),
                    user: UserPreview(
                        id: 2,
                        fullName: "Juan Pérez",
                        profilePictureUrl: nil,
                        role: "member"
                    )
                )
            )
            .environmentObject(ThemeManager())
        }
    }
}
