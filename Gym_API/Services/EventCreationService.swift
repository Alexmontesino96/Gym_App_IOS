//
//  EventCreationService.swift
//  Gym_API
//
//  Created by Assistant on 8/18/25.
//

import Foundation
import SwiftUI

@MainActor
class EventCreationService: ObservableObject {
    
    // MARK: - Published Properties
    @Published var isCreating = false
    @Published var errorMessage: String?
    @Published var successMessage: String?
    @Published var createdEvent: CreateEventResponse?
    
    // MARK: - Private Properties
    private let baseURL = "https://gymapi-eh6m.onrender.com/api/v1"
    private let session = URLSession.shared
    
    // MARK: - Dependencies
    weak var authService: AuthServiceDirect?
    weak var gymService: GymService?
    weak var eventService: EventService?
    
    // MARK: - Initialization
    init() {
        print("🎉 EventCreationService initialized")
    }
    
    // MARK: - Create Event
    func createEvent(_ eventRequest: CreateEventRequest) async -> Bool {
        isCreating = true
        errorMessage = nil
        successMessage = nil
        createdEvent = nil
        
        print("🎉 Creating event: \(eventRequest.title)")
        
        guard let url = URL(string: "\(baseURL)/events/") else {
            await MainActor.run {
                self.errorMessage = "URL inválida"
                self.isCreating = false
            }
            return false
        }
        
        // Create authenticated request with gym header
        guard let httpRequest = await HTTPClient.shared.makeRequest(
            url: url,
            method: "POST",
            includeGymHeader: true
        ) else {
            await MainActor.run {
                self.errorMessage = "No se pudo crear la solicitud autenticada"
                self.isCreating = false
            }
            return false
        }
        
        // Configure request
        var urlRequest = httpRequest
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        // Encode request body
        do {
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            urlRequest.httpBody = try encoder.encode(eventRequest)
            
            print("🎉 Request body created successfully")
            
        } catch {
            await MainActor.run {
                self.errorMessage = "Error al codificar los datos del evento: \(error.localizedDescription)"
                self.isCreating = false
            }
            return false
        }
        
        // Make API call
        do {
            let (data, response) = try await session.data(for: urlRequest)
            
            if let httpResponse = response as? HTTPURLResponse {
                print("🎉 API Response status: \(httpResponse.statusCode)")
                
                if httpResponse.statusCode == 200 || httpResponse.statusCode == 201 {
                    // Success - decode response (200 or 201 are both valid)
                    do {
                        let decoder = DateDecoding.serverDecoder()
                        let eventResponse = try decoder.decode(CreateEventResponse.self, from: data)
                        
                        await MainActor.run {
                            self.createdEvent = eventResponse
                            self.successMessage = "Evento '\(eventResponse.title)' creado exitosamente"
                            self.isCreating = false
                        }
                        
                        print("✅ Event created successfully: \(eventResponse.title) (ID: \(eventResponse.id))")
                        
                        // Refresh events in EventService
                        if let eventService = eventService {
                            await eventService.fetchEvents()
                            await eventService.fetchUserParticipations()
                        }
                        
                        return true
                        
                    } catch {
                        await MainActor.run {
                            self.errorMessage = "Error al procesar la respuesta del servidor: \(error.localizedDescription)"
                            self.isCreating = false
                        }
                        print("❌ Error decoding event response: \(error)")
                        return false
                    }
                    
                } else {
                    // Handle different error status codes
                    let errorMessage = await handleAPIError(data: data, statusCode: httpResponse.statusCode)
                    
                    await MainActor.run {
                        self.errorMessage = errorMessage
                        self.isCreating = false
                    }
                    
                    return false
                }
            }
            
        } catch {
            await MainActor.run {
                self.errorMessage = "Error de conexión: \(error.localizedDescription)"
                self.isCreating = false
            }
            print("❌ Network error creating event: \(error)")
            return false
        }
        
        await MainActor.run {
            self.errorMessage = "Error desconocido"
            self.isCreating = false
        }
        return false
    }
    
    // MARK: - Error Handling
    private func handleAPIError(data: Data, statusCode: Int) async -> String {
        // Try to decode error response
        if let errorString = String(data: data, encoding: .utf8) {
            print("❌ API Error (\(statusCode)): \(errorString)")
        }
        
        switch statusCode {
        case 400:
            return "Datos del evento inválidos. Verifica que todos los campos estén correctos."
        case 401:
            return "No tienes autorización. Inicia sesión nuevamente."
        case 403:
            return "No tienes permisos para crear eventos. Contacta al administrador."
        case 409:
            return "Ya existe un evento con estas características."
        case 422:
            // Try to decode validation errors
            do {
                let decoder = JSONDecoder()
                let validationError = try decoder.decode(ValidationErrorResponse.self, from: data)
                let errors = validationError.detail.map { "\($0.msg)" }.joined(separator: ", ")
                return "Errores de validación: \(errors)"
            } catch {
                return "Datos del evento inválidos."
            }
        case 500:
            return "Error del servidor. Intenta nuevamente en unos minutos."
        default:
            return "Error inesperado (\(statusCode)). Contacta al soporte."
        }
    }
    
    // MARK: - Validation
    func validateEventData(_ formData: EventFormData) -> [String] {
        return formData.validationErrors
    }
    
    // MARK: - Clear State
    func clearState() {
        errorMessage = nil
        successMessage = nil
        createdEvent = nil
        isCreating = false
    }
    
    // MARK: - Quick Event Creation (Templates)
    func createQuickEvent(template: EventTemplate, startTime: Date, location: String) async -> Bool {
        var formData = template.formData
        formData.startDate = startTime
        formData.endDate = startTime.addingTimeInterval(3600) // 1 hour duration
        formData.location = location
        
        let request = formData.toCreateEventRequest()
        return await createEvent(request)
    }
}

// MARK: - Validation Error Response Model
struct ValidationErrorResponse: Codable {
    let detail: [ValidationErrorDetail]
}

struct ValidationErrorDetail: Codable {
    let loc: [ValidationErrorLocation]
    let msg: String
    let type: String
}

enum ValidationErrorLocation: Codable {
    case string(String)
    case int(Int)
    
    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let stringValue = try? container.decode(String.self) {
            self = .string(stringValue)
        } else if let intValue = try? container.decode(Int.self) {
            self = .int(intValue)
        } else {
            throw DecodingError.typeMismatch(
                ValidationErrorLocation.self,
                DecodingError.Context(codingPath: decoder.codingPath, debugDescription: "Cannot decode location")
            )
        }
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .string(let value):
            try container.encode(value)
        case .int(let value):
            try container.encode(value)
        }
    }
}