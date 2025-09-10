import Foundation

// MARK: - Survey Status
enum SurveyStatus: String, Codable, CaseIterable {
    case draft = "DRAFT"
    case published = "PUBLISHED"
    case closed = "CLOSED"
    case archived = "ARCHIVED"
    
    var displayName: String {
        switch self {
        case .draft: return "Draft"
        case .published: return "Published"
        case .closed: return "Closed"
        case .archived: return "Archived"
        }
    }
    
    var color: String {
        switch self {
        case .draft: return "gray"
        case .published: return "green"
        case .closed: return "orange"
        case .archived: return "red"
        }
    }
}

// MARK: - Question Type
enum QuestionType: String, Codable, CaseIterable {
    case text = "TEXT"
    case textarea = "TEXTAREA"
    case radio = "RADIO"
    case checkbox = "CHECKBOX"
    case select = "SELECT"
    case scale = "SCALE"
    case date = "DATE"
    case time = "TIME"
    case number = "NUMBER"
    case email = "EMAIL"
    case phone = "PHONE"
    case yesNo = "YES_NO"
    case nps = "NPS"
    
    var displayName: String {
        switch self {
        case .text: return "Short Text"
        case .textarea: return "Long Text"
        case .radio: return "Single Choice"
        case .checkbox: return "Multiple Choice"
        case .select: return "Dropdown"
        case .scale: return "Scale"
        case .date: return "Date"
        case .time: return "Time"
        case .number: return "Number"
        case .email: return "Email"
        case .phone: return "Phone"
        case .yesNo: return "Yes/No"
        case .nps: return "Net Promoter Score"
        }
    }
    
    var icon: String {
        switch self {
        case .text: return "text.cursor"
        case .textarea: return "text.align.left"
        case .radio: return "circle"
        case .checkbox: return "checkmark.square"
        case .select: return "chevron.down.circle"
        case .scale: return "slider.horizontal.below.rectangle"
        case .date: return "calendar"
        case .time: return "clock"
        case .number: return "number"
        case .email: return "envelope"
        case .phone: return "phone"
        case .yesNo: return "hand.thumbsup"
        case .nps: return "star"
        }
    }
}

// MARK: - Survey Model
struct Survey: Codable, Identifiable {
    let id: Int
    let gymId: Int
    let creatorId: Int?
    let title: String
    let description: String?
    let status: SurveyStatus
    let startDate: Date?
    let endDate: Date?
    let isAnonymous: Bool
    let allowMultiple: Bool
    let randomizeQuestions: Bool
    let showProgress: Bool
    let thankYouMessage: String?
    let tags: [String]?
    let targetAudience: String?
    let createdAt: Date
    let updatedAt: Date?  // Opcional porque puede ser null
    let publishedAt: Date?  // Campo que viene del backend
    let questionsCount: Int?
    let responsesCount: Int?
    let completionRate: Double?
    let estimatedTime: Int?
    let hasResponded: Bool?
    let questions: [SurveyQuestion]?  // Incluido cuando se pide el detalle
    
    private enum CodingKeys: String, CodingKey {
        case id
        case gymId = "gym_id"
        case creatorId = "creator_id"
        case title
        case description
        case status
        case startDate = "start_date"
        case endDate = "end_date"
        case isAnonymous = "is_anonymous"
        case allowMultiple = "allow_multiple"
        case randomizeQuestions = "randomize_questions"
        case showProgress = "show_progress"
        case thankYouMessage = "thank_you_message"
        case tags
        case targetAudience = "target_audience"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
        case publishedAt = "published_at"
        case questionsCount = "questions_count"
        case responsesCount = "response_count"  // Cambiado: la API devuelve response_count sin 's'
        case completionRate = "completion_rate"
        case estimatedTime = "estimated_time"
        case hasResponded = "has_responded"
        case questions
    }
    
    var isAvailable: Bool {
        guard status == .published else { return false }
        
        let now = Date()
        
        if let startDate = startDate, now < startDate {
            return false
        }
        
        if let endDate = endDate, now > endDate {
            return false
        }
        
        if !allowMultiple && (hasResponded ?? false) {
            return false
        }
        
        return true
    }
    
    var daysRemaining: Int? {
        guard let endDate = endDate else { return nil }
        let calendar = Calendar.current
        let components = calendar.dateComponents([.day], from: Date(), to: endDate)
        return components.day
    }
    
