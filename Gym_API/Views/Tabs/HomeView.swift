import SwiftUI

struct HomeView: View {
    @EnvironmentObject var themeManager: ThemeManager
    @EnvironmentObject var eventService: EventService
    @EnvironmentObject var authService: AuthServiceDirect
    @StateObject private var gymService = GymService.shared
    @EnvironmentObject var classService: ClassService
    @StateObject private var profileService = UserProfileService.shared
    @ObservedObject private var userStatsService = UserStatsService.shared
    @EnvironmentObject var surveyService: SurveyService
    @EnvironmentObject var activityService: ActivityService  // Activity feed service
    @StateObject private var paymentService = EventPaymentService.shared  // Add payment service
    @StateObject private var storyService = StoryService()  // Story service for Instagram-style stories
    @StateObject private var postService = PostService()  // Post service for social feed
    @StateObject private var userStatsServiceLocal = UserStatsService.shared  // For HeroProgressWidget
    @ObservedObject private var nutritionService = NutritionService.shared  // Nutrition service for meal plans
    @State private var currentDate = Date()
    @State private var showComebackView = false
    @State private var showStreakDetail = false  // Show streak detail view
    @State private var isInitialLoad = true
    @State private var showingPaymentSheet = false  // For payment modal
    @State private var currentPaymentIntent: PaymentIntent?  // Current payment to process
    @State private var currentParticipationId: Int?  // Track participation ID for payment
    @State private var selectedEventForPayment: Event?  // Track event for payment
    
    private var greeting: String {
        let hour = Calendar.current.component(.hour, from: currentDate)
        let weekday = Calendar.current.component(.weekday, from: currentDate)
        let streak = userStatsService.userStats.currentStreak
        let workoutsThisWeek = userStatsService.userStats.weeklyClasses

        // Saludo contextual basado en actividad del usuario

        // Primero checar rachas significativas
        if streak >= 30 {
            return "¡Un mes sin parar! Eres leyenda 🏆"
        } else if streak >= 14 {
            return "¡2 semanas de constancia! Imparable 💪"
        } else if streak >= 7 {
            return "¡Una semana completa! En fuego 🔥"
        } else if streak >= 3 {
            return "¡\(streak) días seguidos! Vas con todo 💯"
        }

        // Si no hay racha significativa, checar actividad semanal
        if workoutsThisWeek == 0 {
            // Usuario inactivo esta semana - motivar según hora
            switch hour {
            case 0..<6:
                return "El mejor momento para empezar es ahora"
            case 6..<12:
                if weekday == 2 { // Lunes
                    return "Nueva semana, nuevas metas por cumplir"
                }
                return "Hoy es el día perfecto para empezar"
            case 12..<18:
                return "Aún hay tiempo para tu primer workout"
            case 18..<24:
                return "¿Qué tal cerrar el día con ejercicio?"
            default:
                return "Tu momento de brillar te espera"
            }
        } else if workoutsThisWeek >= 3 {
            // Usuario muy activo - celebrar
            switch hour {
            case 0..<12:
                return "¡Ya llevas \(workoutsThisWeek) workouts esta semana! 🎯"
            case 12..<18:
                return "Increíble semana - \(workoutsThisWeek) sesiones ya ⚡"
            default:
                return "¡\(workoutsThisWeek) workouts! Eres inspiración 🌟"
            }
        } else {
            // Usuario moderadamente activo - mantener momentum
            switch hour {
            case 0..<6:
                return "Wow, empezando temprano hoy"
            case 6..<12:
                if weekday == 2 {
                    return "Linda mañana para continuar tu semana"
                }
                return "Buen día para seguir avanzando"
            case 12..<18:
                if weekday == 6 {
                    return "Hermosa tarde para cerrar fuerte"
                }
                return "Perfecto momento para moverte"
            case 18..<24:
                if weekday == 1 || weekday == 7 {
                    return "Aprovecha el fin de semana"
                }
                return "Todavía hay tiempo para ti"
            default:
                return "Tu momento es ahora"
            }
        }
    }
    
    private var userName: String {
        // Priorizar el nombre del perfil sobre el nombre de Auth0
        if let firstName = profileService.userProfile?.firstName, !firstName.isEmpty {
            return firstName
        }
        // Fallback a Auth0 name (primer componente)
        if let auth0Name = authService.user?.name, !auth0Name.isEmpty {
            let components = auth0Name.components(separatedBy: " ")
            let firstComponent = components.first ?? ""
            // Si parece un email, extraer la parte antes del @
            if firstComponent.contains("@") {
                return firstComponent.components(separatedBy: "@").first ?? "Atleta"
            }
            return firstComponent
        }
        return "Atleta"
    }
    
    // Ya no se usa este campo - el saludo principal es suficiente
    // Mantener por compatibilidad pero no mostrar
    private var motivationalQuestion: String {
        return ""
    }

    // Obtener próxima clase registrada del usuario
    private var nextUserClass: GymClass? {
        let now = Date()
        let userRegisteredClasses = classService.classes.filter { gymClass in
            let isRegistered = classService.userRegistrationStatus[gymClass.id] ?? false
            return isRegistered && gymClass.startTime > now
        }
        return userRegisteredClasses.sorted { $0.startTime < $1.startTime }.first
    }

