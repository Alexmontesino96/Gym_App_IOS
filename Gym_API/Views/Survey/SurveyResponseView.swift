import SwiftUI

struct SurveyResponseView: View {
    let survey: Survey
    @EnvironmentObject var surveyService: SurveyService
    @EnvironmentObject var themeManager: ThemeManager
    @Environment(\.dismiss) var dismiss
    
    @State private var currentQuestionIndex = 0
    @State private var showingCompletion = false
    @State private var showingExitAlert = false
    @State private var showingErrorAlert = false
    @State private var answers: [Int: SurveyAnswer] = [:]
    
    var progress: Double {
        guard !surveyService.currentQuestions.isEmpty else { return 0 }
        return Double(currentQuestionIndex + 1) / Double(surveyService.currentQuestions.count)
    }
    
    var currentQuestion: SurveyQuestion? {
        guard currentQuestionIndex < surveyService.currentQuestions.count else { return nil }
        return surveyService.currentQuestions[currentQuestionIndex]
    }
    
    var canProceed: Bool {
        guard let question = currentQuestion else { return false }
        
        if !question.isRequired {
            return true
        }
        
        guard let answer = answers[question.id] else { return false }
        
        switch question.questionType {
        case .text, .textarea, .email, .phone:
            return !(answer.textAnswer ?? "").isEmpty
        case .radio, .select:
            return answer.choiceId != nil || !(answer.otherText ?? "").isEmpty
        case .checkbox:
            return !(answer.choiceIds ?? []).isEmpty || !(answer.otherText ?? "").isEmpty
        case .scale, .number, .nps:
            return answer.numberAnswer != nil
        case .date:
            return answer.dateAnswer != nil
        case .time:
            return !(answer.textAnswer ?? "").isEmpty
        case .yesNo:
            return answer.booleanAnswer != nil
        }
    }
    
