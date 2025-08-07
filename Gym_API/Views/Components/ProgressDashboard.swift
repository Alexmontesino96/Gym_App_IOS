//
//  ProgressDashboard.swift
//  Gym_API
//
//  Modern Dashboard Implementation
//  Created by Claude Code on 8/6/25.
//

import SwiftUI

// MARK: - Progress Dashboard Main Component
struct ProgressDashboard: View {
    @ObservedObject var userStatsService: UserStatsService
    let themeManager: ThemeManager
    let eventService: EventService
    let classService: ClassService
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    
    var body: some View {
        let _ = print("📊 ProgressDashboard.body - comprehensiveStats: \(userStatsService.comprehensiveStats != nil)")
        let _ = print("📊 ProgressDashboard.body - isLoading: \(userStatsService.isLoading)")
        let _ = print("📊 ProgressDashboard.body - errorMessage: \(userStatsService.errorMessage ?? "none")")
        
        return VStack(spacing: 24) {
            if let comprehensiveStats = userStatsService.comprehensiveStats {
                let _ = print("📊 ProgressDashboard - Renderizando dashboard completo")
                
                // Información accionable inmediata
                UpcomingClassesSection(
                    classService: classService,
                    themeManager: themeManager
                )
                
                // Mensajes importantes del coach
                CoachMessagesSection(
                    themeManager: themeManager
                )
                
                // Hero Section - Métricas destacadas
                DashboardHeroSection(
                    stats: comprehensiveStats,
                    themeManager: themeManager
                )
                
                // Quick Stats Cards - 2 métricas principales
                FitnessMetricsSection(
                    fitnessMetrics: comprehensiveStats.fitnessMetrics,
                    themeManager: themeManager
                )
                
                // Getting Started Section para usuarios nuevos
                if isNewUser(stats: comprehensiveStats) {
                    GettingStartedSection(
                        stats: comprehensiveStats,
                        themeManager: themeManager
                    )
                }
                
                
                // Membership Insights
                MembershipInsightsSection(
                    membershipUtilization: comprehensiveStats.membershipUtilization,
                    themeManager: themeManager
                )
                
                
                
            } else if userStatsService.isLoading {
                let _ = print("📊 ProgressDashboard - Mostrando skeleton loader")
                // Loading State
                DashboardSkeletonView(themeManager: themeManager)
                
            } else {
                let _ = print("📊 ProgressDashboard - Mostrando error state")
                // Error State
                DashboardErrorState(
                    errorMessage: userStatsService.errorMessage,
                    themeManager: themeManager,
                    onRetry: {
                        Task {
                            await userStatsService.fetchComprehensiveStats()
                        }
                    }
                )
            }
        }
        .onAppear {
            Task {
                await userStatsService.fetchComprehensiveStats()
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Progress Dashboard")
        .accessibilityHint("View your comprehensive fitness progress and insights")
    }
    
    // Helper function to detect new users
    private func isNewUser(stats: ComprehensiveStats) -> Bool {
        let totalClasses = stats.fitnessMetrics.classesAttended
        let totalEvents = stats.eventsMetrics.eventsAttended
        let totalActivity = totalClasses + totalEvents
        return totalActivity == 0 && stats.fitnessMetrics.streakCurrent == 0
    }
}

// MARK: - Dashboard Hero Section
struct DashboardHeroSection: View {
    let stats: ComprehensiveStats
    let themeManager: ThemeManager
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @State private var animateFlame = false
    
    private var currentStreak: Int {
        stats.fitnessMetrics.streakCurrent
    }
    
    private var longestStreak: Int {
        stats.fitnessMetrics.streakLongest
    }
    
    private var heroMessage: String {
        let classesAttended = stats.fitnessMetrics.classesAttended
        let eventsCreated = stats.eventsMetrics.eventsCreated
        let totalActivity = classesAttended + eventsCreated
        
        if totalActivity == 0 {
            return "Let's get started!"
        } else if totalActivity < 5 {
            return "Great start!"
        } else if totalActivity < 10 {
            return "Keep it up!"
        } else {
            return "You're on fire!"
        }
    }
    
    var body: some View {
        ZStack {
            // Background with glassmorphism
            RoundedRectangle(cornerRadius: 20)
                .fill(Color.dynamicSurface(theme: themeManager.currentTheme))
                .shadow(
                    color: Color.black.opacity(themeManager.currentTheme == .dark ? 0.2 : 0.08),
                    radius: 6,
                    x: 0,
                    y: 3
                )
            
            VStack(spacing: dynamicTypeSize.adjustedSpacing(20)) {
                HStack {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Your Progress")
                            .font(.cappedDynamicSystem(size: 16, weight: .medium, maxSize: 20))
                            .foregroundColor(Color.dynamicTextSecondary(theme: themeManager.currentTheme))
                        
                        Text(heroMessage)
                            .font(.cappedDynamicSystem(size: 28, weight: .bold, maxSize: 36))
                            .foregroundColor(Color.dynamicText(theme: themeManager.currentTheme))
                    }
                    
                    Spacer()
                    
                    // Streak indicator
                    ZStack {
                        Circle()
                            .fill(Color.orange)
                            .frame(width: 50, height: 50)
                            .shadow(color: Color.orange.opacity(0.3), radius: 4, x: 0, y: 2)
                        
                        VStack(spacing: 2) {
                            Image(systemName: "flame.fill")
                                .font(.system(size: 16, weight: .bold))
                                .foregroundColor(.white)
                                .scaleEffect(animateFlame ? 1.1 : 1.0)
                                .animation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true), value: animateFlame)
                            
                            Text("\(currentStreak)")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundColor(.white)
                        }
                    }
                }
                
            }
            .padding(24)
        }
        .onAppear {
            animateFlame = true
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Current streak: \(currentStreak) days. Classes attended: \(stats.fitnessMetrics.classesAttended). Workout hours: \(String(format: "%.1f", stats.fitnessMetrics.totalWorkoutHours))")
    }
}

