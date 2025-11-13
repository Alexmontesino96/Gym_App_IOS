import SwiftUI
import AVKit

/// Simple video player view for stories that respects pause/play binding
struct VideoStoryView: View {
    let url: URL
    @Binding var isPaused: Bool

    private let player: AVPlayer

    init(url: URL, isPaused: Binding<Bool>) {
        self.url = url
        self._isPaused = isPaused
        self.player = AVPlayer(url: url)
        self.player.isMuted = false
        self.player.actionAtItemEnd = .pause
    }

    var body: some View {
        VideoPlayer(player: player)
            .onAppear {
                if !isPaused { player.play() }
            }
            .onDisappear {
                player.pause()
                player.seek(to: .zero)
            }
            .onChange(of: isPaused) { _, paused in
                if paused { player.pause() } else { player.play() }
            }
    }
}