    var body: some View {
        let _ = print("📱 SurveyResponseView.body called")
        let _ = print("   Survey: \(survey.title) (ID: \(survey.id))")
        let _ = print("   isLoading: \(surveyService.isLoading)")
        let _ = print("   currentQuestions count: \(surveyService.currentQuestions.count)")
        let _ = print("   currentQuestionIndex: \(currentQuestionIndex)")
        
        return NavigationView {
            ZStack {
                Color.dynamicBackground(theme: themeManager.currentTheme)
                    .ignoresSafeArea()
                
                // Show completion view first if survey was submitted
                if showingCompletion {
                    let _ = print("🎉 Showing completion view")
                    SurveyCompletionView(survey: survey) {
                        // Clear survey data first
                        surveyService.clearCurrentSurvey()
                        
                        // Dismiss the sheet
                        dismiss()
                        
                        // Refresh surveys after dismissal
                        Task {
                            print("📍 Scheduling survey refresh after dismissal")
                            // Small delay to ensure sheet is fully dismissed
                            try? await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
                            print("📍 Executing deferred survey refresh")
                            await surveyService.refreshSurveysIfNeeded()
                        }
                    }
                    .environmentObject(themeManager)
                } else if surveyService.isLoading && surveyService.currentQuestions.isEmpty {
                    let _ = print("⏳ Showing loading view")
                    ProgressView("Loading survey...")
                } else if let question = currentQuestion {
                    let _ = print("✅ Showing question: \(question.questionText)")
                    VStack(spacing: 0) {
                        // Progress Bar
                        if survey.showProgress {
                            VStack(spacing: 8) {
                                HStack {
                                    Text("Question \(currentQuestionIndex + 1) of \(surveyService.currentQuestions.count)")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                    
                                    Spacer()
                                    
                                    Text("\(Int(progress * 100))%")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                .padding(.horizontal)
                                
                                GeometryReader { geometry in
                                    ZStack(alignment: .leading) {
                                        Rectangle()
                                            .fill(Color.gray.opacity(0.2))
                                            .frame(height: 4)
                                        
                                        Rectangle()
                                            .fill(Color.accentColor)
                                            .frame(width: geometry.size.width * progress, height: 4)
                                            .animation(.easeInOut, value: progress)
                                    }
                                }
                                .frame(height: 4)
                                .padding(.horizontal)
                            }
                            .padding(.vertical)
                        }
                        
                        // Question Content
                        ScrollView {
                            VStack(alignment: .leading, spacing: 20) {
                                // Survey Title (on first question)
                                if currentQuestionIndex == 0 {
                                    VStack(alignment: .leading, spacing: 8) {
                                        Text(survey.title)
                                            .font(.title2)
                                            .fontWeight(.bold)
                                            .foregroundColor(Color.dynamicText(theme: themeManager.currentTheme))
                                        
                                        if let description = survey.description {
                                            Text(description)
                                                .font(.body)
                                                .foregroundColor(.secondary)
                                        }
                                    }
                                    .padding()
                                    .background(Color.dynamicSurface(theme: themeManager.currentTheme))
                                    .cornerRadius(12)
                                    .padding(.horizontal)
                                    .padding(.top)
                                }
                                
                                // Question View with Animation
                                SurveyQuestionView(
                                    question: question,
                                    answer: Binding(
                                        get: {
                                            answers[question.id] ?? SurveyAnswer(questionId: question.id)
                                        },
                                        set: { newAnswer in
                                            answers[question.id] = newAnswer
                                        }
                                    )
                                )
                                .padding()
                                .background(Color.dynamicSurface(theme: themeManager.currentTheme))
                                .cornerRadius(12)
                                .padding(.horizontal)
                                .id(currentQuestionIndex) // Important for animation
                                .transition(.asymmetric(
                                    insertion: .move(edge: .trailing).combined(with: .opacity),
                                    removal: .move(edge: .leading).combined(with: .opacity)
                                ))
                                .animation(.spring(response: 0.4, dampingFraction: 0.8), value: currentQuestionIndex)
                                
                                Spacer(minLength: 100)
                            }
                        }
                        
                        // Navigation Buttons
                        HStack(spacing: 16) {
                            // Previous Button (only show if not first question)
                            if currentQuestionIndex > 0 {
                                Button(action: {
                                    previousQuestion()
                                    let impactFeedback = UIImpactFeedbackGenerator(style: .light)
                                    impactFeedback.impactOccurred()
                                }) {
                                    HStack {
                                        Image(systemName: "arrow.left")
                                        Text("Previous")
                                    }
                                    .font(.system(size: 16, weight: .medium))
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 14)
                                    .background(
                                        RoundedRectangle(cornerRadius: 12)
                                            .fill(Color.secondary.opacity(0.2))
                                    )
                                    .foregroundColor(Color.dynamicText(theme: themeManager.currentTheme))
                                }
                                .transition(.move(edge: .leading).combined(with: .opacity))
                            }
                            
                            // Next/Submit Button with Gradient
                            Button(action: {
                                withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                                    if currentQuestionIndex == surveyService.currentQuestions.count - 1 {
                                        submitSurvey()
                                    } else {
                                        nextQuestion()
                                    }
                                }
                                let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
                                impactFeedback.impactOccurred()
                            }) {
                                HStack(spacing: 8) {
                                    Text(currentQuestionIndex == surveyService.currentQuestions.count - 1 ? "Submit Survey" : "Next")
                                        .font(.system(size: 16, weight: .semibold))
                                    
                                    Image(systemName: currentQuestionIndex == surveyService.currentQuestions.count - 1 ? "checkmark.circle.fill" : "arrow.right")
                                        .font(.system(size: 14, weight: .semibold))
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 14)
                                .background(
                                    LinearGradient(
                                        gradient: Gradient(colors: canProceed ? [Color.blue, Color.purple] : [Color.gray]),
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                    .opacity(canProceed ? 1.0 : 0.5)
                                )
                                .foregroundColor(.white)
                                .cornerRadius(12)
                            }
                            .disabled(!canProceed)
                        }
                        .padding()
                        .background(Color.dynamicSurface(theme: themeManager.currentTheme))
                    }
                } else {
                    let _ = print("⚠️ No content to show")
                    let _ = print("   isLoading: \(surveyService.isLoading)")
                    let _ = print("   currentQuestions.isEmpty: \(surveyService.currentQuestions.isEmpty)")
                    let _ = print("   currentQuestion is nil: \(currentQuestion == nil)")
                    let _ = print("   showingCompletion: \(showingCompletion)")
                    
                    VStack(spacing: 20) {
                        Image(systemName: "questionmark.circle")
                            .font(.system(size: 60))
                            .foregroundColor(.secondary)
                        
                        Text("No questions available")
                            .font(.title3)
                            .fontWeight(.semibold)
                            .foregroundColor(Color.dynamicText(theme: themeManager.currentTheme))
                        
                        Text("This survey has no questions yet")
                            .font(.body)
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    if !showingCompletion {
                        Button("Cancel") {
                            showingExitAlert = true
                        }
                    }
                }
            }
            .alert("Exit Survey?", isPresented: $showingExitAlert) {
                Button("Continue Survey", role: .cancel) { }
                Button("Exit", role: .destructive) {
                    surveyService.clearCurrentSurvey()
                    dismiss()
                }
            } message: {
                Text("Your progress will be lost if you exit now.")
            }
            .alert("Submission Error", isPresented: $showingErrorAlert) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(surveyService.errorMessage ?? "Failed to submit survey. Please try again.")
            }
        }
        .onAppear {
            print("🚀 SurveyResponseView.onAppear")
            print("   Survey ID: \(survey.id)")
            print("   Survey Title: \(survey.title)")
            Task {
                print("📡 Starting to fetch survey details...")
                await surveyService.getSurveyDetails(surveyId: survey.id)
                print("✅ Survey details fetch completed")
                print("   Questions loaded: \(surveyService.currentQuestions.count)")
                initializeAnswers()
                print("📝 Answers initialized")
            }
        }
    }
    
