import SwiftUI

struct SurveyCreatorView: View {
    let survey: Survey?
    @EnvironmentObject var surveyService: SurveyService
    @EnvironmentObject var themeManager: ThemeManager
    @EnvironmentObject var gymService: GymService
    @Environment(\.dismiss) var dismiss
    
    // Survey Details
    @State private var title = ""
    @State private var description = ""
    @State private var isAnonymous = false
    @State private var allowMultiple = false
    @State private var randomizeQuestions = false
    @State private var showProgress = true
    @State private var thankYouMessage = ""
    
    // Date Settings
    @State private var hasStartDate = false
    @State private var startDate = Date()
    @State private var hasEndDate = false
    @State private var endDate = Date().addingTimeInterval(7 * 24 * 60 * 60) // 7 days from now
    
    // Questions
    @State private var questions: [SurveyQuestion] = []
    @State private var currentStep = 0
    @State private var showingQuestionEditor = false
    @State private var editingQuestion: SurveyQuestion?
    @State private var isPublishing = false
    
    var isEditing: Bool {
        survey != nil
    }
    
    var body: some View {
        NavigationView {
            ZStack {
                Color.dynamicBackground(theme: themeManager.currentTheme)
                    .ignoresSafeArea()
                
                VStack(spacing: 0) {
                    // Progress Indicator
                    progressIndicator
                    
                    // Content
                    TabView(selection: $currentStep) {
                        basicDetailsStep
                            .tag(0)
                        
                        questionsStep
                            .tag(1)
                        
                        reviewStep
                            .tag(2)
                    }
                    .tabViewStyle(PageTabViewStyle(indexDisplayMode: .never))
                }
            }
            .navigationTitle(isEditing ? "Edit Survey" : "Create Survey")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save Draft") {
                        saveDraft()
                    }
                    .disabled(title.isEmpty)
                }
                
