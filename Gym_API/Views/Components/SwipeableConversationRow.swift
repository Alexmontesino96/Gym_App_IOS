import SwiftUI

/// Wrapper para ConversationRow que añade funcionalidad de swipe actions
struct SwipeableConversationRow: View {
    let conversation: ChatConversation
    let themeManager: ThemeManager
    let onTap: () -> Void
    let onMute: (() -> Void)?
    let onArchive: (() -> Void)?
    let onDelete: (() -> Void)?
    
    @State private var offset: CGFloat = 0
    @State private var isDragging = false
    @State private var showingDeleteConfirmation = false
    
    // Thresholds for actions
    private let muteThreshold: CGFloat = -80
    private let archiveThreshold: CGFloat = -160
    private let deleteThreshold: CGFloat = -240
    
    init(
        conversation: ChatConversation,
        themeManager: ThemeManager,
        onTap: @escaping () -> Void,
        onMute: (() -> Void)? = nil,
        onArchive: (() -> Void)? = nil,
        onDelete: (() -> Void)? = nil
    ) {
        self.conversation = conversation
        self.themeManager = themeManager
        self.onTap = onTap
        self.onMute = onMute
        self.onArchive = onArchive
        self.onDelete = onDelete
    }
    
    var body: some View {
        ZStack {
            // Background actions
            HStack {
                Spacer()
                
                // Actions row
                HStack(spacing: 0) {
                    // Mute action
                    if onMute != nil && offset <= muteThreshold {
                        SwipeActionButton(
                            icon: "bell.slash.fill",
                            color: .orange,
                            isActive: offset <= muteThreshold && offset > archiveThreshold
                        ) {
                            performAction {
                                onMute?()
                                let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
                                impactFeedback.impactOccurred()
                            }
                        }
                    }
                    
                    // Archive action
                    if onArchive != nil && offset <= archiveThreshold {
                        SwipeActionButton(
                            icon: "archivebox.fill",
                            color: .blue,
                            isActive: offset <= archiveThreshold && offset > deleteThreshold
                        ) {
                            performAction {
                                onArchive?()
                                let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
                                impactFeedback.impactOccurred()
                            }
                        }
                    }
                    
                    // Delete action
                    if onDelete != nil && offset <= deleteThreshold {
                        SwipeActionButton(
                            icon: "trash.fill",
                            color: .red,
                            isActive: offset <= deleteThreshold
                        ) {
                            showingDeleteConfirmation = true
                        }
                    }
                }
            }
            
            // Main conversation row
            ConversationRow(
                conversation: conversation,
                themeManager: themeManager
            )
            .offset(x: offset)
            .onTapGesture {
                if offset == 0 {
                    // Trigger animation in the ConversationRow
                    withAnimation(.easeInOut(duration: 0.1)) {
                        // We'll use a different approach for animation
                    }
                    
                    // Add haptic feedback
                    let impactFeedback = UIImpactFeedbackGenerator(style: .light)
                    impactFeedback.impactOccurred()
                    
                    // Call the onTap callback
                    onTap()
                } else {
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                        offset = 0
                    }
                }
            }
            .gesture(
                DragGesture()
                    .onChanged { value in
                        isDragging = true
                        
                        // Only allow left swipe (negative translation)
                        let translation = min(0, value.translation.width)
                        offset = translation
                        
                        // Haptic feedback at thresholds
                        if !isDragging {
                            if translation <= muteThreshold && translation > archiveThreshold {
                                let impactFeedback = UIImpactFeedbackGenerator(style: .light)
                                impactFeedback.impactOccurred()
                            } else if translation <= archiveThreshold && translation > deleteThreshold {
                                let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
                                impactFeedback.impactOccurred()
                            } else if translation <= deleteThreshold {
                                let impactFeedback = UIImpactFeedbackGenerator(style: .heavy)
                                impactFeedback.impactOccurred()
                            }
                        }
                    }
                    .onEnded { value in
                        isDragging = false
                        
                        let translation = min(0, value.translation.width)
                        let velocity = value.velocity.width
                        
                        // Determine action based on translation and velocity
                        if translation <= deleteThreshold && onDelete != nil {
                            // Snap to delete position
                            withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                                offset = deleteThreshold
                            }
                        } else if translation <= archiveThreshold && onArchive != nil {
                            // Snap to archive position or perform action if velocity is high
                            if velocity < -500 {
                                performAction {
                                    onArchive?()
                                }
                            } else {
                                withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                                    offset = archiveThreshold
                                }
                            }
                        } else if translation <= muteThreshold && onMute != nil {
                            // Snap to mute position or perform action if velocity is high
                            if velocity < -500 {
                                performAction {
                                    onMute?()
                                }
                            } else {
                                withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                                    offset = muteThreshold
                                }
                            }
                        } else {
                            // Snap back to center
                            withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                                offset = 0
                            }
                        }
                    }
            )
        }
        .clipped()
        .alert("Delete Conversation", isPresented: $showingDeleteConfirmation) {
            Button("Cancel", role: .cancel) {
                withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                    offset = 0
                }
            }
            
            Button("Delete", role: .destructive) {
                performAction {
                    onDelete?()
                    let impactFeedback = UIImpactFeedbackGenerator(style: .heavy)
                    impactFeedback.impactOccurred()
                }
            }
        } message: {
            Text("Are you sure you want to delete this conversation? This action cannot be undone.")
        }
    }
    
    private func performAction(_ action: @escaping () -> Void) {
        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
            offset = 0
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            action()
        }
    }
}

