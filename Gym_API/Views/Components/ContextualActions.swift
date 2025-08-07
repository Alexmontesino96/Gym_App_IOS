import SwiftUI
import CoreLocation

// MARK: - Main Contextual Actions Section

struct ContextualActionsSection: View {
    @ObservedObject var userStatsService: UserStatsService
    @ObservedObject var membershipService: MembershipService
    @ObservedObject var locationService: LocationService
    let themeManager: ThemeManager
    let authService: AuthServiceDirect
    
    @State private var contextualActions: [ContextualAction] = []
    @State private var isLoadingActions = true
    @State private var showingLocationAlert = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header
            HStack {
                Text("Quick Actions")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(Color.dynamicText(theme: themeManager.currentTheme))
                
                Spacer()
                
                if isLoadingActions {
                    ProgressView()
                        .scaleEffect(0.8)
                        .accessibilityLabel("Loading contextual actions")
                }
            }
            .padding(.horizontal, 4)
            
            // Actions content
            if contextualActions.isEmpty && !isLoadingActions {
                EmptyActionsState(themeManager: themeManager)
            } else {
                LazyVGrid(columns: [
                    GridItem(.flexible(), spacing: 12),
                    GridItem(.flexible(), spacing: 12)
                ], spacing: 12) {
                    ForEach(contextualActions, id: \.id) { action in
                        ContextualActionCard(
                            action: action,
                            themeManager: themeManager
                        ) {
                            performAction(action)
                        }
                        .frame(maxWidth: .infinity)
                    }
                }
                .padding(.horizontal, 4)
            }
        }
        .onAppear {
            generateContextualActions()
        }
        .onChange(of: locationService.currentLocationStatus) { _ in
            generateContextualActions()
        }
        .onChange(of: membershipService.membershipStatus) { _ in
            generateContextualActions()
        }
        .alert("Location Permission Required", isPresented: $showingLocationAlert) {
            Button("Settings") {
                openSettings()
            }
            Button("Not Now", role: .cancel) { }
        } message: {
            Text("Enable location access to see location-based quick actions like gym check-in and directions.")
        }
    }
}

// MARK: - Contextual Action Model

struct ContextualAction: Identifiable {
    let id = UUID()
    let title: String
    let subtitle: String
    let icon: String
    let color: Color
    let priority: ActionPriority
    let type: ActionType
    let action: () -> Void
    let isEnabled: Bool
    
    enum ActionPriority: Int, CaseIterable {
        case high = 3
        case medium = 2
        case low = 1
    }
    
    enum ActionType {
        case location
        case schedule
        case membership
        case social
        case workout
        case settings
    }
}

// MARK: - Action Card

struct ContextualActionCard: View {
    let action: ContextualAction
    let themeManager: ThemeManager
    let onTap: () -> Void
    
