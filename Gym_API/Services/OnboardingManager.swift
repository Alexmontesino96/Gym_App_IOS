//
//  OnboardingManager.swift
//  Gym_API
//
//  Created by Assistant on 8/3/25.
//
//  Gestión centralizada del flujo de onboarding renovado
//  Maneja el estado, progreso y navegación del onboarding

import Foundation
import SwiftUI

/// Manager centralizado para gestionar el flujo de onboarding
@MainActor
class OnboardingManager: ObservableObject {
    
    // MARK: - Published Properties
    
    @Published var currentFlow: OnboardingFlow = .splash
    @Published var isFirstLaunch: Bool = true
    @Published var userType: UserType?
    @Published var completedSteps: Set<OnboardingStep> = []
    @Published var currentBenefitIndex: Int = 0
    @Published var userProfile: OnboardingUserProfile = OnboardingUserProfile()
    @Published var showOnboarding: Bool = false
    
    // MARK: - Enums
    
    enum OnboardingFlow: String, CaseIterable, Codable {
        case splash
        case benefits
        case authGate
        case welcomeAuthenticated
        case profileEnhancement
        case permissions
        case complete

        var title: String {
            switch self {
            case .splash: return "Welcome"
            case .benefits: return "Benefits"
            case .authGate: return "Authentication"
            case .welcomeAuthenticated: return "Welcome"
            case .profileEnhancement: return "Profile Enhancement"
            case .permissions: return "Permissions"
            case .complete: return "Complete"
            }
        }
        
        var progressPercentage: Double {
            let totalSteps = Double(OnboardingFlow.allCases.count - 1) // Exclude complete
            let currentIndex = Double(OnboardingFlow.allCases.firstIndex(of: self) ?? 0)
            return currentIndex / totalSteps
        }
    }
    
    enum UserType: String, Codable {
        case newUser
        case existingUser

        var displayName: String {
            switch self {
            case .newUser: return "Create Account"
            case .existingUser: return "Sign In"
            }
        }
        
        var subtitle: String {
            switch self {
            case .newUser: return "Start fresh"
            case .existingUser: return "Welcome back"
            }
        }
        
        var icon: String {
            switch self {
            case .newUser: return "person.badge.plus"
            case .existingUser: return "person.badge.key"
            }
        }
    }
    
    enum OnboardingStep: String, CaseIterable, Codable {
        case splashViewed = "splash_viewed"
        case benefitsViewed = "benefits_viewed"
        case userTypeSelected = "user_type_selected"
        case profileSetupCompleted = "profile_setup_completed"
        case permissionsRequested = "permissions_requested"
        
        var displayName: String {
            switch self {
            case .splashViewed: return "Splash Screen"
            case .benefitsViewed: return "Benefits Overview"
            case .userTypeSelected: return "User Type Selection"
            case .profileSetupCompleted: return "Profile Setup"
            case .permissionsRequested: return "Permissions Setup"
            }
        }
    }
    
    // MARK: - Benefits Data
    
    let benefits: [OnboardingBenefit] = [
        OnboardingBenefit(
            title: "Access Multiple Gyms",
            subtitle: "One membership, unlimited locations",
            description: "Train at any partner gym in your area with a single membership",
            icon: "building.2.crop.circle.fill",
            accentColor: .red
        ),
        OnboardingBenefit(
            title: "Connect with Your Tribe",
            subtitle: "Real-time chat with trainers and members",
            description: "Get instant support, share progress, and stay motivated together",
            icon: "message.circle.fill",
            accentColor: .blue
        ),
        OnboardingBenefit(
            title: "Never Miss a Class",
            subtitle: "Smart notifications and easy booking",
            description: "Book classes, get reminders, and track your fitness journey",
            icon: "calendar.badge.clock",
            accentColor: .green
        ),
        OnboardingBenefit(
            title: "Track Your Progress",
            subtitle: "Comprehensive fitness analytics",
            description: "Monitor your workouts, goals, and achievements in one place",
            icon: "chart.line.uptrend.xyaxis.circle.fill",
            accentColor: .purple
        ),
        OnboardingBenefit(
            title: "Professional Support",
            subtitle: "Certified trainers at your fingertips",
            description: "Get personalized advice and professional training programs",
            icon: "person.crop.circle.fill.badge.checkmark",
            accentColor: .orange
        )
    ]
    
