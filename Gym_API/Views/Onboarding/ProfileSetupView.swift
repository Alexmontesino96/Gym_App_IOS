//
//  ProfileSetupView.swift
//  Gym_API
//
//  Created by Assistant on 8/3/25.
//
//  Vista multi-step para configuración del perfil de usuario nuevo con validación en tiempo real

import SwiftUI

struct ProfileSetupView: View {
    @EnvironmentObject var themeManager: ThemeManager
    @EnvironmentObject var onboardingManager: OnboardingManager
    @State private var currentStepIndex = 0
    @State private var showContent = false
    @State private var keyboardHeight: CGFloat = 0
    
    private let setupSteps = ProfileSetupStep.allCases
    
    var body: some View {
        ZStack {
            // Dynamic background
            LinearGradient(
                gradient: Gradient(colors: [
                    Color.dynamicBackground(theme: themeManager.currentTheme),
                    Color.dynamicAccent(theme: themeManager.currentTheme).opacity(0.05)
                ]),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Header section
                headerSection
                
                // Progress indicator
                profileProgressSection
                
                // Current step content
                TabView(selection: $currentStepIndex) {
                    ForEach(Array(setupSteps.enumerated()), id: \.offset) { index, step in
                        ProfileStepView(
                            step: step,
                            isActive: index == currentStepIndex
                        )
                        .tag(index)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .opacity(showContent ? 1.0 : 0.0)
                .scaleEffect(showContent ? 1.0 : 0.9)
                .animation(.easeOut(duration: 0.8).delay(0.3), value: showContent)
                
                // Navigation buttons
                navigationSection
            }
            .padding(.bottom, keyboardHeight > 0 ? keyboardHeight - 30 : 0)
            .animation(.easeInOut(duration: 0.3), value: keyboardHeight)
        }
        .onAppear {
            startInitialAnimation()
            setupKeyboardObservers()
        }
        .onDisappear {
            removeKeyboardObservers()
        }
    }
    
    // MARK: - Header Section
    
    private var headerSection: some View {
        VStack(spacing: 20) {
            HStack {
                Button(action: {
                    if currentStepIndex > 0 {
                        withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                            currentStepIndex -= 1
                        }
                    } else {
                        onboardingManager.previousStep()
                    }
                }) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 18, weight: .medium))
                        .foregroundColor(Color.dynamicText(theme: themeManager.currentTheme))
                        .frame(width: 32, height: 32)
                        .background(
                            Circle()
                                .fill(Color.dynamicSurface(theme: themeManager.currentTheme))
                                .shadow(color: .black.opacity(0.1), radius: 5, x: 0, y: 2)
                        )
                }
                
                Spacer()
                
                Button("Skip") {
                    onboardingManager.nextStep()
                }
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(Color.dynamicTextSecondary(theme: themeManager.currentTheme))
            }
            .padding(.horizontal, 24)
            .padding(.top, 20)
            .opacity(showContent ? 1.0 : 0.0)
            .animation(.easeOut(duration: 0.6).delay(0.2), value: showContent)
            
