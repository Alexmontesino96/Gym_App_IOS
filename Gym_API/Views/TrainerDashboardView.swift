//
//  TrainerDashboardView.swift
//  Gym_API
//
//  El panel del ENTRENADOR. Principio de esta pantalla: caras, no cifras.
//
//  El negocio de un entrenador son sus clientes. Abrir la app tiene que sentirse como entrar
//  en el estudio y ver quién viene hoy; los números son contexto, no el protagonista. Antes
//  esto era un panel de administración: un icono genérico donde iba la foto, tres tarjetas de
//  cifras con colores del sistema, dos acciones rápidas que duplicaban la barra de pestañas,
//  un «Today's Schedule» que ESCONDÍA las sesiones de hoy tras un aviso, y un «Recent Activity»
//  que era un TODO.
//
//  Todo lo que se pinta existe: sesiones de `ClassService`, inscritos de
//  `/schedule/participation/participants/{id}`, y check-ins de `/health/clients/{id}/check-ins`,
//  las rutas de la fase 2 que iOS nunca había consumido.
//

import SwiftUI
import TrainingCore

struct TrainerDashboardView: View {
    @EnvironmentObject var workspaceContext: WorkspaceContextService
    @EnvironmentObject var authService: AuthServiceDirect
    @EnvironmentObject var themeManager: ThemeManager
    @EnvironmentObject var classService: ClassService
    @EnvironmentObject var coachingService: CoachingService
    @EnvironmentObject var trainingService: TrainingService
    @EnvironmentObject var healthService: HealthService
    @StateObject private var profileService = UserProfileService.shared

    /// Navegación de pestañas, que la posee TrainerMainTabView.
    var onGoToClients: () -> Void = {}
    var onGoToMessages: () -> Void = {}

    @State private var now = Date()
    @State private var path = NavigationPath()
    /// El check-in que se está respondiendo (plan §8.5), aparte de cualquier otra hoja del panel.
    @State private var replyTarget: ClientCheckIn?
    private let clock = Timer.publish(every: 60, on: .main, in: .common).autoconnect()

    private var theme: ThemeManager.AppTheme { themeManager.currentTheme }
    private var accent: Color { Color.dynamicAccent(theme: theme) }
    private var ink: Color { ThemeManager.accentInkForCurrentAccent(theme: theme) }

    // MARK: - Datos derivados

    private var firstName: String {
        if let name = profileService.userProfile?.firstName, !name.isEmpty { return name }
        if let full = authService.user?.name, !full.isEmpty, !full.contains("@") {
            return full.components(separatedBy: " ").first ?? full
        }
        return "Coach"
    }

    private var greeting: String {
        let hour = Calendar.current.component(.hour, from: now)
        if hour < 12 { return "Good morning," }
        if hour < 18 { return "Good afternoon," }
        return "Good evening,"
    }

    private var trainerMetrics: TrainerMetrics? {
        if let stats = workspaceContext.stats, case .trainer(let m) = stats.metrics { return m }
        return nil
    }

    /// La siguiente sesión del calendario, hoy o después, para el estado «sin sesiones hoy».
    private var nextUpcoming: SessionWithClass? {
        classService.sessions
            .filter { $0.session.startTime > now && $0.session.status != .cancelled }
            .sorted { $0.session.startTime < $1.session.startTime }
            .first
    }

    // MARK: - Body

