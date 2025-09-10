import SwiftUI

struct SurveyResponsesListView: View {
    @EnvironmentObject var themeManager: ThemeManager
    @EnvironmentObject var surveyService: SurveyService
    @Environment(\.dismiss) var dismiss
    
    let survey: Survey
    @State private var responses: [ResponseWithAnswers] = []
    @State private var isLoading = true
    @State private var errorMessage: String?
    @State private var selectedResponse: ResponseWithAnswers?
    @State private var showOnlyComplete = true
    @State private var searchText = ""
    
    var filteredResponses: [ResponseWithAnswers] {
        if searchText.isEmpty {
            return responses
        }
        
        return responses.filter { response in
            // Search by user name or email
            if let user = response.user {
                let nameMatch = user.name?.localizedCaseInsensitiveContains(searchText) ?? false
                let emailMatch = user.email?.localizedCaseInsensitiveContains(searchText) ?? false
                
                if nameMatch || emailMatch {
                    return true
                }
            }
            
            // Search in answers
            return response.answers.contains { answer in
                answer.textAnswer?.localizedCaseInsensitiveContains(searchText) ?? false
            }
        }
    }
    
    var body: some View {
        NavigationView {
            ZStack {
                Color.dynamicBackground(theme: themeManager.currentTheme)
                    .ignoresSafeArea()
                
                if isLoading {
                    ProgressView("Loading responses...")
                        .progressViewStyle(CircularProgressViewStyle(tint: .accentColor))
                        .scaleEffect(1.2)
                } else if let error = errorMessage {
                    VStack(spacing: 20) {
                        Image(systemName: "exclamationmark.triangle")
                            .font(.system(size: 50))
                            .foregroundColor(.red)
                        
                        Text("Error loading responses")
                            .font(.title2)
                            .fontWeight(.semibold)
                        
                        Text(error)
                            .font(.body)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                        
                        Button(action: loadResponses) {
                            Label("Retry", systemImage: "arrow.clockwise")
                                .padding(.horizontal, 20)
                                .padding(.vertical, 10)
                                .background(Color.accentColor)
                                .foregroundColor(.white)
                                .cornerRadius(10)
                        }
                    }
                } else if responses.isEmpty {
                    VStack(spacing: 20) {
                        Image(systemName: "tray")
                            .font(.system(size: 50))
                            .foregroundColor(.secondary)
                        
                        Text("No Responses Yet")
                            .font(.title2)
                            .fontWeight(.semibold)
                        
                        Text("Responses will appear here once members complete the survey")
                            .font(.body)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                    }
                } else {
                    VStack(spacing: 0) {
                        // Search Bar
                        searchBar
                        
                        // Filter Toggle
                        filterToggle
                        
                        // Responses List
                        ScrollView {
                            LazyVStack(spacing: 12) {
                                ForEach(filteredResponses) { response in
                                    responseCard(response)
                                        .onTapGesture {
                                            selectedResponse = response
                                        }
                                }
                            }
                            .padding()
                        }
                    }
                }
            }
            .navigationTitle("\(survey.title) Responses")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Close") { dismiss() }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: loadResponses) {
                        Image(systemName: "arrow.clockwise")
                    }
                }
            }
        }
        .onAppear {
            loadResponses()
        }
        .sheet(item: $selectedResponse) { response in
            ResponseDetailView(response: response, survey: survey)
                .environmentObject(themeManager)
                .environmentObject(surveyService)
        }
    }
    
    // MARK: - Search Bar
    private var searchBar: some View {
        HStack {
            Image(systemName: "magnifyingglass")
                .foregroundColor(.secondary)
            
            TextField("Search responses...", text: $searchText)
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
        .padding()
    }
    
    // MARK: - Filter Toggle
    private var filterToggle: some View {
        HStack {
            Text("Showing:")
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            Picker("Filter", selection: $showOnlyComplete) {
                Text("Complete").tag(true)
                Text("All").tag(false)
            }
            .pickerStyle(SegmentedPickerStyle())
            .onChange(of: showOnlyComplete) {
                loadResponses()
            }
        }
        .padding(.horizontal)
        .padding(.bottom, 8)
    }
    
    // MARK: - Response Card
    private func responseCard(_ response: ResponseWithAnswers) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            HStack {
                // User Info
                VStack(alignment: .leading, spacing: 4) {
                    if let user = response.user {
                        Text(user.name ?? "Unknown User")
                            .font(.headline)
                            .foregroundColor(Color.dynamicText(theme: themeManager.currentTheme))
                        
                        Text(user.email ?? "Anonymous")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    } else {
                        Text("Anonymous Response")
                            .font(.headline)
                            .foregroundColor(Color.dynamicText(theme: themeManager.currentTheme))
                    }
                }
                
                Spacer()
                
                // Completion Status
                VStack(alignment: .trailing, spacing: 4) {
                    HStack(spacing: 4) {
                        Image(systemName: response.isComplete ? "checkmark.circle.fill" : "circle.dotted")
                            .foregroundColor(response.isComplete ? .green : .orange)
                        
                        Text(response.isComplete ? "Complete" : "Incomplete")
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundColor(response.isComplete ? .green : .orange)
                    }
                    
                    if response.completedAt != nil {
                        Text("Completed")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
            }
            
            Divider()
            
            // Response Summary
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Label("\(response.answers.count) answers", systemImage: "text.bubble")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Spacer()
                    
                    Text(formatDate(response.startedAt))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                // Preview of first few answers
                if !response.answers.isEmpty {
                    VStack(alignment: .leading, spacing: 4) {
                        ForEach(response.answers.prefix(2)) { answer in
                            if let text = answer.textAnswer, !text.isEmpty {
                                HStack {
                                    Circle()
                                        .fill(Color.accentColor)
                                        .frame(width: 4, height: 4)
                                    
                                    Text(text)
                                        .font(.caption)
                                        .lineLimit(1)
                                        .foregroundColor(.secondary)
                                }
                            }
                        }
                        
                        if response.answers.count > 2 {
                            Text("+ \(response.answers.count - 2) more answers")
                                .font(.caption2)
                                .foregroundColor(Color.accentColor)
                        }
                    }
                }
            }
            
            // View Details Button
            HStack {
                Spacer()
                
                Label("View Details", systemImage: "arrow.right.circle")
                    .font(.caption)
                    .foregroundColor(Color.accentColor)
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.dynamicSurface(theme: themeManager.currentTheme))
                .shadow(color: .black.opacity(0.1), radius: 5, x: 0, y: 2)
        )
    }
    
    // MARK: - Helper Methods
    
    private func loadResponses() {
        Task {
            isLoading = true
            errorMessage = nil
            
            let loadedResponses = await surveyService.getSurveyResponses(
                surveyId: survey.id,
                onlyComplete: showOnlyComplete
            )
            
            if loadedResponses.isEmpty && showOnlyComplete {
                // Try loading all responses if no complete ones
                responses = await surveyService.getSurveyResponses(
                    surveyId: survey.id,
                    onlyComplete: false
                )
            } else {
                responses = loadedResponses
            }
            
            if responses.isEmpty {
                errorMessage = nil // Show empty state instead
            }
            
            isLoading = false
        }
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

// MARK: - Response Detail View
struct ResponseDetailView: View {
    @EnvironmentObject var themeManager: ThemeManager
    @Environment(\.dismiss) var dismiss
    
    let response: ResponseWithAnswers
    let survey: Survey
    @State private var questions: [SurveyQuestion] = []
    @State private var isLoading = true
    
    var body: some View {
        NavigationView {
            ZStack {
                Color.dynamicBackground(theme: themeManager.currentTheme)
                    .ignoresSafeArea()
                
                if isLoading {
                    ProgressView("Loading details...")
                } else {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 20) {
                            // Response Header
                            responseHeader
                            
                            // Answers Section
                            answersSection
                        }
                        .padding()
                    }
                }
            }
            .navigationTitle("Response Details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .onAppear {
            loadQuestions()
        }
    }
    
    private var responseHeader: some View {
        VStack(alignment: .leading, spacing: 12) {
            // User Info
            if let user = response.user {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(user.name ?? "Unknown User")
                            .font(.title2)
                            .fontWeight(.semibold)
                            .foregroundColor(Color.dynamicText(theme: themeManager.currentTheme))
                        
                        Text(user.email ?? "")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    // Avatar placeholder
                    Circle()
                        .fill(Color.accentColor.opacity(0.2))
                        .frame(width: 60, height: 60)
                        .overlay(
                            Text(user.name?.prefix(1).uppercased() ?? "U")
                                .font(.title)
                                .foregroundColor(Color.accentColor)
                        )
                }
            } else {
                Text("Anonymous Response")
                    .font(.title2)
                    .fontWeight(.semibold)
                    .foregroundColor(Color.dynamicText(theme: themeManager.currentTheme))
            }
            
            Divider()
            
            // Metadata
            HStack(spacing: 20) {
                Label(response.isComplete ? "Complete" : "Incomplete", 
                      systemImage: response.isComplete ? "checkmark.circle.fill" : "circle.dotted")
                    .foregroundColor(response.isComplete ? .green : .orange)
                    .font(.caption)
                
                Label(formatDate(response.startedAt), systemImage: "calendar")
                    .foregroundColor(.secondary)
                    .font(.caption)
                
                if response.completedAt != nil {
                    Label("Completed", systemImage: "clock")
                        .foregroundColor(.secondary)
                        .font(.caption)
                }
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.dynamicSurface(theme: themeManager.currentTheme))
        )
    }
    
    private var answersSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Responses")
                .font(.headline)
                .foregroundColor(Color.dynamicText(theme: themeManager.currentTheme))
            
            ForEach(response.answers) { answer in
                if let question = questions.first(where: { $0.id == answer.questionId }) {
                    answerCard(answer: answer, question: question)
                }
            }
        }
    }
    
    private func answerCard(answer: SurveyAnswer, question: SurveyQuestion) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            // Question
            Text(question.questionText)
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundColor(Color.dynamicText(theme: themeManager.currentTheme))
            
            // Answer
            Group {
                if let text = answer.textAnswer, !text.isEmpty {
                    Text(text)
                        .font(.body)
                        .foregroundColor(.secondary)
                        .padding(8)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(Color.gray.opacity(0.1))
                        )
                } else if let number = answer.numberAnswer {
                    HStack {
                        Text(String(format: "%.0f", number))
                            .font(.title3)
                            .fontWeight(.bold)
                            .foregroundColor(Color.accentColor)
                        
                        if question.questionType == .scale || question.questionType == .nps {
                            Text("/ 10")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                } else if let date = answer.dateAnswer {
                    Text(formatDate(date))
                        .font(.body)
                        .foregroundColor(.secondary)
                } else if let bool = answer.booleanAnswer {
                    HStack {
                        Image(systemName: bool ? "checkmark.circle.fill" : "xmark.circle.fill")
                            .foregroundColor(bool ? .green : .red)
                        Text(bool ? "Yes" : "No")
                            .font(.body)
                            .foregroundColor(.secondary)
                    }
                } else {
                    Text("No answer provided")
                        .font(.body)
                        .italic()
                        .foregroundColor(.secondary.opacity(0.5))
                }
            }
            
            // Question type badge
            HStack {
                Spacer()
                Text(question.questionType.displayName)
                    .font(.caption2)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 2)
                    .background(
                        Capsule()
                            .fill(Color.accentColor.opacity(0.2))
                    )
                    .foregroundColor(Color.accentColor)
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.dynamicSurface(theme: themeManager.currentTheme))
        )
    }
    
    private func loadQuestions() {
        Task {
            isLoading = true
            
            // Load survey questions
            // Load survey questions from service if available
            // For now, use empty array to avoid errors
            questions = []
            
            isLoading = false
        }
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

// Preview
struct SurveyResponsesListView_Previews: PreviewProvider {
    static var previews: some View {
        SurveyResponsesListView(survey: Survey.sampleSurvey)
        .environmentObject(ThemeManager())
        .environmentObject(SurveyService())
    }
}