import SwiftUI
import CoreLocation

// MARK: - Smart Actions Section (Fusion of QuickAccess + ContextualActions)

struct SmartActionsSection: View {
    let themeManager: ThemeManager
    let authService: AuthServiceDirect
    let eventService: EventService
    let classService: ClassService
    let profileService: UserProfileService
    @ObservedObject var userStatsService: UserStatsService
    @ObservedObject var membershipService: MembershipService
    @ObservedObject var locationService: LocationService
    
    @State private var smartActions: [SmartAction] = []
    @State private var isLoadingActions = true
    @State private var showingLocationAlert = false
    @State private var showingCreateEvent = false
    @StateObject private var gymService = GymService.shared
    
    // Dynamic quick access actions based on user role
    private var quickAccessActions: [SmartAction] {
        var actions: [SmartAction] = []
        let currentRole = gymService.currentGym?.userRoleInGym
        
        // Base actions for all users
        actions.append(SmartAction(
            title: "Chat",
            subtitle: "Mensajes",
            icon: "message.circle.fill",
            color: Color.dynamicAccent(theme: themeManager.currentTheme),
            priority: .high,
            type: .social,
            destination: nil,
            action: { print("Chat tapped") },
            isEnabled: true
        ))
        
        // Role-specific actions
        if RolePermissions.canCreateEvents(currentRole) {
            actions.append(SmartAction(
                title: "Crear Evento",
                subtitle: "Nuevo evento",
                icon: "plus.circle.fill",
                color: Color.green,
                priority: .high,
                type: .navigation,
                destination: nil,
                action: { showingCreateEvent = true },
                isEnabled: true
            ))
        }
        
        if RolePermissions.isAdminLevel(currentRole) {
            actions.append(SmartAction(
                title: "Gestionar",
                subtitle: "Administrar",
                icon: "person.2.circle.fill",
                color: Color.orange,
                priority: .high,
                type: .navigation,
                destination: nil,
                action: { print("Admin panel tapped") },
                isEnabled: true
            ))
        }
        
        // Fill remaining slots with standard actions
        if actions.count < 4 {
            let standardActions = [
                SmartAction(
                    title: "Calendario",
                    subtitle: "Horarios",
                    icon: "calendar.circle.fill",
                    color: Color.dynamicAccent(theme: themeManager.currentTheme),
                    priority: .medium,
                    type: .navigation,
                    destination: nil,
                    action: { print("Calendario tapped") },
                    isEnabled: true
                ),
                SmartAction(
                    title: "Progreso",
                    subtitle: "Estadísticas",
                    icon: "chart.line.uptrend.xyaxis.circle.fill",
                    color: Color.dynamicAccent(theme: themeManager.currentTheme),
                    priority: .medium,
                    type: .navigation,
                    destination: nil,
                    action: { print("Progreso tapped") },
                    isEnabled: true
                ),
                SmartAction(
                    title: "Nutrición",
                    subtitle: "Planes",
                    icon: "leaf.circle.fill",
                    color: Color.dynamicAccent(theme: themeManager.currentTheme),
                    priority: .low,
                    type: .navigation,
                    destination: nil,
                    action: { print("Nutrición tapped") },
                    isEnabled: true
                )
            ]
            
            let slotsToFill = 4 - actions.count
            actions.append(contentsOf: Array(standardActions.prefix(slotsToFill)))
        }
        
        return Array(actions.prefix(4))
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header
            HStack {
                Text("Accesos Rápidos")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(Color.dynamicText(theme: themeManager.currentTheme))
                
                Spacer()
                
                if isLoadingActions {
                    ProgressView()
                        .scaleEffect(0.8)
                        .accessibilityLabel("Loading actions")
                }
            }
            .padding(.horizontal, 4)
            
            // Actions horizontal row (4 circular buttons)
            if smartActions.isEmpty && !isLoadingActions {
                EmptySmartActionsState(themeManager: themeManager)
            } else {
                // Quick access row with background
                ZStack {
                    RoundedRectangle(cornerRadius: 16)
                        .fill(Color.dynamicSurface(theme: themeManager.currentTheme))
                        .shadow(
                            color: Color.black.opacity(themeManager.currentTheme == .dark ? 0.2 : 0.08),
                            radius: 4,
                            x: 0,
                            y: 2
                        )
                    
                    HStack(spacing: 0) {
                        ForEach(Array(quickAccessActions.enumerated()), id: \.offset) { index, action in
                            CircularActionButton(
                                action: action,
                                themeManager: themeManager
                            ) {
                                performSmartAction(action)
                            }
                            .frame(maxWidth: .infinity)
                            
                            // Divider between buttons (except last)
                            if index < quickAccessActions.count - 1 {
                                Rectangle()
                                    .fill(Color.dynamicTextSecondary(theme: themeManager.currentTheme).opacity(0.2))
                                    .frame(width: 1, height: 40)
                            }
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 20)
                }
                .padding(.horizontal, 4)
            }
        }
        .onAppear {
            generateSmartActions()
        }
        .onChange(of: locationService.currentLocationStatus) { _ in
            generateSmartActions()
        }
        .onChange(of: membershipService.membershipStatus) { _ in
            generateSmartActions()
        }
        .sheet(isPresented: $showingCreateEvent) {
            CreateEventView()
                .environmentObject(themeManager)
                .environmentObject(authService)
                .environmentObject(eventService)
        }
        .alert("Location Permission Required", isPresented: $showingLocationAlert) {
            Button("Settings") {
                openSettings()
            }
            Button("Not Now", role: .cancel) { }
        } message: {
            Text("Enable location access to see location-based actions.")
        }
    }
}

