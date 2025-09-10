//
//  SessionCreationService.swift
//  Gym_API
//
//  Service for creating class sessions
//

import Foundation
import Combine

@MainActor
class SessionCreationService: ObservableObject {
    // MARK: - Published Properties
    @Published var availableClasses: [ClassInfo] = []
    @Published var trainers: [UserPublicProfile] = []
    @Published var isLoadingClasses = false
    @Published var isLoadingTrainers = false
    @Published var isCreatingSession = false
    @Published var classesErrorMessage: String?
    @Published var trainersErrorMessage: String?
    @Published var createSessionErrorMessage: String?
    @Published var createSessionSuccessMessage: String?
    @Published var createdSession: ClassSessionResponse?
    
    // Update/Delete session properties
    @Published var isUpdatingSession = false
    @Published var isDeletingSession = false
    @Published var updateSessionErrorMessage: String?
    @Published var deleteSessionErrorMessage: String?
    @Published var updateSessionSuccessMessage: String?
    @Published var deleteSessionSuccessMessage: String?
    
    // MARK: - Private Properties
    private let baseURL = "https://gymapi-eh6m.onrender.com/api/v1"
    private let session = URLSession.shared
    weak var authService: AuthServiceDirect?
    weak var eventService: EventService?
    weak var classService: ClassService?
    
    init(authService: AuthServiceDirect? = nil, eventService: EventService? = nil, classService: ClassService? = nil) {
        self.authService = authService
        self.eventService = eventService
        self.classService = classService
        print("🎯 SessionCreationService initialized")
    }
    
    // MARK: - Fetch Available Classes
    func fetchAvailableClasses() async {
        isLoadingClasses = true
        classesErrorMessage = nil
        
        guard let url = URL(string: "\(baseURL)/schedule/classes/classes?active_only=true&limit=100") else {
            classesErrorMessage = "Invalid URL"
            isLoadingClasses = false
            return
        }
        
        // Create authenticated request
        guard let httpRequest = await HTTPClient.shared.makeRequest(
            url: url,
            method: "GET",
            includeGymHeader: true
        ) else {
            classesErrorMessage = "Could not create authenticated request"
            isLoadingClasses = false
            return
        }
        
        do {
            let (data, response) = try await session.data(for: httpRequest)
            
            if let httpResponse = response as? HTTPURLResponse {
                print("📡 Classes response status: \(httpResponse.statusCode)")
                
                if httpResponse.statusCode == 200 {
                    let decoder = DateDecoding.serverDecoder()
                    let classes = try decoder.decode([ClassInfo].self, from: data)
                    
                    self.availableClasses = classes
                    self.classesErrorMessage = nil
                    print("✅ Successfully loaded \(classes.count) classes")
                } else {
                    self.classesErrorMessage = "Error loading classes: HTTP \(httpResponse.statusCode)"
                }
            }
        } catch {
            print("❌ Error fetching classes: \(error)")
            self.classesErrorMessage = "Error loading classes: \(error.localizedDescription)"
        }
        
        isLoadingClasses = false
    }
    
    // MARK: - Fetch Trainers
    func fetchTrainers() async {
        isLoadingTrainers = true
        trainersErrorMessage = nil
        
        guard let url = URL(string: "\(baseURL)/users/p/gym-participants?role=TRAINER&skip=0&limit=100") else {
            trainersErrorMessage = "Invalid URL"
            isLoadingTrainers = false
            return
        }
        
        // Create authenticated request
        guard let httpRequest = await HTTPClient.shared.makeRequest(
            url: url,
            method: "GET",
            includeGymHeader: true
        ) else {
            trainersErrorMessage = "Could not create authenticated request"
            isLoadingTrainers = false
            return
        }
        
        do {
            let (data, response) = try await session.data(for: httpRequest)
            
            if let httpResponse = response as? HTTPURLResponse {
                print("📡 Trainers response status: \(httpResponse.statusCode)")
                
                if httpResponse.statusCode == 200 {
                    let decoder = DateDecoding.serverDecoder()
                    let trainers = try decoder.decode([UserPublicProfile].self, from: data)
                    
                    self.trainers = trainers
                    self.trainersErrorMessage = nil
                    print("✅ Successfully loaded \(trainers.count) trainers")
                } else {
                    self.trainersErrorMessage = "Error loading trainers: HTTP \(httpResponse.statusCode)"
                }
            }
        } catch {
            print("❌ Error fetching trainers: \(error)")
            self.trainersErrorMessage = "Error loading trainers: \(error.localizedDescription)"
        }
        
        isLoadingTrainers = false
    }
    