    private func initializeAnswers() {
        for question in surveyService.currentQuestions {
            if answers[question.id] == nil {
                answers[question.id] = SurveyAnswer(questionId: question.id)
            }
        }
    }
    
    private func previousQuestion() {
        withAnimation {
            currentQuestionIndex = max(0, currentQuestionIndex - 1)
        }
    }
    
    private func nextQuestion() {
        withAnimation {
            currentQuestionIndex = min(surveyService.currentQuestions.count - 1, currentQuestionIndex + 1)
        }
    }
    
    private func submitSurvey() {
        print("🚀 Starting survey submission")
        print("   Survey ID: \(survey.id)")
        print("   Number of answers: \(answers.count)")
        
        // Log each answer for debugging
        for (questionId, answer) in answers {
            print("   Q\(questionId): text=\(answer.textAnswer ?? "nil"), choice=\(answer.choiceId ?? -1), number=\(answer.numberAnswer ?? -1)")
        }
        
        // Update the service's current response with our answers
        if var response = surveyService.currentResponse {
            response.answers = Array(answers.values)
            response.isComplete = true
            response.completedAt = Date()
            surveyService.currentResponse = response
            print("✅ Updated currentResponse with \(response.answers?.count ?? 0) answers")
        } else {
            print("⚠️ No currentResponse found in surveyService")
        }
        
        Task {
            print("📡 Calling submitSurveyResponse...")
            await surveyService.submitSurveyResponse()
            
            if let error = surveyService.errorMessage {
                print("❌ Submission failed: \(error)")
                showingErrorAlert = true
            } else {
                print("✅ Submission successful, showing completion view")
                withAnimation {
                    showingCompletion = true
                }
            }
        }
    }
}

// MARK: - Survey Completion View
struct SurveyCompletionView: View {
    let survey: Survey
    let onDismiss: () -> Void
    @EnvironmentObject var themeManager: ThemeManager
    @State private var showConfetti = false
    @State private var sparkles: [Sparkle] = []
    @State private var successScale = 0.1
    @State private var successRotation = -180.0
    @State private var textOpacity = 0.0
    @State private var canDismiss = false
    
    struct Sparkle: Identifiable {
        let id = UUID()
        let xPosition: CGFloat
        let yPosition: CGFloat
        let size: CGFloat
        let delay: Double
        let color: Color
    }
    
