import Foundation
import Combine

// MARK: - NutritionService

@MainActor
class NutritionService: ObservableObject {
    // MARK: - Singleton
    static let shared = NutritionService()

    // MARK: - Published Properties
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var successMessage: String?

    // Dashboard & Plans
    @Published var dashboard: NutritionDashboard?
    @Published var todayPlan: TodayMealPlan?
    @Published var availablePlans: [NutritionPlan] = []
    @Published var livePlans: [NutritionPlan] = []
    @Published var templatePlans: [NutritionPlan] = []
    @Published var currentPlan: NutritionPlan?
    @Published var currentDailyPlan: DailyNutritionPlan?

    // Active Plans (planes que el usuario está siguiendo)
    @Published var activePlans: [ActivePlan] = []
    @Published var currentStreak: Int = 0
    @Published var longestStreak: Int = 0

    // User Stats
    @Published var userStats: UserNutritionStats?

    // MARK: - Dependencies
    weak var authService: AuthServiceDirect?
    weak var gymService: GymService?

    // MARK: - Private Properties
    private let baseURL = apiBaseURL
    private var cancellables = Set<AnyCancellable>()

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

    // MARK: - Initialization

    private init() {
        print("NutritionService inicializado")
    }

    // MARK: - Configuration

    func configure(authService: AuthServiceDirect, gymService: GymService? = nil) {
        self.authService = authService
        self.gymService = gymService
        print("NutritionService configurado con authService y gymService")
    }

    // MARK: - Dashboard

    /// Obtiene el dashboard de nutricion con todos los datos relevantes
    func getDashboard() async {
        guard let token = await authService?.getValidAccessToken(),
              let gymId = gymService?.currentGymId else {
            errorMessage = "Autenticacion requerida"
            print("NutritionService: No se puede obtener dashboard - sin autenticacion")
            return
        }

        isLoading = true
        errorMessage = nil

        print("NutritionService: Obteniendo dashboard")
        print("   URL: \(baseURL)/nutrition/dashboard")
        print("   Gym ID: \(gymId)")

        do {
            var request = URLRequest(url: URL(string: "\(baseURL)/nutrition/dashboard")!)
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
            request.setValue("\(gymId)", forHTTPHeaderField: "X-Gym-ID")

            let (data, response) = try await URLSession.shared.data(for: request)

            if let httpResponse = response as? HTTPURLResponse {
                print("NutritionService: Dashboard response status \(httpResponse.statusCode)")

                // Imprimir la respuesta completa del backend
                if let jsonString = String(data: data, encoding: .utf8) {
                    print("NutritionService: Dashboard response JSON:")
                    print("=====================================")
                    print(jsonString)
                    print("=====================================")
                }

                if httpResponse.statusCode == 200 {
                    let dashboard = try customDateDecoder.decode(NutritionDashboard.self, from: data)
                    self.dashboard = dashboard
                    self.todayPlan = dashboard.todayPlan
                    self.livePlans = dashboard.livePlans ?? []
                    self.templatePlans = dashboard.templatePlans ?? []
                    self.availablePlans = dashboard.availablePlans ?? []
                    self.userStats = dashboard.stats

                    // Parse active plans (planes que el usuario está siguiendo)
                    self.activePlans = dashboard.activePlans ?? []
                    self.currentStreak = dashboard.currentStreak ?? 0
                    self.longestStreak = dashboard.longestStreak ?? 0

                    print("🎯 NutritionService: Dashboard cargado exitosamente")
                    print("   - Active plans: \(dashboard.activePlans?.count ?? 0)")
                    if let activePlans = dashboard.activePlans, !activePlans.isEmpty {
                        for (idx, plan) in activePlans.enumerated() {
                            print("     [\(idx)] \(plan.planName) - Day \(plan.currentDay) - Adherencia: \(String(format: "%.0f%%", plan.adherencePercentage * 100))")
                        }
                    }
                    print("   - Live plans: \(dashboard.livePlans?.count ?? 0)")
                    print("   - Template plans: \(dashboard.templatePlans?.count ?? 0)")
                    print("   - Available plans: \(dashboard.availablePlans?.count ?? 0)")
                    print("   - Today plan exists: \(dashboard.todayPlan != nil)")
                    if let todayPlan = dashboard.todayPlan {
                        print("     • Plan: \(todayPlan.plan?.title ?? "nil")")
                        print("     • Progress: \(todayPlan.progress != nil ? "exists" : "nil")")
                        if let progress = todayPlan.progress {
                            print("       - Meals completed: \(progress.mealsCompleted)/\(progress.totalMeals)")
                            print("       - Percentage: \(String(format: "%.0f%%", progress.percentage))")
                        }
                    }
                    print("   - Current streak: \(dashboard.currentStreak ?? 0)")
                } else if httpResponse.statusCode == 401 {
                    print("NutritionService: Token expirado, reintentando...")
                    await getDashboard()
                    return
                } else {
                    if let errorString = String(data: data, encoding: .utf8) {
                        print("NutritionService: Error response: \(errorString)")
                    }
                    errorMessage = "Error al obtener dashboard: HTTP \(httpResponse.statusCode)"
                }
            }
        } catch {
            errorMessage = "Error al obtener dashboard: \(error.localizedDescription)"
            print("NutritionService: Error obteniendo dashboard: \(error)")

            // Si es un error de decodificacion, intentar imprimir el JSON
            if let decodingError = error as? DecodingError {
                print("NutritionService: Detalles del error de decodificacion:")
                switch decodingError {
                case .typeMismatch(let type, let context):
                    print("   - Type mismatch: esperaba \(type)")
                    print("   - Path: \(context.codingPath.map { $0.stringValue }.joined(separator: "."))")
                    print("   - Debug: \(context.debugDescription)")
                case .valueNotFound(let type, let context):
                    print("   - Value not found: \(type)")
                    print("   - Path: \(context.codingPath.map { $0.stringValue }.joined(separator: "."))")
                case .keyNotFound(let key, let context):
                    print("   - Key not found: \(key.stringValue)")
                    print("   - Path: \(context.codingPath.map { $0.stringValue }.joined(separator: "."))")
                case .dataCorrupted(let context):
                    print("   - Data corrupted")
                    print("   - Debug: \(context.debugDescription)")
                @unknown default:
                    print("   - Unknown decoding error")
                }
            }
        }

        isLoading = false
    }

