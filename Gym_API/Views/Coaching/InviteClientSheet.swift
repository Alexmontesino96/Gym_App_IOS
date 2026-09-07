//
//  InviteClientSheet.swift
//  Gym_API
//
//  El entrenador genera un código y lo comparte con su cliente.
//
//  Es la otra mitad del alta: el cliente lo canjea en JoinWorkspaceView. No hay directorio ni
//  búsqueda porque la relación ya existe fuera del producto; lo único que hace falta es que
//  unirse cueste un toque.
//

import SwiftUI

struct InviteClientSheet: View {
    @EnvironmentObject var themeManager: ThemeManager
    @EnvironmentObject var gymService: GymService
    @StateObject private var invitationService = InvitationService.shared
    @Environment(\.dismiss) private var dismiss

    @State private var email: String = ""
    @State private var created: WorkspaceInvitation?
    @State private var copied = false

    private var theme: ThemeManager.AppTheme { themeManager.currentTheme }

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 22) {
                    if let created {
                        resultCard(created)
                    } else {
                        form
                    }

                    if let error = invitationService.errorMessage {
                        Text(error)
                            .font(.system(size: 13))
                            .foregroundColor(Color.errorRed)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .padding(20)
            }
            .background(Color.dynamicBackground(theme: theme).ignoresSafeArea())
            .navigationTitle("Invite a client")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(created == nil ? "Cancel" : "Done") { dismiss() }
                        .foregroundColor(Color.dynamicTextSecondary(theme: theme))
                }
            }
            .onAppear { invitationService.errorMessage = nil }
        }
    }

    // MARK: - Formulario

    private var form: some View {
        VStack(alignment: .leading, spacing: 18) {
            VStack(alignment: .leading, spacing: 8) {
                Text("Create a code for your client")
                    .font(.system(size: 20, weight: .bold))
                    .tracking(-0.3)
                    .foregroundColor(Color.dynamicText(theme: theme))
                Text("Send it wherever you already talk. It expires in 14 days and works once.")
                    .font(.system(size: 14))
                    .foregroundColor(Color.dynamicTextSecondary(theme: theme))
                    .fixedSize(horizontal: false, vertical: true)
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("EMAIL (OPTIONAL)")
                    .font(.system(size: 11, weight: .semibold))
                    .tracking(0.8)
                    .foregroundColor(Color.dynamicTextTertiary(theme: theme))

                TextField("client@email.com", text: $email)
                    .font(.system(size: 15))
                    .foregroundColor(Color.dynamicText(theme: theme))
                    .keyboardType(.emailAddress)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)
                    .padding(14)
                    .background(Color.dynamicSurface(theme: theme))
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                    .overlay(
                        RoundedRectangle(cornerRadius: 14)
                            .stroke(Color.dynamicBorder(theme: theme).opacity(0.15), lineWidth: 1)
                    )

                Text("If you fill it in, only that address can use the code.")
                    .font(.system(size: 12))
                    .foregroundColor(Color.dynamicTextTertiary(theme: theme))
            }

            Button {
                Task {
                    let trimmed = email.trimmingCharacters(in: .whitespacesAndNewlines)
                    created = await invitationService.createInvitation(
                        email: trimmed.isEmpty ? nil : trimmed
                    )
                    if created != nil { HapticManager.shared.buttonTap() }
                }
            } label: {
                Text("Create code")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(ThemeManager.accentInkForCurrentAccent(theme: themeManager.currentTheme))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 15)
                    .background(Capsule().fill(Color.dynamicAccent(theme: theme)))
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: - Resultado

    private func resultCard(_ invitation: WorkspaceInvitation) -> some View {
        VStack(alignment: .leading, spacing: 18) {
            VStack(alignment: .leading, spacing: 8) {
                Text("Code ready")
                    .font(.system(size: 20, weight: .bold))
                    .tracking(-0.3)
                    .foregroundColor(Color.dynamicText(theme: theme))
                Text("Share it with your client. Redeeming it puts them in your space.")
                    .font(.system(size: 14))
                    .foregroundColor(Color.dynamicTextSecondary(theme: theme))
                    .fixedSize(horizontal: false, vertical: true)
            }

            Text(invitation.token)
                .font(.system(size: 16, weight: .semibold, design: .monospaced))
                .foregroundColor(Color.dynamicText(theme: theme))
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(16)
                .background(Color.dynamicSurface2(theme: theme))
                .clipShape(RoundedRectangle(cornerRadius: 14))

            HStack(spacing: 10) {
                Button {
                    UIPasteboard.general.string = invitation.token
                    copied = true
                    HapticManager.shared.buttonTap()
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: copied ? "checkmark" : "doc.on.doc")
                            .font(.system(size: 13, weight: .semibold))
                        Text(copied ? "Copied" : "Copy")
                            .font(.system(size: 14, weight: .semibold))
                    }
                    .foregroundColor(Color.dynamicText(theme: theme))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 13)
                    .background(Color.dynamicSurface(theme: theme))
                    .clipShape(Capsule())
                    .overlay(
                        Capsule().stroke(Color.dynamicBorder(theme: theme).opacity(0.2), lineWidth: 1)
                    )
                }
                .buttonStyle(.plain)

                ShareLink(item: invitation.shareText(gymName: gymService.currentGym?.name)) {
                    HStack(spacing: 6) {
                        Image(systemName: "square.and.arrow.up")
                            .font(.system(size: 13, weight: .semibold))
                        Text("Share")
                            .font(.system(size: 14, weight: .semibold))
                    }
                    .foregroundColor(ThemeManager.accentInkForCurrentAccent(theme: themeManager.currentTheme))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 13)
                    .background(Capsule().fill(Color.dynamicAccent(theme: theme)))
                }
                .buttonStyle(.plain)
            }

            if let email = invitation.email, !email.isEmpty {
                Text("Only \(email) can use it.")
                    .font(.system(size: 12))
                    .foregroundColor(Color.dynamicTextTertiary(theme: theme))
            }

            Button {
                created = nil
                self.email = ""
                copied = false
            } label: {
                Text("Create another")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(Color.dynamicAccent(theme: theme))
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.plain)
        }
        .padding(18)
        .background(Color.dynamicSurface(theme: theme))
        .clipShape(RoundedRectangle(cornerRadius: 22))
        .overlay(
            RoundedRectangle(cornerRadius: 22)
                .stroke(Color.dynamicBorder(theme: theme).opacity(0.15), lineWidth: 1)
        )
    }
}
