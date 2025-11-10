import SwiftUI

struct InstagramStoryBottomBar: View {
    let story: Story
    let onSendMessage: (String) -> Void
    let onReact: (String) -> Void

    @EnvironmentObject var themeManager: ThemeManager
    @State private var isComposing = false
    @State private var messageText: String = ""
    @FocusState private var isTextFocused: Bool

    private let quickReactions = ["🔥", "😍", "👏", "😂", "😮", "😢"]

    var body: some View {
        VStack(spacing: 8) {
            if isComposing {
                // Quick reactions row (inline, like Instagram above keyboard)
                HStack(spacing: 12) {
                    ForEach(quickReactions, id: \.self) { emoji in
                        Button { onReact(emoji) } label: {
                            Text(emoji)
                                .font(.system(size: 24))
                                .frame(width: 40, height: 40)
                                .background(Circle().fill(Color.white.opacity(0.15)))
                        }
                        .buttonStyle(.plain)
                    }
                    Spacer(minLength: 0)
                }
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }

            HStack(spacing: 10) {
                if isComposing {
                    // Camera icon (Instagram style)
                    Button(action: { /* TODO: open camera reply */ }) {
                        Image(systemName: "camera")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.white)
                            .frame(width: 36, height: 36)
                            .background(Circle().fill(Color.white.opacity(0.15)))
                    }
                    .buttonStyle(.plain)
                }

                ZStack(alignment: .leading) {
                    // Placeholder when not composing
                    if !isComposing {
                        HStack(spacing: 8) {
                            Image(systemName: "text.bubble")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(.secondary)
                            Text("Enviar mensaje")
                                .font(.system(size: 14, weight: .regular))
                                .foregroundColor(.white.opacity(0.85))
                        }
                        .onTapGesture {
                            withAnimation(.spring(response: 0.25, dampingFraction: 0.9)) {
                                isComposing = true
                            }
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                                isTextFocused = true
                            }
                        }
                    }

                    // Text input when composing
                    if isComposing {
                        TextField("Enviar mensaje", text: $messageText)
                            .textInputAutocapitalization(.sentences)
                            .disableAutocorrection(false)
                            .submitLabel(.send)
                            .focused($isTextFocused)
                            .onSubmit { sendMessage() }
                            .foregroundColor(.white)
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .background(
                    Capsule().fill(Color.white.opacity(0.12))
                )
                .overlay(
                    Capsule().stroke(Color.white.opacity(0.25), lineWidth: 0.5)
                )

                if isComposing {
                    // Send button
                    Button(action: sendMessage) {
                        Image(systemName: "paperplane.fill")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.white)
                            .frame(width: 36, height: 36)
                            .background(Circle().fill(messageText.trimmingCharacters(in: .whitespaces).isEmpty ? Color.white.opacity(0.15) : Color.dynamicAccent(theme: themeManager.currentTheme)))
                    }
                    .disabled(messageText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                } else {
                    // Heart quick reaction (like Instagram)
                    Button { onReact("❤️") } label: {
                        Image(systemName: "heart.fill")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.white)
                            .frame(width: 36, height: 36)
                            .background(Circle().fill(Color.red))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .frame(maxWidth: .infinity)
    }

    private func sendMessage() {
        let text = messageText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        onSendMessage(text)
        messageText = ""
        withAnimation(.spring(response: 0.25, dampingFraction: 0.9)) {
            isComposing = false
        }
        isTextFocused = false
    }
}