            VStack(spacing: 12) {
                Text("Set Up Your Profile")
                    .font(.system(size: 32, weight: .bold))
                    .foregroundColor(Color.dynamicText(theme: themeManager.currentTheme))
                    .multilineTextAlignment(.center)
                    .opacity(showContent ? 1.0 : 0.0)
                    .scaleEffect(showContent ? 1.0 : 0.8)
                
                Text("Tell us a bit about yourself to personalize your experience")
                    .font(.system(size: 17, weight: .medium))
                    .foregroundColor(Color.dynamicTextSecondary(theme: themeManager.currentTheme))
                    .multilineTextAlignment(.center)
                    .opacity(showContent ? 1.0 : 0.0)
                    .offset(y: showContent ? 0 : 20)
            }
            .padding(.horizontal, 32)
            .animation(.easeOut(duration: 0.8).delay(0.4), value: showContent)
        }
    }
    
    // MARK: - Progress Section
    
    private var profileProgressSection: some View {
        VStack(spacing: 16) {
            // Step indicators
            HStack(spacing: 8) {
                ForEach(0..<setupSteps.count, id: \.self) { index in
                    Circle()
                        .fill(
                            index <= currentStepIndex
                                ? Color.dynamicAccent(theme: themeManager.currentTheme)
                                : Color.dynamicTextSecondary(theme: themeManager.currentTheme).opacity(0.3)
                        )
                        .frame(width: index == currentStepIndex ? 12 : 8, height: index == currentStepIndex ? 12 : 8)
                        .animation(.spring(response: 0.6, dampingFraction: 0.8), value: currentStepIndex)
                }
            }
            .opacity(showContent ? 1.0 : 0.0)
            .animation(.easeOut(duration: 0.6).delay(0.6), value: showContent)
            
            // Current step info
            Text(setupSteps[currentStepIndex].title)
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(Color.dynamicAccent(theme: themeManager.currentTheme))
                .opacity(showContent ? 1.0 : 0.0)
                .animation(.easeOut(duration: 0.6).delay(0.8), value: showContent)
        }
        .padding(.vertical, 20)
    }
    
    // MARK: - Navigation Section
    
    private var navigationSection: some View {
        VStack(spacing: 16) {
            Button(action: {
                if currentStepIndex < setupSteps.count - 1 {
                    withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                        currentStepIndex += 1
                    }
                } else {
                    completeProfileSetup()
                }
            }) {
                HStack(spacing: 12) {
                    Text(currentStepIndex < setupSteps.count - 1 ? "Continue" : "Complete Setup")
                        .font(.system(size: 18, weight: .semibold))
                    
                    Image(systemName: currentStepIndex < setupSteps.count - 1 ? "arrow.right" : "checkmark")
                        .font(.system(size: 16, weight: .semibold))
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 56)
                .background(
                    RoundedRectangle(cornerRadius: 28)
                        .fill(
                            isCurrentStepValid()
                                ? Color.dynamicAccent(theme: themeManager.currentTheme)
                                : Color.dynamicTextSecondary(theme: themeManager.currentTheme)
                        )
                        .shadow(
                            color: isCurrentStepValid()
                                ? Color.dynamicAccent(theme: themeManager.currentTheme).opacity(0.3)
                                : Color.clear,
                            radius: 20, x: 0, y: 10
                        )
                )
            }
            .disabled(!isCurrentStepValid())
            .scaleEffect(showContent ? 1.0 : 0.8)
            .opacity(showContent ? 1.0 : 0.0)
            .animation(.spring(response: 0.6, dampingFraction: 0.8).delay(1.0), value: showContent)
            .padding(.horizontal, 32)
            
            // Progress text
            Text("Step \(currentStepIndex + 1) of \(setupSteps.count)")
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(Color.dynamicTextSecondary(theme: themeManager.currentTheme))
                .opacity(showContent ? 0.7 : 0.0)
                .animation(.easeOut(duration: 0.6).delay(1.2), value: showContent)
        }
        .padding(.bottom, 40)
    }
    
    // MARK: - Helper Methods
    
    private func startInitialAnimation() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            withAnimation {
                showContent = true
            }
        }
    }
    
    private func isCurrentStepValid() -> Bool {
        let currentStep = setupSteps[currentStepIndex]
        
        switch currentStep {
        case .basicInfo:
            return !onboardingManager.userProfile.firstName.isEmpty && 
                   !onboardingManager.userProfile.lastName.isEmpty
        case .fitnessLevel:
            return true // Always valid since it has a default
        case .goals:
            return !onboardingManager.userProfile.goals.isEmpty
        case .workoutTypes:
            return !onboardingManager.userProfile.preferredWorkoutTypes.isEmpty
        }
    }
    
    private func completeProfileSetup() {
        // Save profile to OnboardingManager
        print("✅ Profile setup completed: \(onboardingManager.userProfile)")
        
        // Proceed to next onboarding step
        onboardingManager.nextStep()
    }
    
    // MARK: - Keyboard Handling
    
    private func setupKeyboardObservers() {
        NotificationCenter.default.addObserver(
            forName: UIResponder.keyboardWillShowNotification,
            object: nil,
            queue: .main
        ) { notification in
            if let keyboardFrame = notification.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect {
                keyboardHeight = keyboardFrame.height
            }
        }
        
        NotificationCenter.default.addObserver(
            forName: UIResponder.keyboardWillHideNotification,
            object: nil,
            queue: .main
        ) { _ in
            keyboardHeight = 0
        }
    }
    
    private func removeKeyboardObservers() {
        NotificationCenter.default.removeObserver(self, name: UIResponder.keyboardWillShowNotification, object: nil)
        NotificationCenter.default.removeObserver(self, name: UIResponder.keyboardWillHideNotification, object: nil)
    }
}

