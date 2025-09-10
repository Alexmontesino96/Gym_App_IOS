import SwiftUI

struct SurveyManagementView: View {
    @EnvironmentObject var surveyService: SurveyService
    @EnvironmentObject var authService: AuthServiceDirect
    @EnvironmentObject var gymService: GymService
    @EnvironmentObject var themeManager: ThemeManager
    
    @State private var selectedTab: SurveyTab = .active
    @State private var searchText = ""
    @State private var showingCreator = false
    @State private var selectedSurvey: Survey?
    @State private var showingStatistics = false
    @State private var showingResponses = false
    @State private var showingTemplates = false
    @State private var showingExportOptions = false
    @State private var showingDeleteAlert = false
    @State private var surveyToDelete: Survey?
    @State private var viewMode: ViewMode = .grid
    @State private var showingFilters = false
    
    enum ViewMode: String, CaseIterable {
        case list = "List"
        case grid = "Grid"
        
        var icon: String {
            switch self {
            case .list: return "list.bullet"
            case .grid: return "square.grid.2x2"
            }
        }
    }
    
    enum SurveyTab: String, CaseIterable {
        case active = "Active"
        case draft = "Drafts"
        case closed = "Closed"
        case analytics = "Analytics"
        
        var icon: String {
            switch self {
            case .active: return "checkmark.circle"
            case .draft: return "pencil.circle"
            case .closed: return "xmark.circle"
            case .analytics: return "chart.bar"
            }
        }
    }
    
    var filteredSurveys: [Survey] {
        let surveysForTab: [Survey]
        
        switch selectedTab {
        case .active:
            surveysForTab = surveyService.availableSurveys.filter { $0.status == .published }
        case .draft:
            surveysForTab = surveyService.availableSurveys.filter { $0.status == .draft }
        case .closed:
            surveysForTab = surveyService.availableSurveys.filter { 
                $0.status == .closed || $0.status == .archived 
            }
        case .analytics:
            return [] // Analytics tab doesn't show survey list
        }
        
        if searchText.isEmpty {
            return surveysForTab
        } else {
            return surveysForTab.filter { survey in
                survey.title.localizedCaseInsensitiveContains(searchText) ||
                (survey.description?.localizedCaseInsensitiveContains(searchText) ?? false)
            }
        }
    }
    
    // Calculate stats
    var totalSurveys: Int {
        surveyService.availableSurveys.count
    }
    
    var activeSurveys: Int {
        surveyService.availableSurveys.filter { $0.status == .published }.count
    }
    
    var totalResponses: Int {
        surveyService.availableSurveys.reduce(0) { $0 + ($1.responsesCount ?? 0) }
    }
    
    var averageCompletionRate: Double {
        let surveysWithRate = surveyService.availableSurveys.compactMap { $0.completionRate }
        guard !surveysWithRate.isEmpty else { return 0 }
        return surveysWithRate.reduce(0, +) / Double(surveysWithRate.count)
    }
    