    @State private var isPressed = false
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    
    var body: some View {
        Button(action: {
            withAnimation(.easeInOut(duration: 0.1)) {
                isPressed = true
            }
            
            // Haptic feedback
            let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
            impactFeedback.impactOccurred()
            
            onTap()
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                withAnimation(.easeInOut(duration: 0.1)) {
                    isPressed = false
                }
            }
        }) {
            VStack(alignment: .leading, spacing: dynamicTypeSize.adjustedSpacing(8)) {
                HStack {
                    Image(systemName: action.icon)
                        .font(.cappedDynamicSystem(size: 18, weight: .semibold, maxSize: 24))
                        .foregroundColor(action.color)
                        .accessibilityHidden(true)
                    
                    Spacer()
                    
                    // Priority indicator
                    if action.priority == .high {
                        Circle()
                            .fill(action.color)
                            .frame(width: 6, height: 6)
                            .accessibilityHidden(true)
                    }
                }
                
                Text(action.title)
                    .font(.cappedDynamicSystem(size: 14, weight: .semibold, maxSize: 18))
                    .foregroundColor(Color.dynamicText(theme: themeManager.currentTheme))
                    .lineLimit(1)
                    .dynamicTypeSupport(maxLines: 1)
                
                Text(action.subtitle)
                    .font(.cappedDynamicSystem(size: 12, weight: .medium, maxSize: 16))
                    .foregroundColor(Color.dynamicTextSecondary(theme: themeManager.currentTheme))
                    .lineLimit(2)
                    .dynamicTypeSupport(maxLines: 2)
            }
            .padding(dynamicTypeSize.adjustedPadding(12))
            .frame(height: max(80 * dynamicTypeSize.scalingFactor, 80))
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.dynamicSurface(theme: themeManager.currentTheme))
                    .shadow(
                        color: Color.black.opacity(themeManager.currentTheme == .dark ? 0.3 : 0.1),
                        radius: isPressed ? 2 : 4,
                        x: 0,
                        y: isPressed ? 1 : 2
                    )
            )
            .scaleEffect(isPressed ? 0.95 : 1.0)
            .opacity(action.isEnabled ? 1.0 : 0.6)
        }
        .buttonStyle(PlainButtonStyle())
        .disabled(!action.isEnabled)
        .accessibilityLabel(action.title)
        .accessibilityHint(action.subtitle)
        .accessibilityAddTraits(.isButton)
        .accessibilityValue(action.priority == .high ? "High priority action" : "")
        .accessibleTouchTarget()
    }
}

// MARK: - Empty State

struct EmptyActionsState: View {
    let themeManager: ThemeManager
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    
    var body: some View {
        VStack(spacing: dynamicTypeSize.adjustedSpacing(16)) {
            Image(systemName: "sparkles")
                .font(.cappedDynamicSystem(size: 32, weight: .medium, maxSize: 42))
                .foregroundColor(Color.dynamicTextSecondary(theme: themeManager.currentTheme))
                .accessibilityHidden(true)
            
            VStack(spacing: dynamicTypeSize.adjustedSpacing(8)) {
                Text("No Quick Actions Available")
                    .font(.cappedDynamicSystem(size: 16, weight: .semibold, maxSize: 20))
                    .foregroundColor(Color.dynamicText(theme: themeManager.currentTheme))
                    .dynamicTypeSupport(maxLines: 1)
                
                Text("Actions will appear here based on your context, location, and gym activity.")
                    .font(.cappedDynamicSystem(size: 14, weight: .medium, maxSize: 18))
                    .foregroundColor(Color.dynamicTextSecondary(theme: themeManager.currentTheme))
                    .multilineTextAlignment(.center)
                    .lineLimit(3)
                    .dynamicTypeSupport(maxLines: 3)
            }
        }
        .padding(dynamicTypeSize.adjustedPadding(32))
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.dynamicSurface(theme: themeManager.currentTheme))
                .shadow(
                    color: Color.black.opacity(themeManager.currentTheme == .dark ? 0.2 : 0.08),
                    radius: 4,
                    x: 0,
                    y: 2
                )
        )
        .padding(.horizontal, 20)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("No quick actions available. Actions will appear here based on your context, location, and gym activity.")
    }
}

// MARK: - Action Generation Logic

extension ContextualActionsSection {
    private func generateContextualActions() {
        print("🎯 Generating contextual actions...")
        isLoadingActions = true
        
        Task {
            await MainActor.run {
                var actions: [ContextualAction] = []
                
                // Location-based actions
                actions.append(contentsOf: generateLocationActions())
                
                // Schedule-based actions  
                actions.append(contentsOf: generateScheduleActions())
                
                // Membership-based actions
                actions.append(contentsOf: generateMembershipActions())
                
                // Social actions
                actions.append(contentsOf: generateSocialActions())
                
                // Workout actions
                actions.append(contentsOf: generateWorkoutActions())
                
                // Settings actions
                actions.append(contentsOf: generateSettingsActions())
                
                // Sort by priority and limit to 6 actions
                let sortedActions = actions
                    .sorted { $0.priority.rawValue > $1.priority.rawValue }
                    .prefix(6)
                
                withAnimation(.easeInOut(duration: 0.3)) {
                    contextualActions = Array(sortedActions)
                    isLoadingActions = false
                }
                
                print("✅ Generated \(contextualActions.count) contextual actions")
            }
        }
    }
    