    var formattedEstimatedTime: String {
        guard let time = estimatedTime else { return "Unknown" }
        if time < 60 {
            return "\(time) min"
        } else {
            let hours = time / 60
            let minutes = time % 60
            if minutes == 0 {
                return "\(hours) hr"
            } else {
                return "\(hours) hr \(minutes) min"
            }
        }
    }
}

// MARK: - Survey Question
struct SurveyQuestion: Codable, Identifiable {
    let id: Int
    let surveyId: Int
    let questionText: String
    let questionType: QuestionType
    let isRequired: Bool
    let order: Int
    let helpText: String?
    let minValue: Double?
    let maxValue: Double?
    let minLength: Int?
    let maxLength: Int?
    let placeholder: String?
    let regexValidation: String?
    let regexErrorMessage: String?
    let dependsOnQuestionId: Int?
    let dependsOnAnswer: [String: AnyCodable]?
    let choices: [QuestionChoice]?
    let minSelections: Int?
    let maxSelections: Int?
    let allowOther: Bool?
    let decimalPlaces: Int?
    let step: Double?
    let labels: [String: String]?
    let minDate: Date?
    let maxDate: Date?
    let format: String?
    let createdAt: Date?
    let updatedAt: Date?
    
    private enum CodingKeys: String, CodingKey {
        case id
        case surveyId = "survey_id"
        case questionText = "question_text"
        case questionType = "question_type"
        case isRequired = "is_required"
        case order
        case helpText = "help_text"
        case minValue = "min_value"
        case maxValue = "max_value"
        case minLength = "min_length"
        case maxLength = "max_length"
        case placeholder
        case regexValidation = "regex_validation"
        case regexErrorMessage = "regex_error_message"
        case dependsOnQuestionId = "depends_on_question_id"
        case dependsOnAnswer = "depends_on_answer"
        case choices
        case minSelections = "min_selections"
        case maxSelections = "max_selections"
        case allowOther = "allow_other"
        case decimalPlaces = "decimal_places"
        case step
        case labels
        case minDate = "min_date"
        case maxDate = "max_date"
        case format
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}

// MARK: - Question Choice
struct QuestionChoice: Codable, Identifiable {
    let id: Int
    let questionId: Int
    let choiceText: String
    let choiceValue: String?  // Puede ser vacío o null
    let order: Int
    let nextQuestionId: Int?
    let createdAt: Date?  // Incluido en la respuesta
    
    private enum CodingKeys: String, CodingKey {
        case id
        case questionId = "question_id"
        case choiceText = "choice_text"
        case choiceValue = "choice_value"
        case order
        case nextQuestionId = "next_question_id"
        case createdAt = "created_at"
    }
}

// MARK: - Survey Response
struct SurveyResponse: Codable, Identifiable {
    let id: Int
    let surveyId: Int
    let userId: Int?
    let gymId: Int
    let startedAt: Date
    var completedAt: Date?
    var isComplete: Bool
    let ipAddress: String?
    let userAgent: String?
    let eventId: Int?
    var answers: [SurveyAnswer]?
    
    private enum CodingKeys: String, CodingKey {
        case id
        case surveyId = "survey_id"
        case userId = "user_id"
        case gymId = "gym_id"
        case startedAt = "started_at"
        case completedAt = "completed_at"
        case isComplete = "is_complete"
        case ipAddress = "ip_address"
        case userAgent = "user_agent"
        case eventId = "event_id"
        case answers
    }
    
    var completionTime: TimeInterval? {
        guard let completedAt = completedAt else { return nil }
        return completedAt.timeIntervalSince(startedAt)
    }
}

// MARK: - Survey Answer
struct SurveyAnswer: Codable, Identifiable {
    let id: Int?
    let responseId: Int?
    let questionId: Int
    var textAnswer: String?
    var choiceId: Int?
    var choiceIds: [Int]?
    var numberAnswer: Double?
    var dateAnswer: Date?
    var booleanAnswer: Bool?
    var otherText: String?
    
    private enum CodingKeys: String, CodingKey {
        case id
        case responseId = "response_id"
        case questionId = "question_id"
        case textAnswer = "text_answer"
        case choiceId = "choice_id"
        case choiceIds = "choice_ids"
        case numberAnswer = "number_answer"
        case dateAnswer = "date_answer"
        case booleanAnswer = "boolean_answer"
        case otherText = "other_text"
    }
    
