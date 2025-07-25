//
//  MainTabView_Safe.swift
//  Gym_API
//
//  Created by Alex Montesino on 7/14/25.
//
//  VERSIÓN SEGURA de MainTabView para evitar crashes
//  Simplificada para funcionar sin problemas con AuthServiceAPI_Safe

import SwiftUI

struct MainTabView_Safe: View {
    @EnvironmentObject var authService: AuthServiceAPI_Safe
    @EnvironmentObject var themeManager: ThemeManager
    @State private var selectedTab = 0
    
    var body: some View {
        TabView(selection: $selectedTab) {
            // Home Tab
            HomeView_Safe()
                .tabItem {
                    Image(systemName: selectedTab == 0 ? "house.fill" : "house")
                    Text("Home")
                }
                .tag(0)
            
            // Classes Tab
            ClassesView_Safe()
                .tabItem {
                    Image(systemName: selectedTab == 1 ? "dumbbell.fill" : "dumbbell")
                    Text("Classes")
                }
                .tag(1)
            
            // Events Tab
            EventsView_Safe()
                .tabItem {
                    Image(systemName: selectedTab == 2 ? "calendar.circle.fill" : "calendar.circle")
                    Text("Events")
                }
                .tag(2)
            
            // Messages Tab
            MessagesView_Safe()
                .tabItem {
                    Image(systemName: selectedTab == 3 ? "message.fill" : "message")
                    Text("Messages")
                }
                .tag(3)
            
            // Profile Tab
            ProfileView_Safe()
                .tabItem {
                    Image(systemName: selectedTab == 4 ? "person.fill" : "person")
                    Text("Profile")
                }
                .tag(4)
        }
        .accentColor(Color.dynamicAccent(theme: themeManager.currentTheme))
        .preferredColorScheme(themeManager.currentTheme == .dark ? .dark : .light)
    }
}

// MARK: - Safe Views

struct HomeView_Safe: View {
    @EnvironmentObject var themeManager: ThemeManager
    
    var body: some View {
        NavigationView {
            ZStack {
                Color.dynamicBackground(theme: themeManager.currentTheme).ignoresSafeArea()
                
                VStack(spacing: 24) {
                    // Header
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Hola, Alex.")
                                .font(.system(size: 28, weight: .bold))
                                .foregroundColor(Color.dynamicText(theme: themeManager.currentTheme))
                            
                            Text("Ready for your next class?")
                                .font(.system(size: 16, weight: .medium))
                                .foregroundColor(Color.dynamicTextSecondary(theme: themeManager.currentTheme))
                        }
                        
                        Spacer()
                        
                        Image(systemName: "figure.boxing")
                            .font(.system(size: 40))
                            .foregroundColor(Color.dynamicAccent(theme: themeManager.currentTheme))
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 20)
                    
                    // Próxima clase
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Next Class")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundColor(Color.dynamicText(theme: themeManager.currentTheme))
                            .padding(.horizontal, 20)
                        
                        HStack(spacing: 16) {
                            Image(systemName: "figure.martial.arts")
                                .font(.system(size: 24))
                                .foregroundColor(Color.dynamicAccent(theme: themeManager.currentTheme))
                                .frame(width: 40, height: 40)
                                .background(Color.dynamicAccent(theme: themeManager.currentTheme).opacity(0.2))
                                .clipShape(Circle())
                            
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Kickboxing Avanzado")
                                    .font(.system(size: 16, weight: .semibold))
                                    .foregroundColor(Color.dynamicText(theme: themeManager.currentTheme))
                                
                                Text("Hoy, 1:30 PM con Coach Laura")
                                    .font(.system(size: 14))
                                    .foregroundColor(Color.dynamicTextSecondary(theme: themeManager.currentTheme))
                            }
                            
                            Spacer()
                            
                            Image(systemName: "chevron.right")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(Color.dynamicTextSecondary(theme: themeManager.currentTheme))
                        }
                        .padding(16)
                        .background(
                            RoundedRectangle(cornerRadius: 16)
                                .fill(Color.dynamicSurface(theme: themeManager.currentTheme).opacity(0.5))
                        )
                        .padding(.horizontal, 20)
                    }
                    
