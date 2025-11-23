import SwiftUI
import UIKit

/// Avatar image with primary URL and automatic fallback URL handling.
/// Uses ImageCacheManager to share cache with Stories viewer.
struct AvatarAsyncImage: View {
    let primaryURL: String?
    let fallbackURL: String?
    let size: CGFloat

    @StateObject private var loader = AvatarImageLoader()

    var body: some View {
        Group {
            if let image = loader.image {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } else {
                // Placeholder shown while loading or on error if no fallback available
                Circle()
                    .fill(Color.gray.opacity(0.3))
                    .overlay(
                        Image(systemName: "person.fill")
                            .font(.system(size: 28))
                            .foregroundColor(.white)
                    )
            }
        }
        .frame(width: size, height: size)
        .task {
            await loader.load(primaryURL: primaryURL, fallbackURL: fallbackURL)
        }
    }
}

@MainActor
private final class AvatarImageLoader: ObservableObject {
    @Published var image: UIImage?
    private let cache = ImageCacheManager.shared
    private var task: Task<Void, Never>?

    func load(primaryURL: String?, fallbackURL: String?) async {
        task?.cancel()
        image = nil

        let p = primaryURL?.trimmingCharacters(in: .whitespacesAndNewlines)
        let f = fallbackURL?.trimmingCharacters(in: .whitespacesAndNewlines)

        task = Task { [weak self] in
            guard let self else { return }

            // Try primary
            if let primary = p, !primary.isEmpty {
                if let cached = cache.cachedImage(for: primary) {
                    self.image = cached
                    return
                }
                if let downloaded = await cache.downloadImage(from: primary) {
                    self.image = downloaded
                    return
                }
            }

            // Try fallback
            if let fallback = f, !fallback.isEmpty {
                if let cached = cache.cachedImage(for: fallback) {
                    self.image = cached
                    return
                }
                if let downloaded = await cache.downloadImage(from: fallback) {
                    self.image = downloaded
                    return
                }
            }
        }

        await task?.value
    }

    deinit { task?.cancel() }
}

