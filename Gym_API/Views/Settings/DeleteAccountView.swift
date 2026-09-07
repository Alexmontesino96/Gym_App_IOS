//
//  DeleteAccountView.swift
//  Gym_API
//
//  Borrar la cuenta desde dentro de la app.
//
//  Es un requisito de Apple para publicar, pero además es lo correcto: la app pide fecha de
//  nacimiento, peso y conversaciones privadas, y quien las da tiene que poder retirarlas.
//
//  Dos decisiones sobre la pantalla:
//    - Se enumera qué pasa ANTES de pedir la confirmación. Una alerta de "¿seguro?" no dice
//      nada; lo que hace falta saber es que el espacio se archiva y qué se conserva.
//    - Se pide escribir una palabra en vez de un botón rojo. La acción no tiene vuelta atrás
//      y un toque accidental no debe bastar.
//

import SwiftUI

struct DeleteAccountView: View {
    @EnvironmentObject var themeManager: ThemeManager
    @EnvironmentObject var authService: AuthServiceDirect
    @StateObject private var accountService = AccountService.shared
    @Environment(\.dismiss) private var dismiss

    /// True cuando quien mira dirige un espacio de trabajo: se le avisa de que se archiva.
    var ownsWorkspace: Bool = false

    @State private var typedConfirmation = ""

    private let confirmationWord = "DELETE"

    private var theme: ThemeManager.AppTheme { themeManager.currentTheme }

    private var canDelete: Bool {
        typedConfirmation.trimmingCharacters(in: .whitespacesAndNewlines).uppercased() == confirmationWord
            && !accountService.isDeleting
    }

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 24) {
                    intro
                    consequences
                    confirmationField

                    if let error = accountService.errorMessage {
                        errorRow(error)
                    }

                    deleteButton
                }
                .padding(20)
            }
            .background(Color.dynamicBackground(theme: theme).ignoresSafeArea())
            .navigationTitle("Delete account")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }
                        .foregroundColor(Color.dynamicTextSecondary(theme: theme))
                }
            }
            .onAppear { accountService.errorMessage = nil }
            .interactiveDismissDisabled(accountService.isDeleting)
        }
    }

    // MARK: - Partes

    private var intro: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("This cannot be undone")
                .font(.system(size: 22, weight: .bold))
                .tracking(-0.4)
                .foregroundColor(Color.dynamicText(theme: theme))

            Text("Deleting your account signs you out everywhere and you will not be able to sign back in with it.")
                .font(.system(size: 14))
                .foregroundColor(Color.dynamicTextSecondary(theme: theme))
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var consequences: some View {
        VStack(alignment: .leading, spacing: 14) {
            row(
                icon: "trash",
                title: "Deleted",
                detail: "Your sign-in, your profile details and your weight and goal history."
            )

            if ownsWorkspace {
                row(
                    icon: "archivebox",
                    title: "Archived",
                    detail: "Your workspace. Your clients keep access to their own history, and nobody new can join."
                )
            }

            row(
                icon: "bubble.left.and.text.bubble.right",
                title: "Kept",
                detail: "Messages you already sent and sessions already logged. They belong to the other person's records too."
            )
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.dynamicSurface(theme: theme))
        .clipShape(RoundedRectangle(cornerRadius: 22))
        .overlay(
            RoundedRectangle(cornerRadius: 22)
                .stroke(Color.dynamicBorder(theme: theme).opacity(0.15), lineWidth: 1)
        )
    }

    private func row(icon: String, title: String, detail: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 15, weight: .medium))
                .foregroundColor(Color.dynamicTextSecondary(theme: theme))
                .frame(width: 22)

            VStack(alignment: .leading, spacing: 3) {
                Text(title.uppercased())
                    .font(.system(size: 10, weight: .bold))
                    .tracking(0.8)
                    .foregroundColor(Color.dynamicTextTertiary(theme: theme))
                Text(detail)
                    .font(.system(size: 13))
                    .foregroundColor(Color.dynamicText(theme: theme))
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private var confirmationField: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("TYPE \(confirmationWord) TO CONFIRM")
                .font(.system(size: 11, weight: .semibold))
                .tracking(0.8)
                .foregroundColor(Color.dynamicTextTertiary(theme: theme))

            TextField(confirmationWord, text: $typedConfirmation)
                .font(.system(size: 16, weight: .semibold, design: .monospaced))
                .foregroundColor(Color.dynamicText(theme: theme))
                .autocorrectionDisabled()
                .textInputAutocapitalization(.characters)
                .padding(14)
                .background(Color.dynamicSurface(theme: theme))
                .clipShape(RoundedRectangle(cornerRadius: 14))
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(Color.dynamicBorder(theme: theme).opacity(0.15), lineWidth: 1)
                )
                .disabled(accountService.isDeleting)
        }
    }

    private var deleteButton: some View {
        Button(action: delete) {
            HStack(spacing: 8) {
                if accountService.isDeleting {
                    ProgressView().tint(.white)
                }
                Text(accountService.isDeleting ? "Deleting…" : "Delete my account")
                    .font(.system(size: 16, weight: .semibold))
            }
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 15)
            .background(Capsule().fill(Color.errorRed))
            .opacity(canDelete ? 1 : 0.4)
        }
        .buttonStyle(.plain)
        .disabled(!canDelete)
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

    // MARK: - Acción

    private func delete() {
        Task {
            guard await accountService.deleteAccount() != nil else { return }
            HapticManager.shared.play(.warning)
            // La cuenta de Auth0 ya no existe: quedarse dentro con un token vivo solo lleva
            // a una pantalla que fallará en la siguiente petición.
            await authService.logout()
            dismiss()
        }
    }
}
