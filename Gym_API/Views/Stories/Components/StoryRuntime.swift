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
        GeometryReader { geometry in
            let storyFrame = StoryDimensions.calculateStoryFrame(for: geometry.size)

            ZStack {
                // Background for letterboxing
                Color.black.ignoresSafeArea()

                // Story content in 9:16 container
                Group {
                    switch story.storyType {
                    case .image:
                        InstagramStoryImageView(
                            imageURL: story.mediaUrl,
                            localImage: nil
                        )
                        .frame(width: storyFrame.width, height: storyFrame.height)
                        .position(x: geometry.size.width / 2, y: geometry.size.height / 2)
                        .clipped()

                    case .text:
                        VStack {
                            Spacer()
                            Text(story.caption ?? "")
                                .foregroundColor(.white)
                                .font(.title)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, StoryDimensions.horizontalPadding)
                            Spacer()
                        }
                        .frame(width: storyFrame.width, height: storyFrame.height)
                        .position(x: geometry.size.width / 2, y: geometry.size.height / 2)

                    default:
                        // Basic fallback for other types
                        VStack {
                            Text(story.caption ?? "Story")
                                .foregroundColor(.white)
                                .padding()
                        }
                        .frame(width: storyFrame.width, height: storyFrame.height)
                        .position(x: geometry.size.width / 2, y: geometry.size.height / 2)
                    }
                }
                .clipShape(RoundedRectangle(cornerRadius: 0))
            }
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

