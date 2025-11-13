import Foundation
import SwiftUI

/// Shared UI state for Stories components (avatar frames, transitions, flags)
class StoryUIState: ObservableObject {
    @Published var avatarFramesByUserId: [Int: CGRect] = [:]
    @Published var isViewerPresented: Bool = false
    /// Frame del avatar del usuario actual (para animación de dismiss)
    @Published var myAvatarFrame: CGRect? = nil
}