// MARK: - Hero Metric Item
struct HeroMetricItem: View {
    let title: String
    let value: String
    let subtitle: String
    let color: Color
    let themeManager: ThemeManager
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    
    var body: some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.cappedDynamicSystem(size: 20, weight: .bold, maxSize: 26))
                .foregroundColor(color)
            
            Text(title)
                .font(.cappedDynamicSystem(size: 12, weight: .semibold, maxSize: 16))
                .foregroundColor(Color.dynamicText(theme: themeManager.currentTheme))
            
            Text(subtitle)
                .font(.cappedDynamicSystem(size: 10, weight: .medium, maxSize: 14))
                .foregroundColor(Color.dynamicTextSecondary(theme: themeManager.currentTheme))
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(title): \(value) \(subtitle)")
    }
}

// MARK: - Fitness Metrics Section
struct FitnessMetricsSection: View {
    let fitnessMetrics: FitnessMetrics
    let themeManager: ThemeManager
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    
    var body: some View {
        VStack(spacing: 16) {
            HStack {
                Text("Fitness Overview")
                    .font(.cappedDynamicSystem(size: 20, weight: .bold, maxSize: 26))
                    .foregroundColor(Color.dynamicText(theme: themeManager.currentTheme))
                Spacer()
            }
            .padding(.horizontal, 4)
            
            HStack(spacing: 12) {
                FitnessMetricCard(
                    icon: "figure.strengthtraining.traditional",
                    title: "Classes",
                    value: "\(fitnessMetrics.classesAttended)",
                    subtitle: fitnessMetrics.classesScheduled > 0 ? "of \(fitnessMetrics.classesScheduled) scheduled" : "none scheduled",
                    progress: fitnessMetrics.classesScheduled > 0 ? Double(fitnessMetrics.classesAttended) / Double(fitnessMetrics.classesScheduled) : 0,
                    color: Color.dynamicAccent(theme: themeManager.currentTheme),
                    themeManager: themeManager
                )
                
                FitnessMetricCard(
                    icon: "clock.arrow.circlepath",
                    title: "Hours",
                    value: String(format: "%.1f", fitnessMetrics.totalWorkoutHours),
                    subtitle: "workout time",
                    progress: min(fitnessMetrics.totalWorkoutHours / 10.0, 1.0), // Goal of 10 hours
                    color: Color.dynamicAccent(theme: themeManager.currentTheme).opacity(0.7),
                    themeManager: themeManager
                )
            }
        }
    }
}

// MARK: - Fitness Metric Card
struct FitnessMetricCard: View {
    let icon: String
    let title: String
    let value: String
    let subtitle: String
    let progress: Double
    let color: Color
    let themeManager: ThemeManager
    @State private var animatedProgress: Double = 0
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.dynamicSurface(theme: themeManager.currentTheme))
                .shadow(
                    color: Color.black.opacity(themeManager.currentTheme == .dark ? 0.2 : 0.08),
                    radius: 4,
                    x: 0,
                    y: 2
                )
            
            VStack(spacing: dynamicTypeSize.adjustedSpacing(12)) {
                // Icon and progress ring
                ZStack {
                    Circle()
                        .stroke(color.opacity(0.2), lineWidth: 3)
                        .frame(width: 44, height: 44)
                    
                    Circle()
                        .trim(from: 0, to: animatedProgress)
                        .stroke(color, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                        .frame(width: 44, height: 44)
                        .rotationEffect(.degrees(-90))
                        .animation(.spring(duration: 1.2, bounce: 0.3), value: animatedProgress)
                    
                    Image(systemName: icon)
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(color)
                }
                
                VStack(spacing: 4) {
                    Text(value)
                        .font(.cappedDynamicSystem(size: 18, weight: .bold, maxSize: 24))
                        .foregroundColor(Color.dynamicText(theme: themeManager.currentTheme))
                    
                    Text(title)
                        .font(.cappedDynamicSystem(size: 12, weight: .semibold, maxSize: 16))
                        .foregroundColor(Color.dynamicText(theme: themeManager.currentTheme))
                    
                    Text(subtitle)
                        .font(.cappedDynamicSystem(size: 10, weight: .medium, maxSize: 14))
                        .foregroundColor(Color.dynamicTextSecondary(theme: themeManager.currentTheme))
                        .multilineTextAlignment(.center)
                        .lineLimit(2)
                }
            }
            .padding(dynamicTypeSize.adjustedPadding(16))
        }
        .frame(maxWidth: .infinity)
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                animatedProgress = progress
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(title): \(value) \(subtitle)")
        .accessibilityValue("\(Int(progress * 100)) percent complete")
    }
}

