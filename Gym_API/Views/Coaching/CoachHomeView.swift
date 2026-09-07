//
//  CoachHomeView.swift
//  Gym_API
//
//  Inicio del CLIENTE de un entrenador personal.
//
//  Regla de esta pantalla: solo se pintan widgets cuyos datos existen de verdad. Donde el
//  backend todavía no tiene nada se declara el estado real en lugar de rellenar con cifras de
//  ejemplo. Ver PLAN_MODO_CLIENTE_PT.md.
//
//  Con el módulo de entrenamiento, el hueco que declaraba `ProgramPlaceholderCard` ya tiene
//  detrás una asignación real, así que la tarjeta se sustituye por los widgets de
//  `PLAN_MODULO_ENTRENAMIENTO_UX.md` §4: la semana (W4), el acuse del entrenador, la fuerza (W6),
//  el último registro (W8) y, solo en programas de grupo, «Your group today».
//
//  Lo que NO cambia: si el espacio no tiene el módulo activo o el cliente no tiene programa, la
//  home vuelve exactamente a lo que había. El flag `training` falla cerrado.
//

import SwiftUI
import TrainingCore

struct CoachHomeView: View {
    // MARK: - Dependencias
    @EnvironmentObject var themeManager: ThemeManager
    @EnvironmentObject var classService: ClassService
    @EnvironmentObject var authService: AuthServiceDirect
    @EnvironmentObject var coachingService: CoachingService
    @EnvironmentObject var healthService: HealthService
    @EnvironmentObject var trainingService: TrainingService
    @EnvironmentObject var syncCoordinator: TrainingSyncCoordinator
    @EnvironmentObject var workspaceContext: WorkspaceContextService
    @StateObject private var profileService = UserProfileService.shared

    // MARK: - Acciones (las resuelve ClientMainTabView, que posee pestañas y sheets)
    let onOpenSessions: () -> Void
    let onOpenCoachChat: () -> Void
    let onOpenNutrition: () -> Void
    let onShowQR: () -> Void
    let onOpenNotifications: () -> Void
    let onOpenProfile: () -> Void

    @State private var showingCheckIn = false

    // MARK: - Navegación del módulo de entrenamiento
    @State private var path: [TrainingRoute] = []
    @State private var cover: TrainingCover?
    @State private var kudosMember: GroupTodayMember?
    @State private var shareStoryLogId: IdentifiableInt?
    @State private var shareFeedLogId: IdentifiableInt?

    // MARK: - Datos derivados

    private var theme: ThemeManager.AppTheme { themeManager.currentTheme }

    /// El módulo solo existe si el espacio lo tiene encendido. Falla cerrado.
    private var isTrainingEnabled: Bool {
        workspaceContext.isFeatureEnabled(\.training)
    }

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

    /// El ejercicio de referencia de W6: el primero con datos suficientes.
    private var strengthItem: StrengthSummaryItem? {
        trainingService.strengthSummary.first { $0.currentE1RMKg != nil }
            ?? trainingService.strengthSummary.first
    }

    // MARK: - Body