                // Bottom toolbar for navigation
                ToolbarItemGroup(placement: .bottomBar) {
                    // Previous button
                    Button(action: {
                        withAnimation {
                            currentStep = max(0, currentStep - 1)
                        }
                    }) {
                        HStack {
                            Image(systemName: "chevron.left")
                            Text("Previous")
                        }
                    }
                    .disabled(currentStep == 0)
                    
                    Spacer()
                    
                    // Publish button (only on step 2)
                    if currentStep == 2 {
                        Button(action: {
                            Task {
                                await publishSurvey()
                            }
                        }) {
                            HStack {
                                if isPublishing {
                                    ProgressView()
                                        .progressViewStyle(CircularProgressViewStyle())
                                        .scaleEffect(0.8)
                                    Text("Publishing...")
                                } else {
                                    Image(systemName: "paperplane.fill")
                                    Text("Publish")
                                }
                            }
                            .foregroundColor(.white)
                            .padding(.horizontal, 20)
                            .padding(.vertical, 8)
                            .background(isPublishing ? Color.gray : Color.green)
                            .cornerRadius(8)
                        }
                        .disabled(isPublishing || questions.isEmpty)
                    } else {
                        // Next button for steps 0 and 1
                        Button(action: {
                            withAnimation {
                                currentStep = min(2, currentStep + 1)
                            }
                        }) {
                            HStack {
                                Text("Next")
                                Image(systemName: "chevron.right")
                            }
                        }
                        .disabled((currentStep == 0 && title.isEmpty) || (currentStep == 1 && questions.isEmpty))
                    }
                }
            }
        }
        .sheet(isPresented: $showingQuestionEditor) {
            QuestionEditorView(existingQuestion: editingQuestion) { question in
                if let editingQuestion = editingQuestion,
                   let index = questions.firstIndex(where: { $0.id == editingQuestion.id }) {
                    // Editar pregunta existente
                    questions[index] = question
                } else {
                    // Agregar nueva pregunta
                    questions.append(question)
                }
            }
            .environmentObject(themeManager)
        }
        .onAppear {
            if let survey = survey {
                loadSurvey(survey)
            }
        }
    }
    
    // MARK: - Step 1: Basic Details
    
    private var basicDetailsStep: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Text("Basic Information")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(Color.dynamicText(theme: themeManager.currentTheme))
                    .padding(.horizontal)
                
                VStack(spacing: 16) {
                    // Title
                    VStack(alignment: .leading, spacing: 8) {
                        Label("Title", systemImage: "textformat")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        TextField("Survey Title", text: $title)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                    }
                    
                    // Description
                    VStack(alignment: .leading, spacing: 8) {
                        Label("Description", systemImage: "text.align.left")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        TextEditor(text: $description)
                            .frame(minHeight: 80)
                            .padding(8)
                            .background(Color.gray.opacity(0.1))
                            .cornerRadius(8)
                    }
                    
                    // Settings
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Settings")
                            .font(.headline)
                            .foregroundColor(Color.dynamicText(theme: themeManager.currentTheme))
                        
                        Toggle("Anonymous Responses", isOn: $isAnonymous)
                        
                        Toggle("Allow Multiple Submissions", isOn: $allowMultiple)
                        
                        Toggle("Randomize Question Order", isOn: $randomizeQuestions)
                        
                        Toggle("Show Progress Bar", isOn: $showProgress)
                    }
                    .padding()
                    .background(Color.dynamicSurface(theme: themeManager.currentTheme))
                    .cornerRadius(12)
                    
                    // Date Settings
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Schedule")
                            .font(.headline)
                            .foregroundColor(Color.dynamicText(theme: themeManager.currentTheme))
                        
                        Toggle("Set Start Date", isOn: $hasStartDate)
                        
                        if hasStartDate {
                            DatePicker("Start Date", selection: $startDate, displayedComponents: [.date, .hourAndMinute])
                                .datePickerStyle(CompactDatePickerStyle())
                        }
                        
                        Toggle("Set End Date", isOn: $hasEndDate)
                        
                        if hasEndDate {
                            DatePicker("End Date", selection: $endDate, displayedComponents: [.date, .hourAndMinute])
                                .datePickerStyle(CompactDatePickerStyle())
                        }
                    }
                    .padding()
                    .background(Color.dynamicSurface(theme: themeManager.currentTheme))
                    .cornerRadius(12)
                    
                    // Thank You Message
                    VStack(alignment: .leading, spacing: 8) {
                        Label("Thank You Message (Optional)", systemImage: "heart")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        TextField("Message shown after completion", text: $thankYouMessage)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                    }
                }
                .padding(.horizontal)
                
                Spacer(minLength: 100)
            }
        }
    }
    
    // MARK: - Step 2: Questions
    
    private var questionsStep: some View {
        VStack(spacing: 16) {
            // Header
            HStack {
                Text("Questions")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(Color.dynamicText(theme: themeManager.currentTheme))
                
                Spacer()
                
                Button(action: { showingQuestionEditor = true }) {
                    HStack {
                        Image(systemName: "plus.circle")
                        Text("Add Question")
                    }
                    .font(.subheadline)
                    .foregroundColor(.accentColor)
                }
            }
            .padding(.horizontal)
            
            if questions.isEmpty {
                // Empty State
                VStack(spacing: 20) {
                    Image(systemName: "questionmark.circle")
                        .font(.system(size: 60))
                        .foregroundColor(.secondary)
                    
                    Text("No Questions Yet")
                        .font(.title3)
                        .fontWeight(.semibold)
                        .foregroundColor(Color.dynamicText(theme: themeManager.currentTheme))
                    
                    Text("Add questions to build your survey")
                        .font(.body)
                        .foregroundColor(.secondary)
                    
                    Button(action: { showingQuestionEditor = true }) {
                        Text("Add First Question")
                            .padding(.horizontal, 20)
                            .padding(.vertical, 10)
                            .background(Color.accentColor)
                            .foregroundColor(.white)
                            .cornerRadius(8)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                // Questions List
                ScrollView {
                    LazyVStack(spacing: 12) {
                        ForEach(questions.indices, id: \.self) { index in
                            QuestionRowView(
                                question: questions[index],
                                index: index,
                                onEdit: {
                                    editingQuestion = questions[index]
                                    showingQuestionEditor = true
                                },
                                onDelete: {
                                    questions.remove(at: index)
                                },
                                onMoveUp: {
                                    if index > 0 {
                                        questions.swapAt(index, index - 1)
                                    }
                                },
                                onMoveDown: {
                                    if index < questions.count - 1 {
                                        questions.swapAt(index, index + 1)
                                    }
                                }
                            )
                            .environmentObject(themeManager)
                        }
                    }
                    .padding(.horizontal)
                }
            }
        }
    }
    
    // MARK: - Step 3: Review
    
    private var reviewStep: some View {
        ScrollView {
            VStack(spacing: 16) {
                // Title
                Text("Review & Publish")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(Color.dynamicText(theme: themeManager.currentTheme))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal)
                
                // Survey Info Card
                VStack(alignment: .leading, spacing: 16) {
                    // Title & Description
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Image(systemName: "doc.text.fill")
                                .foregroundColor(.accentColor)
                                .font(.title3)
                            Text(title.isEmpty ? "Untitled Survey" : title)
                                .font(.title3)
                                .fontWeight(.semibold)
                                .foregroundColor(Color.dynamicText(theme: themeManager.currentTheme))
                        }
                        
                        if !description.isEmpty {
                            Text(description)
                                .font(.body)
                                .foregroundColor(.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                        } else {
                            Text("No description provided")
                                .font(.body)
                                .foregroundColor(.secondary.opacity(0.5))
                                .italic()
                        }
                    }
                    
                    Divider()
                    
                    // Configuration Grid
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Configuration")
                            .font(.headline)
                            .foregroundColor(Color.dynamicText(theme: themeManager.currentTheme))
                        
                        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                            ConfigItem(title: "Anonymous", isEnabled: isAnonymous, icon: "person.fill.questionmark")
                            ConfigItem(title: "Multiple Responses", isEnabled: allowMultiple, icon: "arrow.triangle.2.circlepath")
                            ConfigItem(title: "Randomize Questions", isEnabled: randomizeQuestions, icon: "shuffle")
                            ConfigItem(title: "Show Progress", isEnabled: showProgress, icon: "percent")
                        }
                    }
                    .padding()
                    .background(Color.gray.opacity(0.05))
                    .cornerRadius(8)
                    
                    // Schedule if configured
                    if hasStartDate || hasEndDate {
                        VStack(alignment: .leading, spacing: 8) {
                            Label("Schedule", systemImage: "calendar")
                                .font(.headline)
                                .foregroundColor(Color.dynamicText(theme: themeManager.currentTheme))
                            
                            HStack(spacing: 20) {
                                if hasStartDate {
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text("Starts")
                                            .font(.caption2)
                                            .foregroundColor(.secondary)
                                        Text(startDate, style: .date)
                                            .font(.caption)
                                            .foregroundColor(.blue)
                                    }
                                }
                                
                                if hasEndDate {
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text("Ends")
                                            .font(.caption2)
                                            .foregroundColor(.secondary)
                                        Text(endDate, style: .date)
                                            .font(.caption)
                                            .foregroundColor(.orange)
                                    }
                                }
                            }
                        }
                        .padding()
                        .background(Color.blue.opacity(0.05))
                        .cornerRadius(8)
                    }
                    
                    // Thank You Message
                    if !thankYouMessage.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Label("Thank You Message", systemImage: "heart.text.square.fill")
                                .font(.headline)
                                .foregroundColor(Color.dynamicText(theme: themeManager.currentTheme))
                            
                            Text(thankYouMessage)
                                .font(.body)
                                .foregroundColor(.secondary)
                                .padding()
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(Color.green.opacity(0.05))
                                .cornerRadius(8)
                        }
                    }
                }
                .padding()
                .background(Color.dynamicSurface(theme: themeManager.currentTheme))
                .cornerRadius(12)
                .padding(.horizontal)
                
                // Questions Section
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Label("\(questions.count) Questions", systemImage: "questionmark.circle.fill")
                            .font(.headline)
                            .foregroundColor(Color.dynamicText(theme: themeManager.currentTheme))
                        
                        Spacer()
                        
                        if questions.count > 5 {
                            Text("Showing first 5")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    if !questions.isEmpty {
                        VStack(spacing: 0) {
                            ForEach(questions.prefix(5).indices, id: \.self) { index in
                                QuestionPreviewRow(
                                    question: questions[index],
                                    index: index + 1
                                )
                                
                                if index < min(questions.count - 1, 4) {
                                    Divider()
                                        .padding(.leading, 30)
                                }
                            }
                            
                            if questions.count > 5 {
                                HStack {
                                    Spacer()
                                    Text("+\(questions.count - 5) more questions")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                        .italic()
                                        .padding(.top, 12)
                                    Spacer()
                                }
                            }
                        }
                        .padding()
                        .background(Color.gray.opacity(0.05))
                        .cornerRadius(8)
                    } else {
                        HStack {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundColor(.orange)
                            Text("No questions added")
                                .foregroundColor(.secondary)
                        }
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(Color.orange.opacity(0.1))
                        .cornerRadius(8)
                    }
                }
                .padding()
                .background(Color.dynamicSurface(theme: themeManager.currentTheme))
                .cornerRadius(12)
                .padding(.horizontal)
                
                // Smaller spacer
                Spacer(minLength: 20)
            }
            .padding(.vertical)
        }
    }
    
    // MARK: - Components
    
    private var progressIndicator: some View {
        VStack(spacing: 8) {
            HStack(spacing: 20) {
                ForEach(0..<3) { step in
                    VStack(spacing: 4) {
                        Circle()
                            .fill(currentStep >= step ? Color.accentColor : Color.gray.opacity(0.3))
                            .frame(width: 30, height: 30)
                            .overlay(
                                Text("\(step + 1)")
                                    .font(.caption)
                                    .fontWeight(.semibold)
                                    .foregroundColor(currentStep >= step ? .white : .secondary)
                            )
                        
                        Text(stepTitle(for: step))
                            .font(.caption2)
                            .foregroundColor(currentStep == step ? Color.dynamicText(theme: themeManager.currentTheme) : .secondary)
                    }
                }
            }
            
            // Progress bar
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    Rectangle()
                        .fill(Color.gray.opacity(0.2))
                        .frame(height: 2)
                    
                    Rectangle()
                        .fill(Color.accentColor)
                        .frame(width: geometry.size.width * (Double(currentStep) / 2), height: 2)
                        .animation(.easeInOut, value: currentStep)
                }
            }
            .frame(height: 2)
        }
        .padding()
        .background(Color.dynamicSurface(theme: themeManager.currentTheme))
    }
    
    // MARK: - Helper Methods
    
    private func stepTitle(for step: Int) -> String {
        switch step {
        case 0: return "Basics"
        case 1: return "Questions"
        case 2: return "Review"
        default: return ""
        }
    }
    
    private func canProceed() -> Bool {
        switch currentStep {
        case 0:
            return !title.isEmpty
        case 1:
            return !questions.isEmpty
        case 2:
            return !title.isEmpty && !questions.isEmpty
        default:
            return false
        }
    }
    
    private func loadSurvey(_ survey: Survey) {
        title = survey.title
        description = survey.description ?? ""
        isAnonymous = survey.isAnonymous
        allowMultiple = survey.allowMultiple
        randomizeQuestions = survey.randomizeQuestions
        showProgress = survey.showProgress
        thankYouMessage = survey.thankYouMessage ?? ""
        
        if let start = survey.startDate {
            hasStartDate = true
            startDate = start
        }
        
        if let end = survey.endDate {
            hasEndDate = true
            endDate = end
        }
        
        // TODO: Load questions
    }
    
    private func saveDraft() {
        Task {
            // Crear el request con formato correcto
            let createRequest = createSurveyRequest(isDraft: true)
            
            print("📝 Saving survey as draft...")
            if let createdSurvey = await surveyService.createSurvey(createRequest: createRequest) {
                print("✅ Survey saved as draft: \(createdSurvey.title)")
                await MainActor.run {
                    dismiss()
                }
            } else {
                print("🔴 Failed to save draft")
                // Mostrar error al usuario
                await MainActor.run {
                    // TODO: Mostrar alerta de error
                }
            }
        }
    }
    
    private func publishSurvey() {
        guard !isPublishing else { return }
        
        Task {
            await MainActor.run {
                isPublishing = true
            }
            
            // Crear el survey primero
            let createRequest = createSurveyRequest(isDraft: false)
            
            print("📤 Creating and publishing survey...")
            if let createdSurvey = await surveyService.createSurvey(createRequest: createRequest) {
                print("✅ Survey created, now publishing...")
                
                // Publicar el survey
                if await surveyService.publishSurvey(surveyId: createdSurvey.id) {
                    print("🎉 Survey published successfully!")
                    await MainActor.run {
                        isPublishing = false
                        dismiss()
                    }
                } else {
                    print("⚠️ Survey created but failed to publish")
                    await MainActor.run {
                        isPublishing = false
                        // TODO: Mostrar alerta - survey creado pero no publicado
                    }
                }
            } else {
                print("🔴 Failed to create survey")
                await MainActor.run {
                    isPublishing = false
                    // TODO: Mostrar alerta de error
                }
            }
        }
    }
    
    private func createSurveyRequest(isDraft: Bool) -> SurveyCreateRequest {
        // Convertir las preguntas al formato esperado
        let questionRequests = questions.enumerated().map { index, question in
            // Convertir choices si es pregunta de selección
            var choices: [ChoiceCreateRequest] = []
            if [.radio, .checkbox, .select].contains(question.questionType) {
                if let questionChoices = question.choices {
                    choices = questionChoices.enumerated().map { choiceIndex, choice in
                        ChoiceCreateRequest(
                            choiceText: choice.choiceText,
                            choiceValue: choice.choiceValue,
                            order: choiceIndex
                        )
                    }
                }
            }
            
            return QuestionCreateRequest(
                questionText: question.questionText,
                questionType: question.questionType,
                isRequired: question.isRequired,
                order: index,
                helpText: question.helpText,
                placeholder: question.placeholder,
                minValue: question.minValue,
                maxValue: question.maxValue,
                minLength: question.minLength,
                maxLength: question.maxLength,
                allowOther: question.allowOther ?? false,
                choices: choices
            )
        }
        
        return SurveyCreateRequest(
            title: title,
            description: description.isEmpty ? nil : description,
            instructions: nil,
            startDate: hasStartDate ? startDate : nil,
            endDate: hasEndDate ? endDate : nil,
            isAnonymous: isAnonymous,
            allowMultiple: allowMultiple,
            randomizeQuestions: randomizeQuestions,
            showProgress: showProgress,
            thankYouMessage: thankYouMessage.isEmpty ? "Gracias por completar la encuesta" : thankYouMessage,
            tags: [],
            targetAudience: nil,
            questions: questionRequests
        )
    }
}

