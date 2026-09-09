//
//  JoinWorkspaceView.swift
//  Gym_API
//
//  Canje de una invitación: cómo entra un cliente al espacio de su entrenador.
//
//  Antes de esto no había ninguna forma de unirse. El usuario nuevo aterrizaba en el listado
//  de gimnasios disponibles y su único botón era una línea sin implementar.
//
//  Dos pasos deliberados: primero se enseña a qué espacio va a entrar y quién le invita, y solo
//  después se confirma. Unirse da acceso al chat con esa persona, así que no debe pasar de un
//  solo toque a ciegas.
//

import SwiftUI

struct JoinWorkspaceView: View {
    @EnvironmentObject var themeManager: ThemeManager
    @StateObject private var invitationService = InvitationService.shared
    @Environment(\.dismiss) private var dismiss

    /// Código precargado, por ejemplo desde un enlace. Si viene, se resuelve solo.
    var prefilledToken: String?
    /// Se llama tras un canje correcto, para que quien presenta la pantalla reaccione.
    var onJoined: (() -> Void)?

    @State private var code: String = ""
    @State private var didResolvePrefill = false
    /// Tras canjear el código se enseña el intake (8.4) antes de cerrar esta pantalla: es la
    /// única vez que se puede pedir sin sentirse un formulario perdido en un menú.
    @State private var showIntake = false

    private var theme: ThemeManager.AppTheme { themeManager.currentTheme }

