//
//  TrainingGalleryView.swift
//  Gym_API
//
//  Galería de revisión visual del módulo (plan §12.3). **Solo DEBUG.**
//
//  Arranca la app directamente en una pantalla del módulo, con los fixtures del contrato y sin
//  login, para que `PLAN_MODULO_ENTRENAMIENTO_REPORTES/tools/screenshots.sh` pueda sacar la
//  matriz de capturas: claro × oscuro × Dynamic Type × Reduce Motion, más los cuatro estados.
//
//      xcrun simctl launch booted com.alexmontesino.gymapi -training-gallery s11
//      xcrun simctl launch booted com.alexmontesino.gymapi -training-gallery s11 -reduce-motion 1
//
//  Lo que se pinta son las vistas de producción con datos de fixture. No hay una sola maqueta:
//  si la captura enseña algo roto, está roto de verdad.
//

#if DEBUG

import SwiftUI
import TrainingCore

// MARK: - Escenarios

enum TrainingGalleryScenario: String, CaseIterable {
    case w4
    case w4Error = "w4-error"
    case w6
    case w8
    case coachAck = "coachack"
    case group
    case s11
    case s11Empty = "s11-empty"
    case s11Offline = "s11-offline"
    case s12
    case s12Empty = "s12-empty"
    case s15
    case s15Empty = "s15-empty"
    case s16
    case s16Empty = "s16-empty"
    case s17
    case s18
    case s18PersonalRecord = "s18-pr"
    /// El tercer estado del chip de sincronización: el servidor apartó una sesión y hay que
    /// ofrecer «Retry» (revisión 2 de WP3).
    case s16Failed = "s16-failed"

    // Pantallas del entrenador (WP5).
    case s20
    case s20Empty = "s20-empty"
    case s21
    /// El banner «Couldn't save. Your changes are still here.», que sin servidor no se provoca.
    case s21Error = "s21-error"
    case s22
    case s22PersonalRecord = "s22-pr"
    case s23
    case clientDetail = "clientdetail"
    case inbox

    /// Argumento de lanzamiento: `-training-gallery <valor>`.
    static func fromLaunchArguments(_ arguments: [String] = CommandLine.arguments) -> TrainingGalleryScenario? {
        guard let index = arguments.firstIndex(of: "-training-gallery"),
              arguments.indices.contains(index + 1) else { return nil }
        return TrainingGalleryScenario(rawValue: arguments[index + 1])
    }

    /// `-reduce-motion 1` fuerza la rama de Reduce Motion sin tocar los ajustes del simulador.
    static func forcesReduceMotion(_ arguments: [String] = CommandLine.arguments) -> Bool {
        guard let index = arguments.firstIndex(of: "-reduce-motion"),
              arguments.indices.contains(index + 1) else { return false }
        return arguments[index + 1] == "1" || arguments[index + 1].lowercased() == "true"
    }

    var isEmpty: Bool {
        switch self {
        case .s11Empty, .s12Empty, .s15Empty, .s16Empty, .s20Empty: return true
        default: return false
        }
    }

    /// Las pantallas del entrenador cargan sus propios fixtures y ninguno de los del cliente.
    var isStaff: Bool {
        switch self {
        case .s20, .s20Empty, .s21, .s21Error, .s22, .s22PersonalRecord, .s23, .clientDetail, .inbox:
            return true
        default:
            return false
        }
    }

    var isError: Bool { self == .w4Error }

    var isOffline: Bool { self == .s11Offline }

    var usesProgram: Bool {
        if isStaff { return false }
        switch self {
        case .s12Empty, .s15Empty, .s16Empty, .s11Empty: return false
        default: return true
        }
    }

    var usesGroupProgram: Bool { self == .group }
    var usesDay: Bool { !isEmpty && !isStaff }
    var usesLogs: Bool { !isEmpty && !isStaff }
    var usesRecords: Bool { !isEmpty && !isStaff }
    var usesHistory: Bool { !isEmpty && !isStaff }
    var usesGroup: Bool { self == .group }
    var usesExercises: Bool { true }
}

// MARK: - Vista

struct TrainingGalleryView: View {

    let scenario: TrainingGalleryScenario

    @EnvironmentObject var themeManager: ThemeManager
    @EnvironmentObject var trainingService: TrainingService
    @EnvironmentObject var syncCoordinator: TrainingSyncCoordinator
    @EnvironmentObject var gymService: GymService
    @EnvironmentObject var coachingService: CoachingService

