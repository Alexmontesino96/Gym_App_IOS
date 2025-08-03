import SwiftUI

/// Componente reutilizable para mostrar avatares de perfil
struct ProfileAvatar: View {
    let pictureURL: String
    let size: CGFloat
    let placeholderIcon: String
    let showBorder: Bool
    
    @EnvironmentObject var themeManager: ThemeManager
    
    init(
        pictureURL: String,
        size: CGFloat = 48,
        placeholderIcon: String = "person.circle.fill",
        showBorder: Bool = false
    ) {
        self.pictureURL = pictureURL
        self.size = size
        self.placeholderIcon = placeholderIcon
        self.showBorder = showBorder
    }
    
    var body: some View {
        Group {
            if !pictureURL.isEmpty, let url = createValidURL(from: pictureURL) {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .empty:
                        placeholderView
                            .overlay(
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .gray))
                                    .scaleEffect(0.7)
                            )
                    case .success(let image):
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                    case .failure(let error):
                        let _ = print("❌ [ProfileAvatar] Error loading image: \(error.localizedDescription)")
                        let _ = print("🔍 [ProfileAvatar] Failed URL: \(url.absoluteString)")
                        placeholderView
                    @unknown default:
                        placeholderView
                    }
                }
                .frame(width: size, height: size)
                .clipShape(Circle())
                .overlay(
                    showBorder ? Circle()
                        .stroke(Color.dynamicBorder(theme: themeManager.currentTheme), lineWidth: 1)
                        : nil
                )
            } else {
                placeholderView
                    .overlay(
                        showBorder ? Circle()
                            .stroke(Color.dynamicBorder(theme: themeManager.currentTheme), lineWidth: 1)
                            : nil
                    )
            }
        }
    }
    
    @ViewBuilder
    private var placeholderView: some View {
        Image(systemName: placeholderIcon)
            .font(.system(size: size * 0.5))
            .foregroundColor(Color.dynamicTextSecondary(theme: themeManager.currentTheme))
            .frame(width: size, height: size)
            .background(
                Circle()
                    .fill(Color.dynamicSurface(theme: themeManager.currentTheme).opacity(0.1))
            )
    }
    
    // MARK: - Helper Functions
    private func createValidURL(from urlString: String) -> URL? {
        let cleanedString = urlString.trimmingCharacters(in: .whitespacesAndNewlines)
        var cleanURL = cleanedString
        
        // Si la URL termina con '?', la removemos
        if cleanURL.hasSuffix("?") {
            cleanURL = String(cleanURL.dropLast())
        }
        
        // Verificar que sea una URL válida
        if cleanURL.hasPrefix("https://") || cleanURL.hasPrefix("http://") {
            return URL(string: cleanURL)
        }
        
        return nil
    }
}

// MARK: - Convenience Extensions
extension ProfileAvatar {
    /// Avatar pequeño para listas y mensajes
    static func small(pictureURL: String, showBorder: Bool = false) -> ProfileAvatar {
        ProfileAvatar(pictureURL: pictureURL, size: 32, showBorder: showBorder)
    }
    
    /// Avatar mediano para componentes generales
    static func medium(pictureURL: String, showBorder: Bool = false) -> ProfileAvatar {
        ProfileAvatar(pictureURL: pictureURL, size: 48, showBorder: showBorder)
    }
    
    /// Avatar grande para perfiles
    static func large(pictureURL: String, showBorder: Bool = false) -> ProfileAvatar {
        ProfileAvatar(pictureURL: pictureURL, size: 80, showBorder: showBorder)
    }
    
    /// Avatar extra grande para cabeceras de perfil
    static func extraLarge(pictureURL: String, showBorder: Bool = false) -> ProfileAvatar {
        ProfileAvatar(pictureURL: pictureURL, size: 100, showBorder: showBorder)
    }
}

#Preview {
    VStack(spacing: 20) {
        ProfileAvatar.small(pictureURL: "https://via.placeholder.com/150")
        
        ProfileAvatar.medium(pictureURL: "", showBorder: true)
        
        ProfileAvatar.large(pictureURL: "https://via.placeholder.com/150")
        
        ProfileAvatar.extraLarge(pictureURL: "", showBorder: true)
    }
    .environmentObject(ThemeManager())
    .padding()
}