//
//  ButtonStyles.swift
//  Gym_API
//
//  Common button styles used throughout the app
//

import SwiftUI

// MARK: - Scale Button Style

/// Button style with scale animation on press
struct ScaleButtonStyle: ButtonStyle {
    let scale: CGFloat

    init(scale: CGFloat = 0.95) {
        self.scale = scale
    }

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? scale : 1.0)
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
    }
}

// MARK: - Extension for Easy Access

extension ButtonStyle where Self == ScaleButtonStyle {
    static var scale: ScaleButtonStyle {
        ScaleButtonStyle()
    }

    static func scale(_ amount: CGFloat) -> ScaleButtonStyle {
        ScaleButtonStyle(scale: amount)
    }
}