    var body: some View {
        NavigationStack(path: $path) {
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
                        // dentro del héroe. Con el módulo activo el contexto pasa a ser el del
                        // programa («Block 2 · Week 3») y aparece «View plan».
                        TodaySessionHeroCard(
                            gymClass: session,
                            onCheckInTap: onShowQR,
                            onCardTap: onOpenSessions,
                            place: session.room,
                            contextNote: trainingService.myProgram?.contextNote ?? session.notes,
                            roleLabel: "Your coach",
                            personName: coachingService.coach?.fullName,
                            personInitials: coachingService.coach?.initials,
                            personPictureURL: coachingService.coach?.pictureURL,
                            secondaryActionTitle: showsTrainingWidgets ? "View plan" : nil,
                            onSecondaryAction: showsTrainingWidgets
                                ? { path.append(.weeklyProgram(week: nil)) }
                                : nil
                        )
                    } else {
                        NoUpcomingSessionCard(onSeeSessions: onOpenSessions)
                    }

                    CoachCardView(
                        coach: coachingService.coach,
                        state: coachingService.coachState,
                        onMessageCoach: onOpenCoachChat,
                        onRetry: { Task { await loadCoachAndNote(forceRefresh: true) } },
                        note: coachingService.coachNote
                    )

                    if isTrainingEnabled {
                        trainingSection
                    } else {
                        legacyStrengthAndCheckIn
                    }

                    nutritionRow

                    Spacer(minLength: 100)
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)
            }
            .background(Color.dynamicBackground(theme: theme).ignoresSafeArea())
            .navigationBarHidden(true)
            .navigationDestination(for: TrainingRoute.self) { route in
                destination(for: route)
            }
            .task { await loadClientData() }
            .refreshable { await loadClientData(forceRefresh: true) }
            .sheet(isPresented: $showingCheckIn) {
                WeightCheckInSheet()
                    .environmentObject(themeManager)
                    .environmentObject(healthService)
            }
            .sheet(item: $kudosMember) { member in
                KudosSheet(member: member) { logId in
                    await trainingService.sendKudos(logId: logId)
                }
                .environmentObject(themeManager)
            }
            .sheet(item: $shareStoryLogId) { logId in
                WorkoutStoryShareSheet(
                    exerciseName: nil,
                    topRecord: nil,
                    session: nil,
                    log: trainingService.selectedLog?.id == logId.value ? trainingService.selectedLog : nil,
                    unit: WeightUnitPreference.current
                )
                .environmentObject(themeManager)
                .task { await trainingService.fetchLog(logId.value) }
            }
            .sheet(item: $shareFeedLogId) { logId in
                CreatePostView(taggedWorkoutLogId: logId.value)
                    .environmentObject(themeManager)
            }
            .fullScreenCover(item: $cover) { cover in
                coverView(cover)
            }
            .onReceive(NotificationCenter.default.publisher(for: .trainingOpenLog)) { notification in
                guard isTrainingEnabled, let id = notification.object as? Int else { return }
                Analytics.track(Analytics.Event.reminderOpened, [Analytics.Property.logId: id])
                cover = .sessionSummary(logId: id)
            }
        }
    }

    // MARK: - Sección del módulo

    /// Los widgets solo se pintan cuando hay una asignación real detrás.
    private var showsTrainingWidgets: Bool {
        isTrainingEnabled && trainingService.hasActiveProgram
    }

    @ViewBuilder
    private var trainingSection: some View {
        ProgramWeekCardView(
            program: trainingService.myProgram,
            state: trainingService.programState,
            onOpenWeek: { path.append(.weeklyProgram(week: nil)) },
            onOpenDay: { day in
                guard let id = day.dayId else { return }
                path.append(.day(id: id))
            },
            onBrowseSessions: onOpenSessions
        )

        logQuickAction

        if let activity = trainingService.pendingCoachAcknowledgement {
            CoachAckCardView(
                activity: activity,
                onReply: onOpenCoachChat,
                onThank: { await trainingService.thank(logId: activity.logId) }
            )
        }

        if let strengthItem, strengthItem.currentE1RMKg != nil {
            StrengthProgressCardView(
                item: strengthItem,
                state: trainingService.strengthState,
                onOpenHistory: {
                    path.append(.exerciseHistory(key: strengthItem.exerciseKey, name: strengthItem.exerciseName))
                },
                onOpenRecords: { path.append(.records) }
            )
            checkInCard(compact: false)
        } else {
            legacyStrengthAndCheckIn
        }

        LastLogCardView(
            log: trainingService.myProgram?.lastLog ?? trainingService.logs.first,
            state: trainingService.logsState,
            contextNote: trainingService.myProgram?.contextNote,
            onOpen: {
                guard let id = trainingService.myProgram?.lastLog?.id ?? trainingService.logs.first?.id else { return }
                cover = .sessionSummary(logId: id)
            },
            onStartWorkout: { cover = .sessionLog(dayId: nil) },
            onShareToStory: {
                guard let id = lastLogId else { return }
                shareStoryLogId = IdentifiableInt(value: id)
            },
            onShareToFeed: {
                guard let id = lastLogId else { return }
                shareFeedLogId = IdentifiableInt(value: id)
            },
            onViewProgramDay: {
                guard let dayId = trainingService.myProgram?.today?.dayId else { return }
                path.append(.day(id: dayId))
            }
        )

        if trainingService.showsGroupFeatures, let group = trainingService.groupToday {
            GroupTodayCardView(
                group: group,
                state: trainingService.groupState,
                programName: trainingService.myProgram?.program?.name ?? "Your group",
                onSelectMember: { kudosMember = $0 }
            )
        }
    }

    private var lastLogId: Int? {
        trainingService.myProgram?.lastLog?.id ?? trainingService.logs.first?.id
    }

    /// La rejilla de cuatro acciones rápidas se retiró en la fase 1 porque tres de sus cuatro
    /// botones repetían algo visible en la misma pantalla. «Log» no repite nada: es la única
    /// puerta a la pantalla de registro cuando hoy no toca entrenar o toca entreno libre.
    private var logQuickAction: some View {
        Button(action: {
            HapticManager.shared.play(.medium)
            cover = .sessionLog(dayId: trainingService.myProgram?.today?.dayId)
        }) {
            HStack(spacing: 12) {
                Image(systemName: "figure.strengthtraining.traditional")
                    .font(.system(size: 16))
                    .foregroundColor(Color.dynamicAccent(theme: theme))
                    .frame(width: 36, height: 36)
                    .background(Color.dynamicSurface2(theme: theme))
                    .clipShape(RoundedRectangle(cornerRadius: 12))

                VStack(alignment: .leading, spacing: 2) {
                    Text("Log")
                        .font(TrainingType.headline())
                        .foregroundColor(Color.dynamicText(theme: theme))
                    Text(logSubtitle)
                        .font(TrainingType.caption())
                        .foregroundColor(Color.dynamicTextTertiary(theme: theme))
                        .lineLimit(1)
                }

                Spacer(minLength: 0)

                Image(systemName: "chevron.right")
                    .font(.system(size: 12))
                    .foregroundColor(Color.dynamicTextTertiary(theme: theme))
            }
            .padding(14)
            .frame(maxWidth: .infinity, minHeight: 64, alignment: .leading)
            .background(Color.dynamicSurface(theme: theme))
            .clipShape(RoundedRectangle(cornerRadius: 22))
            .overlay(
                RoundedRectangle(cornerRadius: 22)
                    .stroke(Color.dynamicBorder(theme: theme).opacity(0.15), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Log a session")
        .accessibilityHint(logSubtitle)
    }

    private var logSubtitle: String {
        guard let today = trainingService.myProgram?.today, !today.isRest, let name = today.name else {
            return "Free workout"
        }
        return name
    }

    /// Lo que había antes del módulo: objetivo de fuerza de salud y check-in semanal.
    @ViewBuilder
    private var legacyStrengthAndCheckIn: some View {
        if let strengthGoal = healthService.strengthGoal {
            HStack(alignment: .top, spacing: 10) {
                StrengthGoalCardView(goal: strengthGoal, compact: true)
                checkInCard(compact: true)
            }
            .fixedSize(horizontal: false, vertical: true)
        } else {
            checkInCard(compact: false)
        }
    }

    // MARK: - Destinos

    @ViewBuilder
    private func destination(for route: TrainingRoute) -> some View {
        switch route {
        case .weeklyProgram(let week):
            WeeklyProgramView(
                initialWeek: week,
                onOpenDay: { path.append(.day(id: $0)) },
                onStartSession: { cover = .sessionLog(dayId: $0) },
                onMessageCoach: onOpenCoachChat,
                onChangeUnits: onOpenProfile
            )
        case .day(let id):
            TrainingDayDetailView(
                dayId: id,
                onStartSession: { cover = .sessionLog(dayId: $0) },
                onStartFreeWorkout: { cover = .sessionLog(dayId: nil) },
                onViewLog: { cover = .sessionSummary(logId: $0) }
            )
        case .exerciseHistory(let key, let name):
            ExerciseHistoryView(
                exerciseKey: key,
                exerciseName: name,
                onOpenLog: { cover = .sessionSummary(logId: $0) },
                onStartWorkout: { cover = .sessionLog(dayId: nil) },
                onChangeUnits: onOpenProfile,
                onShareProgress: nil
            )
        case .records:
            RecordsView(
                onOpenHistory: { key, name in
                    path.append(.exerciseHistory(key: key, name: name))
                },
                onShare: { record in
                    guard let logId = record.set?.workoutLogId else { return }
                    shareStoryLogId = IdentifiableInt(value: logId)
                }
            )
        }
    }

    @ViewBuilder
    private func coverView(_ cover: TrainingCover) -> some View {
        switch cover {
        case .sessionLog(let dayId):
            SessionLogCoordinatorView(
                dayId: dayId,
                onClose: { self.cover = nil },
                onOpenHistory: { key, name in
                    self.cover = nil
                    path.append(.exerciseHistory(key: key, name: name))
                }
            )
        case .sessionSummary(let logId):
            SessionSummaryView(source: .log(id: logId), onClose: { self.cover = nil })
        }
    }

    // MARK: - Carga

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

    private var nutritionRow: some View {
        Button(action: onOpenNutrition) {
            HStack(spacing: 12) {
                Image(systemName: "fork.knife")
                    .font(.system(size: 16))
                    .foregroundColor(Color.dynamicAccent(theme: theme))
                    .frame(width: 36, height: 36)
                    .background(Color.dynamicSurface2(theme: theme))
                    .clipShape(RoundedRectangle(cornerRadius: 12))

                VStack(alignment: .leading, spacing: 2) {
                    Text("Nutrition")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(Color.dynamicText(theme: theme))
                    Text("Meal plans your coach shares with you")
                        .font(.system(size: 11))
                        .foregroundColor(Color.dynamicTextTertiary(theme: theme))
                }

                Spacer(minLength: 0)

                Image(systemName: "chevron.right")
                    .font(.system(size: 12))
                    .foregroundColor(Color.dynamicTextTertiary(theme: theme))
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.dynamicSurface(theme: theme))
            .clipShape(RoundedRectangle(cornerRadius: 22))
            .overlay(
                RoundedRectangle(cornerRadius: 22)
                    .stroke(Color.dynamicBorder(theme: theme).opacity(0.15), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    private func loadClientData(forceRefresh: Bool = false) async {
        async let coach: Void = loadCoachAndNote(forceRefresh: forceRefresh)
        async let health: Void = healthService.loadAll()
        async let sessions: Void = classService.loadSessionsForDateIfNeeded(date: Date())
        async let training: Void = loadTrainingIfEnabled()
        _ = await (coach, health, sessions, training)
    }

    private func loadTrainingIfEnabled() async {
        guard isTrainingEnabled else { return }
        await trainingService.loadHome()
        if trainingService.showsGroupFeatures, let programId = trainingService.myProgram?.program?.id {
            await trainingService.fetchGroupToday(programId: programId)
        }
    }

    /// La nota necesita saber quién es el coach, así que va después y no en paralelo.
    private func loadCoachAndNote(forceRefresh: Bool) async {
        await coachingService.loadCoach(forceRefresh: forceRefresh)
        await coachingService.loadCoachNote(forceRefresh: forceRefresh)
    }
}

// MARK: - Puente entre S11 y S18

/// Presenta S11 y, al terminar, S18 con la sesión local — sin pasar por el servidor, que puede
/// tardar o no estar. El resumen se actualiza solo cuando llega `trainingLogSynced`.
private struct SessionLogCoordinatorView: View {

    let dayId: Int?
    let onClose: () -> Void
    let onOpenHistory: (String, String) -> Void

    @EnvironmentObject var trainingService: TrainingService
    @EnvironmentObject var themeManager: ThemeManager

    @State private var viewModel: SessionLogViewModel?
    @State private var finished: WorkoutSession?

    var body: some View {
        Group {
            if let finished {
                SessionSummaryView(source: .finished(finished), onClose: onClose)
            } else if let viewModel {
                SessionLogView(
                    viewModel: viewModel,
                    coachNote: trainingService.day?.coachNote?.text,
                    onFinish: { session in
                        self.finished = session
                    },
                    onClose: onClose,
                    onOpenHistory: onOpenHistory
                )
            } else {
                ZStack {
                    Color.dynamicBackground(theme: themeManager.currentTheme).ignoresSafeArea()
                    ProgressView()
                        .tint(Color.dynamicText(theme: themeManager.currentTheme))
                }
                .accessibilityLabel("Preparing your session")
            }
        }
        .task { await prepare() }
    }

    private func prepare() async {
        guard viewModel == nil else { return }
        guard let dayId else {
            viewModel = .freeWorkout()
            return
        }
        await trainingService.fetchDay(dayId)
        if let day = trainingService.day, day.id == dayId, !day.isRest {
            viewModel = .forDay(
                day,
                programId: trainingService.myProgram?.program?.id,
                scheduledDate: trainingService.myProgram?.today?.date
            )
        } else {
            viewModel = .freeWorkout()
        }
    }
}

// MARK: - Identificadores para `sheet(item:)`

/// `Int` no es `Identifiable`, y `sheet(item:)` lo exige.
struct IdentifiableInt: Identifiable, Hashable {
    let value: Int
    var id: Int { value }
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
