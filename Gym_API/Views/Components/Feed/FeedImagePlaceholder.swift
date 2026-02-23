//
//  FeedImagePlaceholder.swift
//  Gym_API
//
//  Created by Claude Code
//  Shimmer placeholder component for feed image loading states
//

import SwiftUI

// MARK: - Feed Image Placeholder

/// A shimmer-animated placeholder view displayed while feed images are loading.
///
/// This component provides visual feedback during image loading with a smooth
/// shimmer animation that moves from left to right. The animation adapts to
/// both light and dark themes.
///
/// - Parameters:
///   - size: The dimensions of the placeholder
///   - cornerRadius: Optional corner radius for rounded placeholders (default: 0)
///
/// Usage:
/// ```swift
/// FeedImagePlaceholder(size: CGSize(width: 300, height: 400))
///     .environmentObject(themeManager)
/// ```
struct FeedImagePlaceholder: View {

    // MARK: - Properties

    /// The size of the placeholder view
    let size: CGSize

    /// Corner radius for the placeholder (default: 0 for square edges)
    var cornerRadius: CGFloat = 0

    /// Theme manager for dynamic color adaptation
    @EnvironmentObject var themeManager: ThemeManager

    // MARK: - Animation State

    /// Shimmer animation offset (-1 to 2 range for full sweep effect)
    @State private var shimmerOffset: CGFloat = -1

    // MARK: - Computed Properties

    /// Base color for the placeholder background (adapts to theme)
    private var baseColor: Color {
        switch themeManager.currentTheme {
        case .light:
            return Color(red: 0.92, green: 0.92, blue: 0.92) // #EBEBEB
        case .dark:
            return Color(red: 0.20, green: 0.20, blue: 0.20) // #333333
        }
    }

    /// Highlight color for shimmer effect (lighter than base)
    private var highlightColor: Color {
        switch themeManager.currentTheme {
        case .light:
            return Color(red: 0.98, green: 0.98, blue: 0.98) // #FAFAFA
        case .dark:
            return Color(red: 0.30, green: 0.30, blue: 0.30) // #4D4D4D
        }
    }

    /// Gradient for the shimmer effect
    private var shimmerGradient: LinearGradient {
        LinearGradient(
            gradient: Gradient(stops: [
                .init(color: baseColor, location: 0),
                .init(color: highlightColor, location: 0.4),
                .init(color: highlightColor, location: 0.5),
                .init(color: highlightColor, location: 0.6),
                .init(color: baseColor, location: 1)
            ]),
            startPoint: UnitPoint(x: shimmerOffset, y: 0.5),
            endPoint: UnitPoint(x: shimmerOffset + 1, y: 0.5)
        )
    }

    // MARK: - Body

    var body: some View {
        Rectangle()
            .fill(shimmerGradient)
            .frame(width: size.width, height: size.height)
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
            .onAppear {
                startShimmerAnimation()
            }
            // Accessibility
            .accessibilityLabel("Loading image")
            .accessibilityAddTraits(.isImage)
    }

    // MARK: - Animation

    /// Starts the continuous shimmer animation loop
    private func startShimmerAnimation() {
        // Reset to start position
        shimmerOffset = -1

        // Animate with continuous loop
        withAnimation(
            .linear(duration: 1.5)
            .repeatForever(autoreverses: false)
        ) {
            shimmerOffset = 2
        }
    }
}

// MARK: - Convenience Initializers

extension FeedImagePlaceholder {

    /// Creates a square placeholder with the given dimension
    /// - Parameters:
    ///   - dimension: The width and height of the square placeholder
    ///   - cornerRadius: Optional corner radius
    init(dimension: CGFloat, cornerRadius: CGFloat = 0) {
        self.size = CGSize(width: dimension, height: dimension)
        self.cornerRadius = cornerRadius
    }

    /// Creates a placeholder matching a typical Instagram-style aspect ratio (4:5)
    /// - Parameters:
    ///   - width: The width of the placeholder
    ///   - cornerRadius: Optional corner radius
    init(width: CGFloat, cornerRadius: CGFloat = 0) {
        self.size = CGSize(width: width, height: width * 1.25) // 4:5 aspect ratio
        self.cornerRadius = cornerRadius
    }
}

// NOTE: ShimmerModifier is defined in Utils/AnimationModifiers.swift
// Use the global shimmer() modifier from there to avoid duplication

// MARK: - Preview

#Preview("Light Theme") {
    VStack(spacing: 20) {
        FeedImagePlaceholder(
            size: CGSize(width: 300, height: 375),
            cornerRadius: 0
        )

        FeedImagePlaceholder(
            size: CGSize(width: 300, height: 200),
            cornerRadius: 12
        )

        HStack(spacing: 8) {
            FeedImagePlaceholder(dimension: 80, cornerRadius: 8)
            FeedImagePlaceholder(dimension: 80, cornerRadius: 8)
            FeedImagePlaceholder(dimension: 80, cornerRadius: 8)
        }
    }
    .padding()
    .background(Color.white)
    .environmentObject(ThemeManager())
}

#Preview("Dark Theme") {
    let darkTheme = ThemeManager()

    return VStack(spacing: 20) {
        FeedImagePlaceholder(
            size: CGSize(width: 300, height: 375),
            cornerRadius: 0
        )

        FeedImagePlaceholder(
            size: CGSize(width: 300, height: 200),
            cornerRadius: 12
        )

        HStack(spacing: 8) {
            FeedImagePlaceholder(dimension: 80, cornerRadius: 8)
            FeedImagePlaceholder(dimension: 80, cornerRadius: 8)
            FeedImagePlaceholder(dimension: 80, cornerRadius: 8)
        }
    }
    .padding()
    .background(Color.black)
    .environmentObject(darkTheme)
    .onAppear {
        darkTheme.setTheme(.dark)
    }
}
