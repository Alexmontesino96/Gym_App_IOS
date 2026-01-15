//
//  StoryDimensions.swift
//  Gym_API
//
//  Instagram Stories dimensions and layout constants
//

import SwiftUI

// MARK: - Story Dimensions Constants
struct StoryDimensions {

    // MARK: - Instagram Story Standard
    /// Instagram standard aspect ratio for stories (9:16)
    static let aspectRatio: CGFloat = 9.0 / 16.0

    /// Instagram recommended resolution
    static let recommendedWidth: CGFloat = 1080
    static let recommendedHeight: CGFloat = 1920

    // MARK: - Safe Areas & Zones
    /// Top safe zone to avoid overlapping with profile header and progress bars
    static let topSafeZone: CGFloat = 250

    /// Bottom safe zone for interaction bar
    static let bottomSafeZone: CGFloat = 100

    /// Horizontal padding for content
    static let horizontalPadding: CGFloat = 16

    // MARK: - Device Specific Adjustments
    /// Dynamic Island height for iPhone 14 Pro/Max
    static let dynamicIslandHeight: CGFloat = 59

    /// Standard notch height for older iPhones
    static let notchHeight: CGFloat = 44

    // MARK: - Image Display Modes
    enum ImageDisplayMode {
        case fill      // Fill entire screen (may crop)
        case fit       // Fit entire image (may show bars)
        case smart     // Intelligent fitting based on image ratio
    }

    // MARK: - Helper Methods

    /// Calculate story dimensions for given screen size
    static func calculateStoryFrame(for screenSize: CGSize) -> CGRect {
        let screenAspectRatio = screenSize.width / screenSize.height

        var storyWidth: CGFloat
        var storyHeight: CGFloat

        if screenAspectRatio < aspectRatio {
            // Screen is taller than 9:16 - fit to width
            storyWidth = screenSize.width
            storyHeight = storyWidth / aspectRatio
        } else {
            // Screen is wider than 9:16 - fit to height
            storyHeight = screenSize.height
            storyWidth = storyHeight * aspectRatio
        }

        // Center the story frame
        let xOffset = (screenSize.width - storyWidth) / 2
        let yOffset = (screenSize.height - storyHeight) / 2

        return CGRect(x: xOffset, y: yOffset, width: storyWidth, height: storyHeight)
    }

    /// Get safe area for content within story
    static func contentSafeArea(for storySize: CGSize) -> CGRect {
        return CGRect(
            x: horizontalPadding,
            y: topSafeZone,
            width: storySize.width - (horizontalPadding * 2),
            height: storySize.height - topSafeZone - bottomSafeZone
        )
    }

    /// Determine best display mode for image
    static func bestDisplayMode(for imageRatio: CGFloat) -> ImageDisplayMode {
        // If image is close to 9:16, use fill
        if abs(imageRatio - aspectRatio) < 0.1 {
            return .fill
        }

        // If image is very wide (landscape), use fit
        if imageRatio > 1.0 {
            return .fit
        }

        // For square or portrait images, use smart cropping
        return .smart
    }
}

// MARK: - View Extension for Story Container
extension View {
    /// Apply Instagram story container constraints
    func storyContainer() -> some View {
        self
            .aspectRatio(StoryDimensions.aspectRatio, contentMode: .fit)
            .clipped()
            .background(Color.black)
    }
}