    // MARK: - Plans

    /// Obtiene lista de planes con filtros opcionales
    func getPlans(
        planType: PlanType? = nil,
        status: PlanStatus? = nil,
        goal: NutritionGoal? = nil,
        page: Int = 1,
        perPage: Int = 20
    ) async -> [NutritionPlan] {
        guard let token = await authService?.getValidAccessToken(),
              let gymId = gymService?.currentGymId else {
            errorMessage = "Autenticacion requerida"
            return []
        }

        isLoading = true
        errorMessage = nil

        var urlComponents = URLComponents(string: "\(baseURL)/nutrition/plans")!
        var queryItems: [URLQueryItem] = [
            URLQueryItem(name: "page", value: String(page)),
            URLQueryItem(name: "per_page", value: String(perPage))
        ]

        if let planType = planType {
            queryItems.append(URLQueryItem(name: "plan_type", value: planType.rawValue))
        }
        if let status = status {
            queryItems.append(URLQueryItem(name: "status", value: status.rawValue))
        }
        if let goal = goal {
            queryItems.append(URLQueryItem(name: "goal", value: goal.rawValue))
        }

        urlComponents.queryItems = queryItems

        print("NutritionService: Obteniendo planes")
        print("   URL: \(urlComponents.url?.absoluteString ?? "")")

        do {
            var request = URLRequest(url: urlComponents.url!)
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
            request.setValue("\(gymId)", forHTTPHeaderField: "X-Gym-ID")

            print("NutritionService: Request headers:")
            print("   Authorization: Bearer ***")
            print("   X-Gym-ID: \(gymId)")

            let (data, response) = try await URLSession.shared.data(for: request)

            if let httpResponse = response as? HTTPURLResponse {
                print("NutritionService: Plans response status \(httpResponse.statusCode)")

                // Imprimir la respuesta completa para debug
                if let jsonString = String(data: data, encoding: .utf8) {
                    print("NutritionService: Plans response JSON:")
                    print("=====================================")
                    // Solo imprimir los primeros 1000 caracteres para no saturar los logs
                    let truncated = String(jsonString.prefix(1000))
                    print(truncated)
                    if jsonString.count > 1000 {
                        print("... (truncated, total: \(jsonString.count) chars)")
                    }
                    print("=====================================")
                }

                if httpResponse.statusCode == 200 {
                    let planResponse = try customDateDecoder.decode(PlanListResponse.self, from: data)
                    isLoading = false
                    print("NutritionService: Planes cargados exitosamente")
                    print("   - Total planes: \(planResponse.plans.count)")
                    print("   - Página: \(planResponse.page)/\(planResponse.total)")
                    print("   - Tiene más páginas: \(planResponse.hasNext)")

                    // Imprimir algunos detalles de los planes
                    for (index, plan) in planResponse.plans.prefix(3).enumerated() {
                        print("   - Plan \(index + 1): \(plan.title) (ID: \(plan.id), Goal: \(plan.goal.rawValue))")
                    }

                    return planResponse.plans
                } else if httpResponse.statusCode == 401 {
                    isLoading = false
                    return await getPlans(planType: planType, status: status, goal: goal, page: page, perPage: perPage)
                } else {
                    errorMessage = "Error al obtener planes: HTTP \(httpResponse.statusCode)"
                }
            }
        } catch {
            errorMessage = "Error al obtener planes: \(error.localizedDescription)"
            print("NutritionService: Error obteniendo planes: \(error)")

            // Si es un error de decodificacion, intentar imprimir el JSON
            if let decodingError = error as? DecodingError {
                print("NutritionService: Detalles del error de decodificacion:")
                switch decodingError {
                case .typeMismatch(let type, let context):
                    print("   - Type mismatch: esperaba \(type)")
                    print("   - Path: \(context.codingPath.map { $0.stringValue }.joined(separator: "."))")
                    print("   - Debug: \(context.debugDescription)")
                case .valueNotFound(let type, let context):
                    print("   - Value not found: \(type)")
                    print("   - Path: \(context.codingPath.map { $0.stringValue }.joined(separator: "."))")
                case .keyNotFound(let key, let context):
                    print("   - Key not found: \(key.stringValue)")
                    print("   - Path: \(context.codingPath.map { $0.stringValue }.joined(separator: "."))")
                case .dataCorrupted(let context):
                    print("   - Data corrupted")
                    print("   - Debug: \(context.debugDescription)")
                @unknown default:
                    print("   - Unknown decoding error")
                }
            }
        }

        isLoading = false
        return []
    }