    var body: some View {
        let _ = debugLog("🏠 HomeView.body evaluado")
        let _ = debugLog("🏠 UserStatsService isLoading: \(userStatsService.isLoading)")
        let _ = debugLog("🏠 UserStatsService hasValidStats: \(userStatsService.comprehensiveStats != nil)")
        let _ = debugLog("🏠 UserStatsService error: \(userStatsService.error?.localizedDescription ?? "ninguno")")
        let _ = debugLog("🏠 UserStatsService authService configurado: \(userStatsService.authService != nil)")
        
        return NavigationStack {
            ZStack {
                Color.dynamicBackground(theme: themeManager.currentTheme).ignoresSafeArea()

                // Mostrar skeleton durante carga inicial
                if isInitialLoad && (eventService.isLoading || userStatsService.isLoading) {
                    HomeViewSkeleton()
                        .environmentObject(themeManager)
                        .transition(.opacity)
                } else {
                    // Contenido scrolleable con pull-to-refresh personalizado
                    ScrollView(.vertical, showsIndicators: false) {
                        VStack(spacing: 20) {
                            // 1. Compact Header con greeting y streak badge
                            CompactHeroHeader(
                                greeting: greeting,
                                userName: userName,
                                streakCount: userStatsService.userStats.currentStreak,
                                onStreakTap: { showStreakDetail = true },
                                onAvatarTap: {
                                    NotificationCenter.default.post(name: .openProfileTab, object: nil)
                                }
                            )
                            .environmentObject(themeManager)
                            .environmentObject(authService)

                            // 2. Stories Preview (conexión social inmediata)
                            InstagramStoriesBar()
                                .environmentObject(storyService)
                                .environmentObject(authService)
                                .environmentObject(themeManager)
                                .environmentObject(profileService)

                            // 2.3 CTA Principal - Reservar Primera Clase (Solo usuarios nuevos)
                            if userStatsService.userStats.currentStreak == 0 {
                                PrimaryCTAButton(
                                    action: {
                                        HapticManager.shared.play(.medium)
                                        // Navegar a la pestaña de clases
                                        NotificationCenter.default.post(name: .openClassesTab, object: nil)

                                        // Track analytics
                                        debugLog("📊 CTA Principal clicked - Navigate to Classes")
                                    }
                                )
                                .transition(.opacity.combined(with: .scale))
                                .animation(.spring(response: 0.4, dampingFraction: 0.8), value: userStatsService.userStats.currentStreak)
                            }

                            // 2.5. Live Pulse Banner (personas entrenando ahora)
                            LivePulseBanner()
                                .environmentObject(activityService)
                                .environmentObject(themeManager)

                            // 2.6. Gym Activity Stream (actividad del gym en tiempo real)
                            GymActivityStream()
                                .environmentObject(activityService)
                                .environmentObject(themeManager)

                            // 2.7. Nutrition Banner (posición fija para evitar saltos visuales)
                            NutritionHomeBannerSection()
                                .environmentObject(nutritionService)
                                .environmentObject(themeManager)

                            // 3. Hero Class Card (CTA principal con gradiente vibrante)
                            if let nextClass = nextUserClass {
                                HeroClassCard(
                                    gymClass: nextClass,
                                    onViewTapped: {
                                        // Navigate to classes tab to see details
                                        HapticManager.shared.buttonTap()
                                        NotificationCenter.default.post(
                                            name: .openClassesTab,
                                            object: nil
                                        )
                                    }
                                )
                                .environmentObject(themeManager)
                            }

                            // ELIMINADO - Duplicación 100% con WeeklyCheckInCard
                            // 4. Weekly Progress Circles (metas semanales)
                            // WeeklyProgressCircles()
                            //     .environmentObject(userStatsService)
                            //     .environmentObject(themeManager)

                            // 5. Stats Summary (colapsado por defecto)
                            WeeklyCheckInCard()
                                .environmentObject(userStatsService)
                                .environmentObject(themeManager)

                            // 5.5. Rankings Carousel (movido arriba para mayor visibilidad)
                            RankingsCarousel()
                                .environmentObject(activityService)
                                .environmentObject(themeManager)

                            // 6. Quick Actions Bar (accesos rápidos para acciones frecuentes)
                            SmartActionsSection(
                                themeManager: themeManager,
                                authService: authService,
                                eventService: eventService,
                                classService: classService,
                                profileService: profileService,
                                userStatsService: userStatsService,
                                membershipService: MembershipService.shared,
                                locationService: LocationService.shared
                            )

                            // 7. Your Week Section (próximos eventos/clases)
                            YourWeekSection()
                                .environmentObject(classService)
                                .environmentObject(eventService)
                                .environmentObject(themeManager)

                            // 8. Goal Progress Bar (métricas de progreso hacia metas)
                            HeroProgressWidget()
                                .environmentObject(userStatsServiceLocal)
                                .environmentObject(themeManager)

                            // ELIMINADO - Duplicación con YourWeekSection + HeroClassCard
                            // 9. Live Activity Card (eventos en vivo)
                            // LiveActivityCard()
                            //     .environmentObject(eventService)
                            //     .environmentObject(themeManager)

                            // 10. Survey Card (mantener si hay encuestas disponibles)
                            SurveyHomeCard()
                                .environmentObject(surveyService)
                                .environmentObject(themeManager)

                            // MOVIDO A PERFIL - Información retrospectiva
                            // 12. Recent Activity (actividad reciente)
                            // HomeRecentActivitySection(
                            //     themeManager: themeManager,
                            //     classService: classService,
                            //     eventService: eventService
                            // )

                            Spacer(minLength: 100)
                        }
                        .padding(.horizontal, 16)
                    }
                    // iOS16 compatible margins handled via padding above
                    .safeAreaPadding(.top, 20)
                    .safeAreaPadding(.bottom, 16)
                }
            }
            .refreshable {
                await eventService.fetchEvents()
                await eventService.fetchUserParticipations()
                await userStatsService.fetchComprehensiveStats()
                await surveyService.getAvailableSurveys()
                await classService.forceRefreshSessions(date: Date())
                await activityService.fetchAllData()
            }
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
        }
        .sheet(isPresented: $showComebackView) {
            ComebackView(
                daysInactive: userStatsService.daysInactive,
                userName: userName,
                lastClass: userStatsService.lastAttendedClass,
                bestStreak: userStatsService.userStats.totalStreak,
                onScheduleClass: {
                    // Navegar a la pestaña de clases
                    NotificationCenter.default.post(name: .openClassesTab, object: nil)
                }
            )
            .environmentObject(themeManager)
            .presentationDetents([.large])
            .presentationDragIndicator(.visible) // Mostrar indicador de drag
            .presentationCornerRadius(30)
            .presentationBackgroundInteraction(.enabled)
        }
        .fullScreenCover(isPresented: $showStreakDetail) {
            StreakDetailView()
                .environmentObject(userStatsService)
                .environmentObject(themeManager)
        }
        .sheet(item: Binding(
            get: { currentPaymentIntent },
            set: { currentPaymentIntent = $0 }
        )) { paymentIntent in
            // Payment sheet for paid events
            let _ = print("💳 [HomeView] Sheet presenting")
            let _ = print("💳 [HomeView] currentPaymentIntent: \(currentPaymentIntent != nil ? "exists" : "nil")")
            let _ = print("💳 [HomeView] currentParticipationId: \(currentParticipationId ?? -1)")
            let _ = print("💳 [HomeView] selectedEventForPayment: \(selectedEventForPayment?.title ?? "nil")")

            EventPaymentView(
                paymentIntent: paymentIntent,
                participationId: currentParticipationId,
                event: selectedEventForPayment,
                onPaymentComplete: { success in
                    currentPaymentIntent = nil
                    currentParticipationId = nil
                    selectedEventForPayment = nil
                    if success {
                        // Payment successful - refresh event data
                        // Note: EventService will be refreshed when view reappears
                    }
                }
            )
            .environmentObject(themeManager)
            .environmentObject(paymentService)
            .environmentObject(eventService)
        }
        .onAppear {
            debugLog("🏠 HomeView.onAppear iniciado")
            currentDate = Date()
            setupServices()
            debugLog("🏠 setupServices completado, iniciando tareas async")
            Task {
                debugLog("🏠 Iniciando carga paralela de datos...")

                // Verificar estado inicial en MainActor
                let eventsIsEmpty = await MainActor.run { eventService.events.isEmpty }

                // Cargar datos en paralelo usando TaskGroup
                await withTaskGroup(of: Void.self) { group in
                    // Grupo 1: Events
                    group.addTask {
                        if eventsIsEmpty {
                            debugLog("🏠 [Parallel] Iniciando fetchEvents...")
                            await eventService.fetchEvents()
                            debugLog("🏠 [Parallel] fetchEvents completado")
                        }
                    }

                    // Grupo 2: User participations
                    group.addTask {
                        debugLog("🏠 [Parallel] Iniciando fetchUserParticipations...")
                        await eventService.fetchUserParticipations()
                        debugLog("🏠 [Parallel] fetchUserParticipations completado")
                    }

                    // Grupo 3: Gyms
                    group.addTask {
                        debugLog("🏠 [Parallel] Iniciando getMyGyms...")
                        await gymService.getMyGyms()
                        debugLog("🏠 [Parallel] getMyGyms completado")
                    }

                    // Grupo 4: User stats
                    group.addTask {
                        debugLog("🏠 [Parallel] Iniciando fetchComprehensiveStats...")
                        await userStatsService.fetchComprehensiveStats()
                        debugLog("🏠 [Parallel] fetchComprehensiveStats completado")
                    }

                    // Grupo 5: Workout history
                    group.addTask {
                        debugLog("🏠 [Parallel] Iniciando fetchWorkoutHistory...")
                        await userStatsService.fetchWorkoutHistory()
                        debugLog("🏠 [Parallel] fetchWorkoutHistory completado")
                    }

                    // Grupo 6: Surveys
                    group.addTask {
                        debugLog("🏠 [Parallel] Iniciando getAvailableSurveys...")
                        await surveyService.getAvailableSurveys()
                        debugLog("🏠 [Parallel] getAvailableSurveys completado")
                    }

                    // Grupo 7: Classes (para RecentActivity)
                    group.addTask {
                        debugLog("🏠 [Parallel] Iniciando loadTrainers...")
                        await classService.loadTrainers()
                        debugLog("🏠 [Parallel] loadTrainers completado")

                        debugLog("🏠 [Parallel] Iniciando loadSessionsForDateIfNeeded...")
                        await classService.loadSessionsForDateIfNeeded(date: Date())
                        debugLog("🏠 [Parallel] loadSessionsForDateIfNeeded completado")
                    }

                    // Grupo 8: Stories Feed
                    group.addTask {
                        debugLog("🏠 [Parallel] Iniciando fetchStoriesFeed...")
                        await storyService.fetchStoriesFeed()
                        let storiesCount = await MainActor.run { storyService.feedStories.count }
                        debugLog("🏠 [Parallel] fetchStoriesFeed completado - Count: \(storiesCount)")
                    }

                    // Grupo 9: Activity Feed (realtime, rankings, insights)
                    group.addTask {
                        debugLog("🏠 [Parallel] Iniciando fetchAllData de ActivityService...")
                        await activityService.fetchAllData()
                        debugLog("🏠 [Parallel] ActivityService fetchAllData completado")
                    }
                }

                debugLog("🏠 Todas las cargas paralelas completadas")

                // Marcar carga inicial como completada
                await MainActor.run {
                    withAnimation(.easeOut(duration: 0.3)) {
                        isInitialLoad = false
                    }
                }
            }
        }
        .onDisappear {
            debugLog("🏠 HomeView.onDisappear - Deteniendo timer de realtime updates")
            activityService.stopRealtimeUpdates()
        }
    }
}

