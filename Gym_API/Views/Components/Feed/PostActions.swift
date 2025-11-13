//
//  PostActions.swift
//  Gym_API
//
//  Created by Claude Code
//  Post action buttons - like, comment, share
//

import SwiftUI

struct PostActions: View {
    let isLiked: Bool
    let likeCount: Int
    let commentCount: Int
    let theme: ThemeManager.AppTheme

    let onLike: () -> Void
    let onComment: () -> Void
    let onShare: () -> Void
    let onLikesTap: () -> Void

    @State private var likeScale: CGFloat = 1.0

    var body: some View {
        let actionButtonSize: CGFloat = 24
        let actionButtonSpacing: CGFloat = 16

        VStack(alignment: .leading, spacing: 8) {
            // Action Buttons
            HStack(spacing: actionButtonSpacing) {
                Button(action: {
                    onLike()
                    animateLike()
                }) {
                    Image(systemName: isLiked ? "heart.fill" : "heart")
                        .font(.system(size: actionButtonSize))
                        .foregroundColor(isLiked ? Color.likeRed : Color.dynamicText(theme: theme))
                        .scaleEffect(likeScale)
                }

                Button(action: onComment) {
                    Image(systemName: "bubble.right")
                        .font(.system(size: actionButtonSize))
                        .foregroundColor(Color.dynamicText(theme: theme))
                }

                Button(action: onShare) {
                    Image(systemName: "paperplane")
                        .font(.system(size: actionButtonSize))
                        .foregroundColor(Color.dynamicText(theme: theme))
                }

                Spacer()
            }

            // Like Count
            if likeCount > 0 {
                Button(action: onLikesTap) {
                    Text("\(likeCount) Me gusta")
                        .font(Typography.labelLarge)
                        .foregroundColor(Color.dynamicText(theme: theme))
                }
            }
        }
    }

    private func animateLike() {
        withAnimation(.spring(response: VisualEffects.springResponse, dampingFraction: VisualEffects.springDamping)) {
            likeScale = 1.3
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
            withAnimation(.spring(response: VisualEffects.springResponse, dampingFraction: VisualEffects.springDamping)) {
                likeScale = 1.0
            }
        }
    }
}
