import Foundation

@MainActor
class GymUserService: ObservableObject {
    static let shared = GymUserService()

    private let baseURL = "https://gymapi-eh6m.onrender.com/api/v1"
    private let session = URLSession.shared
    weak var authService: AuthServiceDirect?

    @Published var isLoading = false
    @Published var errorMessage: String?

    func fetchUsersForCurrentGym(roleFilter: String? = nil) async -> [SelectableUser]? {
        print("🔄 Iniciando carga de usuarios del gimnasio...")
        isLoading = true
        errorMessage = nil

        guard let gymId = GymService.shared.currentGymId else {
            print("❌ No hay gimnasio seleccionado")
            errorMessage = "No hay gimnasio seleccionado"
            isLoading = false
            return nil
        }
        
        print("🏢 Cargando usuarios para el gym ID: \(gymId)")

        // Usar el endpoint de participantes públicos del gym (confirmado que funciona)
        var urlString = "\(baseURL)/users/p/gym-participants"
        if let roleFilter = roleFilter {
            urlString += "?role=\(roleFilter)"
        }
        guard let url = URL(string: urlString) else {
            errorMessage = "URL inválida"
            isLoading = false
            return nil
        }

        guard let request = await HTTPClient.shared.makeRequest(url: url, method: "GET", includeGymHeader: true) else {
            print("❌ No se pudo crear la solicitud HTTP")
            errorMessage = "No se pudo crear la solicitud"
            isLoading = false
            return nil
        }

        print("📤 Enviando solicitud a: \(url)")

        do {
            let (data, response) = try await session.data(for: request)
            guard let http = response as? HTTPURLResponse else {
                print("❌ Respuesta HTTP inválida")
                errorMessage = "Respuesta del servidor inválida"
                isLoading = false
                return nil
            }
            
            print("📥 Respuesta recibida con código: \(http.statusCode)")
            
            if http.statusCode != 200 {
                // Intentar obtener mensaje de error del servidor
                if let errorData = String(data: data, encoding: .utf8) {
                    print("❌ Error del servidor: \(errorData)")
                }
                errorMessage = "Error del servidor (código \(http.statusCode))"
                isLoading = false
                return nil
            }

            // Decodificar usuarios del gimnasio usando el endpoint /users/p/gym-participants
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            
            let profiles = try decoder.decode([UserPublicProfile].self, from: data)
            print("✅ Se obtuvieron \(profiles.count) usuarios del gimnasio")
            
            let users = profiles.map { profile in
                let user = SelectableUser(
                    id: profile.id,
                    name: profile.fullName,
                    email: "", // El endpoint público no devuelve email por seguridad
                    role: profile.role,
                    profilePicture: profile.picture
                )
                print("👤 Usuario cargado: ID=\(profile.id), Nombre=\(user.name), Rol=\(profile.role)")
                return user
            }
            isLoading = false
            return users
        } catch {
            print("❌ Error al decodificar usuarios: \(error)")
            errorMessage = "Error al procesar datos: \(error.localizedDescription)"
            isLoading = false
            return nil
        }
    }
}
