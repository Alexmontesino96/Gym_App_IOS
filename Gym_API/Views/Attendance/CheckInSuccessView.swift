//
//  CheckInSuccessView.swift
//  Gym_API
//
//  Created by Claude Code on 12/1/25.
//

import SwiftUI

/// Vista de éxito después de un check-in exitoso
struct CheckInSuccessView: View {
    let response: AttendanceCheckInResponse
    let memberName: String?

    @EnvironmentObject var themeManager: ThemeManager
    @Environment(\.dismiss) var dismiss

    @State private var isAnimating = false

    init(response: AttendanceCheckInResponse, memberName: String? = nil) {
        self.response = response
        self.memberName = memberName
    }

    var body: some View {
        ZStack {
            Color.dynamicBackground(theme: themeManager.currentTheme)
                .ignoresSafeArea()

            VStack(spacing: 32) {
                Spacer()

                // Icono de éxito animado
                successIcon

                // Mensaje de éxito
                successMessage

                // Información de la sesión
                if let session = response.session {
                    sessionInfo(session: session)
                }

                Spacer()

                // Botón de cerrar
                closeButton
            }
            .padding(.horizontal, 24)
        }
        .onAppear {
            withAnimation(.spring(response: 0.6, dampingFraction: 0.7)) {
                isAnimating = true
            }
        }
    }

    // MARK: - Subviews

    private var successIcon: some View {
        ZStack {
            Circle()
                .fill(Color.green.opacity(0.2))
                .frame(width: 120, height: 120)
                .scaleEffect(isAnimating ? 1.0 : 0.5)

            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 80))
                .foregroundColor(.green)
                .scaleEffect(isAnimating ? 1.0 : 0.5)
        }
        .animation(.spring(response: 0.6, dampingFraction: 0.7), value: isAnimating)
    }

    private var successMessage: some View {
        VStack(spacing: 12) {
            Text("¡Check-in Exitoso!")
                .font(.system(size: 28, weight: .bold))
                .foregroundColor(Color.dynamicText(theme: themeManager.currentTheme))
                .opacity(isAnimating ? 1.0 : 0.0)

            if let memberName = memberName {
                Text(memberName)
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundColor(Color.dynamicText(theme: themeManager.currentTheme))
                    .opacity(isAnimating ? 1.0 : 0.0)

                Text("ha sido registrado")
                    .font(.system(size: 16))
                    .foregroundColor(Color.dynamicTextSecondary(theme: themeManager.currentTheme))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
                    .opacity(isAnimating ? 1.0 : 0.0)
            } else {
                Text(response.message)
                    .font(.system(size: 16))
                    .foregroundColor(Color.dynamicTextSecondary(theme: themeManager.currentTheme))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
                    .opacity(isAnimating ? 1.0 : 0.0)
            }
        }
        .animation(.easeIn(duration: 0.4).delay(0.2), value: isAnimating)
    }

    private func sessionInfo(session: AttendanceSession) -> some View {
        VStack(spacing: 16) {
            Divider()
                .padding(.horizontal, 40)

            VStack(spacing: 12) {
                // Hora de la clase
                HStack(spacing: 8) {
                    Image(systemName: "clock.fill")
                        .foregroundColor(Color.dynamicAccent(theme: themeManager.currentTheme))
                        .font(.system(size: 16))

                    Text(session.timeRange)
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundColor(Color.dynamicText(theme: themeManager.currentTheme))
                }

                // ID de sesión (para referencia)
                Text("Sesión #\(session.id)")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(Color.dynamicTextSecondary(theme: themeManager.currentTheme))
            }
            .padding(.vertical, 16)
            .padding(.horizontal, 20)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.dynamicCard(theme: themeManager.currentTheme))
                    .shadow(color: Color.black.opacity(0.05), radius: 8, x: 0, y: 2)
            )
        }
        .opacity(isAnimating ? 1.0 : 0.0)
        .animation(.easeIn(duration: 0.4).delay(0.4), value: isAnimating)
    }

    private var closeButton: some View {
        Button(action: { dismiss() }) {
            Text("Cerrar")
                .font(.system(size: 17, weight: .semibold))
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.dynamicAccent(theme: themeManager.currentTheme))
                )
        }
        .padding(.bottom, 32)
        .opacity(isAnimating ? 1.0 : 0.0)
        .animation(.easeIn(duration: 0.4).delay(0.6), value: isAnimating)
    }
}

// MARK: - Preview

#Preview {
    CheckInSuccessView(
        response: AttendanceCheckInResponse(
            success: true,
            message: "Check-in realizado correctamente",
            session: AttendanceSession(
                id: 456,
                startTime: Date(),
                endTime: Date().addingTimeInterval(3600),
                name: "Total Body Pump"
            )
        )
    )
    .environmentObject(ThemeManager())
}
