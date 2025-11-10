import Foundation
import UIKit

/// Constructor de datos multipart/form-data para subida de archivos
/// Soporta campos de texto y archivos (imágenes/videos)
final class MultipartFormDataBuilder {

    // MARK: - Properties

    private let boundary: String
    private var bodyData = Data()
    private let lineBreak = "\r\n"

    // MARK: - Initialization

    init(boundary: String? = nil) {
        self.boundary = boundary ?? "Boundary-\(UUID().uuidString)"
    }

    // MARK: - Public Methods

    /// Agrega un campo de texto al formulario
    /// - Parameters:
    ///   - name: Nombre del campo
    ///   - value: Valor del campo
    func append(name: String, value: String) {
        bodyData.append("--\(boundary)\(lineBreak)")
        bodyData.append("Content-Disposition: form-data; name=\"\(name)\"\(lineBreak)\(lineBreak)")
        bodyData.append("\(value)\(lineBreak)")
    }

    /// Agrega un campo de número al formulario
    /// - Parameters:
    ///   - name: Nombre del campo
    ///   - value: Valor numérico
    func append(name: String, value: Int) {
        append(name: name, value: String(value))
    }

    /// Agrega un array como JSON string
    /// - Parameters:
    ///   - name: Nombre del campo
    ///   - array: Array de enteros
    func append(name: String, array: [Int]) throws {
        let jsonData = try JSONSerialization.data(withJSONObject: array)
        guard let jsonString = String(data: jsonData, encoding: .utf8) else {
            throw MultipartError.invalidJSON
        }
        append(name: name, value: jsonString)
    }

    /// Agrega un archivo desde una URL local
    /// - Parameters:
    ///   - name: Nombre del campo (ej: "files")
    ///   - fileURL: URL del archivo local
    ///   - mimeType: Tipo MIME del archivo (ej: "image/jpeg", "video/mp4")
    ///   - filename: Nombre del archivo (opcional, se usa el nombre del fileURL si no se provee)
    func appendFile(name: String, fileURL: URL, mimeType: String, filename: String? = nil) throws {
        guard fileURL.isFileURL else {
            throw MultipartError.invalidFileURL
        }

        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            throw MultipartError.fileNotFound
        }

        let fileData = try Data(contentsOf: fileURL)
        let actualFilename = filename ?? fileURL.lastPathComponent

        appendFile(name: name, data: fileData, mimeType: mimeType, filename: actualFilename)
    }

    /// Agrega un archivo desde Data
    /// - Parameters:
    ///   - name: Nombre del campo
    ///   - data: Datos del archivo
    ///   - mimeType: Tipo MIME
    ///   - filename: Nombre del archivo
    func appendFile(name: String, data: Data, mimeType: String, filename: String) {
        bodyData.append("--\(boundary)\(lineBreak)")
        bodyData.append("Content-Disposition: form-data; name=\"\(name)\"; filename=\"\(filename)\"\(lineBreak)")
        bodyData.append("Content-Type: \(mimeType)\(lineBreak)\(lineBreak)")
        bodyData.append(data)
        bodyData.append(lineBreak)
    }

    /// Agrega una imagen UIImage con compresión opcional
    /// - Parameters:
    ///   - name: Nombre del campo
    ///   - image: Imagen UIImage
    ///   - filename: Nombre del archivo
    ///   - compressionQuality: Calidad de compresión JPEG (0.0 a 1.0, default: 0.8)
    func appendImage(name: String, image: UIImage, filename: String, compressionQuality: CGFloat = 0.8) throws {
        guard let imageData = image.jpegData(compressionQuality: compressionQuality) else {
            throw MultipartError.imageCompressionFailed
        }

        appendFile(name: name, data: imageData, mimeType: "image/jpeg", filename: filename)
    }

    /// Construye el cuerpo completo del formulario multipart
    /// - Returns: Tupla con los datos y el boundary usado
    func build() -> (data: Data, boundary: String) {
        var finalData = bodyData
        finalData.append("--\(boundary)--\(lineBreak)")
        return (finalData, boundary)
    }

    /// Retorna el Content-Type header completo
    var contentType: String {
        "multipart/form-data; boundary=\(boundary)"
    }

    /// Retorna el tamaño actual del body en bytes
    var bodySize: Int {
        bodyData.count
    }

    /// Retorna el tamaño formateado (KB, MB)
    var formattedSize: String {
        let bytes = Double(bodySize)
        if bytes < 1024 {
            return "\(Int(bytes)) bytes"
        } else if bytes < 1024 * 1024 {
            return String(format: "%.1f KB", bytes / 1024)
        } else {
            return String(format: "%.1f MB", bytes / (1024 * 1024))
        }
    }
}

// MARK: - Data Extension

private extension Data {
    mutating func append(_ string: String) {
        if let data = string.data(using: .utf8) {
            append(data)
        }
    }
}

// MARK: - Errors

enum MultipartError: LocalizedError {
    case invalidFileURL
    case fileNotFound
    case imageCompressionFailed
    case invalidJSON
    case fileTooLarge(maxSize: Int)
    case tooManyFiles(maxCount: Int)

    var errorDescription: String? {
        switch self {
        case .invalidFileURL:
            return "La URL del archivo no es válida"
        case .fileNotFound:
            return "El archivo no existe"
        case .imageCompressionFailed:
            return "No se pudo comprimir la imagen"
        case .invalidJSON:
            return "No se pudo serializar a JSON"
        case .fileTooLarge(let maxSize):
            return "El archivo excede el tamaño máximo de \(maxSize / 1024 / 1024) MB"
        case .tooManyFiles(let maxCount):
            return "Se excedió el límite de \(maxCount) archivos"
        }
    }
}

// MARK: - Validaciones

extension MultipartFormDataBuilder {

    /// Valida el tamaño de un archivo antes de agregarlo
    /// - Parameters:
    ///   - fileURL: URL del archivo
    ///   - maxSizeInBytes: Tamaño máximo permitido en bytes
    /// - Throws: MultipartError.fileTooLarge si excede el límite
    static func validateFileSize(fileURL: URL, maxSizeInBytes: Int) throws {
        let attributes = try FileManager.default.attributesOfItem(atPath: fileURL.path)
        let fileSize = attributes[.size] as? Int ?? 0

        if fileSize > maxSizeInBytes {
            throw MultipartError.fileTooLarge(maxSize: maxSizeInBytes)
        }
    }

    /// Valida el tipo MIME de un archivo
    /// - Parameters:
    ///   - fileURL: URL del archivo
    ///   - allowedTypes: Tipos MIME permitidos
    /// - Returns: Tipo MIME detectado
    static func detectMimeType(for fileURL: URL, allowedTypes: [String] = []) -> String? {
        let ext = fileURL.pathExtension.lowercased()

        let mimeMap: [String: String] = [
            "jpg": "image/jpeg",
            "jpeg": "image/jpeg",
            "png": "image/png",
            "gif": "image/gif",
            "webp": "image/webp",
            "mp4": "video/mp4",
            "mov": "video/quicktime",
            "avi": "video/x-msvideo"
        ]

        guard let mimeType = mimeMap[ext] else {
            return nil
        }

        if !allowedTypes.isEmpty && !allowedTypes.contains(mimeType) {
            return nil
        }

        return mimeType
    }
}
