//
//  User.swift
//  Gym_API
//
//  Created by Alex Montesino on 7/14/25.
//

import Foundation
import SwiftData

@Model
final class User {
    var id: String
    var email: String
    var name: String
    var picture: String?
    var isCoach: Bool
    var bio: String?
    var weight: Double?
    var height: String?
    var age: Int?
    var createdAt: Date
    var lastLogin: Date?
    
    init(id: String, email: String, name: String, picture: String? = nil, isCoach: Bool = false, bio: String? = nil, weight: Double? = nil, height: String? = nil, age: Int? = nil) {
        self.id = id
        self.email = email
        self.name = name
        self.picture = picture
        self.isCoach = isCoach
        self.bio = bio
        self.weight = weight
        self.height = height
        self.age = age
        self.createdAt = Date()
        self.lastLogin = nil
    }
} 