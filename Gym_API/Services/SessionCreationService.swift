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
}

