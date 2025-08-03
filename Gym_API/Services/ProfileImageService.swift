import Foundation
import UIKit

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
        
        // Comprimir imagen
        guard let imageData = compressImage(image) else {
            uploadError = "Error al procesar la imagen"
            isUploading = false
            return false
        }
        
        do {
            let success = try await performUpload(imageData: imageData, token: token)
            isUploading = false
            return success
        } catch {
            uploadError = "Error al subir imagen: \(error.localizedDescription)"
            isUploading = false
            return false
        }
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