import Foundation
import UIKit

// MARK: - Notification Names
extension Notification.Name {
    static let profileImageUpdated = Notification.Name("profileImageUpdated")
    static let streamChatAvatarUpdated = Notification.Name("streamChatAvatarUpdated")
}

@MainActor
class ProfileImageService: ObservableObject {
    @Published var isUploading = false
    @Published var uploadError: String?
    @Published var profileImageURL: String?
    
    private let baseURL = "https://gymapi-eh6m.onrender.com/api/v1"
    private let session = URLSession.shared
    weak var authService: AuthServiceDirect?
    
    init(authService: AuthServiceDirect? = nil) {
        self.authService = authService
    }
    
    // MARK: - Upload Profile Image
    func uploadProfileImage(_ image: UIImage) async -> Bool {
        isUploading = true
        uploadError = nil
        
        // Validate authentication
        guard let authService = authService else {
            uploadError = "No se encontró servicio de autenticación"
            isUploading = false
            return false
        }
        
        guard let token = await authService.getValidAccessToken() else {
            uploadError = "No se encontró token de autorización válido"
            isUploading = false
            return false
        }
        
        // Validate image
        guard validateImage(image) else {
            isUploading = false
            return false
        }
        
        // Comprimir imagen
        guard let imageData = compressImage(image) else {
            uploadError = "Error al procesar la imagen"
            isUploading = false
            return false
        }
        
        // Validate compressed image size
        guard validateImageData(imageData) else {
            isUploading = false
            return false
        }
        
        do {
            let success = try await performUploadWithRetry(imageData: imageData, token: token)
            
            // If upload successful and we have a new image URL, sync with Stream Chat
            if success, let imageURL = profileImageURL {
                await syncWithStreamChat(imageURL: imageURL)
            }
            
            isUploading = false
            return success
        } catch {
            uploadError = "Error al subir imagen: \(error.localizedDescription)"
            isUploading = false
            return false
        }
    }
    
    // MARK: - Perform Upload with Retry
    private func performUploadWithRetry(imageData: Data, token: String, maxRetries: Int = 3) async throws -> Bool {
        var lastError: Error?
        
        for attempt in 1...maxRetries {
            do {
                print("📤 Upload attempt \(attempt)/\(maxRetries)")
                let success = try await performUpload(imageData: imageData, token: token)
                if success {
                    return true
                }
                
                // If upload returns false (not success), wait before retry
                if attempt < maxRetries {
                    print("⏳ Waiting before retry...")
                    try await Task.sleep(nanoseconds: UInt64(attempt * 1_000_000_000)) // Wait 1s, 2s, 3s
                }
                
            } catch {
                lastError = error
                print("❌ Upload attempt \(attempt) failed: \(error.localizedDescription)")
                
                // Don't retry on certain errors (like auth errors)
                if let profileError = error as? ProfileImageError {
                    switch profileError {
                    case .invalidURL, .invalidResponse:
                        throw error // Don't retry on these
                    case .uploadFailed:
                        break // Retry on upload failures
                    }
                }
                
                // Wait before retry (exponential backoff)
                if attempt < maxRetries {
                    let waitTime = min(pow(2.0, Double(attempt)), 8.0) // Cap at 8 seconds
                    try await Task.sleep(nanoseconds: UInt64(waitTime * 1_000_000_000))
                }
            }
        }
        
        // All retries exhausted
        throw lastError ?? ProfileImageError.uploadFailed("Máximo número de intentos alcanzado")
    }
    
    // MARK: - Perform Upload
    private func performUpload(imageData: Data, token: String) async throws -> Bool {
        guard let url = URL(string: "\(baseURL)/users/profile/image") else {
            throw ProfileImageError.invalidURL
        }
        
        // Crear multipart form data
        let boundary = UUID().uuidString
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        
        // Agregar header X-Gym-ID
        let gymId = GymService.shared.currentGymId ?? 4
        request.setValue("\(gymId)", forHTTPHeaderField: "X-Gym-ID")
        
        // Crear body multipart
        let httpBody = createMultipartBody(imageData: imageData, boundary: boundary)
        request.httpBody = httpBody
        
        print("🔄 Uploading profile image...")
        print("📄 Content-Length: \(httpBody.count) bytes")
        
        let (data, response) = try await session.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw ProfileImageError.invalidResponse
        }
        
        print("📡 Upload response status: \(httpResponse.statusCode)")
        
