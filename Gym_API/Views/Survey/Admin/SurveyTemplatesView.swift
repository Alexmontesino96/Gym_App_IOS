import SwiftUI

struct SurveyTemplatesView: View {
    @EnvironmentObject var surveyService: SurveyService
    @EnvironmentObject var themeManager: ThemeManager
    @Environment(\.dismiss) var dismiss
    
    @State private var selectedCategory: TemplateCategory = .all
    @State private var searchText = ""
    @State private var selectedTemplate: SurveyTemplate?
    @State private var showingPreview = false
    @State private var showingCreator = false
    
    enum TemplateCategory: String, CaseIterable {
        case all = "All"
        case fitness = "Fitness"
        case satisfaction = "Satisfaction"
        case feedback = "Feedback"
        case health = "Health"
        case custom = "Custom"
        
        var icon: String {
            switch self {
            case .all: return "square.grid.2x2"
            case .fitness: return "figure.walk"
            case .satisfaction: return "star.fill"
            case .feedback: return "bubble.left.and.bubble.right"
            case .health: return "heart.fill"
            case .custom: return "sparkles"
            }
        }
    }
    
    var filteredTemplates: [SurveyTemplate] {
        var templates = surveyService.surveyTemplates
        
        if selectedCategory != .all {
            templates = templates.filter { $0.category == selectedCategory.rawValue }
        }
        
        if !searchText.isEmpty {
            templates = templates.filter { template in
                template.title.localizedCaseInsensitiveContains(searchText) ||
                (template.description?.localizedCaseInsensitiveContains(searchText) ?? false)
            }
        }
        
        return templates
    }
    
    var body: some View {
        NavigationView {
            ZStack {
                Color.dynamicBackground(theme: themeManager.currentTheme)
                    .ignoresSafeArea()
                
                VStack(spacing: 0) {
                    // Search Bar
                    searchBar
                    
                    // Category Selector
                    categorySelector
                    
                    // Templates Grid
                    if filteredTemplates.isEmpty {
                        emptyStateView
                    } else {
                        templatesGrid
                    }
                }
            }
            .navigationTitle("Survey Templates")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Close") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: createCustomTemplate) {
                        Image(systemName: "plus.circle")
                    }
                }
            }
        }
        .sheet(item: $selectedTemplate) { template in
            if showingPreview {
                TemplatePreviewView(template: template) {
                    // Use template action
                    useTemplate(template)
                }
                .environmentObject(themeManager)
            }
        }
        .sheet(isPresented: $showingCreator) {
            SurveyCreatorView(survey: nil)
                .environmentObject(surveyService)
                .environmentObject(themeManager)
        }
        .onAppear {
            if surveyService.surveyTemplates.isEmpty {
                Task {
                    await surveyService.getTemplates()
                }
            }
        }
    }
    
    // MARK: - Components
    
    private var searchBar: some View {
        HStack {
            Image(systemName: "magnifyingglass")
                .foregroundColor(.secondary)
            
            TextField("Search templates", text: $searchText)
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
        .padding(.top)
    }
    
    private var categorySelector: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ForEach(TemplateCategory.allCases, id: \.self) { category in
                    CategoryChip(
                        category: category,
                        isSelected: selectedCategory == category,
                        theme: themeManager.currentTheme
                    ) {
                        withAnimation {
                            selectedCategory = category
                        }
                    }
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
        }
    }
    
    private var templatesGrid: some View {
        ScrollView {
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
                ForEach(filteredTemplates) { template in
                    TemplateCard(
                        template: template,
                        theme: themeManager.currentTheme
                    ) {
                        selectedTemplate = template
                        showingPreview = true
                    }
                }
                
                // Add custom template card
                if selectedCategory == .all || selectedCategory == .custom {
                    CreateTemplateCard(theme: themeManager.currentTheme) {
                        createCustomTemplate()
                    }
                }
            }
            .padding()
        }
    }
    
    private var emptyStateView: some View {
        VStack(spacing: 20) {
            Image(systemName: "doc.text.magnifyingglass")
                .font(.system(size: 60))
                .foregroundColor(.secondary)
            
            Text("No Templates Found")
                .font(.title2)
                .fontWeight(.semibold)
                .foregroundColor(Color.dynamicText(theme: themeManager.currentTheme))
            
            Text("Try adjusting your search or category filter")
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            
            Button(action: createCustomTemplate) {
                HStack {
                    Image(systemName: "plus.circle")
                    Text("Create Template")
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 12)
                .background(Color.accentColor)
                .foregroundColor(.white)
                .cornerRadius(10)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }
    
    // MARK: - Methods
    
    private func createCustomTemplate() {
        showingCreator = true
    }
    
    private func useTemplate(_ template: SurveyTemplate) {
        // Store template for use in creator
        // In a real app, we'd pass this to SurveyCreatorView
        selectedTemplate = nil
        showingPreview = false
        
        // Open creator with template
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            // The parent view would handle creating a survey from this template
            // For now, just dismiss the template selector
        }
    }
}

