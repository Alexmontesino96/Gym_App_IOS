//
//  ChatRoomRow.swift
//  Gym_API
//
//  Componente reutilizable para mostrar un chat con opciones de gestión
//  Incluye: Hide, Delete For Me, Leave Group, Delete Group
//

import SwiftUI

// MARK: - Chat Room Row
struct ChatRoomRow: View {
    @EnvironmentObject var container: ServiceContainer
    @EnvironmentObject var themeManager: ThemeManager

    let room: ChatRoom
    let onRoomRemoved: () -> Void

    @State private var showingHideConfirmation = false
    @State private var showingDeleteConfirmation = false
    @State private var showingLeaveConfirmation = false
    @State private var showingDeleteGroupConfirmation = false
    @State private var errorMessage = ""
    @State private var showingError = false
    @State private var isProcessing = false

    var body: some View {
        HStack(spacing: 12) {
            // Avatar
            Circle()
                .fill(Color.dynamicSurface(theme: themeManager.currentTheme))
                .frame(width: 50, height: 50)
                .overlay(
                    Text(room.displayInitials)
                        .font(.headline)
                        .foregroundColor(.dynamicText(theme: themeManager.currentTheme))
                )

            VStack(alignment: .leading, spacing: 4) {
                // Nombre del chat
                Text(room.displayName)
                    .font(.headline)
                    .foregroundColor(.dynamicText(theme: themeManager.currentTheme))

                // Último mensaje
                if let lastMessage = room.lastMessageText {
                    Text(lastMessage)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                } else {
                    Text("New chat")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .italic()
                }
            }

            Spacer()

            // Fecha
            if let lastMessageDate = room.lastMessageAt {
                Text(formatDate(lastMessageDate))
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 8)
        .opacity(isProcessing ? 0.5 : 1.0)
        .contextMenu {
            contextMenuContent
        }
        // Confirmaciones
        .alert("Ocultar Chat", isPresented: $showingHideConfirmation) {
            Button("Cancelar", role: .cancel) { }
            Button("Ocultar") {
                Task { await hideChat() }
            }
        } message: {
            Text("Este chat se ocultará de tu lista. Puedes mostrarlo nuevamente desde la sección de chats ocultos.")
        }
        .alert("Eliminar Conversación", isPresented: $showingDeleteConfirmation) {
            Button("Cancelar", role: .cancel) { }
            Button("Eliminar Para Mí", role: .destructive) {
                Task { await deleteConversation() }
            }
        } message: {
            Text("¿Eliminar conversación con \(room.displayName)?\n\nSe eliminarán TODOS los mensajes solo para ti.\n\(room.displayName) mantendrá su historial completo.\n\nEsta acción NO se puede deshacer.")
        }
        .alert("Salir del Grupo", isPresented: $showingLeaveConfirmation) {
            Button("Cancelar", role: .cancel) { }
            Button("Salir", role: .destructive) {
                Task { await leaveGroup() }
            }
        } message: {
            Text("¿Estás seguro que quieres salir de '\(room.displayName)'?")
        }
        .alert("Eliminar Grupo", isPresented: $showingDeleteGroupConfirmation) {
            Button("Cancelar", role: .cancel) { }
            Button("Eliminar Permanentemente", role: .destructive) {
                Task { await deleteGroup() }
            }
        } message: {
            Text("Esta acción eliminará el grupo '\(room.displayName)' permanentemente.\n\nTodos los mensajes se borrarán para todos los miembros.\n\nEsta acción no se puede deshacer.")
        }
        .alert("Error", isPresented: $showingError) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(errorMessage)
        }
    }

    // MARK: - Context Menu

    @ViewBuilder
    private var contextMenuContent: some View {
        // OCULTAR (solo chats 1-to-1)
        if room.isDirect {
            Button {
                showingHideConfirmation = true
            } label: {
                Label("Ocultar", systemImage: "archivebox")
            }
        }

        // Divider entre opciones suaves y destructivas
        if room.isDirect {
            Divider()
        }

        // ELIMINAR CONVERSACIÓN (Delete For Me - solo chats 1-to-1)
        if room.isDirect {
            Button(role: .destructive) {
                showingDeleteConfirmation = true
            } label: {
                Label("Eliminar Conversación", systemImage: "trash")
            }
        }

        // SALIR DE GRUPO (solo grupos, no eventos)
        if !room.isDirect && room.eventId == nil {
            Button(role: .destructive) {
                showingLeaveConfirmation = true
            } label: {
                Label("Salir del Grupo", systemImage: "rectangle.portrait.and.arrow.right")
            }
        }

        // ELIMINAR GRUPO (solo admin - placeholder)
        // TODO: Verificar rol de usuario antes de mostrar
        // if !room.isDirect && room.eventId == nil && userIsAdmin {
        //     Divider()
        //     Button(role: .destructive) {
        //         showingDeleteGroupConfirmation = true
        //     } label: {
        //         Label("Eliminar Grupo", systemImage: "trash.fill")
        //     }
        // }
    }