    // MARK: - Initialization
    
    init() {
        checkOnboardingStatus()
    }
    
    // MARK: - Public Methods
    
    /// Verifica si el usuario necesita ver el onboarding
    func checkOnboardingStatus() {
        isFirstLaunch = !UserDefaults.standard.hasCompletedOnboarding
        loadCompletedSteps()

        if isFirstLaunch {
            // Intentar restaurar estado guardado
            restoreState()

            // Si no hay estado guardado o es el primer paso, empezar desde splash
            if currentFlow == .complete || currentFlow == .splash {
                showOnboarding = true
                currentFlow = .splash
            } else {
                // Continuar desde donde se quedó
                showOnboarding = true
            }
        } else {
            showOnboarding = false
            currentFlow = .complete
        }

        print("🎯 OnboardingManager: isFirstLaunch = \(isFirstLaunch)")
        print("🎯 OnboardingManager: completedSteps = \(completedSteps)")
        print("🎯 OnboardingManager: currentFlow = \(currentFlow.title)")
    }
    
    /// Avanza al siguiente paso del onboarding
    func nextStep() {
        withAnimation(.easeInOut(duration: 0.4)) {
            switch currentFlow {
            case .splash:
                markStepCompleted(.splashViewed)
                currentFlow = .benefits

            case .benefits:
                markStepCompleted(.benefitsViewed)
                currentFlow = .authGate

            case .authGate:
                // Auth handled by AuthGateView, this shouldn't be called
                break

            case .welcomeAuthenticated:
                // User can choose to enhance profile or skip
                currentFlow = .profileEnhancement

            case .profileEnhancement:
                markStepCompleted(.profileSetupCompleted)
                currentFlow = .permissions

            case .permissions:
                markStepCompleted(.permissionsRequested)
                completeOnboarding()

            case .complete:
                break
            }

            saveCurrentState()
        }
    }
    
    /// Retrocede al paso anterior
    func previousStep() {
        withAnimation(.easeInOut(duration: 0.4)) {
            switch currentFlow {
            case .splash:
                break

            case .benefits:
                currentFlow = .splash

            case .authGate:
                currentFlow = .benefits

            case .welcomeAuthenticated:
                // Can't go back after auth
                break

            case .profileEnhancement:
                currentFlow = .welcomeAuthenticated

            case .permissions:
                currentFlow = .profileEnhancement

            case .complete:
                break
            }

            saveCurrentState()
        }
    }
    
    /// Omite el onboarding y va directo al login
    func skipOnboarding() {
        markStepCompleted(.splashViewed)
        markStepCompleted(.benefitsViewed)
        completeOnboarding()
    }
    
    /// Selecciona el tipo de usuario
    func selectUserType(_ type: UserType) {
        userType = type
        print("🎯 OnboardingManager: Usuario seleccionó tipo: \(type)")

        // Track analytics
        trackAnalyticsEvent("user_type_selected", parameters: [
            "user_type": type == .newUser ? "new" : "existing"
        ])

        nextStep()
    }

    /// Maneja autenticación exitosa de Auth0
    func handleAuthenticationSuccess(user: AuthUser) {
        print("🎯 OnboardingManager: Autenticación exitosa para \(user.email)")

        // Guardar datos de Auth0 en perfil de onboarding
        if !user.name.isEmpty {
            let components = user.name.components(separatedBy: " ")
            userProfile.firstName = components.first ?? ""
            userProfile.lastName = components.dropFirst().joined(separator: " ")
        }
        userProfile.email = user.email

        // Marcar paso de auth como completado
        markStepCompleted(.userTypeSelected)

        // Avanzar a welcome
        withAnimation(.easeInOut(duration: 0.4)) {
            currentFlow = .welcomeAuthenticated
        }

        saveCurrentState()
    }

