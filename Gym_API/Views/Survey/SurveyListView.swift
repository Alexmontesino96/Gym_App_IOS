import SwiftUI

struct SurveyListView: View {
    @EnvironmentObject var surveyService: SurveyService
    @EnvironmentObject var authService: AuthServiceDirect
    @EnvironmentObject var gymService: GymService
    @EnvironmentObject var themeManager: ThemeManager
    
    @State private var selectedSurvey: Survey?
    @State private var showingSurveyResponse = false
    @State private var showingMyResponses = false
    @State private var searchText = ""
    
    var filteredSurveys: [Survey] {
        if searchText.isEmpty {
            return surveyService.availableSurveys
        } else {
            return surveyService.availableSurveys.filter { survey in
                survey.title.localizedCaseInsensitiveContains(searchText) ||
                (survey.description?.localizedCaseInsensitiveContains(searchText) ?? false)
            }
        }
    }
    
    var body: some View {
        NavigationView {
            ZStack {
                Color.dynamicBackground(theme: themeManager.currentTheme)
                    .ignoresSafeArea()
                
                if surveyService.isLoading {
                    ProgressView("Loading surveys...")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if surveyService.availableSurveys.isEmpty {
                    EmptyStateView()
                } else {
                    ScrollView {
                        VStack(spacing: 16) {
                            // Search Bar
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
                            .padding()
                            .background(Color.dynamicSurface(theme: themeManager.currentTheme))
                            .cornerRadius(10)
                            .padding(.horizontal)
                            
                            // Survey Cards
                            ForEach(filteredSurveys) { survey in
                                SurveyCardView(survey: survey) {
                                    selectedSurvey = survey
                                    showingSurveyResponse = true
                                }
                                .padding(.horizontal)
                            }
                        }
                        .padding(.vertical)
                    }
                }
            }
            .navigationTitle("Surveys")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        showingMyResponses = true
                    }) {
                        Image(systemName: "clock.arrow.circlepath")
                            .foregroundColor(.accentColor)
                    }
                }
            }
            .sheet(isPresented: $showingSurveyResponse) {
                if let survey = selectedSurvey {
                    SurveyResponseView(survey: survey)
                        .environmentObject(surveyService)
                        .environmentObject(authService)
                        .environmentObject(gymService)
                        .environmentObject(themeManager)
                }
            }
            .sheet(isPresented: $showingMyResponses) {
                MyResponsesView()
                    .environmentObject(surveyService)
                    .environmentObject(authService)
                    .environmentObject(gymService)
                    .environmentObject(themeManager)
            }
        }
        .onAppear {
            surveyService.authService = authService
            surveyService.gymService = gymService
            Task {
                await surveyService.getAvailableSurveys()
            }
        }
        .refreshable {
            await surveyService.getAvailableSurveys()
        }
    }
}

// MARK: - Survey Card View
struct SurveyCardView: View {
    let survey: Survey
    let action: () -> Void
    @EnvironmentObject var themeManager: ThemeManager
    
    var statusColor: Color {
        switch survey.status {
        case .published:
            return .green
        case .closed:
            return .orange
        case .draft:
            return .gray
        case .archived:
            return .red
        }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(survey.title)
                        .font(.headline)
                        .foregroundColor(Color.dynamicText(theme: themeManager.currentTheme))
                        .lineLimit(2)
                    
                    if let description = survey.description {
                        Text(description)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .lineLimit(3)
                    }
                }
                
                Spacer()
                
