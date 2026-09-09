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
    @Environment(\.scenePhase) private var scenePhase
    @State private var selectedTab = 0
    @State private var previousTab = 0

    var body: some View {
        TabView(selection: $selectedTab) {
            // Dashboard
            AnimatedTabContent(isSelected: selectedTab == 0) {
                TrainerDashboardView(
                    onGoToClients: { selectedTab = 1 },
                    onGoToMessages: { selectedTab = 3 }
                )
            }
            .tabItem {
                Image(systemName: selectedTab == 0 ? "house.fill" : "house")
                Text("Dashboard")
            }
            .tag(0)

            // Clients (not members)
            AnimatedTabContent(isSelected: selectedTab == 1) {
                ClientsListView(onGoToMessages: { selectedTab = 3 })
            }
            .tabItem {
                Image(systemName: selectedTab == 1 ? "person.2.fill" : "person.2")
                Text(workspaceContext.getCapitalizedTerm("members"))
            }
            .tag(1)

            if workspaceContext.showsPTEvents {
                CoachingEventsView(isCoach: true)
                    .tabItem {
                        Image(systemName: selectedTab == 2 ? "calendar.circle.fill" : "calendar.circle")
                        Text("Events")
                    }
                    .tag(2)
            }

            // Social (Messages + Feed)
            AnimatedTabContent(isSelected: selectedTab == 3) {
                SocialFeedView(pendingEventChat: .constant(nil), showsFeed: false, initialTab: .chats)
            }
            .tabItem {
                Image(systemName: selectedTab == 3 ? "message.fill" : "message")
                Text("Messages")
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
        // Antes fijaba rojo o cian e ignoraba el acento que el entrenador elige en el tema,
        // que es justo lo que hace suya la app en un producto de marca personal.
        .accentColor(Color.dynamicAccent(theme: themeManager.currentTheme))
        .onChange(of: workspaceContext.showsPTEvents) { _, enabled in
            if !enabled && selectedTab == 2 { selectedTab = 0 }
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { Task { await workspaceContext.fetchContext(forceRefresh: true) } }
        }
        .onChange(of: selectedTab) { oldValue, newValue in
            handleTabChange(from: oldValue, to: newValue)
        }
        .onReceive(NotificationCenter.default.publisher(for: .trainingOpenLog)) { _ in
            // El deep link `training/logs/{id}` abre S22, que vive en la pila del panel. Aquí
            // solo se cambia de pestaña; el panel escucha el mismo aviso y empuja la pantalla.
            selectedTab = 0
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
