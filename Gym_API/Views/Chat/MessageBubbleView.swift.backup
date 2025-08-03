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
            
            ZStack {
                // Barra de chat normal
                HStack(spacing: 8) {
                    // Camera Button
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
                                Text("Mensaje")
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
                                    onSendMessage()
                                }
                                .onChange(of: newMessage) { _, newValue in
                                    if !newValue.isEmpty {
                                        onTypingStart()
                                    } else {
                                        onTypingStop()
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
                    
                    // Send Button
                    if !newMessage.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        Button(action: onSendMessage) {
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
    
    // MARK: - Voice Recording Functions
    
    private func startVoiceRecording() {
        print("🎤 Iniciando grabación de voz (SimpleInputView)")
        
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
    @State private var showLockZone = false
    @State private var isLocked = false
    @State private var pressingDown = false
    
    var body: some View {
        ZStack {
            // Solo indicador de bloqueo (arriba) - simplificado
            if isRecording && !isLocked {
                VStack(spacing: 4) {
                    Image(systemName: "lock.fill")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(showLockZone ? .white : Color.gray)
                        .padding(10)
                        .background(
                            Circle()
                                .fill(showLockZone ? Color.blue : Color.gray.opacity(0.3))
                        )
                        .scaleEffect(showLockZone ? 1.1 : 1.0)
                    
                    Image(systemName: "chevron.up")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(Color.gray)
                }
                .offset(y: -80)
                .opacity(isRecording ? 1 : 0)
                .animation(.easeInOut(duration: 0.2), value: showLockZone)
            }
            
            // Botón principal
            Circle()
                .fill(pressingDown || isRecording ? Color.red : Color.dynamicAccent(theme: themeManager.currentTheme))
                .frame(width: pressingDown || isRecording ? 44 : 36, height: pressingDown || isRecording ? 44 : 36)
                .overlay(
                    Image(systemName: isLocked ? "stop.fill" : "mic.fill")
                        .font(.system(size: pressingDown || isRecording ? 20 : 16, weight: .semibold))
                        .foregroundColor(.white)
                )
                .scaleEffect(pressingDown && !isLocked ? 1.15 : 1.0)
                .offset(dragOffset)
                .shadow(color: pressingDown || isRecording ? Color.red.opacity(0.3) : Color.clear, radius: 6, x: 0, y: 3)
            
            // Timer de grabación
            if isRecording {
                HStack(spacing: 4) {
                    Circle()
                        .fill(Color.red)
                        .frame(width: 8, height: 8)
                        .opacity(recordingTime.truncatingRemainder(dividingBy: 1.0) < 0.5 ? 1 : 0.3)
                    
                    Text(String(format: "%02d:%02d", Int(recordingTime) / 60, Int(recordingTime) % 60))
                        .font(.system(size: 14, weight: .semibold, design: .monospaced))
                        .foregroundColor(Color.dynamicText(theme: themeManager.currentTheme))
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 4)
                .background(
                    Capsule()
                        .fill(Color.dynamicSurface(theme: themeManager.currentTheme))
                        .shadow(color: Color.black.opacity(0.1), radius: 4, x: 0, y: 2)
                )
                .offset(y: isLocked ? -50 : -45)
                .transition(.scale.combined(with: .opacity))
            }
        }
        .frame(width: 60, height: 60) // Área de toque
        .zIndex(isRecording ? 10 : 1) // Elevar cuando esté grabando
        .contentShape(Rectangle())
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isLongPressed)
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isRecording)
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isLocked)
        .animation(.easeInOut(duration: 0.2), value: dragOffset)
        .onTapGesture {
            // Si está bloqueado, detener la grabación
            if isLocked {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                    isLocked = false
                    pressingDown = false
                }
                onStopRecording()
            }
        }
        .onLongPressGesture(minimumDuration: 0.1, pressing: { pressing in
            handlePressChange(pressing)
        }) {
            // No hacer nada aquí para evitar llamadas duplicadas
            print("🎤 Long press completado (sin acción)")
        }
        .simultaneousGesture(
            // Solo aplicar gesture de drag si no está bloqueado
            !isLocked ? 
            DragGesture(minimumDistance: 0)
                .onChanged { drag in
                    if isRecording && !isLocked {
                        let translation = drag.translation
                        
                        // Actualizar offset con límites
                        dragOffset = CGSize(
                            width: max(-100, min(0, translation.width)),
                            height: max(-100, min(0, translation.height))
                        )
                        
                        // Solo detectar zona de bloqueo
                        showLockZone = translation.height < -50
                    }
                }
                .onEnded { drag in
                    // Solo procesar si estaba grabando
                    if isRecording && !isLocked {
                        let translation = drag.translation
                        
                        // Resetear estados visuales
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                            dragOffset = .zero
                            showLockZone = false
                        }
                        
                        // Verificar si se deslizó hacia arriba para bloquear
                        if translation.height < -60 {
                            withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                                isLocked = true
                            }
                            // Vibración de bloqueo
                            let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
                            impactFeedback.impactOccurred()
                        }
                        // Si no se bloqueó, detener grabación normal
                        else {
                            onStopRecording()
                            pressingDown = false
                        }
                    }
                }
            : nil
        )
    }
    
    private func handlePressChange(_ pressing: Bool) {
        print("🎤 handlePressChange: pressing=\(pressing), isRecording=\(isRecording), isLocked=\(isLocked)")
        
        withAnimation(.easeInOut(duration: 0.1)) {
            pressingDown = pressing
        }
        
        if pressing {
            // Iniciar grabación cuando empiece el long press (solo si no está ya grabando)
            if !isRecording && !isLocked {
                print("🎤 Iniciando grabación desde handlePressChange")
                onStartRecording()
            }
        } else {
            // Detener grabación cuando se suelte el botón (solo si está grabando y no está bloqueado)
            if isRecording && !isLocked {
                print("🎤 Deteniendo grabación desde handlePressChange")
                onStopRecording()
                withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                    dragOffset = .zero
                    showLockZone = false
                }
            }
        }
    }
}