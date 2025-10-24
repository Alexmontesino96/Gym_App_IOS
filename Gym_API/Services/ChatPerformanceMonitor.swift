import Foundation
import Combine
import SwiftUI
import os.log

// MARK: - Chat Performance Monitor
@MainActor
class ChatPerformanceMonitor: ObservableObject {
    static let shared = ChatPerformanceMonitor()
    
    // MARK: - Published Properties
    @Published var metrics: PerformanceMetrics = PerformanceMetrics()
    @Published var isMonitoring = false
    @Published var alerts: [PerformanceAlert] = []
    
    // MARK: - Private Properties
    private let logger = OSLog(subsystem: "com.gymapi.chat", category: "Performance")
    private var operationTimers: [String: Date] = [:]
    private var networkRequests: [NetworkRequest] = []
    private var cacheHitRates: [CacheHitRate] = []
    private var memoryUsage: [MemoryUsage] = []
    
    // MARK: - Configuration
    private let maxStoredOperations = 100
    private let alertThresholds = AlertThresholds()
    private let metricsUpdateInterval: TimeInterval = 1.0
    
    private var metricsTimer: Timer?
    
    private init() {
        print("📊 ChatPerformanceMonitor inicializado")
    }
    
    // MARK: - Monitoring Control
    
    func startMonitoring() {
        guard !isMonitoring else { return }
        
        isMonitoring = true
        os_log("📊 Iniciando monitoreo de rendimiento", log: logger, type: .info)
        
        // Configurar timer para actualizar métricas
        metricsTimer = Timer.scheduledTimer(withTimeInterval: metricsUpdateInterval, repeats: true) { _ in
            Task { @MainActor in
                await self.updateMetrics()
            }
        }
        
        // Configurar observadores del sistema
        setupSystemObservers()
        
        print("✅ Monitoreo de rendimiento iniciado")
    }
    
    func stopMonitoring() {
        guard isMonitoring else { return }
        
        isMonitoring = false
        os_log("📊 Deteniendo monitoreo de rendimiento", log: logger, type: .info)
        
        metricsTimer?.invalidate()
        metricsTimer = nil
        
        removeSystemObservers()
        
        print("⏹️ Monitoreo de rendimiento detenido")
    }
    
    // MARK: - Operation Tracking
    
    func startOperation(_ operationId: String, type: OperationType) {
        operationTimers[operationId] = Date()
        os_log("⏱️ Iniciando operación: %@ - %@", log: logger, type: .debug, operationId, type.rawValue)
    }
    
    func endOperation(_ operationId: String, type: OperationType, success: Bool = true) {
        guard let startTime = operationTimers.removeValue(forKey: operationId) else {
            os_log("⚠️ No se encontró tiempo de inicio para operación: %@", log: logger, type: .error, operationId)
            return
        }
        
        let duration = Date().timeIntervalSince(startTime)
        
        let operation = OperationMetric(
            id: operationId,
            type: type,
            duration: duration,
            success: success,
            timestamp: Date()
        )
        
        // Agregar a métricas
        addOperationMetric(operation)
        
        // Verificar si excede umbrales
        checkPerformanceThresholds(operation)
        
        os_log("✅ Operación completada: %@ - %dms", log: logger, type: .debug, operationId, Int(duration))
    }
    
    // MARK: - Network Tracking
    
    func trackNetworkRequest(_ url: String, method: String, size: Int, duration: TimeInterval, success: Bool) {
        let request = NetworkRequest(
            url: url,
            method: method,
            size: size,
            duration: duration,
            success: success,
            timestamp: Date()
        )
        
        networkRequests.append(request)
        
        // Mantener solo las últimas N solicitudes
        if networkRequests.count > maxStoredOperations {
            networkRequests.removeFirst()
        }
        
        os_log("🌐 Request tracked: %@ %@ - %dms", log: logger, type: .debug, method, url, duration)
    }
    
    // MARK: - Cache Tracking
    
    func trackCacheOperation(key: String, hit: Bool, loadTime: TimeInterval? = nil) {
        let cacheOp = CacheOperation(
            key: key,
            hit: hit,
            loadTime: loadTime,
            timestamp: Date()
        )
        
        // Actualizar estadísticas de cache hit rate
        updateCacheHitRate(hit)
        
        os_log("💾 Cache %@: %@", log: logger, type: .debug, hit ? "HIT" : "MISS", key)
    }
    