// MARK: - Question Row View
struct QuestionRowView: View {
    let question: SurveyQuestion
    let index: Int
    let onEdit: () -> Void
    let onDelete: () -> Void
    let onMoveUp: () -> Void
    let onMoveDown: () -> Void
    @EnvironmentObject var themeManager: ThemeManager
    
    var body: some View {
        HStack {
            // Order indicator
            Text("\(index + 1)")
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundColor(.white)
                .frame(width: 24, height: 24)
                .background(Color.accentColor)
                .clipShape(Circle())
            
            // Question info
            VStack(alignment: .leading, spacing: 4) {
                Text(question.questionText)
                    .font(.subheadline)
                    .foregroundColor(Color.dynamicText(theme: themeManager.currentTheme))
                    .lineLimit(2)
                
                HStack(spacing: 8) {
                    Image(systemName: question.questionType.icon)
                        .font(.caption)
                    
                    Text(question.questionType.displayName)
                        .font(.caption)
                    
                    if question.isRequired {
                        Text("• Required")
                            .font(.caption)
                            .foregroundColor(.red)
                    }
                }
                .foregroundColor(.secondary)
            }
            
            Spacer()
            
            // Actions
            HStack(spacing: 12) {
                Button(action: onMoveUp) {
                    Image(systemName: "arrow.up")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .disabled(index == 0)
                
                Button(action: onMoveDown) {
                    Image(systemName: "arrow.down")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Button(action: onEdit) {
                    Image(systemName: "pencil")
                        .font(.caption)
                        .foregroundColor(.accentColor)
                }
                
                Button(action: onDelete) {
                    Image(systemName: "trash")
                        .font(.caption)
                        .foregroundColor(.red)
                }
            }
        }
        .padding()
        .background(Color.dynamicSurface(theme: themeManager.currentTheme))
        .cornerRadius(8)
    }
}

// MARK: - Helper Views for Survey Creator

struct ConfigItem: View {
    let title: String
    let isEnabled: Bool
    let icon: String
    
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: isEnabled ? "checkmark.circle.fill" : "xmark.circle")
                .foregroundColor(isEnabled ? .green : .gray)
                .font(.system(size: 16))
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.caption)
                    .foregroundColor(.primary)
                
