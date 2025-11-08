//
//  StoryProgressBars.swift
//  Gym_API
//
//  Created on November 2024
//

import SwiftUI

struct StoryProgressBars: View {
    let stories: [Story]
    let currentIndex: Int
    let progress: CGFloat

    var body: some View {
        HStack(spacing: 4) {
            ForEach(0..<stories.count, id: \.self) { index in
                ProgressBar(
                    progress: progressForBar(at: index)
                )
            }
        }
        .frame(height: 3)
    }

    private func progressForBar(at index: Int) -> CGFloat {
        if index < currentIndex {
            return 1.0 // Completed stories
        } else if index == currentIndex {
            return progress // Current story
        } else {
            return 0.0 // Upcoming stories
        }
    }
}

struct ProgressBar: View {
    let progress: CGFloat

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                // Background
                RoundedRectangle(cornerRadius: 1.5)
                    .fill(Color.white.opacity(0.3))

                // Progress
                RoundedRectangle(cornerRadius: 1.5)
                    .fill(Color.white)
                    .frame(width: geometry.size.width * progress)
            }
        }
    }
}