    @State private var isReady = false
    /// La apariencia la decide el simulador (`xcrun simctl ui … appearance`), no el tema
    /// guardado: es lo que permite capturar la misma pantalla en claro y en oscuro.
    @Environment(\.colorScheme) private var colorScheme

    private var theme: ThemeManager.AppTheme { themeManager.currentTheme }

    var body: some View {
        Group {
            if isReady {
                content
            } else {
                Color.dynamicBackground(theme: theme).ignoresSafeArea()
            }
        }
        .onAppear {
            themeManager.currentTheme = colorScheme == .dark ? .dark : .light
            gymService.setModulesForGallery(["stories": true, "posts": true, "training": true])
            trainingService.loadFixtures(for: scenario)
            if scenario == .clientDetail {
                coachingService.setCheckInsForGallery([Self.galleryCheckIn])
            }
            // Los dos estados de la cola que no se pueden provocar sin red ni servidor.
            switch scenario {
            case .s11Offline:
                syncCoordinator.simulateGalleryState(pending: 1, failed: 0)
            case .s16Failed:
                syncCoordinator.simulateGalleryState(pending: 0, failed: 1)
            default:
                syncCoordinator.simulateGalleryState(pending: 0, failed: 0)
            }
            isReady = true
        }
        .onChange(of: colorScheme) { _, newValue in
            themeManager.currentTheme = newValue == .dark ? .dark : .light
        }
    }

    @ViewBuilder
    private var content: some View {
        switch scenario {
        case .w4, .w4Error, .w6, .w8, .coachAck, .group:
            widgetGallery
        case .s11, .s11Empty, .s11Offline:
            sessionLog
        case .s12, .s12Empty:
            NavigationStack {
                WeeklyProgramView(
                    initialWeek: nil,
                    onOpenDay: { _ in },
                    onStartSession: { _ in },
                    onMessageCoach: {},
                    onChangeUnits: {}
                )
            }
        case .s15, .s15Empty:
            NavigationStack {
                ExerciseHistoryView(
                    exerciseKey: "barbell_bench_press",
                    exerciseName: "Bench press"
                )
            }
        case .s16, .s16Empty, .s16Failed:
            NavigationStack {
                RecordsView()
            }
        case .s17:
            NavigationStack {
                TrainingDayDetailView(
                    dayId: 88,
                    onStartSession: { _ in },
                    onStartFreeWorkout: {},
                    onViewLog: { _ in }
                )
            }
        case .s18:
            SessionSummaryView(source: .finished(fixtureSession()), onClose: {})
        case .s18PersonalRecord:
            SessionSummaryView(source: .log(id: 301), onClose: {})

        // MARK: Entrenador (WP5)

        case .clientDetail:
            NavigationStack {
                ClientDetailView(client: Self.galleryClient)
            }
        case .s20, .s20Empty:
            NavigationStack {
                ClientProgramsView(client: Self.galleryClient)
            }
        case .s21, .s21Error:
            DayEditorView(
                day: trainingService.programDays.first { $0.dayNumber == 18 },
                programId: 7,
                dayNumber: 18,
                client: Self.galleryClient,
                simulatedError: scenario == .s21Error
                    ? "Couldn't save. Your changes are still here."
                    : nil
            )
        case .s22:
            NavigationStack {
                LogReviewView(logId: 301, client: Self.galleryClient)
            }
        case .s22PersonalRecord:
            NavigationStack {
                LogReviewView(logId: 302, client: Self.galleryClient)
            }
        case .s23:
            DayNoteSheet(client: Self.galleryClient, date: Self.galleryNoteDate)
        case .inbox:
            ScrollView {
                TrainerInboxSection { _ in }
                    .padding(.horizontal, 20)
                    .padding(.top, 16)
            }
            .background(Color.dynamicBackground(theme: theme).ignoresSafeArea())
        }
    }

    /// La persona de todas las capturas del entrenador. El nombre importa: media docena de
    /// textos lo llevan dentro («Note for Dana», «Recently used with Dana», «Sent to Dana»).
    static let galleryClient = TrainingClientRef(id: 2, name: "Dana Reyes")

    /// El jueves del wireframe de S23.
    static let galleryNoteDate = CalendarDate(year: 2026, month: 9, day: 24)