// MARK: - Supporting Views

struct CategoryChip: View {
    let category: SurveyTemplatesView.TemplateCategory
    let isSelected: Bool
    let theme: ThemeManager.AppTheme
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: category.icon)
                    .font(.system(size: 14))
                Text(category.rawValue)
                    .font(.subheadline)
                    .fontWeight(isSelected ? .medium : .regular)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(isSelected ? Color.accentColor : Color.dynamicSurface(theme: theme))
            .foregroundColor(isSelected ? .white : Color.dynamicText(theme: theme))
            .cornerRadius(20)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

struct TemplateCard: View {
    let template: SurveyTemplate
    let theme: ThemeManager.AppTheme
    let onTap: () -> Void
    
    var categoryColor: Color {
        switch template.category?.lowercased() ?? "" {
        case "fitness": return .blue
        case "satisfaction": return .green
        case "feedback": return .orange
        case "health": return .red
        case "custom": return .purple
        default: return .gray
        }
    }
    
    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 12) {
                // Header
                HStack {
                    Image(systemName: iconForCategory(template.category))
                        .font(.system(size: 24))
                        .foregroundColor(categoryColor)
                    
                    Spacer()
                    
                    if template.isPopular {
                        Label("Popular", systemImage: "star.fill")
                            .font(.caption)
                            .foregroundColor(.yellow)
                    }
                }
                
                // Title and Description
                VStack(alignment: .leading, spacing: 4) {
                    Text(template.title)
                        .font(.headline)
                        .foregroundColor(Color.dynamicText(theme: theme))
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                    
                    if let description = template.description {
                        Text(description)
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .lineLimit(3)
                            .multilineTextAlignment(.leading)
                    }
                }
                
                Spacer()
                
                // Stats
                HStack(spacing: 12) {
                    HStack(spacing: 4) {
                        Image(systemName: "questionmark.circle")
                            .font(.caption)
                        Text("\(template.questions.count)")
                            .font(.caption)
                            .fontWeight(.medium)
                    }
                    .foregroundColor(.secondary)
                    
                    if let estimatedTime = template.estimatedCompletionTime {
                        HStack(spacing: 4) {
                            Image(systemName: "clock")
                                .font(.caption)
                            Text("\(estimatedTime)m")
                                .font(.caption)
                                .fontWeight(.medium)
                        }
                        .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                }
                
                // Category Tag
                Text(template.category?.capitalized ?? "General")
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(.white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(categoryColor)
                    .cornerRadius(4)
            }
            .padding()
            .frame(height: 180)
            .background(Color.dynamicSurface(theme: theme))
            .cornerRadius(12)
            .shadow(color: Color.black.opacity(0.05), radius: 5, x: 0, y: 2)
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    private func iconForCategory(_ category: String?) -> String {
        switch category?.lowercased() ?? "" {
        case "fitness": return "figure.walk"
        case "satisfaction": return "star.fill"
        case "feedback": return "bubble.left.and.bubble.right"
        case "health": return "heart.fill"
        case "custom": return "sparkles"
        default: return "doc.text"
        }
    }
}

struct CreateTemplateCard: View {
    let theme: ThemeManager.AppTheme
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 12) {
                Image(systemName: "plus.circle.fill")
                    .font(.system(size: 40))
                    .foregroundColor(.accentColor)
                
                Text("Create Custom")
                    .font(.headline)
                    .foregroundColor(Color.dynamicText(theme: theme))
                
                Text("Build your own survey template")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .frame(height: 180)
            .background(Color.dynamicSurface(theme: theme).opacity(0.5))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(style: StrokeStyle(lineWidth: 2, dash: [5]))
                    .foregroundColor(.accentColor.opacity(0.5))
            )
            .cornerRadius(12)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

struct TemplatePreviewView: View {
    let template: SurveyTemplate
    @EnvironmentObject var themeManager: ThemeManager
    @Environment(\.dismiss) var dismiss
    let onUse: () -> Void
    
    @State private var currentQuestionIndex = 0
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Template Info
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Image(systemName: iconForCategory(template.category))
                                .font(.system(size: 30))
                                .foregroundColor(categoryColor)
                            
                            Spacer()
                            
                            if template.isPopular {
                                Label("Popular", systemImage: "star.fill")
                                    .font(.subheadline)
                                    .foregroundColor(.yellow)
                            }
                        }
                        
                        Text(template.title)
                            .font(.largeTitle)
                            .fontWeight(.bold)
                            .foregroundColor(Color.dynamicText(theme: themeManager.currentTheme))
                        
                        if let description = template.description {
                            Text(description)
                                .font(.body)
                                .foregroundColor(.secondary)
                        }
                        
                        HStack(spacing: 20) {
                            Label("\(template.questions.count) Questions", systemImage: "questionmark.circle")
                            if let time = template.estimatedCompletionTime {
                                Label("\(time) min", systemImage: "clock")
                            }
                            if template.isAnonymous {
                                Label("Anonymous", systemImage: "person.fill.questionmark")
                            }
                        }
                        .font(.caption)
                        .foregroundColor(.secondary)
                    }
                    .padding()
                    .background(Color.dynamicSurface(theme: themeManager.currentTheme))
                    .cornerRadius(12)
                    
                    // Questions Preview
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Questions Preview")
                            .font(.headline)
                            .foregroundColor(Color.dynamicText(theme: themeManager.currentTheme))
                        
                        ForEach(Array(template.questions.enumerated()), id: \.element.id) { index, question in
                            QuestionPreviewCard(
                                question: question,
                                index: index + 1,
                                theme: themeManager.currentTheme
                            )
                        }
                    }
                    
                    // Use Template Button
                    Button(action: onUse) {
                        HStack {
                            Image(systemName: "doc.badge.plus")
                            Text("Use This Template")
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.accentColor)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                    }
                }
                .padding()
            }
            .background(Color.dynamicBackground(theme: themeManager.currentTheme))
            .navigationTitle("Template Preview")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Close") {
                        dismiss()
                    }
                }
            }
        }
    }
    
    private func iconForCategory(_ category: String?) -> String {
        switch category?.lowercased() ?? "" {
        case "fitness": return "figure.walk"
        case "satisfaction": return "star.fill"
        case "feedback": return "bubble.left.and.bubble.right"
        case "health": return "heart.fill"
        case "custom": return "sparkles"
        default: return "doc.text"
        }
    }
    
    private var categoryColor: Color {
        switch template.category?.lowercased() ?? "" {
        case "fitness": return .blue
        case "satisfaction": return .green
        case "feedback": return .orange
        case "health": return .red
        case "custom": return .purple
        default: return .gray
        }
    }
}

