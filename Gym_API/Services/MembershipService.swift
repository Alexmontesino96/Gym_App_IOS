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
    let expiresAt: String?
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
            return "Inactive"
        }
        
        if membershipType == "free" {
            return "Free Membership"
        }
        
        if let days = daysRemaining {
            if days <= 0 {
                return "Expired"
            } else if days <= 7 {
                return "Expires in \(days) days"
            } else {
                return "Active"
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
            return "Free Plan"
        case "basic":
            return "Basic Plan"
        case "premium":
            return "Premium Plan"
        case "vip":
            return "VIP Plan"
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
        guard let expiresAtString = expiresAt else {
            return "No expiration"
        }
        
        // Si es null string o está vacío
        if expiresAtString.isEmpty {
            return "No expiration"
        }
        
        // Intentar parsear la fecha
        let formatter = ISO8601DateFormatter()
        if let date = formatter.date(from: expiresAtString) {
            let displayFormatter = DateFormatter()
            displayFormatter.dateStyle = .medium
            return "Expires: \(displayFormatter.string(from: date))"
        }
        
        return "Sin vencimiento"
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