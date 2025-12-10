//
//  StoryReactionMiniPicker.swift
//  Gym_API
//
//  Compact emoji picker overlay (180px height)
//  Replaces the full-screen StoryReactionPicker (400px)
//  Design doc: STORY_REACTION_UX_REDESIGN.md - Section 4.4
//
//  Created on December 2024
//

import SwiftUI

// MARK: - Mini Reaction Picker
/// Compact emoji picker with tabbed categories
/// Displays as an overlay instead of a full modal sheet
/// Height: 180px (vs 400px of legacy picker)
struct StoryReactionMiniPicker: View {
    // MARK: - Properties
    let categories: [EmojiPickerCategory]
    let onSelect: (String) -> Void
    let onClose: () -> Void

    // MARK: - State
    @State private var selectedCategoryIndex: Int = 0

    // MARK: - Constants
    private let pickerHeight: CGFloat = 180
    private let gridColumns: Int = 8
    private let emojiSize: CGFloat = 28
    private let tabHeight: CGFloat = 44

    // MARK: - Body
    var body: some View {
        VStack(spacing: 0) {
            // Category tabs
            categoryTabs

            // Emoji grid
            emojiGrid
        }
        .frame(height: pickerHeight)
        .clipShape(RoundedRectangle(cornerRadius: StoryInteractionTokens.Radius.picker))
        .overlay(
            RoundedRectangle(cornerRadius: StoryInteractionTokens.Radius.picker)
                .stroke(Color.white.opacity(0.1), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.3), radius: 20, x: 0, y: -10)
        .padding(.horizontal, StoryInteractionTokens.Spacing.sm)
    }

    // MARK: - Category Tabs
    private var categoryTabs: some View {
        HStack(spacing: 0) {
            ForEach(Array(categories.enumerated()), id: \.element.id) { index, category in
                Button(action: {
                    withAnimation(StoryInteractionTokens.Animations.traySlide) {
                        selectedCategoryIndex = index
                    }
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                }) {
                    VStack(spacing: StoryInteractionTokens.Spacing.xs) {
                        Image(systemName: category.icon)
                            .font(.system(size: 18))
                            .foregroundColor(
                                selectedCategoryIndex == index
                                ? StoryInteractionTokens.Colors.accent
                                : StoryInteractionTokens.Colors.textPlaceholder
                            )

                        Text(category.name)
                            .font(.system(size: 10, weight: .medium))
                            .foregroundColor(
                                selectedCategoryIndex == index
                                ? StoryInteractionTokens.Colors.textPrimary
                                : StoryInteractionTokens.Colors.textPlaceholder
                            )
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, StoryInteractionTokens.Spacing.sm)
                    .background(
                        selectedCategoryIndex == index
                        ? StoryInteractionTokens.Colors.glassSurface
                        : Color.clear
                    )
                }
                .buttonStyle(.plain)
                .accessibilityLabel(category.name)
                .accessibilityAddTraits(selectedCategoryIndex == index ? .isSelected : [])
            }
        }
        .frame(height: tabHeight)
        .background(Color.black.opacity(0.3))
    }

    // MARK: - Emoji Grid
    private var emojiGrid: some View {
        ScrollView {
            LazyVGrid(
                columns: Array(repeating: GridItem(.flexible(), spacing: StoryInteractionTokens.Spacing.sm), count: gridColumns),
                spacing: StoryInteractionTokens.Spacing.sm
            ) {
                ForEach(currentCategoryEmojis, id: \.self) { emoji in
                    Button(action: {
                        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                        onSelect(emoji)
                    }) {
                        Text(emoji)
                            .font(.system(size: emojiSize))
                            .frame(width: 40, height: 40)
                    }
                    .buttonStyle(.scale(0.9))
                    .accessibilityLabel(emoji)
                }
            }
            .padding(StoryInteractionTokens.Spacing.md)
        }
        .background(Color.black.opacity(0.8))
    }

    // MARK: - Computed Properties
    private var currentCategoryEmojis: [String] {
        guard selectedCategoryIndex < categories.count else { return [] }
        return categories[selectedCategoryIndex].emojis
    }
}

// MARK: - Preview
#Preview("Mini Reaction Picker") {
    ZStack {
        Color.black.ignoresSafeArea()

        VStack {
            Spacer()

            StoryReactionMiniPicker(
                categories: ContextualEmojis.pickerCategories,
                onSelect: { emoji in
                    print("Selected: \(emoji)")
                },
                onClose: {
                    print("Closed")
                }
            )

            Spacer()
                .frame(height: 100)
        }
    }
}

#Preview("Mini Picker Dark") {
    ZStack {
        // Simulated story background
        LinearGradient(
            colors: [.purple.opacity(0.8), .blue.opacity(0.8)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .ignoresSafeArea()

        VStack {
            Spacer()

            StoryReactionMiniPicker(
                categories: ContextualEmojis.pickerCategories,
                onSelect: { emoji in
                    print("Selected: \(emoji)")
                },
                onClose: {
                    print("Closed")
                }
            )
            .padding(.bottom, 120)
        }
    }
}