                Image(systemName: icon)
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct QuestionPreviewRow: View {
    let question: SurveyQuestion
    let index: Int
    @Environment(\.colorScheme) var colorScheme
    
    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Text("\(index).")
                .font(.caption)
                .foregroundColor(.secondary)
                .frame(width: 20, alignment: .trailing)
            
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text(question.questionText)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.primary)
                    
                    if question.isRequired {
                        Text("*")
                            .foregroundColor(.red)
                            .font(.subheadline)
                    }
                }
                
                HStack(spacing: 6) {
                    Image(systemName: question.questionType.icon)
                        .font(.caption2)
                        .foregroundColor(.accentColor)
                    
                    Text(question.questionType.displayName)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                // Show choices preview for selection questions
                if let choices = question.choices,
                   !choices.isEmpty,
                   [.radio, .checkbox, .select].contains(question.questionType) {
                    VStack(alignment: .leading, spacing: 4) {
                        ForEach(choices.prefix(2), id: \.id) { choice in
                            HStack(spacing: 4) {
                                Image(systemName: question.questionType == .checkbox ? "square" : "circle")
                                    .font(.caption2)
                                    .foregroundColor(.gray.opacity(0.5))
                                Text(choice.choiceText)
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                            }
                        }
                        if choices.count > 2 {
                            Text("+ \(choices.count - 2) more options")
                                .font(.caption2)
                                .foregroundColor(.secondary.opacity(0.7))
                                .italic()
                        }
                    }
                    .padding(.leading, 4)
                }
            }
            
            Spacer()
        }
        .padding(.vertical, 8)
    }
}