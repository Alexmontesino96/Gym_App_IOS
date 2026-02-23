import SwiftUI

/// Celda de grid para mostrar un post en formato thumbnail (estilo Instagram)
/// Optimizado: Usa thumbnails del backend y caché integrado
struct PostGridCell: View {
    let post: Post

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .topTrailing) {
                // Thumbnail del post - Usa FeedOptimizedImage para máxima performance
                if let firstMedia = post.media.sorted(by: { $0.displayOrder < $1.displayOrder }).first {
                    FeedOptimizedImage(
                        thumbnailUrl: firstMedia.thumbnailUrl,  // Prioriza thumbnail del backend
                        fullUrl: firstMedia.mediaUrl,
                        displaySize: CGSize(width: geometry.size.width, height: geometry.size.height),
                        contentMode: .fill,
                        cornerRadius: 0
                    )
                } else {
                    // Placeholder si no hay media
                    Rectangle()
                        .fill(Color.gray.opacity(0.3))
                        .overlay(
                            Image(systemName: "photo")
                                .font(.system(size: 30))
                                .foregroundColor(.gray.opacity(0.5))
                        )
                }

                // Indicador de galería (si tiene múltiples imágenes)
                if post.media.count > 1 {
                    Image(systemName: "square.stack.fill")
                        .font(.system(size: 16))
                        .foregroundColor(.white)
                        .padding(8)
                        .shadow(color: .black.opacity(0.3), radius: 2)
                }
            }
        }
        .aspectRatio(1, contentMode: .fill)
        .clipped()
        .contentShape(Rectangle())
    }
}

// MARK: - Preview

#Preview {
    let samplePost = Post(
        id: 1,
        userId: 1,
        gymId: 1,
        caption: "Sample post",
        postType: .gallery,
        privacy: .public,
        location: "Gym",
        likeCount: 10,
        commentCount: 5,
        viewCount: 50,
        shareCount: 2,
        isEdited: false,
        isDeleted: false,
        createdAt: Date(),
        updatedAt: Date(),
        editedAt: nil,
        workoutData: nil,
        media: [
            PostMedia(
                id: 1,
                postId: 1,
                mediaType: .image,
                mediaUrl: "https://picsum.photos/400/400",
                thumbnailUrl: "https://picsum.photos/200/200",
                displayOrder: 0,
                width: 400,
                height: 400,
                fileSize: 102400,
                durationSeconds: nil
            )
        ],
        tags: [],
        user: UserPreview(
            id: 1,
            fullName: "Test User",
            profilePictureUrl: nil,
            role: "member"
        ),
        hasLiked: false,
        isOwnPost: true
    )

    PostGridCell(post: samplePost)
        .frame(width: 120, height: 120)
}
