import SwiftUI

struct EventsView: View {
    @EnvironmentObject var authService: AuthServiceDirect
    @EnvironmentObject var eventService: EventService
    @EnvironmentObject var themeManager: ThemeManager
    @State private var searchText = ""
    @State private var selectedFilter: EventFilter = .available
    @State private var showingFilterSheet = false
    @State private var searchTask: Task<Void, Never>?
    
    // Estados para navegación de chat desde tarjetas
    @State private var selectedEventForChat: Event?
    
    var filteredEvents: [Event] {
        let searchFilteredEvents = searchText.isEmpty ? eventService.events : eventService.events.filter { event in
            event.title.localizedCaseInsensitiveContains(searchText) ||
            event.description.localizedCaseInsensitiveContains(searchText) ||
            event.location.localizedCaseInsensitiveContains(searchText)
        }
        
        switch selectedFilter {
        case .available:
            return searchFilteredEvents.filter { $0.startTime > Date() }
        case .past:
            return searchFilteredEvents.filter { $0.startTime <= Date() }
        case .joined:
            return searchFilteredEvents.filter { event in
                eventService.userParticipations.contains { $0.eventId == event.id }
            }
        }
    }
    
    var body: some View {
        NavigationView {
            ZStack {
                Color.dynamicBackground(theme: themeManager.currentTheme).ignoresSafeArea()
                
                VStack(spacing: 0) {
                    // Fixed Header
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
                        
                        // Search Bar with Filter Button
                        HStack(spacing: 12) {
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
                                            // TODO: Implement search functionality
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
                            
                            // Filter Button
                            Button(action: {
                                showingFilterSheet = true
                            }) {
                                Image(systemName: "line.3.horizontal.decrease.circle")
                                    .font(.system(size: 20))
                                    .foregroundColor(Color.dynamicAccent(theme: themeManager.currentTheme))
                            }
                            .padding(.vertical, 12)
                        }
                        .padding(.horizontal, 20)
                    }
                    .padding(.bottom, 16)
                    .background(Color.dynamicBackground(theme: themeManager.currentTheme))
                    
                    // Scrollable Events List
                    ScrollView {
                        LazyVStack(spacing: 16) {
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
                                ForEach(filteredEvents) { event in
                                    EventCard(event: event, onChatTap: {
                                        print("🎯 EventCard onChatTap ejecutado para evento: \(event.title)")
                                        handleEventChatTap(event: event)
                                    })
                                    .padding(.horizontal, 20)
                                }
                            }
                            
                            Spacer(minLength: 100)
                        }
                        .padding(.top, 8)
                    }
                    .refreshable {
                        await eventService.fetchEvents()
                    }
                }
            }
            .sheet(isPresented: $showingFilterSheet) {
                EventFilterSheet(selectedFilter: $selectedFilter)
                    .presentationDetents([.fraction(0.6)])
                    .presentationDragIndicator(.visible)
            }
        }
        .onAppear {
            Task {
                await eventService.fetchEvents()
            }
        }
        .sheet(item: $selectedEventForChat) { event in
            let _ = print("🔥 sheet activated for event: \(event.title) (ID: \(event.id))")
            EventChatView(
                eventId: String(event.id),
                eventTitle: event.title,
                authService: authService
            )
            .environmentObject(themeManager)
        }
    }
    
    private func handleEventChatTap(event: Event) {
        print("🔥 handleEventChatTap called for event: \(event.title) (ID: \(event.id))")
        
        // Usar selectedEventForChat para el sheet
        selectedEventForChat = event
        print("🔥 selectedEventForChat set to: \(selectedEventForChat?.title ?? "nil")")
    }
}

#Preview {
    EventsView()
        .environmentObject(AuthServiceDirect())
        .environmentObject(EventService())
        .environmentObject(ThemeManager())
}