// MARK: - Helper Methods
extension HomeView {
    private func setupServices() {
        debugLog("🏠 setupServices iniciado")
        debugLog("🏠 Configurando authService en gymService...")
        gymService.authService = authService
        debugLog("🏠 Configurando authService en classService...")
        classService.authService = authService
        debugLog("🏠 Configurando authService en profileService...")
        profileService.authService = authService
        debugLog("🏠 Configurando authService en userStatsService...")
        userStatsService.authService = authService
        userStatsService.gymService = gymService
        debugLog("🏠 AuthService configurado en userStatsService: \(userStatsService.authService != nil)")
        debugLog("🏠 Configurando authService en surveyService...")
        surveyService.authService = authService
        surveyService.gymService = gymService

        // Setup story service
        debugLog("🏠 Configurando authService en storyService...")
        storyService.authService = authService

        // Setup location service
        debugLog("🏠 Configurando LocationService...")
        LocationService.shared.requestLocationPermission()

        // Start realtime activity updates (every 30 seconds)
        debugLog("🏠 Iniciando actualizaciones en tiempo real de ActivityService...")
        activityService.startRealtimeUpdates(interval: 30)

        debugLog("🏠 setupServices completado")
    }

    private func refreshAllData() async {
        HapticManager.shared.play(.medium)
        await eventService.fetchEvents()
        await eventService.fetchUserParticipations()
        await userStatsService.fetchComprehensiveStats()
        await surveyService.getAvailableSurveys()
        await classService.loadTrainers()
        await classService.forceRefreshSessions(date: Date())
        await storyService.fetchStoriesFeed()
        await activityService.fetchAllData()
        HapticManager.shared.play(.success)
    }
}

