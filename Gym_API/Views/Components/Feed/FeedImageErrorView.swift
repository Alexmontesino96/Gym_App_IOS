//
//  FeedImageErrorView.swift
//  Gym_API
//
//  Created by Claude Code
//  Error state component for failed feed image loads with retry functionality
//

import SwiftUI

// MARK: - Feed Image Error View

/// A view displayed when a feed image fails to load, with optional retry functionality.
///
/// This component provides clear visual feedback for loading failures and offers
/// users an intuitive way to retry the failed request. The design is minimal
/// and adapts to both light and dark themes.
///
/// - Parameters:
///   - size: The dimensions of the error view
///   - cornerRadius: Optional corner radius for rounded corners (default: 0)
///   - onRetry: Optional closure called when user taps to retry
///
/// Usage:
/// ```swift
/// FeedImageErrorView(
///     size: CGSize(width: 300, height: 400),
///     onRetry: { reloadImage() }
/// )
/// .environmentObject(themeManager)
/// ```
struct FeedImageErrorView: View {

    // MARK: - Properties

    /// The size of the error view
    let size: CGSize

    /// Corner radius for the error view (default: 0 for square edges)
    var cornerRadius: CGFloat = 0

    /// Optional retry action closure
    var onRetry: (() -> Void)?

    /// Theme manager for dynamic color adaptation
    @EnvironmentObject var themeManager: ThemeManager

    // MARK: - State

    /// Tracks if the view is being pressed for visual feedback
    @State private var isPressed = false

    // MARK: - Computed Properties

    /// Background color adapting to theme
    private var backgroundColor: Color {
        switch themeManager.currentTheme {
        case .light:
            return Color(red: 0.95, green: 0.95, blue: 0.95) // #F2F2F2
        case .dark:
            return Color(red: 0.15, green: 0.15, blue: 0.15) // #262626
        }
    }

    /// Icon color adapting to theme
    private var iconColor: Color {
        Color.dynamicTextSecondary(theme: themeManager.currentTheme)
    }

    /// Retry button accent color (gym brand red)
    private var retryAccentColor: Color {
        Color(hex: "#D93333") ?? .red
    }

    /// Text color for secondary elements
    private var secondaryTextColor: Color {
        Color.dynamicTextTertiary(theme: themeManager.currentTheme)
    }

    // MARK: - Body

    var body: some View {
        ZStack {
            // Background
            Rectangle()
                .fill(backgroundColor)

            // Content
            VStack(spacing: 12) {
                // Error icon
                Image(systemName: "exclamationmark.triangle")
                    .font(.system(size: 32, weight: .light))
                    .foregroundColor(iconColor)

                // Retry section (only if onRetry is provided)
                if onRetry != nil {
                    VStack(spacing: 8) {
                        // Retry button
                        Button(action: handleRetry) {
                            HStack(spacing: 6) {
                                Image(systemName: "arrow.clockwise")
                                    .font(.system(size: 14, weight: .medium))
                                Text("Retry")
                                    .font(.system(size: 14, weight: .medium))
                            }
                            .foregroundColor(retryAccentColor)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(
                                Capsule()
                                    .stroke(retryAccentColor, lineWidth: 1.5)
                            )
                        }
                        .scaleEffect(isPressed ? 0.95 : 1.0)
                        .animation(.easeInOut(duration: 0.1), value: isPressed)

                        // Hint text
                        Text("Tap to retry")
                            .font(.system(size: 11))
                            .foregroundColor(secondaryTextColor)
                    }
                } else {
                    // Simple error text when no retry available
                    Text("Image unavailable")
                        .font(.system(size: 13))
                        .foregroundColor(secondaryTextColor)
                }
            }
        }
        .frame(width: size.width, height: size.height)
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
        // Accessibility
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityLabelText)
        .accessibilityHint(onRetry != nil ? "Double tap to retry loading" : "")
        .accessibilityAddTraits(onRetry != nil ? .isButton : [])
    }

    // MARK: - Accessibility

    private var accessibilityLabelText: String {
        if onRetry != nil {
            return "Failed to load image, double tap to retry"
        } else {
            return "Failed to load image"
        }
    }

    // MARK: - Actions

    private func handleRetry() {
        // Haptic feedback
        let impact = UIImpactFeedbackGenerator(style: .light)
        impact.impactOccurred()

        // Visual feedback
        withAnimation(.easeInOut(duration: 0.1)) {
            isPressed = true
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            withAnimation(.easeInOut(duration: 0.1)) {
                isPressed = false
            }

            // Execute retry action
            onRetry?()
        }
    }
}

// MARK: - Convenience Initializers

