import SwiftUI

/// Componente especializado para cargar imágenes de perfil usando AsyncImage
struct AsyncProfileImage: View {
    let url: String
    let size: CGFloat
    let placeholder: AnyView
    
    @EnvironmentObject var themeManager: ThemeManager
    
    init(url: String, size: CGFloat, placeholder: @escaping () -> AnyView) {
        self.url = url
        self.size = size
        self.placeholder = placeholder()
    }
    
    var body: some View {
        Group {
            if let cleanURL = createCleanURL(from: url) {
                AsyncImage(url: cleanURL) { phase in
                    switch phase {
                    case .empty:
                        placeholder
                            .overlay(
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                    .scaleEffect(0.7)
                            )
                    case .success(let image):
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                    case .failure(let error):
                        let _ = print("❌ [AsyncProfileImage] Failed to load: \(error.localizedDescription)")
                        let _ = print("🔍 [AsyncProfileImage] URL: \(cleanURL.absoluteString)")
                        
                        // Mostrar placeholder en caso de error
                        placeholder
                    @unknown default:
                        placeholder
                    }
                }
            } else {
                placeholder
            }
        }
        .frame(width: size, height: size)
        .clipShape(Circle())
    }
    
    private func createCleanURL(from urlString: String) -> URL? {
        let trimmed = urlString.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Limpiar la URL y usar directamente
        var cleanURL = trimmed
        if cleanURL.hasSuffix("?") {
            cleanURL = String(cleanURL.dropLast())
        }
        
        if let url = URL(string: cleanURL) {
            print("🔧 [AsyncProfileImage] Using clean URL: \(cleanURL)")
            return url
        }
        
        print("❌ [AsyncProfileImage] Could not create valid URL from: \(urlString)")
        return nil
    }
}

#Preview {
    AsyncProfileImage(
        url: "https://via.placeholder.com/150",
        size: 100
    ) {
        AnyView(
            Circle()
                .fill(Color.blue)
                .overlay(
                    Image(systemName: "person.fill")
                        .foregroundColor(.white)
                )
        )
    }
    .environmentObject(ThemeManager())
}