    /// Obtiene detalles de un plan especifico
    func getPlanDetails(planId: Int) async -> NutritionPlan? {
        guard let token = await authService?.getValidAccessToken(),
              let gymId = gymService?.currentGymId else {
            errorMessage = "Autenticacion requerida"
            return nil
        }

        isLoading = true
        errorMessage = nil

        print("NutritionService: Obteniendo detalles del plan \(planId)")

        do {
            var request = URLRequest(url: URL(string: "\(baseURL)/nutrition/plans/\(planId)")!)
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
            request.setValue("\(gymId)", forHTTPHeaderField: "X-Gym-ID")

            let (data, response) = try await URLSession.shared.data(for: request)

            if let httpResponse = response as? HTTPURLResponse {
                if httpResponse.statusCode == 200 {
                    let plan = try customDateDecoder.decode(NutritionPlan.self, from: data)
                    self.currentPlan = plan
                    isLoading = false
                    print("NutritionService: Plan cargado: \(plan.title)")
                    return plan
                } else if httpResponse.statusCode == 401 {
                    isLoading = false
                    return await getPlanDetails(planId: planId)
                } else {
                    errorMessage = "Error al obtener plan: HTTP \(httpResponse.statusCode)"
                }
            }
        } catch {
            errorMessage = "Error al obtener plan: \(error.localizedDescription)"
            print("NutritionService: Error obteniendo plan: \(error)")
        }

        isLoading = false
        return nil
    }