    /// Omite el profile enhancement y va a permissions
    func skipProfileEnhancement() {
        print("🎯 OnboardingManager: Usuario omitió profile enhancement")

        withAnimation(.easeInOut(duration: 0.4)) {
            currentFlow = .permissions
        }

        saveCurrentState()
    }
    
    /// Completa el onboarding y guarda el estado
    func completeOnboarding() {
        UserDefaults.standard.hasCompletedOnboarding = true
        saveCompletedSteps()

        // Limpiar estado guardado ya que completó
        clearState()

        withAnimation(.easeInOut(duration: 0.5)) {
            showOnboarding = false
            currentFlow = .complete
        }

        // Track completion analytics
        trackAnalyticsEvent("onboarding_completed", parameters: [
            "user_type": userType == .newUser ? "new" : "existing",
            "completed_steps": completedSteps.count,
            "total_time": Date().timeIntervalSince1970 // Could track actual time
        ])

        print("✅ OnboardingManager: Onboarding completado")
    }
    
    /// Reinicia el onboarding (para testing)
    func resetOnboarding() {
        UserDefaults.standard.hasCompletedOnboarding = false
        UserDefaults.standard.onboardingCompletedSteps = []
        completedSteps.removeAll()
        userType = nil
        userProfile = OnboardingUserProfile()
        currentBenefitIndex = 0
        currentFlow = .splash
        showOnboarding = true
        isFirstLaunch = true
        
        print("🔄 OnboardingManager: Onboarding reiniciado")
    }
    
    // MARK: - Benefits Carousel
    
    /// Avanza al siguiente beneficio en el carousel
    func nextBenefit() {
        withAnimation(.easeInOut(duration: 0.6)) {
            currentBenefitIndex = (currentBenefitIndex + 1) % benefits.count
        }
    }
    
    /// Va a un beneficio específico
    func goToBenefit(_ index: Int) {
        guard index >= 0 && index < benefits.count else { return }
        withAnimation(.easeInOut(duration: 0.6)) {
            currentBenefitIndex = index
        }
    }
    
    var currentBenefit: OnboardingBenefit {
        return benefits[currentBenefitIndex]
    }
    
    // MARK: - Private Methods
    
    private func markStepCompleted(_ step: OnboardingStep) {
        completedSteps.insert(step)
        saveCompletedSteps()
        
        // Track analytics
        trackAnalyticsEvent("onboarding_step_completed", parameters: [
            "step": step.rawValue,
            "step_name": step.displayName
        ])
    }
    
    private func loadCompletedSteps() {
        let stepStrings = UserDefaults.standard.onboardingCompletedSteps
        completedSteps = Set(stepStrings.compactMap { OnboardingStep(rawValue: $0) })
    }
    
    private func saveCompletedSteps() {
        let stepStrings = completedSteps.map { $0.rawValue }
        UserDefaults.standard.onboardingCompletedSteps = stepStrings
    }
    
    private func trackAnalyticsEvent(_ event: String, parameters: [String: Any]) {
        // TODO: Implementar analytics real (Firebase, Mixpanel, etc.)
        print("📊 Analytics: \(event) - \(parameters)")
    }

    // MARK: - State Persistence

    private let stateKey = "onboarding_current_state_v2"

    /// Guarda el estado actual del onboarding
    func saveCurrentState() {
        let state = OnboardingState(
            currentFlow: currentFlow,
            userType: userType,
            userProfile: userProfile,
            completedSteps: Array(completedSteps),
            currentBenefitIndex: currentBenefitIndex
        )

        if let encoded = try? JSONEncoder().encode(state) {
            UserDefaults.standard.set(encoded, forKey: stateKey)
            print("💾 OnboardingManager: Estado guardado")
        }
    }

    /// Restaura el estado guardado del onboarding
    func restoreState() {
        guard let data = UserDefaults.standard.data(forKey: stateKey),
              let state = try? JSONDecoder().decode(OnboardingState.self, from: data) else {
            print("ℹ️ OnboardingManager: No hay estado guardado")
            return
        }

        currentFlow = state.currentFlow
        userType = state.userType
        userProfile = state.userProfile
        completedSteps = Set(state.completedSteps)
        currentBenefitIndex = state.currentBenefitIndex

        print("🔄 OnboardingManager: Estado restaurado - \(currentFlow.title)")
    }