// MARK: - Hero Section
struct HeroSection: View {
    let greeting: String
    let userName: String
    let motivationalQuestion: String
    let themeManager: ThemeManager
    let authService: AuthServiceDirect
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    
    var body: some View {
        VStack(spacing: dynamicTypeSize.adjustedSpacing(20)) {
            // Header with greeting and avatar
            HStack(alignment: .top, spacing: 16) {
                VStack(alignment: .leading, spacing: dynamicTypeSize.adjustedSpacing(4)) {
                    Text("\(greeting), \(userName).")
                        .font(.system(size: 28, weight: .bold))
                        .foregroundColor(Color.dynamicText(theme: themeManager.currentTheme))
                        .dynamicTypeSupport(maxLines: 2)
                        .lineLimit(2)
                        .minimumScaleFactor(0.5)
                        .fixedSize(horizontal: false, vertical: true)
                    
                    Text(motivationalQuestion)
                        .font(.cappedDynamicSystem(size: 16, weight: .medium, maxSize: 20))
                        .foregroundColor(Color.dynamicTextSecondary(theme: themeManager.currentTheme))
                        .dynamicTypeSupport()
                        .padding(.top, 4)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                
                Spacer()
                
                // User Avatar - positioned at top right
                Group {
                    if let urlString = resolvedAvatarURL(authService: authService), !urlString.isEmpty,
                       let user = authService.user {
                        let normalizedId = user.id
                            .replacingOccurrences(of: "user_", with: "")
                            .replacingOccurrences(of: "auth0|", with: "")
                        CustomImageView(url: urlString, cacheKey: "avatar_self_\(normalizedId)", size: 80) {
                                AnyView(
                                    Image(systemName: "person.fill")
                                        .font(.system(size: 40, weight: .semibold))
                                        .foregroundColor(Color.dynamicTextSecondary(theme: themeManager.currentTheme))
                                        .frame(width: 80, height: 80)
                                        .background(
                                            Circle()
                                                .fill(Color.dynamicSurface(theme: themeManager.currentTheme).opacity(0.1))
                                        )
                                )
                            }
                            .clipShape(Circle())
                            .accessibilityLabel(Text("Foto de perfil"))
                    } else {
                        Image(systemName: "person.fill")
                            .font(.system(size: 40, weight: .semibold))
                            .foregroundColor(Color.dynamicTextSecondary(theme: themeManager.currentTheme))
                            .frame(width: 80, height: 80)
                            .background(
                                Circle()
                                    .fill(Color.dynamicSurface(theme: themeManager.currentTheme).opacity(0.1))
                            )
                            .clipShape(Circle())
                            .accessibilityLabel(Text("Foto de perfil por defecto"))
                    }
                }
                .onTapGesture {
                    // Navegar a la pestaña de perfil
                    let impact = UIImpactFeedbackGenerator(style: .light)
                    impact.impactOccurred()
                    NotificationCenter.default.post(name: .openProfileTab, object: nil)
                }
                .accessibilityAddTraits(.isButton)
                .accessibilityHint("Abrir perfil")
            }
        }
        .padding(.horizontal, dynamicTypeSize.adjustedPadding(20))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(greeting), \(userName). \(motivationalQuestion)")
        .accessibilityAddTraits(.isHeader)
    }
}

// MARK: - Avatar URL Resolution Helper
@MainActor
private func resolvedAvatarURL(authService: AuthServiceDirect) -> String? {
    // Prefer backend profile picture if available
    if let profilePic = UserProfileService.shared.userProfile?.picture, !profilePic.isEmpty {
        return cleanAvatarURL(profilePic)
    }
    // Fallback to Auth0 user picture
    if let userPic = authService.user?.picture, !userPic.isEmpty {
        return cleanAvatarURL(userPic)
    }
    // As a last resort, generate a UI Avatar from name
    let name = authService.user?.name ?? "User"
    let encoded = name.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "User"
    let bg = String(format: "%06X", abs(name.hashValue) % 0xFFFFFF)
    return "https://ui-avatars.com/api/?name=\(encoded)&size=128&background=\(bg)&color=fff&format=png"
}

private func cleanAvatarURL(_ urlString: String) -> String {
    var s = urlString.trimmingCharacters(in: .whitespacesAndNewlines)
    // Remove trailing '?' which some providers append and can break URL parsing
    while s.hasSuffix("?") { s.removeLast() }
    return s
}

// MARK: - Compact Hero Header

struct CompactHeroHeader: View {
    let greeting: String
    let userName: String
    let streakCount: Int
    let onStreakTap: () -> Void
    let onAvatarTap: () -> Void