    /// Obtiene el estado actual de un plan para el usuario
    func getPlanStatus(planId: Int) async -> PlanStatusResponse? {
        guard let token = await authService?.getValidAccessToken(),
              let gymId = gymService?.currentGymId else {
            errorMessage = "Autenticacion requerida"
            return nil
        }

        do {
            var request = URLRequest(url: URL(string: "\(baseURL)/nutrition/plans/\(planId)/status")!)
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
            request.setValue("\(gymId)", forHTTPHeaderField: "X-Gym-ID")

            let (data, response) = try await URLSession.shared.data(for: request)

            if let httpResponse = response as? HTTPURLResponse {
                if httpResponse.statusCode == 200 {
                    return try customDateDecoder.decode(PlanStatusResponse.self, from: data)
                } else if httpResponse.statusCode == 401 {
                    return await getPlanStatus(planId: planId)
                }
            }
        } catch {
            print("NutritionService: Error obteniendo estado del plan: \(error)")
        }

        return nil
    }

    // MARK: - Today Plan

    /// Obtiene el plan del dia actual
    func getTodayPlan() async {
        guard let token = await authService?.getValidAccessToken(),
              let gymId = gymService?.currentGymId else {
            errorMessage = "Autenticacion requerida"
            print("NutritionService: No se puede obtener plan de hoy - sin autenticacion")
            return
        }

        isLoading = true
        errorMessage = nil

        print("NutritionService: Obteniendo plan de hoy")

        do {
            var request = URLRequest(url: URL(string: "\(baseURL)/nutrition/today")!)
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
            request.setValue("\(gymId)", forHTTPHeaderField: "X-Gym-ID")

            let (data, response) = try await URLSession.shared.data(for: request)

            if let httpResponse = response as? HTTPURLResponse {
                print("NutritionService: Today plan response status \(httpResponse.statusCode)")

                if httpResponse.statusCode == 200 {
                    let todayPlan = try customDateDecoder.decode(TodayMealPlan.self, from: data)
                    self.todayPlan = todayPlan

                    print("NutritionService: Plan de hoy cargado")
                    print("   - Status: \(todayPlan.status)")
                    print("   - Current day: \(todayPlan.currentDay)")
                    print("   - Meals: \(todayPlan.meals.count)")
                    if let progress = todayPlan.progress {
                        print("   - Progress: \(progress.mealsCompleted)/\(progress.totalMeals)")
                    } else {
                        print("   - Progress: No disponible")
                    }
                } else if httpResponse.statusCode == 404 {
                    // Usuario no tiene plan activo hoy
                    self.todayPlan = nil
                    print("NutritionService: Usuario no tiene plan activo hoy")
                } else if httpResponse.statusCode == 401 {
                    await getTodayPlan()
                    return
                } else {
                    if let errorString = String(data: data, encoding: .utf8) {
                        print("NutritionService: Error response: \(errorString)")
                    }
                    errorMessage = "Error al obtener plan de hoy: HTTP \(httpResponse.statusCode)"
                }
            }
        } catch {
            errorMessage = "Error al obtener plan de hoy: \(error.localizedDescription)"
            print("NutritionService: Error obteniendo plan de hoy: \(error)")
        }

        isLoading = false
    }

    /// Obtiene el plan diario para un dia especifico
    func getDailyPlan(planId: Int, dayNumber: Int) async -> DailyNutritionPlan? {
        guard let token = await authService?.getValidAccessToken(),
              let gymId = gymService?.currentGymId else {
            errorMessage = "Autenticacion requerida"
            return nil
        }

        isLoading = true
        errorMessage = nil

        print("NutritionService: Obteniendo plan diario - Plan \(planId), Dia \(dayNumber)")

        do {
            var request = URLRequest(url: URL(string: "\(baseURL)/nutrition/plans/\(planId)/days/\(dayNumber)")!)
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
            request.setValue("\(gymId)", forHTTPHeaderField: "X-Gym-ID")

            let (data, response) = try await URLSession.shared.data(for: request)

            if let httpResponse = response as? HTTPURLResponse {
                if httpResponse.statusCode == 200 {
                    let dailyPlan = try customDateDecoder.decode(DailyNutritionPlan.self, from: data)
                    self.currentDailyPlan = dailyPlan
                    isLoading = false
                    print("NutritionService: Plan diario cargado - \(dailyPlan.meals.count) comidas")
                    return dailyPlan
                } else if httpResponse.statusCode == 401 {
                    isLoading = false
                    return await getDailyPlan(planId: planId, dayNumber: dayNumber)
                } else {
                    errorMessage = "Error al obtener plan diario: HTTP \(httpResponse.statusCode)"
                }
            }
        } catch {
            errorMessage = "Error al obtener plan diario: \(error.localizedDescription)"
            print("NutritionService: Error obteniendo plan diario: \(error)")
        }

        isLoading = false
        return nil
    }