    // MARK: - Memory Tracking
    
    func trackMemoryUsage() {
        let usage = getCurrentMemoryUsage()
        memoryUsage.append(usage)
        
        // Mantener solo las últimas mediciones
        if memoryUsage.count > maxStoredOperations {
            memoryUsage.removeFirst()
        }
        
        // Verificar alertas de memoria
        if usage.usedMB > alertThresholds.memoryUsageMB {
            let alert = PerformanceAlert(
                type: .highMemoryUsage,
                message: "Uso alto de memoria: \(usage.usedMB)MB",
                severity: .warning,
                timestamp: Date(),
                data: ["usedMB": usage.usedMB]
            )
            addAlert(alert)
        }
    }
    
    // MARK: - Metrics Calculation
    
    private func updateMetrics() async {
        let newMetrics = calculateCurrentMetrics()
        metrics = newMetrics
        
        // Trackear memoria periódicamente
        trackMemoryUsage()
    }
    
    private func calculateCurrentMetrics() -> PerformanceMetrics {
        let now = Date()
        let oneMinuteAgo = now.addingTimeInterval(-60)
        
        // Filtrar operaciones de la última minuta
        let recentOperations = metrics.operations.filter { $0.timestamp > oneMinuteAgo }
        
        // Calcular promedios
        let avgMessageSendTime = calculateAverageTime(for: .sendMessage, in: recentOperations)
        let avgMessageLoadTime = calculateAverageTime(for: .loadMessages, in: recentOperations)
        let avgCacheLoadTime = calculateAverageTime(for: .cacheOperation, in: recentOperations)
        
        // Calcular tasas de éxito
        let messageSuccessRate = calculateSuccessRate(for: .sendMessage, in: recentOperations)
        let syncSuccessRate = calculateSuccessRate(for: .syncMessages, in: recentOperations)
        
        // Calcular cache hit rate
        let currentCacheHitRate = calculateCurrentCacheHitRate()
        
        // Estadísticas de red
        let recentNetworkRequests = networkRequests.filter { $0.timestamp > oneMinuteAgo }
        let avgNetworkLatency = recentNetworkRequests.isEmpty ? 0 : 
            recentNetworkRequests.reduce(0) { $0 + $1.duration } / Double(recentNetworkRequests.count)
        
        // Uso de memoria actual
        let currentMemoryUsage = memoryUsage.last?.usedMB ?? 0
        
        return PerformanceMetrics(
            operations: Array(recentOperations.suffix(maxStoredOperations)),
            avgMessageSendTime: avgMessageSendTime,
            avgMessageLoadTime: avgMessageLoadTime,
            avgCacheLoadTime: avgCacheLoadTime,
            messageSuccessRate: messageSuccessRate,
            syncSuccessRate: syncSuccessRate,
            cacheHitRate: currentCacheHitRate,
            networkLatency: avgNetworkLatency,
            memoryUsageMB: currentMemoryUsage,
            lastUpdated: now
        )
    }
    
    // MARK: - Helper Methods
    
    private func addOperationMetric(_ operation: OperationMetric) {
        metrics.operations.append(operation)
        
        // Mantener solo las últimas operaciones
        if metrics.operations.count > maxStoredOperations {
            metrics.operations.removeFirst()
        }
    }
    
    private func calculateAverageTime(for type: OperationType, in operations: [OperationMetric]) -> TimeInterval {
        let filtered = operations.filter { $0.type == type }
        guard !filtered.isEmpty else { return 0 }
        
        return filtered.reduce(0) { $0 + $1.duration } / Double(filtered.count)
    }
    
    private func calculateSuccessRate(for type: OperationType, in operations: [OperationMetric]) -> Double {
        let filtered = operations.filter { $0.type == type }
        guard !filtered.isEmpty else { return 1.0 }
        
        let successful = filtered.filter { $0.success }.count
        return Double(successful) / Double(filtered.count)
    }
    
