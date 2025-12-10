//
//  ClassSelectionSheet.swift
//  Gym_API
//
//  Created by Claude Code on 12/1/25.
//

import SwiftUI

/// Sheet para seleccionar una clase cuando hay múltiples clases activas
struct ClassSelectionSheet: View {
    let qrCode: String?
    let sessions: [SessionWithClass]
    let onSessionSelected: (SessionWithClass) -> Void
    let onCancel: (() -> Void)?

    @EnvironmentObject var themeManager: ThemeManager
    @Environment(\.dismiss) var dismiss

    init(qrCode: String? = nil, sessions: [SessionWithClass], onSessionSelected: @escaping (SessionWithClass) -> Void, onCancel: (() -> Void)? = nil) {
        self.qrCode = qrCode
        self.sessions = sessions
        self.onSessionSelected = onSessionSelected
        self.onCancel = onCancel
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color.dynamicBackground(theme: themeManager.currentTheme)
                    .ignoresSafeArea()

                VStack(spacing: 20) {
                    // Header
                    headerView
                        .padding(.top, 20)

                    // Lista de clases
                    ScrollView {
                        VStack(spacing: 12) {
                            ForEach(sessions) { session in
                                ClassSelectionCard(
                                    session: session,
                                    onSelect: {
                                        onSessionSelected(session)
                                        dismiss()
                                    }
                                )
                            }
                        }
                        .padding(.horizontal, 20)
                    }
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                // Mostrar botón X si hay callback de cancelar
                if let onCancel = onCancel {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button(action: {
                            onCancel()
                            dismiss()
                        }) {
                            Image(systemName: "xmark.circle.fill")
                                .font(.system(size: 24))
                                .foregroundColor(Color.dynamicTextSecondary(theme: themeManager.currentTheme))
                        }
                    }
                }
            }
        }
    }

    // MARK: - Subviews

    private var headerView: some View {
        VStack(spacing: 8) {
            Image(systemName: "calendar.badge.clock")
                .font(.system(size: 50))
                .foregroundColor(Color.dynamicAccent(theme: themeManager.currentTheme))

            Text(qrCode == nil ? "Selecciona la clase" : "Múltiples Clases Disponibles")
                .font(.system(size: 22, weight: .bold))
                .foregroundColor(Color.dynamicText(theme: themeManager.currentTheme))

            Text(qrCode == nil ? "Elige la clase para hacer check-in" : "Selecciona la clase a la que asistirá")
                .font(.system(size: 15))
                .foregroundColor(Color.dynamicTextSecondary(theme: themeManager.currentTheme))
                .multilineTextAlignment(.center)

            if qrCode == nil {
                // Modo pre-scanner: Nota adicional
                Text("Después podrás escanear el código QR")
                    .font(.system(size: 13))
                    .foregroundColor(Color.dynamicTextSecondary(theme: themeManager.currentTheme).opacity(0.8))
                    .padding(.top, 4)
            }

            // Info de sesiones disponibles
            Text("\(sessions.count) \(sessions.count == 1 ? "clase" : "clases") dentro de la ventana de check-in")
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(Color.dynamicAccent(theme: themeManager.currentTheme))
                .padding(.horizontal, 16)
                .padding(.vertical, 6)
                .background(
                    Capsule()
                        .fill(Color.dynamicAccent(theme: themeManager.currentTheme).opacity(0.1))
                )
                .padding(.top, 8)
        }
    }
}

// MARK: - Class Selection Card

struct ClassSelectionCard: View {
    let session: SessionWithClass
    let onSelect: () -> Void

    @EnvironmentObject var themeManager: ThemeManager

    var body: some View {
        Button(action: onSelect) {
            HStack(spacing: 16) {
                // Icono de clase
                classIcon

                // Info de clase
                classInfo

                Spacer()

                // Flecha
                Image(systemName: "chevron.right")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(Color.dynamicAccent(theme: themeManager.currentTheme))
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color.dynamicCard(theme: themeManager.currentTheme))
                    .shadow(color: Color.black.opacity(0.05), radius: 8, x: 0, y: 2)
            )
        }
        .buttonStyle(ScaleButtonStyle())
    }

    // MARK: - Subviews

    private var classIcon: some View {
        ZStack {
            Circle()
                .fill((Color(hex: session.categoryColor) ?? Color.dynamicAccent(theme: themeManager.currentTheme)).opacity(0.2))
                .frame(width: 60, height: 60)

            Image(systemName: "figure.run")
                .font(.system(size: 24))
                .foregroundColor(Color(hex: session.categoryColor) ?? Color.dynamicAccent(theme: themeManager.currentTheme))
        }
    }

    private var classInfo: some View {
        VStack(alignment: .leading, spacing: 6) {
            // Nombre de la clase
            Text(session.classInfo.name)
                .font(.system(size: 17, weight: .semibold))
                .foregroundColor(Color.dynamicText(theme: themeManager.currentTheme))
                .lineLimit(1)

            // Hora y ubicación
            HStack(spacing: 12) {
                Label(session.formattedTime, systemImage: "clock.fill")
                    .font(.system(size: 14))
                    .foregroundColor(Color.dynamicTextSecondary(theme: themeManager.currentTheme))

                if let room = session.session.room {
                    Label(room, systemImage: "location.fill")
                        .font(.system(size: 14))
                        .foregroundColor(Color.dynamicTextSecondary(theme: themeManager.currentTheme))
                }
            }

            // Tiempo hasta la clase
            HStack(spacing: 4) {
                Image(systemName: "timer")
                    .font(.system(size: 11))
                Text(session.timeUntilClass)
                    .font(.system(size: 12, weight: .medium))
            }
            .foregroundColor(Color.dynamicAccent(theme: themeManager.currentTheme))
        }
    }
}

// MARK: - Button Style
// ScaleButtonStyle moved to Views/Components/ButtonStyles.swift

// MARK: - Preview

#Preview {
    ClassSelectionSheet(
        qrCode: "U123_test",
        sessions: [],
        onSessionSelected: { _ in }
    )
    .environmentObject(ThemeManager())
}