    // MARK: - Follow/Unfollow Plans

    /// Sigue un plan de nutricion
    func followPlan(
        planId: Int,
        notificationsEnabled: Bool = true,
        notificationTimeBreakfast: String = "07:30",
        notificationTimeLunch: String = "13:00",
        notificationTimeDinner: String = "20:00"
    ) async -> Bool {
        guard let token = await authService?.getValidAccessToken(),
              let gymId = gymService?.currentGymId else {
            errorMessage = "Autenticacion requerida"
            return false
        }

        isLoading = true
        errorMessage = nil

        print("NutritionService: Siguiendo plan \(planId)")

        do {
            let body = FollowPlanRequest(
                notificationsEnabled: notificationsEnabled,
                notificationTimeBreakfast: notificationTimeBreakfast,
                notificationTimeLunch: notificationTimeLunch,
                notificationTimeDinner: notificationTimeDinner
            )

            let encoder = JSONEncoder()
            let bodyData = try encoder.encode(body)

            var request = URLRequest(url: URL(string: "\(baseURL)/nutrition/plans/\(planId)/follow")!)
            request.httpMethod = "POST"
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
            request.setValue("\(gymId)", forHTTPHeaderField: "X-Gym-ID")
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.httpBody = bodyData

            let (data, response) = try await URLSession.shared.data(for: request)

            if let httpResponse = response as? HTTPURLResponse {
                print("NutritionService: Follow plan response status \(httpResponse.statusCode)")

                if httpResponse.statusCode == 200 || httpResponse.statusCode == 201 {
                    let followResponse = try customDateDecoder.decode(FollowPlanResponse.self, from: data)
                    successMessage = "Te has unido al plan exitosamente"
                    isLoading = false
                    print("NutritionService: Plan seguido exitosamente - ID \(followResponse.id)")

                    // Refrescar datos
                    await getDashboard()
                    return true
                } else if httpResponse.statusCode == 401 {
                    isLoading = false
                    return await followPlan(planId: planId, notificationsEnabled: notificationsEnabled)
                } else if httpResponse.statusCode == 409 {
                    errorMessage = "Ya estas siguiendo este plan"
                } else {
                    if let errorString = String(data: data, encoding: .utf8) {
                        print("NutritionService: Error response: \(errorString)")
                    }
                    errorMessage = "Error al unirse al plan: HTTP \(httpResponse.statusCode)"
                }
            }
        } catch {
            errorMessage = "Error al unirse al plan: \(error.localizedDescription)"
            print("NutritionService: Error siguiendo plan: \(error)")
        }

        isLoading = false
        return false
    }

    /// Deja de seguir un plan de nutricion
    func unfollowPlan(planId: Int) async -> Bool {
        guard let token = await authService?.getValidAccessToken(),
              let gymId = gymService?.currentGymId else {
            errorMessage = "Autenticacion requerida"
            return false
        }

        isLoading = true
        errorMessage = nil

        print("NutritionService: Dejando de seguir plan \(planId)")

        do {
            var request = URLRequest(url: URL(string: "\(baseURL)/nutrition/plans/\(planId)/follow")!)
            request.httpMethod = "DELETE"
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
            request.setValue("\(gymId)", forHTTPHeaderField: "X-Gym-ID")

            let (_, response) = try await URLSession.shared.data(for: request)

            if let httpResponse = response as? HTTPURLResponse {
                if httpResponse.statusCode == 200 || httpResponse.statusCode == 204 {
                    successMessage = "Has dejado el plan exitosamente"
                    isLoading = false
                    print("NutritionService: Plan dejado exitosamente")

                    // Refrescar datos
                    await getDashboard()
                    return true
                } else if httpResponse.statusCode == 401 {
                    isLoading = false
                    return await unfollowPlan(planId: planId)
                } else {
                    errorMessage = "Error al dejar el plan: HTTP \(httpResponse.statusCode)"
                }
            }
        } catch {
            errorMessage = "Error al dejar el plan: \(error.localizedDescription)"
            print("NutritionService: Error dejando plan: \(error)")
        }

        isLoading = false
        return false
    }