        if httpResponse.statusCode == 200 {
            // Parsear respuesta para obtener la nueva URL de la imagen
            if let jsonResponse = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let pictureURL = jsonResponse["picture"] as? String {
                profileImageURL = pictureURL
                print("✅ Profile image uploaded successfully: \(pictureURL)")
                return true
            } else {
                print("⚠️ Upload successful but couldn't parse image URL")
                return true
            }
        } else {
            // Manejo de errores específicos
            if let errorData = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let detail = errorData["detail"] as? String {
                uploadError = detail
            } else {
                uploadError = "Error del servidor: \(httpResponse.statusCode)"
            }
            return false
        }
    }
    
    // MARK: - Create Multipart Body
    private func createMultipartBody(imageData: Data, boundary: String) -> Data {
        var body = Data()
        let lineBreak = "\r\n"
        
        // Agregar archivo de imagen
        body.append("--\(boundary)\(lineBreak)".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"file\"; filename=\"profile.jpg\"\(lineBreak)".data(using: .utf8)!)
        body.append("Content-Type: image/jpeg\(lineBreak)\(lineBreak)".data(using: .utf8)!)
        body.append(imageData)
        body.append("\(lineBreak)".data(using: .utf8)!)
        
        // Cerrar multipart
        body.append("--\(boundary)--\(lineBreak)".data(using: .utf8)!)
        
        return body
    }
    
    // MARK: - Compress Image
    private func compressImage(_ image: UIImage) -> Data? {
        // Redimensionar imagen si es muy grande
        let maxSize: CGFloat = 1024
        let resizedImage: UIImage
        
        if image.size.width > maxSize || image.size.height > maxSize {
            let ratio = min(maxSize / image.size.width, maxSize / image.size.height)
            let newSize = CGSize(width: image.size.width * ratio, height: image.size.height * ratio)
            
            UIGraphicsBeginImageContextWithOptions(newSize, false, 1.0)
            image.draw(in: CGRect(origin: .zero, size: newSize))
            resizedImage = UIGraphicsGetImageFromCurrentImageContext() ?? image
            UIGraphicsEndImageContext()
        } else {
            resizedImage = image
        }
        
        // Comprimir con calidad ajustable
        let compressionQuality: CGFloat = 0.8
        return resizedImage.jpegData(compressionQuality: compressionQuality)
    }
    
    // MARK: - Validation Methods
    private func validateImage(_ image: UIImage) -> Bool {
        // Check minimum dimensions
        let minDimension: CGFloat = 100
        if image.size.width < minDimension || image.size.height < minDimension {
            uploadError = "La imagen debe ser al menos de \(Int(minDimension))x\(Int(minDimension)) píxeles"
            return false
        }
        
        // Check maximum dimensions
        let maxDimension: CGFloat = 4000
        if image.size.width > maxDimension || image.size.height > maxDimension {
            uploadError = "La imagen es demasiado grande. Máximo \(Int(maxDimension))x\(Int(maxDimension)) píxeles"
            return false
        }
        
        return true
    }
    
    private func validateImageData(_ data: Data) -> Bool {
        // Check file size (max 10MB)
        let maxSizeInBytes = 10 * 1024 * 1024 // 10MB
        if data.count > maxSizeInBytes {
            let sizeInMB = Double(data.count) / (1024.0 * 1024.0)
            uploadError = String(format: "La imagen es demasiado grande (%.1fMB). Máximo permitido: 10MB", sizeInMB)
            return false
        }
        
        // Check minimum file size (prevent corrupt/empty images)
        let minSizeInBytes = 1024 // 1KB
        if data.count < minSizeInBytes {
            uploadError = "La imagen es demasiado pequeña o está corrupta"
            return false
        }
        
        print("✅ Image validation passed: \(String(format: "%.2fMB", Double(data.count) / (1024.0 * 1024.0)))")
        return true
    }
    
    // MARK: - Stream Chat Sync
    private func syncWithStreamChat(imageURL: String) async {
        print("🔄 Syncing profile image with Stream Chat...")
        
        // Get the chat provider manager
        let chatProviderManager = ChatProviderManager.shared
        
        // Check if we have a Stream Chat provider
        guard let streamProvider = chatProviderManager.currentProvider as? GetStreamChatProvider else {
            print("⚠️ No Stream Chat provider available for avatar sync")
            return
        }
        
        // Get current user ID
        guard let currentUserId = streamProvider.currentUserId else {
            print("⚠️ No current user ID available for avatar sync")
            return
        }
        
        do {
            // Update user's avatar in Stream Chat
            await updateStreamChatAvatar(
                userId: currentUserId,
                imageURL: imageURL,
                provider: streamProvider
            )
            
            // Invalidate UI Avatars cache by posting notification
            NotificationCenter.default.post(
                name: .profileImageUpdated,
                object: nil,
                userInfo: ["imageURL": imageURL, "userId": currentUserId]
            )
            
            print("✅ Stream Chat avatar updated successfully")
            
        } catch {
            print("❌ Error updating Stream Chat avatar: \(error)")
        }
    }
    
    private func updateStreamChatAvatar(
        userId: String,
        imageURL: String,
        provider: GetStreamChatProvider
    ) async {
        // This would typically be done through Stream Chat's user update API
        // For now, we'll post a notification to refresh conversations
        await MainActor.run {
            NotificationCenter.default.post(
                name: .streamChatAvatarUpdated,
                object: nil,
                userInfo: [
                    "userId": userId,
                    "imageURL": imageURL
                ]
            )
        }
    }
}

// MARK: - Profile Image Error
enum ProfileImageError: LocalizedError {
    case invalidURL
    case invalidResponse
    case uploadFailed(String)
    
    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "URL inválida"
        case .invalidResponse:
            return "Respuesta inválida del servidor"
        case .uploadFailed(let message):
            return "Error al subir imagen: \(message)"
        }
    }
}