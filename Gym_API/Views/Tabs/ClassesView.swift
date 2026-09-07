import SwiftUI

struct ClassesView: View {
    @EnvironmentObject var authService: AuthServiceDirect
    @EnvironmentObject var classService: ClassService
    @EnvironmentObject var themeManager: ThemeManager
    @EnvironmentObject var attendanceService: AttendanceService
    @StateObject private var gymService = GymService.shared
    @StateObject private var profileService = UserProfileService.shared

    @State private var selectedDate = Date()
    @State private var isRefreshing = false
    @State private var showingCreateSession = false
    @State private var showingQRScanner = false
    @State private var showingClassSelection = false
    @State private var selectedSessionForScanner: SessionWithClass?
    @State private var selectedClass: GymClass?
    @State private var showError = false
    @State private var errorMessage = ""

    // MARK: - Computed Properties

    private var filteredClasses: [GymClass] {
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: selectedDate)
        let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay) ?? selectedDate

        return classService.classes
            .filter { $0.startTime >= startOfDay && $0.startTime < endOfDay }
            .sorted { $0.startTime < $1.startTime }
    }

    private var eyebrowDate: String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "es_ES")
        formatter.dateFormat = "EEE dd MMM"
        return "HOY · " + formatter.string(from: selectedDate).uppercased()
    }

    // MARK: - Body

    var body: some View {
        NavigationStack {
            ZStack {
                Color.dynamicBackground(theme: themeManager.currentTheme).ignoresSafeArea()

                VStack(spacing: 0) {
                    // Header
                    headerSection

                    // Day Pills
                    DayPillsSelector(selectedDate: $selectedDate)
                        .environmentObject(themeManager)
                        .padding(.bottom, 20)

                    // Content
                    if classService.isLoading && !isRefreshing {
                        Spacer()
                        ProgressView()
                            .scaleEffect(1.2)
                        Spacer()
                    } else if filteredClasses.isEmpty {
                        emptyState
                    } else {
                        timelineList
                    }
                }
            }
            .navigationTitle("")
            .navigationBarHidden(true)
            .navigationDestination(item: $selectedClass) { gymClass in
                ClassDetailView(gymClass: gymClass)
                    .environmentObject(themeManager)
                    .environmentObject(classService)
                    .environmentObject(gymService)
            }
        }
        .onAppear {
            Task {
                classService.authService = authService
                await classService.loadTrainers()
                await classService.loadSessionsForDateIfNeeded(date: selectedDate)
                await classService.fetchMyClasses()

                // Always stay on today — don't jump to another date
            }
        }
        .onChange(of: selectedDate) { _, newDate in
            Task { await classService.loadSessionsForDateIfNeeded(date: newDate) }
        }
        .sheet(isPresented: $showingCreateSession) {
            CreateSessionView()
                .environmentObject(themeManager)
                .environmentObject(authService)
                .environmentObject(classService)
        }
        .fullScreenCover(isPresented: $showingQRScanner) {
            QRScannerView(preSelectedSession: selectedSessionForScanner)
                .environmentObject(attendanceService)
                .environmentObject(classService)
                .environmentObject(themeManager)
                .environmentObject(authService)
                .onDisappear { selectedSessionForScanner = nil }
        }
        .sheet(isPresented: $showingClassSelection) {
            ClassSelectionSheet(
                sessions: attendanceService.availableSessions,
                onSessionSelected: { session in
                    selectedSessionForScanner = session
                    showingClassSelection = false
                    showingQRScanner = true
                },
                onCancel: { showingClassSelection = false }
            )
            .environmentObject(themeManager)
        }
        .alert("Error", isPresented: $showError) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(errorMessage)
        }
    }

    // MARK: - Header

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(eyebrowDate)
                        .font(.system(size: 9, weight: .bold))
                        .tracking(1.0)
                        .foregroundColor(Color.dynamicText(theme: themeManager.currentTheme).opacity(0.5))

                    Text("Clases")
                        .font(.system(size: 28, weight: .bold))
                        .tracking(-0.8)
                        .foregroundColor(Color.dynamicText(theme: themeManager.currentTheme))
                }

                Spacer()

                HStack(spacing: 8) {
                    // Filter button
                    Button(action: {}) {
                        Image(systemName: "line.3.horizontal.decrease")
                            .font(.system(size: 18))
                            .foregroundColor(Color.dynamicText(theme: themeManager.currentTheme))
                            .frame(width: 40, height: 40)
                            .background(Color.dynamicSurface(theme: themeManager.currentTheme))
                            .clipShape(Circle())
                            .overlay(
                                Circle().stroke(Color.white.opacity(0.08), lineWidth: 1)
                            )
                    }

                    // QR Scanner (admin/trainer only)
                    if RolePermissions.canScanQRCheckIn(gymService.currentGym?.userRoleInGym) {
                        Button(action: handleScannerButtonTap) {
                            Image(systemName: "qrcode.viewfinder")
                                .font(.system(size: 18))
                                .foregroundColor(Color.dynamicText(theme: themeManager.currentTheme))
                                .frame(width: 40, height: 40)
                                .background(Color.dynamicSurface(theme: themeManager.currentTheme))
                                .clipShape(Circle())
                                .overlay(
                                    Circle().stroke(Color.white.opacity(0.08), lineWidth: 1)
                                )
                        }
                    }
                }
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 16)
        .padding(.bottom, 12)
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 16) {
            Spacer()
            Image(systemName: "calendar.badge.exclamationmark")
                .font(.system(size: 48))
                .foregroundColor(Color.dynamicText(theme: themeManager.currentTheme).opacity(0.3))

            Text("No hay clases disponibles")
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(Color.dynamicText(theme: themeManager.currentTheme).opacity(0.5))

            Text("Prueba seleccionando otro día")
                .font(.system(size: 14))
                .foregroundColor(Color.dynamicText(theme: themeManager.currentTheme).opacity(0.35))
            Spacer()
        }
        .frame(maxWidth: .infinity)
        .refreshableCompat { await refreshClasses() }
    }

    // MARK: - Timeline List

    private var timelineList: some View {
        ScrollView(.vertical, showsIndicators: false) {
            ZStack(alignment: .leading) {
                // Timeline rail
                Rectangle()
                    .fill(Color.white.opacity(0.08))
                    .frame(width: 1)
                    .padding(.leading, 36)

                // Class cards
                LazyVStack(spacing: 12) {
                    ForEach(filteredClasses, id: \.id) { gymClass in
                        let isRegistered = classService.userRegistrationStatus[gymClass.id] ?? false

                        ZStack(alignment: .leading) {
                            // Timeline dot
                            timelineDot(isRegistered: isRegistered, gymClass: gymClass)
                                .offset(x: 31)

                            // Card
                            TimelineClassCard(
                                gymClass: gymClass,
                                isRegistered: isRegistered,
                                onTap: {
                                    HapticManager.shared.buttonTap()
                                    selectedClass = gymClass
                                },
                                onAction: {
                                    HapticManager.shared.buttonTap()
                                    Task { await classService.joinClass(sessionId: gymClass.id) }
                                }
                            )
                            .environmentObject(themeManager)
                            .padding(.leading, 56)
                        }
                    }
                }
                .padding(.vertical, 12)
            }
            .padding(.horizontal, 20)

            // FAB spacer
            if RolePermissions.canCreateSessions(gymService.currentGym?.userRoleInGym) {
                Spacer(minLength: 80)
            }
        }
        .refreshable { await refreshClasses() }
        .overlay(alignment: .bottomTrailing) {
            // FAB
            if RolePermissions.canCreateSessions(gymService.currentGym?.userRoleInGym) {
                Button(action: { showingCreateSession = true }) {
                    Image(systemName: "plus")
                        .font(.system(size: 22, weight: .semibold))
                        .foregroundColor(Color.accentInk)
                        .frame(width: 56, height: 56)
                        .background(Color(hex: "#D4FF3F")!)
                        .clipShape(Circle())
                        .shadow(color: Color(hex: "#D4FF3F")!.opacity(0.3), radius: 8, y: 4)
                }
                .padding(.trailing, 20)
                .padding(.bottom, 20)
            }
        }
    }

    // MARK: - Timeline Dot

    private func timelineDot(isRegistered: Bool, gymClass: GymClass) -> some View {
        let catColor = ClassCategoryHelper.color(for: gymClass)
        let accentColor = Color(hex: "#D4FF3F")!
        let state = SessionDisplayState.resolve(gymClass: gymClass, isRegistered: isRegistered)

        let dotColor: Color = {
            switch state {
            case .cancelled:
                return Color.dynamicText(theme: themeManager.currentTheme).opacity(0.25)
            case .completedAttended:
                return Color(hex: "#4ADE80")!
            case .completedNoShow:
                return Color.dynamicText(theme: themeManager.currentTheme).opacity(0.25)
            case .inProgress:
                return accentColor
            case .scheduled:
                return isRegistered ? accentColor : catColor
            }
        }()

        let hasGlow = state == .inProgress || (state == .scheduled && isRegistered)

        return ZStack {
            if hasGlow {
                Circle()
                    .fill(dotColor.opacity(0.2))
                    .frame(width: 18, height: 18)
            }

            Circle()
                .fill(Color.dynamicBackground(theme: themeManager.currentTheme))
                .frame(width: 10, height: 10)
                .overlay(
                    Circle()
                        .stroke(dotColor, lineWidth: 2)
                )
        }
    }

    // MARK: - Actions

    private func handleScannerButtonTap() {
        Task {
            await attendanceService.getAvailableSessionsForCheckIn()
            let count = attendanceService.availableSessions.count
            if count == 0 {
                errorMessage = "No hay clases disponibles para check-in en este momento"
                showError = true
            } else if count >= 3 {
                showingClassSelection = true
            } else {
                showingQRScanner = true
            }
        }
    }

    private func refreshClasses() async {
        await MainActor.run { isRefreshing = true }
        await classService.forceRefreshSessions(date: selectedDate)
        await classService.forceRefreshMyClasses()
        await classService.forceReloadTrainers()
        try? await Task.sleep(nanoseconds: 100_000_000)
        await MainActor.run { isRefreshing = false }
    }
}

// MARK: - Refreshable compat for non-ScrollView

private extension View {
    func refreshableCompat(action: @escaping () async -> Void) -> some View {
        ScrollView {
            self
        }
        .refreshable { await action() }
    }
}

// MARK: - GymClass Hashable conformance for navigationDestination

extension GymClass: @retroactive Hashable {
    public func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    public static func == (lhs: GymClass, rhs: GymClass) -> Bool {
        lhs.id == rhs.id
    }
}

#Preview {
    ClassesView()
        .environmentObject(AuthServiceDirect())
        .environmentObject(ClassService())
        .environmentObject(ServiceContainer.shared.attendanceService)
        .environmentObject(ThemeManager())
}