    // MARK: - Meal Completion

    /// Marca una comida como completada
    func completeMeal(
        mealId: Int,
        rating: Int,
        photoUrl: String? = nil,
        notes: String? = nil,
        portionModifier: Double = 1.0
    ) async -> MealCompletion? {
        guard let token = await authService?.getValidAccessToken(),
              let gymId = gymService?.currentGymId else {
            errorMessage = "Autenticacion requerida"
            return nil
        }

        isLoading = true
        errorMessage = nil

        print("NutritionService: Completando comida \(mealId)")

        do {
            let body = MealCompletionRequest(
                satisfactionRating: rating,
                photoUrl: photoUrl,
                notes: notes,
                portionSizeModifier: portionModifier
            )

            let encoder = JSONEncoder()
            let bodyData = try encoder.encode(body)

            var request = URLRequest(url: URL(string: "\(baseURL)/nutrition/meals/\(mealId)/complete")!)
            request.httpMethod = "POST"
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
            request.setValue("\(gymId)", forHTTPHeaderField: "X-Gym-ID")
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.httpBody = bodyData

            let (data, response) = try await URLSession.shared.data(for: request)

            if let httpResponse = response as? HTTPURLResponse {
                print("NutritionService: Complete meal response status \(httpResponse.statusCode)")

                if httpResponse.statusCode == 200 || httpResponse.statusCode == 201 {
                    let completion = try customDateDecoder.decode(MealCompletion.self, from: data)
                    successMessage = "Comida registrada exitosamente"
                    isLoading = false
                    print("NutritionService: Comida completada - ID \(completion.id)")

                    // Refrescar plan de hoy
                    await getTodayPlan()
                    return completion
                } else if httpResponse.statusCode == 401 {
                    isLoading = false
                    return await completeMeal(mealId: mealId, rating: rating, photoUrl: photoUrl, notes: notes, portionModifier: portionModifier)
                } else if httpResponse.statusCode == 409 {
                    errorMessage = "Esta comida ya fue completada"
                } else {
                    if let errorString = String(data: data, encoding: .utf8) {
                        print("NutritionService: Error response: \(errorString)")
                    }
                    errorMessage = "Error al completar comida: HTTP \(httpResponse.statusCode)"
                }
            }
        } catch {
            errorMessage = "Error al completar comida: \(error.localizedDescription)"
            print("NutritionService: Error completando comida: \(error)")
        }

        isLoading = false
        return nil
    }

    /// Obtiene detalles de una comida especifica
    func getMealDetails(mealId: Int) async -> Meal? {
        guard let token = await authService?.getValidAccessToken(),
              let gymId = gymService?.currentGymId else {
            errorMessage = "Autenticacion requerida"
            return nil
        }

        do {
            var request = URLRequest(url: URL(string: "\(baseURL)/nutrition/meals/\(mealId)")!)
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
            request.setValue("\(gymId)", forHTTPHeaderField: "X-Gym-ID")

            let (data, response) = try await URLSession.shared.data(for: request)

            if let httpResponse = response as? HTTPURLResponse {
                if httpResponse.statusCode == 200 {
                    return try customDateDecoder.decode(Meal.self, from: data)
                } else if httpResponse.statusCode == 401 {
                    return await getMealDetails(mealId: mealId)
                }
            }
        } catch {
            print("NutritionService: Error obteniendo detalles de comida: \(error)")
        }

        return nil
    }

    // MARK: - User Statistics

