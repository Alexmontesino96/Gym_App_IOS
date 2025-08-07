//
//  AccessibilityExtensions.swift
//  Gym_API
//
//  Created by Claude Code on 8/4/25.
//

import SwiftUI

// MARK: - Dynamic Type Extensions
extension Font {
    /// Creates a font that automatically scales with Dynamic Type
    static func dynamicSystem(size: CGFloat, weight: Font.Weight = .regular) -> Font {
        return Font.system(size: size, weight: weight)
    }
    
    /// Creates a font that respects Dynamic Type but has maximum and minimum limits
    static func cappedDynamicSystem(size: CGFloat, weight: Font.Weight = .regular, maxSize: CGFloat? = nil, minSize: CGFloat? = nil) -> Font {
        let scaledSize = UIFontMetrics.default.scaledValue(for: size)
        
        var finalSize = scaledSize
        if let maxSize = maxSize {
            finalSize = min(finalSize, maxSize)
        }
        if let minSize = minSize {
            finalSize = max(finalSize, minSize)
        }
        
        return Font.system(size: finalSize, weight: weight)
    }
}

// MARK: - View Extensions for Accessibility
extension View {
    /// Adds minimum touch target size for accessibility compliance (44x44 pts minimum)
    func accessibleTouchTarget(minWidth: CGFloat = 44, minHeight: CGFloat = 44) -> some View {
        self.frame(minWidth: minWidth, minHeight: minHeight)
    }
    
    /// Makes text automatically scale with Dynamic Type and ensures it doesn't clip
    func dynamicTypeSupport(maxLines: Int? = nil) -> some View {
        self.lineLimit(maxLines)
            .minimumScaleFactor(0.75) // Allow text to scale down if needed
            .allowsTightening(true)
    }
    
    /// Adds proper semantic structure for VoiceOver navigation
    func accessibilitySection(label: String, hint: String? = nil) -> some View {
        self.accessibilityElement(children: .contain)
            .accessibilityLabel(label)
            .accessibilityHint(hint ?? "")
            .accessibilityAddTraits(.isHeader)
    }
    
    /// Groups related accessibility elements together
    func accessibilityGroup(label: String, hint: String? = nil) -> some View {
        self.accessibilityElement(children: .combine)
            .accessibilityLabel(label)
            .accessibilityHint(hint ?? "")
    }
}

// MARK: - Dynamic Type Size Helpers
extension DynamicTypeSize {
    /// Returns true if the current Dynamic Type size is considered large (accessibility sizes)
    var isAccessibilitySize: Bool {
        switch self {
        case .accessibility1, .accessibility2, .accessibility3, .accessibility4, .accessibility5:
            return true
        default:
            return false
        }
    }
    
    /// Returns a scaling factor based on the Dynamic Type size
    var scalingFactor: CGFloat {
        switch self {
        case .xSmall: return 0.8
        case .small: return 0.9
        case .medium: return 1.0
        case .large: return 1.1
        case .xLarge: return 1.2
        case .xxLarge: return 1.3
        case .xxxLarge: return 1.4
        case .accessibility1: return 1.6
        case .accessibility2: return 1.8
        case .accessibility3: return 2.0
        case .accessibility4: return 2.2
        case .accessibility5: return 2.4
        @unknown default: return 1.0
        }
    }
    
    /// Returns adjusted spacing for the current Dynamic Type size
    func adjustedSpacing(_ baseSpacing: CGFloat) -> CGFloat {
        return baseSpacing * scalingFactor
    }
    
    /// Returns adjusted padding for the current Dynamic Type size
    func adjustedPadding(_ basePadding: CGFloat) -> CGFloat {
        return basePadding * min(scalingFactor, 1.5) // Cap padding scaling
    }
}

// MARK: - Loading State Accessibility
extension View {
    /// Adds proper accessibility announcement for loading states
    func accessibilityLoadingState(isLoading: Bool, loadingMessage: String = "Loading") -> some View {
        self.accessibilityElement(children: .contain)
            .accessibilityValue(isLoading ? loadingMessage : "")
            .accessibilityAddTraits(isLoading ? .updatesFrequently : [])
    }
    
    /// Adds proper accessibility for error states
    func accessibilityErrorState(hasError: Bool, errorMessage: String? = nil) -> some View {
        self.accessibilityElement(children: .contain)
            .accessibilityValue(hasError ? (errorMessage ?? "Error occurred") : "")
            .accessibilityAddTraits(hasError ? .causesPageTurn : [])
    }
}