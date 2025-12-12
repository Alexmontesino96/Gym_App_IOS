//
//  MessageWindow.swift
//  Gym_API
//
//  Created by Claude Code
//  Copyright © 2025 Gym API. All rights reserved.
//

import Foundation

// MARK: - Message Window Actor
/// Actor que implementa windowing para reducir uso de memoria
/// Solo mantiene ~50 mensajes visibles en memoria a la vez
actor MessageWindow {

    // MARK: - Configuration

    /// Tamaño de la ventana visible (mensajes en memoria)
    private let windowSize: Int = 50

    /// Buffer para smooth scrolling (cargar antes de que sea visible)
    private let bufferSize: Int = 10

    // MARK: - Storage

    /// IDs de todos los mensajes de la conversación (lightweight)
    private var allMessageIds: [String] = []

    /// Diccionario de mensajes actualmente en memoria
    private var visibleMessages: [String: ChatMessage] = [:]

    /// Índices de la ventana actual
    private var currentWindowStart: Int = 0
    private var currentWindowEnd: Int = 50

    // MARK: - Public API

    /// Inicializa la ventana con una lista completa de IDs
    /// - Parameter messageIds: Array de IDs de mensajes ordenados por timestamp
    func initialize(with messageIds: [String]) {
        self.allMessageIds = messageIds
        self.currentWindowStart = max(0, messageIds.count - windowSize)
        self.currentWindowEnd = messageIds.count

        print("🪟 MessageWindow inicializado: \(allMessageIds.count) mensajes total, ventana: [\(currentWindowStart)..\(currentWindowEnd)]")
    }

    /// Actualiza la ventana basado en posición de scroll
    /// - Parameters:
    ///   - scrollPosition: Índice del mensaje actualmente visible en pantalla
    ///   - direction: Dirección del scroll (up = hacia mensajes antiguos, down = hacia nuevos)
    func updateWindow(scrollPosition: Int, direction: ScrollDirection) {
        guard !allMessageIds.isEmpty else { return }

        let totalCount = allMessageIds.count

        // Calcular nueva ventana centrada en scrollPosition con buffer
        let newStart: Int
        let newEnd: Int

        switch direction {
        case .up:
            // Scrolling hacia arriba (mensajes antiguos)
            newStart = max(0, scrollPosition - windowSize + bufferSize)
            newEnd = min(totalCount, scrollPosition + bufferSize)

        case .down:
            // Scrolling hacia abajo (mensajes nuevos)
            newStart = max(0, scrollPosition - bufferSize)
            newEnd = min(totalCount, scrollPosition + windowSize - bufferSize)

        case .none:
            // Sin movimiento, mantener ventana actual
            return
        }

        // Solo actualizar si hay cambio significativo
        let hasSignificantChange = abs(newStart - currentWindowStart) > bufferSize ||
                                  abs(newEnd - currentWindowEnd) > bufferSize

        guard hasSignificantChange else { return }

        currentWindowStart = newStart
        currentWindowEnd = newEnd

        print("🪟 Ventana actualizada: [\(currentWindowStart)..\(currentWindowEnd)] (scroll: \(scrollPosition), dir: \(direction))")
    }

    /// Retorna los mensajes actualmente en la ventana visible
    /// - Returns: Array de ChatMessage en la ventana
    func getVisibleMessages() -> [ChatMessage] {
        guard !allMessageIds.isEmpty else { return [] }

        let safeStart = max(0, min(currentWindowStart, allMessageIds.count))
        let safeEnd = max(safeStart, min(currentWindowEnd, allMessageIds.count))

        guard safeStart < safeEnd else { return [] }

        let visibleIds = Array(allMessageIds[safeStart..<safeEnd])
        let messages = visibleIds.compactMap { visibleMessages[$0] }

        return messages
    }

    /// Carga un mensaje en la ventana si aún no está cargado
    /// - Parameters:
    ///   - id: ID del mensaje a cargar
    ///   - fetcher: Closure asíncrono que retorna el mensaje
    func loadMessage(id: String, fetcher: () async -> ChatMessage?) async {
        // Ya está cargado
        guard visibleMessages[id] == nil else { return }

        // No está en la ventana actual, no cargar
        let isInWindow = allMessageIds.indices.contains(where: { index in
            allMessageIds[index] == id &&
            index >= currentWindowStart &&
            index < currentWindowEnd
        })

        guard isInWindow else {
            print("⏭️ Mensaje \(id) fuera de ventana, skip")
            return
        }

        if let message = await fetcher() {
            visibleMessages[id] = message
            print("📥 Mensaje cargado en ventana: \(id)")
        }
    }

    /// Carga múltiples mensajes de una vez
    /// - Parameters:
    ///   - messages: Array de ChatMessage a cargar
    func loadMessages(_ messages: [ChatMessage]) {
        for message in messages {
            // Solo cargar si está en la ventana actual
            guard let index = allMessageIds.firstIndex(of: message.id),
                  index >= currentWindowStart && index < currentWindowEnd else {
                continue
            }

            visibleMessages[message.id] = message
        }

        print("📥 Cargados \(messages.count) mensajes en ventana")
    }

    /// Agrega un nuevo mensaje (típicamente mensaje recién enviado)
    /// - Parameter message: ChatMessage a agregar
    func appendMessage(_ message: ChatMessage) {
        // Agregar ID al final
        allMessageIds.append(message.id)

        // Si la ventana está al final, expandir para incluir nuevo mensaje
        if currentWindowEnd == allMessageIds.count - 1 {
            currentWindowEnd = allMessageIds.count
            visibleMessages[message.id] = message

            // Mantener windowSize, evictar del inicio si es necesario
            if allMessageIds.count > windowSize {
                currentWindowStart = max(0, currentWindowEnd - windowSize)
                evictInvisibleMessages()
            }
        }

        print("➕ Mensaje agregado: \(message.id) (total: \(allMessageIds.count))")
    }

    /// Remueve mensajes fuera de la ventana visible para liberar memoria
    func evictInvisibleMessages() {
        guard !allMessageIds.isEmpty else { return }

        let safeStart = max(0, min(currentWindowStart, allMessageIds.count))
        let safeEnd = max(safeStart, min(currentWindowEnd, allMessageIds.count))

        let visibleIds = Set(allMessageIds[safeStart..<safeEnd])
        let beforeCount = visibleMessages.count

        visibleMessages = visibleMessages.filter { visibleIds.contains($0.key) }

        let evictedCount = beforeCount - visibleMessages.count
        if evictedCount > 0 {
            print("🗑️ Evictados \(evictedCount) mensajes fuera de ventana")
        }
    }

    /// Limpia toda la ventana
    func clear() {
        allMessageIds.removeAll()
        visibleMessages.removeAll()
        currentWindowStart = 0
        currentWindowEnd = 0

        print("🧹 MessageWindow limpiado")
    }

    // MARK: - Inspection

    /// Número total de mensajes conocidos
    var totalMessageCount: Int {
        allMessageIds.count
    }

    /// Número de mensajes actualmente en memoria
    var loadedMessageCount: Int {
        visibleMessages.count
    }

    /// Rango actual de la ventana
    var currentWindow: (start: Int, end: Int) {
        (currentWindowStart, currentWindowEnd)
    }

    /// Estimación de uso de memoria en MB
    var estimatedMemoryUsageMB: Double {
        // Estimación: ~1 KB por mensaje
        let bytesPerMessage = 1024.0
        let bytes = Double(visibleMessages.count) * bytesPerMessage
        return bytes / (1024 * 1024)
    }
}

// MARK: - Supporting Types

enum ScrollDirection {
    case up      // Hacia mensajes antiguos
    case down    // Hacia mensajes nuevos
    case none    // Sin movimiento
}

// MARK: - Debug Extension
#if DEBUG
extension MessageWindow {
    /// Imprime estado actual del window (solo para debugging)
    func debugPrintStatus() async {
        print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
        print("🪟 MESSAGE WINDOW STATUS")
        print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
        print("Total mensajes: \(allMessageIds.count)")
        print("Mensajes cargados: \(visibleMessages.count)")
        print("Ventana: [\(currentWindowStart)..\(currentWindowEnd)]")
        print("Memoria estimada: \(String(format: "%.2f", estimatedMemoryUsageMB)) MB")
        print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
    }
}
#endif
