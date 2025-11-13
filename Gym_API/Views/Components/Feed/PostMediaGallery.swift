//
//  PostMediaGallery.swift
//  Gym_API
//
//  Created by Claude Code
//  Minimal media gallery component with page indicators
//

import SwiftUI

struct PostMediaGallery: View {
    let mediaItems: [PostMedia]
    let theme: ThemeManager.AppTheme

    @State private var currentIndex = 0

    var body: some View {
        ZStack(alignment: .bottom) {
            TabView(selection: $currentIndex) {
                ForEach(Array(mediaItems.enumerated()), id: \.offset) { index, media in
                    AsyncImage(url: URL(string: media.mediaUrl)) { image in
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                    } placeholder: {
                        Rectangle()
                            .fill(Color.dynamicSurface(theme: theme))
                            .overlay(
                                ProgressView()
                                    .tint(Color.dynamicAccent(theme: theme))
                            )
                    }
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
        .frame(height: calculateHeight(for: UIScreen.main.bounds.width))
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
