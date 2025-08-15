import SwiftUI

struct HomeView: View {
    @EnvironmentObject var themeManager: ThemeManager
    @EnvironmentObject var eventService: EventService
    @EnvironmentObject var authService: AuthServiceDirect
    @StateObject private var gymService = GymService.shared
    @EnvironmentObject var classService: ClassService
    @StateObject private var profileService = UserProfileService.shared
    @ObservedObject private var userStatsService = UserStatsService.shared
    @State private var currentDate = Date()
    
    private var greeting: String {
        let hour = Calendar.current.component(.hour, from: currentDate)
        switch hour {
        case 6..<12: return "Buenos días"
        case 12..<17: return "Buenas tardes"
        case 17..<22: return "Buenas noches"
        default: return "Buenas noches"
        }
    }
    
    private var userName: String {
        authService.user?.name.components(separatedBy: " ").first ?? "Atleta"
    }
    
    private var motivationalQuestion: String {
        let hour = Calendar.current.component(.hour, from: currentDate)
        switch hour {
        case 6..<12: return "¿Listo para conquistar el día?"
        case 12..<17: return "¿Preparado para entrenar?"
        case 17..<22: return "¿Es hora de tu próxima clase?"
        default: return "¿Planificando el entrenamiento de mañana?"
        }
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
                
                ScrollView(.vertical, showsIndicators: false) {
                    VStack(spacing: 20) {
                        // Hero Section with personalized greeting
                        HeroSection(greeting: greeting, userName: userName, motivationalQuestion: motivationalQuestion, themeManager: themeManager, authService: authService)
                        
                        // Streak Indicator - Siempre mostrar con un valor por defecto
                        HStack {
                            StreakIndicator(
                                streakCount: max(userStatsService.userStats.currentStreak, 3), // Mínimo 3 días si no hay datos
                                theme: themeManager.currentTheme
                            )
                            Spacer()
                        }
                        .padding(.horizontal, 20)
                        .transition(.asymmetric(
                            insertion: .scale.combined(with: .opacity),
                            removal: .opacity
                        ))
                        
                        // Next Class Card (if user has upcoming registered classes)
                        NextClassCard(themeManager: themeManager, classService: classService)
                        
                        // Quick Access Actions (4 circular buttons)
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
                        
                        // Featured Event (single event with action buttons)
                        if !eventService.events.isEmpty {
                            FeaturedEventSection(events: eventService.events, themeManager: themeManager)
                                .environmentObject(eventService)
                        } else {
                            // Empty state placeholder for no events
                            HStack {
                                Image(systemName: "calendar")
                                    .foregroundColor(Color.dynamicTextSecondary(theme: themeManager.currentTheme))
                                Text(NSLocalizedString("no_upcoming_events", comment: "No upcoming events"))
                                    .foregroundColor(Color.dynamicTextSecondary(theme: themeManager.currentTheme))
                                    .font(.cappedDynamicSystem(size: 14, weight: .medium, maxSize: 18))
                                Spacer()
                            }
                            .padding(12)
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(Color.dynamicSurface(theme: themeManager.currentTheme))
                            )
                        }
                        
                        // Recent Activity (completed classes/events)
                        HomeRecentActivitySection(themeManager: themeManager, classService: classService, eventService: eventService)
                        
                        Spacer(minLength: 100)
                    }
                    .padding(.horizontal, 16)
                }
                .safeAreaPadding(.top, 16)
                // .drawingGroup() // Comentado temporalmente para debug
            }
            .refreshable {
                await eventService.fetchEvents()
                await eventService.fetchUserParticipations()
                await userStatsService.fetchComprehensiveStats()
            }
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        themeManager.toggleTheme()
                    }) {
                        Image(systemName: themeManager.currentTheme == .dark ? "sun.max.fill" : "moon.fill")
                            .font(.system(size: 18))
                            .foregroundColor(Color.dynamicAccent(theme: themeManager.currentTheme))
                    }
                    .accessibilityLabel("Toggle theme")
                    .accessibilityHint("Switch between light and dark mode")
                    .accessibilityValue("Current theme: \(themeManager.currentTheme.displayName)")
                    .accessibleTouchTarget()
                }
            }
        }
        .onAppear {
            debugLog("🏠 HomeView.onAppear iniciado")
            currentDate = Date()
            setupServices()
            debugLog("🏠 setupServices completado, iniciando tareas async")
            Task {
                debugLog("🏠 Iniciando fetchEvents...")
                await eventService.fetchEvents()
                debugLog("🏠 fetchEvents completado, iniciando fetchUserParticipations...")
                await eventService.fetchUserParticipations()
                debugLog("🏠 fetchUserParticipations completado, iniciando getMyGyms...")
                await gymService.getMyGyms()
                debugLog("🏠 getMyGyms completado, iniciando fetchComprehensiveStats...")
                await userStatsService.fetchComprehensiveStats()
                debugLog("🏠 fetchComprehensiveStats completado")
            }
        }
    }
    
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
        debugLog("🏠 AuthService configurado en userStatsService: \(userStatsService.authService != nil)")
        
        // Setup location service
        debugLog("🏠 Configurando LocationService...")
        LocationService.shared.requestLocationPermission()
        debugLog("🏠 setupServices completado")
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
                ZStack {
                    // Avatar background with red accent
                    Circle()
                        .fill(Color.dynamicAccent(theme: themeManager.currentTheme))
                        .frame(width: 60, height: 60)
                        .shadow(
                            color: Color.dynamicAccent(theme: themeManager.currentTheme).opacity(0.2),
                            radius: 4,
                            x: 0,
                            y: 2
                        )
                    
                    // User avatar or default icon (cached)
                    Group {
                        if let urlString = resolvedAvatarURL(authService: authService), !urlString.isEmpty,
                           let user = authService.user {
                            let normalizedId = user.id
                                .replacingOccurrences(of: "user_", with: "")
                                .replacingOccurrences(of: "auth0|", with: "")
                            CustomImageView(url: urlString, cacheKey: "avatar_self_\(normalizedId)", size: 56) {
                                AnyView(
                                    Image(systemName: "person.fill")
                                        .font(.system(size: 28, weight: .semibold))
                                        .foregroundColor(.white)
                                )
                            }
                            .accessibilityLabel(Text("Foto de perfil"))
                        } else {
                            Image(systemName: "person.fill")
                                .font(.system(size: 28, weight: .semibold))
                                .foregroundColor(.white)
                                .accessibilityLabel(Text("Foto de perfil por defecto"))
                        }
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


// MARK: - Featured Event Section
struct FeaturedEventSection: View {
    let events: [Event]
    let themeManager: ThemeManager
    @EnvironmentObject var eventService: EventService
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    
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
            return Color.red
        case .scheduled:
            return Color.dynamicAccent(theme: themeManager.currentTheme)
        case .completed:
            return Color.gray
        case .cancelled:
            return Color.red
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
        if let event = featuredEvent {
            VStack(spacing: 16) {
                // Header unificado
                SectionHeaderView(
                    title: NSLocalizedString("featured_event", comment: "Featured Event"),
                    ctaTitle: "view_all",
                    themeManager: themeManager,
                    onTapCTA: { /* Navegar a lista de eventos - manejado por vista de eventos */ }
                )
                .padding(.horizontal, 0)
                
                // Event card
                ZStack {
                    RoundedRectangle(cornerRadius: 20)
                        .fill(Color.dynamicSurface(theme: themeManager.currentTheme))
                        .shadow(
                            color: Color.black.opacity(themeManager.currentTheme == .dark ? 0.2 : 0.08),
                            radius: 8,
                            x: 0,
                            y: 4
                        )
                    
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
                                        .stroke(Color.red.opacity(0.3), lineWidth: 2)
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
                                                .fill(Color.red)
                                        )
                                        .shadow(color: Color.red.opacity(0.3), radius: 2, x: 0, y: 1)
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
                                        if isRegistered {
                                            await eventService.cancelEvent(eventId: event.id)
                                        } else {
                                            await eventService.joinEvent(eventId: event.id)
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
            .accessibilityElement(children: .combine)
            .accessibilityLabel("Featured event: \(event.title) on \(dayFormatter.string(from: event.startTime)) at \(timeFormatter.string(from: event.startTime))")
        } else if eventService.isLoading {
            EventCardSkeleton()
                .environmentObject(themeManager)
        } else {
            // Empty state placeholder for no events
            HStack {
                Image(systemName: "calendar")
                    .foregroundColor(Color.dynamicTextSecondary(theme: themeManager.currentTheme))
                Text(NSLocalizedString("no_upcoming_events", comment: "No upcoming events"))
                    .foregroundColor(Color.dynamicTextSecondary(theme: themeManager.currentTheme))
                    .font(.cappedDynamicSystem(size: 14, weight: .medium, maxSize: 18))
                Spacer()
            }
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.dynamicSurface(theme: themeManager.currentTheme))
            )
        }
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
                .shadow(
                    color: Color.black.opacity(themeManager.currentTheme == .dark ? 0.2 : 0.08),
                    radius: 4,
                    x: 0,
                    y: 2
                )
            
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

#Preview {
    HomeView()
        .environmentObject(ThemeManager())
        .environmentObject(EventService())
        .environmentObject(AuthServiceDirect())
}
