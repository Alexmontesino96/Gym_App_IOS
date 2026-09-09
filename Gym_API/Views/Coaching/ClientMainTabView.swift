//
//  ClientMainTabView.swift
//  Gym_API
//
//  Shell de navegación del CLIENTE de un entrenador personal.
//
//  Es la tercera raíz de la app, junto a MainTabView (gimnasio tradicional) y
//  TrainerMainTabView (el entrenador). Hasta la fase 1 del plan, un cliente de entrenador
//  aterrizaba en la vista del ENTRENADOR: cartera de clientes, ingresos y retención,
//  además con datos de ejemplo. Ver PLAN_MODO_CLIENTE_PT.md.
//
//  A diferencia de las otras dos raíces, esta usa el acento configurable del ThemeManager
//  en lugar de fijar un color, para que la app respete la identidad elegida.
//

import SwiftUI

struct ClientMainTabView: View {
    @EnvironmentObject var themeManager: ThemeManager
    @EnvironmentObject var workspaceContext: WorkspaceContextService
    @Environment(\.scenePhase) private var scenePhase
    @StateObject private var profileService = UserProfileService.shared
    @StateObject private var unreadCountService = UnreadCountService.shared

    @State private var selectedTab: Tab = .home
    @State private var showQRCode = false
    @State private var showNutrition = false
    @State private var pendingEventChat: Event?

    private enum Tab: Hashable {
        case home, sessions, events, messages, profile
    }

    var body: some View {
        TabView(selection: $selectedTab) {
            AnimatedTabContent(isSelected: selectedTab == .home) {
                CoachHomeView(
                    onOpenSessions: { selectedTab = .sessions },
                    onOpenCoachChat: { selectedTab = .messages },
                    onOpenNutrition: { showNutrition = true },
                    onShowQR: { showQRCode = true },
                    onOpenNotifications: { selectedTab = .messages },
                    onOpenProfile: { selectedTab = .profile }
                )
            }
            .tabItem {
                Image(systemName: selectedTab == .home ? "house.fill" : "house")
                Text("Home")
            }
            .tag(Tab.home)

            AnimatedTabContent(isSelected: selectedTab == .sessions) {
                ClientSessionsView(onAskCoach: { selectedTab = .messages })
            }
            .tabItem {
                Image(systemName: selectedTab == .sessions ? "figure.strengthtraining.traditional" : "figure.walk")
                Text("Sessions")
            }
            .tag(Tab.sessions)

            if workspaceContext.showsPTEvents {
                CoachingEventsView(isCoach: false)
                    .tabItem {
                        Image(systemName: selectedTab == .events ? "calendar.circle.fill" : "calendar.circle")
                        Text("Events")
                    }
                    .tag(Tab.events)
            }

            AnimatedTabContent(isSelected: selectedTab == .messages) {
                SocialFeedView(pendingEventChat: $pendingEventChat, showsFeed: false, initialTab: .chats, singleContact: true)
            }
            .tabItem {
                Image(systemName: selectedTab == .messages ? "message.fill" : "message")
                Text("Messages")
            }
            .badge(unreadCountService.totalUnreadCount > 0 ? unreadCountService.totalUnreadCount : 0)
            .tag(Tab.messages)

            AnimatedTabContent(isSelected: selectedTab == .profile) {
                ModernProfileView()
            }
            .tabItem {
                Image(systemName: selectedTab == .profile ? "person.fill" : "person")
                Text("Profile")
            }
            .tag(Tab.profile)
        }
        .accentColor(Color.dynamicAccent(theme: themeManager.currentTheme))
        .onChange(of: workspaceContext.showsPTEvents) { _, enabled in
            if !enabled && selectedTab == .events { selectedTab = .home }
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { Task { await workspaceContext.fetchContext(forceRefresh: true) } }
        }
        .onChange(of: selectedTab) { _, _ in
            HapticManager.shared.buttonTap()
        }
        .onReceive(NotificationCenter.default.publisher(for: .trainingOpenLog)) { _ in
            // El deep link `training/logs/{id}` abre el resumen, que vive en la pila de Home.
            // Aquí solo se cambia de pestaña; la home escucha el mismo aviso y presenta S18.
            selectedTab = .home
        }
        .sheet(isPresented: $showQRCode) {
            QRCodeSheet(
                qrCode: profileService.userProfile?.qrCode,
                userName: profileService.userProfile?.fullName
            )
            .environmentObject(themeManager)
        }
        .sheet(isPresented: $showNutrition) {
            NavigationStack {
                PlansListView()
                    .environmentObject(themeManager)
                    .environmentObject(NutritionService.shared)
            }
        }
    }
}