// MARK: - Social Engagement Section  
struct SocialEngagementSection: View {
    let socialMetrics: SocialMetrics
    let themeManager: ThemeManager
    @State private var animatedScore: Double = 0
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    
    var body: some View {
        VStack(spacing: 16) {
            HStack {
                Text("Social Engagement")
                    .font(.cappedDynamicSystem(size: 20, weight: .bold, maxSize: 26))
                    .foregroundColor(Color.dynamicText(theme: themeManager.currentTheme))
                
                Spacer()
                
                // Social level badge
                HStack(spacing: 4) {
                    Image(systemName: "person.2.fill")
                        .font(.system(size: 12))
                        .foregroundColor(.purple)
                    
                    Text(socialLevelText)
                        .font(.cappedDynamicSystem(size: 12, weight: .semibold, maxSize: 16))
                        .foregroundColor(Color.dynamicText(theme: themeManager.currentTheme))
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(.purple.opacity(0.15))
                .cornerRadius(12)
            }
            .padding(.horizontal, 4)
            
            ZStack {
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color.dynamicSurface(theme: themeManager.currentTheme))
                    .shadow(
                        color: Color.black.opacity(themeManager.currentTheme == .dark ? 0.25 : 0.1),
                        radius: 8,
                        x: 0,
                        y: 4
                    )
                
                HStack(spacing: 20) {
                    // Social score ring
                    VStack(spacing: 8) {
                        ZStack {
                            Circle()
                                .stroke(.purple.opacity(0.2), lineWidth: 8)
                                .frame(width: 80, height: 80)
                            
                            Circle()
                                .trim(from: 0, to: animatedScore / 10.0)
                                .stroke(.purple, style: StrokeStyle(lineWidth: 8, lineCap: .round))
                                .frame(width: 80, height: 80)
                                .rotationEffect(.degrees(-90))
                                .animation(.spring(duration: 1.5, bounce: 0.3), value: animatedScore)
                            
                            VStack(spacing: 2) {
                                Text("\(Int(socialMetrics.socialScore))")
                                    .font(.system(size: 20, weight: .bold))
                                    .foregroundColor(.purple)
                                
                                Text("/ 10")
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundColor(Color.dynamicTextSecondary(theme: themeManager.currentTheme))
                            }
                        }
                        
                        Text("Social Score")
                            .font(.cappedDynamicSystem(size: 12, weight: .semibold, maxSize: 16))
                            .foregroundColor(Color.dynamicText(theme: themeManager.currentTheme))
                    }
                    
                    // Social stats
                    VStack(alignment: .leading, spacing: 12) {
                        SocialStatRow(
                            icon: "message.fill",
                            label: "Messages Sent",
                            value: "\(socialMetrics.chatMessagesSent)",
                            color: .blue,
                            themeManager: themeManager
                        )
                        
                        SocialStatRow(
                            icon: "bubble.left.and.bubble.right.fill",
                            label: "Active Chats",
                            value: "\(socialMetrics.chatRoomsActive)",
                            color: .green,
                            themeManager: themeManager
                        )
                        
                        SocialStatRow(
                            icon: "person.badge.clock.fill",
                            label: "Trainer Interactions",
                            value: "\(socialMetrics.trainerInteractions)",
                            color: .orange,
                            themeManager: themeManager
                        )
                    }
                    
                    Spacer()
                }
                .padding(20)
            }
            .padding(.horizontal, 4)
        }
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
                animatedScore = Double(socialMetrics.socialScore)
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Social engagement: \(socialMetrics.socialScore) out of 10 score")
    }
    
    private var socialLevelText: String {
        switch socialMetrics.socialScore {
        case 0...2: return "Newcomer"
        case 3...5: return "Social"
        case 6...7: return "Active"
        case 8...9: return "Community Star"
        case 10: return "Social Champion"
        default: return "Newcomer"
        }
    }
}

// MARK: - Social Stat Row
struct SocialStatRow: View {
    let icon: String
    let label: String
    let value: String
    let color: Color
    let themeManager: ThemeManager
    
    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(color.opacity(0.15))
                    .frame(width: 32, height: 32)
                
                Image(systemName: icon)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(color)
            }
            
            VStack(alignment: .leading, spacing: 2) {
                Text(value)
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(Color.dynamicText(theme: themeManager.currentTheme))
                
                Text(label)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(Color.dynamicTextSecondary(theme: themeManager.currentTheme))
            }
            
            Spacer()
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(label): \(value)")
    }
}