// MARK: - Smart Action Model

struct SmartAction: Identifiable {
    let id = UUID()
    let title: String
    let subtitle: String
    let icon: String
    let color: Color
    let priority: ActionPriority
    let type: ActionType
    let destination: AnyView?
    let action: (() -> Void)?
    let isEnabled: Bool
    
    enum ActionPriority: Int, CaseIterable {
        case high = 3
        case medium = 2
        case low = 1
    }
    
    enum ActionType {
        case navigation
        case contextual
        case location
        case membership
        case social
    }
}

// MARK: - Circular Action Button

struct CircularActionButton: View {
    let action: SmartAction
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
            let impactFeedback = UIImpactFeedbackGenerator(style: .light)
            impactFeedback.impactOccurred()
            
            onTap()
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                withAnimation(.easeInOut(duration: 0.1)) {
                    isPressed = false
                }
            }
        }) {
            VStack(spacing: dynamicTypeSize.adjustedSpacing(10)) {
                // Circular icon background
                ZStack {
                    Circle()
                        .fill(action.color)
                        .frame(
                            width: min(48 * dynamicTypeSize.scalingFactor, 60),
                            height: min(48 * dynamicTypeSize.scalingFactor, 60)
                        )
                        .shadow(
                            color: action.color.opacity(0.3),
                            radius: 4,
                            x: 0,
                            y: 2
                        )
                    
                    Image(systemName: action.icon)
                        .font(.cappedDynamicSystem(size: 22, weight: .semibold, maxSize: 28))
                        .foregroundColor(.white)
                        .accessibilityHidden(true)
                        .scaleEffect(isPressed ? 0.9 : 1.0)
                        .animation(.easeInOut(duration: 0.1), value: isPressed)
                }
                
                Text(action.title)
                    .font(.cappedDynamicSystem(size: 12, weight: .semibold, maxSize: 15))
                    .foregroundColor(Color.dynamicText(theme: themeManager.currentTheme))
                    .lineLimit(1)
                    .dynamicTypeSupport(maxLines: 1)
                    .accessibilityHidden(true) // Hide individual text from VoiceOver
            }
            .frame(maxWidth: .infinity)
            .accessibleTouchTarget()
            .padding(.vertical, dynamicTypeSize.adjustedPadding(8))
            .scaleEffect(isPressed ? 0.95 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: isPressed)
        }
        .buttonStyle(PlainButtonStyle())
        .disabled(!action.isEnabled)
        .opacity(action.isEnabled ? 1.0 : 0.6)
        // Accessibility: Group the entire button as a single element
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Navigate to \(action.title)")
        .accessibilityHint("Double tap to open \(action.subtitle)")
        .accessibilityAddTraits(.isButton)
        .accessibilityValue("Quick access button")
    }
}

// MARK: - Smart Action Card