    private func updateCacheHitRate(_ hit: Bool) {
        let now = Date()
        let currentMinute = Calendar.current.dateInterval(of: .minute, for: now)
        
        if let interval = currentMinute,
           let lastRate = cacheHitRates.last,
           interval.contains(lastRate.timestamp) {
            // Actualizar rate existente
            cacheHitRates[cacheHitRates.count - 1].totalRequests += 1
            if hit {
                cacheHitRates[cacheHitRates.count - 1].hits += 1
            }
        } else {
            // Crear nuevo rate para este minuto
            let newRate = CacheHitRate(
                hits: hit ? 1 : 0,
                totalRequests: 1,
                timestamp: now
            )
            cacheHitRates.append(newRate)
            
            // Mantener solo las últimas horas
            if cacheHitRates.count > 60 {
                cacheHitRates.removeFirst()
            }
        }
    }
    
    private func calculateCurrentCacheHitRate() -> Double {
        guard !cacheHitRates.isEmpty else { return 0 }
        
        let totalHits = cacheHitRates.reduce(0) { $0 + $1.hits }
        let totalRequests = cacheHitRates.reduce(0) { $0 + $1.totalRequests }
        
        return totalRequests > 0 ? Double(totalHits) / Double(totalRequests) : 0
    }
    
    private func getCurrentMemoryUsage() -> MemoryUsage {
        var info = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size)/4
        
        let kerr: kern_return_t = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: 1) {
                task_info(mach_task_self_,
                         task_flavor_t(MACH_TASK_BASIC_INFO),
                         $0,
                         &count)
            }
        }
        
        let usedMB = kerr == KERN_SUCCESS ? Double(info.resident_size) / 1024.0 / 1024.0 : 0
        
        return MemoryUsage(
            usedMB: usedMB,
            timestamp: Date()
        )
    }
    
    // MARK: - Performance Alerts
    
    private func checkPerformanceThresholds(_ operation: OperationMetric) {
        let threshold = alertThresholds.getThreshold(for: operation.type)
        
        if operation.duration > threshold {
            let alert = PerformanceAlert(
                type: .slowOperation,
                message: "Operación lenta detectada: \(operation.type.rawValue) - \(Int(operation.duration * 1000))ms",
                severity: operation.duration > threshold * 2 ? .critical : .warning,
                timestamp: Date(),
                data: [
                    "operationType": operation.type.rawValue,
                    "duration": operation.duration,
                    "threshold": threshold
                ]
            )
            addAlert(alert)
        }
        
        if !operation.success {
            let alert = PerformanceAlert(
                type: .operationFailure,
                message: "Operación falló: \(operation.type.rawValue)",
                severity: .warning,
                timestamp: Date(),
                data: ["operationType": operation.type.rawValue]
            )
            addAlert(alert)
        }
    }
    
    private func addAlert(_ alert: PerformanceAlert) {
        alerts.append(alert)
        
        // Mantener solo las alertas recientes
        if alerts.count > 20 {
            alerts.removeFirst()
        }
        
        os_log("🚨 Performance Alert: %@", log: logger, type: .error, alert.message)
    }
    
    // MARK: - System Observers
    
    private func setupSystemObservers() {
        NotificationCenter.default.addObserver(
            forName: UIApplication.didReceiveMemoryWarningNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            let alert = PerformanceAlert(
                type: .memoryWarning,
                message: "Sistema reportó advertencia de memoria",
                severity: .critical,
                timestamp: Date(),
                data: [:]
            )
            self?.addAlert(alert)
        }
    }
    
    private func removeSystemObservers() {
        NotificationCenter.default.removeObserver(self)
    }
    
    // MARK: - Export & Analysis
    
    func exportMetrics() -> PerformanceReport {
        return PerformanceReport(
            metrics: metrics,
            alerts: alerts,
            networkRequests: networkRequests,
            cacheHitRates: cacheHitRates,
            memoryUsage: memoryUsage,
            generatedAt: Date()
        )
    }
    
    func clearMetrics() {
        metrics = PerformanceMetrics()
        alerts.removeAll()
        networkRequests.removeAll()
        cacheHitRates.removeAll()
        memoryUsage.removeAll()
        
        os_log("🧹 Métricas de rendimiento limpiadas", log: logger, type: .info)
    }
    
    deinit {
        // El cleanup será manejado automáticamente por el garbage collector
        // No podemos llamar a stopMonitoring() desde deinit porque es @MainActor
    }
}

// MARK: - Supporting Models

