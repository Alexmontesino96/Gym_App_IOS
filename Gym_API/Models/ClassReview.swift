import Foundation

// MARK: - Class Review Models

struct ClassReview: Codable, Identifiable {
    let id: Int
    let sessionId: Int
    let memberId: Int
    let gymId: Int
    let rating: Int
    let comment: String?
    let createdAt: Date
    let updatedAt: Date?
    let memberName: String?
    let className: String?
    let sessionDate: Date?

    enum CodingKeys: String, CodingKey {
        case id
        case sessionId = "session_id"
        case memberId = "member_id"
        case gymId = "gym_id"
        case rating, comment
        case createdAt = "created_at"
        case updatedAt = "updated_at"
        case memberName = "member_name"
        case className = "class_name"
        case sessionDate = "session_date"
    }
}

struct CanReviewResponse: Codable {
    let canReview: Bool
    let reason: String?

    enum CodingKeys: String, CodingKey {
        case canReview = "can_review"
        case reason
    }
}

struct SessionReviewsResponse: Codable {
    let reviews: [ClassReview]
    let total: Int
    let stats: ReviewStats
}

struct ReviewStats: Codable {
    let averageRating: Double
    let totalReviews: Int
    let ratingDistribution: [String: Int]

    enum CodingKeys: String, CodingKey {
        case averageRating = "average_rating"
        case totalReviews = "total_reviews"
        case ratingDistribution = "rating_distribution"
    }

    // Convenience: class/trainer info (optional, depends on endpoint)
    var className: String? { nil }
    var trainerName: String? { nil }
}

struct CreateReviewRequest: Codable {
    let sessionId: Int
    let rating: Int
    let comment: String?

    enum CodingKeys: String, CodingKey {
        case sessionId = "session_id"
        case rating, comment
    }
}

struct UpdateReviewRequest: Codable {
    let rating: Int?
    let comment: String?
}
