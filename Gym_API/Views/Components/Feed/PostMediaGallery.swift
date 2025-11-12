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

    /// Calcula la altura ideal basada en el aspect ratio de la primera imagen
    /// Respeta el aspect ratio original pero con límites sensatos (como Instagram)
    private func calculateHeight(for width: CGFloat) -> CGFloat {
        guard let firstMedia = mediaItems.first,
              let mediaWidth = firstMedia.width,
              let mediaHeight = firstMedia.height,
              mediaWidth > 0 else {
            // Fallback a altura fija si no hay dimensiones
            return SocialFeedLayout.mediaHeight
        }

        // Calcular aspect ratio original
        let aspectRatio = CGFloat(mediaWidth) / CGFloat(mediaHeight)

        // Límites de Instagram:
        // - Portrait mínimo: 4:5 (0.8) - imágenes más altas que anchas
        // - Landscape máximo: 1.91:1 (1.91) - imágenes muy anchas
        // - Cuadrado: 1:1 (1.0)
        let minAspectRatio: CGFloat = 0.8  // 4:5 portrait
        let maxAspectRatio: CGFloat = 1.91 // 1.91:1 landscape

        // Limitar el aspect ratio
        let clampedAspectRatio = min(max(aspectRatio, minAspectRatio), maxAspectRatio)

        // Calcular altura basada en el aspect ratio limitado
        let calculatedHeight = width / clampedAspectRatio

        // Limitar altura máxima absoluta para evitar posts demasiado largos
        let maxHeight: CGFloat = UIScreen.main.bounds.height * 0.7 // 70% de la pantalla
        let minHeight: CGFloat = 200 // Mínimo 200pt

        return min(max(calculatedHeight, minHeight), maxHeight)
    }
}
