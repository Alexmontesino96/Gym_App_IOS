//
//  MessageLoadingCoordinator.swift
//  Gym_API
//
//  Created by Claude Code
//  Copyright © 2025 Gym API. All rights reserved.
//

import Foundation

// MARK: - Message Loading Coordinator
/// Actor que coordina la carga de mensajes para prevenir race conditions
/// cuando el usuario cambia rápidamente entre conversaciones
actor MessageLoadingCoordinator {

    // MARK: - Properties

    /// Task actual de carga de mensajes
    private var currentTask: Task<[ChatMessage], Error>?

    /// ID de la conversación que se está cargando actualmente
    private var currentConversationId: String?

    // MARK: - Public Methods

    /// Carga mensajes para una conversación específica
    /// - Parameters:
    ///   - conversationId: ID de la conversación
    ///   - fetcher: Closure que realiza el fetch real de mensajes
    /// - Returns: Array de mensajes cargados
    /// - Throws: Error si el fetch falla
    ///
    /// **Garantías:**
    /// - Cancela automáticamente el task anterior si la conversación cambió
    /// - Deduplica requests para la misma conversación
    /// - Thread-safe mediante actor isolation
    func loadMessages(
        conversationId: String,
        fetcher: @escaping () async throws -> [ChatMessage]
    ) async throws -> [ChatMessage] {

        // 1. Cancelar task anterior si conversación cambió
        if let currentId = currentConversationId, currentId != conversationId {
            print("🔄 MessageLoadingCoordinator: Conversación cambió de '\(currentId)' a '\(conversationId)', cancelando task anterior")
            currentTask?.cancel()
            currentTask = nil
        }

        // 2. Actualizar conversación actual
        currentConversationId = conversationId

        // 3. Evitar fetches duplicados para misma conversación
        if let existing = currentTask, !existing.isCancelled {
            print("⏳ MessageLoadingCoordinator: Reutilizando task existente para '\(conversationId)'")
            return try await existing.value
        }

        // 4. Crear nuevo task de carga
        print("🚀 MessageLoadingCoordinator: Iniciando carga de mensajes para '\(conversationId)'")
        let task = Task {
            try await fetcher()
        }

        currentTask = task

        do {
            let messages = try await task.value
            print("✅ MessageLoadingCoordinator: Cargados \(messages.count) mensajes para '\(conversationId)'")
            return messages
        } catch {
            print("❌ MessageLoadingCoordinator: Error cargando mensajes para '\(conversationId)': \(error.localizedDescription)")
            throw error
        }
    }

    /// Cancela cualquier carga en progreso
    func cancel() {
        if let conversationId = currentConversationId {
            print("🛑 MessageLoadingCoordinator: Cancelando carga para '\(conversationId)'")
        }
        currentTask?.cancel()
        currentTask = nil
        currentConversationId = nil
    }

    /// Verifica si hay una carga en progreso
    var isLoading: Bool {
        currentTask != nil && !(currentTask?.isCancelled ?? true)
    }

    /// ID de la conversación actualmente en carga
    var activeConversationId: String? {
        currentConversationId
    }
}

// MARK: - Debug Extension
#if DEBUG
extension MessageLoadingCoordinator {
    /// Estado actual del coordinator (solo para debugging)
    func debugStatus() -> String {
        if let taskStatus = currentTask?.isCancelled {
            return "Conversation: \(currentConversationId ?? "none"), Task: \(taskStatus ? "cancelled" : "active")"
        } else {
            return "Conversation: \(currentConversationId ?? "none"), Task: none"
        }
    }
}
#endif
