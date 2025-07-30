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
            
            ZStack {
                // Barra de chat normal
                HStack(spacing: 8) {
                    // Camera Button (estilo iMessage)
                    Button(action: {}) {
                        Image(systemName: "camera.circle.fill")
                            .font(.system(size: 24))
                            .foregroundColor(Color.dynamicTextSecondary(theme: themeManager.currentTheme))
                            .frame(width: 36, height: 36)
                    }
                    
                    // Text Input Container
                    HStack(spacing: 8) {
                        ZStack(alignment: .leading) {
                            if newMessage.isEmpty {
                                Text("iMessage")
                                    .font(.system(size: 16))
                                    .foregroundColor(Color.dynamicTextSecondary(theme: themeManager.currentTheme).opacity(0.6))
                            }
                            
                            TextField("", text: $newMessage, axis: .vertical)
                                .font(.system(size: 16))
                                .foregroundColor(Color.dynamicText(theme: themeManager.currentTheme))
                                .lineLimit(1...5)
                                .textFieldStyle(PlainTextFieldStyle())
                                .frame(minHeight: 20)
                                .padding(.vertical, 0)
                                .accentColor(Color.dynamicAccent(theme: themeManager.currentTheme))
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
                        }
                        
                        // Emoji/Plus Button
                        if newMessage.isEmpty {
                            Button(action: {}) {
                                Image(systemName: "plus.circle.fill")
                                    .font(.system(size: 20))
                                    .foregroundColor(Color.dynamicTextSecondary(theme: themeManager.currentTheme))
                                    .frame(width: 30, height: 30)
                            }
                        }
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
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
                                .font(.system(size: 24))
                                .foregroundColor(Color.dynamicAccent(theme: themeManager.currentTheme))
                                .frame(width: 36, height: 36)
                        }
                        .transition(.scale.combined(with: .opacity))
                    } else {
                        // Voice Recording Button con gestos
                        VoiceRecordingButtonSimple(
                            isRecording: $isRecording,
                            recordingTime: $recordingTime,
                            onStartRecording: startVoiceRecording,
                            onStopRecording: stopVoiceRecording,
                            onCancelRecording: cancelVoiceRecording,
                            themeManager: themeManager
                        )
                    }
                }
                .opacity(isRecording ? 0 : 1)
                .animation(.easeInOut(duration: 0.2), value: isRecording)
                
                // Interfaz de grabación estilo WhatsApp
                if isRecording {
                    HStack(spacing: 12) {
                        // Timer de grabación
                        HStack(spacing: 6) {
                            Circle()
                                .fill(Color.red)
                                .frame(width: 8, height: 8)
                                .opacity(recordingTime.truncatingRemainder(dividingBy: 1.0) < 0.5 ? 1 : 0.3)
                            
                            Text(String(format: "%01d:%02d", Int(recordingTime) / 60, Int(recordingTime) % 60))
                                .font(.system(size: 16, weight: .medium, design: .monospaced))
                                .foregroundColor(Color.dynamicText(theme: themeManager.currentTheme))
                        }
                        
                        Spacer()
                        
                        // Texto "Desliza para cancelar" con flechas
                        HStack(spacing: 4) {
                            Image(systemName: "chevron.left")
                                .font(.system(size: 12, weight: .medium))
                            Image(systemName: "chevron.left")
                                .font(.system(size: 12, weight: .medium))
                            Text("Desliza para cancelar")
                                .font(.system(size: 14, weight: .medium))
                        }
                        .foregroundColor(Color.gray)
                        .onLongPressGesture(minimumDuration: 0.01, pressing: { _ in }) {
                            // No hacer nada - esto previene interferencias
                        }
                        .simultaneousGesture(
                            DragGesture(minimumDistance: 10)
                                .onEnded { drag in
                                    if drag.translation.width < -50 {
                                        cancelVoiceRecording()
                                    }
                                }
                        )
                        
                        Spacer()
                        
                        // Espacio para mantener proporción
                        Color.clear
                            .frame(width: 36, height: 36)
                    }
                    .transition(.opacity.combined(with: .scale(scale: 0.95)))
                    .animation(.easeInOut(duration: 0.2), value: isRecording)
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
        print("🔍 authService.isAuthenticated: \(authService.isAuthenticated)")
        print("🔍 authService.user: \(authService.user?.email ?? "nil")")
        isLoading = true
        hasLoadedChat = true
        errorMessage = nil
        
        chatService.authService = authService
        
        Task {
            do {
                guard let eventIdInt = Int(eventId) else {
                    print("❌ Error: No se pudo convertir eventId '\(eventId)' a Int")
                    await MainActor.run {
                        errorMessage = "ID de evento inválido: \(eventId)"
                        isLoading = false
                    }
                    return
                }
                
                print("✅ eventId convertido exitosamente: \(eventIdInt)")
                print("🔄 Llamando getChatDataForEvent...")
                
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
                    print("❌ Error: getChatDataForEvent devolvió nil")
                    await MainActor.run {
                        errorMessage = "No se pudo cargar el chat para el evento \(eventIdInt)"
                        isLoading = false
                    }
                    return
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
        
        // Usar async para evitar modificar estado durante actualización de vista
        DispatchQueue.main.async {
            self.isRecording = true
            self.recordingTime = 0
            
            // Vibración de inicio
            let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
            impactFeedback.impactOccurred()
            
            // Timer para contar tiempo de grabación
            self.recordingTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { _ in
                DispatchQueue.main.async {
                    self.recordingTime += 0.1
                }
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
        
        DispatchQueue.main.async {
            self.isRecording = false
            self.recordingTimer?.invalidate()
            self.recordingTimer = nil
            
            // Vibración de finalización
            let impactFeedback = UIImpactFeedbackGenerator(style: .light)
            impactFeedback.impactOccurred()
        }
        
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
        
        DispatchQueue.main.async {
            self.isRecording = false
            self.recordingTimer?.invalidate()
            self.recordingTimer = nil
            self.recordingTime = 0
            
            // Vibración de cancelación
            let impactFeedback = UIImpactFeedbackGenerator(style: .heavy)
            impactFeedback.impactOccurred()
        }
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
        .onLongPressGesture(minimumDuration: 0.1, pressing: { pressing in
            print("🎤 handlePressChange (iMessage): pressing=\(pressing), isRecording=\(isRecording)")
            
            withAnimation(.easeInOut(duration: 0.1)) {
                // pressingDown = pressing (esta variable no existe en esta versión)
            }
            
            if pressing {
                // Iniciar grabación cuando empiece el long press
                if !isRecording {
                    print("🎤 Iniciando grabación desde iMessage")
                    onStartRecording()
                }
            } else {
                // Detener grabación cuando se suelte el botón
                if isRecording {
                    print("🎤 Deteniendo grabación desde iMessage")
                    onStopRecording()
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                        dragOffset = .zero
                        showCancelText = false
                    }
                }
            }
        }) {
            // No hacer nada aquí para evitar llamadas duplicadas
            print("🎤 Long press completado (iMessage sin acción)")
        }
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { drag in
                    if isRecording {
                        let translation = drag.translation
                        
                        // Actualizar offset con límites
                        dragOffset = CGSize(
                            width: max(-100, min(0, translation.width)),
                            height: max(-100, min(0, translation.height))
                        )
                        
                        // Detectar zona de cancelar
                        showCancelText = translation.width < -50
                    }
                }
                .onEnded { drag in
                    if isRecording {
                        let translation = drag.translation
                        
                        // Resetear estados visuales
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                            dragOffset = .zero
                            showCancelText = false
                        }
                        
                        // Verificar si se deslizó hacia la izquierda para cancelar
                        if translation.width < -60 {
                            onCancelRecording()
                        } else {
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