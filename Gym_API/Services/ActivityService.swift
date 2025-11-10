import Foundation
import Combine

/// Service for managing social activity including achievements, records, and new members
@MainActor
class ActivityService: ObservableObject {
    // MARK: - Published Properties

    @Published var achievements: [Achievement] = []
    @Published var isLoading = false
    @Published var errorMessage: String?

    // MARK: - Private Properties

    private var cancellables = Set<AnyCancellable>()

    // MARK: - Initialization

    init() {
        // For now, use sample data
        // TODO: Replace with actual API calls when backend is ready
        loadSampleAchievements()
    }

    // MARK: - Public Methods

    /// Loads achievements from the backend
    func loadAchievements() async {
        isLoading = true
        errorMessage = nil

        // TODO: Implement actual API call
        // For now, simulate network delay and use sample data
        try? await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds

        await MainActor.run {
            loadSampleAchievements()
            isLoading = false
        }
    }

    /// Refreshes achievements data
    func refreshAchievements() {
        Task {
            await loadAchievements()
        }
    }

    // MARK: - Private Methods

    private func loadSampleAchievements() {
        // Generate dynamic sample achievements using the existing Achievement model from UserStats.swift
        let dateFormatter = ISO8601DateFormatter()

        achievements = [
            Achievement(
                id: 1,
                type: "personal_record",
                name: "Nuevo récord de peso muerto",
                description: "Carlos levantó 180kg en peso muerto",
                earnedAt: dateFormatter.string(from: Date().addingTimeInterval(-3600)),
                badgeIcon: "trophy.fill"
            ),
            Achievement(
                id: 2,
                type: "streak",
                name: "30 días consecutivos",
                description: "María completó 30 días de entrenamiento sin faltar",
                earnedAt: dateFormatter.string(from: Date().addingTimeInterval(-7200)),
                badgeIcon: "flame.fill"
            ),
            Achievement(
                id: 3,
                type: "milestone",
                name: "100 clases completadas",
                description: "Juan alcanzó 100 clases de spinning",
                earnedAt: dateFormatter.string(from: Date().addingTimeInterval(-14400)),
                badgeIcon: "flag.checkered"
            ),
            Achievement(
                id: 4,
                type: "participation",
                name: "Participante destacado del mes",
                description: "Ana asistió a más de 20 eventos este mes",
                earnedAt: dateFormatter.string(from: Date().addingTimeInterval(-21600)),
                badgeIcon: "star.fill"
            ),
            Achievement(
                id: 5,
                type: "personal_record",
                name: "Récord en press de banca",
                description: "Luis alcanzó 120kg en press de banca",
                earnedAt: dateFormatter.string(from: Date().addingTimeInterval(-28800)),
                badgeIcon: "trophy.fill"
            ),
            Achievement(
                id: 6,
                type: "social",
                name: "Miembro más activo",
                description: "Sofia ayudó a 10 nuevos miembros esta semana",
                earnedAt: dateFormatter.string(from: Date().addingTimeInterval(-43200)),
                badgeIcon: "person.2.fill"
            )
        ]
    }

    // MARK: - Deinit

    deinit {
        #if DEBUG
        print("🗑️ ActivityService deinitialized")
        #endif
    }
}