    @EnvironmentObject var themeManager: ThemeManager
    @EnvironmentObject var authService: AuthServiceDirect
    @ObservedObject private var profileService = UserProfileService.shared

    // Cache para mantener la última URL y cacheKey válidos del avatar durante recargas
    @State private var cachedAvatarURL: String = ""
    @State private var cachedAvatarCacheKey: String = ""

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            // Greeting - Formato más cálido y amigable
            VStack(alignment: .leading, spacing: 2) {
                Text("Hola, \(userName) 👋")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(Color.dynamicText(theme: themeManager.currentTheme))
                    .lineLimit(1)

                Text(greeting)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(Color.dynamicTextSecondary(theme: themeManager.currentTheme))
                    .lineLimit(2)
            }

            Spacer()

            // Streak badge (compact) - Solo mostrar si racha >= 7 días
            // Usuarios nuevos/ocasionales no ven presión de racha en header
            if streakCount >= 7 {
                Button(action: {
                    HapticManager.shared.buttonTap()
                    onStreakTap()
                }) {
                    HStack(spacing: 6) {
                        Image(systemName: "flame.fill")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(Color(red: 0.85, green: 0.2, blue: 0.2))

                        Text("\(streakCount)")
                            .font(.system(size: 16, weight: .bold, design: .rounded))
                            .foregroundColor(Color.dynamicText(theme: themeManager.currentTheme))
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(
                        Capsule()
                            .fill(Color.dynamicSurface(theme: themeManager.currentTheme))
                    )
                }
                .buttonStyle(PlainButtonStyle())
            }

            // Avatar (compact)
            Button(action: {
                HapticManager.shared.buttonTap()
                onAvatarTap()
            }) {
                avatarView
                    .frame(width: 44, height: 44)
            }
            .buttonStyle(PlainButtonStyle())
        }
        .padding(.vertical, 12)
        .onAppear {
            updateCachedAvatarURL()
        }
        .onChange(of: profileService.userProfile?.picture) { _, _ in
            updateCachedAvatarURL()
        }
    }

    // Actualiza la URL y cacheKey cacheados solo cuando tenemos valores válidos
    private func updateCachedAvatarURL() {
        let newURL = computeAvatarURL()
        let newCacheKey = computeAvatarCacheKey()

        // Solo actualizar si tenemos valores válidos y no estamos cargando
        // o si el cache está vacío (primera carga)
        let shouldUpdate = cachedAvatarURL.isEmpty || cachedAvatarCacheKey.isEmpty || !profileService.isLoading

        if !newURL.isEmpty && shouldUpdate {
            cachedAvatarURL = newURL
        }
        if !newCacheKey.isEmpty && newCacheKey != "avatar_header_default" && shouldUpdate {
            cachedAvatarCacheKey = newCacheKey
        } else if cachedAvatarCacheKey.isEmpty && !newCacheKey.isEmpty {
            // Primera carga - usar cualquier cacheKey disponible
            cachedAvatarCacheKey = newCacheKey
        }
    }

    // MARK: - Avatar View

    @ViewBuilder
    private var avatarView: some View {
        // Usar URL y cacheKey cacheados para evitar cambios durante recarga
        let avatarURL = cachedAvatarURL.isEmpty ? computeAvatarURL() : cachedAvatarURL
        let cacheKey = cachedAvatarCacheKey.isEmpty ? computeAvatarCacheKey() : cachedAvatarCacheKey

        if !avatarURL.isEmpty {
            CustomImageView(url: avatarURL, cacheKey: cacheKey, size: 44) {
                AnyView(avatarPlaceholder)
            }
            .clipShape(Circle())
            .id(cacheKey) // Estabilizar el view para evitar recreaciones innecesarias
        } else {
            avatarPlaceholder
        }
    }

