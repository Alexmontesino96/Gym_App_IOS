//
//  MembershipService.swift
//  Gym_API
//
//  Created by Alex Montesino on 7/24/25.
//

import Foundation
import Combine

// MARK: - Membership Status Model
struct MembershipStatus: Codable {
    let userId: Int
    let gymId: Int
    let gymName: String
    let isActive: Bool
    let membershipType: String
    let expiresAt: Date?
    let daysRemaining: Int?
    let planName: String?
    let canAccess: Bool
    
    enum CodingKeys: String, CodingKey {
        case userId = "user_id"
        case gymId = "gym_id"
        case gymName = "gym_name"
        case isActive = "is_active"
        case membershipType = "membership_type"
        case expiresAt = "expires_at"
        case daysRemaining = "days_remaining"
        case planName = "plan_name"
        case canAccess = "can_access"
    }
    
    // MARK: - Computed Properties for UI
    var statusText: String {
        if !isActive {
            return "Inactiva"
        }
        
        if membershipType == "free" {
            return "Membresía Gratuita"
        }
        
        if let days = daysRemaining {
            if days <= 0 {
                return "Expirada"
            } else if days <= 7 {
                return "Expira en \(days) días"
            } else {
                return "Activa"
            }
        }
        
        return "Activa"
    }
    
    var statusColor: String {
        if !isActive || (daysRemaining ?? 1) <= 0 {
            return "red"
        }
        
        if let days = daysRemaining, days <= 7 {
            return "orange"
        }
        
        return "green"
    }
    
    var membershipDisplayName: String {
        if let planName = planName, !planName.isEmpty {
            return planName
        }
        
        switch membershipType.lowercased() {
        case "free":
            return "Plan Gratuito"
        case "basic":
            return "Plan Básico"
        case "premium":
            return "Plan Premium"
        case "vip":
            return "Plan VIP"
        default:
            return membershipType.capitalized
        }
    }
    
    var membershipIcon: String {
        switch membershipType.lowercased() {
        case "free":
            return "person.circle"
        case "basic":
            return "star.circle"
        case "premium":
            return "star.circle.fill"
        case "vip":
            return "crown.fill"
        default:
            return "creditcard.circle"
        }
    }
    
    var expirationText: String {
        guard let expiresAt = expiresAt else {
            return "Sin vencimiento"
        }
        
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return "Vence: \(formatter.string(from: expiresAt))"
    }
}

// MARK: - Membership Service
@MainActor
class MembershipService: ObservableObject {
    static let shared = MembershipService()
    
    private init() {
        print("🔧 MembershipService singleton inicializado")
    }
    
    private let baseURL = "https://gymapi-eh6m.onrender.com/api/v1"
    private let session = URLSession.shared
    weak var authService: AuthServiceProtocol?
    
    // Gym ID dinámico - se puede configurar desde la app
    var currentGymId: Int = 4 // Default, pero debe ser configurable
    
    // MARK: - Published Properties
    @Published var membershipStatus: MembershipStatus?
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    // MARK: - Helper for Main Thread Updates
    private func updateOnMainThread(_ updates: @escaping () -> Void) {
        if Thread.isMainThread {
            updates()
        } else {
            DispatchQueue.main.async {
                updates()
            }
        }
    }
    
    // MARK: - Helper for Authenticated Requests
    private func createAuthenticatedRequest(url: URL, method: String = "GET") async -> URLRequest? {
        guard let authService = authService else {
            print("❌ No authService configured")
            return nil
        }
        
        guard let token = await authService.getValidAccessToken() else {
            print("❌ No valid access token")
            return nil
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("\(currentGymId)", forHTTPHeaderField: "X-Gym-ID")
        
        if method == "POST" || method == "PUT" {
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        }
        
        return request
    }
    
    // MARK: - Get My Membership Status
    func getMyMembershipStatus() async {
        updateOnMainThread {
            self.isLoading = true
            self.errorMessage = nil
        }
        
        guard let url = URL(string: "\(baseURL)/memberships/my-status") else {
            updateOnMainThread {
                self.errorMessage = "URL inválida"
                self.isLoading = false
            }
            return
        }
        
        guard let request = await createAuthenticatedRequest(url: url) else {
            updateOnMainThread {
                self.errorMessage = "No se pudo crear request autenticado"
                self.isLoading = false
            }
            return
        }
        
        do {
            let (data, response) = try await session.data(for: request)
            
            if let httpResponse = response as? HTTPURLResponse {
                print("📡 Response status for membership status: \(httpResponse.statusCode)")
                
                if httpResponse.statusCode == 200 {
                    let decoder = JSONDecoder()
                    decoder.dateDecodingStrategy = .custom { decoder in
                        let container = try decoder.singleValueContainer()
                        let dateString = try container.decode(String.self)
                        
                        let formatter = DateFormatter()
                        formatter.locale = Locale(identifier: "en_US_POSIX")
                        formatter.timeZone = TimeZone(secondsFromGMT: 0)
                        
                        let dateFormats = [
                            "yyyy-MM-dd'T'HH:mm:ss.SSSSSS'Z'",
                            "yyyy-MM-dd'T'HH:mm:ss.SSS'Z'",
                            "yyyy-MM-dd'T'HH:mm:ss'Z'",
                            "yyyy-MM-dd'T'HH:mm:ss.SSSSSS",
                            "yyyy-MM-dd'T'HH:mm:ss.SSS",
                            "yyyy-MM-dd'T'HH:mm:ss"
                        ]
                        
                        for format in dateFormats {
                            formatter.dateFormat = format
                            if let date = formatter.date(from: dateString) {
                                return date
                            }
                        }
                        
                        throw DecodingError.dataCorruptedError(in: container, debugDescription: "Cannot decode date string '\(dateString)'")
                    }
                    
                    let status = try decoder.decode(MembershipStatus.self, from: data)
                    
                    updateOnMainThread {
                        self.membershipStatus = status
                        self.isLoading = false
                    }
                    
                    print("✅ Estado de membresía obtenido exitosamente: \(status.membershipDisplayName)")
                } else {
                    let errorString = String(data: data, encoding: .utf8) ?? "Error desconocido"
                    print("❌ Error getting membership status: \(errorString)")
                    
                    updateOnMainThread {
                        self.errorMessage = "Error al obtener estado de membresía: \(httpResponse.statusCode)"
                        self.isLoading = false
                    }
                }
            }
        } catch {
            print("❌ Error fetching membership status: \(error)")
            
            updateOnMainThread {
                self.errorMessage = "Error de red: \(error.localizedDescription)"
                self.isLoading = false
            }
        }
    }
    
    // MARK: - Refresh Membership Status
    func refreshMembershipStatus() async {
        await getMyMembershipStatus()
    }
    
    // MARK: - Clear Membership Data
    func clearMembershipData() {
        membershipStatus = nil
        errorMessage = nil
        print("🗑️ Datos de membresía limpiados")
    }
}