//
//  EnhancedMessageInput.swift
//  Gym_API
//
//  Created by Assistant on 7/24/25.
//
//  Input de mensajes mejorado con soporte multimedia

import SwiftUI
import PhotosUI

struct EnhancedMessageInput: View {
    @Binding var text: String
    let onSendMessage: () -> Void
    let onSendMedia: ([MediaItem]) -> Void
    let onTypingStart: (() -> Void)?
    let onTypingStop: (() -> Void)?
    let themeManager: ThemeManager
    
    @State private var showAttachmentMenu = false
    @State private var showMediaPicker = false
    @State private var showCamera = false
    @StateObject private var audioRecorder = AudioRecorderService.shared
    
    var body: some View {
        VStack(spacing: 0) {
            // Divider
            Rectangle()
                .fill(Color.dynamicBorder(theme: themeManager.currentTheme))
                .frame(height: 1)
            
            HStack(spacing: 12) {
                // Attachment Button
                Button(action: {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                        showAttachmentMenu.toggle()
                    }
                }) {
                    Image(systemName: showAttachmentMenu ? "xmark" : "plus")
                        .font(.system(size: 18, weight: .medium))
                        .foregroundColor(Color.dynamicTextSecondary(theme: themeManager.currentTheme))
                        .frame(width: 32, height: 32)
                        .background(
                            Circle()
                                .fill(showAttachmentMenu ? 
                                     Color.dynamicAccent(theme: themeManager.currentTheme).opacity(0.2) :
                                     Color.dynamicSurface(theme: themeManager.currentTheme))
                        )
                        .rotationEffect(.degrees(showAttachmentMenu ? 45 : 0))
                }
                
                // Text Input or Recording View
                if audioRecorder.isRecording {
                    // Voice Recording View
                    HStack(spacing: 12) {
                        // Recording Indicator
                        HStack(spacing: 8) {
                            Circle()
                                .fill(Color.red)
                                .frame(width: 8, height: 8)
                                .opacity(audioRecorder.recordingTime.truncatingRemainder(dividingBy: 1) < 0.5 ? 1 : 0.3)
                            
                            Text(audioRecorder.formatDuration(audioRecorder.recordingTime))
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(Color.dynamicText(theme: themeManager.currentTheme))
                        }
                        
                        // Audio Level Indicator
                        HStack(spacing: 2) {
                            ForEach(0..<5) { index in
                                RoundedRectangle(cornerRadius: 2)
                                    .fill(Color.red.opacity(Double(index) / 5 < Double(audioRecorder.audioLevel) ? 1 : 0.3))
                                    .frame(width: 3, height: CGFloat(8 + index * 2))
                            }
                        }
                        
                        Spacer()
                        
                        // Cancel Recording
                        Button(action: {
                            audioRecorder.cancelRecording()
                        }) {
                            Text("Cancelar")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(.red)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .background(
                        RoundedRectangle(cornerRadius: 20)
                            .fill(Color.dynamicSurface(theme: themeManager.currentTheme))
                    )
                } else {
                    // Text Input
                    HStack(spacing: 8) {
                        TextField("Escribe un mensaje...", text: $text, axis: .vertical)
                            .font(.system(size: 15, weight: .medium))
                            .foregroundColor(Color.dynamicText(theme: themeManager.currentTheme))
                            .lineLimit(1...4)
                            .textFieldStyle(PlainTextFieldStyle())
                            .onSubmit {
                                if !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                                    onSendMessage()
                                }
                            }
                            .onChange(of: text) { _, newValue in
                                if !newValue.isEmpty {
                                    onTypingStart?()
                                } else {
                                    onTypingStop?()
                                }
                            }
                        
                        // Camera Button
                        Button(action: {
                            showCamera = true
                        }) {
                            Image(systemName: "camera")
                                .font(.system(size: 16))
                                .foregroundColor(Color.dynamicTextSecondary(theme: themeManager.currentTheme))
                        }
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(
                        RoundedRectangle(cornerRadius: 20)
                            .fill(Color.dynamicSurface(theme: themeManager.currentTheme))
                    )
                }
                
                // Send/Voice Button
                Button(action: {
                    if audioRecorder.isRecording {
                        stopRecording()
                    } else if !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        onSendMessage()
                    } else {
                        startRecording()
                    }
                }) {
                    Image(systemName: audioRecorder.isRecording ? "stop.circle.fill" : 
                          (text.isEmpty ? "mic.circle.fill" : "arrow.up.circle.fill"))
                        .font(.system(size: 28))
                        .foregroundColor(audioRecorder.isRecording ? .red : 
                                       (text.isEmpty ? Color.dynamicTextSecondary(theme: themeManager.currentTheme) : 
                                        Color.dynamicAccent(theme: themeManager.currentTheme)))
                }
                .scaleEffect(audioRecorder.isRecording ? 1.1 : 1.0)
                .animation(.easeInOut(duration: 0.3), value: audioRecorder.isRecording)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(Color.dynamicBackground(theme: themeManager.currentTheme))
            
            // Attachment Menu
            if showAttachmentMenu {
                AttachmentMenuView(
                    onPhotoTap: {
                        showMediaPicker = true
                        showAttachmentMenu = false
                    },
                    onCameraTap: {
                        showCamera = true
                        showAttachmentMenu = false
                    },
                    onLocationTap: {
                        // TODO: Implementar compartir ubicación
                        showAttachmentMenu = false
                    },
                    themeManager: themeManager
                )
                .transition(.scale.combined(with: .opacity))
            }
        }
        .sheet(isPresented: $showMediaPicker) {
            MediaPickerView(
                isPresented: $showMediaPicker,
                onMediaSelected: onSendMedia
            )
            .environmentObject(themeManager)
        }
        .sheet(isPresented: $showCamera) {
            CameraView { image in
                onSendMedia([MediaItem(type: .image(image))])
                showCamera = false
            }
        }
    }
    
    // MARK: - Voice Recording Functions
    
    private func startRecording() {
        Task {
            do {
                let success = try await audioRecorder.startRecording()
                if !success {
                    print("❌ No se pudo iniciar la grabación - permisos denegados")
                }
            } catch {
                print("❌ Error al iniciar grabación: \(error)")
            }
        }
    }
    
    private func stopRecording() {
        if let audioURL = audioRecorder.stopRecording(),
           let duration = audioRecorder.getAudioDuration(from: audioURL) {
            // Enviar el mensaje de voz
            let mediaItem = MediaItem(type: .voice(audioURL, duration: duration))
            onSendMedia([mediaItem])
        }
    }
}

// MARK: - Attachment Menu View
struct AttachmentMenuView: View {
    let onPhotoTap: () -> Void
    let onCameraTap: () -> Void
    let onLocationTap: () -> Void
    let themeManager: ThemeManager
    