/// Botón de acción para swipe gestures
struct SwipeActionButton: View {
    let icon: String
    let color: Color
    let isActive: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: isActive ? 24 : 20, weight: .semibold))
                    .foregroundColor(.white)
                    .scaleEffect(isActive ? 1.2 : 1.0)
                    .animation(.spring(response: 0.3, dampingFraction: 0.6), value: isActive)
            }
            .frame(width: 80, height: 80)
            .background(
                RoundedRectangle(cornerRadius: 0)
                    .fill(color)
                    .opacity(isActive ? 1.0 : 0.8)
            )
            .scaleEffect(isActive ? 1.05 : 1.0)
            .animation(.spring(response: 0.3, dampingFraction: 0.6), value: isActive)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Convenience extension for SwipeableConversationRow
extension SwipeableConversationRow {
    /// Creates a swipeable conversation row with all common actions
    static func withStandardActions(
        conversation: ChatConversation,
        themeManager: ThemeManager,
        onTap: @escaping () -> Void,
        onMute: @escaping () -> Void,
        onArchive: @escaping () -> Void,
        onDelete: @escaping () -> Void
    ) -> SwipeableConversationRow {
        SwipeableConversationRow(
            conversation: conversation,
            themeManager: themeManager,
            onTap: onTap,
            onMute: onMute,
            onArchive: onArchive,
            onDelete: onDelete
        )
    }
    
    /// Creates a swipeable conversation row with only mute and delete actions
    static func withBasicActions(
        conversation: ChatConversation,
        themeManager: ThemeManager,
        onTap: @escaping () -> Void,
        onMute: @escaping () -> Void,
        onDelete: @escaping () -> Void
    ) -> SwipeableConversationRow {
        SwipeableConversationRow(
            conversation: conversation,
            themeManager: themeManager,
            onTap: onTap,
            onMute: onMute,
            onDelete: onDelete
        )
    }
}

#Preview {
    VStack {
        SwipeableConversationRow.withStandardActions(
            conversation: ChatConversation(
                id: "1",
                name: "Chat de Ejemplo",
                type: .group,
                members: [],
                lastMessage: ChatMessage(
                    id: "msg1",
                    conversationId: "1",
                    text: "Este es un mensaje de ejemplo",
                    authorId: "user1",
                    authorName: "Usuario",
                    timestamp: Date(),
                    isFromCurrentUser: false
                ),
                lastActivity: Date(),
                unreadCount: 3,
                metadata: [:]
            ),
            themeManager: ThemeManager(),
            onTap: { print("Tapped") },
            onMute: { print("Muted") },
            onArchive: { print("Archived") },
            onDelete: { print("Deleted") }
        )
        
        Divider()
        
        Text("Swipe left to see actions")
            .font(.caption)
            .foregroundColor(.secondary)
    }
    .environmentObject(ThemeManager())
}