// MARK: - Profile Setup Steps

enum ProfileSetupStep: CaseIterable {
    case basicInfo
    case fitnessLevel
    case goals
    case workoutTypes
    
    var title: String {
        switch self {
        case .basicInfo: return "Basic Information"
        case .fitnessLevel: return "Fitness Level"
        case .goals: return "Your Goals"
        case .workoutTypes: return "Workout Preferences"
        }
    }
    
    var subtitle: String {
        switch self {
        case .basicInfo: return "What should we call you?"
        case .fitnessLevel: return "What's your current fitness level?"
        case .goals: return "What do you want to achieve?"
        case .workoutTypes: return "What types of workouts do you enjoy?"
        }
    }
    
    var icon: String {
        switch self {
        case .basicInfo: return "person.circle.fill"
        case .fitnessLevel: return "figure.walk"
        case .goals: return "target"
        case .workoutTypes: return "heart.fill"
        }
    }
}

// MARK: - Profile Step View

struct ProfileStepView: View {
    let step: ProfileSetupStep
    let isActive: Bool
    @EnvironmentObject var themeManager: ThemeManager
    @EnvironmentObject var onboardingManager: OnboardingManager
    @State private var showContent = false
    
    var body: some View {
        ScrollView {
            VStack(spacing: 30) {
                // Step icon and title
                stepHeaderSection
                
                // Step-specific content
                stepContentSection
                
                Spacer(minLength: 100)
            }
            .padding(.horizontal, 32)
            .padding(.top, 20)
        }
        .onAppear {
            if isActive {
                startContentAnimation()
            }
        }
        .onChange(of: isActive) { active in
            if active {
                startContentAnimation()
            } else {
                hideContent()
            }
        }
    }
    
    private var stepHeaderSection: some View {
        VStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(Color.dynamicAccent(theme: themeManager.currentTheme).opacity(0.15))
                    .frame(width: 80, height: 80)
                
                Image(systemName: step.icon)
                    .font(.system(size: 32, weight: .medium))
                    .foregroundColor(Color.dynamicAccent(theme: themeManager.currentTheme))
            }
            .scaleEffect(showContent ? 1.0 : 0.5)
            .opacity(showContent ? 1.0 : 0.0)
            .animation(.spring(response: 0.8, dampingFraction: 0.6).delay(0.2), value: showContent)
            
            VStack(spacing: 8) {
                Text(step.title)
                    .font(.system(size: 24, weight: .bold))
                    .foregroundColor(Color.dynamicText(theme: themeManager.currentTheme))
                    .multilineTextAlignment(.center)
                
                Text(step.subtitle)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(Color.dynamicTextSecondary(theme: themeManager.currentTheme))
                    .multilineTextAlignment(.center)
            }
            .opacity(showContent ? 1.0 : 0.0)
            .offset(y: showContent ? 0 : 20)
            .animation(.easeOut(duration: 0.6).delay(0.4), value: showContent)
        }
    }
    
    @ViewBuilder
    private var stepContentSection: some View {
        switch step {
        case .basicInfo:
            BasicInfoStepView()
        case .fitnessLevel:
            FitnessLevelStepView()
        case .goals:
            GoalsStepView()
        case .workoutTypes:
            WorkoutTypesStepView()
        }
    }
    
    private func startContentAnimation() {
        withAnimation {
            showContent = true
        }
    }
    
    private func hideContent() {
        withAnimation(.easeInOut(duration: 0.3)) {
            showContent = false
        }
    }
}