    var body: some View {
        NavigationStack(path: $path) {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 26) {
                    header
                    todaySection
                    if isTrainingEnabled { needsAttentionSection }
                    if isTrainingEnabled { toReviewSection }
                    weekStrip
                    checkInsSection
                    Spacer(minLength: 16)
                }
                .padding(.horizontal, 20)
                .padding(.top, 12)
            }
            .background(Color.dynamicBackground(theme: theme).ignoresSafeArea())
            .navigationBarHidden(true)
            .navigationDestination(for: TrainerTrainingRoute.self) { route in
                TrainerTrainingDestination(route: route, path: $path, onMessage: onGoToMessages)
            }
            .task { await load() }
            .refreshable { await load(force: true) }
            .sheet(item: $replyTarget) { item in
                CheckInReplySheet(client: item.client, checkIn: item.checkIn) { updated in
                    coachingService.applyCheckInReply(updated, clientId: item.client.id)
                }
                .environmentObject(themeManager)
                .environmentObject(healthService)
            }
            .onReceive(clock) { now = $0 }
            .onReceive(NotificationCenter.default.publisher(for: .trainingOpenLog)) { notification in
                // Deep link `training/logs/{id}` del push «Dana finished Upper A» (plan §7.1).
                // Aquí el usuario es personal, así que el registro se abre en S22, no en S18.
                guard isTrainingEnabled, let id = notification.object as? Int else { return }
                Analytics.track(Analytics.Event.reminderOpened, [Analytics.Property.logId: id])
                path.append(TrainerTrainingRoute.logReview(logId: id, client: nil))
            }
        }
    }

    /// El módulo puede estar apagado en el espacio: sin él, la sección no existe y nada se rompe.
    /// Misma fuente que la home del cliente (`WorkspaceFeatures.training`, plan §8.2).
    private var isTrainingEnabled: Bool {
        workspaceContext.isFeatureEnabled(\.training)
    }

    // MARK: - Needs attention (visión §8.3, GET /clients/summary)

    /// Va encima de «To review» a propósito: el buzón enseña lo que tus clientes hicieron; esto,
    /// a quien no está haciendo nada, que es lo que hace perder clientes.
    private var needsAttentionSection: some View {
        NeedsAttentionSection(
            onSeeAll: onGoToClients,
            onOpenClient: { client in
                path.append(TrainerTrainingRoute.clientDetail(
                    TrainingClientRef(id: client.userId, name: client.fullName, pictureURL: client.pictureURL)
                ))
            }
        )
    }

    // MARK: - To review (plan §6.2, GET /inbox)

    /// La sección vive en `TrainerInboxSection` para que la galería de revisión la capture tal
    /// cual, sin una maqueta paralela que se quede vieja.
    private var toReviewSection: some View {
        TrainerInboxSection { log in
            path.append(TrainerTrainingRoute.logReview(logId: log.id, client: client(for: log)))
        }
    }

    /// Quién entrenó, con el nombre y la foto que ya trae el buzón.
    private func client(for log: TrainingWorkoutLogSummary) -> TrainingClientRef? {
        guard let id = log.userId else { return nil }
        return TrainingClientRef(
            id: id,
            name: log.userName ?? "Client",
            pictureURL: log.userPictureURL
        )
    }

    // MARK: - Cabecera

    private var header: some View {
        HStack(alignment: .center, spacing: 14) {
            VStack(alignment: .leading, spacing: 2) {
                Text(greeting)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(Color.dynamicTextSecondary(theme: theme))
                Text(firstName)
                    .font(.system(size: 30, weight: .bold))
                    .tracking(-1.0)
                    .foregroundColor(Color.dynamicText(theme: theme))
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }

            Spacer(minLength: 0)

            avatar(url: profileService.userProfile?.picture, initials: String(firstName.prefix(1)), size: 48)
        }
        .padding(.top, 4)
    }

    // MARK: - Hoy

    private var todaySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                eyebrow("TODAY")
                Spacer()
                Text(DateFormatter.localized(template: "EEEdMMM").string(from: now))
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(Color.dynamicTextTertiary(theme: theme))
            }

            switch coachingService.rosterState {
            case .loading, .idle where coachingService.todayRoster.isEmpty && classService.sessions.isEmpty:
                skeletonCard(height: 132)
            default:
                if coachingService.todayRoster.isEmpty {
                    noSessionsTodayCard
                } else {
                    ForEach(coachingService.todayRoster) { entry in
                        sessionCard(entry, isNext: entry.id == nextTodayId)
                    }
                }
            }
        }
    }

    /// La primera sesión de hoy que todavía no ha terminado. Es la que va en el acento.
    private var nextTodayId: Int? {
        coachingService.todayRoster.first { $0.session.endTime > now }?.id
    }

    private func sessionCard(_ entry: SessionRosterEntry, isNext: Bool) -> some View {
        let hora = DateFormatter.localized(template: "jmm")
        hora.timeZone = entry.gymTimeZone
        let rango = "\(hora.string(from: entry.session.startTime))–\(hora.string(from: entry.session.endTime))"
        let terminada = entry.session.endTime <= now
        let enCurso = entry.session.startTime <= now && !terminada
        let fg: Color = isNext ? ink : Color.dynamicText(theme: theme)
        let fg2: Color = isNext ? ink.opacity(0.72) : Color.dynamicTextSecondary(theme: theme)

        return HStack(spacing: 14) {
            avatar(url: entry.client?.pictureURL,
                   initials: entry.client?.initials ?? "?",
                   size: isNext ? 60 : 48,
                   ring: isNext ? ink.opacity(0.35) : nil)

            VStack(alignment: .leading, spacing: 4) {
                Text(entry.client?.displayName ?? "Open slot")
                    .font(.system(size: isNext ? 20 : 16, weight: .bold))
                    .tracking(isNext ? -0.5 : -0.2)
                    .foregroundColor(fg)
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)

                HStack(spacing: 6) {
                    Text(rango)
                        .font(.system(size: 13, weight: .semibold, design: .monospaced))
                        .foregroundColor(fg2)
                    if let room = entry.session.room, !room.isEmpty {
                        Text("·").foregroundColor(fg2)
                        Text(room)
                            .font(.system(size: 13))
                            .foregroundColor(fg2)
                            .lineLimit(1)
                    }
                }

                if isNext, let notes = entry.session.notes, !notes.isEmpty {
                    Text(notes)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(fg2)
                        .lineLimit(2)
                        .padding(.top, 2)
                }
            }

            Spacer(minLength: 0)

            if terminada {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 18))
                    .foregroundColor(accent)
            } else if enCurso {
                statusPill("NOW", filled: isNext)
            } else {
                statusPill(countdown(to: entry.session.startTime), filled: isNext)
            }
        }
        .padding(isNext ? 18 : 14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            Group {
                if isNext {
                    LinearGradient(colors: [accent, accent.opacity(0.72)],
                                   startPoint: .topLeading, endPoint: .bottomTrailing)
                } else {
                    Color.dynamicSurface(theme: theme)
                }
            }
        )
        .clipShape(RoundedRectangle(cornerRadius: 24))
        .overlay(
            RoundedRectangle(cornerRadius: 24)
                .stroke(Color.dynamicBorder(theme: theme).opacity(isNext ? 0 : 0.15), lineWidth: 1)
        )
        .opacity(terminada ? 0.6 : 1)
    }

    private func statusPill(_ text: String, filled: Bool) -> some View {
        Text(text)
            .font(.system(size: 10, weight: .bold))
            .tracking(0.6)
            .foregroundColor(filled ? accent : Color.dynamicTextSecondary(theme: theme))
            .padding(.horizontal, 9)
            .padding(.vertical, 5)
            .background(Capsule().fill(filled ? Color.black.opacity(0.85) : Color.dynamicSurface2(theme: theme)))
    }

    /// «IN 2H 10M», «IN 45M», «IN 3 DAYS». Lo que un entrenador mira de reojo entre sesiones.
    private func countdown(to date: Date) -> String {
        let secs = Int(date.timeIntervalSince(now))
        guard secs > 0 else { return "NOW" }
        let m = secs / 60
        if m < 60 { return "IN \(max(m, 1))M" }
        let h = m / 60
        if h < 24 { return m % 60 >= 5 ? "IN \(h)H \(m % 60)M" : "IN \(h)H" }
        let d = h / 24
        return "IN \(d) DAY\(d == 1 ? "" : "S")"
    }

    private var noSessionsTodayCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                Image(systemName: "sun.max")
                    .font(.system(size: 18, weight: .medium))
                    .foregroundColor(accent)
                Text("No sessions today")
                    .font(.system(size: 17, weight: .bold))
                    .tracking(-0.3)
                    .foregroundColor(Color.dynamicText(theme: theme))
            }

            if let next = nextUpcoming {
                Text("Next up: \(nextLabel(next))")
                    .font(.system(size: 14))
                    .foregroundColor(Color.dynamicTextSecondary(theme: theme))
            } else {
                Text("Nothing on the calendar this week. Sessions you schedule for your clients show up here.")
                    .font(.system(size: 14))
                    .foregroundColor(Color.dynamicTextSecondary(theme: theme))
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.dynamicSurface(theme: theme))
        .clipShape(RoundedRectangle(cornerRadius: 24))
        .overlay(
            RoundedRectangle(cornerRadius: 24)
                .stroke(Color.dynamicBorder(theme: theme).opacity(0.15), lineWidth: 1)
        )
    }

    private func nextLabel(_ item: SessionWithClass) -> String {
        let f = DateFormatter.localized(template: "EEEdMMM jmm")
        f.timeZone = TimeZone(identifier: item.session.timeInfo.gymTimezone) ?? .current
        return f.string(from: item.session.startTime)
    }

    // MARK: - La semana, en una tira

    private var weekStrip: some View {
        HStack(spacing: 0) {
            metric(value: trainerMetrics.map { "\($0.activeClients)" }, label: "CLIENTS")
            divider
            metric(value: trainerMetrics.map { "\($0.sessionsThisWeek)" }, label: "SESSIONS THIS WEEK")
            if let m = trainerMetrics, m.maxClients != nil {
                divider
                metric(value: "\(Int(m.capacityPercentage.rounded()))%", label: "CAPACITY")
            }
        }
        .padding(.vertical, 16)
        .padding(.horizontal, 18)
        .frame(maxWidth: .infinity)
        .background(Color.dynamicSurface(theme: theme))
        .clipShape(RoundedRectangle(cornerRadius: 22))
        .overlay(
            RoundedRectangle(cornerRadius: 22)
                .stroke(Color.dynamicBorder(theme: theme).opacity(0.15), lineWidth: 1)
        )
        .contentShape(Rectangle())
        .onTapGesture { onGoToClients() }
    }

    private var divider: some View {
        Rectangle()
            .fill(Color.dynamicBorder(theme: theme).opacity(0.2))
            .frame(width: 1, height: 34)
            .padding(.horizontal, 14)
    }

    private func metric(value: String?, label: String) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            // «—» cuando no se ha podido cargar: un cero afirmaría que no tienes clientes.
            Text(value ?? NumberFormat.placeholder)
                .font(.system(size: 24, weight: .bold, design: .monospaced))
                .tracking(-1.0)
                .foregroundColor(value == nil ? Color.dynamicTextTertiary(theme: theme) : accent)
            Text(label)
                .font(.system(size: 9, weight: .bold))
                .tracking(0.8)
                .foregroundColor(Color.dynamicTextTertiary(theme: theme))
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Lo que tus clientes te contaron

    private var checkInsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                eyebrow("THIS WEEK'S CHECK-INS")
                Spacer()
                if !coachingService.recentCheckIns.isEmpty {
                    Text("\(coachingService.recentCheckIns.count)")
                        .font(.system(size: 12, weight: .bold, design: .monospaced))
                        .foregroundColor(Color.dynamicTextTertiary(theme: theme))
                }
            }

            switch coachingService.checkInsState {
            case .loading, .idle where coachingService.recentCheckIns.isEmpty:
                skeletonCard(height: 96)
                skeletonCard(height: 96)
            case .failed where coachingService.recentCheckIns.isEmpty:
                infoCard(icon: "exclamationmark.triangle",
                         text: "Couldn't load your clients' check-ins. Pull to try again.")
            default:
                if coachingService.recentCheckIns.isEmpty {
                    infoCard(icon: "bubble.left",
                             text: "No check-ins yet this week. Your clients log them from the app, and they land here.")
                } else {
                    ForEach(coachingService.recentCheckIns) { item in
                        checkInCard(item)
                    }
                }
            }
        }
    }

    private func checkInCard(_ item: ClientCheckIn) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                avatar(url: item.client.pictureURL, initials: item.client.initials, size: 36)
                VStack(alignment: .leading, spacing: 1) {
                    Text(item.client.displayName)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(Color.dynamicText(theme: theme))
                        .lineLimit(1)
                    Text("Week of \(DateFormatter.localized(template: "dMMM").string(from: item.checkIn.weekStart))")
                        .font(.system(size: 11))
                        .foregroundColor(Color.dynamicTextTertiary(theme: theme))
                }
                Spacer(minLength: 0)
                if let kg = item.checkIn.weight {
                    let unit = WeightUnit.preferred
                    Text("\(NumberFormat.decimal(unit.fromKilograms(kg), digits: 1)) \(unit.symbol)")
                        .font(.system(size: 13, weight: .semibold, design: .monospaced))
                        .foregroundColor(Color.dynamicTextSecondary(theme: theme))
                }
            }

            if let nota = item.checkIn.notes?.trimmingCharacters(in: .whitespacesAndNewlines), !nota.isEmpty {
                Text("“\(nota)”")
                    .font(.system(size: 14))
                    .foregroundColor(Color.dynamicText(theme: theme))
                    .lineLimit(3)
                    .fixedSize(horizontal: false, vertical: true)
            }

            HStack(spacing: 6) {
                scalePill("Energy", item.checkIn.energy, lowIsBad: true)
                scalePill("Sleep", item.checkIn.sleep, lowIsBad: true)
                scalePill("Soreness", item.checkIn.soreness, lowIsBad: false)
            }

            if let reply = item.checkIn.coachReply?.trimmingCharacters(in: .whitespacesAndNewlines), !reply.isEmpty {
                Divider().background(Color.dynamicBorder(theme: theme).opacity(0.15))
                Text("Your reply")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundColor(Color.dynamicTextTertiary(theme: theme))
                Text(reply)
                    .font(.system(size: 14))
                    .foregroundColor(Color.dynamicText(theme: theme))
                    .lineLimit(3)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Button {
                HapticManager.shared.play(.selection)
                replyTarget = item
            } label: {
                Text(item.checkIn.coachReply == nil ? "Reply" : "Edit reply")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(Color.dynamicText(theme: theme))
                    .padding(.horizontal, 12)
                    .frame(minHeight: 44)
                    .overlay(Capsule().stroke(Color.dynamicBorder(theme: theme).opacity(0.4), lineWidth: 1))
            }
            .buttonStyle(.plain)
            .accessibilityHint("Opens a text field to reply to \(item.client.displayName)'s check-in.")
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

    /// Escala de 1 a 5 como píldora. Lo que merece un vistazo se tiñe: sueño bajo o agujetas
    /// altas es justo lo que el entrenador quiere saber antes de la sesión.
    @ViewBuilder
    private func scalePill(_ label: String, _ value: Int?, lowIsBad: Bool) -> some View {
        if let value {
            let alerta = lowIsBad ? value <= 2 : value >= 4
            HStack(spacing: 4) {
                Text(label)
                    .font(.system(size: 10, weight: .medium))
                Text("\(value)")
                    .font(.system(size: 11, weight: .bold, design: .monospaced))
            }
            .foregroundColor(alerta ? Color.warningYellow : Color.dynamicTextSecondary(theme: theme))
            .padding(.horizontal, 9)
            .padding(.vertical, 5)
            .background(Capsule().fill(alerta ? Color.warningYellow.opacity(0.14) : Color.dynamicSurface2(theme: theme)))
        }
    }

    // MARK: - Piezas comunes

    private func eyebrow(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 9, weight: .bold))
            .tracking(0.9)
            .foregroundColor(Color.dynamicTextTertiary(theme: theme))
            .padding(.leading, 2)
    }

    private func avatar(url: String?, initials: String, size: CGFloat, ring: Color? = nil) -> some View {
        Group {
            if let url, !url.isEmpty {
                OptimizedAsyncImage(
                    url: url,
                    displaySize: CGSize(width: size, height: size),
                    placeholder: { AnyView(initialsCircle(initials, size: size)) },
                    errorView: { AnyView(initialsCircle(initials, size: size)) }
                )
                .frame(width: size, height: size)
                .clipShape(Circle())
            } else {
                initialsCircle(initials, size: size)
            }
        }
        .overlay(
            Circle().stroke(ring ?? .clear, lineWidth: ring == nil ? 0 : 2)
        )
    }

    private func initialsCircle(_ initials: String, size: CGFloat) -> some View {
        ZStack {
            Circle().fill(Color.dynamicSurface2(theme: theme))
            Text(initials)
                .font(.system(size: size * 0.36, weight: .bold))
                .foregroundColor(Color.dynamicTextSecondary(theme: theme))
        }
        .frame(width: size, height: size)
    }

    private func infoCard(icon: String, text: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 15, weight: .medium))
                .foregroundColor(Color.dynamicTextTertiary(theme: theme))
                .padding(.top, 1)
            Text(text)
                .font(.system(size: 14))
                .foregroundColor(Color.dynamicTextSecondary(theme: theme))
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
        }
        .padding(14)
        .background(Color.dynamicSurface(theme: theme))
        .clipShape(RoundedRectangle(cornerRadius: 22))
        .overlay(
            RoundedRectangle(cornerRadius: 22)
                .stroke(Color.dynamicBorder(theme: theme).opacity(0.15),
                        style: StrokeStyle(lineWidth: 1, dash: [5, 4]))
        )
    }

    private func skeletonCard(height: CGFloat) -> some View {
        RoundedRectangle(cornerRadius: 22)
            .fill(Color.dynamicSurface(theme: theme))
            .frame(maxWidth: .infinity)
            .frame(height: height)
            .overlay(alignment: .topLeading) {
                HStack(spacing: 12) {
                    SkeletonView(width: 48, height: 48, cornerRadius: 24)
                    VStack(alignment: .leading, spacing: 8) {
                        SkeletonView(width: 140, height: 14, cornerRadius: 4)
                        SkeletonView(width: 90, height: 11, cornerRadius: 4)
                    }
                }
                .padding(14)
            }
    }

    // MARK: - Carga

    private func load(force: Bool = false) async {
        async let stats: Void = loadStats(force: force)
        async let sessions: Void = classService.loadSessionsForDateIfNeeded(date: Date())
        async let inbox: Void = loadInbox()
        async let attention: Void = loadClientsSummary()
        _ = await (stats, sessions, inbox, attention)

        // El roster necesita las sesiones ya cargadas; los check-ins, la lista de clientes.
        async let roster: Void = coachingService.loadTodayRoster(from: classService.sessions)
        async let checkIns: Void = coachingService.loadRecentCheckIns()
        _ = await (roster, checkIns)
        now = Date()
    }

    private func loadInbox() async {
        guard isTrainingEnabled else { return }
        await trainingService.fetchInbox()
    }

    /// Falla cerrado igual que el buzón: sin el módulo, la ruta responde 403 y la sección ni se
    /// pinta, así que tampoco se pide.
    private func loadClientsSummary() async {
        guard isTrainingEnabled else { return }
        await trainingService.fetchClientsSummary()
    }

    private func loadStats(force: Bool) async {
        if force || workspaceContext.stats == nil {
            await workspaceContext.fetchStats(forceRefresh: force)
        }
    }
}

#Preview {
    TrainerDashboardView()
        .environmentObject(WorkspaceContextService.shared)
        .environmentObject(AuthServiceDirect())
        .environmentObject(ThemeManager())
        .environmentObject(ServiceContainer.shared.classService)
        .environmentObject(ServiceContainer.shared.coachingService)
        .environmentObject(ServiceContainer.shared.trainingService)
}
