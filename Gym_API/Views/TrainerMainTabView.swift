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
                ClientsListView()
            }
            .tabItem {
                Image(systemName: selectedTab == 1 ? "person.2.fill" : "person.2")
                Text(workspaceContext.getCapitalizedTerm("members"))
            }
            .tag(1)

            // La pestaña de agenda se retiró: eran 569 líneas de interfaz sin backend detrás,
            // con un formulario cuyo botón «Save» descartaba lo que el usuario acababa de
            // escribir. Vuelve en el tramo 6 del módulo de entrenamiento, cuando exista la
            // entidad de cita. El hueco del tag 2 se deja a propósito para no renumerar el
            // resto de pestañas ni la preferencia guardada de nadie.

            // Social (Messages + Feed)
            AnimatedTabContent(isSelected: selectedTab == 3) {
                SocialFeedView(pendingEventChat: .constant(nil), showsFeed: false, initialTab: .chats)
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
        // Antes fijaba rojo o cian e ignoraba el acento que el entrenador elige en el tema,
        // que es justo lo que hace suya la app en un producto de marca personal.
        .accentColor(Color.dynamicAccent(theme: themeManager.currentTheme))
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
