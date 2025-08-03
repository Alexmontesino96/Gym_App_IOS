//
//  KeychainService.swift
//  Gym_API
//
//  Created by Assistant on 8/3/25.
//
//  Secure token storage using iOS Keychain Services
//  Provides encrypted storage for sensitive authentication tokens

import Foundation
import Security

/// Service for secure storage of authentication tokens in iOS Keychain
@MainActor
class KeychainService {
    static let shared = KeychainService()
    
    private init() {}
    
    // MARK: - Constants
    private let serviceName = "com.gymapi.ios"
    private let accessGroup: String? = nil // Set if using app groups
    
    // MARK: - Token Types
    enum TokenType: String {
        case accessToken = "access_token"
        case refreshToken = "refresh_token"
        case idToken = "id_token"
        
        var account: String {
            return "gymapi_\(self.rawValue)"
        }
    }
    
    // MARK: - Error Types
    enum KeychainError: LocalizedError {
        case itemNotFound
        case duplicateItem
        case invalidData
        case unhandledError(status: OSStatus)
        
        var errorDescription: String? {
            switch self {
            case .itemNotFound:
                return "Token not found in keychain"
            case .duplicateItem:
                return "Token already exists in keychain"
            case .invalidData:
                return "Invalid token data"
            case .unhandledError(let status):
                return "Keychain error: \(status)"
            }
        }
    }
    
    // MARK: - Public Methods
    
    /// Save a token to the keychain
    /// - Parameters:
    ///   - token: The token string to save
    ///   - type: The type of token (access, refresh, or id)
    /// - Returns: Success status
    @discardableResult
    func saveToken(_ token: String, type: TokenType) -> Bool {
        guard let tokenData = token.data(using: .utf8) else {
            print("❌ KeychainService: Failed to convert token to data")
            return false
        }
        
        // First, try to delete any existing token
        deleteToken(type: type)
        
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceName,
            kSecAttrAccount as String: type.account,
            kSecValueData as String: tokenData,
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        ]
        
        if let accessGroup = accessGroup {
            var mutableQuery = query
            mutableQuery[kSecAttrAccessGroup as String] = accessGroup
        }
        
        let status = SecItemAdd(query as CFDictionary, nil)
        
