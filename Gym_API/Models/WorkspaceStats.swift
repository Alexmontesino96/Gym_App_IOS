//
//  WorkspaceStats.swift
//  Gym_API
//
//  Created by Claude Code on 2025-01-25
//

import Foundation

// MARK: - Workspace Stats Response
/// Respuesta de estadísticas del workspace
struct WorkspaceStatsResponse: Codable {
    let type: String
    let metrics: MetricsContainer

    enum CodingKeys: String, CodingKey {
        case type, metrics
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        type = try container.decode(String.self, forKey: .type)

        // Decodificar métricas según el tipo
        if type == "trainer" {
            let trainerMetrics = try container.decode(TrainerMetrics.self, forKey: .metrics)
            metrics = .trainer(trainerMetrics)
        } else {
            let gymMetrics = try container.decode(GymMetrics.self, forKey: .metrics)
            metrics = .gym(gymMetrics)
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(type, forKey: .type)

        switch metrics {
        case .trainer(let trainerMetrics):
            try container.encode(trainerMetrics, forKey: .metrics)
        case .gym(let gymMetrics):
            try container.encode(gymMetrics, forKey: .metrics)
        }
    }
}

// MARK: - Metrics Container
/// Contenedor de métricas que puede ser de trainer o gym
enum MetricsContainer: Codable {
    case trainer(TrainerMetrics)
    case gym(GymMetrics)
}

// MARK: - Trainer Metrics
/// Métricas específicas para entrenadores personales
struct TrainerMetrics: Codable {
    let activeClients: Int
    let maxClients: Int
    let capacityPercentage: Double
    let sessionsThisWeek: Int
    let avgSessionsPerClient: Double
    let clientRetentionRate: Double
    let revenueThisMonth: Double

    enum CodingKeys: String, CodingKey {
        case activeClients = "active_clients"
        case maxClients = "max_clients"
        case capacityPercentage = "capacity_percentage"
        case sessionsThisWeek = "sessions_this_week"
        case avgSessionsPerClient = "avg_sessions_per_client"
        case clientRetentionRate = "client_retention_rate"
        case revenueThisMonth = "revenue_this_month"
    }
}

// MARK: - Gym Metrics
/// Métricas específicas para gimnasios tradicionales
struct GymMetrics: Codable {
    let totalMembers: Int
    let activeTrainers: Int
    let activeClasses: Int
    let occupancyRate: Double
    let memberGrowthRate: Double
    let revenueThisMonth: Double

    enum CodingKeys: String, CodingKey {
        case totalMembers = "total_members"
        case activeTrainers = "active_trainers"
        case activeClasses = "active_classes"
        case occupancyRate = "occupancy_rate"
        case memberGrowthRate = "member_growth_rate"
        case revenueThisMonth = "revenue_this_month"
    }
}