    var body: some View {
        NavigationView {
            ZStack {
                Color.dynamicBackground(theme: themeManager.currentTheme)
                    .ignoresSafeArea()
                
                VStack(spacing: 0) {
                    // Dashboard Header with Metrics
                    dashboardHeader
                        .padding(.horizontal)
                        .padding(.top)
                    
                    // Search and View Controls
                    HStack(spacing: 12) {
                        searchBar
                        
                        // View Mode Selector
                        Menu {
                            ForEach(ViewMode.allCases, id: \.self) { mode in
                                Button(action: {
                                    withAnimation(.easeInOut(duration: 0.2)) {
                                        viewMode = mode
                                    }
                                }) {
                                    Label(mode.rawValue, systemImage: mode.icon)
                                }
                            }
                        } label: {
                            Image(systemName: viewMode.icon)
                                .foregroundColor(.accentColor)
                                .frame(width: 44, height: 44)
                                .background(Color.dynamicSurface(theme: themeManager.currentTheme))
                                .cornerRadius(10)
                        }
                        
                        // Filter Button
                        Button(action: { showingFilters.toggle() }) {
                            Image(systemName: "line.3.horizontal.decrease.circle")
                                .foregroundColor(.accentColor)
                                .frame(width: 44, height: 44)
                                .background(Color.dynamicSurface(theme: themeManager.currentTheme))
                                .cornerRadius(10)
                        }
                    }
                    .padding(.horizontal)
                    .padding(.vertical, 8)
                    
                    // Tab Selector
                    tabSelector
                    
                    // Content Area
                    if selectedTab == .analytics {
                        analyticsView
                    } else {
                        if filteredSurveys.isEmpty {
                            emptyStateView
                        } else {
                            if viewMode == .grid {
                                surveyGridView
                            } else {
                                surveyList
                            }
                        }
                    }
                }
                
                // Floating Action Button
                VStack {
                    Spacer()
                    HStack {
                        Spacer()
                        Button(action: { showingCreator = true }) {
                            Image(systemName: "plus")
                                .font(.title2)
                                .fontWeight(.semibold)
                                .foregroundColor(.white)
                                .frame(width: 56, height: 56)
                                .background(
                                    LinearGradient(
                                        gradient: Gradient(colors: [Color.accentColor, Color.accentColor.opacity(0.8)]),
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                                .cornerRadius(28)
                                .shadow(color: Color.accentColor.opacity(0.3), radius: 8, x: 0, y: 4)
                        }
                    }
                    .padding(.trailing, 20)
                    .padding(.bottom, 20)
                }
            }
            .navigationTitle("Survey Management")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Menu {
                        Button(action: { showingCreator = true }) {
                            Label("New Survey", systemImage: "plus.circle")
                        }
                        
                        Button(action: { showingTemplates = true }) {
                            Label("Templates", systemImage: "doc.on.doc")
                        }
                        
                        Button(action: { Task { await refreshData() } }) {
                            Label("Refresh", systemImage: "arrow.clockwise")
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                            .foregroundColor(.accentColor)
                    }
                }
            }
        }
        .sheet(isPresented: $showingCreator) {
            SurveyCreatorView(survey: selectedSurvey)
                .environmentObject(surveyService)
                .environmentObject(themeManager)
                .environmentObject(gymService)
        }
        .sheet(isPresented: $showingStatistics) {
            if let survey = selectedSurvey {
                SurveyStatisticsView(survey: survey)
                    .environmentObject(surveyService)
                    .environmentObject(themeManager)
            }
        }
        .sheet(isPresented: $showingResponses) {
            if let survey = selectedSurvey {
                SurveyResponsesListView(survey: survey)
                    .environmentObject(surveyService)
                    .environmentObject(themeManager)
            }
        }
        .sheet(isPresented: $showingExportOptions) {
            if let survey = selectedSurvey {
                ExportOptionsView(survey: survey)
                    .environmentObject(surveyService)
                    .environmentObject(themeManager)
            }
        }
        .sheet(isPresented: $showingTemplates) {
            SurveyTemplatesView()
                .environmentObject(surveyService)
                .environmentObject(themeManager)
        }
        .alert("Delete Survey", isPresented: $showingDeleteAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Delete", role: .destructive) {
                if let survey = surveyToDelete {
                    Task {
                        // TODO: Implement delete in service
                        await refreshData()
                    }
                }
            }
        } message: {
            Text("Are you sure you want to delete '\(surveyToDelete?.title ?? "")'? This action cannot be undone.")
        }
        .onAppear {
            setupServices()
            Task {
                await loadData()
            }
        }
    }
    
    // MARK: - Components
    
