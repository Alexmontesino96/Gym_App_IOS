import SwiftUI

/// Vista especializada para cargar imágenes desde el backend con autenticación
struct BackendImageView: View {
    let url: String
    let size: CGFloat
    @EnvironmentObject var authService: AuthServiceDirect
    @EnvironmentObject var themeManager: ThemeManager
    
    @State private var image: UIImage?
    @State private var isLoading = true
    @State private var hasError = false
    
    var body: some View {
        Group {
            if let image = image {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: size, height: size)
                    .clipShape(Circle())
            } else if isLoading {
                placeholderView
                    .overlay(
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            .scaleEffect(0.7)
                    )
            } else {
                placeholderView
            }
        }
        .frame(width: size, height: size)
        .onAppear {
            Task {
                await loadImage()
            }
        }
    }
    
    private var placeholderView: some View {
        Circle()
            .fill(
                LinearGradient(
                    colors: [
                        Color.dynamicAccent(theme: themeManager.currentTheme),
                        Color.dynamicAccent(theme: themeManager.currentTheme).opacity(0.7)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .frame(width: size, height: size)
            .overlay(
                Image(systemName: "person.fill")
                    .font(.system(size: size * 0.45))
                    .foregroundColor(.white)
            )
    }
    
    @MainActor
    private func loadImage() async {
        guard !url.isEmpty else {
            print("⚠️ [BackendImageView] Empty URL")
            isLoading = false
            return
        }
        
        // Extraer el user ID de la URL para construir el endpoint correcto
        let userID = extractUserID(from: url)
        let backendURL = "https://gymapi-eh6m.onrender.com/api/v1/users/\(userID)/photo"
        
        print("🔄 [BackendImageView] Loading from: \(backendURL)")
        
        guard let imageURL = URL(string: backendURL) else {
            print("❌ [BackendImageView] Invalid URL")
            isLoading = false
            return
        }
        
        // Obtener token de autenticación
        guard let token = await authService.getValidAccessToken() else {
            print("❌ [BackendImageView] No auth token")
            isLoading = false
            return
        }
        
        var request = URLRequest(url: imageURL)
        request.httpMethod = "GET"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("*/*", forHTTPHeaderField: "Accept")
        
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            
            if let httpResponse = response as? HTTPURLResponse {
                print("🌐 [BackendImageView] HTTP Status: \(httpResponse.statusCode)")
                
                if httpResponse.statusCode == 200, let loadedImage = UIImage(data: data) {
                    print("✅ [BackendImageView] Image loaded successfully")
                    self.image = loadedImage
                } else {
                    print("❌ [BackendImageView] Failed to load image, status: \(httpResponse.statusCode)")
                    hasError = true
                }
            }
        } catch {
            print("❌ [BackendImageView] Error: \(error.localizedDescription)")
            hasError = true
        }
        
        isLoading = false
    }
    
    private func extractUserID(from urlString: String) -> String {
        // Extraer el ID del usuario de patrones como auth0_68269ecc731a77fcf55529e7_...
        if urlString.contains("auth0_") {
            let components = urlString.components(separatedBy: "auth0_")
            if components.count > 1 {
                let idPart = components[1]
                if let underscoreIndex = idPart.firstIndex(of: "_") {
                    let userID = "auth0_" + idPart[..<underscoreIndex]
                    print("📁 [BackendImageView] Extracted userID: \(userID)")
                    return userID
                }
            }
        }
        
        // Fallback: usar el ID del usuario actual
        if let currentUser = authService.user?.id {
            print("📁 [BackendImageView] Using current userID: \(currentUser)")
            return currentUser
        }
        
        return ""
    }
}

#Preview {
    BackendImageView(
        url: "https://via.placeholder.com/150",
        size: 100
    )
    .environmentObject(AuthServiceDirect())
    .environmentObject(ThemeManager())
}