struct SmartActionCard: View {
    let action: SmartAction
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
            let impactFeedback = UIImpactFeedbackGenerator(style: .light)
            impactFeedback.impactOccurred()
            
            onTap()
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                withAnimation(.easeInOut(duration: 0.1)) {
                    isPressed = false
                }
            }
        }) {
            VStack(spacing: dynamicTypeSize.adjustedSpacing(12)) {
                // Icon with simplified background
                ZStack {
                    Circle()
                        .fill(action.color.opacity(0.15))
                        .frame(
                            width: min(44 * dynamicTypeSize.scalingFactor, 60),
                            height: min(44 * dynamicTypeSize.scalingFactor, 60)
                        )
                    
                    Image(systemName: action.icon)
                        .font(.cappedDynamicSystem(size: 20, weight: .semibold, maxSize: 28))
                        .foregroundColor(action.color)
                        .accessibilityHidden(true)
                }
                
                VStack(spacing: dynamicTypeSize.adjustedSpacing(4)) {
                    Text(action.title)
                        .font(.cappedDynamicSystem(size: 14, weight: .semibold, maxSize: 18))
                        .foregroundColor(Color.dynamicText(theme: themeManager.currentTheme))
                        .lineLimit(1)
                        .dynamicTypeSupport(maxLines: 1)
                    
                    Text(action.subtitle)
                        .font(.cappedDynamicSystem(size: 12, weight: .medium, maxSize: 16))
                        .foregroundColor(Color.dynamicTextSecondary(theme: themeManager.currentTheme))
                        .lineLimit(2)
                        .multilineTextAlignment(.center)
                        .dynamicTypeSupport(maxLines: 2)
                }
            }
            .padding(dynamicTypeSize.adjustedPadding(16))
            .frame(height: max(120 * dynamicTypeSize.scalingFactor, 120))
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color.dynamicSurface(theme: themeManager.currentTheme))
                    .shadow(
                        color: Color.black.opacity(themeManager.currentTheme == .dark ? 0.2 : 0.08),
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
        .accessibleTouchTarget()
    }
}

// MARK: - Empty State

struct EmptySmartActionsState: View {
    let themeManager: ThemeManager
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    
    var body: some View {
        VStack(spacing: dynamicTypeSize.adjustedSpacing(16)) {
            Image(systemName: "sparkles")
                .font(.cappedDynamicSystem(size: 32, weight: .medium, maxSize: 42))
                .foregroundColor(Color.dynamicTextSecondary(theme: themeManager.currentTheme))
                .accessibilityHidden(true)
            
            VStack(spacing: dynamicTypeSize.adjustedSpacing(8)) {
                Text("No Actions Available")
                    .font(.cappedDynamicSystem(size: 16, weight: .semibold, maxSize: 20))
                    .foregroundColor(Color.dynamicText(theme: themeManager.currentTheme))
                    .dynamicTypeSupport(maxLines: 1)
                
                Text("Actions will appear based on your activity and context.")
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
                    color: Color.black.opacity(themeManager.currentTheme == .dark ? 0.15 : 0.06),
                    radius: 3,
                    x: 0,
                    y: 2
                )
        )
        .padding(.horizontal, 4)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("No actions available. Actions will appear based on your activity and context.")
    }
}

// MARK: - Action Generation Logic

extension SmartActionsSection {
    private func generateSmartActions() {
        print("🎯 Generating smart actions...")
        isLoadingActions = true
        
        Task {
            await MainActor.run {
                var actions: [SmartAction] = []
                
                // Core navigation actions (always available)
                actions.append(contentsOf: generateCoreNavigationActions())
                
                // Contextual actions based on state
                actions.append(contentsOf: generateContextualActions())
                
                // Sort by priority and limit to 4 actions
                let sortedActions = actions
                    .sorted { $0.priority.rawValue > $1.priority.rawValue }
                    .prefix(4)
                
                withAnimation(.easeInOut(duration: 0.3)) {
                    smartActions = Array(sortedActions)
                    isLoadingActions = false
                }
                
                print("✅ Generated \(smartActions.count) smart actions")
            }
        }
    }
    
