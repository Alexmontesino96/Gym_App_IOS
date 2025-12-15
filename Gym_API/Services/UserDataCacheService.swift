//
//  UserDataCacheService.swift
//  Gym_API
//
//  Servicio centralizado para el caché de datos de usuarios
//  Elimina duplicación de cachés en múltiples servicios
//

import Foundation
import SwiftUI

// MARK: - User Data Cache Service
/// Servicio singleton que centraliza todo el caché de datos de usuarios
/// Reemplaza cachés duplicados en: EventService, ClassService, ChatService, UnifiedChatService
@MainActor
final class UserDataCacheService: ObservableObject {

    // MARK: - Singleton
    static let shared = UserDataCacheService()

    // MARK: - Cache Storage

    /// Caché principal de perfiles completos de usuarios
    /// Key: userId (Int), Value: UserProfile
    @Published private(set) var userProfiles: [Int: UserProfile] = [:]

    /// Caché de perfiles públicos (versión ligera)
    /// Key: userId (Int), Value: UserPublicProfile
    @Published private(set) var publicProfiles: [Int: UserPublicProfile] = [:]

    /// Caché de nombres de usuarios para búsqueda rápida
    /// Key: userId (Int), Value: fullName (String)
    @Published private(set) var userNames: [Int: String] = [:]

    /// Caché de trainers/coaches específicamente
    /// Key: trainerId (Int), Value: UserPublicProfile
    @Published private(set) var trainers: [Int: UserPublicProfile] = [:]

    // MARK: - Cache Metadata

    /// Timestamp de última actualización por usuario
    private var lastUpdated: [Int: Date] = [:]

    /// TTL para el caché (30 minutos por defecto)
    private let cacheTTL: TimeInterval = 1800 // 30 minutes

    /// Límite máximo de usuarios en caché
    private let maxCacheSize = 500

    // MARK: - Loading States
    @Published var isLoading = false
    @Published var errorMessage: String?

    // MARK: - Statistics
    @Published private(set) var cacheHits = 0
    @Published private(set) var cacheMisses = 0

    // MARK: - Private Properties
    private let queue = DispatchQueue(label: "com.gymapi.usercache", attributes: .concurrent)
    private var pendingFetches: Set<Int> = []
    private let baseURL = "https://gymapi-eh6m.onrender.com/api/v1"

    // MARK: - Initialization
    private init() {
        print("🎯 UserDataCacheService initialized")
        setupCacheCleanupTimer()
    }

    // MARK: - Public Methods

    /// Obtiene un perfil completo de usuario, desde caché o API
    func getUserProfile(_ userId: Int, forceRefresh: Bool = false) async -> UserProfile? {
        // Check if we need to refresh
        if !forceRefresh, let cached = getCachedUserProfile(userId) {
            cacheHits += 1
            return cached
        }

        cacheMisses += 1

        // Avoid duplicate fetches
        if pendingFetches.contains(userId) {
            // Wait a bit and try cache again
            try? await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
            return getCachedUserProfile(userId)
        }

        pendingFetches.insert(userId)
        defer { pendingFetches.remove(userId) }

        // Fetch from API (implement actual API call in integration)
        return await fetchUserProfileFromAPI(userId)
    }

    /// Obtiene un perfil público de usuario
    func getPublicProfile(_ userId: Int) async -> UserPublicProfile? {
        if let cached = publicProfiles[userId] {
            if !isExpired(userId) {
                cacheHits += 1
                return cached
            }
        }

        cacheMisses += 1

        // Try to get from full profile first
        if let fullProfile = await getUserProfile(userId) {
            let publicProfile = UserPublicProfile(from: fullProfile)
            updatePublicProfile(userId, profile: publicProfile)
            return publicProfile
        }

        return nil
    }

    /// Obtiene el nombre de un usuario
    func getUserName(_ userId: Int) async -> String {
        if let cached = userNames[userId] {
            if !isExpired(userId) {
                cacheHits += 1
                return cached
            }
        }

        cacheMisses += 1

        if let profile = await getUserProfile(userId) {
            return profile.fullName
        }

        return "Usuario \(userId)"
    }

    /// Obtiene información de un trainer
    func getTrainer(_ trainerId: Int) async -> UserPublicProfile? {
        if let cached = trainers[trainerId] {
            if !isExpired(trainerId) {
                cacheHits += 1
                return cached
            }
        }

        cacheMisses += 1

        if let profile = await getPublicProfile(trainerId) {
            trainers[trainerId] = profile
            return profile
        }

        return nil
    }

    /// Actualiza múltiples perfiles de usuarios en batch
    func updateUserProfiles(_ profiles: [UserProfile]) {
        for profile in profiles {
            updateUserProfile(profile.id, profile: profile)
        }

        // Enforce cache size limit
        if userProfiles.count > maxCacheSize {
            evictOldestEntries()
        }
    }