    /// El check-in que la ficha del cliente reutiliza del panel del entrenador.
    static let galleryCheckIn = ClientCheckIn(
        client: ClientSummary(
            id: 2,
            fullName: "Dana Reyes",
            email: "dana@example.com",
            pictureURL: nil,
            joinedAt: nil
        ),
        checkIn: WeeklyCheckIn(
            id: 77,
            weekStart: CalendarDate(year: 2026, month: 9, day: 21).startOfDay(in: .current),
            energy: 4,
            sleep: 2,
            soreness: 3,
            notes: "Slept badly on Tuesday, otherwise good week.",
            weight: 63.5,
            measurementId: nil,
            createdAt: CalendarDate(year: 2026, month: 9, day: 22).startOfDay(in: .current)
        )
    )

    // MARK: - Widgets

    private var widgetGallery: some View {
        ScrollView {
            VStack(spacing: 20) {
                switch scenario {
                case .w4, .w4Error:
                    ProgramWeekCardView(
                        program: trainingService.myProgram,
                        state: scenario.isError ? .failed : .loaded,
                        onOpenWeek: {},
                        onOpenDay: { _ in },
                        onBrowseSessions: {}
                    )
                case .w6:
                    if let item = trainingService.strengthSummary.first {
                        StrengthProgressCardView(item: item, onOpenHistory: {}, onOpenRecords: {})
                    }
                case .w8:
                    LastLogCardView(
                        log: trainingService.myProgram?.lastLog ?? trainingService.logs.first,
                        state: .loaded,
                        contextNote: trainingService.myProgram?.contextNote,
                        onOpen: {},
                        onStartWorkout: {},
                        onShareToStory: {},
                        onShareToFeed: {},
                        onViewProgramDay: {}
                    )
                case .coachAck:
                    if let activity = trainingService.myProgram?.coachActivity {
                        CoachAckCardView(activity: activity, onReply: {}, onThank: { true })
                    }
                case .group:
                    if let group = trainingService.groupToday {
                        GroupTodayCardView(
                            group: group,
                            state: .loaded,
                            programName: trainingService.myProgram?.program?.name ?? "Spring Bootcamp",
                            onSelectMember: { _ in }
                        )
                    }
                default:
                    EmptyView()
                }
            }
            .padding(16)
        }
        .background(Color.dynamicBackground(theme: theme).ignoresSafeArea())
    }

    // MARK: - S11

    @ViewBuilder
    private var sessionLog: some View {
        let session: WorkoutSession = {
            if scenario == .s11Empty { return .freeWorkout(startedAt: Date().addingTimeInterval(-240)) }
            guard let day = trainingService.fixtureDay() else {
                return .freeWorkout(startedAt: Date())
            }
            var session = WorkoutSession(
                day: day,
                programId: 7,
                scheduledDate: day.coachNote?.date,
                startedAt: Date().addingTimeInterval(-1934)
            )
            // Seis series marcadas, como el wireframe («32:14 · 6 of 18 sets»).
            var marked = 0
            for exercise in session.exercises {
                for set in exercise.sets where marked < 6 {
                    session.markSet(exerciseId: exercise.id, setId: set.id, at: Date().addingTimeInterval(-60))
                    marked += 1
                }
                if marked >= 6 { break }
            }
            return session
        }()

        SessionLogView(
            viewModel: GalleryViewModelFactory.make(session: session),
            coachNote: trainingService.fixtureDay()?.coachNote?.text,
            onFinish: { _ in },
            onClose: {},
            onOpenHistory: { _, _ in }
        )
    }

    private func fixtureSession() -> WorkoutSession {
        guard let day = trainingService.fixtureDay() else {
            return .freeWorkout(startedAt: Date().addingTimeInterval(-3130))
        }
        var session = WorkoutSession(
            day: day,
            programId: 7,
            scheduledDate: day.coachNote?.date,
            startedAt: Date().addingTimeInterval(-3130)
        )
        for exercise in session.exercises {
            for set in exercise.sets {
                session.markSet(exerciseId: exercise.id, setId: set.id, at: Date().addingTimeInterval(-120))
            }
        }
        session.feeling = 4
        session.finish(at: Date())
        return session
    }
}

// MARK: - Fábrica del modelo de S11

/// El modelo de S11 se construye fuera de la vista para que la galería no lo recree en cada
/// redibujado, que reiniciaría el cronómetro en mitad de la captura.
private enum GalleryViewModelFactory {
    @MainActor private static var cached: SessionLogViewModel?

    @MainActor
    static func make(session: WorkoutSession) -> SessionLogViewModel {
        if let cached { return cached }
        let model = SessionLogViewModel(session: session)
        // En la galería los coach marks se ven solo en su propia captura, no encima de todas.
        model.showsCoachMarks = false
        cached = model
        return model
    }
}

#endif
