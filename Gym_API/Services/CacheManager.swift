//
//  CacheManager.swift
//  Gym_API
//
//  Sistema centralizado de gestión de caché con límites de memoria
//  Created as part of memory optimization phase
//

import Foundation
import UIKit
import SwiftUI

// MARK: - Cache Policy
enum CachePolicy {
    case lru // Least Recently Used
    case lfu // Least Frequently Used
    case fifo // First In First Out
    case ttl(seconds: TimeInterval) // Time To Live
}

// MARK: - Cache Entry
private struct CacheEntry<T> {
    let value: T
    let size: Int
    let timestamp: Date
    var accessCount: Int
    var lastAccessTime: Date

    init(value: T, size: Int) {
        self.value = value
        self.size = size
        self.timestamp = Date()
        self.accessCount = 1
        self.lastAccessTime = Date()
    }

    mutating func recordAccess() {
        accessCount += 1
        lastAccessTime = Date()
    }
}

// MARK: - Cache Manager
@MainActor
class CacheManager: ObservableObject {

    // MARK: - Singleton
    static let shared = CacheManager()

    // MARK: - Configuration
    struct Configuration {
        var maxMemoryBytes: Int = 50 * 1024 * 1024 // 50 MB por defecto
        var maxImageCacheBytes: Int = 30 * 1024 * 1024 // 30 MB para imágenes
        var maxDataCacheBytes: Int = 10 * 1024 * 1024 // 10 MB para datos
        var maxCacheAge: TimeInterval = 600 // 10 minutos
        var evictionPolicy: CachePolicy = .lru
        var memoryWarningThreshold: Double = 0.8 // 80% de uso dispara limpieza
    }

    // MARK: - Published Properties
    @Published var currentMemoryUsage: Int = 0
    @Published var cacheHitRate: Double = 0.0
    @Published var isMemoryOptimized = true

    // MARK: - Private Properties
    private var configuration = Configuration()
    private var imageCache = NSCache<NSString, UIImage>()
    private var dataCache: [String: CacheEntry<Data>] = [:]
    private var objectCache: [String: CacheEntry<Any>] = [:]

    // Statistics
    private var cacheHits: Int = 0
    private var cacheMisses: Int = 0
    private var totalEvictions: Int = 0

    // Memory monitoring
    private var memoryWarningObserver: NSObjectProtocol?

    // MARK: - Initialization
    private init() {
        setupImageCache()
        setupMemoryMonitoring()
        startPeriodicCleanup()

        print("✅ CacheManager inicializado")
        print("📊 Límite de memoria: \(configuration.maxMemoryBytes / 1024 / 1024) MB")
    }

    // MARK: - Setup
    private func setupImageCache() {
        imageCache.countLimit = 100 // Máximo 100 imágenes
        imageCache.totalCostLimit = configuration.maxImageCacheBytes
        imageCache.evictsObjectsWithDiscardedContent = true
    }

    private func setupMemoryMonitoring() {
        // Observar warnings de memoria
        memoryWarningObserver = NotificationCenter.default.addObserver(
            forName: UIApplication.didReceiveMemoryWarningNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.handleMemoryWarning()
        }
    }