    private var dashboardHeader: some View {
        VStack(spacing: 12) {
            HStack {
                Text("Survey Dashboard")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(Color.dynamicText(theme: themeManager.currentTheme))
                
                Spacer()
                
                // Quick Stats Badge
                HStack(spacing: 4) {
                    Circle()
                        .fill(Color.green)
                        .frame(width: 8, height: 8)
                    Text("\(activeSurveys) Active")
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(.secondary)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(Color.green.opacity(0.1))
                .cornerRadius(12)
            }
            
            // Metrics Cards
            HStack(spacing: 12) {
                // Total Responses Card
                MetricCard(
                    title: "Responses",
                    value: "\(totalResponses)",
                    icon: "person.2.fill",
                    trend: "+12%",
                    trendUp: true,
                    color: .blue
                )
                
                // Completion Rate Card
                MetricCard(
                    title: "Completion",
                    value: "\(Int(averageCompletionRate))%",
                    icon: "chart.pie.fill",
                    trend: "+5%",
                    trendUp: true,
                    color: .green
                )
                
                // Active Surveys Card
                MetricCard(
                    title: "Active",
                    value: "\(activeSurveys)",
                    icon: "checkmark.circle.fill",
                    trend: "\(totalSurveys) total",
                    trendUp: nil,
                    color: .orange
                )
            }
        }
    }
    
    private var searchBar: some View {
        HStack {
            Image(systemName: "magnifyingglass")
                .foregroundColor(.secondary)
            
            TextField("Search surveys", text: $searchText)
                .textFieldStyle(PlainTextFieldStyle())
            
            if !searchText.isEmpty {
                Button(action: { searchText = "" }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 12)
        .background(Color.dynamicSurface(theme: themeManager.currentTheme))
        .cornerRadius(10)
        .frame(maxWidth: .infinity)
    }
    
    private var tabSelector: some View {
        HStack(spacing: 0) {
            ForEach(SurveyTab.allCases, id: \.self) { tab in
                Button(action: {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        selectedTab = tab
                    }
                }) {
                    VStack(spacing: 4) {
                        Image(systemName: tab.icon)
                            .font(.system(size: 20))
                        
                        Text(tab.rawValue)
                            .font(.caption)
                            .fontWeight(selectedTab == tab ? .semibold : .regular)
                    }
                    .foregroundColor(selectedTab == tab ? .accentColor : .secondary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                    .background(
                        VStack {
                            Spacer()
                            if selectedTab == tab {
                                Rectangle()
                                    .fill(Color.accentColor)
                                    .frame(height: 2)
                            }
                        }
                    )
                }
                .buttonStyle(PlainButtonStyle())
            }
        }
        .background(Color.dynamicSurface(theme: themeManager.currentTheme))
        .padding(.top, 8)
    }
    
    private var surveyGridView: some View {
        ScrollView {
            LazyVGrid(columns: [
                GridItem(.flexible(), spacing: 12),
                GridItem(.flexible(), spacing: 12)
            ], spacing: 12) {
                ForEach(filteredSurveys) { survey in
                    SurveyGridCard(survey: survey)
                        .environmentObject(themeManager)
                        .environmentObject(surveyService)
                        .onTapGesture {
                            selectedSurvey = survey
                            showingStatistics = true
                        }
                        .contextMenu {
                            Button(action: {
                                selectedSurvey = survey
                                showingStatistics = true
                            }) {
                                Label("View Statistics", systemImage: "chart.bar")
                            }
                            
                            Button(action: {
                                selectedSurvey = survey
                                showingResponses = true
                            }) {
                                Label("View Responses", systemImage: "person.2")
                            }
                            
                            if survey.status == .draft {
                                Button(action: {
                                    Task {
                                        await surveyService.publishSurvey(surveyId: survey.id)
                                    }
                                }) {
                                    Label("Publish", systemImage: "paperplane")
                                }
                            }
                            
                            Divider()
                            
                            Button(action: {
                                selectedSurvey = survey
                                showingCreator = true
                            }) {
                                Label("Edit", systemImage: "pencil")
                            }
                            
                            if (survey.responsesCount ?? 0) == 0 {
                                Button(role: .destructive, action: {
                                    surveyToDelete = survey
                                    showingDeleteAlert = true
                                }) {
                                    Label("Delete", systemImage: "trash")
                                }
                            }
                        }
                }
            }
            .padding(.horizontal)
            .padding(.vertical)
        }
        .refreshable {
            await refreshData()
        }
    }
    
    private var surveyList: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                ForEach(filteredSurveys) { survey in
                    SurveyAdminCard(
                        survey: survey,
                        onEdit: {
                            selectedSurvey = survey
                            showingCreator = true
                        },
                        onStatistics: {
                            selectedSurvey = survey
                            showingStatistics = true
                        },
                        onResponses: {
                            selectedSurvey = survey
                            showingResponses = true
                        },
                        onExport: {
                            selectedSurvey = survey
                            showingExportOptions = true
                        },
                        onDelete: {
                            surveyToDelete = survey
                            showingDeleteAlert = true
                        }
                    )
                    .environmentObject(themeManager)
                    .environmentObject(surveyService)
                    .padding(.horizontal)
                    .contextMenu {
                        // Quick actions in context menu
                        Button(action: {
                            selectedSurvey = survey
                            showingStatistics = true
                        }) {
                            Label("View Statistics", systemImage: "chart.bar")
                        }
                        
                        if RolePermissions.canExportSurveyData(gymService.currentGym?.userRoleInGym) {
                            Button(action: {
                                Task { await exportSurvey(survey) }
                            }) {
                                Label("Export", systemImage: "arrow.down.doc")
                            }
                        }
                        
                        Divider()
                        
                        if survey.status != .archived {
                            Button(action: {
                                selectedSurvey = survey
                                showingCreator = true
                            }) {
                                Label("Edit", systemImage: "pencil")
                            }
                        }
                        
                        if survey.status == .draft {
                            Button(action: {
                                Task {
                                    await surveyService.publishSurvey(surveyId: survey.id)
                                }
                            }) {
                                if surveyService.isPublishingSurvey(survey.id) {
                                    Label("Publishing...", systemImage: "arrow.triangle.2.circlepath")
                                } else {
                                    Label("Publish", systemImage: "paperplane")
                                }
                            }
                            .disabled(surveyService.isPublishingSurvey(survey.id))
                        }
                        
                        if RolePermissions.canDeleteSurveys(gymService.currentGym?.userRoleInGym) &&
                           (survey.responsesCount ?? 0) == 0 {
                            Divider()
                            
                            Button(role: .destructive, action: {
                                surveyToDelete = survey
                                showingDeleteAlert = true
                            }) {
                                Label("Delete", systemImage: "trash")
                            }
                        }
                    }
                }
            }
            .padding(.vertical)
        }
        .refreshable {
            await refreshData()
        }
    }
    
