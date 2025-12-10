//
//  StoryReactionPicker_Legacy.swift
//  Gym_API
//
//  DEPRECATED - Use StoryReactionMiniPicker instead
//  This file is kept for reference and potential rollback.
//  See STORY_REACTION_UX_REDESIGN.md for migration details.
//
//  Key differences from new implementation:
//  - Height: 400px vs 180px (new mini picker)
//  - Presentation: Full sheet vs inline overlay
//  - Categories: Generic vs fitness-focused
//

import SwiftUI

// MARK: - DEPRECATED: Use StoryReactionMiniPicker
/// Legacy selector de reacciones con emojis categorizados
/// @available(*, deprecated, message: "Use StoryReactionMiniPicker instead")
struct StoryReactionPicker_Legacy: View {
    @Binding var isPresented: Bool
    let onReactionSelected: (String) -> Void

    @State private var selectedCategory: EmojiCategory_Legacy = .smileys

    enum EmojiCategory_Legacy: String, CaseIterable {
        case smileys = "😀"
        case hearts = "❤️"
        case hands = "👏"
        case objects = "🔥"

        var emojis: [String] {
            switch self {
            case .smileys:
                return [
                    "😀", "😃", "😄", "😁", "😆", "😅", "🤣", "😂", "🙂", "🙃",
                    "😉", "😊", "😇", "🥰", "😍", "🤩", "😘", "😗", "😚", "😙",
                    "🥲", "😋", "😛", "😜", "🤪", "😝", "🤗", "🤭", "🫣", "🤫",
                    "🤔", "🫡", "🤐", "🤨", "😐", "😑", "😶", "🫥", "😶‍🌫️", "😏",
                    "😒", "🙄", "😬", "😮‍💨", "🤥", "😌", "😔", "😪", "🤤", "😴",
                    "😷", "🤒", "🤕", "🤢", "🤮", "🤧", "🥵", "🥶", "🥴", "😵",
                    "😵‍💫", "🤯", "🤠", "🥳", "🥸", "😎", "🤓", "🧐", "😕", "🫤",
                    "😟", "🙁", "☹️", "😮", "😯", "😲", "😳", "🥺", "🥹", "😦",
                    "😧", "😨", "😰", "😥", "😢", "😭", "😱", "😖", "😣", "😞",
                    "😓", "😩", "😫", "🥱"
                ]
            case .hearts:
                return [
                    "❤️", "🧡", "💛", "💚", "💙", "💜", "🖤", "🤍", "🤎", "💔",
                    "❤️‍🔥", "❤️‍🩹", "💕", "💞", "💓", "💗", "💖", "💘", "💝", "💟"
                ]
            case .hands:
                return [
                    "👏", "🙌", "👐", "🤲", "🤝", "🙏", "✍️", "💅", "🤳", "💪",
                    "🦾", "🦿", "🦵", "🦶", "👂", "🦻", "👃", "🧠", "🫀", "🫁",
                    "🦷", "🦴", "👀", "👁️", "👅", "👄", "🫦", "👍", "👎", "👊",
                    "✊", "🤛", "🤜", "🤞", "✌️", "🫰", "🤟", "🤘", "👌", "🤌",
                    "🤏", "👈", "👉", "👆", "👇", "☝️", "✋", "🤚", "🖐️", "🖖",
                    "👋", "🤙", "🫶"
                ]
            case .objects:
                return [
                    "🔥", "⭐", "✨", "💥", "💫", "💦", "💨", "🕳️", "💬", "👁️‍🗨️",
                    "🗨️", "🗯️", "💭", "💤", "🎉", "🎊", "🎈", "🎁", "🏆", "🥇",
                    "🥈", "🥉", "⚽", "🏀", "🏈", "⚾", "🥎", "🎾", "🏐", "🏉",
                    "🥏", "🎱", "🪀", "🏓", "🏸", "🏒", "🏑", "🥍", "🏏", "🪃",
                    "🥅", "⛳", "🪁", "🏹", "🎣", "🤿", "🥊", "🥋", "🎽", "🛹",
                    "🛼", "🛷", "⛸️", "🥌", "🎿", "⛷️", "🏂", "🪂", "🏋️", "🤼",
                    "🤸", "🤺", "🤾", "🏌️", "🏇", "🧘", "🏄", "🏊", "🤽", "🚣",
                    "🧗", "🚵", "🚴", "🏅", "🎖️", "🏵️", "🎗️"
                ]
            }
        }

        var icon: String {
            rawValue
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Reaccionar")
                    .font(.headline)
                    .foregroundColor(.white)

                Spacer()

                Button(action: { isPresented = false }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 24))
                        .foregroundColor(.white.opacity(0.6))
                }
            }
            .padding()
            .background(Color.black.opacity(0.95))

            // Category tabs
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 20) {
                    ForEach(EmojiCategory_Legacy.allCases, id: \.self) { category in
                        Button(action: {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                selectedCategory = category
                            }
                        }) {
                            VStack(spacing: 4) {
                                Text(category.icon)
                                    .font(.system(size: 28))

                                if selectedCategory == category {
                                    Capsule()
                                        .fill(Color.red)
                                        .frame(width: 30, height: 3)
                                        .transition(.scale.combined(with: .opacity))
                                }
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal)
                .padding(.vertical, 12)
            }
            .background(Color.black.opacity(0.8))

            // Emojis grid
            ScrollView {
                LazyVGrid(
                    columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 8),
                    spacing: 12
                ) {
                    ForEach(selectedCategory.emojis, id: \.self) { emoji in
                        Button(action: {
                            onReactionSelected(emoji)
                            isPresented = false

                            // Haptic feedback
                            let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
                            impactFeedback.impactOccurred()
                        }) {
                            Text(emoji)
                                .font(.system(size: 32))
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding()
            }
            .background(Color.black.opacity(0.95))
        }
        .frame(height: 400)
        .clipShape(UnevenRoundedRectangle(topLeadingRadius: 16, topTrailingRadius: 16))
        .shadow(color: .black.opacity(0.3), radius: 20, x: 0, y: -5)
    }
}

// MARK: - Preview
#Preview {
    ZStack {
        Color.black
        VStack {
            Spacer()
            StoryReactionPicker_Legacy(isPresented: .constant(true)) { emoji in
                print("Selected: \(emoji)")
            }
        }
    }
    .ignoresSafeArea()
}