    private var avatarPlaceholder: some View {
        Circle()
            .fill(
                LinearGradient(
                    gradient: Gradient(colors: [
                        Color.dynamicAccent(theme: themeManager.currentTheme).opacity(0.3),
                        Color.dynamicAccent(theme: themeManager.currentTheme).opacity(0.1)
                    ]),
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .frame(width: 44, height: 44)
            .overlay(
                Image(systemName: "person.fill")
                    .font(.system(size: 20, weight: .medium))
                    .foregroundColor(Color.dynamicTextSecondary(theme: themeManager.currentTheme))
            )
    }

    private func computeAvatarURL() -> String {
        // Priority 1: Backend profile picture
        if let profilePic = profileService.userProfile?.picture, !profilePic.isEmpty {
            return cleanURL(profilePic)
        }
        // Priority 2: Auth0 user picture
        if let userPic = authService.user?.picture, !userPic.isEmpty {
            return cleanURL(userPic)
        }
        // Priority 3: Generated avatar from name
        let name = authService.user?.name ?? userName
        let encoded = name.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "User"
        let bg = String(format: "%06X", abs(name.hashValue) % 0xFFFFFF)
        return "https://ui-avatars.com/api/?name=\(encoded)&size=128&background=\(bg)&color=fff&format=png"
    }

    private func computeAvatarCacheKey() -> String {
        // Usar solo el userId para el cache key - la URL ya contiene info única de la foto
        if let userId = authService.user?.id {
            let normalizedId = userId
                .replacingOccurrences(of: "user_", with: "")
                .replacingOccurrences(of: "auth0|", with: "")
            return "avatar_header_\(normalizedId)"
        }
        return "avatar_header_default"
    }

    private func cleanURL(_ urlString: String) -> String {
        var s = urlString.trimmingCharacters(in: .whitespacesAndNewlines)
        while s.hasSuffix("?") { s.removeLast() }
        return s
    }
}


// MARK: - Featured Event Section
struct FeaturedEventSection: View {
    let events: [Event]
    let themeManager: ThemeManager
    @EnvironmentObject var eventService: EventService
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    // Payment-related properties
    let paymentService: EventPaymentService
    @Binding var showingPaymentSheet: Bool
    @Binding var currentPaymentIntent: PaymentIntent?
    @Binding var currentParticipationId: Int?
    @Binding var selectedEventForPayment: Event?
    
    private var featuredEvent: Event? {
        events.filter { $0.startTime > Date() }
              .sorted { $0.startTime < $1.startTime }
              .first
    }
    
    private func isUserRegistered(for event: Event) -> Bool {
        let isRegistered = eventService.isUserRegistered(eventId: event.id)
        print("🏠 HomeView: Event \(event.id) (\(event.title)) - Status: \(event.status) - IsRegistered: \(isRegistered)")
        return isRegistered
    }
    
    private func participationButtonConfig(for event: Event) -> (title: String, icon: String, color: Color) {
        let isRegistered = isUserRegistered(for: event)
        
        print("🏠 HomeView: participationButtonConfig - Event \(event.id) - Status: \(event.status) - IsRegistered: \(isRegistered)")
        print("🏠 HomeView: Detailed info - Title: '\(event.title)', Status raw: '\(event.status)', Status == .active: \(event.status == .active)")
        
        let result: (title: String, icon: String, color: Color)
        switch event.status {
        case .active:
            if isRegistered {
                result = ("En Vivo", "dot.radiowaves.left.and.right", Color.green)
            } else {
                result = ("En Vivo", "dot.radiowaves.left.and.right", Color.gray)
            }
        case .scheduled:
            if isRegistered {
                result = ("Registrado", "checkmark.circle.fill", Color.green)
            } else {
                result = ("Unirse", "plus.circle.fill", Color.dynamicAccent(theme: themeManager.currentTheme))
            }
        case .completed:
            if isRegistered {
                result = ("Participaste", "checkmark.circle.fill", Color.gray)
            } else {
                result = ("Completado", "clock.fill", Color.gray)
            }
        case .cancelled:
            result = ("Cancelado", "xmark.circle.fill", Color.red)
        }
        
        print("🏠 HomeView: Button config result - Title: '\(result.title)', Icon: '\(result.icon)'")
        return result
    }
    
    private func canPerformAction(for event: Event, isRegistered: Bool) -> Bool {
        switch event.status {
        case .scheduled:
            // Para eventos programados, permitir join/cancel normalmente
            return true
        case .active:
            // Para eventos activos (en vivo), no permitir ninguna acción
            // El evento ya está en curso
            return false
        case .completed, .cancelled:
            // No permitir acciones en eventos completados o cancelados
            return false
        }
    }
    
    private func eventIconName(for status: EventStatus) -> String {
        switch status {
        case .active:
            return "dot.radiowaves.left.and.right"
        case .scheduled:
            return "figure.run"
        case .completed:
            return "checkmark.circle"
        case .cancelled:
            return "xmark.circle"
        }
    }
    
    private func eventIconBackgroundColor(for status: EventStatus) -> Color {
        switch status {
        case .active:
            return Color.dynamicAccent(theme: themeManager.currentTheme)
        case .scheduled:
            return Color.dynamicAccent(theme: themeManager.currentTheme)
        case .completed:
            return Color.gray
        case .cancelled:
            return Color.dynamicAccent(theme: themeManager.currentTheme)
        }
    }
    
    private var timeFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"
        formatter.timeZone = TimeZone.current
        return formatter
    }
    
    private var dayFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE, MMM d"
        formatter.timeZone = TimeZone.current
        return formatter
    }
    
    private var timeUntilEvent: String {
        guard let event = featuredEvent else { return "" }
        
        let now = Date()
        let timeInterval = event.startTime.timeIntervalSince(now)
        let days = Int(timeInterval / 86400)
        let hours = Int(timeInterval / 3600)
        let minutes = Int((timeInterval.truncatingRemainder(dividingBy: 3600)) / 60)
        
        if days > 0 {
            return "En \(days) día\(days > 1 ? "s" : "")"
        } else if hours > 0 {
            return "En \(hours)h \(minutes)m"
        } else {
            return "En \(minutes)m"
        }
    }

    var body: some View {
        Group {
            if let event = featuredEvent {
                featuredEventContent(event: event)
            }
        }
    }

