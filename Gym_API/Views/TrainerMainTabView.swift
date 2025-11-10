//
//  TrainerMainTabView.swift
//  Gym_API
//
//  Created by Claude Code on 2025-01-25
//

import SwiftUI

struct TrainerMainTabView: View {
    @EnvironmentObject var workspaceContext: WorkspaceContextService
    @EnvironmentObject var themeManager: ThemeManager
    @State private var selectedTab = 0
    @State private var previousTab = 0

    var body: some View {
        TabView(selection: $selectedTab) {
            // Dashboard
            AnimatedTabContent(isSelected: selectedTab == 0) {
                TrainerDashboardView()
            }
            .tabItem {
                Image(systemName: selectedTab == 0 ? "house.fill" : "house")
                Text("Dashboard")
            }
            .tag(0)

            // Clients (not members)
            AnimatedTabContent(isSelected: selectedTab == 1) {
                ClientsListView()
            }
            .tabItem {
                Image(systemName: selectedTab == 1 ? "person.2.fill" : "person.2")
                Text(workspaceContext.getCapitalizedTerm("members"))
            }
            .tag(1)

            // Appointments (if enabled)
            if workspaceContext.isFeatureEnabled(\.showAppointments) {
                AnimatedTabContent(isSelected: selectedTab == 2) {
                    AppointmentsView()
                }
                .tabItem {
                    Image(systemName: selectedTab == 2 ? "calendar.circle.fill" : "calendar.circle")
                    Text(workspaceContext.getCapitalizedTerm("schedule"))
                }
                .tag(2)
            }

            // Social (Messages + Feed)
            AnimatedTabContent(isSelected: selectedTab == 3) {
                SocialFeedView()
            }
            .tabItem {
                Image(systemName: selectedTab == 3 ? "message.fill" : "message")
                Text("Social")
            }
            .tag(3)

            // Profile
            AnimatedTabContent(isSelected: selectedTab == 4) {
                ModernProfileView()
            }
            .tabItem {
                Image(systemName: selectedTab == 4 ? "person.fill" : "person")
                Text("Profile")
            }
            .tag(4)
        }
        .accentColor(themeManager.currentTheme == .dark ?
                    Color(red: 0.85, green: 0.2, blue: 0.2) :
                    Color(red: 61.0/255.0, green: 190.0/255.0, blue: 208.0/255.0))
        .onChange(of: selectedTab) { oldValue, newValue in
            handleTabChange(from: oldValue, to: newValue)
        }
    }

    private func handleTabChange(from oldTab: Int, to newTab: Int) {
        // Haptic feedback
        let generator = UIImpactFeedbackGenerator(style: .light)
        generator.impactOccurred()

        previousTab = oldTab

        print("🔄 Trainer tab changed from \(oldTab) to \(newTab)")

        // Preload next probable tab
        Task {
            await PreloadService.shared.preloadNextProbableTab(from: newTab)
        }
    }
}

#Preview {
    TrainerMainTabView()
        .environmentObject(WorkspaceContextService.shared)
        .environmentObject(ThemeManager())
}
