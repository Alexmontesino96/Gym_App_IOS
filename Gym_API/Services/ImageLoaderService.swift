import SwiftUI
import Combine

/// Servicio para cargar imágenes con mejor manejo de errores
class ImageLoaderService: ObservableObject {
    @Published var image: UIImage?
    @Published var isLoading = false
    @Published var error: Error?
    
    private var cancellables = Set<AnyCancellable>()
    
    func loadImage(from urlString: String) {
        guard !urlString.isEmpty else {
            print("⚠️ [ImageLoader] URL string is empty")
            return
        }
        
        let cleanedURL = cleanURL(urlString)
        
        guard let url = URL(string: cleanedURL) else {
            print("❌ [ImageLoader] Invalid URL: \(cleanedURL)")
            return
        }
        
        print("🔄 [ImageLoader] Original URL: \(urlString)")
        print("🔄 [ImageLoader] Cleaned URL: \(cleanedURL)")
        print("🔄 [ImageLoader] Loading image from: \(url.absoluteString)")
        
        isLoading = true
        error = nil
        
        loadImageDirect(from: url)
    }
    
    private func loadImageDirect(from url: URL) {
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("*/*", forHTTPHeaderField: "Accept")
        request.setValue("Mozilla/5.0 (iPhone; CPU iPhone OS 16_0 like Mac OS X) AppleWebKit/605.1.15", forHTTPHeaderField: "User-Agent")
        
        print("🔧 [ImageLoader] Request headers: \(request.allHTTPHeaderFields ?? [:])")
        
        URLSession.shared.dataTaskPublisher(for: request)
            .sink(
                receiveCompletion: { [weak self] completion in
                    self?.isLoading = false
                    switch completion {
                    case .finished:
                        break
                    case .failure(let error):
                        print("❌ [ImageLoader] Network error: \(error.localizedDescription)")
                        DispatchQueue.main.async {
                            self?.error = error
                        }
                    }
                },
                receiveValue: { [weak self] data, response in
                    if let httpResponse = response as? HTTPURLResponse {
                        print("🌐 [ImageLoader] HTTP Status: \(httpResponse.statusCode)")
                        print("🌐 [ImageLoader] Content-Type: \(httpResponse.allHeaderFields["Content-Type"] ?? "unknown")")
                        print("🌐 [ImageLoader] Content-Length: \(httpResponse.allHeaderFields["Content-Length"] ?? "unknown")")
                        
                        if httpResponse.statusCode != 200 {
                            print("❌ [ImageLoader] HTTP Error: \(httpResponse.statusCode)")
                            print("🔍 [ImageLoader] Response data: \(String(data: data, encoding: .utf8) ?? "No readable data")")
                            
                            DispatchQueue.main.async {
                                self?.error = ImageLoaderError.httpError(httpResponse.statusCode)
                            }
                            return
                        }
                    }
                    
                    if let image = UIImage(data: data) {
                        print("✅ [ImageLoader] Image loaded successfully, size: \(image.size)")
                        DispatchQueue.main.async {
                            self?.image = image
                        }
                    } else {
                        print("❌ [ImageLoader] Failed to create image from data")
                        print("🔍 [ImageLoader] Data size: \(data.count) bytes")
                        DispatchQueue.main.async {
                            self?.error = ImageLoaderError.invalidImageData
                        }
                    }
                }
            )
            .store(in: &cancellables)
    }
    
    private func cleanURL(_ urlString: String) -> String {
        let trimmed = urlString.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Remover el "?" final si existe
        if trimmed.hasSuffix("?") {
            return String(trimmed.dropLast())
        }
        
        return trimmed
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
    let size: CGFloat
    let placeholder: AnyView
    
    @StateObject private var imageLoader = ImageLoaderService()
    
    init(url: String, size: CGFloat, placeholder: @escaping () -> AnyView) {
        self.url = url
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
            imageLoader.loadImage(from: url)
        }
    }
}