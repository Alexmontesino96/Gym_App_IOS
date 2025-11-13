//
//  StoryViewExtensions.swift
//  Gym_API
//
//  Created on November 2024
//

import SwiftUI

// MARK: - View Extension for Placeholder
extension View {
    func placeholder<Content: View>(
        when shouldShow: Bool,
        @ViewBuilder placeholder: () -> Content
    ) -> some View {
        ZStack(alignment: .leading) {
            if shouldShow {
                placeholder()
            }
            self
        }
    }

    // MARK: - Conditional transform if optional has value
    @ViewBuilder
    func ifLet<T, Content: View>(_ value: T?, transform: (Self, T) -> Content) -> some View {
        if let value = value {
            transform(self, value)
        } else {
            self
        }
    }
}