// MARK: - Membership Insights Section
struct MembershipInsightsSection: View {
    let membershipUtilization: MembershipUtilization
    let themeManager: ThemeManager
    @State private var animatedUtilization: Double = 0
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    
    var body: some View {
        VStack(spacing: 16) {
            HStack {
                Text("Membership Insights")
                    .font(.cappedDynamicSystem(size: 20, weight: .bold, maxSize: 26))
                    .foregroundColor(Color.dynamicText(theme: themeManager.currentTheme))
                
                Spacer()
                
                // Plan badge
                HStack(spacing: 4) {
                    Image(systemName: "crown.fill")
                        .font(.system(size: 12))
                        .foregroundColor(.yellow)
                    
                    Text(membershipUtilization.planName)
                        .font(.cappedDynamicSystem(size: 12, weight: .semibold, maxSize: 16))
                        .foregroundColor(Color.dynamicText(theme: themeManager.currentTheme))
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(.yellow.opacity(0.15))
                .cornerRadius(12)
            }
            .padding(.horizontal, 4)
            
            ZStack {
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color.dynamicSurface(theme: themeManager.currentTheme))
                    .shadow(
                        color: Color.black.opacity(themeManager.currentTheme == .dark ? 0.25 : 0.1),
                        radius: 8,
                        x: 0,
                        y: 4
                    )
                
                VStack(spacing: 20) {
                    // Utilization progress
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Text("Membership Utilization")
                                .font(.cappedDynamicSystem(size: 16, weight: .semibold, maxSize: 20))
                                .foregroundColor(Color.dynamicText(theme: themeManager.currentTheme))
                            
                            Spacer()
                            
                            Text("\(membershipUtilization.utilizationRate)%")
                                .font(.cappedDynamicSystem(size: 18, weight: .bold, maxSize: 24))
                                .foregroundColor(utilizationColor)
                        }
                        
                        ZStack(alignment: .leading) {
                            RoundedRectangle(cornerRadius: 8)
                                .fill(Color.dynamicTextSecondary(theme: themeManager.currentTheme).opacity(0.2))
                                .frame(height: 12)
                            
                            RoundedRectangle(cornerRadius: 8)
                                .fill(utilizationColor)
                                .frame(height: 12)
                                .scaleEffect(x: animatedUtilization / 100.0, y: 1, anchor: .leading)
                                .animation(.spring(duration: 1.2, bounce: 0.3), value: animatedUtilization)
                        }
                        
                        Text(utilizationLevelText)
                            .font(.cappedDynamicSystem(size: 12, weight: .medium, maxSize: 16))
                            .foregroundColor(Color.dynamicTextSecondary(theme: themeManager.currentTheme))
                    }
                    
                    // Value metrics
                    HStack(spacing: 20) {
                        MembershipMetricItem(
                            title: "Value Score",
                            value: "\(membershipUtilization.valueScore)/10",
                            color: valueScoreColor,
                            themeManager: themeManager
                        )
                        
                        MembershipMetricItem(
                            title: "Renewal",
                            value: renewalText,
                            color: renewalColor,
                            themeManager: themeManager
                        )
                    }
                }
                .padding(20)
            }
            .padding(.horizontal, 4)
        }
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                animatedUtilization = Double(membershipUtilization.utilizationRate)
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Membership utilization: \(membershipUtilization.utilizationRate)%, Value score: \(membershipUtilization.valueScore) out of 10")
    }
    
    private var utilizationColor: Color {
        switch membershipUtilization.utilizationRate {
        case 0...30: return .red
        case 31...60: return .orange
        case 61...80: return .yellow
        default: return .green
        }
    }
    
    private var valueScoreColor: Color {
        switch membershipUtilization.valueScore {
        case 0...3: return .red
        case 4...6: return .orange
        case 7...8: return .yellow
        default: return .green
        }
    }
    
    private var renewalColor: Color {
        switch membershipUtilization.daysUntilRenewal {
        case 0...7: return .red
        case 8...30: return .orange
        case 31...90: return .yellow
        default: return .green
        }
    }
    
    private var utilizationLevelText: String {
        switch membershipUtilization.utilizationRate {
        case 0...30: return "Low utilization - Consider attending more classes"
        case 31...60: return "Moderate utilization - You're doing great!"
        case 61...80: return "Good utilization - Keep up the momentum!"
        default: return "Excellent utilization - You're maximizing your membership!"
        }
    }
    
    private var renewalText: String {
        let days = membershipUtilization.daysUntilRenewal
        if days <= 0 {
            return "Today"
        } else if days == 1 {
            return "1 day"
        } else if days < 30 {
            return "\(days) days"
        } else {
            let months = days / 30
            return "\(months) month\(months > 1 ? "s" : "")"
        }
    }
}

// MARK: - Membership Metric Item
struct MembershipMetricItem: View {
    let title: String
    let value: String
    let color: Color
    let themeManager: ThemeManager
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(Color.dynamicTextSecondary(theme: themeManager.currentTheme))
            
            Text(value)
                .font(.system(size: 18, weight: .bold))
                .foregroundColor(color)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(title): \(value)")
    }
}

// MARK: - Achievements Section
struct AchievementsSection: View {
    let achievements: [Achievement]
    let themeManager: ThemeManager
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    
    var body: some View {
        VStack(spacing: 16) {
            HStack {
                Text("Achievements")
                    .font(.cappedDynamicSystem(size: 20, weight: .bold, maxSize: 26))
                    .foregroundColor(Color.dynamicText(theme: themeManager.currentTheme))
                
                Spacer()
                
                HStack(spacing: 4) {
                    Image(systemName: "trophy.fill")
                        .font(.system(size: 12))
                        .foregroundColor(.yellow)
                    
                    Text("\(achievements.count)")
                        .font(.cappedDynamicSystem(size: 12, weight: .semibold, maxSize: 16))
                        .foregroundColor(Color.dynamicText(theme: themeManager.currentTheme))
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(.yellow.opacity(0.15))
                .cornerRadius(12)
            }
            .padding(.horizontal, 4)
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(achievements, id: \.id) { achievement in
                        AchievementCard(achievement: achievement, themeManager: themeManager)
                    }
                }
                .padding(.horizontal, 20)
            }
        }
    }
}

