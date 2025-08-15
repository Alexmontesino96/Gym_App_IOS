import SwiftUI
import Combine

/// Servicio para cargar imágenes con mejor manejo de errores
class ImageLoaderService: ObservableObject {
    @Published var image: UIImage?
    @Published var isLoading = false
    @Published var error: Error?
    
    private var cancellables = Set<AnyCancellable>()
    private static let memoryCache = NSCache<NSString, UIImage>()
    private static let ioQueue = DispatchQueue(label: "image-loader.disk-cache")
    
    // Cache versión para invalidar caché viejo
    private static let cacheVersion = "v2"
    
    // Configuración de caché mejorada
    static let shared = ImageLoaderService()
    
    init() {
        // Configurar límites de memoria caché
        Self.memoryCache.countLimit = 100 // máximo 100 imágenes
        Self.memoryCache.totalCostLimit = 50 * 1024 * 1024 // 50MB máximo
        
        // Limpiar caché antiguo al iniciar (versiones anteriores)
        Self.cleanOldCache()
    }
    
    func loadImage(from urlString: String, cacheKeyOverride: String? = nil) {
        guard !urlString.isEmpty else {
            print("⚠️ [ImageLoader] URL string is empty")
            return
        }
        
        let cleanedURL = cleanURL(urlString)
        let cacheKey = cacheKeyOverride ?? cleanedURL
        let versionedKey = "\(Self.cacheVersion)_\(cacheKey)"
        
        guard let url = URL(string: cleanedURL) else {
            print("❌ [ImageLoader] Invalid URL: \(cleanedURL)")
            return
        }

        // Check memory cache
        if let cached = Self.memoryCache.object(forKey: versionedKey as NSString) {
            debugLog("🧠 [ImageLoader] Memory cache hit for key: \(cacheKey)")
            self.image = cached
            return
        }

        // Check disk cache with better error handling
        if let diskImage = loadFromDisk(for: versionedKey) {
            debugLog("💾 [ImageLoader] Disk cache hit for key: \(cacheKey)")
            // Store in memory cache with cost estimation
            let cost = diskImage.size.width * diskImage.size.height * 4
            Self.memoryCache.setObject(diskImage, forKey: versionedKey as NSString, cost: Int(cost))
            self.image = diskImage
            return
        }

        isLoading = true
        error = nil
        debugLog("🌐 [ImageLoader] Fetching: \(url.absoluteString) (key: \(cacheKey))")
        loadImageDirect(from: url, cacheKey: versionedKey)
    }
    