                if survey.isAnonymous {
                    Image(systemName: "person.fill.questionmark")
                        .foregroundColor(.secondary)
                        .font(.title3)
                }
            }
            
            Divider()
            
            // Stats Row
            HStack(spacing: 20) {
                // Questions Count
                HStack(spacing: 4) {
                    Image(systemName: "questionmark.circle")
                        .foregroundColor(.secondary)
                        .font(.caption)
                    Text("\(survey.questionsCount ?? 0) questions")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                // Estimated Time
                HStack(spacing: 4) {
                    Image(systemName: "clock")
                        .foregroundColor(.secondary)
                        .font(.caption)
                    Text(survey.formattedEstimatedTime)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                // Response Rate
                if let responsesCount = survey.responsesCount {
                    HStack(spacing: 4) {
                        Image(systemName: "person.2")
                            .foregroundColor(.secondary)
                            .font(.caption)
                        Text("\(responsesCount) responses")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
            
            // Tags
            if let tags = survey.tags, !tags.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(tags, id: \.self) { tag in
                            Text(tag)
                                .font(.caption)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Color.accentColor.opacity(0.2))
                                .foregroundColor(.accentColor)
                                .cornerRadius(4)
                        }
                    }
                }
            }
            
            // Footer
            HStack {
                // Days Remaining
                if let daysRemaining = survey.daysRemaining {
                    HStack(spacing: 4) {
                        Image(systemName: "calendar.badge.exclamationmark")
                            .foregroundColor(daysRemaining <= 3 ? .orange : .secondary)
                        Text(daysRemaining == 0 ? "Last day!" : "\(daysRemaining) days left")
                            .foregroundColor(daysRemaining <= 3 ? .orange : .secondary)
                    }
                    .font(.caption)
                }
                
                Spacer()
                
                // Action Button
                Button(action: action) {
                    HStack {
                        Text(survey.hasResponded == true ? "View Response" : "Start Survey")
                            .font(.subheadline)
                            .fontWeight(.medium)
                        Image(systemName: "arrow.right")
                            .font(.caption)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(survey.hasResponded == true ? Color.gray : Color.accentColor)
                    .foregroundColor(.white)
                    .cornerRadius(20)
                }
                .disabled(!survey.isAvailable && !(survey.hasResponded ?? false))
            }
        }
        .padding()
        .background(Color.dynamicSurface(theme: themeManager.currentTheme))
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.05), radius: 5, x: 0, y: 2)
    }
}

// MARK: - Empty State View
struct EmptyStateView: View {
    @EnvironmentObject var themeManager: ThemeManager
    
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "doc.text.magnifyingglass")
                .font(.system(size: 60))
                .foregroundColor(.secondary)
            
            Text("No Surveys Available")
                .font(.title2)
                .fontWeight(.semibold)
                .foregroundColor(Color.dynamicText(theme: themeManager.currentTheme))
            
            Text("Check back later for new surveys or pull to refresh")
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - My Responses View
struct MyResponsesView: View {
    @EnvironmentObject var surveyService: SurveyService
    @EnvironmentObject var themeManager: ThemeManager
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        NavigationView {
            ZStack {
                Color.dynamicBackground(theme: themeManager.currentTheme)
                    .ignoresSafeArea()
                
                if surveyService.isLoading {
                    ProgressView("Loading responses...")
                } else if surveyService.myResponses.isEmpty {
                    VStack(spacing: 20) {
                        Image(systemName: "tray")
                            .font(.system(size: 60))
                            .foregroundColor(.secondary)
                        
                        Text("No Responses Yet")
                            .font(.title2)
                            .fontWeight(.semibold)
                        
                        Text("Your survey responses will appear here")
                            .font(.body)
                            .foregroundColor(.secondary)
                    }
                } else {
                    List(surveyService.myResponses) { response in
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text("Survey #\(response.surveyId)")
                                    .font(.headline)
                                
                                Spacer()
                                
                                if response.isComplete {
                                    Label("Complete", systemImage: "checkmark.circle.fill")
                                        .font(.caption)
                                        .foregroundColor(.green)
                                } else {
                                    Label("In Progress", systemImage: "circle.dotted")
                                        .font(.caption)
                                        .foregroundColor(.orange)
                                }
                            }
                            
                            HStack {
                                Text("Started: \(response.startedAt, style: .date)")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                
                                if let completedAt = response.completedAt {
                                    Text("• Completed: \(completedAt, style: .date)")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            }
                            
                            if let completionTime = response.completionTime {
                                Text("Time taken: \(Int(completionTime / 60)) minutes")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                    .listStyle(InsetGroupedListStyle())
                }
            }
            .navigationTitle("My Responses")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
        .onAppear {
            Task {
                await surveyService.getMyResponses()
            }
        }
    }
}