// MARK: - Individual Step Views

struct BasicInfoStepView: View {
    @EnvironmentObject var onboardingManager: OnboardingManager
    @EnvironmentObject var themeManager: ThemeManager
    @FocusState private var firstNameFocused: Bool
    @FocusState private var lastNameFocused: Bool
    
    var body: some View {
        VStack(spacing: 20) {
            VStack(spacing: 16) {
                OnboardingTextField(
                    title: "First Name",
                    text: $onboardingManager.userProfile.firstName,
                    placeholder: "John"
                )
                .focused($firstNameFocused)
                
                OnboardingTextField(
                    title: "Last Name",
                    text: $onboardingManager.userProfile.lastName,
                    placeholder: "Doe"
                )
                .focused($lastNameFocused)
            }
            
            // Validation feedback
            if !onboardingManager.userProfile.firstName.isEmpty && !onboardingManager.userProfile.lastName.isEmpty {
                HStack(spacing: 8) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                    
                    Text("Great! Nice to meet you, \(onboardingManager.userProfile.fullName)")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.green)
                }
                .transition(.scale.combined(with: .opacity))
            }
        }
    }
}

struct FitnessLevelStepView: View {
    @EnvironmentObject var onboardingManager: OnboardingManager
    @EnvironmentObject var themeManager: ThemeManager
    
    var body: some View {
        VStack(spacing: 16) {
            ForEach(OnboardingUserProfile.FitnessLevel.allCases, id: \.self) { level in
                Button(action: {
                    onboardingManager.userProfile.fitnessLevel = level
                }) {
                    HStack(spacing: 16) {
                        Image(systemName: level.icon)
                            .font(.system(size: 24, weight: .medium))
                            .foregroundColor(Color.dynamicAccent(theme: themeManager.currentTheme))
                            .frame(width: 40)
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text(level.rawValue)
                                .font(.system(size: 18, weight: .semibold))
                                .foregroundColor(Color.dynamicText(theme: themeManager.currentTheme))
                                .frame(maxWidth: .infinity, alignment: .leading)
                            
                            Text(level.description)
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(Color.dynamicTextSecondary(theme: themeManager.currentTheme))
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        
                        if onboardingManager.userProfile.fitnessLevel == level {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 20))
                                .foregroundColor(.green)
                        }
                    }
                    .padding(20)
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(Color.dynamicSurface(theme: themeManager.currentTheme))
                            .overlay(
                                RoundedRectangle(cornerRadius: 16)
                                    .stroke(
                                        onboardingManager.userProfile.fitnessLevel == level
                                            ? Color.dynamicAccent(theme: themeManager.currentTheme)
                                            : Color.clear,
                                        lineWidth: 2
                                    )
                            )
                    )
                }
                .scaleEffect(onboardingManager.userProfile.fitnessLevel == level ? 1.02 : 1.0)
                .animation(.spring(response: 0.4, dampingFraction: 0.8), value: onboardingManager.userProfile.fitnessLevel)
            }
        }
    }
}

struct GoalsStepView: View {
    @EnvironmentObject var onboardingManager: OnboardingManager
    @EnvironmentObject var themeManager: ThemeManager
    