        switch status {
        case errSecSuccess:
            print("✅ KeychainService: Saved \(type.rawValue) successfully")
            return true
        case errSecDuplicateItem:
            print("⚠️ KeychainService: \(type.rawValue) already exists, updating...")
            return updateToken(token, type: type)
        default:
            print("❌ KeychainService: Failed to save \(type.rawValue) - Status: \(status)")
            return false
        }
    }
    
    /// Retrieve a token from the keychain
    /// - Parameter type: The type of token to retrieve
    /// - Returns: The token string if found, nil otherwise
    func getToken(type: TokenType) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceName,
            kSecAttrAccount as String: type.account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        
        if let accessGroup = accessGroup {
            var mutableQuery = query
            mutableQuery[kSecAttrAccessGroup as String] = accessGroup
        }
        
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        
        switch status {
        case errSecSuccess:
            if let data = result as? Data,
               let token = String(data: data, encoding: .utf8) {
                print("✅ KeychainService: Retrieved \(type.rawValue)")
                return token
            }
            print("❌ KeychainService: Failed to decode \(type.rawValue)")
            return nil
        case errSecItemNotFound:
            print("⚠️ KeychainService: \(type.rawValue) not found")
            return nil
        default:
            print("❌ KeychainService: Failed to retrieve \(type.rawValue) - Status: \(status)")
            return nil
        }
    }
    
    /// Update an existing token in the keychain
    /// - Parameters:
    ///   - token: The new token string
    ///   - type: The type of token to update
    /// - Returns: Success status
    @discardableResult
    func updateToken(_ token: String, type: TokenType) -> Bool {
        guard let tokenData = token.data(using: .utf8) else {
            print("❌ KeychainService: Failed to convert token to data")
            return false
        }
        
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceName,
            kSecAttrAccount as String: type.account
        ]
        
        if let accessGroup = accessGroup {
            var mutableQuery = query
            mutableQuery[kSecAttrAccessGroup as String] = accessGroup
        }
        
        let attributes: [String: Any] = [
            kSecValueData as String: tokenData
        ]
        
        let status = SecItemUpdate(query as CFDictionary, attributes as CFDictionary)
        
        switch status {
        case errSecSuccess:
            print("✅ KeychainService: Updated \(type.rawValue) successfully")
            return true
        case errSecItemNotFound:
            print("⚠️ KeychainService: \(type.rawValue) not found, saving new...")
            return saveToken(token, type: type)
        default:
            print("❌ KeychainService: Failed to update \(type.rawValue) - Status: \(status)")
            return false
        }
    }
    
    /// Delete a token from the keychain
    /// - Parameter type: The type of token to delete
    /// - Returns: Success status
    @discardableResult
    func deleteToken(type: TokenType) -> Bool {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceName,
            kSecAttrAccount as String: type.account
        ]
        
        if let accessGroup = accessGroup {
            var mutableQuery = query
            mutableQuery[kSecAttrAccessGroup as String] = accessGroup
        }
        
        let status = SecItemDelete(query as CFDictionary)
        
        switch status {
        case errSecSuccess:
            print("✅ KeychainService: Deleted \(type.rawValue)")
            return true
        case errSecItemNotFound:
            print("⚠️ KeychainService: \(type.rawValue) not found (already deleted)")
            return true
        default:
            print("❌ KeychainService: Failed to delete \(type.rawValue) - Status: \(status)")
            return false
        }
    }
    
    /// Delete all tokens from the keychain
    func deleteAllTokens() {
        print("🧹 KeychainService: Deleting all tokens...")
        deleteToken(type: .accessToken)
        deleteToken(type: .refreshToken)
        deleteToken(type: .idToken)
        print("✅ KeychainService: All tokens deleted")
    }
    
    // MARK: - Migration from UserDefaults
    
    /// Migrate existing tokens from UserDefaults to Keychain
    /// This method should be called once during app update
    func migrateFromUserDefaults() {
        print("🔄 KeychainService: Starting migration from UserDefaults...")
        
        var migrationCount = 0
        
        // Migrate access token
        if let accessToken = UserDefaults.standard.string(forKey: "auth0_access_token") {
            if saveToken(accessToken, type: .accessToken) {
                UserDefaults.standard.removeObject(forKey: "auth0_access_token")
                migrationCount += 1
                print("✅ Migrated access token")
            }
        }
        
        // Migrate refresh token
        if let refreshToken = UserDefaults.standard.string(forKey: "auth0_refresh_token") {
            if saveToken(refreshToken, type: .refreshToken) {
                UserDefaults.standard.removeObject(forKey: "auth0_refresh_token")
                migrationCount += 1
                print("✅ Migrated refresh token")
            }
        }
        
        // Migrate ID token
        if let idToken = UserDefaults.standard.string(forKey: "auth0_id_token") {
            if saveToken(idToken, type: .idToken) {
                UserDefaults.standard.removeObject(forKey: "auth0_id_token")
                migrationCount += 1
                print("✅ Migrated ID token")
            }
        }
        
        if migrationCount > 0 {
            print("✅ KeychainService: Migration complete. Migrated \(migrationCount) tokens")
            
            // Mark migration as complete
            UserDefaults.standard.set(true, forKey: "keychain_migration_completed")
        } else {
            print("ℹ️ KeychainService: No tokens to migrate")
        }
    }
    
    /// Check if migration has been completed
    var hasMigratedToKeychain: Bool {
        return UserDefaults.standard.bool(forKey: "keychain_migration_completed")
    }
    
    // MARK: - Debugging (Only for DEBUG builds)
    
    #if DEBUG
    /// Print all stored tokens (for debugging only)
    func debugPrintTokens() {
        print("\n📱 KeychainService Debug Info:")
        print("================================")
        
        for tokenType in [TokenType.accessToken, .refreshToken, .idToken] {
            if let token = getToken(type: tokenType) {
                let preview = String(token.prefix(20)) + "..."
                print("• \(tokenType.rawValue): \(preview)")
            } else {
                print("• \(tokenType.rawValue): Not found")
            }
        }
        
        print("================================\n")
    }
    #endif
}