    /// Actualiza un perfil de usuario
    func updateUserProfile(_ userId: Int, profile: UserProfile) {
        userProfiles[userId] = profile
        userNames[userId] = profile.fullName
        lastUpdated[userId] = Date()

        // Also update public profile
        let publicProfile = UserPublicProfile(from: profile)
        publicProfiles[userId] = publicProfile
    }

    /// Actualiza un perfil público
    func updatePublicProfile(_ userId: Int, profile: UserPublicProfile) {
        publicProfiles[userId] = profile
        userNames[userId] = profile.fullName
        lastUpdated[userId] = Date()

        // If it's a trainer, update trainer cache
        if profile.role.lowercased().contains("trainer") || profile.role.lowercased().contains("coach") {
            trainers[userId] = profile
        }
    }

    /// Limpia el caché completo
    func clearCache() {
        userProfiles.removeAll()
        publicProfiles.removeAll()
        userNames.removeAll()
        trainers.removeAll()
        lastUpdated.removeAll()
        pendingFetches.removeAll()
        cacheHits = 0
        cacheMisses = 0
        print("🧹 User cache cleared")
    }

    /// Limpia entradas expiradas
    func cleanExpiredEntries() {
        let now = Date()
        var expiredIds: [Int] = []

        for (userId, timestamp) in lastUpdated {
            if now.timeIntervalSince(timestamp) > cacheTTL {
                expiredIds.append(userId)
            }
        }

        for id in expiredIds {
            removeFromCache(id)
        }

        if !expiredIds.isEmpty {
            print("🧹 Cleaned \(expiredIds.count) expired user entries")
        }
    }

    /// Obtiene estadísticas del caché
    func getCacheStatistics() -> UserCacheStatistics {
        return UserCacheStatistics(
            totalProfiles: userProfiles.count,
            publicProfiles: publicProfiles.count,
            trainers: trainers.count,
            cacheHits: cacheHits,
            cacheMisses: cacheMisses,
            hitRate: cacheHits + cacheMisses > 0
                ? Double(cacheHits) / Double(cacheHits + cacheMisses)
                : 0
        )
    }

    // MARK: - Private Methods

    private func getCachedUserProfile(_ userId: Int) -> UserProfile? {
        guard let profile = userProfiles[userId],
              !isExpired(userId) else {
            return nil
        }
        return profile
    }

    private func isExpired(_ userId: Int) -> Bool {
        guard let timestamp = lastUpdated[userId] else {
            return true
        }
        return Date().timeIntervalSince(timestamp) > cacheTTL
    }

    private func removeFromCache(_ userId: Int) {
        userProfiles.removeValue(forKey: userId)
        publicProfiles.removeValue(forKey: userId)
        userNames.removeValue(forKey: userId)
        trainers.removeValue(forKey: userId)
        lastUpdated.removeValue(forKey: userId)
    }

    private func evictOldestEntries() {
        let sortedByAge = lastUpdated.sorted { $0.value < $1.value }
        let toEvict = sortedByAge.prefix(maxCacheSize / 10) // Evict 10% of oldest

        for (userId, _) in toEvict {
            removeFromCache(userId)
        }

        print("🧹 Evicted \(toEvict.count) oldest cache entries")
    }

    private func setupCacheCleanupTimer() {
        Task {
            while true {
                try? await Task.sleep(nanoseconds: 300_000_000_000) // 5 minutes
                await MainActor.run {
                    cleanExpiredEntries()
                }
            }
        }
    }