struct QuestionPreviewCard: View {
    let question: TemplateQuestion
    let index: Int
    let theme: ThemeManager.AppTheme
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Text("\(index)")
                .font(.caption)
                .fontWeight(.bold)
                .foregroundColor(.white)
                .frame(width: 24, height: 24)
                .background(Color.accentColor)
                .clipShape(Circle())
            
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text(question.text)
                        .font(.subheadline)
                        .foregroundColor(Color.dynamicText(theme: theme))
                    
                    if question.required {
                        Text("*")
                            .foregroundColor(.red)
                    }
                }
                
                HStack {
                    Image(systemName: iconForQuestionType(question.type))
                        .font(.caption)
                    Text(question.type.displayName)
                        .font(.caption)
                        .fontWeight(.medium)
                }
                .foregroundColor(.secondary)
                
                if let options = question.options, !options.isEmpty {
                    VStack(alignment: .leading, spacing: 4) {
                        ForEach(Array(options.prefix(3)), id: \.self) { option in
                            HStack(spacing: 6) {
                                Image(systemName: question.type == .checkbox ? "square" : "circle")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                Text(option)
                                    .font(.caption)
                                    .foregroundColor(Color.dynamicText(theme: theme))
                            }
                        }
                        if options.count > 3 {
                            Text("... and \(options.count - 3) more")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding(.leading, 20)
                }
            }
            
            Spacer()
        }
        .padding()
        .background(Color.dynamicSurface(theme: theme))
        .cornerRadius(8)
    }
    
    private func iconForQuestionType(_ type: QuestionType) -> String {
        switch type {
        case .text, .textarea: return "text.align.left"
        case .radio: return "circle"
        case .checkbox: return "checkmark.square"
        case .select: return "chevron.down.circle"
        case .scale: return "slider.horizontal.below.rectangle"
        case .date: return "calendar"
        case .time: return "clock"
        case .number: return "number"
        case .email: return "envelope"
        case .phone: return "phone"
        case .yesNo: return "hand.thumbsup"
        case .nps: return "star"
        }
    }
}