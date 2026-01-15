//
//  InstagramStoryImageView.swift
//  Gym_API
//
//  Instagram-style image view with intelligent scaling and cropping
//

import SwiftUI

// MARK: - InstagramStoryImageView
/// Componente de imagen para historias con formato Instagram
/// Maneja el escalado inteligente y recorte dentro del contenedor 9:16
struct InstagramStoryImageView: View {

    // MARK: - Properties

    let imageURL: String?
    let localImage: UIImage?
    var displayMode: StoryDimensions.ImageDisplayMode = .smart

    @State private var loadedImage: UIImage?
    @State private var isLoading = false
    @State private var imageSize: CGSize = .zero

    // MARK: - Computed Properties

    private var currentImage: UIImage? {
        if let localImage = localImage {
            return localImage
        }
        return loadedImage
    }

    private var imageAspectRatio: CGFloat {
        guard imageSize.height > 0 else { return 1.0 }
        return imageSize.width / imageSize.height
    }

    private var contentMode: ContentMode {
        switch displayMode {
        case .fill:
            return .fill
        case .fit:
            return .fit
        case .smart:
            // Determine best mode based on image ratio
            if abs(imageAspectRatio - StoryDimensions.aspectRatio) < 0.1 {
                // Image is close to 9:16, use fill
                return .fill
            } else if imageAspectRatio > 1.0 {
                // Landscape image, use fit to avoid excessive cropping
                return .fit
            } else {
                // Portrait or square, use fill for better coverage
                return .fill
            }
        }
    }

    // MARK: - Body

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Background (for letterboxing when using .fit)
                backgroundView

                // Main image content
                if let image = currentImage {
                    Image(uiImage: image)
                        .resizable()
                        .aspectRatio(contentMode: contentMode)
                        .frame(width: geometry.size.width, height: geometry.size.height)
                        .clipped()
                        .onAppear {
                            updateImageSize(image)
                        }
                } else if let imageURL = imageURL {
                    // Remote image with loading state
                    remoteImageView(geometry: geometry)
                } else {
                    // Placeholder for no image
                    placeholderView
                }

                // Loading indicator
                if isLoading {
                    loadingIndicator
                }
            }
            .frame(width: geometry.size.width, height: geometry.size.height)
        }
    }

    // MARK: - Subviews

    private var backgroundView: some View {
        Rectangle()
            .fill(
                LinearGradient(
                    colors: [
                        Color.black,
                        Color.black.opacity(0.95)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
    }

    private func remoteImageView(geometry: GeometryProxy) -> some View {
        AsyncImage(url: URL(string: imageURL ?? "")) { phase in
            switch phase {
            case .empty:
                Color.clear
                    .onAppear { isLoading = true }

            case .success(let image):
                image
                    .resizable()
                    .aspectRatio(contentMode: contentMode)
                    .frame(width: geometry.size.width, height: geometry.size.height)
                    .clipped()
                    .onAppear {
                        isLoading = false
                        // Capture image for size calculation
                        captureImageSize(from: imageURL ?? "")
                    }

            case .failure(_):
                failureView
                    .onAppear { isLoading = false }

            @unknown default:
                EmptyView()
            }
        }
    }

    private var placeholderView: some View {
        VStack(spacing: 20) {
            Image(systemName: "photo.fill")
                .font(.system(size: 60))
                .foregroundColor(.gray.opacity(0.5))

            Text("No hay imagen")
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(.gray.opacity(0.7))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var failureView: some View {
        VStack(spacing: 20) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 60))
                .foregroundColor(.red.opacity(0.7))

            Text("Error al cargar imagen")
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(.gray.opacity(0.7))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var loadingIndicator: some View {
        ProgressView()
            .progressViewStyle(CircularProgressViewStyle(tint: .white))
            .scaleEffect(1.5)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color.black.opacity(0.3))
    }

    // MARK: - Helper Methods

    private func updateImageSize(_ image: UIImage) {
        imageSize = CGSize(
            width: image.size.width,
            height: image.size.height
        )
    }

    private func captureImageSize(from urlString: String) {
        guard let url = URL(string: urlString) else { return }

        URLSession.shared.dataTask(with: url) { data, _, _ in
            guard let data = data,
                  let image = UIImage(data: data) else { return }

            DispatchQueue.main.async {
                self.imageSize = CGSize(
                    width: image.size.width,
                    height: image.size.height
                )
            }
        }.resume()
    }
}

// MARK: - Story Container Modifier

extension View {
    /// Aplica el contenedor de historia con aspect ratio 9:16
    func storyImageContainer() -> some View {
        self
            .aspectRatio(StoryDimensions.aspectRatio, contentMode: .fit)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .clipped()
            .background(Color.black)
    }
}

// MARK: - Preview

#Preview("Story Image - Portrait") {
    InstagramStoryImageView(
        imageURL: "https://picsum.photos/1080/1920",
        localImage: nil
    )
    .storyImageContainer()
    .frame(height: 600)
}

#Preview("Story Image - Landscape") {
    InstagramStoryImageView(
        imageURL: "https://picsum.photos/1920/1080",
        localImage: nil
    )
    .storyImageContainer()
    .frame(height: 600)
}

#Preview("Story Image - Square") {
    InstagramStoryImageView(
        imageURL: "https://picsum.photos/1080/1080",
        localImage: nil
    )
    .storyImageContainer()
    .frame(height: 600)
}