    private func generateCoreNavigationActions() -> [SmartAction] {
        var actions: [SmartAction] = []
        
        // Always show Classes as primary action
        actions.append(SmartAction(
            title: "Classes",
            subtitle: "Book sessions",
            icon: "dumbbell.fill",
            color: Color.dynamicAccent(theme: themeManager.currentTheme),
            priority: .high,
            type: .navigation,
            destination: AnyView(
                ClassesView()
                    .environmentObject(themeManager)
                    .environmentObject(authService)
                    .environmentObject(classService)
            ),
            action: nil,
            isEnabled: true
        ))
        
        // Events - only if there are upcoming events
        if !eventService.events.isEmpty {
            actions.append(SmartAction(
                title: "Events",
                subtitle: "Upcoming activities",
                icon: "calendar.circle.fill",
                color: Color.dynamicAccent(theme: themeManager.currentTheme).opacity(0.8),
                priority: .medium,
                type: .navigation,
                destination: AnyView(
                    EventsView()
                        .environmentObject(themeManager)
                        .environmentObject(authService)
                        .environmentObject(eventService)
                ),
                action: nil,
                isEnabled: true
            ))
        }
        
        // Always show Profile (ModernProfileView)
        actions.append(SmartAction(
            title: "Profile",
            subtitle: "Settings & info",
            icon: "person.circle.fill",
            color: Color.dynamicAccent(theme: themeManager.currentTheme).opacity(0.6),
            priority: .low,
            type: .navigation,
            destination: AnyView(
                ModernProfileView()
                    .environmentObject(authService)
                    .environmentObject(themeManager)
            ),
            action: nil,
            isEnabled: true
        ))
        
        return actions
    }
    
    private func generateContextualActions() -> [SmartAction] {
        var actions: [SmartAction] = []
        
        // Location-based check-in
        if locationService.currentLocationStatus == .nearGym {
            actions.append(SmartAction(
                title: "Check-in",
                subtitle: "You're at the gym!",
                icon: "location.circle.fill",
                color: .green,
                priority: .high,
                type: .location,
                destination: nil,
                action: { performCheckin() },
                isEnabled: true
            ))
        }
        
        // Membership renewal if expiring soon
        if let membership = membershipService.membershipStatus,
           let daysRemaining = membership.daysRemaining,
           daysRemaining <= 7 {
            actions.append(SmartAction(
                title: "Renew",
                subtitle: "\(daysRemaining) days left",
                icon: "arrow.clockwise.circle.fill",
                color: .orange,
                priority: .high,
                type: .membership,
                destination: nil,
                action: { navigateToMembershipRenewal() },
                isEnabled: true
            ))
        }
        
        // Messages if there are unread (mock for now)
        let hasUnreadMessages = false // TODO: Get from chat service
        if hasUnreadMessages {
            actions.append(SmartAction(
                title: "Messages",
                subtitle: "New conversations",
                icon: "message.circle.fill",
                color: .blue,
                priority: .medium,
                type: .social,
                destination: AnyView(
                    UnifiedMessagesView()
                        .environmentObject(themeManager)
                        .environmentObject(authService)
                ),
                action: nil,
                isEnabled: true
            ))
        }
        
        return actions
    }
}

// MARK: - Action Handlers

extension SmartActionsSection {
    private func performSmartAction(_ action: SmartAction) {
        print("🎯 Performing smart action: \(action.title)")
        
        if let actionClosure = action.action {
            actionClosure()
        } else if let destination = action.destination {
            // Navigation will be handled by parent view via NavigationLink
        }
    }
    
    private func performCheckin() {
        print("📍 Performing gym check-in...")
        let notification = UINotificationFeedbackGenerator()
        notification.notificationOccurred(.success)
    }
    
    private func navigateToMembershipRenewal() {
        print("🔄 Navigating to membership renewal...")
        // TODO: Navigate to membership renewal flow
    }
    
    private func openSettings() {
        if let settingsUrl = URL(string: UIApplication.openSettingsURLString) {
            UIApplication.shared.open(settingsUrl)
        }
    }
}

#Preview {
    SmartActionsSection(
        themeManager: ThemeManager(),
        authService: AuthServiceDirect(),
        eventService: EventService(),
        classService: ClassService(),
        profileService: UserProfileService.shared,
        userStatsService: UserStatsService.shared,
        membershipService: MembershipService.shared,
        locationService: LocationService.shared
    )
}
