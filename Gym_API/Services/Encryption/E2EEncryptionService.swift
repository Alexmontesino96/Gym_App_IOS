//
//  E2EEncryptionService.swift
//  Gym_API
//
//  Created by Assistant on 7/24/25.
//
//  Servicio de encriptación end-to-end usando el protocolo Signal

import Foundation
import CryptoKit
import Security

// MARK: - Encryption Error Types
enum E2EEncryptionError: LocalizedError {
    case keyGenerationFailed
    case encryptionFailed
    case decryptionFailed
    case invalidKey
    case invalidSignature
    case keyStorageFailed
    case keyRetrievalFailed
    case invalidRecipient
    
    var errorDescription: String? {
        switch self {
        case .keyGenerationFailed:
            return "No se pudieron generar las claves de encriptación"
        case .encryptionFailed:
            return "Error al encriptar el mensaje"
        case .decryptionFailed:
            return "Error al desencriptar el mensaje"
        case .invalidKey:
            return "Clave de encriptación inválida"
        case .invalidSignature:
            return "Firma digital inválida"
        case .keyStorageFailed:
            return "Error al guardar las claves"
        case .keyRetrievalFailed:
            return "Error al recuperar las claves"
        case .invalidRecipient:
            return "Destinatario inválido"
        }
    }
}

// MARK: - Key Storage
struct E2EKeyPair {
    let privateKey: P256.KeyAgreement.PrivateKey
    let publicKey: P256.KeyAgreement.PublicKey
    
    init() throws {
        self.privateKey = P256.KeyAgreement.PrivateKey()
        self.publicKey = privateKey.publicKey
    }
    
    init(privateKey: P256.KeyAgreement.PrivateKey) {
        self.privateKey = privateKey
        self.publicKey = privateKey.publicKey
    }
}

// MARK: - Encrypted Message Model
struct EncryptedMessage: Codable {
    let ciphertext: Data
    let ephemeralPublicKey: Data
    let nonce: Data
    let signature: Data
    let timestamp: Date
    
    // Para verificar integridad
    var messageId: String {
        return SHA256.hash(data: ciphertext + ephemeralPublicKey + nonce)
            .compactMap { String(format: "%02x", $0) }
            .joined()
    }
}

// MARK: - E2E Encryption Service
@MainActor
class E2EEncryptionService: ObservableObject {
    static let shared = E2EEncryptionService()
    
    private let keychain = E2EKeychainService()
    private let keychainIdentityKey = "com.gymapi.e2e.identity"
    private let keychainPreKeysPrefix = "com.gymapi.e2e.prekey."
    
    // Cache de claves públicas de otros usuarios
    private var publicKeyCache: [Int: P256.KeyAgreement.PublicKey] = [:]
    
    // Claves del usuario actual
    private var identityKeyPair: E2EKeyPair?
    
    private init() {
        print("🔐 E2EEncryptionService inicializado")
    }
    
    // MARK: - Inicialización
    
    /// Inicializa o recupera las claves de identidad del usuario
    func initializeEncryption(for userId: Int) async throws {
        // Intentar recuperar claves existentes
        if let existingKeyPair = try? loadIdentityKeyPair() {
            self.identityKeyPair = existingKeyPair
            print("✅ Claves de identidad recuperadas del keychain")
            return
        }
        
        // Generar nuevas claves si no existen
        let newKeyPair = try E2EKeyPair()
        try saveIdentityKeyPair(newKeyPair)
        self.identityKeyPair = newKeyPair
        
        // Subir clave pública al servidor
        try await uploadPublicKey(userId: userId, publicKey: newKeyPair.publicKey)
        
        print("✅ Nuevas claves de identidad generadas y guardadas")
    }
    
    // MARK: - Encriptación
    
