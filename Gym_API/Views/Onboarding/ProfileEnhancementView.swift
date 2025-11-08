//
//  ProfileEnhancementView.swift
//  Gym_API
//
//  Created by Claude Code on 2025-10-26
//
//  Post-authentication OPTIONAL profile enhancement
//  Only asks for fitness preferences, NOT basic info (comes from Auth0)

import SwiftUI

struct ProfileEnhancementView: View {
    @EnvironmentObject var themeManager: ThemeManager
    @EnvironmentObject var onboardingManager: OnboardingManager
    @State private var currentStepIndex = 0
    @State private var showContent = false
    @State private var isSaving = false
    @State private var saveError: String?

    private let enhancementSteps = ProfileEnhancementStep.allCases

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
                progressSection

                // Current step content
                TabView(selection: $currentStepIndex) {
                    ForEach(Array(enhancementSteps.enumerated()), id: \.offset) { index, step in
                        ProfileEnhancementStepView(
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

                // Error message
                if let error = saveError {
                    Text(error)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.red)
                        .padding(.horizontal, 32)
                        .multilineTextAlignment(.center)
                }

                // Navigation buttons
                navigationSection
            }
        }
        .onAppear {
            startInitialAnimation()
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
                    onboardingManager.skipProfileEnhancement()
                }
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(Color.dynamicAccent(theme: themeManager.currentTheme))
            }
            .padding(.horizontal, 24)
            .padding(.top, 20)
            .opacity(showContent ? 1.0 : 0.0)
            .animation(.easeOut(duration: 0.6).delay(0.2), value: showContent)

            VStack(spacing: 12) {
                Text("Enhance Your Profile")
                    .font(.system(size: 32, weight: .bold))
                    .foregroundColor(Color.dynamicText(theme: themeManager.currentTheme))
                    .multilineTextAlignment(.center)
                    .opacity(showContent ? 1.0 : 0.0)
                    .scaleEffect(showContent ? 1.0 : 0.8)

                Text("Help us recommend the best workouts for you")
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

    private var progressSection: some View {
        VStack(spacing: 16) {
            // Step indicators
            HStack(spacing: 8) {
                ForEach(0..<enhancementSteps.count, id: \.self) { index in
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
            Text(enhancementSteps[currentStepIndex].title)
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
                if currentStepIndex < enhancementSteps.count - 1 {
                    withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                        currentStepIndex += 1
                    }
                } else {
                    completeProfileEnhancement()
                }
            }) {
                HStack(spacing: 12) {
                    if isSaving {
                        ProgressView()
                            .tint(.white)
                    } else {
                        Text(currentStepIndex < enhancementSteps.count - 1 ? "Continue" : "Save & Continue")
                            .font(.system(size: 18, weight: .semibold))

                        Image(systemName: currentStepIndex < enhancementSteps.count - 1 ? "arrow.right" : "checkmark")
                            .font(.system(size: 16, weight: .semibold))
                    }
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
            .disabled(!isCurrentStepValid() || isSaving)
            .scaleEffect(showContent ? 1.0 : 0.8)
            .opacity(showContent ? 1.0 : 0.0)
            .animation(.spring(response: 0.6, dampingFraction: 0.8).delay(1.0), value: showContent)
            .padding(.horizontal, 32)

            // Progress text
            Text("Step \(currentStepIndex + 1) of \(enhancementSteps.count)")
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
        let currentStep = enhancementSteps[currentStepIndex]

        switch currentStep {
        case .fitnessLevel:
            return true // Always valid since it has a default
        case .goals:
            return !onboardingManager.userProfile.goals.isEmpty
        case .workoutTypes:
            return !onboardingManager.userProfile.preferredWorkoutTypes.isEmpty
        }
    }

    private func completeProfileEnhancement() {
        guard !isSaving else { return }

        isSaving = true
        saveError = nil

        Task {
            do {
                // Send profile data to backend
                try await saveProfileDataToBackend()

                await MainActor.run {
                    print("✅ Profile enhancement completed and saved")
                    isSaving = false

                    // Proceed to next onboarding step
                    onboardingManager.nextStep()
                }
            } catch {
                await MainActor.run {
                    saveError = "Failed to save profile: \(error.localizedDescription)"
                    isSaving = false
                    print("❌ Error saving profile: \(error)")
                }
            }
        }
    }

    private func saveProfileDataToBackend() async throws {
        // TODO: Implement actual API call to POST /api/v1/users/profile/data
        // For now, just simulate a delay
        print("📤 Saving profile data to backend...")
        print("   Fitness Level: \(onboardingManager.userProfile.fitnessLevel.rawValue)")
        print("   Goals: \(onboardingManager.userProfile.goals.map { $0.rawValue })")
        print("   Workout Types: \(onboardingManager.userProfile.preferredWorkoutTypes.map { $0.rawValue })")

        try await Task.sleep(nanoseconds: 1_000_000_000) // 1 second delay

        // In production, this would be:
        // let endpoint = "\(apiBaseURL)/users/profile/data"
        // Make POST request with profile data
        // Handle response
    }
}

// MARK: - Profile Enhancement Steps (NO basicInfo - that comes from Auth0)

enum ProfileEnhancementStep: CaseIterable {
    case fitnessLevel
    case goals
    case workoutTypes

    var title: String {
        switch self {
        case .fitnessLevel: return "Fitness Level"
        case .goals: return "Your Goals"
        case .workoutTypes: return "Workout Preferences"
        }
    }

    var subtitle: String {
        switch self {
        case .fitnessLevel: return "What's your current fitness level?"
        case .goals: return "What do you want to achieve?"
        case .workoutTypes: return "What types of workouts do you enjoy?"
        }
    }

    var icon: String {
        switch self {
        case .fitnessLevel: return "figure.walk"
        case .goals: return "target"
        case .workoutTypes: return "heart.fill"
        }
    }
}

// MARK: - Profile Enhancement Step View

struct ProfileEnhancementStepView: View {
    let step: ProfileEnhancementStep
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

#Preview {
    ProfileEnhancementView()
        .environmentObject(ThemeManager())
        .environmentObject(OnboardingManager())
}