    private func startPeriodicCleanup() {
        Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.performPeriodicCleanup()
            }
        }
    }

    // MARK: - Image Cache
    func cacheImage(_ image: UIImage, forKey key: String) {
        let cost = image.estimatedMemorySize

        // Verificar límite antes de cachear
        if cost > configuration.maxImageCacheBytes / 4 {
            print("⚠️ Imagen muy grande para cachear: \(cost / 1024) KB")
            return
        }

        imageCache.setObject(image, forKey: key as NSString, cost: cost)
        updateMemoryUsage()

        #if DEBUG
        print("🖼️ Imagen cacheada: \(key) (\(cost / 1024) KB)")
        #endif
    }

    func getImage(forKey key: String) -> UIImage? {
        if let image = imageCache.object(forKey: key as NSString) {
            cacheHits += 1
            updateHitRate()
            return image
        }

        cacheMisses += 1
        updateHitRate()
        return nil
    }

    func removeImage(forKey key: String) {
        imageCache.removeObject(forKey: key as NSString)
        updateMemoryUsage()
    }

    // MARK: - Data Cache
    func cacheData(_ data: Data, forKey key: String) {
        let size = data.count

        // Verificar límite
        if size > configuration.maxDataCacheBytes / 4 {
            print("⚠️ Datos muy grandes para cachear: \(size / 1024) KB")
            return
        }

        // Aplicar política de evicción si es necesario
        while currentDataCacheSize() + size > configuration.maxDataCacheBytes {
            evictOldestData()
        }

        dataCache[key] = CacheEntry(value: data, size: size)
        updateMemoryUsage()

        #if DEBUG
        print("📦 Datos cacheados: \(key) (\(size / 1024) KB)")
        #endif
    }

    func getData(forKey key: String) -> Data? {
        guard var entry = dataCache[key] else {
            cacheMisses += 1
            updateHitRate()
            return nil
        }

        // Verificar TTL si aplica
        if case .ttl(let seconds) = configuration.evictionPolicy {
            if Date().timeIntervalSince(entry.timestamp) > seconds {
                dataCache.removeValue(forKey: key)
                cacheMisses += 1
                updateHitRate()
                return nil
            }
        }

        entry.recordAccess()
        dataCache[key] = entry
        cacheHits += 1
        updateHitRate()

        return entry.value
    }

    // MARK: - Object Cache (Generic)
    func cacheObject<T>(_ object: T, forKey key: String, estimatedSize: Int? = nil) {
        let size = estimatedSize ?? MemoryLayout<T>.size

        // Verificar límite
        if size > configuration.maxDataCacheBytes / 4 {
            print("⚠️ Objeto muy grande para cachear: \(size / 1024) KB")
            return
        }

        objectCache[key] = CacheEntry(value: object, size: size)
        updateMemoryUsage()

        #if DEBUG
        print("🗂️ Objeto cacheado: \(key)")
        #endif
    }

    func getObject<T>(forKey key: String, type: T.Type) -> T? {
        guard var entry = objectCache[key] else {
            cacheMisses += 1
            updateHitRate()
            return nil
        }

        entry.recordAccess()
        objectCache[key] = entry
        cacheHits += 1
        updateHitRate()

        return entry.value as? T
    }

    // MARK: - Memory Management
    private func updateMemoryUsage() {
        let imageCacheSize = estimateImageCacheSize()
        let dataCacheSize = currentDataCacheSize()
        let objectCacheSize = currentObjectCacheSize()

        currentMemoryUsage = imageCacheSize + dataCacheSize + objectCacheSize
        isMemoryOptimized = currentMemoryUsage < configuration.maxMemoryBytes

        // Verificar umbral de memoria
        let usagePercentage = Double(currentMemoryUsage) / Double(configuration.maxMemoryBytes)
        if usagePercentage > configuration.memoryWarningThreshold {
            performAggressiveCleanup()
        }
    }

    private func estimateImageCacheSize() -> Int {
        // NSCache no proporciona tamaño exacto, estimamos basándonos en el límite
        return min(imageCache.totalCostLimit / 2, configuration.maxImageCacheBytes / 2)
    }

    private func currentDataCacheSize() -> Int {
        dataCache.values.reduce(0) { $0 + $1.size }
    }

    private func currentObjectCacheSize() -> Int {
        objectCache.values.reduce(0) { $0 + $1.size }
    }

    // MARK: - Eviction Policies
    private func evictOldestData() {
        guard !dataCache.isEmpty else { return }

        var keyToRemove: String?

        switch configuration.evictionPolicy {
        case .lru:
            // Eliminar el menos recientemente usado
            keyToRemove = dataCache.min { $0.value.lastAccessTime < $1.value.lastAccessTime }?.key

        case .lfu:
            // Eliminar el menos frecuentemente usado
            keyToRemove = dataCache.min { $0.value.accessCount < $1.value.accessCount }?.key

        case .fifo:
            // Eliminar el más antiguo
            keyToRemove = dataCache.min { $0.value.timestamp < $1.value.timestamp }?.key

        case .ttl:
            // TTL se maneja en getData
            keyToRemove = dataCache.first?.key
        }

        if let key = keyToRemove {
            dataCache.removeValue(forKey: key)
            totalEvictions += 1
            #if DEBUG
            print("🗑️ Cache eviction: \(key)")
            #endif
        }
    }

    // MARK: - Cleanup
    private func performPeriodicCleanup() {
        let now = Date()
        var removedCount = 0

        // Limpiar datos expirados
        dataCache = dataCache.filter { key, entry in
            let shouldKeep = now.timeIntervalSince(entry.timestamp) < configuration.maxCacheAge
            if !shouldKeep {
                removedCount += 1
            }
            return shouldKeep
        }

        // Limpiar objetos expirados
        objectCache = objectCache.filter { key, entry in
            let shouldKeep = now.timeIntervalSince(entry.timestamp) < configuration.maxCacheAge
            if !shouldKeep {
                removedCount += 1
            }
            return shouldKeep
        }

        if removedCount > 0 {
            print("🧹 Limpieza periódica: \(removedCount) elementos eliminados")
            updateMemoryUsage()
        }
    }

    private func performAggressiveCleanup() {
        print("⚠️ Umbral de memoria alcanzado, ejecutando limpieza agresiva...")

        // Limpiar 50% del caché menos usado
        let targetReduction = dataCache.count / 2

        let sortedEntries = dataCache.sorted {
            $0.value.lastAccessTime < $1.value.lastAccessTime
        }

        for (index, entry) in sortedEntries.enumerated() {
            if index >= targetReduction { break }
            dataCache.removeValue(forKey: entry.key)
        }

        // Limpiar caché de imágenes
        imageCache.removeAllObjects()

        // Limpiar 50% del caché de objetos
        let objectTargetReduction = objectCache.count / 2
        let sortedObjects = objectCache.sorted {
            $0.value.lastAccessTime < $1.value.lastAccessTime
        }

        for (index, entry) in sortedObjects.enumerated() {
            if index >= objectTargetReduction { break }
            objectCache.removeValue(forKey: entry.key)
        }

        updateMemoryUsage()
        print("✅ Limpieza agresiva completada. Memoria actual: \(currentMemoryUsage / 1024 / 1024) MB")
    }

    private func handleMemoryWarning() {
        print("🚨 MEMORY WARNING RECIBIDO - Limpiando todos los cachés...")
        clearAllCaches()
    }

    // MARK: - Statistics
    private func updateHitRate() {
        let total = cacheHits + cacheMisses
        cacheHitRate = total > 0 ? Double(cacheHits) / Double(total) : 0.0
    }

    var statistics: CacheStatistics {
        CacheStatistics(
            hitRate: cacheHitRate,
            totalHits: cacheHits,
            totalMisses: cacheMisses,
            totalEvictions: totalEvictions,
            currentMemoryUsage: currentMemoryUsage,
            maxMemory: configuration.maxMemoryBytes,
            imageCacheCount: 0, // NSCache no expone count
            dataCacheCount: dataCache.count,
            objectCacheCount: objectCache.count
        )
    }

    // MARK: - Public Methods
    func clearAllCaches() {
        imageCache.removeAllObjects()
        dataCache.removeAll()
        objectCache.removeAll()
        currentMemoryUsage = 0
        isMemoryOptimized = true

        print("🗑️ Todos los cachés limpiados")
    }

    func clearImageCache() {
        imageCache.removeAllObjects()
        updateMemoryUsage()
        print("🖼️ Caché de imágenes limpiado")
    }

    func clearDataCache() {
        dataCache.removeAll()
        updateMemoryUsage()
        print("📦 Caché de datos limpiado")
    }

    func configure(_ configuration: Configuration) {
        self.configuration = configuration
        setupImageCache()
        print("⚙️ Configuración de caché actualizada")
    }

    deinit {
        #if DEBUG
        print("🗑️ CacheManager deinitialized")
        #endif

        if let observer = memoryWarningObserver {
            NotificationCenter.default.removeObserver(observer)
        }

        // Los cachés se limpiarán automáticamente con ARC
        // No podemos llamar a clearAllCaches() desde deinit porque está en MainActor
    }
}

// MARK: - Cache Statistics
struct CacheStatistics {
    let hitRate: Double
    let totalHits: Int
    let totalMisses: Int
    let totalEvictions: Int
    let currentMemoryUsage: Int
    let maxMemory: Int
    let imageCacheCount: Int
    let dataCacheCount: Int
    let objectCacheCount: Int

    var hitRatePercentage: String {
        "\(Int(hitRate * 100))%"
    }

    var memoryUsagePercentage: String {
        let percentage = Double(currentMemoryUsage) / Double(maxMemory) * 100
        return "\(Int(percentage))%"
    }

    var formattedMemoryUsage: String {
        "\(currentMemoryUsage / 1024 / 1024) / \(maxMemory / 1024 / 1024) MB"
    }
}

// MARK: - UIImage Extension
private extension UIImage {
    var estimatedMemorySize: Int {
        guard let cgImage = self.cgImage else { return 0 }
        return cgImage.bytesPerRow * cgImage.height
    }
}