extension FeedImageErrorView {

    /// Creates a square error view with the given dimension
    /// - Parameters:
    ///   - dimension: The width and height of the square view
    ///   - cornerRadius: Optional corner radius
    ///   - onRetry: Optional retry action
    init(dimension: CGFloat, cornerRadius: CGFloat = 0, onRetry: (() -> Void)? = nil) {
        self.size = CGSize(width: dimension, height: dimension)
        self.cornerRadius = cornerRadius
        self.onRetry = onRetry
    }
}

// MARK: - Feed Image Transitions

extension AnyTransition {

    /// A smooth transition for feed images appearing after loading
    ///
    /// Combines opacity fade with a subtle scale effect for a polished
    /// appearance animation when images finish loading.
    static var feedImageAppear: AnyTransition {
        .opacity
        .combined(with: .scale(scale: 0.98))
        .animation(.easeOut(duration: 0.3))
    }

    /// A quick fade transition for placeholder to image swap
    static var feedImageFade: AnyTransition {
        .opacity.animation(.easeInOut(duration: 0.25))
    }
}

// MARK: - Async Image with States

/// A wrapper around AsyncImage that uses custom placeholder and error views
struct FeedAsyncImage: View {
    let url: URL?
    let size: CGSize
    var cornerRadius: CGFloat = 0
    var onRetry: (() -> Void)?

    @EnvironmentObject var themeManager: ThemeManager
    @State private var loadState: LoadState = .loading

    private enum LoadState {
        case loading
        case success
        case failure
    }

    var body: some View {
        AsyncImage(url: url) { phase in
            switch phase {
            case .empty:
                FeedImagePlaceholder(size: size, cornerRadius: cornerRadius)
                    .transition(.feedImageFade)

            case .success(let image):
                image
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: size.width, height: size.height)
                    .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
                    .transition(.feedImageAppear)

            case .failure:
                FeedImageErrorView(
                    size: size,
                    cornerRadius: cornerRadius,
                    onRetry: onRetry
                )
                .transition(.feedImageFade)

            @unknown default:
                FeedImagePlaceholder(size: size, cornerRadius: cornerRadius)
            }
        }
        .animation(.easeInOut(duration: 0.3), value: loadState)
    }
}

// MARK: - Preview

#Preview("Error View - Light Theme") {
    VStack(spacing: 20) {
        // With retry button
        FeedImageErrorView(
            size: CGSize(width: 300, height: 375),
            cornerRadius: 0,
            onRetry: { print("Retry tapped") }
        )

        // Without retry button
        FeedImageErrorView(
            size: CGSize(width: 300, height: 200),
            cornerRadius: 12,
            onRetry: nil
        )

        // Small thumbnails with retry
        HStack(spacing: 8) {
            FeedImageErrorView(dimension: 80, cornerRadius: 8) {
                print("Retry thumbnail")
            }
            FeedImageErrorView(dimension: 80, cornerRadius: 8) {
                print("Retry thumbnail")
            }
        }
    }
    .padding()
    .background(Color.white)
    .environmentObject(ThemeManager())
}

#Preview("Error View - Dark Theme") {
    let darkTheme = ThemeManager()

    return VStack(spacing: 20) {
        // With retry button
        FeedImageErrorView(
            size: CGSize(width: 300, height: 375),
            cornerRadius: 0,
            onRetry: { print("Retry tapped") }
        )

        // Without retry button
        FeedImageErrorView(
            size: CGSize(width: 300, height: 200),
            cornerRadius: 12,
            onRetry: nil
        )

        // Small thumbnails with retry
        HStack(spacing: 8) {
            FeedImageErrorView(dimension: 80, cornerRadius: 8) {
                print("Retry thumbnail")
            }
            FeedImageErrorView(dimension: 80, cornerRadius: 8) {
                print("Retry thumbnail")
            }
        }
    }
    .padding()
    .background(Color.black)
    .environmentObject(darkTheme)
    .onAppear {
        darkTheme.setTheme(.dark)
    }
}

#Preview("Async Image Wrapper") {
    VStack(spacing: 20) {
        // Valid URL (will load)
        FeedAsyncImage(
            url: URL(string: "https://picsum.photos/300/375"),
            size: CGSize(width: 300, height: 375),
            cornerRadius: 12,
            onRetry: { print("Retrying...") }
        )

        // Invalid URL (will show error)
        FeedAsyncImage(
            url: URL(string: "https://invalid-url-test.com/image.jpg"),
            size: CGSize(width: 300, height: 200),
            cornerRadius: 12,
            onRetry: { print("Retrying...") }
        )
    }
    .padding()
    .environmentObject(ThemeManager())
}