    // MARK: - Actions

    private func hideChat() async {
        isProcessing = true
        defer { isProcessing = false }

        do {
            let response = try await container.chatManagementService.hideChat(room: room)
            print("✅ \(response.message)")

            // Feedback háptico
            await MainActor.run {
                let generator = UINotificationFeedbackGenerator()
                generator.notificationOccurred(.success)
            }

            // Remover de la lista con animación
            onRoomRemoved()

        } catch let error as ChatManagementError {
            errorMessage = error.localizedDescription
            showingError = true
        } catch {
            errorMessage = "Error al ocultar el chat: \(error.localizedDescription)"
            showingError = true
        }
    }

    private func deleteConversation() async {
        isProcessing = true
        defer { isProcessing = false }

        do {
            let response = try await container.chatManagementService.deleteConversation(room: room)
            print("✅ Eliminados \(response.messagesDeleted) mensajes")
            print("   \(response.message)")

            // Feedback háptico
            await MainActor.run {
                let generator = UINotificationFeedbackGenerator()
                generator.notificationOccurred(.success)
            }

            // Remover de la lista con animación
            onRoomRemoved()

        } catch let error as ChatManagementError {
            errorMessage = error.localizedDescription
            showingError = true
        } catch {
            errorMessage = "Error al eliminar conversación: \(error.localizedDescription)"
            showingError = true
        }
    }

    private func leaveGroup() async {
        isProcessing = true
        defer { isProcessing = false }

        do {
            let response = try await container.chatManagementService.leaveGroup(room: room, autoHide: true)

            if response.groupDeleted {
                print("✅ Grupo eliminado (último miembro)")
                errorMessage = "Has salido del grupo. El grupo ha sido eliminado porque no quedan miembros."
            } else {
                print("✅ Saliste del grupo, quedan \(response.remainingMembers) miembros")
                errorMessage = "Has salido del grupo '\(room.displayName)'. Quedan \(response.remainingMembers) miembros."
            }

            // Feedback háptico
            await MainActor.run {
                let generator = UINotificationFeedbackGenerator()
                generator.notificationOccurred(.success)
            }

            // Mostrar mensaje de éxito
            showingError = true

            // Remover de la lista con animación
            onRoomRemoved()

        } catch let error as ChatManagementError {
            errorMessage = error.localizedDescription
            showingError = true
        } catch {
            errorMessage = "Error al salir del grupo: \(error.localizedDescription)"
            showingError = true
        }
    }

    private func deleteGroup() async {
        isProcessing = true
        defer { isProcessing = false }

        do {
            let response = try await container.chatManagementService.deleteGroup(room: room, hardDelete: true)
            print("✅ \(response.message)")

            // Feedback háptico
            await MainActor.run {
                let generator = UINotificationFeedbackGenerator()
                generator.notificationOccurred(.success)
            }

            // Remover de la lista con animación
            onRoomRemoved()

        } catch let error as ChatManagementError {
            errorMessage = error.localizedDescription
            showingError = true
        } catch {
            errorMessage = "Error al eliminar grupo: \(error.localizedDescription)"
            showingError = true
        }
    }

    // MARK: - Helpers

    private func formatDate(_ date: Date) -> String {
        let calendar = Calendar.current
        let now = Date()

        if calendar.isDateInToday(date) {
            let formatter = DateFormatter()
            formatter.timeStyle = .short
            return formatter.string(from: date)
        } else if calendar.isDateInYesterday(date) {
            return "Yesterday"
        } else if calendar.dateInterval(of: .weekOfYear, for: now)?.contains(date) == true {
            let formatter = DateFormatter()
            formatter.dateFormat = "EEEE"
            return formatter.string(from: date)
        } else {
            let formatter = DateFormatter()
            formatter.dateStyle = .short
            return formatter.string(from: date)
        }
    }
}

// MARK: - Preview
#if DEBUG
struct ChatRoomRow_Previews: PreviewProvider {
    static var previews: some View {
        // Preview example with mock data
        List {
            Text("ChatRoomRow requires actual ChatRoom data")
                .foregroundColor(.secondary)
        }
        .environmentObject(ServiceContainer.shared)
        .environmentObject(ThemeManager())
    }
}
#endif