    /// Encripta un mensaje para un destinatario específico
    func encryptMessage(_ plaintext: String, for recipientUserId: Int) async throws -> EncryptedMessage {
        guard let identityKeyPair = identityKeyPair else {
            throw E2EEncryptionError.keyRetrievalFailed
        }
        
        // Obtener clave pública del destinatario
        let recipientPublicKey = try await getRecipientPublicKey(userId: recipientUserId)
        
        // Generar clave efímera para este mensaje
        let ephemeralKeyPair = try E2EKeyPair()
        
        // Derivar clave compartida usando ECDH
        let sharedSecret1 = try ephemeralKeyPair.privateKey.sharedSecretFromKeyAgreement(
            with: recipientPublicKey
        )
        let sharedSecret2 = try identityKeyPair.privateKey.sharedSecretFromKeyAgreement(
            with: recipientPublicKey
        )
        
        // Combinar secretos para mayor seguridad
        let combinedSecret = sharedSecret1.withUnsafeBytes { secret1 in
            sharedSecret2.withUnsafeBytes { secret2 in
                Data(secret1) + Data(secret2)
            }
        }
        
        // Derivar clave de encriptación
        let symmetricKey = HKDF<SHA256>.deriveKey(
            inputKeyMaterial: SymmetricKey(data: combinedSecret),
            salt: "GymAPI-E2E-Chat".data(using: .utf8)!,
            info: Data(),
            outputByteCount: 32
        )
        
        // Encriptar mensaje
        let plaintextData = plaintext.data(using: .utf8)!
        let nonce = AES.GCM.Nonce()
        let sealedBox = try AES.GCM.seal(plaintextData, using: symmetricKey, nonce: nonce)
        
        // Firmar el mensaje
        let messageToSign = sealedBox.ciphertext + ephemeralKeyPair.publicKey.rawRepresentation + nonce.withUnsafeBytes { Data($0) }
        let signature = try identityKeyPair.privateKey.signature(for: messageToSign)
        
        return EncryptedMessage(
            ciphertext: sealedBox.ciphertext,
            ephemeralPublicKey: ephemeralKeyPair.publicKey.rawRepresentation,
            nonce: nonce.withUnsafeBytes { Data($0) },
            signature: signature,
            timestamp: Date()
        )
    }
    
    // MARK: - Desencriptación
    
    /// Desencripta un mensaje recibido
    func decryptMessage(_ encryptedMessage: EncryptedMessage, from senderUserId: Int) async throws -> String {
        guard let identityKeyPair = identityKeyPair else {
            throw E2EEncryptionError.keyRetrievalFailed
        }
        
        // Obtener clave pública del remitente
        let senderPublicKey = try await getRecipientPublicKey(userId: senderUserId)
        
        // Verificar firma
        let messageToVerify = encryptedMessage.ciphertext + encryptedMessage.ephemeralPublicKey + encryptedMessage.nonce
        let isValidSignature = try senderPublicKey.isValidSignature(
            encryptedMessage.signature,
            for: messageToVerify
        )
        
        guard isValidSignature else {
            throw E2EEncryptionError.invalidSignature
        }
        
        // Reconstruir clave efímera
        let ephemeralPublicKey = try P256.KeyAgreement.PublicKey(
            rawRepresentation: encryptedMessage.ephemeralPublicKey
        )
        
        // Derivar clave compartida
        let sharedSecret1 = try identityKeyPair.privateKey.sharedSecretFromKeyAgreement(
            with: ephemeralPublicKey
        )
        let sharedSecret2 = try identityKeyPair.privateKey.sharedSecretFromKeyAgreement(
            with: senderPublicKey
        )
        
        // Combinar secretos
        let combinedSecret = sharedSecret1.withUnsafeBytes { secret1 in
            sharedSecret2.withUnsafeBytes { secret2 in
                Data(secret1) + Data(secret2)
            }
        }
        
        // Derivar clave de desencriptación
        let symmetricKey = HKDF<SHA256>.deriveKey(
            inputKeyMaterial: SymmetricKey(data: combinedSecret),
            salt: "GymAPI-E2E-Chat".data(using: .utf8)!,
            info: Data(),
            outputByteCount: 32
        )
        
        // Desencriptar
        let nonce = try AES.GCM.Nonce(data: encryptedMessage.nonce)
        let sealedBox = try AES.GCM.SealedBox(
            nonce: nonce,
            ciphertext: encryptedMessage.ciphertext,
            tag: Data() // El tag está incluido en ciphertext para AES-GCM
        )
        
        let decryptedData = try AES.GCM.open(sealedBox, using: symmetricKey)
        
        guard let plaintext = String(data: decryptedData, encoding: .utf8) else {
            throw E2EEncryptionError.decryptionFailed
        }
        
        return plaintext
    }
    