// MARK: - Achievement Card
struct AchievementCard: View {
    let achievement: Achievement
    let themeManager: ThemeManager
    @State private var shimmer = false
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 16)
                .fill(
                    LinearGradient(
                        colors: [.yellow.opacity(0.8), .orange.opacity(0.6)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .shadow(color: .yellow.opacity(0.4), radius: 8, x: 0, y: 4)
            
            VStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(Color.white.opacity(0.3))
                        .frame(width: 50, height: 50)
                    
                    Image(systemName: achievement.badgeIcon.isEmpty ? "star.fill" : achievement.badgeIcon)
                        .font(.system(size: 24, weight: .bold))
                        .foregroundColor(.white)
                        .scaleEffect(shimmer ? 1.1 : 1.0)
                        .animation(.easeInOut(duration: 2.0).repeatForever(autoreverses: true), value: shimmer)
                }
                
                VStack(spacing: 4) {
                    Text(achievement.name)
                        .font(.cappedDynamicSystem(size: 14, weight: .bold, maxSize: 18))
                        .foregroundColor(.white)
                        .multilineTextAlignment(.center)
                        .lineLimit(2)
                    
                    Text(achievement.description)
                        .font(.cappedDynamicSystem(size: 12, weight: .medium, maxSize: 16))
                        .foregroundColor(.white.opacity(0.9))
                        .multilineTextAlignment(.center)
                        .lineLimit(3)
                }
            }
            .padding(16)
        }
        .frame(width: 140, height: 160)
        .onAppear {
            shimmer = true
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Achievement: \(achievement.name). \(achievement.description)")
    }
}

// MARK: - Smart Recommendations Section
struct SmartRecommendationsSection: View {
    let recommendations: [String]
    let themeManager: ThemeManager
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    
    var body: some View {
        VStack(spacing: 16) {
            HStack {
                Text("Smart Recommendations")
                    .font(.cappedDynamicSystem(size: 20, weight: .bold, maxSize: 26))
                    .foregroundColor(Color.dynamicText(theme: themeManager.currentTheme))
                
                Spacer()
                
                HStack(spacing: 4) {
                    Image(systemName: "brain.head.profile.fill")
                        .font(.system(size: 12))
                        .foregroundColor(.blue)
                    
                    Text("AI Powered")
                        .font(.cappedDynamicSystem(size: 12, weight: .semibold, maxSize: 16))
                        .foregroundColor(Color.dynamicText(theme: themeManager.currentTheme))
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(.blue.opacity(0.15))
                .cornerRadius(12)
            }
            .padding(.horizontal, 4)
            
            LazyVStack(spacing: 12) {
                ForEach(Array(recommendations.enumerated()), id: \.offset) { index, recommendation in
                    DashboardRecommendationCard(
                        recommendation: recommendation,
                        index: index,
                        themeManager: themeManager
                    )
                }
            }
            .padding(.horizontal, 4)
        }
    }
}

// MARK: - Dashboard Recommendation Card
struct DashboardRecommendationCard: View {
    let recommendation: String
    let index: Int
    let themeManager: ThemeManager
    @State private var isPressed = false
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    
    private let icons = ["lightbulb.fill", "target", "person.2.fill", "chart.line.uptrend.xyaxis"]
    private let colors: [Color] = [.blue, .green, .purple, .orange]
    
    var body: some View {
        Button(action: {
            let impactFeedback = UIImpactFeedbackGenerator(style: .light)
            impactFeedback.impactOccurred()
        }) {
            ZStack {
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color.dynamicSurface(theme: themeManager.currentTheme))
                    .shadow(
                        color: Color.black.opacity(themeManager.currentTheme == .dark ? 0.25 : 0.1),
                        radius: isPressed ? 2 : 8,
                        x: 0,
                        y: isPressed ? 1 : 4
                    )
                
                HStack(spacing: 16) {
                    ZStack {
                        Circle()
                            .fill(currentColor.opacity(0.15))
                            .frame(width: 44, height: 44)
                        
                        Image(systemName: currentIcon)
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundColor(currentColor)
                    }
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text(recommendation)
                            .font(.cappedDynamicSystem(size: 14, weight: .medium, maxSize: 18))
                            .foregroundColor(Color.dynamicText(theme: themeManager.currentTheme))
                            .multilineTextAlignment(.leading)
                            .fixedSize(horizontal: false, vertical: true)
                        
                        Text("Tap to explore")
                            .font(.cappedDynamicSystem(size: 12, weight: .medium, maxSize: 16))
                            .foregroundColor(Color.dynamicTextSecondary(theme: themeManager.currentTheme))
                    }
                    
                    Spacer()
                    
                    Image(systemName: "chevron.right")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(Color.dynamicTextSecondary(theme: themeManager.currentTheme).opacity(0.6))
                }
                .padding(16)
            }
        }
        .buttonStyle(PlainButtonStyle())
        .scaleEffect(isPressed ? 0.98 : 1.0)
        .animation(.easeInOut(duration: 0.1), value: isPressed)
        .onPressGesture(
            onPressed: { isPressed = true },
            onEnded: { isPressed = false }
        )
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Recommendation: \(recommendation)")
        .accessibilityHint("Double tap to explore this suggestion")
    }
    
    private var currentIcon: String {
        icons[index % icons.count]
    }
    
    private var currentColor: Color {
        colors[index % colors.count]
    }
}

// MARK: - Dashboard States

// MARK: - Dashboard Skeleton View
struct DashboardSkeletonView: View {
    let themeManager: ThemeManager
    @State private var isAnimating = false
    
    var body: some View {
        VStack(spacing: 24) {
            // Hero skeleton
            SkeletonCard(width: .infinity, height: 140, themeManager: themeManager, isAnimating: isAnimating)
            
            // Metrics skeleton
            HStack(spacing: 12) {
                ForEach(0..<3, id: \.self) { _ in
                    SkeletonCard(width: nil, height: 120, themeManager: themeManager, isAnimating: isAnimating)
                }
            }
            
            // Social skeleton
            SkeletonCard(width: .infinity, height: 120, themeManager: themeManager, isAnimating: isAnimating)
            
            // Membership skeleton
            SkeletonCard(width: .infinity, height: 140, themeManager: themeManager, isAnimating: isAnimating)
        }
        .onAppear {
            isAnimating = true
        }
        .accessibilityLabel("Loading dashboard content")
    }
}