                    Spacer()
                }
            }
            .navigationTitle("Home")
            .navigationBarTitleDisplayMode(.large)
        }
    }
}

struct ClassesView_Safe: View {
    @EnvironmentObject var themeManager: ThemeManager
    
    var body: some View {
        NavigationView {
            ZStack {
                Color.dynamicBackground(theme: themeManager.currentTheme).ignoresSafeArea()
                
                VStack {
                    Text("Clases")
                        .font(.title)
                        .foregroundColor(Color.dynamicText(theme: themeManager.currentTheme))
                    
                    Text("Functionality coming soon")
                        .font(.subheadline)
                        .foregroundColor(Color.dynamicTextSecondary(theme: themeManager.currentTheme))
                }
            }
            .navigationTitle("Clases")
            .navigationBarTitleDisplayMode(.large)
        }
    }
}

struct EventsView_Safe: View {
    @EnvironmentObject var authService: AuthServiceAPI_Safe
    @EnvironmentObject var themeManager: ThemeManager
    @StateObject private var eventService = EventService()
    @State private var showingEventChat = false
    @State private var selectedChatEvent: Event?
    @State private var searchText = ""
    
    var body: some View {
        NavigationView {
            ZStack {
                Color.dynamicBackground(theme: themeManager.currentTheme).ignoresSafeArea()
                
                ScrollView {
                    VStack(alignment: .leading, spacing: 24) {
                        // Header Section
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Eventos")
                                .font(.system(size: 32, weight: .bold))
                                .foregroundColor(Color.dynamicText(theme: themeManager.currentTheme))
                            
                            Text("Connect with your community. Train together.")
                                .font(.system(size: 16, weight: .medium))
                                .foregroundColor(Color.dynamicTextSecondary(theme: themeManager.currentTheme))
                        }
                        .padding(.horizontal, 20)
                        .padding(.top, 20)
                        
                        // Events List
                        if eventService.isLoading {
                            // Loading State
                            VStack(spacing: 16) {
                                ForEach(0..<3, id: \.self) { _ in
                                    EventCardSkeleton()
                                }
                            }
                            .padding(.horizontal, 20)
                        } else if eventService.events.isEmpty {
                            // Empty State
                            VStack(spacing: 16) {
                                Image(systemName: "calendar.badge.exclamationmark")
                                    .font(.system(size: 48))
                                    .foregroundColor(Color.dynamicTextSecondary(theme: themeManager.currentTheme))
                                
                                Text("No hay eventos disponibles")
                                    .font(.system(size: 18, weight: .medium))
                                    .foregroundColor(Color.dynamicTextSecondary(theme: themeManager.currentTheme))
                                
                                Text("Mantente atento a nuevos eventos")
                                    .font(.system(size: 14))
                                    .foregroundColor(Color.dynamicTextSecondary(theme: themeManager.currentTheme).opacity(0.7))
                            }
                            .padding(.vertical, 40)
                        } else {
                            // Events List
                            LazyVStack(spacing: 16) {
                                ForEach(eventService.events) { event in
                                    EventCard(event: event, eventService: eventService, onChatTapped: handleChatEvent)
                                }
                            }
                            .padding(.horizontal, 20)
                        }
                        
                        // Error Message
                        if let errorMessage = eventService.errorMessage {
                            VStack(spacing: 12) {
                                Image(systemName: "exclamationmark.triangle")
                                    .font(.system(size: 24))
                                    .foregroundColor(.yellow)
                                
                                Text("Error al cargar eventos")
                                    .font(.system(size: 16, weight: .medium))
                                    .foregroundColor(.white)
                                
                                Text(errorMessage)
                                    .font(.system(size: 14))
                                    .foregroundColor(.gray)
                                    .multilineTextAlignment(.center)
                                
                                Button("Retry") {
                                    Task {
                                        await eventService.fetchEvents()
                                    }
                                }
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(.white)
                                .padding(.horizontal, 20)
                                .padding(.vertical, 8)
                                .background(Color.dynamicAccent(theme: themeManager.currentTheme))
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                            }
                            .padding(.horizontal, 20)
                            .padding(.vertical, 20)
                        }
                    }
                    .padding(.bottom, 100) // Para el tab bar
                }
            }
            .navigationBarHidden(true)
            .background(
                NavigationLink(
                    destination: selectedChatEvent.map { event in
                        EventChatView(
                            eventId: String(event.id),
                            eventTitle: event.title,
                            authService: AuthServiceDirect() // Conversión temporal
                        )
                    },
                    isActive: $showingEventChat,
                    label: { EmptyView() }
                )
            )
        }
        .onAppear {
            Task {
                await eventService.fetchEvents()
            }
        }
    }
    
    private func handleChatEvent(_ event: Event) {
        print("💬 Chatting for event: \(event.title)")
        selectedChatEvent = event
        showingEventChat = true
    }
}

