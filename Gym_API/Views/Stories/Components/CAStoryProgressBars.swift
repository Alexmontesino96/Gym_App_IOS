import SwiftUI

/// Minimal replacement for a Core Animation-based progress bar stack used in Story viewer.
/// Matches the call site signature in StoryViewerContainer.
struct CAStoryProgressBars: View {
    let storiesCount: Int
    let currentIndex: Int
    let durations: [TimeInterval]
    let isPaused: Bool
    let barHeight: CGFloat
    let barSpacing: CGFloat
    let onSegmentComplete: () -> Void

    var body: some View {
        HStack(spacing: barSpacing) {
            ForEach(0..<storiesCount, id: \.self) { index in
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule().fill(Color.white.opacity(0.25))
                        Capsule()
                            .fill(Color.white)
                            .frame(width: progressWidth(for: index, totalWidth: geo.size.width))
                            .animation(.linear(duration: 0.0), value: currentIndex)
                    }
                }
                .frame(height: barHeight)
            }
        }
    }

    private func progressWidth(for index: Int, totalWidth: CGFloat) -> CGFloat {
        if index < currentIndex { return totalWidth }
        if index > currentIndex { return 0 }
        // Current segment progress is visually handled by StoryView; keep full to avoid flicker
        return totalWidth
    }
}

extension Array where Element == Story {
    func defaultDurations() -> [TimeInterval] {
        map { _ in StoryDesignTokens.defaultStoryDuration }
    }
}