    init(questionId: Int) {
        self.id = nil
        self.responseId = nil
        self.questionId = questionId
    }
}

// MARK: - Survey Template
struct SurveyTemplate: Codable, Identifiable {
    let id: Int
    let gymId: Int?
    let name: String
    let description: String?
    let category: String?
    let templateData: [String: AnyCodable]
    let isPublic: Bool
    let usageCount: Int
    let createdAt: Date
    let updatedAt: Date?
    
    // Computed properties for convenience
    var title: String { name }
    var questions: [TemplateQuestion] {
        // Parse questions from templateData if available
        if let questionsData = templateData["questions"]?.value as? [[String: Any]] {
            return questionsData.compactMap { dict in
                guard let text = dict["text"] as? String,
                      let typeStr = dict["type"] as? String,
                      let type = QuestionType(rawValue: typeStr) else { return nil }
                
                return TemplateQuestion(
                    id: dict["id"] as? Int ?? 0,
                    text: text,
                    type: type,
                    required: dict["required"] as? Bool ?? false,
                    options: dict["options"] as? [String],
                    order: dict["order"] as? Int ?? 0,
                    metadata: nil
                )
            }
        }
        return []
    }
    var isAnonymous: Bool {
        templateData["isAnonymous"]?.value as? Bool ?? false
    }
    var estimatedCompletionTime: Int? {
        templateData["estimatedCompletionTime"]?.value as? Int
    }
    var isPopular: Bool {
        usageCount > 10
    }
    
    private enum CodingKeys: String, CodingKey {
        case id
        case gymId = "gym_id"
        case name
        case description
        case category
        case templateData = "template_data"
        case isPublic = "is_public"
        case usageCount = "usage_count"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}

// Template Question structure for templates
struct TemplateQuestion: Codable, Identifiable {
    let id: Int
    let text: String
    let type: QuestionType
    let required: Bool
    let options: [String]?
    let order: Int
    let metadata: [String: AnyCodable]?
}

// MARK: - Survey Statistics Models
struct SurveyStatistics: Codable {
    let surveyId: Int
    let totalResponses: Int
    let completeResponses: Int
    let incompleteResponses: Int
    let completionRate: Double?  // Hacerlo opcional ya que no siempre viene
    let averageCompletionTime: Int? // in seconds
    let lastResponseDate: Date?
    let questionStatistics: [QuestionStatistics]
    let npsScore: Double?
    let responsesByDate: [String: Int]? // Date string to count mapping
    
    private enum CodingKeys: String, CodingKey {
        case surveyId = "survey_id"
        case totalResponses = "total_responses"
        case completeResponses = "complete_responses"
        case incompleteResponses = "incomplete_responses"
        case completionRate = "completion_rate"
        case averageCompletionTime = "average_completion_time"
        case lastResponseDate = "last_response_date"
        case questionStatistics = "question_statistics"
        case npsScore = "nps_score"
        case responsesByDate = "responses_by_date"
    }
}

struct QuestionStatistics: Codable, Identifiable {
    let questionId: Int
    let questionText: String
    let questionType: String
    let responseCount: Int
    let statistics: StatisticsData
    
    var id: Int { questionId }
    
    private enum CodingKeys: String, CodingKey {
        case questionId = "question_id"
        case questionText = "question_text"
        case questionType = "question_type"
        case responseCount = "response_count"
        case statistics
    }
}

struct StatisticsData: Codable {
    // For numeric questions (SCALE, NUMBER, NPS)
    let average: Double?
    let median: Double?
    let mode: Double?
    let standardDeviation: Double?
    let min: Double?
    let max: Double?
    
    // For NPS specific
    let npsScore: Double?
    let promoters: Int?
    let passives: Int?
    let detractors: Int?
    
    // For choice questions (RADIO, CHECKBOX, SELECT)
    let distribution: [String: Int]? // Option to count mapping
    let percentages: [String: Double]? // Option to percentage mapping
    
    // For text questions
    let wordFrequency: [String: Int]? // Word to frequency mapping
    let topTerms: [String]?
    let sentimentScore: Double? // -1 to 1
    
    // For YES_NO questions
    let yesCount: Int?
    let noCount: Int?
    let yesPercentage: Double?
    
