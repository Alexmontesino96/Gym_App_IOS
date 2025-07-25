import SwiftUI

struct EventsView: View {
    @EnvironmentObject var authService: AuthServiceDirect
    @EnvironmentObject var eventService: EventService
    @EnvironmentObject var themeManager: ThemeManager
    @EnvironmentObject var streamChatService: StreamChatService
    @State private var searchText = ""
    @State private var selectedFilter: EventFilter = .available
    @State private var showingFilterSheet = false
    @State private var searchTask: Task<Void, Never>?
    
    // Estados para navegación de chat desde tarjetas
    @State private var shouldNavigateToChat = false
    @State private var selectedEventForChat: Event?
    @State private var showingChat = false
    
    var filteredEvents: [Event] {
        let baseEvents = searchText.isEmpty ? eventService.events : eventService.filteredEvents
        
        switch selectedFilter {
        case .available:
            return baseEvents.filter { $0.startTime > Date() }
        case .past:
            return baseEvents.filter { $0.startTime <= Date() }
        case .joined:
            return baseEvents.filter { event in
                eventService.userParticipations.contains { $0.eventId == event.id }
            }
        }
    }
    
    var body: some View {
        NavigationView {
            ZStack {
                Color.dynamicBackground(theme: themeManager.currentTheme).ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 24) {
                        // Header
                        VStack(alignment: .leading, spacing: 16) {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Eventos")
                                    .font(.system(size: 32, weight: .bold))
                                    .foregroundColor(Color.dynamicText(theme: themeManager.currentTheme))
                                
                                Text("Connect with your community. Train together.")
                                    .font(.system(size: 16, weight: .medium))
                                    .foregroundColor(Color.dynamicTextSecondary(theme: themeManager.currentTheme))
                            }
                            .padding(.horizontal, 20)
                            
                            // Search Bar
                            HStack {
                                Image(systemName: "magnifyingglass")
                                    .foregroundColor(Color.dynamicTextSecondary(theme: themeManager.currentTheme))
                                    .font(.system(size: 16))
                                
                                TextField("Buscar eventos...", text: $searchText)
                                    .textFieldStyle(PlainTextFieldStyle())
                                    .foregroundColor(Color.dynamicText(theme: themeManager.currentTheme))
                                    .autocorrectionDisabled()
                                    .onChange(of: searchText) { _, newValue in
                                        searchTask?.cancel()
                                        searchTask = Task {
                                            try? await Task.sleep(nanoseconds: 300_000_000)
                                            await eventService.searchEvents(query: newValue)
                                        }
                                    }
                                
                                if !searchText.isEmpty {
                                    Button(action: {
                                        searchText = ""
                                    }) {
                                        Image(systemName: "xmark.circle.fill")
                                            .foregroundColor(Color.dynamicTextSecondary(theme: themeManager.currentTheme))
                                            .font(.system(size: 16))
                                    }
                                }
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 12)
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(Color.dynamicSurface(theme: themeManager.currentTheme))
                            )
                            .padding(.horizontal, 20)
                            
                            // Action Buttons
                            HStack(spacing: 16) {
                                // Refresh Button
                                Button(action: {
                                    Task { await eventService.loadEvents() }
                                }) {
                                    Image(systemName: eventService.isLoading ? "arrow.clockwise.circle.fill" : "arrow.clockwise.circle")
                                        .font(.system(size: 20))
                                        .foregroundColor(Color.dynamicAccent(theme: themeManager.currentTheme))
                                        .rotationEffect(.degrees(eventService.isLoading ? 360 : 0))
                                        .animation(eventService.isLoading ? Animation.linear(duration: 1).repeatForever(autoreverses: false) : .default, value: eventService.isLoading)
                                }
                                .disabled(eventService.isLoading)
                                
                                Spacer()
                                
                                // Filter Button
                                Button(action: {
                                    showingFilterSheet = true
                                }) {
                                    Image(systemName: "line.3.horizontal.decrease.circle")
                                        .font(.system(size: 20))
                                        .foregroundColor(Color.dynamicAccent(theme: themeManager.currentTheme))
                                }
                            }
                            .padding(.horizontal, 20)
                        }
                        
                        // Events List
                        if filteredEvents.isEmpty {
                            VStack(spacing: 16) {
                                Image(systemName: searchText.isEmpty ? "calendar.badge.exclamationmark" : "magnifyingglass")
                                    .font(.system(size: 48))
                                    .foregroundColor(Color.dynamicTextSecondary(theme: themeManager.currentTheme))
                                
                                Text(searchText.isEmpty ? "No hay eventos disponibles" : "No se encontraron eventos")
                                    .font(.system(size: 18, weight: .medium))
                                    .foregroundColor(Color.dynamicTextSecondary(theme: themeManager.currentTheme))
                                    .multilineTextAlignment(.center)
                                
                                Text(searchText.isEmpty ? "Stay tuned for new events" : "Try different search terms")
                                    .font(.system(size: 14))
                                    .foregroundColor(Color.dynamicTextSecondary(theme: themeManager.currentTheme).opacity(0.7))
                                    .multilineTextAlignment(.center)
                            }
                            .padding(.top, 40)
                        } else {
                            LazyVStack(spacing: 16) {
                                ForEach(filteredEvents) { event in
                                    EventCard(event: event, onChatTap: {
                                        handleEventChatTap(event: event)
                                    })
                                    .padding(.horizontal, 20)
                                }
                            }
                        }
                        
                        Spacer(minLength: 100)
                    }
                }
            }
            .sheet(isPresented: $showingFilterSheet) {
                EventFilterSheet(selectedFilter: $selectedFilter)
            }
        }
        .onAppear {
            Task {
                await eventService.loadEvents()
            }
        }
        .fullScreenCover(isPresented: $showingChat) {
            if let event = selectedEventForChat {
                StreamChatView(event: event)
            }
        }
    }
    
    private func handleEventChatTap(event: Event) {
        selectedEventForChat = event
        showingChat = true
    }
}

#Preview {
    EventsView()
        .environmentObject(AuthServiceDirect())
        .environmentObject(EventService())
        .environmentObject(ThemeManager())
        .environmentObject(StreamChatService.shared)
}