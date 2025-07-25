//
//  MessageBubbleView.swift
//  Gym_API
//
//  Created by Assistant on 7/24/25.
//
//  Vista de burbuja de mensaje estilo iMessage

import SwiftUI

struct MessageBubbleView: View {
    let message: StreamChatMessage
    let themeManager: ThemeManager
    
    var body: some View {
        HStack {
            if message.isFromCurrentUser {
                Spacer(minLength: 60)
                messageBubbleContent(isFromCurrentUser: true)
            } else {
                messageBubbleContent(isFromCurrentUser: false)
                Spacer(minLength: 60)
            }
        }
        .padding(.vertical, 1)
    }
    
    func messageBubbleContent(isFromCurrentUser: Bool) -> some View {
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
    
    private func formatMessageTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

struct TypingIndicatorView: View {
    let typingUsers: [String]
    let themeManager: ThemeManager
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 3) {
                Text("\(typingUsers.joined(separator: ", ")) está escribiendo...")
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
}

struct SimpleInputView: View {
    @Binding var newMessage: String
    let onSendMessage: () -> Void
    let onTypingStart: () -> Void
    let onTypingStop: () -> Void
    let themeManager: ThemeManager
    
    @State private var isRecording = false
    @State private var recordingTime: TimeInterval = 0
    @State private var recordingTimer: Timer?
    
    var body: some View {
        VStack(spacing: 0) {
            // Divider
            Rectangle()
                .fill(Color.dynamicBorder(theme: themeManager.currentTheme))
                .frame(height: 0.5)
            
            HStack(spacing: 8) {
                // Camera Button
                Button(action: {}) {
                    Image(systemName: "camera.circle.fill")
                        .font(.system(size: 28))
                        .foregroundColor(Color.dynamicTextSecondary(theme: themeManager.currentTheme))
                }
                
                // Text Input Container
                HStack(spacing: 8) {
                    TextField("Mensaje", text: $newMessage, axis: .vertical)
                        .font(.system(size: 16))
                        .foregroundColor(Color.dynamicText(theme: themeManager.currentTheme))
                        .lineLimit(1...5)
                        .textFieldStyle(PlainTextFieldStyle())
                        .onSubmit {
                            onSendMessage()
                        }
                        .onChange(of: newMessage) { _, newValue in
                            if !newValue.isEmpty {
                                onTypingStart()
                            } else {
                                onTypingStop()
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
                
                // Send Button
                if !newMessage.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    Button(action: onSendMessage) {
                        Image(systemName: "arrow.up.circle.fill")
                            .font(.system(size: 28))
                            .foregroundColor(Color.dynamicAccent(theme: themeManager.currentTheme))
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
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color.dynamicBackground(theme: themeManager.currentTheme))
        }
        .animation(.spring(response: 0.3, dampingFraction: 0.8), value: newMessage.isEmpty)
    }
    
    // MARK: - Voice Recording Functions
    
    private func startVoiceRecording() {
        print("🎤 Iniciando grabación de voz (SimpleInputView)")
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

// MARK: - Voice Recording Button Component (Simple Version)

struct VoiceRecordingButtonSimple: View {
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
                    .frame(width: 44, height: 44) // Tamaño fijo y grande
                    .overlay(
                        Image(systemName: "mic.circle.fill")
                            .font(.system(size: 26, weight: .semibold))
                            .foregroundColor(.white)
                    )
                    .scaleEffect(isLongPressed || isRecording ? 1.2 : 1.0)
            }
            .disabled(true) // Deshabilitamos el tap normal
            
            // Overlay para grabación activa
            if isRecording {
                VStack(spacing: 4) {
                    if showCancelText {
                        Text("⬅️ Desliza para cancelar")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(.red)
                            .transition(.opacity)
                    } else {
                        HStack(spacing: 4) {
                            Circle()
                                .fill(Color.red)
                                .frame(width: 8, height: 8)
                                .opacity(0.8)
                            Text("Grabando... \(String(format: "%.1fs", recordingTime))")
                                .font(.system(size: 11, weight: .medium))
                                .foregroundColor(Color.dynamicText(theme: themeManager.currentTheme))
                        }
                    }
                }
                .offset(y: -35)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .frame(width: 60, height: 60) // Área de toque grande
        .contentShape(Rectangle()) // Toda el área es tocable
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isLongPressed)
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isRecording)
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
                            showCancelText = (drag?.translation.width ?? 0) < -30
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
                            if let dragValue = drag, dragValue.translation.width < -50 {
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