    /// Fetches user profile from the API
    private func fetchUserProfileFromAPI(_ userId: Int) async -> UserProfile? {
        print("🔄 Fetching user profile from API: \(userId)")

        // ✅ Usar endpoint que permite MEMBERS: /users/profile/{user_id}
        guard let url = URL(string: "\(baseURL)/users/profile/\(userId)") else {
            print("❌ Invalid URL for user \(userId)")
            return nil
        }

        guard let request = await HTTPClient.shared.makeRequest(url: url, method: "GET") else {
            print("⚠️ No se pudo crear request para user \(userId)")
            return nil
        }

        do {
            let (data, response) = try await URLSession.shared.data(for: request)

            // Verificar código de respuesta
            if let httpResponse = response as? HTTPURLResponse {
                guard httpResponse.statusCode == 200 else {
                    // Manejo específico por código de error
                    switch httpResponse.statusCode {
                    case 403:
                        // 403 Forbidden - Usuario de otro gym o sin permisos
                        // Logging reducido para no contaminar logs
                        #if DEBUG
                        print("⚠️ Usuario \(userId) no accesible (403 Forbidden) - probablemente de otro gym")
                        #endif

                    case 404:
                        #if DEBUG
                        print("⚠️ Usuario \(userId) no encontrado (404)")
                        #endif

                    case 500...599:
                        // Error del servidor - estos sí son críticos
                        print("❌ Error del servidor para user \(userId): Status \(httpResponse.statusCode)")

                    default:
                        print("❌ API error for user \(userId): Status code \(httpResponse.statusCode)")
                    }
                    return nil
                }
            }

            // Decodificar respuesta con estrategia de fecha flexible
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .custom { decoder in
                let container = try decoder.singleValueContainer()
                let dateString = try container.decode(String.self)

                let formatter = DateFormatter()
                formatter.locale = Locale(identifier: "en_US_POSIX")
                formatter.timeZone = TimeZone(secondsFromGMT: 0)

                // Intentar múltiples formatos de fecha
                let dateFormats = [
                    "yyyy-MM-dd'T'HH:mm:ss'Z'",
                    "yyyy-MM-dd'T'HH:mm:ss.SSSSSS'Z'",
                    "yyyy-MM-dd'T'HH:mm:ss.SSS'Z'",
                    "yyyy-MM-dd'T'HH:mm:ss",
                    "yyyy-MM-dd'T'HH:mm:ss.SSSSSS",
                    "yyyy-MM-dd'T'HH:mm:ss.SSS",
                    "yyyy-MM-dd"  // Solo fecha sin tiempo
                ]

                for format in dateFormats {
                    formatter.dateFormat = format
                    if let date = formatter.date(from: dateString) {
                        return date
                    }
                }

                throw DecodingError.dataCorruptedError(in: container, debugDescription: "Cannot decode date string '\(dateString)'")
            }
            let userProfile = try decoder.decode(UserProfile.self, from: data)

            // Guardar en caché
            await MainActor.run {
                self.updateUserProfile(userId, profile: userProfile)
            }

            print("✅ User profile cargado: \(userProfile.fullName)")
            return userProfile

        } catch {
            print("❌ Error fetching user profile \(userId): \(error)")
            return nil
        }
    }

    // MARK: - Deinit
    deinit {
        print("💀 UserDataCacheService deinitialized")
    }
}

// MARK: - User Cache Statistics
struct UserCacheStatistics {
    let totalProfiles: Int
    let publicProfiles: Int
    let trainers: Int
    let cacheHits: Int
    let cacheMisses: Int
    let hitRate: Double

    var description: String {
        """
        📊 Cache Statistics:
        - Total Profiles: \(totalProfiles)
        - Public Profiles: \(publicProfiles)
        - Trainers: \(trainers)
        - Cache Hits: \(cacheHits)
        - Cache Misses: \(cacheMisses)
        - Hit Rate: \(String(format: "%.1f%%", hitRate * 100))
        """
    }
}

// MARK: - UserPublicProfile Extension
extension UserPublicProfile {
    /// Creates a public profile from a full UserProfile
    init(from profile: UserProfile) {
        self.init(
            id: profile.id,
            firstName: profile.firstName,
            lastName: profile.lastName,
            picture: profile.picture,
            role: profile.role ?? "member",
            bio: nil,
            isActive: profile.isActive ?? true,  // ✅ Default true si no está presente
            color: profile.color,
            gymRole: profile.gymRole
        )
    }
}

// MARK: - Thread-Safe Access Extension
extension UserDataCacheService {

    /// Thread-safe batch update
    func updateProfilesBatch(_ profiles: [UserProfile]) async {
        await MainActor.run {
            updateUserProfiles(profiles)
        }
    }

    /// Thread-safe single update
    func updateProfileSafe(_ userId: Int, profile: UserProfile) async {
        await MainActor.run {
            updateUserProfile(userId, profile: profile)
        }
    }
}

// MARK: - Convenience Methods
extension UserDataCacheService {

    /// Get multiple users at once
    func getUsers(_ userIds: [Int]) async -> [UserProfile] {
        var profiles: [UserProfile] = []

        for userId in userIds {
            if let profile = await getUserProfile(userId) {
                profiles.append(profile)
            }
        }

        return profiles
    }

    /// Prefetch users for better performance
    func prefetchUsers(_ userIds: [Int]) {
        Task {
            for userId in userIds {
                _ = await getUserProfile(userId)
            }
        }
    }

    /// Search users by name (from cache only)
    func searchUsersByName(_ query: String) -> [UserProfile] {
        let lowercaseQuery = query.lowercased()
        return userProfiles.values.filter {
            $0.fullName.lowercased().contains(lowercaseQuery)
        }
    }

    /// Get all cached user profiles (no API calls)
    func getAllCachedProfiles() -> [UserProfile] {
        return Array(userProfiles.values)
    }
}