    private enum CodingKeys: String, CodingKey {
        case average, median, mode, min, max
        case standardDeviation = "std_dev"
        case npsScore = "nps_score"
        case promoters, passives, detractors
        case distribution, percentages
        case wordFrequency = "word_frequency"
        case topTerms = "top_terms"
        case sentimentScore = "sentiment_score"
        case yesCount = "yes_count"
        case noCount = "no_count"
        case yesPercentage = "yes_percentage"
    }
}

// MARK: - Response with Answers
struct ResponseWithAnswers: Codable, Identifiable {
    let id: Int
    let surveyId: Int
    let userId: Int?
    let eventId: Int?
    let isComplete: Bool
    let startedAt: Date
    let completedAt: Date?
    let ipAddress: String?
    let userAgent: String?
    let answers: [SurveyAnswer]
    let user: UserInfo?
    
    private enum CodingKeys: String, CodingKey {
        case id
        case surveyId = "survey_id"
        case userId = "user_id"
        case eventId = "event_id"
        case isComplete = "is_complete"
        case startedAt = "started_at"
        case completedAt = "completed_at"
        case ipAddress = "ip_address"
        case userAgent = "user_agent"
        case answers
        case user
    }
    
    var completionTime: Int? {
        guard let completedAt = completedAt else { return nil }
        return Int(completedAt.timeIntervalSince(startedAt))
    }
    
    var formattedCompletionTime: String {
        guard let time = completionTime else { return "Not completed" }
        let minutes = time / 60
        let seconds = time % 60
        return "\(minutes)m \(seconds)s"
    }
}

struct UserInfo: Codable {
    let id: Int
    let name: String?
    let email: String?
    let avatar: String?
}

// MARK: - AnyCodable Helper
struct AnyCodable: Codable {
    let value: Any
    
    init(_ value: Any) {
        self.value = value
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        
        if let value = try? container.decode(Bool.self) {
            self.value = value
        } else if let value = try? container.decode(Int.self) {
            self.value = value
        } else if let value = try? container.decode(Double.self) {
            self.value = value
        } else if let value = try? container.decode(String.self) {
            self.value = value
        } else if let value = try? container.decode([String: AnyCodable].self) {
            self.value = value.mapValues { $0.value }
        } else if let value = try? container.decode([AnyCodable].self) {
            self.value = value.map { $0.value }
        } else {
            self.value = NSNull()
        }
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        
        switch value {
        case let value as Bool:
            try container.encode(value)
        case let value as Int:
            try container.encode(value)
        case let value as Double:
            try container.encode(value)
        case let value as String:
            try container.encode(value)
        case let value as [String: Any]:
            try container.encode(value.mapValues { AnyCodable($0) })
        case let value as [Any]:
            try container.encode(value.map { AnyCodable($0) })
        default:
            try container.encodeNil()
        }
    }
}

// MARK: - API Response Models
struct SurveyListResponse: Codable {
    let surveys: [Survey]
    let total: Int
    let page: Int
    let pageSize: Int
    
    private enum CodingKeys: String, CodingKey {
        case surveys
        case total
        case page
        case pageSize = "page_size"
    }
}

struct SurveyDetailResponse: Codable {
    let survey: Survey
    let questions: [SurveyQuestion]
}

// MARK: - Survey Response Submit Request (formato esperado por el backend)
struct SurveyResponseRequest: Codable {
    let surveyId: Int
    let eventId: Int?
    let answers: [AnswerRequest]
    
    private enum CodingKeys: String, CodingKey {
        case surveyId = "survey_id"
        case eventId = "event_id"
        case answers
    }
}

// Formato de respuesta individual esperado por el backend
struct AnswerRequest: Codable {
    let questionId: Int
    let textAnswer: String?
    let choiceId: Int?
    let choiceIds: [Int]?
    let numberAnswer: Double?
    let dateAnswer: Date?
    let booleanAnswer: Bool?
    let otherText: String?
    
    private enum CodingKeys: String, CodingKey {
        case questionId = "question_id"
        case textAnswer = "text_answer"
        case choiceId = "choice_id"
        case choiceIds = "choice_ids"
        case numberAnswer = "number_answer"
        case dateAnswer = "date_answer"
        case booleanAnswer = "boolean_answer"
        case otherText = "other_text"
    }
}

// Mantener el antiguo por compatibilidad temporal
struct SubmitSurveyRequest: Codable {
    let surveyId: Int
    let answers: [SurveyAnswer]
    
    private enum CodingKeys: String, CodingKey {
        case surveyId = "survey_id"
        case answers
    }
}

struct SubmitSurveyResponse: Codable {
    let responseId: Int
    let message: String
    