// MARK: - Skeleton Card
struct SkeletonCard: View {
    let width: CGFloat?
    let height: CGFloat
    let themeManager: ThemeManager
    let isAnimating: Bool
    
    var body: some View {
        RoundedRectangle(cornerRadius: 16)
            .fill(Color.dynamicSurface(theme: themeManager.currentTheme))
            .frame(height: height)
            .frame(maxWidth: width == .infinity ? .infinity : (width ?? .infinity))
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color.clear,
                                Color.white.opacity(0.1),
                                Color.clear
                            ],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .scaleEffect(x: isAnimating ? 1 : 0, y: 1, anchor: .leading)
                    .animation(.easeInOut(duration: 1.5).repeatForever(autoreverses: false), value: isAnimating)
            )
    }
}

// MARK: - Dashboard Error State
struct DashboardErrorState: View {
    let errorMessage: String?
    let themeManager: ThemeManager
    let onRetry: () -> Void
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    
    var body: some View {
        VStack(spacing: 20) {
            ZStack {
                Circle()
                    .fill(Color.red.opacity(0.15))
                    .frame(width: 80, height: 80)
                
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 32, weight: .semibold))
                    .foregroundColor(.red)
            }
            
            VStack(spacing: 8) {
                Text("Unable to load dashboard")
                    .font(.cappedDynamicSystem(size: 18, weight: .semibold, maxSize: 24))
                    .foregroundColor(Color.dynamicText(theme: themeManager.currentTheme))
                    .multilineTextAlignment(.center)
                
                if let errorMessage = errorMessage {
                    Text(errorMessage)
                        .font(.cappedDynamicSystem(size: 14, weight: .medium, maxSize: 18))
                        .foregroundColor(Color.dynamicTextSecondary(theme: themeManager.currentTheme))
                        .multilineTextAlignment(.center)
                }
            }
            
            Button(action: onRetry) {
                HStack(spacing: 8) {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 14, weight: .semibold))
                    
                    Text("Try Again")
                        .font(.cappedDynamicSystem(size: 14, weight: .semibold, maxSize: 18))
                }
                .foregroundColor(.white)
                .padding(.horizontal, 24)
                .padding(.vertical, 12)
                .background(Color.dynamicAccent(theme: themeManager.currentTheme))
                .cornerRadius(12)
            }
            .accessibilityLabel("Retry loading dashboard")
        }
        .padding(40)
        .background(Color.dynamicSurface(theme: themeManager.currentTheme))
        .cornerRadius(16)
        .shadow(
            color: Color.black.opacity(themeManager.currentTheme == .dark ? 0.25 : 0.1),
            radius: 8,
            x: 0,
            y: 4
        )
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Error loading dashboard. \(errorMessage ?? "Unknown error")")
    }
}

// MARK: - Helper Extensions
extension View {
    func onPressGesture(
        onPressed: @escaping () -> Void,
        onEnded: @escaping () -> Void
    ) -> some View {
        self
            .onTapGesture {
                onPressed()
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    onEnded()
                }
            }
    }
}

// MARK: - Getting Started Section
struct GettingStartedSection: View {
    let stats: ComprehensiveStats
    let themeManager: ThemeManager
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    
    var body: some View {
        VStack(spacing: 16) {
            HStack {
                Text("Welcome to Your Fitness Journey!")
                    .font(.cappedDynamicSystem(size: 20, weight: .bold, maxSize: 26))
                    .foregroundColor(Color.dynamicText(theme: themeManager.currentTheme))
                
                Spacer()
                
                Image(systemName: "sparkles")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(.yellow)
            }
            .padding(.horizontal, 4)
            
            ZStack {
                RoundedRectangle(cornerRadius: 20)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color.dynamicAccent(theme: themeManager.currentTheme).opacity(0.1),
                                Color.dynamicAccent(theme: themeManager.currentTheme).opacity(0.05)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 20)
                            .stroke(Color.dynamicAccent(theme: themeManager.currentTheme).opacity(0.2), lineWidth: 1)
                    )
                
                VStack(spacing: 20) {
                    VStack(spacing: 8) {
                        Image(systemName: "figure.strengthtraining.traditional")
                            .font(.system(size: 40, weight: .bold))
                            .foregroundColor(Color.dynamicAccent(theme: themeManager.currentTheme))
                        
                        Text("Ready to transform your fitness?")
                            .font(.cappedDynamicSystem(size: 18, weight: .semibold, maxSize: 22))
                            .foregroundColor(Color.dynamicText(theme: themeManager.currentTheme))
                            .multilineTextAlignment(.center)
                        
                        Text("You have \(stats.fitnessMetrics.classesScheduled) class scheduled. Let's make it happen!")
                            .font(.cappedDynamicSystem(size: 14, weight: .medium, maxSize: 18))
                            .foregroundColor(Color.dynamicTextSecondary(theme: themeManager.currentTheme))
                            .multilineTextAlignment(.center)
                    }
                    
                    HStack(spacing: 16) {
                        GetStartedActionCard(
                            icon: "calendar.badge.plus",
                            title: "Book a Class",
                            subtitle: "Start your journey",
                            color: .blue,
                            themeManager: themeManager
                        )
                        
                        GetStartedActionCard(
                            icon: "person.2.fill",
                            title: "Join Community",
                            subtitle: "Meet members",
                            color: .purple,
                            themeManager: themeManager
                        )
                        
                        GetStartedActionCard(
                            icon: "target",
                            title: "Set Goals",
                            subtitle: "Track progress",
                            color: .green,
                            themeManager: themeManager
                        )
                    }
                }
                .padding(24)
            }
            .padding(.horizontal, 4)
        }
    }
}

