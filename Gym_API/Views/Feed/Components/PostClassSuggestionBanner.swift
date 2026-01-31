//
//  PostClassSuggestionBanner.swift
//  Gym_API
//
//  Created by Claude on 2026-01-31.
//

import SwiftUI

/// Banner que sugiere al usuario compartir su experiencia después de asistir a una clase
struct PostClassSuggestionBanner: View {
    let attendedClass: AttendedClass
    let onTap: () -> Void
    let onDismiss: () -> Void

    @EnvironmentObject var themeManager: ThemeManager
    @State private var isAnimating = false
    @State private var isDismissed = false

    var body: some View {
        if !isDismissed {
            VStack(spacing: 0) {
                HStack(spacing: 12) {
                    // Ícono animado
                    ZStack {
                        Circle()
                            .fill(
                                LinearGradient(
                                    gradient: Gradient(colors: [
                                        Color.dynamicAccent(theme: themeManager.currentTheme),
                                        Color.dynamicAccent(theme: themeManager.currentTheme).opacity(0.7)
                                    ]),
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: 48, height: 48)
                            .scaleEffect(isAnimating ? 1.1 : 1.0)
                            .animation(
                                .easeInOut(duration: 1.5)
                                .repeatForever(autoreverses: true),
                                value: isAnimating
                            )

                        Image(systemName: "figure.run")
                            .font(.system(size: 20, weight: .bold))
                            .foregroundColor(.white)
                    }

                    // Contenido del mensaje
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text("¿Cómo te fue en")
                                .font(.subheadline)
                                .foregroundColor(.dynamicText(theme: themeManager.currentTheme))

                            Text(attendedClass.className)
                                .font(.subheadline.bold())
                                .foregroundColor(.dynamicText(theme: themeManager.currentTheme))
                                .lineLimit(1)

                            Text("?")
                                .font(.subheadline)
                                .foregroundColor(.dynamicText(theme: themeManager.currentTheme))
                        }

                        HStack(spacing: 4) {
                            Image(systemName: "clock")
                                .font(.caption2)
                                .foregroundColor(.secondary)

                            Text(attendedClass.timeAgoText)
                                .font(.caption)
                                .foregroundColor(.secondary)

                            Text("•")
                                .foregroundColor(.secondary)

                            Text("con \(attendedClass.instructor)")
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .lineLimit(1)
                        }
                    }

                    Spacer()

                    // Botón de cerrar
                    Button {
                        withAnimation(.easeOut(duration: 0.3)) {
                            isDismissed = true
                        }
                        onDismiss()

                        // Haptic feedback
                        let generator = UIImpactFeedbackGenerator(style: .light)
                        generator.impactOccurred()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.secondary)
                            .padding(8)
                            .background(
                                Circle()
                                    .fill(Color.dynamicCard(theme: themeManager.currentTheme))
                            )
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(
                            LinearGradient(
                                gradient: Gradient(colors: [
                                    Color.dynamicCard(theme: themeManager.currentTheme),
                                    Color.dynamicCard(theme: themeManager.currentTheme).opacity(0.9)
                                ]),
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 16)
                                .stroke(
                                    Color.dynamicAccent(theme: themeManager.currentTheme).opacity(0.3),
                                    lineWidth: 1
                                )
                        )
                )
                .shadow(
                    color: Color.black.opacity(themeManager.currentTheme == .dark ? 0.3 : 0.1),
                    radius: 8,
                    x: 0,
                    y: 4
                )
                .onTapGesture {
                    // Haptic feedback
                    let generator = UIImpactFeedbackGenerator(style: .medium)
                    generator.impactOccurred()

                    onTap()
                }

                // Texto de llamada a la acción
                HStack {
                    Text("Toca para compartir tu experiencia")
                        .font(.caption2)
                        .foregroundColor(.secondary)

                    Image(systemName: "arrow.right")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
                .padding(.top, 4)
                .padding(.horizontal, 16)
            }
            .padding(.horizontal)
            .transition(
                .asymmetric(
                    insertion: .move(edge: .top).combined(with: .opacity),
                    removal: .move(edge: .top).combined(with: .opacity)
                )
            )
            .onAppear {
                isAnimating = true
            }
        }
    }
}

// MARK: - Preview

#if DEBUG
struct PostClassSuggestionBanner_Previews: PreviewProvider {
    static var previews: some View {
        VStack {
            PostClassSuggestionBanner(
                attendedClass: AttendedClass.mockData[0],
                onTap: {
                    print("Banner tapped")
                },
                onDismiss: {
                    print("Banner dismissed")
                }
            )
            .environmentObject(ThemeManager())

            Spacer()
        }
        .background(Color.gray.opacity(0.1))
    }
}
#endif