    /// Obtiene estadisticas de nutricion del usuario
    func getUserStats() async -> UserNutritionStats? {
        guard let token = await authService?.getValidAccessToken(),
              let gymId = gymService?.currentGymId else {
            errorMessage = "Autenticacion requerida"
            return nil
        }

        do {
            var request = URLRequest(url: URL(string: "\(baseURL)/nutrition/stats")!)
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
            request.setValue("\(gymId)", forHTTPHeaderField: "X-Gym-ID")

            let (data, response) = try await URLSession.shared.data(for: request)

            if let httpResponse = response as? HTTPURLResponse {
                if httpResponse.statusCode == 200 {
                    let stats = try customDateDecoder.decode(UserNutritionStats.self, from: data)
                    self.userStats = stats
                    return stats
                } else if httpResponse.statusCode == 401 {
                    return await getUserStats()
                }
            }
        } catch {
            print("NutritionService: Error obteniendo estadisticas: \(error)")
        }

        return nil
    }

    // MARK: - Data Management

    /// Limpia todos los datos de nutricion (usado en logout)
    func clearData() {
        print("NutritionService: Limpiando datos...")
        dashboard = nil
        todayPlan = nil
        availablePlans = []
        livePlans = []
        templatePlans = []
        currentPlan = nil
        currentDailyPlan = nil
        userStats = nil
        errorMessage = nil
        successMessage = nil
    }

    /// Refresca todos los datos de nutricion
    func refreshAllData() async {
        print("NutritionService: Refrescando todos los datos...")
        await getDashboard()
        await getTodayPlan()
    }

    // MARK: - Convenience Methods

    /// Indica si hay un challenge LIVE activo
    var hasActiveLiveChallenge: Bool {
        return todayPlan?.plan?.isActiveLiveChallenge == true
    }

    /// Obtiene el challenge LIVE activo actual
    var activeLiveChallenge: NutritionPlan? {
        if let plan = todayPlan?.plan, plan.isActiveLiveChallenge {
            return plan
        }
        return livePlans.first { $0.isActiveLiveChallenge }
    }

    /// Progreso del dia actual
    var todayProgress: DayProgress? {
        return todayPlan?.progress
    }

    // MARK: - Deinit

    deinit {
        #if DEBUG
        print("NutritionService deinitialized")
        #endif
    }
}

// MARK: - Supporting Types

struct PlanListResponse: Codable {
    let plans: [NutritionPlan]
    let total: Int
    let page: Int
    let perPage: Int
    let hasNext: Bool
    let hasPrev: Bool

    enum CodingKeys: String, CodingKey {
        case plans
        case total
        case page
        case perPage = "per_page"
        case hasNext = "has_next"
        case hasPrev = "has_prev"
    }
}

struct PlanStatusResponse: Codable {
    let planId: Int
    let planType: PlanType
    let currentDay: Int
    let status: PlanStatus
    let daysUntilStart: Int?
    let isLiveActive: Bool
    let liveParticipantsCount: Int
    let isFollowing: Bool

    enum CodingKeys: String, CodingKey {
        case planId = "plan_id"
        case planType = "plan_type"
        case currentDay = "current_day"
        case status
        case daysUntilStart = "days_until_start"
        case isLiveActive = "is_live_active"
        case liveParticipantsCount = "live_participants_count"
        case isFollowing = "is_following"
    }
}

struct FollowPlanRequest: Codable {
    let notificationsEnabled: Bool
    let notificationTimeBreakfast: String
    let notificationTimeLunch: String
    let notificationTimeDinner: String

    enum CodingKeys: String, CodingKey {
        case notificationsEnabled = "notifications_enabled"
        case notificationTimeBreakfast = "notification_time_breakfast"
        case notificationTimeLunch = "notification_time_lunch"
        case notificationTimeDinner = "notification_time_dinner"
    }
}

struct FollowPlanResponse: Codable {
    let id: Int
    let userId: Int
    let planId: Int
    let isActive: Bool
    let startDate: Date
    let notificationsEnabled: Bool?

    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case planId = "plan_id"
        case isActive = "is_active"
        case startDate = "start_date"
        case notificationsEnabled = "notifications_enabled"
    }
}
