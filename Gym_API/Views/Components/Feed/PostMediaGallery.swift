//
//  PostMediaGallery.swift
//  Gym_API
//
//  Created by Claude Code
//  Minimal media gallery component with page indicators
//

import SwiftUI

/// Galería de medios optimizada para posts del feed
/// Usa FeedOptimizedImage para thumbnails, caché y downscaling automático
struct PostMediaGallery: View {
    let mediaItems: [PostMedia]
    let theme: ThemeManager.AppTheme

    @State private var currentIndex = 0

    private var screenWidth: CGFloat {
        UIScreen.main.bounds.width
    }

    private var galleryHeight: CGFloat {
        calculateHeight(for: screenWidth)
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            TabView(selection: $currentIndex) {
                ForEach(Array(mediaItems.enumerated()), id: \.offset) { index, media in
                    // Usa FeedOptimizedImage para carga optimizada con caché
                    FeedOptimizedImage(
                        thumbnailUrl: media.thumbnailUrl,  // Thumbnail del backend
                        fullUrl: media.mediaUrl,
                        displaySize: CGSize(width: screenWidth, height: galleryHeight),
                        contentMode: .fit,
                        cornerRadius: 0
                    )
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .tag(index)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))

            // Page Indicators (solo si hay más de 1 imagen)
            if mediaItems.count > 1 {
                HStack(spacing: 4) {
                    ForEach(0..<mediaItems.count, id: \.self) { index in
                        Circle()
                            .fill(currentIndex == index ? Color.white : Color.white.opacity(0.4))
                            .frame(width: 6, height: 6)
                    }
                }
                .padding(.bottom, 12)
            }
        }
        .frame(height: galleryHeight)
        .clipped()
    }
}

extension PostMediaGallery {
    /// Calcula la altura basada en el aspect ratio del primer media, con límites tipo Instagram
    fileprivate func calculateHeight(for width: CGFloat) -> CGFloat {
        guard let first = mediaItems.first,
              let w = first.width, let h = first.height, w > 0, h > 0 else {
            // Fallback si no hay dimensiones disponibles
            return 375
        }

        let aspect = CGFloat(w) / CGFloat(h)
        let minAspect: CGFloat = 0.8   // 4:5 portrait
        let maxAspect: CGFloat = 1.91  // 1.91:1 landscape
        let clamped = min(max(aspect, minAspect), maxAspect)
        let computed = width / clamped

        let maxH: CGFloat = UIScreen.main.bounds.height * 0.7
        let minH: CGFloat = 200
        return min(max(computed, minH), maxH)
    }
}