    var body: some View {
        HStack(spacing: 24) {
            // Photo Library
            AttachmentButton(
                icon: "photo",
                title: "Fotos",
                color: .blue,
                action: onPhotoTap,
                themeManager: themeManager
            )
            
            // Camera
            AttachmentButton(
                icon: "camera",
                title: "Cámara",
                color: .green,
                action: onCameraTap,
                themeManager: themeManager
            )
            
            // Location
            AttachmentButton(
                icon: "location",
                title: "Ubicación",
                color: .orange,
                action: onLocationTap,
                themeManager: themeManager
            )
            
            Spacer()
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 16)
        .background(
            Color.dynamicSurface(theme: themeManager.currentTheme)
                .shadow(color: Color.black.opacity(0.1), radius: 8, x: 0, y: -4)
        )
    }
}

// MARK: - Attachment Button
struct AttachmentButton: View {
    let icon: String
    let title: String
    let color: Color
    let action: () -> Void
    let themeManager: ThemeManager
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                ZStack {
                    Circle()
                        .fill(color.opacity(0.2))
                        .frame(width: 50, height: 50)
                    
                    Image(systemName: icon)
                        .font(.system(size: 22))
                        .foregroundColor(color)
                }
                
                Text(title)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(Color.dynamicText(theme: themeManager.currentTheme))
            }
        }
    }
}