    var body: some View {
        VStack(spacing: 16) {
            Text("Select all that apply")
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(Color.dynamicTextSecondary(theme: themeManager.currentTheme))
            
            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 12) {
                ForEach(OnboardingUserProfile.FitnessGoal.allCases, id: \.self) { goal in
                    Button(action: {
                        if onboardingManager.userProfile.goals.contains(goal) {
                            onboardingManager.userProfile.goals.remove(goal)
                        } else {
                            onboardingManager.userProfile.goals.insert(goal)
                        }
                    }) {
                        VStack(spacing: 8) {
                            Image(systemName: goal.icon)
                                .font(.system(size: 24, weight: .medium))
                                .foregroundColor(
                                    onboardingManager.userProfile.goals.contains(goal)
                                        ? .white
                                        : Color.dynamicAccent(theme: themeManager.currentTheme)
                                )
                            
                            Text(goal.rawValue)
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundColor(
                                    onboardingManager.userProfile.goals.contains(goal)
                                        ? .white
                                        : Color.dynamicText(theme: themeManager.currentTheme)
                                )
                                .multilineTextAlignment(.center)
                        }
                        .padding(16)
                        .frame(height: 80)
                        .frame(maxWidth: .infinity)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(
                                    onboardingManager.userProfile.goals.contains(goal)
                                        ? Color.dynamicAccent(theme: themeManager.currentTheme)
                                        : Color.dynamicSurface(theme: themeManager.currentTheme)
                                )
                        )
                    }
                    .scaleEffect(onboardingManager.userProfile.goals.contains(goal) ? 1.05 : 1.0)
                    .animation(.spring(response: 0.4, dampingFraction: 0.8), value: onboardingManager.userProfile.goals)
                }
            }
        }
    }
}

struct WorkoutTypesStepView: View {
    @EnvironmentObject var onboardingManager: OnboardingManager
    @EnvironmentObject var themeManager: ThemeManager
    
    var body: some View {
        VStack(spacing: 16) {
            Text("Choose your preferred workout types")
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(Color.dynamicTextSecondary(theme: themeManager.currentTheme))
            
            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 12) {
                ForEach(OnboardingUserProfile.WorkoutType.allCases, id: \.self) { type in
                    Button(action: {
                        if onboardingManager.userProfile.preferredWorkoutTypes.contains(type) {
                            onboardingManager.userProfile.preferredWorkoutTypes.remove(type)
                        } else {
                            onboardingManager.userProfile.preferredWorkoutTypes.insert(type)
                        }
                    }) {
                        VStack(spacing: 8) {
                            Image(systemName: type.icon)
                                .font(.system(size: 24, weight: .medium))
                                .foregroundColor(
                                    onboardingManager.userProfile.preferredWorkoutTypes.contains(type)
                                        ? .white
                                        : Color.dynamicAccent(theme: themeManager.currentTheme)
                                )
                            
                            Text(type.rawValue)
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundColor(
                                    onboardingManager.userProfile.preferredWorkoutTypes.contains(type)
                                        ? .white
                                        : Color.dynamicText(theme: themeManager.currentTheme)
                                )
                                .multilineTextAlignment(.center)
                        }
                        .padding(12)
                        .frame(height: 70)
                        .frame(maxWidth: .infinity)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(
                                    onboardingManager.userProfile.preferredWorkoutTypes.contains(type)
                                        ? Color.dynamicAccent(theme: themeManager.currentTheme)
                                        : Color.dynamicSurface(theme: themeManager.currentTheme)
                                )
                        )
                    }
                    .scaleEffect(onboardingManager.userProfile.preferredWorkoutTypes.contains(type) ? 1.05 : 1.0)
                    .animation(.spring(response: 0.4, dampingFraction: 0.8), value: onboardingManager.userProfile.preferredWorkoutTypes)
                }
            }
        }
    }
}

// MARK: - Onboarding Text Field

struct OnboardingTextField: View {
    let title: String
    @Binding var text: String
    let placeholder: String
    @EnvironmentObject var themeManager: ThemeManager
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(Color.dynamicText(theme: themeManager.currentTheme))
            
            TextField(placeholder, text: $text)
                .font(.system(size: 18, weight: .medium))
                .foregroundColor(Color.dynamicText(theme: themeManager.currentTheme))
                .padding(16)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.dynamicSurface(theme: themeManager.currentTheme))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(
                                    text.isEmpty
                                        ? Color.dynamicTextSecondary(theme: themeManager.currentTheme).opacity(0.3)
                                        : Color.dynamicAccent(theme: themeManager.currentTheme),
                                    lineWidth: 2
                                )
                        )
                )
                .autocorrectionDisabled()
        }
    }
}

#Preview {
    ProfileSetupView()
        .environmentObject(ThemeManager())
        .environmentObject(OnboardingManager())
}