struct MessagesView_Safe: View {
    @EnvironmentObject var themeManager: ThemeManager
    
    var body: some View {
        NavigationView {
            ZStack {
                Color.dynamicBackground(theme: themeManager.currentTheme).ignoresSafeArea()
                
                VStack {
                    Text("Mensajes")
                        .font(.title)
                        .foregroundColor(Color.dynamicText(theme: themeManager.currentTheme))
                    
                    Text("Functionality coming soon")
                        .font(.subheadline)
                        .foregroundColor(Color.dynamicTextSecondary(theme: themeManager.currentTheme))
                }
            }
            .navigationTitle("Mensajes")
            .navigationBarTitleDisplayMode(.large)
        }
    }
}

struct ProfileView_Safe: View {
    @EnvironmentObject var authService: AuthServiceAPI_Safe
    @EnvironmentObject var themeManager: ThemeManager
    
    var body: some View {
        NavigationView {
            ZStack {
                Color.dynamicBackground(theme: themeManager.currentTheme).ignoresSafeArea()
                
                VStack(spacing: 24) {
                    // Información del usuario
                    VStack(spacing: 16) {
                        Image(systemName: "person.circle.fill")
                            .font(.system(size: 80))
                            .foregroundColor(Color.dynamicAccent(theme: themeManager.currentTheme))
                        
                        if let user = authService.user {
                            Text(user.name)
                                .font(.system(size: 24, weight: .bold))
                                .foregroundColor(Color.dynamicText(theme: themeManager.currentTheme))
                            
                            Text(user.email)
                                .font(.system(size: 16))
                                .foregroundColor(Color.dynamicTextSecondary(theme: themeManager.currentTheme))
                            
                            if user.isCoach {
                                Text("👨‍🏫 Coach")
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundColor(Color.dynamicAccent(theme: themeManager.currentTheme))
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 4)
                                    .background(Color.dynamicAccent(theme: themeManager.currentTheme).opacity(0.2))
                                    .clipShape(RoundedRectangle(cornerRadius: 8))
                            }
                        }
                    }
                    
                    Spacer()
                    
                    // Botón de logout
                    Button(action: {
                        Task {
                            await authService.logout()
                        }
                    }) {
                        HStack {
                            Image(systemName: "rectangle.portrait.and.arrow.right")
                                .font(.system(size: 16))
                            Text("Log Out")
                                .font(.system(size: 16, weight: .semibold))
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                        .background(themeManager.currentTheme == .dark ? Color.red : Color.red.opacity(0.8))
                        .foregroundColor(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 32)
                }
                .padding(.top, 40)
            }
            .navigationTitle("Perfil")
            .navigationBarTitleDisplayMode(.large)
        }
    }
}

#Preview {
    MainTabView_Safe()
        .environmentObject(AuthServiceAPI_Safe())
        .environmentObject(ThemeManager())
} 