    var body: some View {
        ZStack {
            // Background with gradient
            LinearGradient(
                gradient: Gradient(colors: [
                    Color.dynamicBackground(theme: themeManager.currentTheme),
                    Color.accentColor.opacity(0.05)
                ]),
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
            
            // Animated sparkles
            ForEach(sparkles) { sparkle in
                Image(systemName: "sparkle")
                    .font(.system(size: sparkle.size))
                    .foregroundColor(sparkle.color)
                    .position(x: sparkle.xPosition, y: sparkle.yPosition)
                    .opacity(showConfetti ? 0 : 1)
                    .scaleEffect(showConfetti ? 0.1 : 1.5)
                    .animation(
                        .easeOut(duration: 1.5)
                        .delay(sparkle.delay),
                        value: showConfetti
                    )
            }
            
            VStack(spacing: 30) {
                Spacer()
                
                // Success Icon with better animation
                ZStack {
                    // Pulsing circle background
                    Circle()
                        .fill(
                            LinearGradient(
                                gradient: Gradient(colors: [Color.green.opacity(0.2), Color.blue.opacity(0.1)]),
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 140, height: 140)
                        .scaleEffect(showConfetti ? 1.0 : 0.8)
                        .opacity(showConfetti ? 1.0 : 0.0)
                        .animation(
                            .spring(response: 0.6, dampingFraction: 0.6)
                            .delay(0.2),
                            value: showConfetti
                        )
                    
                    // Success icon
                    Image(systemName: "checkmark.seal.fill")
                        .font(.system(size: 80))
                        .foregroundStyle(
                            LinearGradient(
                                gradient: Gradient(colors: [Color.green, Color.blue]),
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .scaleEffect(successScale)
                        .rotationEffect(.degrees(successRotation))
                        .animation(
                            .spring(response: 0.6, dampingFraction: 0.5)
                            .delay(0.3),
                            value: successScale
                        )
                }
                
                // Success Message with fade-in animation
                VStack(spacing: 16) {
                    Text("🎉 Excellent!")
                        .font(.system(size: 36, weight: .bold, design: .rounded))
                        .foregroundStyle(
                            LinearGradient(
                                gradient: Gradient(colors: [Color.blue, Color.purple]),
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .opacity(textOpacity)
                        .animation(
                            .easeIn(duration: 0.6)
                            .delay(0.5),
                            value: textOpacity
                        )
                    
                    Text("Your feedback has been recorded")
                        .font(.title3)
                        .foregroundColor(Color.dynamicText(theme: themeManager.currentTheme))
                        .opacity(textOpacity)
                        .animation(
                            .easeIn(duration: 0.6)
                            .delay(0.7),
                            value: textOpacity
                        )
                    
                    if let thankYouMessage = survey.thankYouMessage {
                        Text(thankYouMessage)
                            .font(.body)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                            .padding()
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(Color.dynamicSurface(theme: themeManager.currentTheme).opacity(0.8))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 12)
                                            .stroke(
                                                LinearGradient(
                                                    gradient: Gradient(colors: [Color.white.opacity(0.2), Color.white.opacity(0.05)]),
                                                    startPoint: .topLeading,
                                                    endPoint: .bottomTrailing
                                                ),
                                                lineWidth: 1
                                            )
                                    )
                            )
                            .padding(.horizontal)
                            .opacity(textOpacity)
                            .animation(
                                .easeIn(duration: 0.6)
                                .delay(0.9),
                                value: textOpacity
                            )
                    }
                    
                    // Stats or reward hint
                    HStack(spacing: 4) {
                        Image(systemName: "star.fill")
                            .foregroundColor(.yellow)
                            .font(.caption)
                        Text("You've earned 10 points!")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Image(systemName: "star.fill")
                            .foregroundColor(.yellow)
                            .font(.caption)
                    }
                    .padding(.top, 8)
                    .opacity(textOpacity)
                    .animation(
                        .easeIn(duration: 0.6)
                        .delay(1.1),
                        value: textOpacity
                    )
                }
                .padding(.horizontal)
                
                Spacer()
                
                // Done Button with gradient
                Button(action: {
                    guard canDismiss else {
                        print("⏱️ Waiting for minimum display time...")
                        return
                    }
                    let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
                    impactFeedback.impactOccurred()
                    onDismiss()
                }) {
                    HStack {
                        Text("Continue")
                            .font(.system(size: 18, weight: .semibold))
                        Image(systemName: "arrow.right.circle.fill")
                            .font(.system(size: 16))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(
                        LinearGradient(
                            gradient: Gradient(colors: [Color.blue, Color.purple]),
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .foregroundColor(.white)
                    .cornerRadius(14)
                    .shadow(color: Color.accentColor.opacity(0.3), radius: 8, x: 0, y: 4)
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 30)
                .opacity(textOpacity)
                .animation(
                    .easeIn(duration: 0.6)
                    .delay(1.3),
                    value: textOpacity
                )
            }
        }
        .onAppear {
            // Generate random sparkles
            for _ in 0..<12 {
                sparkles.append(Sparkle(
                    xPosition: CGFloat.random(in: 50...350),
                    yPosition: CGFloat.random(in: 100...700),
                    size: CGFloat.random(in: 12...24),
                    delay: Double.random(in: 0...0.5),
                    color: [Color.yellow, Color.blue, Color.purple, Color.green].randomElement()!
                ))
            }
            
            // Trigger animations
            withAnimation {
                showConfetti = true
                successScale = 1.0
                successRotation = 0
                textOpacity = 1.0
            }
            
            // Haptic feedback
            let notificationFeedback = UINotificationFeedbackGenerator()
            notificationFeedback.notificationOccurred(.success)
            
            // Enable dismiss after minimum display time (2 seconds)
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                canDismiss = true
                print("✅ Completion view can now be dismissed")
            }
        }
    }
}