// MARK: - Get Started Action Card
struct GetStartedActionCard: View {
    let icon: String
    let title: String
    let subtitle: String
    let color: Color
    let themeManager: ThemeManager
    @State private var isPressed = false
    
    var body: some View {
        Button(action: {
            let impactFeedback = UIImpactFeedbackGenerator(style: .light)
            impactFeedback.impactOccurred()
        }) {
            VStack(spacing: 8) {
                ZStack {
                    Circle()
                        .fill(color.opacity(0.15))
                        .frame(width: 44, height: 44)
                    
                    Image(systemName: icon)
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(color)
                }
                
                VStack(spacing: 2) {
                    Text(title)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(Color.dynamicText(theme: themeManager.currentTheme))
                    
                    Text(subtitle)
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(Color.dynamicTextSecondary(theme: themeManager.currentTheme))
                }
                .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
        }
        .buttonStyle(PlainButtonStyle())
        .scaleEffect(isPressed ? 0.95 : 1.0)
        .animation(.easeInOut(duration: 0.1), value: isPressed)
        .onPressGesture(
            onPressed: { isPressed = true },
            onEnded: { isPressed = false }
        )
        .accessibilityLabel("\(title): \(subtitle)")
    }
}

// MARK: - Upcoming Classes Section
struct UpcomingClassesSection: View {
    @ObservedObject var classService: ClassService
    let themeManager: ThemeManager
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    
    private var upcomingClasses: [GymClass] {
        let now = Date()
        let in24Hours = Calendar.current.date(byAdding: .hour, value: 24, to: now) ?? now
        
        return classService.classes.filter { gymClass in
            // Solo mostrar clases registradas por el usuario
            let isRegistered = classService.userRegistrationStatus[gymClass.id] ?? false
            let isInNext24Hours = gymClass.startTime > now && gymClass.startTime <= in24Hours
            return isRegistered && isInNext24Hours
        }.sorted { $0.startTime < $1.startTime }
        .prefix(3)
        .map { $0 }
    }
    
    var body: some View {
        if !upcomingClasses.isEmpty {
            VStack(spacing: 16) {
                HStack {
                    HStack(spacing: 8) {
                        Image(systemName: "clock.badge.exclamationmark")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundColor(Color.dynamicAccent(theme: themeManager.currentTheme))
                        
                        Text("Próximas Clases")
                            .font(.cappedDynamicSystem(size: 20, weight: .bold, maxSize: 26))
                            .foregroundColor(Color.dynamicText(theme: themeManager.currentTheme))
                    }
                    
                    Spacer()
                    
                    Text("Próximas 24h")
                        .font(.cappedDynamicSystem(size: 12, weight: .medium, maxSize: 16))
                        .foregroundColor(Color.dynamicTextSecondary(theme: themeManager.currentTheme))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(
                            Capsule()
                                .fill(Color.dynamicAccent(theme: themeManager.currentTheme).opacity(0.1))
                        )
                }
                .padding(.horizontal, 4)
                
                ZStack {
                    RoundedRectangle(cornerRadius: 16)
                        .fill(Color.dynamicSurface(theme: themeManager.currentTheme))
                        .shadow(
                            color: Color.black.opacity(themeManager.currentTheme == .dark ? 0.2 : 0.08),
                            radius: 4,
                            x: 0,
                            y: 2
                        )
                    
                    VStack(spacing: 12) {
                        ForEach(Array(upcomingClasses.enumerated()), id: \.element.id) { index, gymClass in
                            UpcomingClassRow(gymClass: gymClass, themeManager: themeManager)
                            
                            if index < upcomingClasses.count - 1 {
                                Rectangle()
                                    .fill(Color.dynamicTextSecondary(theme: themeManager.currentTheme).opacity(0.2))
                                    .frame(height: 1)
                                    .padding(.horizontal, 16)
                            }
                        }
                    }
                    .padding(16)
                }
                .padding(.horizontal, 4)
            }
        }
    }
}

// MARK: - Upcoming Class Row
struct UpcomingClassRow: View {
    let gymClass: GymClass
    let themeManager: ThemeManager
    
    private var timeFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"
        formatter.timeZone = TimeZone.current
        return formatter
    }
    
    private var timeUntilClass: String {
        let now = Date()
        let timeInterval = gymClass.startTime.timeIntervalSince(now)
        let hours = Int(timeInterval / 3600)
        let minutes = Int((timeInterval.truncatingRemainder(dividingBy: 3600)) / 60)
        
        if hours > 0 {
            return "En \(hours)h \(minutes)m"
        } else {
            return "En \(minutes)m"
        }
    }
    
    private var urgencyColor: Color {
        let now = Date()
        let timeInterval = gymClass.startTime.timeIntervalSince(now)
        let hours = timeInterval / 3600
        
        if hours <= 1 {
            return .red
        } else if hours <= 3 {
            return .orange
        } else {
            return .green
        }
    }
    