    @ViewBuilder
    private func featuredEventContent(event: Event) -> some View {
        VStack(spacing: 16) {
            featuredEventHeader()
            featuredEventCard(event: event)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Featured event: \(event.title) on \(dayFormatter.string(from: event.startTime)) at \(timeFormatter.string(from: event.startTime))")
    }

    @ViewBuilder
    private func featuredEventHeader() -> some View {
        SectionHeaderView(
            title: NSLocalizedString("featured_event", comment: "Featured Event"),
            ctaTitle: "view_all",
            themeManager: themeManager,
            onTapCTA: { /* Navegar a lista de eventos - manejado por vista de eventos */ }
        )
        .padding(.horizontal, 0)
    }

    @ViewBuilder
    private func featuredEventCard(event: Event) -> some View {
        ZStack {
                    RoundedRectangle(cornerRadius: 20)
                        .fill(Color.dynamicSurface(theme: themeManager.currentTheme))
                    
                    VStack(spacing: 20) {
                        // Event header with icon
                        HStack(spacing: 16) {
                            // Event icon (changes based on status)
                            ZStack {
                                Circle()
                                    .fill(eventIconBackgroundColor(for: event.status).opacity(0.15))
                                    .frame(width: 50, height: 50)
                                
                                Image(systemName: eventIconName(for: event.status))
                                    .font(.system(size: 24, weight: .semibold))
                                    .foregroundColor(eventIconBackgroundColor(for: event.status))
                                
                                // Pulsing animation for active events
                                if event.status == .active {
                                    Circle()
                                        .stroke(Color.dynamicAccent(theme: themeManager.currentTheme).opacity(0.3), lineWidth: 2)
                                        .frame(width: 50, height: 50)
                                        .scaleEffect(1.2)
                                        .opacity(0.7)
                                        .animation(.easeInOut(duration: 1.0).repeatForever(autoreverses: true), value: event.status == .active)
                                }
                            }
                            
                            VStack(alignment: .leading, spacing: 8) {
                                Text(event.title)
                                    .font(.cappedDynamicSystem(size: 20, weight: .bold, maxSize: 26))
                                    .foregroundColor(Color.dynamicText(theme: themeManager.currentTheme))
                                    .lineLimit(2)
                                    .minimumScaleFactor(0.9)
                                
                                Text(dayFormatter.string(from: event.startTime) + " • " + timeFormatter.string(from: event.startTime))
                                    .font(.cappedDynamicSystem(size: 14, weight: .medium, maxSize: 18))
                                    .foregroundColor(Color.dynamicTextSecondary(theme: themeManager.currentTheme))
                            }
                            
                            Spacer()
                            
                            // Status and time badge
                            VStack(spacing: 4) {
                                // Status badge for active events
                                if event.status == .active {
                                    Text(NSLocalizedString("live_badge", comment: "Live badge"))
                                        .font(.cappedDynamicSystem(size: 10, weight: .black, maxSize: 12))
                                        .foregroundColor(.white)
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 3)
                                        .background(
                                            Capsule()
                                                .fill(Color.dynamicAccent(theme: themeManager.currentTheme))
                                        )
                                        .accessibilityLabel(Text(NSLocalizedString("live_badge_accessibility", comment: "Event is live")))
                                }
                                
                                // Time until event badge (only for scheduled events)
                                if event.status == .scheduled {
                                    Text(timeUntilEvent)
                                        .font(.cappedDynamicSystem(size: 11, weight: .bold, maxSize: 14))
                                        .foregroundColor(Color.dynamicAccent(theme: themeManager.currentTheme))
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 4)
                                        .background(
                                            Capsule()
                                                .fill(Color.dynamicAccent(theme: themeManager.currentTheme).opacity(0.1))
                                        )
                                        .accessibilityLabel(Text(String(format: NSLocalizedString("time_until_event", comment: "Time until event"), timeUntilEvent)))
                                }
                            }
                        }
                        
                        // Description
                        if !event.description.isEmpty {
                            HStack {
                                Text(event.description)
                                    .font(.cappedDynamicSystem(size: 14, weight: .medium, maxSize: 18))
                                    .foregroundColor(Color.dynamicTextSecondary(theme: themeManager.currentTheme))
                                    .lineLimit(2)
                                    .multilineTextAlignment(.leading)
                                
                                Spacer()
                            }
                        }
                        
                        // Action buttons
                        HStack(spacing: 12) {
                            // Join/Registered button
                            if let event = featuredEvent {
                                let isRegistered = isUserRegistered(for: event)
                                let buttonConfig = participationButtonConfig(for: event)
                                
                                // Capture the loading state from environment object
                                Button(action: {
                                    // Validar si la acción es permitida según el estado del evento
                                    guard canPerformAction(for: event, isRegistered: isRegistered) else {
                                        return
                                    }
                                    
                                    Task {
                                        print("💰 HomeView: Button action - Event \(event.id) '\(event.title)' - isPaid: \(event.isPaid ?? false) - isRegistered: \(isRegistered)")

                                        if isRegistered {
                                            // Cancel registration (could include refund for paid events)
                                            if event.isPaid == true {
                                                let refundResult = await paymentService.cancelWithRefund(eventId: event.id)
                                                if refundResult?.success == true {
                                                    await eventService.fetchEvents()
                                                }
                                            } else {
                                                await eventService.cancelEvent(eventId: event.id)
                                            }
                                        } else {
                                            // Join event - check if it's a paid event
                                            if event.isPaid == true {
                                                // Paid event - needs payment process
                                                print("💳 Calling registerForPaidEvent for event \(event.id)")
                                                if let participation = await paymentService.registerForPaidEvent(eventId: event.id) {
                                                    print("✅ Got participation response: paymentRequired=\(participation.paymentRequired ?? false), clientSecret=\(participation.paymentClientSecret != nil)")
                                                    if participation.paymentRequired == true,
                                                       let clientSecret = participation.paymentClientSecret {
                                                        // Set up payment intent and show payment sheet
                                                        print("🎫 Setting up payment sheet with amount: \(participation.paymentAmount ?? 0)")
                                                        print("🎫 clientSecret: \(clientSecret.prefix(20))...")
                                                        print("🎫 participationId: \(participation.id)")
                                                        print("🎫 event: \(event.title)")
                                                        await MainActor.run {
                                                            print("🎫 [MainActor] Creating PaymentIntent...")
                                                            currentPaymentIntent = PaymentIntent(
                                                                clientSecret: clientSecret,
                                                                paymentIntentId: participation.paymentIntentId ?? "",
                                                                stripeAccountId: participation.stripeAccountId,
                                                                amount: participation.paymentAmount ?? 0,
                                                                currency: participation.paymentCurrency ?? "EUR",
                                                                paymentDeadline: participation.paymentDeadline
                                                            )
                                                            print("🎫 [MainActor] currentPaymentIntent set: \(currentPaymentIntent != nil)")
                                                            currentParticipationId = participation.id
                                                            print("🎫 [MainActor] currentParticipationId set: \(currentParticipationId ?? -1)")
                                                            selectedEventForPayment = event
                                                            print("🎫 [MainActor] selectedEventForPayment set: \(selectedEventForPayment?.title ?? "nil")")

                                                            // Open sheet immediately - capture list in sheet closure handles state correctly
                                                            showingPaymentSheet = true
                                                            print("✅ [MainActor] Payment sheet should now be showing: showingPaymentSheet=\(showingPaymentSheet)")
                                                            print("✅ [MainActor] currentPaymentIntent final check: \(currentPaymentIntent != nil)")
                                                        }
                                                    } else {
                                                        // Registration successful without payment required
                                                        print("ℹ️ Payment not required, fetching events")
                                                        await eventService.fetchEvents()
                                                    }
                                                } else {
                                                    print("❌ registerForPaidEvent returned nil")
                                                }
                                            } else {
                                                // Free event - regular join
                                                await eventService.joinEvent(eventId: event.id)
                                            }
                                        }
                                    }
                                }) {
                                    HStack(spacing: 8) {
                                        if eventService.isJoiningEvent {
                                            ProgressView()
                                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                                .scaleEffect(0.8)
                                        } else {
                                            Image(systemName: buttonConfig.icon)
                                                .font(.system(size: 14, weight: .semibold))
                                        }
                                        
                                        Text(eventService.isJoiningEvent ? "Procesando..." : buttonConfig.title)
                                            .font(.cappedDynamicSystem(size: 14, weight: .semibold, maxSize: 18))
                                    }
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 20)
                                    .padding(.vertical, 12)
                                    .background(
                                        Capsule()
                                            .fill(eventService.isJoiningEvent ? Color.gray : buttonConfig.color)
                                    )
                                }
                                .disabled(eventService.isJoiningEvent || !canPerformAction(for: event, isRegistered: isRegistered))
                            }
                            
                            // Chat button
                            Button(action: {
                                // TODO: Open event chat
                            }) {
                                HStack(spacing: 8) {
                                    Image(systemName: "message.fill")
                                        .font(.system(size: 14, weight: .semibold))
                                    Text("Chat")
                                        .font(.cappedDynamicSystem(size: 14, weight: .semibold, maxSize: 18))
                                }
                                .foregroundColor(Color.dynamicText(theme: themeManager.currentTheme))
                                .padding(.horizontal, 20)
                                .padding(.vertical, 12)
                                .background(
                                    Capsule()
                                        .fill(Color.dynamicSurface(theme: themeManager.currentTheme))
                                        .overlay(
                                            Capsule()
                                                .stroke(Color.dynamicBorder(theme: themeManager.currentTheme), lineWidth: 1)
                                        )
                                )
                            }
                            
                            Spacer()
                        }
                    }
                    .padding(24)
                }
                .padding(.horizontal, 4)
        }
    }