    // MARK: - Create Session
    func createSession(sessionData: ClassSessionCreate) async -> Bool {
        isCreatingSession = true
        createSessionErrorMessage = nil
        createSessionSuccessMessage = nil
        
        print("🎯 Creating session for class \(sessionData.classId) with trainer \(sessionData.trainerId)")
        
        guard let url = URL(string: "\(baseURL)/schedule/sessions/sessions") else {
            createSessionErrorMessage = "Invalid URL"
            isCreatingSession = false
            return false
        }
        
        // Create request body
        do {
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            let jsonData = try encoder.encode(sessionData)
            
            // Debug: print request body
            if let jsonString = String(data: jsonData, encoding: .utf8) {
                print("📤 Request body: \(jsonString)")
            }
            
            // Create authenticated request
            guard var httpRequest = await HTTPClient.shared.makeRequest(
                url: url,
                method: "POST",
                includeGymHeader: true
            ) else {
                createSessionErrorMessage = "Could not create authenticated request"
                isCreatingSession = false
                return false
            }
            
            httpRequest.httpBody = jsonData
            httpRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
            
            let (data, response) = try await session.data(for: httpRequest)
            
            if let httpResponse = response as? HTTPURLResponse {
                print("📡 Create session response status: \(httpResponse.statusCode)")
                
                if httpResponse.statusCode == 201 || httpResponse.statusCode == 200 {
                    // Success - decode response
                    let decoder = DateDecoding.serverDecoder()
                    let sessionResponse = try decoder.decode(ClassSessionResponse.self, from: data)
                    
                    self.createdSession = sessionResponse
                    self.createSessionSuccessMessage = "Session created successfully"
                    self.isCreatingSession = false
                    
                    print("✅ Session created successfully with ID: \(sessionResponse.id)")
                    
                    // Refresh sessions in ClassService if available
                    if let classService = classService {
                        await classService.forceRefreshSessions(date: Date())
                    }
                    
                    return true
                } else {
                    // Handle error response
                    let errorMessage = await handleCreateSessionAPIError(statusCode: httpResponse.statusCode, data: data)
                    self.createSessionErrorMessage = errorMessage
                    self.isCreatingSession = false
                    return false
                }
            }
        } catch {
            print("❌ Error creating session: \(error)")
            self.createSessionErrorMessage = "Error creating session: \(error.localizedDescription)"
            self.isCreatingSession = false
            return false
        }
        
        return false
    }
    
    // MARK: - Error Handling
    private func handleCreateSessionAPIError(statusCode: Int, data: Data) async -> String {
        switch statusCode {
        case 400:
            // Try to decode validation error
            if let errorResponse = try? JSONDecoder().decode(ValidationErrorResponse.self, from: data) {
                return errorResponse.detail.first?.msg ?? "Invalid session data"
            }
            return "Invalid session data"
        case 401:
            return "Authentication required"
        case 403:
            return "You don't have permission to create sessions"
        case 404:
            return "Class or trainer not found"
        case 422:
            // Validation error
            if let errorResponse = try? JSONDecoder().decode(ValidationErrorResponse.self, from: data) {
                return errorResponse.detail.first?.msg ?? "Validation error"
            }
            return "Validation error"
        default:
            return "Server error: \(statusCode)"
        }
    }
    
    // MARK: - Update Session
    func updateSession(sessionId: Int, sessionData: ClassSessionUpdate) async -> Bool {
        isUpdatingSession = true
        updateSessionErrorMessage = nil
        updateSessionSuccessMessage = nil
        
        print("🔄 Updating session: \(sessionId)")
        
        guard let url = URL(string: "\(baseURL)/schedule/sessions/sessions/\(sessionId)") else {
            updateSessionErrorMessage = "Invalid URL"
            isUpdatingSession = false
            return false
        }
        
        // Create authenticated request
        guard let httpRequest = await HTTPClient.shared.makeRequest(
            url: url,
            method: "PUT",
            includeGymHeader: true
        ) else {
            updateSessionErrorMessage = "Failed to create authenticated request"
            isUpdatingSession = false
            return false
        }
        
        // Configure request
        var urlRequest = httpRequest
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        // Encode request body
        do {
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            urlRequest.httpBody = try encoder.encode(sessionData)
            
            print("🔄 Update request body created successfully")
            
        } catch {
            updateSessionErrorMessage = "Error encoding session data: \(error.localizedDescription)"
            isUpdatingSession = false
            return false
        }
        
        // Make API call
        do {
            let (data, response) = try await session.data(for: urlRequest)
            
            if let httpResponse = response as? HTTPURLResponse {
                print("🔄 Update API Response status: \(httpResponse.statusCode)")
                
                if httpResponse.statusCode == 200 {
                    // Success - decode response
                    do {
                        let decoder = JSONDecoder()
                        decoder.dateDecodingStrategy = .iso8601
                        let sessionResponse = try decoder.decode(ClassSessionResponse.self, from: data)
                        
                        isUpdatingSession = false
                        updateSessionSuccessMessage = "Session updated successfully"
                        
                        print("✅ Session updated successfully: \(sessionResponse.id)")
                        
                        // Refresh the class service data
                        await classService?.forceRefreshSessions(date: sessionResponse.startTime)
                        
                        return true
                        
                    } catch {
                        updateSessionErrorMessage = "Error processing server response: \(error.localizedDescription)"
                        isUpdatingSession = false
                        print("❌ Error decoding update session response: \(error)")
                        return false
                    }
                    
                } else {
                    // Handle different error status codes
                    let errorMessage = await handleUpdateSessionAPIError(statusCode: httpResponse.statusCode, data: data)
                    
                    updateSessionErrorMessage = errorMessage
                    isUpdatingSession = false
                    
                    return false
                }
            }
            
        } catch {
            updateSessionErrorMessage = "Connection error: \(error.localizedDescription)"
            isUpdatingSession = false
            print("❌ Network error updating session: \(error)")
            return false
        }
        
        updateSessionErrorMessage = "Unknown error"
        isUpdatingSession = false
        return false
    }
    