    private func loadImageDirect(from url: URL, cacheKey: String) {
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("*/*", forHTTPHeaderField: "Accept")
        request.setValue("Mozilla/5.0 (iPhone; CPU iPhone OS 16_0 like Mac OS X) AppleWebKit/605.1.15", forHTTPHeaderField: "User-Agent")
        
        #if DEBUG
        print("🔧 [ImageLoader] Request headers: \(request.allHTTPHeaderFields ?? [:])")
        #endif
        
        URLSession.shared.dataTaskPublisher(for: request)
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { [weak self] completion in
                    self?.isLoading = false
                    switch completion {
                    case .finished:
                        break
                    case .failure(let error):
                        print("❌ [ImageLoader] Network error: \(error.localizedDescription)")
                        self?.error = error
                    }
                },
                receiveValue: { [weak self] data, response in
                    if let httpResponse = response as? HTTPURLResponse {
                        #if DEBUG
                        print("🌐 [ImageLoader] HTTP Status: \(httpResponse.statusCode)")
                        print("🌐 [ImageLoader] Content-Type: \(httpResponse.allHeaderFields["Content-Type"] ?? "unknown")")
                        print("🌐 [ImageLoader] Content-Length: \(httpResponse.allHeaderFields["Content-Length"] ?? "unknown")")
                        #endif
                        
                        if httpResponse.statusCode != 200 {
                            #if DEBUG
                            print("❌ [ImageLoader] HTTP Error: \(httpResponse.statusCode)")
                            print("🔍 [ImageLoader] Response data: \(String(data: data, encoding: .utf8) ?? "No readable data")")
                            #endif
                            
                            self?.error = ImageLoaderError.httpError(httpResponse.statusCode)
                            return
                        }
                    }
                    
                    if let image = UIImage(data: data) {
                        #if DEBUG
                        print("✅ [ImageLoader] Image loaded successfully, size: \(image.size)")
                        #endif
                        self?.image = image
                        // Cache in memory with cost and disk
                        let cost = image.size.width * image.size.height * 4
                        Self.memoryCache.setObject(image, forKey: cacheKey as NSString, cost: Int(cost))
                        self?.saveToDisk(image: image, for: cacheKey)
                    } else {
                        #if DEBUG
                        print("❌ [ImageLoader] Failed to create image from data")
                        print("🔍 [ImageLoader] Data size: \(data.count) bytes")
                        #endif
                        self?.error = ImageLoaderError.invalidImageData
                    }
                }
            )
            .store(in: &cancellables)
    }
    
    private func cleanURL(_ urlString: String) -> String {
        // Mantener la URL exacta (incluyendo querystrings) y solo recortar espacios
        return urlString.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    // MARK: - Disk Cache
    private func cacheDirectory() -> URL {
        let base = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first!
        let dir = base.appendingPathComponent("ImageCache", isDirectory: true)
        if !FileManager.default.fileExists(atPath: dir.path) {
            try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        }
        return dir
    }

    private func filename(for key: String) -> String {
        // Simple safe key: base64 of URL, replacing non-filesystem chars
        let data = key.data(using: .utf8) ?? Data()
        var b64 = data.base64EncodedString()
        b64 = b64.replacingOccurrences(of: "/", with: "_")
                 .replacingOccurrences(of: "+", with: "-")
                 .replacingOccurrences(of: "=", with: "")
        return b64 + ".img"
    }

    private func fileURL(for key: String) -> URL {
        cacheDirectory().appendingPathComponent(filename(for: key))
    }

    private func loadFromDisk(for key: String) -> UIImage? {
        let url = fileURL(for: key)
        guard FileManager.default.fileExists(atPath: url.path) else { 
            debugLog("💾 [ImageLoader] No disk cache for key: \(key)")
            return nil 
        }
        
        do {
            let data = try Data(contentsOf: url)
            if let img = UIImage(data: data) {
                debugLog("💾 [ImageLoader] Successfully loaded from disk: \(key)")
                return img
            } else {
                debugLog("⚠️ [ImageLoader] Corrupted cache file for key: \(key)")
                // Eliminar archivo corrupto
                try? FileManager.default.removeItem(at: url)
            }
        } catch {
            debugLog("❌ [ImageLoader] Error loading from disk: \(error)")
        }
        return nil
    }

    private func saveToDisk(image: UIImage, for key: String) {
        let url = fileURL(for: key)
        Self.ioQueue.async {
            // Save as JPEG (smaller) if possible, else PNG
            if let data = image.jpegData(compressionQuality: 0.9) ?? image.pngData() {
                do {
                    try data.write(to: url, options: [.atomic])
                    debugLog("💾 [ImageLoader] Saved to disk: \(key)")
                } catch {
                    debugLog("❌ [ImageLoader] Failed to save to disk: \(error)")
                }
            }
        }
    }
    
    // Método para limpiar caché antiguo
    private static func cleanOldCache() {
        ioQueue.async {
            let fm = FileManager.default
            let base = fm.urls(for: .cachesDirectory, in: .userDomainMask).first!
            let dir = base.appendingPathComponent("ImageCache", isDirectory: true)
            
            guard fm.fileExists(atPath: dir.path) else { return }
            
            do {
                let files = try fm.contentsOfDirectory(at: dir, includingPropertiesForKeys: [.creationDateKey])
                let now = Date()
                
                for file in files {
                    // Eliminar archivos más antiguos de 7 días o que no contengan la versión actual
                    let filename = file.lastPathComponent
                    if !filename.hasPrefix(cacheVersion + "_") {
                        try? fm.removeItem(at: file)
                        debugLog("🗑️ [ImageLoader] Removed old cache file: \(filename)")
                    } else if let attrs = try? fm.attributesOfItem(atPath: file.path),
                              let creationDate = attrs[.creationDate] as? Date,
                              now.timeIntervalSince(creationDate) > 7 * 24 * 60 * 60 {
                        try? fm.removeItem(at: file)
                        debugLog("🗑️ [ImageLoader] Removed expired cache file: \(filename)")
                    }
                }
            } catch {
                debugLog("❌ [ImageLoader] Error cleaning old cache: \(error)")
            }
        }
    }
    
    // Método público para precargar imágenes
    static func preloadImages(urls: [(url: String, cacheKey: String?)]) {
        for item in urls {
            let loader = ImageLoaderService()
            loader.loadImage(from: item.url, cacheKeyOverride: item.cacheKey)
        }
    }
}

enum ImageLoaderError: Error, LocalizedError {
    case invalidImageData
    case httpError(Int)
    
    var errorDescription: String? {
        switch self {
        case .invalidImageData:
            return "Could not create image from data"
        case .httpError(let statusCode):
            return "HTTP error: \(statusCode)"
        }
    }
}

/// Vista personalizada para mostrar imágenes cargadas con ImageLoaderService
struct CustomImageView: View {
    let url: String
    let cacheKey: String?
    let size: CGFloat
    let placeholder: AnyView
    
    @StateObject private var imageLoader = ImageLoaderService()
    
    init(url: String, cacheKey: String? = nil, size: CGFloat, placeholder: @escaping () -> AnyView) {
        self.url = url
        self.cacheKey = cacheKey
        self.size = size
        self.placeholder = placeholder()
    }
    
    var body: some View {
        Group {
            if let image = imageLoader.image {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } else if imageLoader.isLoading {
                placeholder
                    .overlay(
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            .scaleEffect(0.7)
                    )
            } else {
                placeholder
            }
        }
        .frame(width: size, height: size)
        .clipShape(Circle())
        .onAppear {
            imageLoader.loadImage(from: url, cacheKeyOverride: cacheKey)
        }
    }
}
