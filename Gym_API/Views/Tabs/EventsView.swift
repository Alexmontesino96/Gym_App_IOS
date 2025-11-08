import SwiftUI

struct EventsView: View {
    @EnvironmentObject var authService: AuthServiceDirect
    @EnvironmentObject var eventService: EventService
    @EnvironmentObject var themeManager: ThemeManager
    @State private var searchText = ""
    @State private var selectedFilter: EventFilter = .available
    @State private var showingFilterSheet = false
    @State private var searchTask: Task<Void, Never>?
    @State private var showingCreateEvent = false
    @State private var selectedEventForEdit: Event?
    @State private var showingDeleteConfirmation = false
    @State private var selectedEventForDelete: Event?
    @State private var showDeleteSuccessMessage = false
    @State private var deleteSuccessMessage = ""
    @StateObject private var gymService = GymService.shared
    
    // Estados para navegación de chat desde tarjetas
    @State private var selectedEventForChat: Event?
    
    // Estado para registro masivo
    @State private var selectedEventForBulkRegistration: Event?

    // Estados para pagos
    @State private var showEventPayment = false
    @State private var currentPaymentIntent: PaymentIntent?
    @State private var currentParticipationId: Int?
    @State private var currentPaymentEvent: Event?
    @EnvironmentObject var paymentService: EventPaymentService