    private func generateLocationActions() -> [ContextualAction] {
        var actions: [ContextualAction] = []
        
        switch locationService.currentLocationStatus {
        case .nearGym:
            actions.append(ContextualAction(
                title: "Check-in Now",
                subtitle: "You're at the gym!",
                icon: "location.circle.fill",
                color: .green,
                priority: .high,
                type: .location,
                action: { performCheckin() },
                isEnabled: true
            ))
            
        case .farFromGym:
            let distanceKm = Int(locationService.distanceToGym / 1000)
            actions.append(ContextualAction(
                title: "Get Directions",
                subtitle: "\(distanceKm > 0 ? "\(distanceKm)km" : "\(Int(locationService.distanceToGym))m") to gym",
                icon: "map.fill",
                color: .blue,
                priority: .medium,
                type: .location,
                action: { openMaps() },
                isEnabled: true
            ))
            
        case .denied:
            actions.append(ContextualAction(
                title: "Enable Location",
                subtitle: "For location-based actions",
                icon: "location.slash",
                color: .orange,
                priority: .low,
                type: .settings,
                action: { showingLocationAlert = true },
                isEnabled: true
            ))
            
        default:
            break
        }
        
        return actions
    }
    
    private func generateScheduleActions() -> [ContextualAction] {
        var actions: [ContextualAction] = []
        
        let now = Date()
        let hour = Calendar.current.component(.hour, from: now)
        let dayOfWeek = Calendar.current.component(.weekday, from: now)
        
        // Morning actions (6-11 AM)
        if hour >= 6 && hour <= 11 {
            actions.append(ContextualAction(
                title: "Today's Classes",
                subtitle: "See what's available today",
                icon: "calendar.circle.fill",
                color: .orange,
                priority: .high,
                type: .schedule,
                action: { navigateToTodaysClasses() },
                isEnabled: true
            ))
        }
        
        // Afternoon actions (12-17 PM)
        if hour >= 12 && hour <= 17 {
            actions.append(ContextualAction(
                title: "Book Evening Class",
                subtitle: "Popular evening slots",
                icon: "clock.circle.fill",
                color: .purple,
                priority: .medium,
                type: .schedule,
                action: { navigateToEveningClasses() },
                isEnabled: true
            ))
        }
        
        // Evening actions (18-22 PM)
        if hour >= 18 && hour <= 22 {
            actions.append(ContextualAction(
                title: "Tomorrow's Schedule",
                subtitle: "Plan your workout",
                icon: "calendar.badge.clock",
                color: .indigo,
                priority: .medium,
                type: .schedule,
                action: { navigateToTomorrowClasses() },
                isEnabled: true
            ))
        }
        
        // Weekend specific actions
        if dayOfWeek == 1 || dayOfWeek == 7 { // Sunday or Saturday
            actions.append(ContextualAction(
                title: "Weekend Classes",
                subtitle: "Special weekend programs",
                icon: "calendar.badge.plus",
                color: .cyan,
                priority: .medium,
                type: .schedule,
                action: { navigateToWeekendClasses() },
                isEnabled: true
            ))
        }
        
        return actions
    }
    