    private var analyticsView: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Overall Stats
                SurveyQuickStats(
                    totalSurveys: totalSurveys,
                    activeSurveys: activeSurveys,
                    totalResponses: totalResponses,
                    averageCompletionRate: averageCompletionRate
                )
                .environmentObject(themeManager)
                .padding(.horizontal)
                
                // Recent Activity
                VStack(alignment: .leading, spacing: 12) {
                    Text("Recent Activity")
                        .font(.headline)
                        .foregroundColor(Color.dynamicText(theme: themeManager.currentTheme))
                        .padding(.horizontal)
                    
                    // Activity cards would go here
                    Text("Activity timeline coming soon...")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(Color.dynamicSurface(theme: themeManager.currentTheme))
                        .cornerRadius(12)
                        .padding(.horizontal)
                }
                
                // Top Performing Surveys
                VStack(alignment: .leading, spacing: 12) {
                    Text("Top Performing Surveys")
                        .font(.headline)
                        .foregroundColor(Color.dynamicText(theme: themeManager.currentTheme))
                        .padding(.horizontal)
                    
                    ForEach(surveyService.availableSurveys.sorted {
                        ($0.responsesCount ?? 0) > ($1.responsesCount ?? 0)
                    }.prefix(3)) { survey in
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(survey.title)
                                    .font(.subheadline)
                                    .foregroundColor(Color.dynamicText(theme: themeManager.currentTheme))
                                
                                Text("\(survey.responsesCount ?? 0) responses")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            
                            Spacer()
                            
                            if let rate = survey.completionRate {
                                Text("\(Int(rate))%")
                                    .font(.headline)
                                    .foregroundColor(.accentColor)
                            }
                        }
                        .padding()
                        .background(Color.dynamicSurface(theme: themeManager.currentTheme))
                        .cornerRadius(8)
                        .padding(.horizontal)
                    }
                }
                
                Spacer(minLength: 100)
            }
            .padding(.vertical)
        }
    }
    
    private var emptyStateView: some View {
        VStack(spacing: 20) {
            Image(systemName: selectedTab == .draft ? "pencil.slash" : 
                             selectedTab == .closed ? "archivebox" : "doc.text.magnifyingglass")
                .font(.system(size: 60))
                .foregroundColor(.secondary)
            
            Text(emptyStateTitle)
                .font(.title2)
                .fontWeight(.semibold)
                .foregroundColor(Color.dynamicText(theme: themeManager.currentTheme))
            
            Text(emptyStateMessage)
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
            
            if selectedTab == .active || selectedTab == .draft {
                Button(action: { showingCreator = true }) {
                    HStack {
                        Image(systemName: "plus.circle")
                        Text("Create Survey")
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 12)
                    .background(Color.accentColor)
                    .foregroundColor(.white)
                    .cornerRadius(10)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    private var emptyStateTitle: String {
        switch selectedTab {
        case .active: return "No Active Surveys"
        case .draft: return "No Drafts"
        case .closed: return "No Closed Surveys"
        case .analytics: return "No Data Yet"
        }
    }
    
    private var emptyStateMessage: String {
        switch selectedTab {
        case .active: return "Create a survey to start collecting feedback"
        case .draft: return "Your draft surveys will appear here"
        case .closed: return "Closed and archived surveys will appear here"
        case .analytics: return "Analytics will be available once you have survey responses"
        }
    }
    
    // MARK: - Methods
    
    private func setupServices() {
        surveyService.authService = authService
        surveyService.gymService = gymService
    }
    
    private func loadData() async {
        // Para admin, obtener las encuestas creadas por él
        await surveyService.getMySurveys()
        if surveyService.surveyTemplates.isEmpty {
            await surveyService.getTemplates()
        }
    }
    
    private func refreshData() async {
        // Refrescar con las encuestas creadas por el usuario actual
        await surveyService.getMySurveys()
    }
    
    private func exportSurvey(_ survey: Survey) async {
        if let exportURL = await surveyService.exportSurveyData(surveyId: survey.id, format: "csv") {
            // Share the exported file
            let activityVC = UIActivityViewController(
                activityItems: [exportURL],
                applicationActivities: nil
            )
            
            if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
               let window = windowScene.windows.first {
                window.rootViewController?.present(activityVC, animated: true)
            }
        }
    }
}

// MARK: - Supporting Views

struct MetricCard: View {
    let title: String
    let value: String
    let icon: String
    let trend: String
    let trendUp: Bool?
    let color: Color
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: icon)
                    .font(.system(size: 16))
                    .foregroundColor(color)
                
                Spacer()
                
                if let trendUp = trendUp {
                    HStack(spacing: 2) {
                        Image(systemName: trendUp ? "arrow.up.right" : "arrow.down.right")
                            .font(.system(size: 10))
                        Text(trend)
                            .font(.caption2)
                    }
                    .foregroundColor(trendUp ? .green : .red)
                } else {
                    Text(trend)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
            
            Text(value)
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(.primary)
            
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            LinearGradient(
                gradient: Gradient(colors: [
                    color.opacity(0.1),
                    color.opacity(0.05)
                ]),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .cornerRadius(12)
    }
}

struct SurveyGridCard: View {
    let survey: Survey
    @EnvironmentObject var themeManager: ThemeManager
    @EnvironmentObject var surveyService: SurveyService
    
    var statusColor: Color {
        switch survey.status {
        case .draft: return .gray
        case .published: return .green
        case .closed: return .orange
        case .archived: return .red
        }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(survey.title)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(Color.dynamicText(theme: themeManager.currentTheme))
                        .lineLimit(2)
                    
                    // Status Badge
                    HStack(spacing: 4) {
                        Circle()
                            .fill(statusColor)
                            .frame(width: 6, height: 6)
                        Text(survey.status.displayName)
                            .font(.caption2)
                            .foregroundColor(statusColor)
                    }
                }
                
                Spacer()
                
                // Options Menu
                Menu {
                    Button(action: {}) {
                        Label("View", systemImage: "eye")
                    }
                    Button(action: {}) {
                        Label("Edit", systemImage: "pencil")
                    }
                } label: {
                    Image(systemName: "ellipsis")
                        .foregroundColor(.secondary)
                        .frame(width: 24, height: 24)
                }
            }
            
            // Stats
            VStack(spacing: 8) {
                // Response Progress
                HStack {
                    Text("\(survey.responsesCount ?? 0) responses")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Spacer()
                    
                    if let rate = survey.completionRate {
                        Text("\(Int(rate))%")
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundColor(.accentColor)
                    }
                }
                
                // Progress Bar
                GeometryReader { geometry in
                    ZStack(alignment: .leading) {
                        Rectangle()
                            .fill(Color.gray.opacity(0.2))
                            .frame(height: 4)
                        
                        Rectangle()
                            .fill(statusColor)
                            .frame(width: geometry.size.width * CGFloat(survey.completionRate ?? 0) / 100, height: 4)
                    }
                    .cornerRadius(2)
                }
                .frame(height: 4)
                
                // Bottom Info
                HStack {
                    HStack(spacing: 4) {
                        Image(systemName: "questionmark.circle")
                            .font(.caption2)
                        Text("\(survey.questionsCount ?? 0)")
                            .font(.caption2)
                    }
                    .foregroundColor(.secondary)
                    
                    Spacer()
                    
                    if survey.status == .published, let daysRemaining = survey.daysRemaining {
                        HStack(spacing: 4) {
                            Image(systemName: "clock")
                                .font(.caption2)
                            Text("\(daysRemaining)d")
                                .font(.caption2)
                        }
                        .foregroundColor(daysRemaining <= 3 ? .orange : .secondary)
                    }
                }
            }
        }
        .padding()
        .background(Color.dynamicSurface(theme: themeManager.currentTheme))
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.05), radius: 5, x: 0, y: 2)
    }
}