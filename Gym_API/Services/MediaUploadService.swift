//
//  MediaUploadService.swift
//  Gym_API
//
//  Created by Assistant on 7/24/25.
//
//  Servicio para manejar la subida de multimedia a Stream.io

import Foundation
import UIKit
import StreamChat
import PhotosUI
import AVFoundation

// MARK: - Media Upload Service
@MainActor
class MediaUploadService: ObservableObject {
    static let shared = MediaUploadService()
    
    @Published var isUploading = false
    @Published var uploadProgress: Double = 0.0
    @Published var errorMessage: String?
    
    private init() {}
    
    // MARK: - Upload Image
    
    /// Sube una imagen a Stream CDN
    func uploadImage(_ image: UIImage, compressionQuality: CGFloat = 0.7) async throws -> URL {
        guard let imageData = image.jpegData(compressionQuality: compressionQuality) else {
            throw MediaError.compressionFailed
        }
        
        isUploading = true
        uploadProgress = 0.0
        errorMessage = nil
        
        defer {
            isUploading = false
            uploadProgress = 0.0
        }
        
        // Simular progreso inicial
        uploadProgress = 0.1
        
        // Stream maneja la subida internamente cuando adjuntas archivos
        // Por ahora, guardamos temporalmente y devolvemos una URL local
        let fileName = "\(UUID().uuidString).jpg"
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(fileName)
        
        do {
            try imageData.write(to: tempURL)
            uploadProgress = 1.0
            return tempURL
        } catch {
            errorMessage = "Error guardando imagen: \(error.localizedDescription)"
            throw MediaError.saveFailed
        }
    }
    
    // MARK: - Process Video
    
    /// Procesa y comprime un video para subida
    func processVideo(from url: URL) async throws -> URL {
        isUploading = true
        uploadProgress = 0.0
        errorMessage = nil
        
        defer {
            isUploading = false
            uploadProgress = 0.0
        }
        
        // Por ahora solo copiamos el video
        // En producción: comprimir con AVAssetExportSession
        let fileName = "\(UUID().uuidString).mp4"
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(fileName)
        
        do {
            try FileManager.default.copyItem(at: url, to: tempURL)
            uploadProgress = 1.0
            return tempURL
        } catch {
            errorMessage = "Error procesando video: \(error.localizedDescription)"
            throw MediaError.processingFailed
        }
    }
    
    // MARK: - Validate Media
    
    /// Valida el tamaño y tipo de archivo
    func validateMedia(at url: URL) throws {
        let fileSize = try FileManager.default.attributesOfItem(atPath: url.path)[.size] as? Int64 ?? 0
        let maxSize: Int64 = 50 * 1024 * 1024 // 50MB
        
        if fileSize > maxSize {
            throw MediaError.fileTooLarge(maxSize: maxSize)
        }
        
        // Validar tipo de archivo
        let allowedTypes = ["jpg", "jpeg", "png", "gif", "mp4", "mov"]
        let fileExtension = url.pathExtension.lowercased()
        
        if !allowedTypes.contains(fileExtension) {
            throw MediaError.unsupportedType(type: fileExtension)
        }
    }
    
    // MARK: - Generate Thumbnail
    
    /// Genera un thumbnail para videos
    func generateVideoThumbnail(from url: URL) async -> UIImage? {
        return await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .background).async {
                let asset = AVAsset(url: url)
                let imageGenerator = AVAssetImageGenerator(asset: asset)
                imageGenerator.appliesPreferredTrackTransform = true
                
                let time = CMTime(seconds: 1, preferredTimescale: 1)
                
                do {
                    let cgImage = try imageGenerator.copyCGImage(at: time, actualTime: nil)
                    let thumbnail = UIImage(cgImage: cgImage)
                    continuation.resume(returning: thumbnail)
                } catch {
                    print("Error generando thumbnail: \(error)")
                    continuation.resume(returning: nil)
                }
            }
        }
    }
}

// MARK: - Media Errors
enum MediaError: LocalizedError {
    case compressionFailed
    case saveFailed
    case processingFailed
    case fileTooLarge(maxSize: Int64)
    case unsupportedType(type: String)
    case uploadFailed(reason: String)
    
    var errorDescription: String? {
        switch self {
        case .compressionFailed:
            return "No se pudo comprimir la imagen"
        case .saveFailed:
            return "No se pudo guardar el archivo"
        case .processingFailed:
            return "Error procesando el archivo"
        case .fileTooLarge(let maxSize):
            let maxSizeMB = maxSize / (1024 * 1024)
            return "El archivo es muy grande. Máximo: \(maxSizeMB)MB"
        case .unsupportedType(let type):
            return "Tipo de archivo no soportado: .\(type)"
        case .uploadFailed(let reason):
            return "Error subiendo archivo: \(reason)"
        }
    }
}

// MARK: - Media Type
enum MediaType {
    case image(UIImage)
    case video(URL, thumbnail: UIImage?)
    case voice(URL, duration: TimeInterval)
    
    var displayName: String {
        switch self {
        case .image:
            return "Imagen"
        case .video:
            return "Video"
        case .voice(_, let duration):
            let minutes = Int(duration) / 60
            let seconds = Int(duration) % 60
            return String(format: "Audio %d:%02d", minutes, seconds)
        }
    }
    
    var icon: String {
        switch self {
        case .image:
            return "photo"
        case .video:
            return "video"
        case .voice:
            return "mic"
        }
    }
}