    private func generateMembershipActions() -> [ContextualAction] {
        var actions: [ContextualAction] = []
        
        if let membership = membershipService.membershipStatus {
            if !membership.isActive {
                actions.append(ContextualAction(
                    title: "Activate Membership",
                    subtitle: "Get gym access now",
                    icon: "creditcard.circle.fill",
                    color: .red,
                    priority: .high,
                    type: .membership,
                    action: { navigateToMembershipPurchase() },
                    isEnabled: true
                ))
            } else if let daysRemaining = membership.daysRemaining, daysRemaining <= 7 {
                actions.append(ContextualAction(
                    title: "Renew Membership",
                    subtitle: "\(daysRemaining) days left",
                    icon: "arrow.clockwise.circle.fill",
                    color: .orange,
                    priority: .high,
                    type: .membership,
                    action: { navigateToMembershipRenewal() },
                    isEnabled: true
                ))
            } else if let daysRemaining = membership.daysRemaining, daysRemaining <= 30 {
                actions.append(ContextualAction(
                    title: "Membership Expires Soon",
                    subtitle: "\(daysRemaining) days remaining",
                    icon: "exclamationmark.circle.fill",
                    color: .yellow,
                    priority: .low,
                    type: .membership,
                    action: { navigateToMembershipDetails() },
                    isEnabled: true
                ))
            }
        } else {
            // No membership information available
            actions.append(ContextualAction(
                title: "Check Membership",
                subtitle: "View your membership status",
                icon: "person.badge.shield.checkmark",
                color: .blue,
                priority: .medium,
                type: .membership,
                action: { refreshMembershipStatus() },
                isEnabled: true
            ))
        }
        
        return actions
    }
    
    private func generateSocialActions() -> [ContextualAction] {
        var actions: [ContextualAction] = []
        
        // Mock: User analytics would determine these
        let hasTrainer = false // This would come from user profile
        let comesAloneFrequently = true // This would come from user analytics
        let hasUnreadMessages = false // This would come from chat service
        
        if hasTrainer {
            actions.append(ContextualAction(
                title: "Message Trainer",
                subtitle: "Ask about your program",
                icon: "message.badge.circle.fill",
                color: .green,
                priority: .medium,
                type: .social,
                action: { navigateToTrainerChat() },
                isEnabled: true
            ))
        }
        
        if comesAloneFrequently {
            actions.append(ContextualAction(
                title: "Find Workout Buddy",
                subtitle: "Connect with other members",
                icon: "person.2.circle.fill",
                color: .cyan,
                priority: .low,
                type: .social,
                action: { navigateToSocialFeatures() },
                isEnabled: true
            ))
        }
        
        if hasUnreadMessages {
            actions.append(ContextualAction(
                title: "Unread Messages",
                subtitle: "Check your conversations",
                icon: "message.badge.filled.fill",
                color: .red,
                priority: .high,
                type: .social,
                action: { navigateToMessages() },
                isEnabled: true
            ))
        }
        
        return actions
    }
    
    private func generateWorkoutActions() -> [ContextualAction] {
        var actions: [ContextualAction] = []
        
        // Mock: Would come from workout tracking
        let hasIncompleteWorkout = false
        let hasPersonalRecord = true
        let suggestedWorkout = true
        
        if hasIncompleteWorkout {
            actions.append(ContextualAction(
                title: "Continue Workout",
                subtitle: "Resume your session",
                icon: "play.circle.fill",
                color: .green,
                priority: .high,
                type: .workout,
                action: { continueWorkout() },
                isEnabled: true
            ))
        }
        
        if hasPersonalRecord {
            actions.append(ContextualAction(
                title: "Beat Your Record",
                subtitle: "Try to improve your best",
                icon: "trophy.circle.fill",
                color: .yellow,
                priority: .medium,
                type: .workout,
                action: { navigateToPersonalRecords() },
                isEnabled: true
            ))
        }
        
        if suggestedWorkout {
            actions.append(ContextualAction(
                title: "Suggested Workout",
                subtitle: "Based on your progress",
                icon: "lightbulb.circle.fill",
                color: .orange,
                priority: .low,
                type: .workout,
                action: { showSuggestedWorkout() },
                isEnabled: true
            ))
        }
        
        return actions
    }
    
