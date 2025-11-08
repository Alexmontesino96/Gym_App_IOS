import Foundation
import Combine

@MainActor
class SurveyService: ObservableObject {
    static let shared = SurveyService()
    
    @Published var availableSurveys: [Survey] = []
    @Published var currentSurvey: Survey?
    @Published var currentQuestions: [SurveyQuestion] = []
    @Published var currentResponse: SurveyResponse?
    @Published var myResponses: [SurveyResponse] = []
    @Published var surveyTemplates: [SurveyTemplate] = []
    @Published var surveyStatistics: SurveyStatistics?
    
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var successMessage: String?
    @Published var needsSurveyRefresh = false
    @Published var isPublishing = false

    private let baseURL = apiBaseURL
    weak var authService: AuthServiceDirect?
    weak var gymService: GymService?
    
    private var cancellables = Set<AnyCancellable>()
    private var publishingIds = Set<Int>() // Track surveys being published
    
    // Custom date decoder para manejar diferentes formatos de fecha del backend
    private lazy var customDateDecoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .custom { decoder in
            let container = try decoder.singleValueContainer()
            let dateString = try container.decode(String.self)
            
            // Array de formatos de fecha a intentar, ordenados por probabilidad
            let dateFormats = [
                "yyyy-MM-dd'T'HH:mm:ss.SSSSSSZ",  // Microsegundos (formato principal del backend)
                "yyyy-MM-dd'T'HH:mm:ss.SSSZ",      // Milisegundos
                "yyyy-MM-dd'T'HH:mm:ssZ",          // Sin fracciones
                "yyyy-MM-dd'T'HH:mm:ss",           // Sin zona horaria
                "yyyy-MM-dd"                       // Solo fecha
            ]
            
            let formatter = DateFormatter()
            formatter.locale = Locale(identifier: "en_US_POSIX")
            formatter.timeZone = TimeZone(secondsFromGMT: 0)
            
            // Intentar con cada formato
            for format in dateFormats {
                formatter.dateFormat = format
                if let date = formatter.date(from: dateString) {
                    return date
                }
            }
            
            // Si ningún formato funciona, intentar con ISO8601
            let isoFormatter = ISO8601DateFormatter()
            
            // Intentar con diferentes opciones de ISO8601
            let isoOptions: [ISO8601DateFormatter.Options] = [
                [.withInternetDateTime, .withFractionalSeconds],
                [.withInternetDateTime],
                [.withFullDate]
            ]
            
            for option in isoOptions {
                isoFormatter.formatOptions = option
                if let date = isoFormatter.date(from: dateString) {
                    return date
                }
            }
            
            // Si todo falla, lanzar error descriptivo
            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "Cannot decode date string: '\(dateString)'. Expected format: yyyy-MM-dd'T'HH:mm:ss.SSSSSSZ"
            )
        }
        return decoder
    }()
    
    // MARK: - Public Methods for Members
    
    func clearCurrentSurvey() {
        print("🧹 Clearing survey data from service")
        currentSurvey = nil
        currentQuestions = []
        currentResponse = nil
        successMessage = nil
        errorMessage = nil
    }
    
    func refreshSurveysIfNeeded() async {
        if needsSurveyRefresh {
            print("🔄 Refreshing surveys after completion")
            needsSurveyRefresh = false
            await getAvailableSurveys()
        }
    }
    
    func isPublishingSurvey(_ surveyId: Int) -> Bool {
        return publishingIds.contains(surveyId)
    }
    
    func getAvailableSurveys() async {
        guard let token = await authService?.getValidAccessToken(),
              let gymId = gymService?.currentGymId else {
            errorMessage = "Authentication required"
            return
        }
        
        isLoading = true
        errorMessage = nil
        
        print("📤 Getting Available Surveys:")
        print("   URL: \(baseURL)/surveys/available")
        print("   Gym ID: \(gymId)")
        
        do {
            var request = URLRequest(url: URL(string: "\(baseURL)/surveys/available")!)
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
            request.setValue("\(gymId)", forHTTPHeaderField: "X-Gym-ID")
            
            let (data, response) = try await URLSession.shared.data(for: request)
            
            if let httpResponse = response as? HTTPURLResponse {
                print("📥 Available Surveys Response: Status \(httpResponse.statusCode)")
                
                if httpResponse.statusCode == 200 {
                    // Decodificar las encuestas
                    let surveys = try customDateDecoder.decode([Survey].self, from: data)
                    self.availableSurveys = surveys
                    print("✅ Loaded \(surveys.count) available surveys for members")
                    
                    // Mostrar detalles de las encuestas cargadas
                    for survey in surveys {
                        print("   📝 Survey: \(survey.title) - Status: \(survey.status.rawValue)")
                    }
                } else if httpResponse.statusCode == 401 {
                    // Token refresh is handled in getValidAccessToken
                    await getAvailableSurveys()
                } else {
                    if let errorString = String(data: data, encoding: .utf8) {
                        print("🔴 Error Response: \(errorString)")
                    }
                    errorMessage = "Failed to fetch surveys: HTTP \(httpResponse.statusCode)"
                    print("🔴 Failed to fetch available surveys: HTTP \(httpResponse.statusCode)")
                }
            }
        } catch {
            errorMessage = "Failed to fetch surveys: \(error.localizedDescription)"
            print("🔴 Error fetching available surveys: \(error)")
            print("Error fetching surveys: \(error)")
        }
        
        isLoading = false
    }
    
    func getSurveyDetails(surveyId: Int) async {
        guard let token = await authService?.getValidAccessToken(),
              let gymId = gymService?.currentGymId else {
            errorMessage = "Authentication required"
            print("❌ Cannot get survey details: No authentication")
            return
        }
        
        // Clear previous data
        print("🧹 Clearing previous survey data...")
        self.currentQuestions = []
        self.currentSurvey = nil
        
        isLoading = true
        errorMessage = nil
        
        print("📤 Getting Survey Details:")
        print("   URL: \(baseURL)/surveys/\(surveyId)")
        print("   Gym ID: \(gymId)")
        
        do {
            var request = URLRequest(url: URL(string: "\(baseURL)/surveys/\(surveyId)")!)
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
            request.setValue("\(gymId)", forHTTPHeaderField: "X-Gym-ID")
            
            let (data, response) = try await URLSession.shared.data(for: request)
            
            if let httpResponse = response as? HTTPURLResponse {
                print("📥 Survey Details Response: Status \(httpResponse.statusCode)")
                
                if httpResponse.statusCode == 200 {
                    // El backend devuelve el survey con questions incluidas
                    let surveyWithQuestions = try customDateDecoder.decode(Survey.self, from: data)
                    self.currentSurvey = surveyWithQuestions
                    
                    // Extraer y ordenar las preguntas
                    if let questions = surveyWithQuestions.questions {
                        self.currentQuestions = questions.sorted { $0.order < $1.order }
                        print("✅ Loaded survey '\(surveyWithQuestions.title)' with \(questions.count) questions")
                        for question in questions {
                            print("   📝 Question \(question.order): \(question.questionText) (\(question.questionType.rawValue))")
                            if let choices = question.choices {
                                print("      Choices: \(choices.count)")
                            }
                        }
                    } else {
                        self.currentQuestions = []
                        print("⚠️ Survey has no questions")
                    }
                    
                    // Initialize empty response
                    self.currentResponse = SurveyResponse(
                        id: 0,
                        surveyId: surveyId,
                        userId: nil,
                        gymId: gymId,
                        startedAt: Date(),
                        completedAt: nil,
                        isComplete: false,
                        ipAddress: nil,
                        userAgent: nil,
                        eventId: nil,
                        answers: currentQuestions.map { SurveyAnswer(questionId: $0.id) }
                    )
                } else if httpResponse.statusCode == 401 {
                    // Token refresh is handled in getValidAccessToken
                    await getSurveyDetails(surveyId: surveyId)
                } else {
                    throw URLError(.badServerResponse)
                }
            }
        } catch {
            errorMessage = "Failed to fetch survey details: \(error.localizedDescription)"
            print("Error fetching survey details: \(error)")
        }
        
        isLoading = false
    }
    
    func submitSurveyResponse() async {
        guard let token = await authService?.getValidAccessToken(),
              let gymId = gymService?.currentGymId,
              let response = currentResponse,
              let surveyId = currentSurvey?.id else {
            errorMessage = "Invalid survey data"
            print("❌ Cannot submit survey: Missing required data")
            return
        }
        
        isLoading = true
        errorMessage = nil
        
        print("📤 Submitting Survey Response:")
        print("   URL: \(baseURL)/surveys/responses")
        print("   Survey ID: \(surveyId)")
        print("   Gym ID: \(gymId)")
        print("   Answers count: \(response.answers?.count ?? 0)")
        
        do {
            // Convertir las respuestas al formato esperado por el backend
            let answerRequests = (response.answers ?? []).map { answer in
                AnswerRequest(
                    questionId: answer.questionId,
                    textAnswer: answer.textAnswer,
                    choiceId: answer.choiceId,
                    choiceIds: answer.choiceIds,
                    numberAnswer: answer.numberAnswer,
                    dateAnswer: answer.dateAnswer,
                    booleanAnswer: answer.booleanAnswer,
                    otherText: answer.otherText
                )
            }
            
            let submitRequest = SurveyResponseRequest(
                surveyId: surveyId,
                eventId: response.eventId,
                answers: answerRequests
            )
            
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            let bodyData = try encoder.encode(submitRequest)
            
            // Log del request body para debugging
            if let jsonString = String(data: bodyData, encoding: .utf8) {
                print("📋 Request Body:")
                print(jsonString)
            }
            
            var request = URLRequest(url: URL(string: "\(baseURL)/surveys/responses")!)
            request.httpMethod = "POST"
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
            request.setValue("\(gymId)", forHTTPHeaderField: "X-Gym-ID")
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.httpBody = bodyData
            
            let (data, response) = try await URLSession.shared.data(for: request)
            
            if let httpResponse = response as? HTTPURLResponse {
                print("📬 Submit Response Status: \(httpResponse.statusCode)")
                
                if httpResponse.statusCode == 200 || httpResponse.statusCode == 201 {
                    print("✅ Survey submitted successfully")
                    
                    // Log raw response for debugging
                    if let responseString = String(data: data, encoding: .utf8) {
                        print("📋 Success Response Body:")
                        print(responseString)
                    }
                    
                    // Try to decode the response
                    do {
                        let decoder = JSONDecoder()
                        let submitResponse = try decoder.decode(SubmitSurveyResponse.self, from: data)
                        successMessage = submitResponse.message
                    } catch {
                        // If decoding fails, just set a default success message
                        print("⚠️ Could not decode response but submission was successful")
                        successMessage = "Survey submitted successfully!"
                    }
                    
                    // Don't clear survey data here - let the view handle it
                    // This allows the completion screen to show properly
                    
                    // Don't refresh available surveys immediately - let the view handle this
                    // after the completion screen is dismissed to avoid closing the sheet prematurely
                    needsSurveyRefresh = true
                    print("📌 Survey refresh scheduled for after completion screen dismissal")
                } else if httpResponse.statusCode == 401 {
                    print("🔑 Token expired, refreshing...")
                    // Token refresh is handled in getValidAccessToken
                    await submitSurveyResponse()
                } else {
                    // Log the raw response for debugging
                    if let responseString = String(data: data, encoding: .utf8) {
                        print("❌ Error Response Body:")
                        print(responseString)
                    }
                    
                    let errorData = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
                    let errorDetail = errorData?["detail"] as? String ?? errorData?["message"] as? String
                    
                    print("🔴 Submit failed with status \(httpResponse.statusCode): \(errorDetail ?? "Unknown error")")
                    
                    throw NSError(domain: "", code: httpResponse.statusCode, 
                                 userInfo: [NSLocalizedDescriptionKey: errorDetail ?? "Failed to submit survey"])
                }
            }
        } catch {
            errorMessage = "Failed to submit survey: \(error.localizedDescription)"
            print("🔴 Error submitting survey: \(error)")
            print("   Error details: \(error.localizedDescription)")
        }
        
        isLoading = false
    }
    
    func getMyResponses() async {
        guard let token = await authService?.getValidAccessToken(),
              let gymId = gymService?.currentGymId else {
            errorMessage = "Authentication required"
            return
        }
        
        isLoading = true
        errorMessage = nil
        
        do {
            var request = URLRequest(url: URL(string: "\(baseURL)/surveys/my-responses")!)
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
            request.setValue("\(gymId)", forHTTPHeaderField: "X-Gym-ID")
            
            let (data, response) = try await URLSession.shared.data(for: request)
            
            if let httpResponse = response as? HTTPURLResponse {
                if httpResponse.statusCode == 200 {
                    // Usar custom decoder para manejar fechas con microsegundos
                    let responses = try customDateDecoder.decode([SurveyResponse].self, from: data)
                    self.myResponses = responses
                } else if httpResponse.statusCode == 401 {
                    // Token refresh is handled in getValidAccessToken
                    await getMyResponses()
                } else {
                    throw URLError(.badServerResponse)
                }
            }
        } catch {
            errorMessage = "Failed to fetch responses: \(error.localizedDescription)"
            print("Error fetching responses: \(error)")
        }
        
        isLoading = false
    }
    
    // MARK: - Statistics & Analytics Methods
    
    func getSurveyStatistics(surveyId: Int) async -> SurveyStatistics? {
        guard let token = await authService?.getValidAccessToken(),
              let gymId = gymService?.currentGymId else {
            errorMessage = "Authentication required"
            return nil
        }
        
        isLoading = true
        errorMessage = nil
        
        do {
            var request = URLRequest(url: URL(string: "\(baseURL)/surveys/\(surveyId)/statistics")!)
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
            request.setValue("\(gymId)", forHTTPHeaderField: "X-Gym-ID")
            
            let (data, response) = try await URLSession.shared.data(for: request)
            
            if let httpResponse = response as? HTTPURLResponse {
                if httpResponse.statusCode == 200 {
                    // Try to parse and fix very small numbers that cause issues
                    if var jsonObject = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                        // Function to clean numeric values recursively
                        func cleanNumericValues(_ value: Any) -> Any {
                            if let dict = value as? [String: Any] {
                                return dict.mapValues { cleanNumericValues($0) }
                            } else if let array = value as? [Any] {
                                return array.map { cleanNumericValues($0) }
                            } else if let number = value as? Double {
                                // Round very small numbers to zero
                                if abs(number) < 0.000001 {
                                    return 0.0
                                }
                                // Handle potential infinity or NaN
                                if number.isInfinite || number.isNaN {
                                    return 0.0
                                }
                                return number
                            }
                            return value
                        }
                        
                        // Clean the JSON object
                        jsonObject = cleanNumericValues(jsonObject) as? [String: Any] ?? jsonObject
                        
                        // Convert back to Data
                        let cleanedData = try JSONSerialization.data(withJSONObject: jsonObject)
                        let statistics = try customDateDecoder.decode(SurveyStatistics.self, from: cleanedData)
                        isLoading = false
                        return statistics
                    } else {
                        // Fallback to original decoding
                        let statistics = try customDateDecoder.decode(SurveyStatistics.self, from: data)
                        isLoading = false
                        return statistics
                    }
                } else if httpResponse.statusCode == 401 {
                    // Token refresh is handled in getValidAccessToken
                    return await getSurveyStatistics(surveyId: surveyId)
                } else if httpResponse.statusCode == 403 {
                    errorMessage = "You don't have permission to view survey statistics"
                } else {
                    let errorData = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
                    let errorDetail = errorData?["detail"] as? String
                    errorMessage = errorDetail ?? "Failed to fetch statistics"
                }
            }
        } catch {
            errorMessage = "Failed to fetch statistics: \(error.localizedDescription)"
            print("🔴 Error fetching statistics: \(error)")
        }
        
        isLoading = false
        return nil
    }
    
    func getSurveyResponses(surveyId: Int, onlyComplete: Bool = true, skip: Int = 0, limit: Int = 100) async -> [ResponseWithAnswers] {
        guard let token = await authService?.getValidAccessToken(),
              let gymId = gymService?.currentGymId else {
            errorMessage = "Authentication required"
            return []
        }
        
        isLoading = true
        errorMessage = nil
        
        do {
            var urlComponents = URLComponents(string: "\(baseURL)/surveys/\(surveyId)/responses")!
            urlComponents.queryItems = [
                URLQueryItem(name: "skip", value: String(skip)),
                URLQueryItem(name: "limit", value: String(limit)),
                URLQueryItem(name: "only_complete", value: String(onlyComplete))
            ]
            
            var request = URLRequest(url: urlComponents.url!)
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
            request.setValue("\(gymId)", forHTTPHeaderField: "X-Gym-ID")
            
            let (data, response) = try await URLSession.shared.data(for: request)
            
            if let httpResponse = response as? HTTPURLResponse {
                if httpResponse.statusCode == 200 {
                    let responses = try customDateDecoder.decode([ResponseWithAnswers].self, from: data)
                    isLoading = false
                    return responses
                } else if httpResponse.statusCode == 401 {
                    // Token refresh is handled in getValidAccessToken
                    return await getSurveyResponses(surveyId: surveyId, onlyComplete: onlyComplete, skip: skip, limit: limit)
                } else if httpResponse.statusCode == 403 {
                    errorMessage = "You don't have permission to view survey responses"
                } else {
                    let errorData = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
                    let errorDetail = errorData?["detail"] as? String
                    errorMessage = errorDetail ?? "Failed to fetch responses"
                }
            }
        } catch {
            errorMessage = "Failed to fetch responses: \(error.localizedDescription)"
            print("🔴 Error fetching responses: \(error)")
        }
        
        isLoading = false
        return []
    }
    
    func exportSurveyResults(surveyId: Int, format: String = "excel") async -> URL? {
        guard let token = await authService?.getValidAccessToken(),
              let gymId = gymService?.currentGymId else {
            errorMessage = "Authentication required"
            return nil
        }
        
        isLoading = true
        errorMessage = nil
        
        do {
            var urlComponents = URLComponents(string: "\(baseURL)/surveys/\(surveyId)/export")!
            urlComponents.queryItems = [
                URLQueryItem(name: "format", value: format)
            ]
            
            var request = URLRequest(url: urlComponents.url!)
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
            request.setValue("\(gymId)", forHTTPHeaderField: "X-Gym-ID")
            
            let (data, response) = try await URLSession.shared.data(for: request)
            
            if let httpResponse = response as? HTTPURLResponse {
                if httpResponse.statusCode == 200 {
                    // Save file to temporary directory
                    let fileName = "survey_\(surveyId)_results_\(Date().timeIntervalSince1970).\(format == "excel" ? "xlsx" : "csv")"
                    let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(fileName)
                    
                    try data.write(to: tempURL)
                    isLoading = false
                    return tempURL
                } else if httpResponse.statusCode == 401 {
                    // Token refresh is handled in getValidAccessToken
                    return await exportSurveyResults(surveyId: surveyId, format: format)
                } else if httpResponse.statusCode == 403 {
                    errorMessage = "You don't have permission to export survey results"
                } else {
                    let errorData = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
                    let errorDetail = errorData?["detail"] as? String
                    errorMessage = errorDetail ?? "Failed to export results"
                }
            }
        } catch {
            errorMessage = "Failed to export results: \(error.localizedDescription)"
            print("🔴 Error exporting results: \(error)")
        }
        
        isLoading = false
        return nil
    }
    
    // MARK: - Admin Methods
    
    func getMySurveys(statusFilter: SurveyStatus? = nil, skip: Int = 0, limit: Int = 100) async {
        guard let token = await authService?.getValidAccessToken(),
              let gymId = gymService?.currentGymId else {
            errorMessage = "Authentication required"
            return
        }
        
        isLoading = true
        errorMessage = nil
        
        print("📤 Getting My Surveys:")
        print("   URL: \(baseURL)/surveys/my-surveys")
        print("   Gym ID: \(gymId)")
        if let status = statusFilter {
            print("   Status Filter: \(status)")
        }
        
        do {
            var urlString = "\(baseURL)/surveys/my-surveys?skip=\(skip)&limit=\(limit)"
            if let status = statusFilter {
                urlString += "&status_filter=\(status.rawValue)"
            }
            
            var request = URLRequest(url: URL(string: urlString)!)
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
            request.setValue("\(gymId)", forHTTPHeaderField: "X-Gym-ID")
            
            let (data, response) = try await URLSession.shared.data(for: request)
            
            if let httpResponse = response as? HTTPURLResponse {
                print("📥 My Surveys Response: Status \(httpResponse.statusCode)")
                
                if httpResponse.statusCode == 200 {
                    // Log raw response para debug
                    if let jsonString = String(data: data, encoding: .utf8) {
                        print("📋 Raw Response (first 1500 chars):")
                        print(String(jsonString.prefix(1500)))
                    }
                    
                    // Usar custom decoder para manejar fechas con microsegundos
                    let surveys = try customDateDecoder.decode([Survey].self, from: data)
                    
                    await MainActor.run {
                        self.availableSurveys = surveys
                        self.isLoading = false
                        print("✅ Loaded \(surveys.count) surveys created by current user")
                        
                        // Debug: mostrar response count de cada survey
                        for survey in surveys {
                            print("   📊 Survey '\(survey.title)': responsesCount=\(survey.responsesCount ?? -1)")
                        }
                    }
                } else {
                    if let errorString = String(data: data, encoding: .utf8) {
                        print("🔴 Error Response: \(errorString)")
                    }
                    await MainActor.run {
                        self.errorMessage = "Failed to fetch your surveys"
                        self.isLoading = false
                    }
                }
            }
        } catch {
            await MainActor.run {
                self.errorMessage = "Error fetching your surveys: \(error.localizedDescription)"
                self.isLoading = false
                print("🔴 Error fetching my surveys: \(error)")
            }
        }
    }
    
    func createSurvey(createRequest: SurveyCreateRequest) async -> Survey? {
        guard let token = await authService?.getValidAccessToken(),
              let gymId = gymService?.currentGymId else {
            errorMessage = "Authentication required"
            print("🔴 Survey Creation Failed: Missing authentication or gym ID")
            return nil
        }
        
        isLoading = true
        errorMessage = nil
        
        do {
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            let bodyData = try encoder.encode(createRequest)
            
            // Log request details
            print("📤 Creating Survey:")
            print("   URL: \(baseURL)/surveys/")
            print("   Gym ID: \(gymId)")
            print("   Title: \(createRequest.title)")
            print("   Questions: \(createRequest.questions.count)")
            if let jsonString = String(data: bodyData, encoding: .utf8) {
                print("   Request Body: \(jsonString)")
            }
            
            var request = URLRequest(url: URL(string: "\(baseURL)/surveys/")!)
            request.httpMethod = "POST"
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
            request.setValue("\(gymId)", forHTTPHeaderField: "X-Gym-ID")
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.httpBody = bodyData
            
            let (data, response) = try await URLSession.shared.data(for: request)
            
            if let httpResponse = response as? HTTPURLResponse {
                print("📥 Survey Creation Response: Status \(httpResponse.statusCode)")
                
                if httpResponse.statusCode == 200 || httpResponse.statusCode == 201 {
                    // Usar custom decoder para manejar fechas con microsegundos
                    let createdSurvey = try customDateDecoder.decode(Survey.self, from: data)
                    
                    print("✅ Survey created successfully: ID \(createdSurvey.id)")
                    successMessage = "Survey created successfully"
                    await getAvailableSurveys()
                    return createdSurvey
                    
                } else if httpResponse.statusCode == 422 {
                    // Validation error
                    if let errorResponse = String(data: data, encoding: .utf8) {
                        print("🔴 Validation Error: \(errorResponse)")
                        errorMessage = "Validation error: \(errorResponse)"
                    }
                } else if httpResponse.statusCode == 401 {
                    print("🔄 Token expired, retrying...")
                    // Token refresh is handled in getValidAccessToken
                    return await createSurvey(createRequest: createRequest)
                } else {
                    if let errorResponse = String(data: data, encoding: .utf8) {
                        print("🔴 Server Error: \(errorResponse)")
                        errorMessage = "Server error: \(errorResponse)"
                    }
                    throw URLError(.badServerResponse)
                }
            }
        } catch {
            errorMessage = "Failed to create survey: \(error.localizedDescription)"
            print("🔴 Error creating survey: \(error)")
        }
        
        isLoading = false
        return nil
    }
    
    func publishSurvey(surveyId: Int) async -> Bool {
        // Check if already publishing this survey
        if publishingIds.contains(surveyId) {
            print("⚠️ Survey \(surveyId) is already being published")
            return false
        }
        
        guard let token = await authService?.getValidAccessToken(),
              let gymId = gymService?.currentGymId else {
            errorMessage = "Authentication required"
            print("🔴 Survey Publish Failed: Missing authentication or gym ID")
            return false
        }
        
        // Mark as publishing
        publishingIds.insert(surveyId)
        isPublishing = true
        errorMessage = nil
        
        print("📤 Publishing Survey ID: \(surveyId)")
        print("   URL: \(baseURL)/surveys/\(surveyId)/publish")
        
        do {
            var request = URLRequest(url: URL(string: "\(baseURL)/surveys/\(surveyId)/publish")!)
            request.httpMethod = "POST"
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
            request.setValue("\(gymId)", forHTTPHeaderField: "X-Gym-ID")
            
            let (data, response) = try await URLSession.shared.data(for: request)
            
            if let httpResponse = response as? HTTPURLResponse {
                print("📥 Survey Publish Response: Status \(httpResponse.statusCode)")
                
                if httpResponse.statusCode == 200 {
                    print("✅ Survey published successfully")
                    successMessage = "Survey published successfully"
                    await getAvailableSurveys()
                    // Clean up publishing state
                    publishingIds.remove(surveyId)
                    isPublishing = false
                    return true
                } else if httpResponse.statusCode == 401 {
                    print("🔄 Token expired, retrying...")
                    // Clean up state before retry
                    publishingIds.remove(surveyId)
                    isPublishing = false
                    // Token refresh is handled in getValidAccessToken
                    return await publishSurvey(surveyId: surveyId)
                } else {
                    if let errorResponse = String(data: data, encoding: .utf8) {
                        print("🔴 Publish Error: \(errorResponse)")
                        errorMessage = "Failed to publish: \(errorResponse)"
                    }
                    throw URLError(.badServerResponse)
                }
            }
        } catch {
            errorMessage = "Failed to publish survey: \(error.localizedDescription)"
            print("🔴 Error publishing survey: \(error)")
        }
        
        // Clean up publishing state on failure
        publishingIds.remove(surveyId)
        isPublishing = false
        return false
    }
    
    func closeSurvey(surveyId: Int) async {
        guard let token = await authService?.getValidAccessToken(),
              let gymId = gymService?.currentGymId else {
            errorMessage = "Authentication required"
            return
        }
        
        isLoading = true
        errorMessage = nil
        
        do {
            var request = URLRequest(url: URL(string: "\(baseURL)/surveys/\(surveyId)/close")!)
            request.httpMethod = "POST"
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
            request.setValue("\(gymId)", forHTTPHeaderField: "X-Gym-ID")
            
            let (_, response) = try await URLSession.shared.data(for: request)
            
            if let httpResponse = response as? HTTPURLResponse {
                if httpResponse.statusCode == 200 {
                    successMessage = "Survey closed successfully"
                    await getAvailableSurveys()
                } else if httpResponse.statusCode == 401 {
                    // Token refresh is handled in getValidAccessToken
                    await closeSurvey(surveyId: surveyId)
                } else {
                    throw URLError(.badServerResponse)
                }
            }
        } catch {
            errorMessage = "Failed to close survey: \(error.localizedDescription)"
            print("Error closing survey: \(error)")
        }
        
        isLoading = false
    }
    
    
    func exportSurveyData(surveyId: Int, format: String = "csv") async -> URL? {
        guard let token = await authService?.getValidAccessToken(),
              let gymId = gymService?.currentGymId else {
            errorMessage = "Authentication required"
            return nil
        }
        
        isLoading = true
        errorMessage = nil
        
        do {
            var request = URLRequest(url: URL(string: "\(baseURL)/surveys/\(surveyId)/export?format=\(format)")!)
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
            request.setValue("\(gymId)", forHTTPHeaderField: "X-Gym-ID")
            
            let (data, response) = try await URLSession.shared.data(for: request)
            
            if let httpResponse = response as? HTTPURLResponse {
                if httpResponse.statusCode == 200 {
                    // Save to temporary file
                    let tempDir = FileManager.default.temporaryDirectory
                    let fileName = "survey_\(surveyId)_\(Date().timeIntervalSince1970).\(format)"
                    let fileURL = tempDir.appendingPathComponent(fileName)
                    
                    try data.write(to: fileURL)
                    isLoading = false
                    return fileURL
                } else if httpResponse.statusCode == 401 {
                    // Token refresh is handled in getValidAccessToken
                    return await exportSurveyData(surveyId: surveyId, format: format)
                } else {
                    throw URLError(.badServerResponse)
                }
            }
        } catch {
            errorMessage = "Failed to export survey data: \(error.localizedDescription)"
            print("Error exporting survey data: \(error)")
        }
        
        isLoading = false
        return nil
    }
    
    // MARK: - Templates
    
    func getTemplates() async {
        guard let token = await authService?.getValidAccessToken(),
              let gymId = gymService?.currentGymId else {
            errorMessage = "Authentication required"
            return
        }
        
        isLoading = true
        errorMessage = nil
        
        do {
            var request = URLRequest(url: URL(string: "\(baseURL)/surveys/templates")!)
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
            request.setValue("\(gymId)", forHTTPHeaderField: "X-Gym-ID")
            
            let (data, response) = try await URLSession.shared.data(for: request)
            
            if let httpResponse = response as? HTTPURLResponse {
                if httpResponse.statusCode == 200 {
                    // Usar custom decoder para manejar fechas con microsegundos
                    let templates = try customDateDecoder.decode([SurveyTemplate].self, from: data)
                    self.surveyTemplates = templates
                } else if httpResponse.statusCode == 401 {
                    // Token refresh is handled in getValidAccessToken
                    await getTemplates()
                } else {
                    throw URLError(.badServerResponse)
                }
            }
        } catch {
            errorMessage = "Failed to fetch templates: \(error.localizedDescription)"
            print("Error fetching templates: \(error)")
        }
        
        isLoading = false
    }
    
    func createSurveyFromTemplate(templateId: Int) async {
        guard let token = await authService?.getValidAccessToken(),
              let gymId = gymService?.currentGymId else {
            errorMessage = "Authentication required"
            return
        }
        
        isLoading = true
        errorMessage = nil
        
        do {
            var request = URLRequest(url: URL(string: "\(baseURL)/surveys/from-template/\(templateId)")!)
            request.httpMethod = "POST"
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
            request.setValue("\(gymId)", forHTTPHeaderField: "X-Gym-ID")
            
            let (_, response) = try await URLSession.shared.data(for: request)
            
            if let httpResponse = response as? HTTPURLResponse {
                if httpResponse.statusCode == 200 || httpResponse.statusCode == 201 {
                    successMessage = "Survey created from template successfully"
                    await getAvailableSurveys()
                } else if httpResponse.statusCode == 401 {
                    // Token refresh is handled in getValidAccessToken
                    await createSurveyFromTemplate(templateId: templateId)
                } else {
                    throw URLError(.badServerResponse)
                }
            }
        } catch {
            errorMessage = "Failed to create survey from template: \(error.localizedDescription)"
            print("Error creating survey from template: \(error)")
        }
        
        isLoading = false
    }
    
    // MARK: - Helper Methods
    
    func updateAnswer(questionId: Int, answer: SurveyAnswer) {
        guard var response = currentResponse,
              var answers = response.answers else { return }
        
        if let index = answers.firstIndex(where: { $0.questionId == questionId }) {
            answers[index] = answer
        } else {
            answers.append(answer)
        }
        
        response.answers = answers
        currentResponse = response
    }
    
    func getAnswer(for questionId: Int) -> SurveyAnswer? {
        return currentResponse?.answers?.first { $0.questionId == questionId }
    }
    
    func validateCurrentAnswers() -> Bool {
        guard let questions = currentQuestions.isEmpty ? nil : currentQuestions,
              let answers = currentResponse?.answers else { return false }
        
        for question in questions where question.isRequired {
            guard let answer = answers.first(where: { $0.questionId == question.id }) else {
                return false
            }
            
            // Check if answer has content based on question type
            switch question.questionType {
            case .text, .textarea, .email, .phone:
                if answer.textAnswer?.isEmpty ?? true {
                    return false
                }
            case .radio, .select:
                if answer.choiceId == nil {
                    return false
                }
            case .checkbox:
                if answer.choiceIds?.isEmpty ?? true {
                    return false
                }
            case .scale, .number, .nps:
                if answer.numberAnswer == nil {
                    return false
                }
            case .date:
                if answer.dateAnswer == nil {
                    return false
                }
            case .time:
                if answer.textAnswer?.isEmpty ?? true {
                    return false
                }
            case .yesNo:
                if answer.booleanAnswer == nil {
                    return false
                }
            }
        }
        
        return true
    }
    
    // MARK: - Update Survey
    func updateSurvey(surveyId: Int, updateRequest: SurveyCreateRequest) async -> Survey? {
        guard let token = await authService?.getValidAccessToken(),
              let gymId = gymService?.currentGymId else {
            errorMessage = "Authentication required"
            print("🔴 Survey Update Failed: Missing authentication or gym ID")
            return nil
        }
        
        isLoading = true
        errorMessage = nil
        
        print("📤 Updating Survey:")
        print("   URL: \(baseURL)/surveys/\(surveyId)")
        print("   Gym ID: \(gymId)")
        
        var request = URLRequest(url: URL(string: "\(baseURL)/surveys/\(surveyId)")!)
        request.httpMethod = "PUT"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("\(gymId)", forHTTPHeaderField: "X-Gym-ID")
        
        do {
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            request.httpBody = try encoder.encode(updateRequest)
            
            let (data, response) = try await URLSession.shared.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                throw URLError(.badServerResponse)
            }
            
            print("📥 Update Survey Response: Status \(httpResponse.statusCode)")
            
            if httpResponse.statusCode == 200 {
                let updatedSurvey = try customDateDecoder.decode(Survey.self, from: data)
                print("✅ Survey updated successfully: \(updatedSurvey.title)")
                successMessage = "Survey updated successfully"
                isLoading = false
                return updatedSurvey
            } else {
                let errorString = String(data: data, encoding: .utf8) ?? "Unknown error"
                print("🔴 Update Survey Error: \(errorString)")
                errorMessage = "Failed to update survey: \(errorString)"
                isLoading = false
                return nil
            }
        } catch {
            print("🔴 Update Survey Exception: \(error)")
            errorMessage = "Failed to update survey: \(error.localizedDescription)"
            isLoading = false
            return nil
        }
    }
    
    // MARK: - Delete Survey
    func deleteSurvey(surveyId: Int) async -> Bool {
        guard let token = await authService?.getValidAccessToken(),
              let gymId = gymService?.currentGymId else {
            errorMessage = "Authentication required"
            print("🔴 Survey Delete Failed: Missing authentication or gym ID")
            return false
        }
        
        isLoading = true
        errorMessage = nil
        
        print("📤 Deleting Survey:")
        print("   URL: \(baseURL)/surveys/\(surveyId)")
        print("   Gym ID: \(gymId)")
        
        var request = URLRequest(url: URL(string: "\(baseURL)/surveys/\(surveyId)")!)
        request.httpMethod = "DELETE"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("\(gymId)", forHTTPHeaderField: "X-Gym-ID")
        
        do {
            let (_, response) = try await URLSession.shared.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                throw URLError(.badServerResponse)
            }
            
            print("📥 Delete Survey Response: Status \(httpResponse.statusCode)")
            
            if httpResponse.statusCode == 204 || httpResponse.statusCode == 200 {
                print("✅ Survey deleted successfully")
                successMessage = "Survey deleted successfully"
                
                // Remove from local arrays if present
                availableSurveys.removeAll { $0.id == surveyId }
                
                isLoading = false
                return true
            } else {
                print("🔴 Delete Survey Error: Status \(httpResponse.statusCode)")
                errorMessage = "Failed to delete survey"
                isLoading = false
                return false
            }
        } catch {
            print("🔴 Delete Survey Exception: \(error)")
            errorMessage = "Failed to delete survey: \(error.localizedDescription)"
            isLoading = false
            return false
        }
    }

    deinit {
        #if DEBUG
        print("🗑️ SurveyService deinitialized")
        #endif
        // Los datos de encuestas se limpiarán automáticamente con ARC
        // No podemos modificar propiedades @Published desde deinit en una clase @MainActor
    }
}