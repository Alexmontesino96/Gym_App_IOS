import SwiftUI

// MARK: - Story Runtime Primitives

/// Minimal controller to manage play/pause for stories
class StoryController: ObservableObject {
    @Published var isPaused: Bool = false
    func pause() { isPaused = true }
    func play() { isPaused = false }
}

/// Representable story item derived from a Story model
struct StoryItem: Identifiable {
    let id = UUID()
    let story: Story

    static func from(story: Story) -> StoryItem {
        StoryItem(story: story)
    }
}

enum StoryProgressPosition { case top, bottom }
enum VerticalSwipeDirection { case up, down, none }

/// Minimal StoryView that shows current story content and handles basic navigation callbacks
struct StoryView: View {
    @Binding var storyItems: [StoryItem]
    @ObservedObject var controller: StoryController
    @Binding var opacityLevel: Double
    @Binding var isHorizontalDragging: Bool

    let onComplete: () -> Void
    let onVerticalDragChanged: (CGFloat) -> Void
    let onVerticalSwipeComplete: (VerticalSwipeDirection) -> Void
    let onStoryShow: (StoryItem) -> Void
    let progressPosition: StoryProgressPosition

    @State private var index: Int = 0

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            if !storyItems.isEmpty {
                contentView(for: storyItems[index].story)
                    .onAppear { onStoryShow(storyItems[index]) }
                    .onChange(of: index) { _, _ in
                        if index < storyItems.count { onStoryShow(storyItems[index]) }
                    }
            } else {
                Text("No stories")
                    .foregroundColor(.white)
            }

            // Simple tap zones to simulate next/previous
            HStack(spacing: 0) {
                TapArea(side: .left) { previous() }
                TapArea(side: .right) { next() }
            }
        }
        .gesture(
            DragGesture(minimumDistance: 20)
                .onChanged { value in
                    onVerticalDragChanged(value.translation.height)
                }
                .onEnded { value in
                    if value.translation.height > StoryDesignTokens.swipeThresholdVertical {
                        onVerticalSwipeComplete(.down)
                    } else if value.translation.height < -StoryDesignTokens.swipeThresholdVertical {
                        onVerticalSwipeComplete(.up)
                    } else {
                        onVerticalSwipeComplete(.none)
                    }
                }
        )
    }

    @ViewBuilder
    private func contentView(for story: Story) -> some View {
        switch story.storyType {
        case .image:
            if let urlStr = story.mediaUrl, let url = URL(string: urlStr) {
                AsyncImage(url: url) { image in
                    image.resizable().scaledToFill()
                } placeholder: {
                    ProgressView().tint(.white)
                }
                .ignoresSafeArea()
            } else {
                Color.gray.ignoresSafeArea()
            }
        case .text:
            Text(story.caption ?? "")
                .foregroundColor(.white)
                .font(.title)
                .padding()
        default:
            // Basic fallback for other types
            Text(story.caption ?? "Story")
                .foregroundColor(.white)
                .padding()
        }
    }

    private func next() {
        guard !storyItems.isEmpty else { return }
        if index < storyItems.count - 1 {
            index += 1
        } else {
            onComplete()
        }
    }

    private func previous() {
        guard !storyItems.isEmpty else { return }
        if index > 0 { index -= 1 }
    }
}

