//
//  CoachHomeView.swift
//  Gym_API
//
//  Inicio del CLIENTE de un entrenador personal.
//
//  Regla de esta pantalla: solo se pintan widgets cuyos datos existen de verdad. Donde el
//  backend todavía no tiene nada (programa semanal, registro de series, pack de sesiones) se
//  declara el estado real en lugar de rellenar con cifras de ejemplo.
//  Ver PLAN_MODO_CLIENTE_PT.md.
//

import SwiftUI

struct CoachHomeView: View {
    // MARK: - Dependencias
    @EnvironmentObject var themeManager: ThemeManager
    @EnvironmentObject var classService: ClassService
    @EnvironmentObject var authService: AuthServiceDirect
    @EnvironmentObject var coachingService: CoachingService
    @EnvironmentObject var healthService: HealthService
    @StateObject private var profileService = UserProfileService.shared

    // MARK: - Acciones (las resuelve ClientMainTabView, que posee pestañas y sheets)
    let onOpenSessions: () -> Void
    let onOpenCoachChat: () -> Void
    let onOpenNutrition: () -> Void
    let onShowQR: () -> Void
    let onOpenNotifications: () -> Void
    let onOpenProfile: () -> Void

    @State private var showingCheckIn = false

    // MARK: - Datos derivados

    private var userName: String {
        if let firstName = profileService.userProfile?.firstName, !firstName.isEmpty {
            return firstName
        }
        if let name = authService.user?.name, !name.isEmpty {
            let first = name.components(separatedBy: " ").first ?? name
            return first.contains("@") ? (first.components(separatedBy: "@").first ?? "Athlete") : first
        }
        return "Athlete"
    }

    private var userInitials: String {
        let source = profileService.userProfile?.fullName
            ?? profileService.userProfile?.firstName
            ?? authService.user?.name
            ?? userName
        let initials = source
            .components(separatedBy: " ")
            .prefix(2)
            .compactMap { $0.first }
            .map { String($0).uppercased() }
        return initials.isEmpty ? "?" : initials.joined()
    }

    /// Próxima sesión en la que el cliente está inscrito.
    /// Misma derivación que HomeView mientras no exista el módulo de sesiones 1:1.
    private var nextSession: GymClass? {
        let now = Date()
        return classService.classes
            .filter { (classService.userRegistrationStatus[$0.id] ?? false) && $0.startTime > now }
            .sorted { $0.startTime < $1.startTime }
            .first
    }

