//
//  SimpleiMessageChatView.swift
//  Gym_API
//
//  Created by Assistant on 7/24/25.
//
//  Chat simple estilo iMessage usando componentes nativos de SwiftUI

import SwiftUI

struct SimpleiMessageChatView: View {
    let eventId: String
    let eventTitle: String
    @ObservedObject var authService: AuthServiceDirect
    @EnvironmentObject var themeManager: ThemeManager
    
    @ObservedObject private var chatService = ChatService.shared
    @ObservedObject private var streamChatService = StreamChatService.shared
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var streamToken: StreamTokenResponse?
    @State private var chatRoom: ChatRoomSchema?
    @State private var newMessage = ""
    @State private var hasLoadedChat = false
    @State private var isRecording = false
    @State private var recordingTime: TimeInterval = 0
    @State private var recordingTimer: Timer?
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        VStack(spacing: 0) {
            // Header estilo iMessage
            iMessageHeader
            
            // Chat Content
            if isLoading || streamChatService.isLoading {
                LoadingChatView(themeManager: themeManager)
            } else if let errorMessage = errorMessage ?? streamChatService.errorMessage {
                ErrorChatView(message: errorMessage, themeManager: themeManager, onRetry: loadChatRoom)
            } else if streamChatService.isConnected {
                // iMessage Style Chat Interface
                VStack(spacing: 0) {
                    // Messages List
                    ScrollViewReader { proxy in
                        ScrollView {
                            LazyVStack(spacing: 2) {
                                ForEach(streamChatService.messages) { message in
                                    iMessageBubble(message: message)
                                        .id(message.id)
                                }
                                
                                // Typing Indicator
                                if !streamChatService.typingUsers.isEmpty {
                                    iMessageTypingIndicator
                                        .padding(.top, 8)
                                }
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 12)
                        }
                        .background(Color.dynamicBackground(theme: themeManager.currentTheme))
                        .onChange(of: streamChatService.messages.count) { _, _ in
                            if let lastMessage = streamChatService.messages.last {
                                withAnimation(.easeOut(duration: 0.3)) {
                                    proxy.scrollTo(lastMessage.id, anchor: .bottom)
                                }
                            }
                        }
                    }
                    
                    // iMessage Input View
                    iMessageInputView
                }
            } else {
                // Fallback Interface
                VStack {
                    Spacer()
                    Text("Conectando al chat...")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(Color.dynamicTextSecondary(theme: themeManager.currentTheme))
                    Spacer()
                }
            }
        }
        .background(Color.dynamicBackground(theme: themeManager.currentTheme))
        .navigationBarHidden(true)
        .onAppear {
            loadChatRoom()
        }
        .onDisappear {
            hasLoadedChat = false
            Task {
                streamChatService.disconnect()
            }
        }
    }
    
    // MARK: - iMessage Components
    
    var iMessageHeader: some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                // Back Button
                Button(action: { dismiss() }) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(Color.dynamicAccent(theme: themeManager.currentTheme))
                }
                
                // Profile Image
                Circle()
                    .fill(Color.dynamicAccent(theme: themeManager.currentTheme))
                    .frame(width: 32, height: 32)
                    .overlay(
                        Text(eventTitle.prefix(1).uppercased())
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(.white)
                    )
                
                // Event Info
                VStack(alignment: .leading, spacing: 1) {
                    Text(eventTitle)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(Color.dynamicText(theme: themeManager.currentTheme))
                    
                    if streamChatService.isConnected {
                        Text("Online")
                            .font(.system(size: 13))
                            .foregroundColor(Color.dynamicTextSecondary(theme: themeManager.currentTheme))
                    }
                }
                
                Spacer()
                
                // Info Button (estilo iMessage)
                Button(action: {}) {
                    Image(systemName: "info.circle")
                        .font(.system(size: 18))
                        .foregroundColor(Color.dynamicAccent(theme: themeManager.currentTheme))
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(Color.dynamicSurface(theme: themeManager.currentTheme))
            
            // Divider
            Rectangle()
                .fill(Color.dynamicBorder(theme: themeManager.currentTheme))
                .frame(height: 0.5)
        }
    }
    
    func iMessageBubble(message: StreamChatMessage) -> some View {
        HStack {
            if message.isFromCurrentUser {
                Spacer(minLength: 60)
                messageBubbleContent(message: message, isFromCurrentUser: true)
            } else {
                messageBubbleContent(message: message, isFromCurrentUser: false)
                Spacer(minLength: 60)
            }
        }
        .padding(.vertical, 1)
    }
    
    func messageBubbleContent(message: StreamChatMessage, isFromCurrentUser: Bool) -> some View {
        VStack(alignment: isFromCurrentUser ? .trailing : .leading, spacing: 3) {
            // Bubble
            HStack {
                if isFromCurrentUser {
                    Spacer(minLength: 0)
                }
                
                Text(message.text)
                    .font(.system(size: 16))
                    .foregroundColor(isFromCurrentUser ? .white : Color.dynamicText(theme: themeManager.currentTheme))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(
                        RoundedRectangle(cornerRadius: 18)
                            .fill(isFromCurrentUser ? 
                                  Color.dynamicAccent(theme: themeManager.currentTheme) :
                                  Color.dynamicSurface(theme: themeManager.currentTheme))
                    )
                
                if !isFromCurrentUser {
                    Spacer(minLength: 0)
                }
            }
            
            // Timestamp
            Text(formatMessageTime(message.timestamp))
                .font(.system(size: 11))
                .foregroundColor(Color.dynamicTextSecondary(theme: themeManager.currentTheme))
                .padding(.horizontal, 6)
        }
    }
    
    var iMessageTypingIndicator: some View {
        HStack {
            VStack(alignment: .leading, spacing: 3) {
                Text("\(streamChatService.typingUsers.joined(separator: ", ")) está escribiendo...")
                    .font(.system(size: 13))
                    .foregroundColor(Color.dynamicTextSecondary(theme: themeManager.currentTheme))
                
                HStack(spacing: 4) {
                    ForEach(0..<3, id: \.self) { index in
                        Circle()
                            .fill(Color.dynamicTextSecondary(theme: themeManager.currentTheme))
                            .frame(width: 4, height: 4)
                            .opacity(0.5)
                            .animation(
                                Animation.easeInOut(duration: 0.6)
                                    .repeatForever(autoreverses: true)
                                    .delay(Double(index) * 0.2),
                                value: Date()
                            )
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(
                    RoundedRectangle(cornerRadius: 18)
                        .fill(Color.dynamicSurface(theme: themeManager.currentTheme))
                )
            }
            
            Spacer(minLength: 60)
        }
    }
    
    var iMessageInputView: some View {
        VStack(spacing: 0) {
            // Divider
            Rectangle()
                .fill(Color.dynamicBorder(theme: themeManager.currentTheme))
                .frame(height: 0.5)
            
            HStack(spacing: 8) {
                // Camera Button (estilo iMessage)
                Button(action: {}) {
                    Image(systemName: "camera.circle.fill")
                        .font(.system(size: 28))
                        .foregroundColor(Color.dynamicTextSecondary(theme: themeManager.currentTheme))
                }
                
                // Text Input Container
                HStack(spacing: 8) {
                    TextField("iMessage", text: $newMessage, axis: .vertical)
                        .font(.system(size: 16))
                        .foregroundColor(Color.dynamicText(theme: themeManager.currentTheme))
                        .lineLimit(1...5)
                        .textFieldStyle(PlainTextFieldStyle())
                        .onSubmit {
                            sendMessage()
                        }
                        .onChange(of: newMessage) { _, newValue in
                            if !newValue.isEmpty {
                                streamChatService.startTyping()
                            } else {
                                streamChatService.stopTyping()
                            }
                        }
                    
                    // Emoji/Plus Button
                    if newMessage.isEmpty {
                        Button(action: {}) {
                            Image(systemName: "plus.circle.fill")
                                .font(.system(size: 22))
                                .foregroundColor(Color.dynamicTextSecondary(theme: themeManager.currentTheme))
                        }
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(
                    RoundedRectangle(cornerRadius: 20)
                        .fill(Color.dynamicSurface(theme: themeManager.currentTheme))
                        .overlay(
                            RoundedRectangle(cornerRadius: 20)
                                .stroke(Color.dynamicBorder(theme: themeManager.currentTheme), lineWidth: 1)
                        )
                )
                
                // Send Button (estilo iMessage)
                if !newMessage.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    Button(action: sendMessage) {
                        Image(systemName: "arrow.up.circle.fill")
                            .font(.system(size: 28))
                            .foregroundColor(Color.dynamicAccent(theme: themeManager.currentTheme))
                    }
                    .transition(.scale.combined(with: .opacity))
                } else {
                    // Voice Recording Button con gestos
                    VoiceRecordingButton(
                        isRecording: $isRecording,
                        recordingTime: $recordingTime,
                        onStartRecording: startVoiceRecording,
                        onStopRecording: stopVoiceRecording,
                        onCancelRecording: cancelVoiceRecording,
                        themeManager: themeManager
                    )
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color.dynamicBackground(theme: themeManager.currentTheme))
        }
        .animation(.spring(response: 0.3, dampingFraction: 0.8), value: newMessage.isEmpty)
    }
    
    // MARK: - Functions
    
    private func loadChatRoom() {
        if isLoading || hasLoadedChat {
            print("⚠️ Chat ya está cargando o ya fue cargado, saltando loadChatRoom")
            return
        }
        
        print("🚀 Iniciando loadChatRoom para evento \(eventId)")
        isLoading = true
        hasLoadedChat = true
        errorMessage = nil
        
        chatService.authService = authService
        
        Task {
            do {
                guard let eventIdInt = Int(eventId) else {
                    errorMessage = "ID de evento inválido"
                    isLoading = false
                    return
                }
                
                if let chatData = await chatService.getChatDataForEvent(eventId: eventIdInt) {
                    streamToken = chatData.token
                    chatRoom = chatData.room
                    
                    print("✅ Chat cargado exitosamente")
                    print("🎫 Token obtenido para usuario ID: \(chatData.token.internalUserId)")
                    print("💬 Canal: \(chatData.room.streamChannelId)")
                    
                    let formattedUserId = "user_\(chatData.token.internalUserId)"
                    print("🔍 User ID que enviaremos a Stream: \(formattedUserId)")
                    
                    streamChatService.connectToChat(
                        token: chatData.token.token,
                        apiKey: chatData.token.apiKey,
                        userId: formattedUserId,
                        channelId: chatData.room.streamChannelId
                    )
                    
                    isLoading = false
                } else {
                    errorMessage = "No se pudieron obtener datos del chat"
                    print("⚠️ No se pudieron obtener datos del chat")
                    isLoading = false
                }
            }
        }
    }
    
    private func sendMessage() {
        guard !newMessage.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        
        let messageToSend = newMessage.trimmingCharacters(in: .whitespacesAndNewlines)
        streamChatService.sendMessage(messageToSend)
        newMessage = ""
    }
    
    private func formatMessageTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
    
    // MARK: - Voice Recording Functions
    
    private func startVoiceRecording() {
        print("🎤 Iniciando grabación de voz")
        isRecording = true
        recordingTime = 0
        
        // Vibración de inicio
        let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
        impactFeedback.impactOccurred()
        
        // Timer para contar tiempo de grabación en el main thread
        recordingTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { _ in
            DispatchQueue.main.async {
                self.recordingTime += 0.1
            }
        }
        
        // Asegurarse de que el timer se ejecute en el main run loop
        if let timer = recordingTimer {
            RunLoop.main.add(timer, forMode: .common)
        }
        
        // TODO: Iniciar grabación real con AVAudioRecorder
    }
    
    private func stopVoiceRecording() {
        print("🎤 Deteniendo grabación de voz (duración: \(recordingTime)s)")
        isRecording = false
        recordingTimer?.invalidate()
        recordingTimer = nil
        
        // Vibración de finalización
        let impactFeedback = UIImpactFeedbackGenerator(style: .light)
        impactFeedback.impactOccurred()
        
        if recordingTime > 1.0 {
            // Solo enviar si la grabación dura más de 1 segundo
            print("✅ Grabación enviada")
            // TODO: Procesar y enviar archivo de audio
        } else {
            print("⚠️ Grabación muy corta, cancelada")
        }
        
        recordingTime = 0
    }
    
    private func cancelVoiceRecording() {
        print("❌ Grabación de voz cancelada")
        isRecording = false
        recordingTimer?.invalidate()
        recordingTimer = nil
        recordingTime = 0
        
        // Vibración de cancelación
        let impactFeedback = UIImpactFeedbackGenerator(style: .heavy)
        impactFeedback.impactOccurred()
    }
}

// MARK: - Voice Recording Button Component

struct VoiceRecordingButton: View {
    @Binding var isRecording: Bool
    @Binding var recordingTime: TimeInterval
    let onStartRecording: () -> Void
    let onStopRecording: () -> Void
    let onCancelRecording: () -> Void
    let themeManager: ThemeManager
    
    @GestureState private var isLongPressed = false
    @State private var dragOffset = CGSize.zero
    @State private var showCancelText = false
    
    var body: some View {
        ZStack {
            // Botón principal - tamaño fijo y grande
            Button(action: {}) {
                Circle()
                    .fill(isRecording ? Color.red : Color.dynamicTextSecondary(theme: themeManager.currentTheme))
                    .frame(width: 50, height: 50) // Tamaño fijo y grande
                    .overlay(
                        Image(systemName: "mic.circle.fill")
                            .font(.system(size: 30, weight: .semibold))
                            .foregroundColor(.white)
                    )
                    .scaleEffect(isLongPressed || isRecording ? 1.15 : 1.0)
            }
            .disabled(true) // Deshabilitamos el tap normal
            
            // Overlay para grabación activa
            if isRecording {
                VStack(spacing: 6) {
                    if showCancelText {
                        Text("⬅️ Desliza para cancelar")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(.red)
                            .transition(.opacity)
                    } else {
                        VStack(spacing: 2) {
                            HStack(spacing: 6) {
                                Circle()
                                    .fill(Color.red)
                                    .frame(width: 10, height: 10)
                                    .opacity(0.8)
                                Text("Grabando...")
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundColor(Color.dynamicText(theme: themeManager.currentTheme))
                            }
                            Text(String(format: "%.1fs", recordingTime))
                                .font(.system(size: 11, weight: .medium))
                                .foregroundColor(Color.dynamicTextSecondary(theme: themeManager.currentTheme))
                        }
                    }
                }
                .offset(y: -65)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .frame(width: 70, height: 70) // Área de toque muy grande
        .contentShape(Rectangle()) // Toda el área es tocable
        .animation(.spring(response: 0.25, dampingFraction: 0.8), value: isLongPressed)
        .animation(.spring(response: 0.25, dampingFraction: 0.8), value: isRecording)
        .animation(.easeInOut(duration: 0.2), value: showCancelText)
        .gesture(
            // Combinar gesto de presión larga con arrastre
            LongPressGesture(minimumDuration: 0.3) // Duración mínima para activar
                .sequenced(before: DragGesture())
                .updating($isLongPressed) { value, state, transaction in
                    switch value {
                    case .first(true):
                        state = true
                        if !isRecording {
                            onStartRecording()
                        }
                    case .second(true, let drag):
                        state = true
                        if isRecording {
                            dragOffset = drag?.translation ?? .zero
                            showCancelText = (drag?.translation.width ?? 0) < -40
                        }
                    default:
                        state = false
                    }
                }
                .onEnded { value in
                    dragOffset = .zero
                    showCancelText = false
                    
                    switch value {
                    case .first(false):
                        // Se soltó antes de completar la presión larga - no hacer nada
                        break
                    case .second(true, let drag):
                        if isRecording {
                            if let dragValue = drag, dragValue.translation.width < -60 {
                                onCancelRecording()
                            } else {
                                onStopRecording()
                            }
                        }
                    default:
                        if isRecording {
                            onStopRecording()
                        }
                    }
                }
        )
    }
}

// MARK: - Preview

#Preview {
    SimpleiMessageChatView(
        eventId: "608",
        eventTitle: "Torneo Interno",
        authService: AuthServiceDirect()
    )
    .environmentObject(ThemeManager())
}