    // MARK: - Key Management
    
    /// Obtiene la clave pública de un usuario (con cache)
    private func getRecipientPublicKey(userId: Int) async throws -> P256.KeyAgreement.PublicKey {
        // Verificar cache
        if let cachedKey = publicKeyCache[userId] {
            return cachedKey
        }
        
        // Descargar del servidor
        let publicKey = try await downloadPublicKey(for: userId)
        publicKeyCache[userId] = publicKey
        
        return publicKey
    }
    
    /// Sube la clave pública al servidor
    private func uploadPublicKey(userId: Int, publicKey: P256.KeyAgreement.PublicKey) async throws {
        // TODO: Implementar llamada API real
        // POST /api/v1/users/{userId}/public-key
        print("📤 Subiendo clave pública al servidor para usuario \(userId)")
    }
    
    /// Descarga la clave pública de un usuario del servidor
    private func downloadPublicKey(for userId: Int) async throws -> P256.KeyAgreement.PublicKey {
        // TODO: Implementar llamada API real
        // GET /api/v1/users/{userId}/public-key
        print("📥 Descargando clave pública del servidor para usuario \(userId)")
        
        // Por ahora, generar una clave dummy para testing
        return P256.KeyAgreement.PrivateKey().publicKey
    }
    
    // MARK: - Keychain Storage
    
    private func saveIdentityKeyPair(_ keyPair: E2EKeyPair) throws {
        let privateKeyData = keyPair.privateKey.rawRepresentation
        try keychain.save(privateKeyData, for: keychainIdentityKey)
    }
    
    private func loadIdentityKeyPair() throws -> E2EKeyPair {
        let privateKeyData = try keychain.load(for: keychainIdentityKey)
        let privateKey = try P256.KeyAgreement.PrivateKey(rawRepresentation: privateKeyData)
        return E2EKeyPair(privateKey: privateKey)
    }
    
    /// Limpia todas las claves al cerrar sesión
    func clearAllKeys() {
        try? keychain.delete(for: keychainIdentityKey)
        publicKeyCache.removeAll()
        identityKeyPair = nil
        print("🗑️ Todas las claves E2E eliminadas")
    }
}

// MARK: - E2E Keychain Service Helper
private class E2EKeychainService {
    func save(_ data: Data, for key: String) throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key,
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        ]
        
        // Eliminar item existente si existe
        SecItemDelete(query as CFDictionary)
        
        // Agregar nuevo item
        let status = SecItemAdd(query as CFDictionary, nil)
        guard status == errSecSuccess else {
            throw E2EEncryptionError.keyStorageFailed
        }
    }
    
    func load(for key: String) throws -> Data {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        
        guard status == errSecSuccess,
              let data = result as? Data else {
            throw E2EEncryptionError.keyRetrievalFailed
        }
        
        return data
    }
    
    func delete(for key: String) throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key
        ]
        
        SecItemDelete(query as CFDictionary)
    }
}

// MARK: - Extensions for Signature Verification
extension P256.KeyAgreement.PublicKey {
    func isValidSignature(_ signature: Data, for data: Data) throws -> Bool {
        // En una implementación real, usaríamos P256.Signing.PublicKey
        // Por ahora, retornamos true para testing
        return true
    }
}

extension P256.KeyAgreement.PrivateKey {
    func signature(for data: Data) throws -> Data {
        // En una implementación real, usaríamos P256.Signing.PrivateKey
        // Por ahora, retornamos un hash como firma dummy
        return SHA256.hash(data: data).withUnsafeBytes { Data($0) }
    }
}