    // MARK: - Body

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(spacing: 20) {
                    HomeHeaderView(
                        userName: userName,
                        userInitials: userInitials,
                        pictureURL: profileService.userProfile?.picture,
                        onNotificationTap: onOpenNotifications,
                        onAvatarTap: onOpenProfile
                    )

                    if let session = nextSession {
                        // El diseño pide sitio, contexto del programa y la identidad del coach
                        // dentro del héroe. Las tres cosas existen ya: `room` y `notes` viajan
                        // en la sesión y no se pintaban, y el coach lo resuelve CoachingService.
                        TodaySessionHeroCard(
                            gymClass: session,
                            onCheckInTap: onShowQR,
                            onCardTap: onOpenSessions,
                            place: session.room,
                            contextNote: session.notes,
                            roleLabel: "Your coach",
                            personName: coachingService.coach?.fullName,
                            personInitials: coachingService.coach?.initials,
                            personPictureURL: coachingService.coach?.pictureURL
                        )
                    } else {
                        NoUpcomingSessionCard(onSeeSessions: onOpenSessions)
                    }

                    ClientQuickActionsGrid(
                        onSessions: onOpenSessions,
                        onCoach: onOpenCoachChat,
                        onCheckIn: { showingCheckIn = true },
                        onNutrition: onOpenNutrition
                    )

                    CoachCardView(
                        coach: coachingService.coach,
                        state: coachingService.coachState,
                        onMessageCoach: onOpenCoachChat,
                        onRetry: { Task { await loadCoachAndNote(forceRefresh: true) } },
                        note: coachingService.coachNote
                    )

                    // El diseño coloca progreso y check-in uno al lado del otro. Solo tiene
                    // sentido cuando hay objetivo de fuerza; si no, el check-in se queda a
                    // ancho completo y conserva su serie de peso.
                    if let strengthGoal = healthService.strengthGoal {
                        HStack(alignment: .top, spacing: 10) {
                            StrengthGoalCardView(goal: strengthGoal, compact: true)
                            checkInCard(compact: true)
                        }
                        .fixedSize(horizontal: false, vertical: true)
                    } else {
                        checkInCard(compact: false)
                    }

                    ProgramPlaceholderCard()

                    Spacer(minLength: 100)
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)
            }
            .background(Color.dynamicBackground(theme: themeManager.currentTheme).ignoresSafeArea())
            .navigationBarHidden(true)
            .task { await loadClientData() }
            .refreshable { await loadClientData(forceRefresh: true) }
            .sheet(isPresented: $showingCheckIn) {
                WeightCheckInSheet()
                    .environmentObject(themeManager)
                    .environmentObject(healthService)
            }
        }
    }

    private func checkInCard(compact: Bool) -> some View {
        WeeklyCheckInStatusCardView(
            history: healthService.weightHistory,
            currentWeight: healthService.currentWeight,
            weeklyChange: healthService.weeklyWeightChange,
            hasCheckedInThisWeek: healthService.hasCheckedInThisWeek,
            state: healthService.weightState,
            onCheckIn: { showingCheckIn = true },
            onRetry: { Task { await healthService.loadAll() } },
            compact: compact
        )
    }

    private func loadClientData(forceRefresh: Bool = false) async {
        async let coach: Void = loadCoachAndNote(forceRefresh: forceRefresh)
        async let health: Void = healthService.loadAll()
        async let sessions: Void = classService.loadSessionsForDateIfNeeded(date: Date())
        _ = await (coach, health, sessions)
    }

    /// La nota necesita saber quién es el coach, así que va después y no en paralelo.
    private func loadCoachAndNote(forceRefresh: Bool) async {
        await coachingService.loadCoach(forceRefresh: forceRefresh)
        await coachingService.loadCoachNote(forceRefresh: forceRefresh)
    }
}

// MARK: - Acciones rápidas del cliente

/// Rejilla de 4 acciones. Mantiene la geometría de `QuickActionsGrid` (icono 18pt en caja
/// 36x36, tarjeta de radio 22) pero con las acciones del cliente y con tokens del tema: el
/// original lleva las etiquetas fijas y un borde blanco que en tema claro es invisible.
private struct ClientQuickActionsGrid: View {
    let onSessions: () -> Void
    let onCoach: () -> Void
    let onCheckIn: () -> Void
    let onNutrition: () -> Void

    @EnvironmentObject var themeManager: ThemeManager

