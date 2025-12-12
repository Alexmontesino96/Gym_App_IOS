//
//  MemoryBudgetManager.swift
//  Gym_API
//
//  Created by Claude Code
//  Copyright © 2025 Gym API. All rights reserved.
//

import Foundation
import Combine
import UIKit

// MARK: - Memory Budget Manager
/// Gestor global de presupuesto de memoria para prevenir SIGKILL
/// Coordina el uso de memoria entre múltiples cache managers
@MainActor
class MemoryBudgetManager: ObservableObject {

    // MARK: - Singleton
    static let shared = MemoryBudgetManager()

    // MARK: - Published Properties
    @Published private(set) var allocations: [String: MemoryAllocation] = [:]
    @Published private(set) var currentUsageMB: Double = 0
    @Published private(set) var isNearLimit: Bool = false

    // MARK: - Configuration
    /// Presupuesto total en MB (conservador para evitar SIGKILL)
    /// iOS típicamente termina apps que usan > 150-200 MB en dispositivos con 2GB RAM
    private let totalBudgetMB: Double = 80

    /// Threshold para considerar que estamos cerca del límite (80%)
    private let nearLimitThreshold: Double = 0.8

    // MARK: - Structures
    struct MemoryAllocation {
        let key: String
        let sizeMB: Double
        let timestamp: Date
        let category: AllocationCategory
    }

    enum AllocationCategory: String {
        case messageCache = "Message Cache"
        case imageCache = "Image Cache"
        case profileCache = "Profile Cache"
        case userData = "User Data"
        case other = "Other"
    }

    // MARK: - Initialization
    private init() {
        print("💰 MemoryBudgetManager inicializado con presupuesto de \(totalBudgetMB) MB")
        setupMemoryWarningObserver()
    }

    // MARK: - Public Methods

    /// Intenta asignar memoria del presupuesto global
    /// - Parameters:
    ///   - mb: Cantidad de MB a asignar
    ///   - key: Identificador único para esta asignación
    ///   - category: Categoría de la asignación
    /// - Returns: true si hay presupuesto disponible, false si excedería el límite
    func allocate(_ mb: Double, for key: String, category: AllocationCategory = .other) -> Bool {
        let available = totalBudgetMB - currentUsageMB

        guard mb <= available else {
            print("⚠️ MemoryBudget EXCEDIDO: solicitando \(mb)MB, disponible \(available)MB")
            print("⚠️ Uso actual: \(currentUsageMB)MB / \(totalBudgetMB)MB")
            return false
        }

        let allocation = MemoryAllocation(
            key: key,
            sizeMB: mb,
            timestamp: Date(),
            category: category
        )

        allocations[key] = allocation
        updateCurrentUsage()

        print("💰 Memoria asignada: \(mb)MB para '\(key)' (\(category.rawValue))")
        print("💰 Uso actual: \(currentUsageMB)MB / \(totalBudgetMB)MB (\(Int(usagePercentage))%)")

        return true
    }

    /// Libera memoria previamente asignada
    /// - Parameter key: Identificador de la asignación a liberar
    func deallocate(for key: String) {
        guard let allocation = allocations[key] else {
            print("⚠️ Intento de deallocate para clave no asignada: \(key)")
            return
        }

        allocations.removeValue(forKey: key)
        updateCurrentUsage()

        print("💰 Memoria liberada: \(allocation.sizeMB)MB de '\(key)' (\(allocation.category.rawValue))")
        print("💰 Uso actual: \(currentUsageMB)MB / \(totalBudgetMB)MB (\(Int(usagePercentage))%)")
    }

    /// Obtiene el uso actual de memoria como porcentaje
    var usagePercentage: Double {
        (currentUsageMB / totalBudgetMB) * 100
    }

    /// Obtiene memoria disponible en MB
    var availableMB: Double {
        totalBudgetMB - currentUsageMB
    }

    /// Verifica si una asignación es posible sin exceder el presupuesto
    func canAllocate(_ mb: Double) -> Bool {
        return mb <= availableMB
    }

    /// Obtiene estadísticas de uso de memoria por categoría
    func getUsageByCategory() -> [AllocationCategory: Double] {
        var usage: [AllocationCategory: Double] = [:]

        for allocation in allocations.values {
            usage[allocation.category, default: 0] += allocation.sizeMB
        }

        return usage
    }

    /// Fuerza liberación de memoria de asignaciones antiguas (más de 5 minutos)
    /// Útil en situaciones de memory pressure
    func cleanupStaleAllocations() {
        let fiveMinutesAgo = Date().addingTimeInterval(-300)
        var removed: [(String, Double)] = []

        for (key, allocation) in allocations {
            if allocation.timestamp < fiveMinutesAgo {
                removed.append((key, allocation.sizeMB))
                allocations.removeValue(forKey: key)
            }
        }

        if !removed.isEmpty {
            updateCurrentUsage()
            print("🧹 Cleanup: Liberados \(removed.count) allocations antiguos")
            for (key, mb) in removed {
                print("  - \(key): \(mb)MB")
            }
        }
    }

    /// Imprime reporte detallado de uso de memoria
    func printMemoryReport() {
        print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
        print("💰 REPORTE DE MEMORIA")
        print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
        print("Presupuesto Total: \(totalBudgetMB) MB")
        print("Uso Actual: \(String(format: "%.2f", currentUsageMB)) MB (\(Int(usagePercentage))%)")
        print("Disponible: \(String(format: "%.2f", availableMB)) MB")
        print("\nAsignaciones Activas (\(allocations.count)):")

        let byCategory = getUsageByCategory()
        for (category, usage) in byCategory.sorted(by: { $0.value > $1.value }) {
            print("  \(category.rawValue): \(String(format: "%.2f", usage)) MB")
        }

        print("\nDetalle:")
        for (key, allocation) in allocations.sorted(by: { $0.value.sizeMB > $1.value.sizeMB }) {
            let age = Date().timeIntervalSince(allocation.timestamp)
            print("  - \(key): \(String(format: "%.2f", allocation.sizeMB)) MB (hace \(Int(age))s)")
        }
        print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
    }

    // MARK: - Private Methods

    private func updateCurrentUsage() {
        currentUsageMB = allocations.values.reduce(0) { $0 + $1.sizeMB }
        isNearLimit = usagePercentage >= (nearLimitThreshold * 100)

        if isNearLimit {
            print("⚠️ ADVERTENCIA: Uso de memoria cerca del límite (\(Int(usagePercentage))%)")
        }
    }

    private func setupMemoryWarningObserver() {
        NotificationCenter.default.addObserver(
            forName: UIApplication.didReceiveMemoryWarningNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            guard let self = self else { return }

            Task { @MainActor in
                print("🚨 MEMORY WARNING RECIBIDO")
                self.printMemoryReport()
                self.cleanupStaleAllocations()
            }
        }
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
        #if DEBUG
        print("💰 MemoryBudgetManager deinit")
        #endif
    }
}

// MARK: - Memory Budget Extensions

extension MemoryBudgetManager {

    /// Helper para calcular tamaño estimado de mensajes en MB
    static func estimatedSize(forMessageCount count: Int) -> Double {
        // Estimación: ~1 KB por mensaje (incluyendo metadata)
        let bytesPerMessage = 1024.0
        let bytes = Double(count) * bytesPerMessage
        return bytes / (1024 * 1024) // Convert to MB
    }

    /// Helper para calcular tamaño estimado de imágenes en MB
    static func estimatedSize(forImageCount count: Int, averageSizeMB: Double = 0.5) -> Double {
        return Double(count) * averageSizeMB
    }
}