    /// Limpia el estado guardado
    func clearState() {
        UserDefaults.standard.removeObject(forKey: stateKey)
        print("🗑️ OnboardingManager: Estado limpiado")
    }

    // MARK: - State Model

    private struct OnboardingState: Codable {
        let currentFlow: OnboardingFlow
        let userType: UserType?
        let userProfile: OnboardingUserProfile
        let completedSteps: [OnboardingStep]
        let currentBenefitIndex: Int
    }
}

// MARK: - Data Models

struct OnboardingBenefit: Identifiable {
    let id = UUID()
    let title: String
    let subtitle: String
    let description: String
    let icon: String
    let accentColor: Color
}

struct OnboardingUserProfile: Codable {
    var firstName: String = ""
    var lastName: String = ""
    var email: String = ""
    var fitnessLevel: FitnessLevel = .beginner
    var goals: Set<FitnessGoal> = []
    var preferredWorkoutTypes: Set<WorkoutType> = []

    enum FitnessLevel: String, CaseIterable, Codable {
        case beginner = "Beginner"
        case intermediate = "Intermediate"
        case advanced = "Advanced"
        
        var description: String {
            switch self {
            case .beginner: return "Just starting my fitness journey"
            case .intermediate: return "I workout regularly"
            case .advanced: return "I'm a fitness enthusiast"
            }
        }
        
        var icon: String {
            switch self {
            case .beginner: return "figure.walk"
            case .intermediate: return "figure.run"
            case .advanced: return "figure.walk"
            }
        }
    }
    
    enum FitnessGoal: String, CaseIterable, Codable, Hashable {
        case loseWeight = "Lose Weight"
        case buildMuscle = "Build Muscle"
        case improveEndurance = "Improve Endurance"
        case increaseFlexibility = "Increase Flexibility"
        case generalHealth = "General Health"
        case stressRelief = "Stress Relief"
        
        var icon: String {
            switch self {
            case .loseWeight: return "scale.3d"
            case .buildMuscle: return "dumbbell"
            case .improveEndurance: return "heart.fill"
            case .increaseFlexibility: return "figure.flexibility"
            case .generalHealth: return "heart.text.square"
            case .stressRelief: return "leaf.fill"
            }
        }
    }
    
    enum WorkoutType: String, CaseIterable, Codable, Hashable {
        case weightLifting = "Weight Lifting"
        case cardio = "Cardio"
        case yoga = "Yoga"
        case pilates = "Pilates"
        case crossfit = "CrossFit"
        case swimming = "Swimming"
        case running = "Running"
        case cycling = "Cycling"
        
        var icon: String {
            switch self {
            case .weightLifting: return "dumbbell.fill"
            case .cardio: return "heart.fill"
            case .yoga: return "figure.yoga"
            case .pilates: return "figure.pilates"
            case .crossfit: return "figure.strengthtraining.functional"
            case .swimming: return "figure.pool.swim"
            case .running: return "figure.run"
            case .cycling: return "bicycle"
            }
        }
    }
    
    var isValid: Bool {
        return !firstName.isEmpty && !lastName.isEmpty
    }
    
    var fullName: String {
        return "\(firstName) \(lastName)".trimmingCharacters(in: .whitespaces)
    }
}

// MARK: - UserDefaults Extensions

extension UserDefaults {
    var hasCompletedOnboarding: Bool {
        get { bool(forKey: "hasCompletedOnboarding") }
        set { set(newValue, forKey: "hasCompletedOnboarding") }
    }
    
    var onboardingCompletedSteps: [String] {
        get { array(forKey: "onboardingCompletedSteps") as? [String] ?? [] }
        set { set(newValue, forKey: "onboardingCompletedSteps") }
    }
    
    var onboardingStartTime: Date? {
        get { object(forKey: "onboardingStartTime") as? Date }
        set { set(newValue, forKey: "onboardingStartTime") }
    }
}