struct PerformanceMetrics {
    var operations: [OperationMetric] = []
    var avgMessageSendTime: TimeInterval = 0
    var avgMessageLoadTime: TimeInterval = 0
    var avgCacheLoadTime: TimeInterval = 0
    var messageSuccessRate: Double = 1.0
    var syncSuccessRate: Double = 1.0
    var cacheHitRate: Double = 0
    var networkLatency: TimeInterval = 0
    var memoryUsageMB: Double = 0
    var lastUpdated: Date = Date()
}

struct OperationMetric {
    let id: String
    let type: OperationType
    let duration: TimeInterval
    let success: Bool
    let timestamp: Date
}

enum OperationType: String, CaseIterable {
    case sendMessage = "send_message"
    case loadMessages = "load_messages"
    case syncMessages = "sync_messages"
    case cacheOperation = "cache_operation"
    case networkRequest = "network_request"
    case databaseQuery = "database_query"
    case imageLoad = "image_load"
    case connect = "connect"
    case disconnect = "disconnect"
}

struct NetworkRequest {
    let url: String
    let method: String
    let size: Int
    let duration: TimeInterval
    let success: Bool
    let timestamp: Date
}

struct CacheOperation {
    let key: String
    let hit: Bool
    let loadTime: TimeInterval?
    let timestamp: Date
}

struct CacheHitRate {
    var hits: Int
    var totalRequests: Int
    let timestamp: Date
    
    var rate: Double {
        return totalRequests > 0 ? Double(hits) / Double(totalRequests) : 0
    }
}

struct MemoryUsage {
    let usedMB: Double
    let timestamp: Date
}

struct PerformanceAlert {
    let type: AlertType
    let message: String
    let severity: AlertSeverity
    let timestamp: Date
    let data: [String: Any]
    
    enum AlertType {
        case slowOperation
        case operationFailure
        case highMemoryUsage
        case memoryWarning
        case highNetworkLatency
        case lowCacheHitRate
    }
    
    enum AlertSeverity {
        case info
        case warning
        case critical
        
        var color: Color {
            switch self {
            case .info: return .blue
            case .warning: return .orange
            case .critical: return .red
            }
        }
    }
}

struct AlertThresholds {
    let sendMessageThreshold: TimeInterval = 2.0 // 2 segundos
    let loadMessagesThreshold: TimeInterval = 1.0 // 1 segundo
    let cacheOperationThreshold: TimeInterval = 0.1 // 100ms
    let networkRequestThreshold: TimeInterval = 3.0 // 3 segundos
    let memoryUsageMB: Double = 100.0 // 100MB
    
    func getThreshold(for type: OperationType) -> TimeInterval {
        switch type {
        case .sendMessage: return sendMessageThreshold
        case .loadMessages: return loadMessagesThreshold
        case .cacheOperation: return cacheOperationThreshold
        case .networkRequest: return networkRequestThreshold
        default: return 1.0
        }
    }
}

struct PerformanceReport {
    let metrics: PerformanceMetrics
    let alerts: [PerformanceAlert]
    let networkRequests: [NetworkRequest]
    let cacheHitRates: [CacheHitRate]
    let memoryUsage: [MemoryUsage]
    let generatedAt: Date
    
    var summary: String {
        let alertCount = alerts.count
        let criticalAlerts = alerts.filter { $0.severity == .critical }.count
        let avgLatency = Int(metrics.networkLatency * 1000)
        let cacheHitRate = Int(metrics.cacheHitRate * 100)
        
        return """
        📊 Reporte de Rendimiento
        
        🔄 Operaciones:
        • Envío promedio: \(Int(metrics.avgMessageSendTime * 1000))ms
        • Carga promedio: \(Int(metrics.avgMessageLoadTime * 1000))ms
        • Tasa de éxito mensajes: \(Int(metrics.messageSuccessRate * 100))%
        
        🌐 Red:
        • Latencia promedio: \(avgLatency)ms
        
        💾 Cache:
        • Hit rate: \(cacheHitRate)%
        
        🧠 Memoria:
        • Uso actual: \(Int(metrics.memoryUsageMB))MB
        
        🚨 Alertas:
        • Total: \(alertCount)
        • Críticas: \(criticalAlerts)
        
        📅 Generado: \(DateFormatter.localizedString(from: generatedAt, dateStyle: .short, timeStyle: .short))
        """
    }
}