    private func generateSettingsActions() -> [ContextualAction] {
        var actions: [ContextualAction] = []
        
        // Check if profile is incomplete
        let profileIncomplete = authService.user?.name.isEmpty == true
        
        if profileIncomplete {
            actions.append(ContextualAction(
                title: "Complete Profile",
                subtitle: "Add your information",
                icon: "person.badge.plus",
                color: .blue,
                priority: .medium,
                type: .settings,
                action: { navigateToProfileSetup() },
                isEnabled: true
            ))
        }
        
        return actions
    }
}

// MARK: - Action Handlers

extension ContextualActionsSection {
    private func performAction(_ action: ContextualAction) {
        print("🎯 Performing contextual action: \(action.title)")
        action.action()
    }
    
    // Location actions
    private func performCheckin() {
        print("📍 Performing gym check-in...")
        // TODO: Implement actual check-in logic
        let notification = UINotificationFeedbackGenerator()
        notification.notificationOccurred(.success)
    }
    
    private func openMaps() {
        print("🗺️ Opening maps to gym...")
        // TODO: Open Maps app with gym location
        if let url = URL(string: "maps://") {
            if UIApplication.shared.canOpenURL(url) {
                UIApplication.shared.open(url)
            }
        }
    }
    
    private func openSettings() {
        if let settingsUrl = URL(string: UIApplication.openSettingsURLString) {
            UIApplication.shared.open(settingsUrl)
        }
    }
    
    // Schedule actions
    private func navigateToTodaysClasses() {
        print("📅 Navigating to today's classes...")
        // TODO: Navigate to ClassesView with today filter
    }
    
    private func navigateToEveningClasses() {
        print("🌆 Navigating to evening classes...")
        // TODO: Navigate to ClassesView with evening filter
    }
    
    private func navigateToTomorrowClasses() {
        print("📅 Navigating to tomorrow's classes...")
        // TODO: Navigate to ClassesView with tomorrow filter
    }
    
    private func navigateToWeekendClasses() {
        print("🎉 Navigating to weekend classes...")
        // TODO: Navigate to ClassesView with weekend filter
    }
    
    // Membership actions
    private func navigateToMembershipPurchase() {
        print("💳 Navigating to membership purchase...")
        // TODO: Navigate to membership purchase flow
    }
    
    private func navigateToMembershipRenewal() {
        print("🔄 Navigating to membership renewal...")
        // TODO: Navigate to membership renewal flow
    }
    
    private func navigateToMembershipDetails() {
        print("📋 Navigating to membership details...")
        // TODO: Navigate to membership details view
    }
    
    private func refreshMembershipStatus() {
        print("🔄 Refreshing membership status...")
        Task {
            await membershipService.getMyMembershipStatus()
        }
    }
    
    // Social actions
    private func navigateToTrainerChat() {
        print("💬 Navigating to trainer chat...")
        // TODO: Navigate to specific trainer conversation
    }
    
    private func navigateToSocialFeatures() {
        print("👥 Navigating to social features...")
        // TODO: Navigate to social/community features
    }
    
    private func navigateToMessages() {
        print("💬 Navigating to messages...")
        // TODO: Navigate to messages view
    }
    
    // Workout actions
    private func continueWorkout() {
        print("🏋️‍♂️ Continuing workout...")
        // TODO: Navigate to workout continuation
    }
    
    private func navigateToPersonalRecords() {
        print("🏆 Navigating to personal records...")
        // TODO: Navigate to personal records view
    }
    
    private func showSuggestedWorkout() {
        print("💡 Showing suggested workout...")
        // TODO: Show suggested workout modal
    }
    
    // Settings actions
    private func navigateToProfileSetup() {
        print("👤 Navigating to profile setup...")
        // TODO: Navigate to profile setup flow
    }
}

#Preview {
    ContextualActionsSection(
        userStatsService: UserStatsService.shared,
        membershipService: MembershipService.shared,
        locationService: LocationService.shared,
        themeManager: ThemeManager(),
        authService: AuthServiceDirect()
    )
}