    private var trimmedCode: String {
        InvitationService.normalizeToken(code)
    }

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 24) {
                    intro

                    if let preview = invitationService.preview {
                        previewCard(preview)
                    } else {
                        codeEntry
                    }

                    if let error = invitationService.errorMessage {
                        errorRow(error)
                    }
                }
                .padding(20)
            }
            .background(Color.dynamicBackground(theme: theme).ignoresSafeArea())
            .navigationTitle("Join")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Close") { dismiss() }
                        .foregroundColor(Color.dynamicTextSecondary(theme: theme))
                }
            }
            .task {
                guard !didResolvePrefill, let prefilledToken, !prefilledToken.isEmpty else { return }
                didResolvePrefill = true
                code = prefilledToken
                await invitationService.loadPreview(token: prefilledToken)
            }
            .onDisappear { invitationService.preview = nil }
            .sheet(isPresented: $showIntake, onDismiss: {
                // El intake es opcional de rellenar aquí mismo: si lo cierra sin enviar, sigue
                // pudiendo hacerlo luego desde la tarjeta de CoachHomeView.
                onJoined?()
                dismiss()
            }) {
                IntakeFlowView()
                    .environmentObject(themeManager)
            }
        }
    }

    // MARK: - Partes

    private var intro: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("You have a code from your trainer")
                .font(.system(size: 22, weight: .bold))
                .tracking(-0.4)
                .foregroundColor(Color.dynamicText(theme: theme))
                .fixedSize(horizontal: false, vertical: true)

            Text("Paste it here to join their space. The full link they sent you works too.")
                .font(.system(size: 14))
                .foregroundColor(Color.dynamicTextSecondary(theme: theme))
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var codeEntry: some View {
        VStack(alignment: .leading, spacing: 14) {
            TextField("Code or link", text: $code, axis: .vertical)
                .lineLimit(1...3)
                .font(.system(size: 15, design: .monospaced))
                .foregroundColor(Color.dynamicText(theme: theme))
                .autocorrectionDisabled()
                .textInputAutocapitalization(.never)
                .padding(14)
                .background(Color.dynamicSurface(theme: theme))
                .clipShape(RoundedRectangle(cornerRadius: 14))
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(Color.dynamicBorder(theme: theme).opacity(0.15), lineWidth: 1)
                )

            Button {
                Task { await invitationService.loadPreview(token: code) }
            } label: {
                HStack(spacing: 8) {
                    if invitationService.isLoading {
                        ProgressView().tint(Color.accentInk)
                    }
                    Text(invitationService.isLoading ? "Checking…" : "Continue")
                        .font(.system(size: 16, weight: .semibold))
                }
                .foregroundColor(Color.accentInk)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 15)
                .background(Capsule().fill(Color.dynamicAccent(theme: theme)))
                .opacity(trimmedCode.count >= 8 ? 1 : 0.4)
            }
            .buttonStyle(.plain)
            .disabled(trimmedCode.count < 8 || invitationService.isLoading)
        }
    }

    private func previewCard(_ preview: InvitationPreview) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 14) {
                workspaceAvatar(preview)

                VStack(alignment: .leading, spacing: 4) {
                    Text(preview.gymName)
                        .font(.system(size: 18, weight: .bold))
                        .tracking(-0.3)
                        .foregroundColor(Color.dynamicText(theme: theme))
                        .lineLimit(2)

                    if let inviter = preview.inviterName, !inviter.isEmpty {
                        Text("Invited by \(inviter)")
                            .font(.system(size: 13))
                            .foregroundColor(Color.dynamicTextSecondary(theme: theme))
                    }
                }
                Spacer(minLength: 0)
            }

            Text(preview.joiningDescription)
                .font(.system(size: 14))
                .foregroundColor(Color.dynamicTextSecondary(theme: theme))
                .fixedSize(horizontal: false, vertical: true)

            Divider().background(Color.dynamicBorder(theme: theme).opacity(0.2))

            if preview.alreadyMember {
                statusRow(icon: "checkmark.circle.fill",
                          text: "You are already a member of this space.",
                          color: Color.successGreen)
                closeButton
            } else if !preview.isRedeemable {
                statusRow(icon: "clock.badge.xmark",
                          text: "This invitation has already been used or has expired. Ask your trainer for a new one.",
                          color: Color.warningYellow)
                tryAnotherButton
            } else {
                acceptButton
                tryAnotherButton
            }
        }
        .padding(18)
        .background(Color.dynamicSurface(theme: theme))
        .clipShape(RoundedRectangle(cornerRadius: 22))
        .overlay(
            RoundedRectangle(cornerRadius: 22)
                .stroke(Color.dynamicBorder(theme: theme).opacity(0.15), lineWidth: 1)
        )
    }

    private func workspaceAvatar(_ preview: InvitationPreview) -> some View {
        Group {
            if let logo = preview.gymLogoURL, !logo.isEmpty {
                OptimizedAsyncImage(
                    url: logo,
                    displaySize: CGSize(width: 52, height: 52),
                    placeholder: { AnyView(avatarFallback(preview)) },
                    errorView: { AnyView(avatarFallback(preview)) }
                )
                .frame(width: 52, height: 52)
                .clipShape(RoundedRectangle(cornerRadius: 16))
            } else {
                avatarFallback(preview)
            }
        }
    }

    private func avatarFallback(_ preview: InvitationPreview) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.dynamicAccent(theme: theme))
            Image(systemName: preview.isPersonalTrainer ? "person.fill" : "building.2.fill")
                .font(.system(size: 22, weight: .medium))
                .foregroundColor(Color.accentInk)
        }
        .frame(width: 52, height: 52)
    }

    private func statusRow(icon: String, text: String, color: Color) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(color)
            Text(text)
                .font(.system(size: 13))
                .foregroundColor(Color.dynamicTextSecondary(theme: theme))
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var acceptButton: some View {
        Button {
            Task {
                if await invitationService.accept(token: code) != nil {
                    HapticManager.shared.goalCompleted()
                    showIntake = true
                }
            }
        } label: {
            HStack(spacing: 8) {
                if invitationService.isAccepting {
                    ProgressView().tint(Color.accentInk)
                }
                Text(invitationService.isAccepting ? "Joining…" : "Join")
                    .font(.system(size: 16, weight: .semibold))
            }
            .foregroundColor(Color.accentInk)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 15)
            .background(Capsule().fill(Color.dynamicAccent(theme: theme)))
        }
        .buttonStyle(.plain)
        .disabled(invitationService.isAccepting)
    }

    private var tryAnotherButton: some View {
        Button {
            invitationService.preview = nil
            invitationService.errorMessage = nil
            code = ""
        } label: {
            Text("Use another code")
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(Color.dynamicAccent(theme: theme))
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(.plain)
    }

    private var closeButton: some View {
        Button { dismiss() } label: {
            Text("Continue")
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(Color.accentInk)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 15)
                .background(Capsule().fill(Color.dynamicAccent(theme: theme)))
        }
        .buttonStyle(.plain)
    }

    private func errorRow(_ message: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: "exclamationmark.circle")
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(Color.errorRed)
            Text(message)
                .font(.system(size: 13))
                .foregroundColor(Color.errorRed)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}