    var filteredEvents: [Event] {
        let searchFilteredEvents = searchText.isEmpty ? eventService.events : eventService.events.filter { event in
            event.title.localizedCaseInsensitiveContains(searchText) ||
            event.description.localizedCaseInsensitiveContains(searchText) ||
            event.location.localizedCaseInsensitiveContains(searchText)
        }
        
        switch selectedFilter {
        case .available:
            // Mostrar eventos próximos u ONGOING: status SCHEDULED o ACTIVE y que no hayan terminado
            let now = Date()
            return searchFilteredEvents.filter { ([$0.status].contains(.scheduled) || [$0.status].contains(.active)) && $0.endTime > now }
        case .past:
            // Solo eventos finalizados: por tiempo o estado COMPLETED
            let now = Date()
            return searchFilteredEvents.filter { $0.endTime <= now || $0.status == .completed }
        case .joined:
            // Usar la fuente de verdad: userRegistrationStatus
            return searchFilteredEvents.filter { event in
                eventService.userRegistrationStatus[event.id] == true
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
                                .font(.system(size: 28, weight: .bold))
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
                    
                    // Events List with FAB
                    ZStack {
                        // Scrollable Events List using OptimizedList
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
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                        } else {
                            ScrollView {
                                LazyVStack(spacing: 16) {
                                    ForEach(filteredEvents) { event in
                                        EventCard(
                                            event: event,
                                            onChatTap: {
                                                print("🎯 EventCard onChatTap ejecutado para evento: \(event.title)")
                                                handleEventChatTap(event: event)
                                            },
                                            onEditTap: {
                                                print("✏️ Edit event tapped: \(event.title)")
                                                selectedEventForEdit = event
                                            },
                                            onDeleteTap: {
                                                print("🗑️ Delete event tapped: \(event.title)")
                                                selectedEventForDelete = event
                                                showingDeleteConfirmation = true
                                            },
                                            onBulkRegistrationTap: {
                                                print("👥 Bulk registration tapped: \(event.title)")
                                                selectedEventForBulkRegistration = event
                                            },
                                            onPaymentRequired: { paymentIntent, participationId, event in
                                                print("💳 Payment required for event: \(event.title)")
                                                print("💳 PaymentIntent: amount=\(paymentIntent.amount), participationId=\(participationId)")

                                                // Set state variables and open sheet
                                                // Using capture list in sheet closure to ensure state is captured correctly
                                                print("💳 Setting payment state variables...")
                                                currentPaymentIntent = paymentIntent
                                                currentParticipationId = participationId
                                                currentPaymentEvent = event
                                                print("💳 State variables set: \(currentPaymentIntent != nil), \(currentParticipationId != nil), \(currentPaymentEvent != nil)")
                                                print("💳 Opening sheet now...")
                                                showEventPayment = true
                                            }
                                        )
                                        .padding(.horizontal, 20)
                                    }
                                }
                                .padding(.top, 8)
                                .padding(.bottom, 80)
                            }
                            .refreshable {
                                await eventService.fetchEvents()
                                await eventService.fetchUserParticipations()
                            }
                        }
                        
                        // Floating Action Button (only for trainers and above)
                        if RolePermissions.canCreateEvents(gymService.currentGym?.userRoleInGym) {
                            FABContainer(position: .bottomTrailing) {
                                FloatingActionButton(
                                    icon: "plus",
                                    themeManager: themeManager
                                ) {
                                    showingCreateEvent = true
                                }
                            }
                        }
                    }
                }
                .safeAreaPadding(.top, 16)
            }
            .sheet(isPresented: $showingFilterSheet) {
                EventFilterSheet(selectedFilter: $selectedFilter)
                    .presentationDetents([.fraction(0.6)])
                    .presentationDragIndicator(.visible)
            }
            .sheet(isPresented: $showingCreateEvent) {
                CreateEventView()
                    .environmentObject(themeManager)
                    .environmentObject(authService)
                    .environmentObject(eventService)
            }
        }
        .onAppear {
            Task {
                if eventService.events.isEmpty {
                    await eventService.fetchEvents()
                }
                await eventService.fetchUserParticipations()
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .gymChanged)) { _ in
            Task {
                await eventService.forceRefresh()
                await eventService.fetchUserParticipations()
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
        .sheet(item: $selectedEventForEdit) { event in
            EditEventView(event: event)
                .environmentObject(themeManager)
                .environmentObject(authService)
                .environmentObject(eventService)
        }
        .sheet(item: $selectedEventForBulkRegistration) { event in
            BulkRegistrationView(event: event)
                .environmentObject(themeManager)
                .environmentObject(authService)
                .environmentObject(eventService)
                .environmentObject(gymService)
        }
        .sheet(item: Binding(
            get: { currentPaymentIntent },
            set: { currentPaymentIntent = $0 }
        )) { paymentIntent in
            let _ = print("🔥 [EventsView] Sheet presenting")
            let _ = print("🔥 [EventsView] currentPaymentIntent exists: \(currentPaymentIntent != nil)")
            let _ = print("🔥 [EventsView] currentParticipationId: \(currentParticipationId ?? -1)")
            let _ = print("🔥 [EventsView] currentPaymentEvent: \(currentPaymentEvent?.title ?? "nil")")

            if let participationId = currentParticipationId,
               let event = currentPaymentEvent {
                let _ = print("🔥 [EventsView] About to create EventPaymentView")
                let _ = print("🔥 [EventsView] themeManager exists: \(String(describing: themeManager))")
                let _ = print("🔥 [EventsView] paymentService exists: \(String(describing: paymentService))")

                EventPaymentView(
                    paymentIntent: paymentIntent,
                    participationId: participationId,
                    event: event,
                    onPaymentComplete: { success in
                        currentPaymentIntent = nil
                        currentParticipationId = nil
                        currentPaymentEvent = nil

                        if success {
                            Task {
                                await eventService.fetchEvents()
                                await eventService.fetchUserParticipations()
                            }
                        }
                    }
                )
                .environmentObject(themeManager)
                .environmentObject(paymentService)
                .environmentObject(eventService)
            } else {
                let _ = print("❌ [EventsView] Sheet opened but missing participation or event data")
                let _ = print("   - participationId: \(currentParticipationId != nil)")
                let _ = print("   - event: \(currentPaymentEvent != nil)")

                Text("Error: Missing payment data")
                    .foregroundColor(.red)
                    .font(.system(size: 20, weight: .bold))
            }
        }
        .alert("Delete Event", isPresented: $showingDeleteConfirmation) {
            Button("Cancel", role: .cancel) { }
            Button("Delete", role: .destructive) {
                if let event = selectedEventForDelete {
                    Task {
                        let success = await eventService.deleteEvent(eventId: event.id)
                        if success {
                            showDeleteSuccessMessage = true
                            deleteSuccessMessage = "Event '\(event.title)' deleted successfully"
                            print("✅ Event deleted successfully")
                        } else {
                            print("❌ Failed to delete event")
                        }
                    }
                }
            }
        } message: {
            if let event = selectedEventForDelete {
                Text("Are you sure you want to delete the event '\(event.title)'? This action cannot be undone.")
            }
        }
        .alert("Success", isPresented: $showDeleteSuccessMessage) {
            Button("OK") { 
                showDeleteSuccessMessage = false
            }
        } message: {
            Text(deleteSuccessMessage)
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