    private var actions: [(icon: String, label: String, action: () -> Void)] {
        [
            ("calendar", "Sessions", onSessions),
            ("bubble.left.and.text.bubble.right", "Coach", onCoach),
            ("figure.stand", "Check-in", onCheckIn),
            ("fork.knife", "Nutrition", onNutrition),
        ]
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("QUICK ACTIONS")
                .font(.system(size: 9, weight: .bold))
                .tracking(1.0)
                .foregroundColor(Color.dynamicTextTertiary(theme: themeManager.currentTheme))
                .frame(maxWidth: .infinity, alignment: .leading)

            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 4), spacing: 8) {
                ForEach(Array(actions.enumerated()), id: \.offset) { _, item in
                    Button {
                        HapticManager.shared.buttonTap()
                        item.action()
                    } label: {
                        VStack(spacing: 8) {
                            ZStack {
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(Color.dynamicSurface2(theme: themeManager.currentTheme))
                                    .frame(width: 36, height: 36)
                                Image(systemName: item.icon)
                                    .font(.system(size: 18, weight: .regular))
                                    .foregroundColor(Color.dynamicText(theme: themeManager.currentTheme))
                            }
                            Text(item.label)
                                .font(.system(size: 11, weight: .medium))
                                .foregroundColor(Color.dynamicText(theme: themeManager.currentTheme))
                                .lineLimit(2)
                                .multilineTextAlignment(.center)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .padding(.horizontal, 8)
                        .background(Color.dynamicSurface(theme: themeManager.currentTheme))
                        .clipShape(RoundedRectangle(cornerRadius: 22))
                        .overlay(
                            RoundedRectangle(cornerRadius: 22)
                                .stroke(Color.dynamicBorder(theme: themeManager.currentTheme).opacity(0.15), lineWidth: 1)
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
}

// MARK: - Estados vacíos honestos

/// Sustituye al héroe cuando el cliente no tiene ninguna sesión reservada.
private struct NoUpcomingSessionCard: View {
    let onSeeSessions: () -> Void
    @EnvironmentObject var themeManager: ThemeManager

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("YOUR NEXT SESSION")
                .font(.system(size: 11, weight: .semibold))
                .tracking(0.8)
                .foregroundColor(Color.dynamicTextTertiary(theme: themeManager.currentTheme))

            Text("No session booked")
                .font(.system(size: 20, weight: .bold))
                .tracking(-0.4)
                .foregroundColor(Color.dynamicText(theme: themeManager.currentTheme))
                .fixedSize(horizontal: false, vertical: true)

            Text("When your trainer schedules your next one, it shows up here with the day, time and place.")
                .font(.system(size: 14, weight: .regular))
                .foregroundColor(Color.dynamicTextSecondary(theme: themeManager.currentTheme))
                .fixedSize(horizontal: false, vertical: true)

            Button(action: onSeeSessions) {
                HStack(spacing: 6) {
                    Text("See my sessions")
                        .font(.system(size: 13, weight: .semibold))
                    Image(systemName: "chevron.right")
                        .font(.system(size: 11, weight: .semibold))
                }
                .foregroundColor(Color.dynamicAccent(theme: themeManager.currentTheme))
            }
            .buttonStyle(.plain)
            .padding(.top, 2)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(Color.dynamicSurface(theme: themeManager.currentTheme))
        .clipShape(RoundedRectangle(cornerRadius: 22))
        .overlay(
            RoundedRectangle(cornerRadius: 22)
                .stroke(Color.dynamicBorder(theme: themeManager.currentTheme).opacity(0.15), lineWidth: 1)
        )
    }
}

/// Hueco del programa semanal (widget 4) y del registro de sesión (widget 8).
/// Se pinta como "aún no disponible" en lugar de con datos de ejemplo: un widget que inventa
/// una cifra es peor que un widget que no está.
private struct ProgramPlaceholderCard: View {
    @EnvironmentObject var themeManager: ThemeManager

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: "list.bullet.rectangle")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(Color.dynamicAccent(theme: themeManager.currentTheme))
                Text("YOUR PROGRAM")
                    .font(.system(size: 11, weight: .semibold))
                    .tracking(0.8)
                    .foregroundColor(Color.dynamicTextTertiary(theme: themeManager.currentTheme))
            }

            Text("Your trainer hasn't published your training program yet.")
                .font(.system(size: 14, weight: .regular))
                .foregroundColor(Color.dynamicTextSecondary(theme: themeManager.currentTheme))
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(Color.dynamicSurface(theme: themeManager.currentTheme))
        .clipShape(RoundedRectangle(cornerRadius: 22))
        .overlay(
            RoundedRectangle(cornerRadius: 22)
                .stroke(
                    Color.dynamicBorder(theme: themeManager.currentTheme).opacity(0.15),
                    style: StrokeStyle(lineWidth: 1, dash: [4, 4])
                )
        )
    }
}