    private enum CodingKeys: String, CodingKey {
        case responseId = "response_id"
        case message
    }
}

// MARK: - UI Support Models for Statistics
struct ResponseDataPoint: Identifiable {
    let id = UUID()
    let date: Date
    let count: Int
}

struct Demographics {
    let ageGroups: [AgeGroup]
    let genderDistribution: [GenderData]
}

struct AgeGroup {
    let group: String
    let count: Int
}

struct GenderData {
    let gender: String
    let count: Int
}

struct QuestionStatistic {
    let questionId: Int
    let questionText: String
    let questionType: QuestionType
    let responseCount: Int
    let averageScore: Double?
    let optionDistribution: [OptionDistribution]
    let textResponses: [String]
    
    init(from stats: QuestionStatistics) {
        self.questionId = stats.questionId
        self.questionText = stats.questionText
        // Convert string to QuestionType enum
        self.questionType = QuestionType(rawValue: stats.questionType) ?? .text
        self.responseCount = stats.responseCount
        
        // Get average score from statistics
        self.averageScore = stats.statistics.average
        
        // Parse option distribution from statistics
        if let distribution = stats.statistics.distribution,
           let percentages = stats.statistics.percentages {
            self.optionDistribution = distribution.map { key, count in
                let percentage = Int(percentages[key] ?? 0)
                return OptionDistribution(option: key, count: count, percentage: percentage)
            }
        } else {
            self.optionDistribution = []
        }
        
        // Parse text responses from top terms
        if let topTerms = stats.statistics.topTerms {
            self.textResponses = topTerms
        } else {
            self.textResponses = []
        }
    }
}

struct OptionDistribution {
    let option: String
    let count: Int
    let percentage: Int
}

// MARK: - Sample Data for Previews
extension Survey {
    static var sampleSurvey: Survey {
        Survey(
            id: 1,
            gymId: 1,
            creatorId: 1,
            title: "Customer Satisfaction Survey",
            description: "Help us improve",
            status: .published,
            startDate: nil,
            endDate: nil,
            isAnonymous: true,
            allowMultiple: false,
            randomizeQuestions: false,
            showProgress: true,
            thankYouMessage: "Thank you for your feedback!",
            tags: ["feedback", "customer"],
            targetAudience: "All members",
            createdAt: Date(),
            updatedAt: Date(),
            publishedAt: nil,
            questionsCount: 5,
            responsesCount: 10,
            completionRate: 80.0,
            estimatedTime: 5,
            hasResponded: false,
            questions: nil
        )
    }
}

// MARK: - API Request Models
struct SurveyCreateRequest: Codable {
    let title: String
    let description: String?
    let instructions: String?
    let startDate: Date?
    let endDate: Date?
    let isAnonymous: Bool
    let allowMultiple: Bool
    let randomizeQuestions: Bool
    let showProgress: Bool
    let thankYouMessage: String
    let tags: [String]
    let targetAudience: String?
    let questions: [QuestionCreateRequest]
    
    private enum CodingKeys: String, CodingKey {
        case title
        case description
        case instructions
        case startDate = "start_date"
        case endDate = "end_date"
        case isAnonymous = "is_anonymous"
        case allowMultiple = "allow_multiple"
        case randomizeQuestions = "randomize_questions"
        case showProgress = "show_progress"
        case thankYouMessage = "thank_you_message"
        case tags
        case targetAudience = "target_audience"
        case questions
    }
}

struct QuestionCreateRequest: Codable {
    let questionText: String
    let questionType: QuestionType
    let isRequired: Bool
    let order: Int
    let helpText: String?
    let placeholder: String?
    let minValue: Double?
    let maxValue: Double?
    let minLength: Int?
    let maxLength: Int?
    let allowOther: Bool
    let choices: [ChoiceCreateRequest]
    
    private enum CodingKeys: String, CodingKey {
        case questionText = "question_text"
        case questionType = "question_type"
        case isRequired = "is_required"
        case order
        case helpText = "help_text"
        case placeholder
        case minValue = "min_value"
        case maxValue = "max_value"
        case minLength = "min_length"
        case maxLength = "max_length"
        case allowOther = "allow_other"
        case choices
    }
}

struct ChoiceCreateRequest: Codable {
    let choiceText: String
    let choiceValue: String?
    let order: Int
    
    private enum CodingKeys: String, CodingKey {
        case choiceText = "choice_text"
        case choiceValue = "choice_value"
        case order
    }
}