    // MARK: - Delete Session
    func deleteSession(sessionId: Int) async -> Bool {
        isDeletingSession = true
        deleteSessionErrorMessage = nil
        deleteSessionSuccessMessage = nil
        
        print("🗑️ Deleting session: \(sessionId)")
        
        guard let url = URL(string: "\(baseURL)/schedule/sessions/sessions/\(sessionId)") else {
            deleteSessionErrorMessage = "Invalid URL"
            isDeletingSession = false
            return false
        }
        
        // Create authenticated request
        guard let httpRequest = await HTTPClient.shared.makeRequest(
            url: url,
            method: "DELETE",
            includeGymHeader: true
        ) else {
            deleteSessionErrorMessage = "Failed to create authenticated request"
            isDeletingSession = false
            return false
        }
        
        // Make API call
        do {
            let (data, response) = try await session.data(for: httpRequest)
            
            if let httpResponse = response as? HTTPURLResponse {
                print("🗑️ Delete API Response status: \(httpResponse.statusCode)")
                
                if httpResponse.statusCode == 200 {
                    // Success - decode response to see if it was deleted or cancelled
                    do {
                        let decoder = JSONDecoder()
                        decoder.dateDecodingStrategy = .iso8601
                        let sessionResponse = try decoder.decode(ClassSessionResponse.self, from: data)
                        
                        isDeletingSession = false
                        
                        if sessionResponse.status == "cancelled" {
                            deleteSessionSuccessMessage = "Session cancelled (had registered participants)"
                        } else {
                            deleteSessionSuccessMessage = "Session deleted successfully"
                        }
                        
                        print("✅ Session deleted/cancelled successfully: \(sessionResponse.id)")
                        
                        // Refresh the class service data
                        await classService?.forceRefreshSessions(date: sessionResponse.startTime)
                        
                        return true
                        
                    } catch {
                        deleteSessionErrorMessage = "Error processing server response: \(error.localizedDescription)"
                        isDeletingSession = false
                        print("❌ Error decoding delete session response: \(error)")
                        return false
                    }
                    
                } else {
                    // Handle different error status codes
                    let errorMessage = await handleDeleteSessionAPIError(statusCode: httpResponse.statusCode, data: data)
                    
                    deleteSessionErrorMessage = errorMessage
                    isDeletingSession = false
                    
                    return false
                }
            }
            
        } catch {
            deleteSessionErrorMessage = "Connection error: \(error.localizedDescription)"
            isDeletingSession = false
            print("❌ Network error deleting session: \(error)")
            return false
        }
        
        deleteSessionErrorMessage = "Unknown error"
        isDeletingSession = false
        return false
    }
    
    // MARK: - Update Session Error Handling
    private func handleUpdateSessionAPIError(statusCode: Int, data: Data) async -> String {
        switch statusCode {
        case 400:
            // Try to decode validation error
            if let errorResponse = try? JSONDecoder().decode(ValidationErrorResponse.self, from: data) {
                return errorResponse.detail.first?.msg ?? "Invalid session data"
            }
            return "Invalid session data (e.g., end time before start time)"
        case 401:
            return "Authentication required"
        case 403:
            return "You don't have permission to update this session"
        case 404:
            return "Session, gym, class, or trainer not found"
        case 422:
            // Validation error
            if let errorResponse = try? JSONDecoder().decode(ValidationErrorResponse.self, from: data) {
                return errorResponse.detail.first?.msg ?? "Validation error"
            }
            return "Validation error in request data"
        default:
            return "Server error: \(statusCode)"
        }
    }
    
    // MARK: - Delete Session Error Handling
    private func handleDeleteSessionAPIError(statusCode: Int, data: Data) async -> String {
        switch statusCode {
        case 401:
            return "Authentication required"
        case 403:
            return "You don't have permission to delete this session"
        case 404:
            return "Session or gym not found"
        case 422:
            // Validation error
            if let errorResponse = try? JSONDecoder().decode(ValidationErrorResponse.self, from: data) {
                return errorResponse.detail.first?.msg ?? "Validation error"
            }
            return "Validation error"
        default:
            return "Server error: \(statusCode)"
        }
    }
}