    var body: some View {
        HStack(spacing: 16) {
            // Urgency indicator
            Circle()
                .fill(urgencyColor)
                .frame(width: 8, height: 8)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(gymClass.name)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(Color.dynamicText(theme: themeManager.currentTheme))
                    .lineLimit(1)
                
                HStack(spacing: 8) {
                    Text(timeFormatter.string(from: gymClass.startTime))
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(Color.dynamicTextSecondary(theme: themeManager.currentTheme))
                    
                    Text("•")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(Color.dynamicTextSecondary(theme: themeManager.currentTheme))
                    
                    Text(gymClass.instructor)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(Color.dynamicTextSecondary(theme: themeManager.currentTheme))
                }
            }
            
            Spacer()
            
            // Time until class
            Text(timeUntilClass)
                .font(.system(size: 11, weight: .bold))
                .foregroundColor(urgencyColor)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(
                    Capsule()
                        .fill(urgencyColor.opacity(0.1))
                )
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(gymClass.name) class at \(timeFormatter.string(from: gymClass.startTime)) with \(gymClass.instructor), \(timeUntilClass)")
    }
}

// MARK: - Coach Messages Section
struct CoachMessagesSection: View {
    let themeManager: ThemeManager
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @State private var importantMessages: [CoachMessage] = []
    
    var body: some View {
        if !importantMessages.isEmpty {
            VStack(spacing: 16) {
                HStack {
                    HStack(spacing: 8) {
                        Image(systemName: "megaphone.fill")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundColor(.orange)
                        
                        Text("Mensajes del Coach")
                            .font(.cappedDynamicSystem(size: 20, weight: .bold, maxSize: 26))
                            .foregroundColor(Color.dynamicText(theme: themeManager.currentTheme))
                    }
                    
                    Spacer()
                    
                    Text("Importantes")
                        .font(.cappedDynamicSystem(size: 12, weight: .medium, maxSize: 16))
                        .foregroundColor(.orange)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(
                            Capsule()
                                .fill(Color.orange.opacity(0.1))
                        )
                }
                .padding(.horizontal, 4)
                
                ZStack {
                    RoundedRectangle(cornerRadius: 16)
                        .fill(Color.dynamicSurface(theme: themeManager.currentTheme))
                        .shadow(
                            color: Color.black.opacity(themeManager.currentTheme == .dark ? 0.2 : 0.08),
                            radius: 4,
                            x: 0,
                            y: 2
                        )
                    
                    VStack(spacing: 12) {
                        ForEach(Array(importantMessages.enumerated()), id: \.element.id) { index, message in
                            CoachMessageRow(message: message, themeManager: themeManager)
                            
                            if index < importantMessages.count - 1 {
                                Rectangle()
                                    .fill(Color.dynamicTextSecondary(theme: themeManager.currentTheme).opacity(0.2))
                                    .frame(height: 1)
                                    .padding(.horizontal, 16)
                            }
                        }
                    }
                    .padding(16)
                }
                .padding(.horizontal, 4)
            }
            .onAppear {
                loadImportantMessages()
            }
        }
    }
    
    // Mock data - esto se reemplazará con datos reales del servicio de chat
    private func loadImportantMessages() {
        // Simulación de mensajes importantes del coach
        importantMessages = [
            CoachMessage(
                id: "1",
                coachName: "Maria Rodriguez",
                message: "Mañana haremos un entrenamiento especial de resistencia. ¡Trae toalla extra!",
                timestamp: Date(),
                priority: .high,
                isUnread: true
            ),
            CoachMessage(
                id: "2", 
                coachName: "Carlos Mendez",
                message: "Recuerda hidratarte bien antes de la clase de spinning de hoy",
                timestamp: Calendar.current.date(byAdding: .hour, value: -2, to: Date()) ?? Date(),
                priority: .medium,
                isUnread: false
            )
        ]
    }
}

// MARK: - Coach Message Row
struct CoachMessageRow: View {
    let message: CoachMessage
    let themeManager: ThemeManager
    
    private var timeFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"
        formatter.timeZone = TimeZone.current
        return formatter
    }
    
    private var priorityColor: Color {
        switch message.priority {
        case .high: return .red
        case .medium: return .orange
        case .low: return .blue
        }
    }
    
    var body: some View {
        HStack(spacing: 12) {
            // Priority indicator
            Rectangle()
                .fill(priorityColor)
                .frame(width: 4, height: 40)
                .cornerRadius(2)
            
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text(message.coachName)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(Color.dynamicText(theme: themeManager.currentTheme))
                    
                    Spacer()
                    
                    Text(timeFormatter.string(from: message.timestamp))
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(Color.dynamicTextSecondary(theme: themeManager.currentTheme))
                    
                    if message.isUnread {
                        Circle()
                            .fill(Color.dynamicAccent(theme: themeManager.currentTheme))
                            .frame(width: 8, height: 8)
                    }
                }
                
                Text(message.message)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(Color.dynamicTextSecondary(theme: themeManager.currentTheme))
                    .lineLimit(3)
                    .multilineTextAlignment(.leading)
            }
        }
        .padding(.vertical, 4)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Message from \(message.coachName) at \(timeFormatter.string(from: message.timestamp)): \(message.message)")
    }
}

// MARK: - Coach Message Model
struct CoachMessage: Identifiable {
    let id: String
    let coachName: String
    let message: String
    let timestamp: Date
    let priority: MessagePriority
    let isUnread: Bool
    
    enum MessagePriority {
        case high, medium, low
    }
}

#Preview {
    ProgressDashboard(
        userStatsService: UserStatsService.shared,
        themeManager: ThemeManager(),
        eventService: EventService(),
        classService: ClassService()
    )
}