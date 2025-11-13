import SwiftUI

/// Instagram-style post card for the social feed
struct MinimalPostCard: View {
    let post: Post
    let theme: ThemeManager.AppTheme

    @State private var showDoubleTapHeart = false
    @State private var heartScale: CGFloat = 0.5
    @State private var isLiking = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Divider superior
            Divider()
                .background(Color.gray.opacity(0.3))

            // Header (avatar + nombre + ubicación)
            headerView
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(Color.dynamicBackground(theme: theme))

            // Media gallery
            if !post.media.isEmpty {
                mediaGalleryView
            }

            // Sección inferior con fondo
            VStack(alignment: .leading, spacing: 0) {
                // Botones de acción (like, comment, share)
                actionButtonsView
                    .padding(.horizontal, 16)
                    .padding(.top, 14)

                // Contador de likes
                if post.likeCount > 0 {
                    likesCountView
                        .padding(.horizontal, 16)
                        .padding(.top, 4)
                }

                // Caption con username en negrita
                if let caption = post.caption, !caption.isEmpty {
                    captionView
                        .padding(.horizontal, 16)
                        .padding(.top, 4)
                }

                // Botón "ver comentarios"
                if post.commentCount > 0 {
                    viewCommentsButton
                        .padding(.horizontal, 16)
                        .padding(.top, 6)
                }

                // Ubicación
                if let location = post.location, !location.isEmpty {
                    locationView
                        .padding(.horizontal, 16)
                        .padding(.top, 4)
                }

                // Tiempo transcurrido
                timeView
                    .padding(.horizontal, 16)
                    .padding(.top, 8)
                    .padding(.bottom, 16)
            }
            .background(Color.dynamicBackground(theme: theme))

            // Divider inferior
            Divider()
                .background(Color.gray.opacity(0.3))
        }
    }

    // MARK: - Header View

    private var headerView: some View {
        HStack(spacing: 12) {
            // Avatar del usuario
            if let profilePictureURL = post.user.profilePictureURL {
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
                        )
                }
                .frame(width: 32, height: 32)
                .clipShape(Circle())
            } else {
                Circle()
                    .fill(Color.gray.opacity(0.3))
                    .frame(width: 32, height: 32)
                    .overlay(
                        Image(systemName: "person.fill")
                            .foregroundColor(.gray)
                    )
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(post.user.fullName)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(Color.dynamicText(theme: theme))

                if let location = post.location {
                    Text(location)
                        .font(.system(size: 12))
                        .foregroundColor(.gray)
                        .lineLimit(1)
                }
            }

            Spacer()

            // Botón de opciones
            Image(systemName: "ellipsis")
                .font(.system(size: 20))
                .foregroundColor(Color.dynamicText(theme: theme))
                .frame(width: 24, height: 24)
        }
    }

    // MARK: - Media Gallery View

    private var mediaGalleryView: some View {
        ZStack {
            PostMediaGallery(mediaItems: post.media, theme: theme)

            // Double-tap like heart animation
            if showDoubleTapHeart {
                Image(systemName: "heart.fill")
                    .font(.system(size: 100))
                    .foregroundColor(.white)
                    .shadow(color: .black.opacity(0.3), radius: 10, x: 0, y: 0)
                    .scaleEffect(heartScale)
                    .opacity(showDoubleTapHeart ? 1 : 0)
                    .animation(.spring(response: 0.3, dampingFraction: 0.6), value: heartScale)
            }
        }
        .onTapGesture(count: 2) {
            handleDoubleTapLike()
        }
    }

    // MARK: - Action Buttons View

    private var actionButtonsView: some View {
        HStack(spacing: 16) {
            // Like button
            Image(systemName: post.hasLiked ? "heart.fill" : "heart")
                .font(.system(size: 24))
                .foregroundColor(post.hasLiked ? .red : Color.dynamicText(theme: theme))

            // Comment button
            Image(systemName: "bubble.right")
                .font(.system(size: 24))
                .foregroundColor(Color.dynamicText(theme: theme))

            // Share button
            Image(systemName: "paperplane")
                .font(.system(size: 24))
                .foregroundColor(Color.dynamicText(theme: theme))

            Spacer()

            // Gallery indicator
            if post.media.count > 1 {
                Text("1/\(post.media.count)")
                    .font(.system(size: 12))
                    .foregroundColor(.gray)
            }
        }
    }

    // MARK: - Likes Count View

    private var likesCountView: some View {
        Text(likesText)
            .font(.system(size: 14, weight: .semibold))
            .foregroundColor(Color.dynamicText(theme: theme))
    }

    private var likesText: String {
        if post.likeCount == 1 {
            return "1 me gusta"
        } else {
            return "\(post.likeCount) me gusta"
        }
    }

    // MARK: - Caption View

    private var captionView: some View {
        HStack(alignment: .top, spacing: 4) {
            // Username en negrita
            Text(post.user.fullName)
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(Color.dynamicText(theme: theme))

            // Caption texto
            Text(post.caption ?? "")
                .font(.system(size: 14))
                .foregroundColor(Color.dynamicText(theme: theme))
                .lineLimit(3)

            Spacer()
        }
    }

    // MARK: - View Comments Button

    private var viewCommentsButton: some View {
        Text(commentsText)
            .font(.system(size: 14))
            .foregroundColor(Color.dynamicTextSecondary(theme: theme))
    }

    private var commentsText: String {
        if post.commentCount == 1 {
            return "Ver el comentario"
        } else {
            return "Ver los \(post.commentCount) comentarios"
        }
    }

    // MARK: - Location View

    private var locationView: some View {
        HStack(spacing: 4) {
            Image(systemName: "location.fill")
                .font(.system(size: 10))
            Text(post.location ?? "")
                .font(.system(size: 12))
        }
        .foregroundColor(.gray)
    }

    // MARK: - Time View

    private var timeView: some View {
        Text(post.relativeTime.uppercased())
            .font(.system(size: 10))
            .foregroundColor(.gray)
    }

    // MARK: - Double-Tap Like

    private func handleDoubleTapLike() {
        let impact = UIImpactFeedbackGenerator(style: .medium)
        impact.impactOccurred()

        showHeartAnimation()

        // Note: Actual like functionality would need PostService integration
        // For now just show animation
    }

    private func showHeartAnimation() {
        showDoubleTapHeart = true
        heartScale = 0.5

        withAnimation(.spring(response: 0.4, dampingFraction: 0.6)) {
            heartScale = 1.3
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            withAnimation(.easeOut(duration: 0.3)) {
                heartScale = 1.5
            }
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            withAnimation(.easeOut(duration: 0.2)) {
                showDoubleTapHeart = false
                heartScale = 0.5
            }
        }
    }
}