// MARK: - StatCardSkeleton Component
struct StatCardSkeleton: View {
    let themeManager: ThemeManager
    @State private var isAnimating = false
    
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.dynamicSurface(theme: themeManager.currentTheme))
            
            VStack(spacing: 12) {
                HStack {
                    Circle()
                        .fill(Color.secondary.opacity(0.3))
                        .frame(width: 32, height: 32)
                    Spacer()
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color.secondary.opacity(0.3))
                            .frame(width: 40, height: 24)
                        Spacer()
                    }
                    
                    HStack {
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color.secondary.opacity(0.3))
                            .frame(height: 16)
                        Spacer()
                    }
                }
            }
            .padding(16)
        }
        .opacity(isAnimating ? 0.6 : 1.0)
        .drawingGroup()
        .animation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true), value: isAnimating)
        .onAppear {
            isAnimating = true
        }
    }
}

// MARK: - Primary CTA Button
struct PrimaryCTAButton: View {
    let action: () -> Void
    @State private var isPressed = false
    @State private var isPulsing = false
    @EnvironmentObject var themeManager: ThemeManager

    var body: some View {
        Button(action: {
            isPressed = true
            HapticManager.shared.play(.medium)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                isPressed = false
                action()
            }
        }) {
            HStack(spacing: 12) {
                Image(systemName: "sparkles")
                    .font(.system(size: 18, weight: .semibold))
                    .rotationEffect(.degrees(isPulsing ? 5 : -5))

                VStack(spacing: 2) {
                    Text("Reserva tu Primera Clase")
                        .font(.system(size: 17, weight: .bold))
                    Text("¡GRATIS HOY!")
                        .font(.system(size: 12, weight: .bold))
                        .tracking(1)
                        .opacity(0.9)
                }

                Image(systemName: "arrow.right.circle.fill")
                    .font(.system(size: 20, weight: .semibold))
                    .offset(x: isPulsing ? 3 : 0)
            }
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 18)
            .background(
                ZStack {
                    // Gradiente de fondo con animación
                    LinearGradient(
                        colors: [
                            Color(hex: "#D93333") ?? .red,
                            Color(hex: "#FF6B6B") ?? .red.opacity(0.8)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )

                    // Efecto de brillo animado
                    LinearGradient(
                        colors: [
                            Color.white.opacity(0),
                            Color.white.opacity(0.3),
                            Color.white.opacity(0)
                        ],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                    .frame(width: 60)
                    .offset(x: isPulsing ? 200 : -200)
                    .animation(.easeInOut(duration: 2.5).repeatForever(autoreverses: false), value: isPulsing)
                }
            )
            .cornerRadius(16)
            .shadow(color: (Color(hex: "#D93333") ?? .red).opacity(0.3), radius: 12, x: 0, y: 6)
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(0.3),
                                Color.white.opacity(0.1)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1
                    )
            )
        }
        .scaleEffect(isPressed ? 0.95 : 1.0)
        .animation(.spring(response: 0.3, dampingFraction: 0.6), value: isPressed)
        .onAppear {
            withAnimation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true)) {
                isPulsing = true
            }
        }
    }
}

#Preview {
    HomeView()
        .environmentObject(ThemeManager())
        .environmentObject(EventService())
        .environmentObject(AuthServiceDirect())
}
