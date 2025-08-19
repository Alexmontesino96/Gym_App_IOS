import SwiftUI
import Auth0

struct BulkRegistrationView: View {
    @EnvironmentObject var themeManager: ThemeManager
    @EnvironmentObject var authService: AuthServiceDirect
    @EnvironmentObject var eventService: EventService
    @EnvironmentObject var gymService: GymService
    @Environment(\.dismiss) private var dismiss

    @State private var selectableUsers: [SelectableUser] = []
    @State private var selectedUserIds: Set<Int> = []
    @State private var selectedEvent: Event?
    @State private var searchText: String = ""
    @State private var isLoading: Bool = false
    @State private var errorMessage: String?
    @State private var successMessage: String?

    var filteredUsers: [SelectableUser] {
        guard !searchText.isEmpty else { return selectableUsers }
        return selectableUsers.filter { u in
            u.name.localizedCaseInsensitiveContains(searchText) ||
            u.email.localizedCaseInsensitiveContains(searchText)
        }
    }

    // Optional preselection of event
    private let preselectedEvent: Event?

    init(event: Event? = nil) {
        self.preselectedEvent = event
    }

    private var isEventLocked: Bool { preselectedEvent != nil }

    var body: some View {
        NavigationView {
            ZStack {
                Color.dynamicBackground(theme: themeManager.currentTheme).ignoresSafeArea()

                VStack(spacing: 16) {
                    header

                    // Evento fijo (si viene preseleccionado) o selector
                    eventSection

                    // Search
                    searchBar

                    // Users list
                    if isLoading {
                        ProgressView().padding(.top, 20)
                    } else if filteredUsers.isEmpty {
                        Text("No users found")
                            .foregroundColor(Color.dynamicTextSecondary(theme: themeManager.currentTheme))
                            .padding(.top, 20)
                    } else {
                        ScrollView {
                            LazyVStack(spacing: 1) {
                                ForEach(filteredUsers) { user in
                                    modernUserRow(user)
                                }
                            }
                            .background(
                                RoundedRectangle(cornerRadius: 16)
                                    .fill(Color.dynamicSurface(theme: themeManager.currentTheme))
                            )
                        }
                    }

                    // Status messages
                    statusMessages

                    // Modern action bar
                    modernActionBar
                        .padding(.horizontal, 16)
                        .padding(.bottom, 8)
                }
                .padding(.horizontal, 16)
            }
            .navigationTitle("Register Users")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Close") { dismiss() }
                        .foregroundColor(Color.dynamicAccent(theme: themeManager.currentTheme))
                }
            }
        }
        .onAppear {
            if let ev = preselectedEvent { self.selectedEvent = ev }
            Task { await loadData() }
        }
    }

    private var header: some View {
        VStack(spacing: 12) {
            HStack {
                Text("Register Users")
                    .font(.title2.weight(.bold))
                    .foregroundColor(Color.dynamicText(theme: themeManager.currentTheme))
                
                Spacer()
                
                // Indicador visual de progreso
                if !selectedUserIds.isEmpty {
                    Text("\(selectedUserIds.count)")
                        .font(.callout.weight(.semibold))
                        .foregroundColor(.white)
                        .frame(width: 24, height: 24)
                        .background(
                            Circle().fill(Color.dynamicAccent(theme: themeManager.currentTheme))
                        )
                        .scaleEffect(selectedUserIds.isEmpty ? 0.8 : 1.1)
                        .animation(.spring(response: 0.3), value: selectedUserIds.count)
                }
            }
            
            // Event info compacta solo si está preseleccionado
            if let event = preselectedEvent {
                HStack(spacing: 8) {
                    Image(systemName: "calendar.badge.clock")
                        .font(.caption)
                        .foregroundColor(Color.dynamicAccent(theme: themeManager.currentTheme))
                    
                    Text(event.title)
                        .font(.subheadline.weight(.medium))
                        .foregroundColor(Color.dynamicTextSecondary(theme: themeManager.currentTheme))
                        .lineLimit(1)
                    
                    Spacer()
                    
                    Text("\(event.participantsCount)/\(event.maxParticipants)")
                        .font(.caption.weight(.medium))
                        .foregroundColor(Color.dynamicTextSecondary(theme: themeManager.currentTheme))
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.dynamicSurface(theme: themeManager.currentTheme))
                )
            }
        }
    }

    private var eventSection: some View {
        Group {
            if let ev = preselectedEvent ?? selectedEvent, isEventLocked {
                // Tarjeta de evento fija (no editable)
                VStack(alignment: .leading, spacing: 12) {
                    HStack(spacing: 12) {
                        Image(systemName: "calendar")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(Color.dynamicAccent(theme: themeManager.currentTheme))
                        Text(ev.title)
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(Color.dynamicText(theme: themeManager.currentTheme))
                        Spacer()
                        Image(systemName: "lock.fill")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(Color.dynamicTextSecondary(theme: themeManager.currentTheme))
                    }
                    HStack(spacing: 16) {
                        HStack(spacing: 6) {
                            Image(systemName: "clock")
                                .font(.system(size: 12))
                            Text(ev.dayTimeString)
                                .font(.system(size: 12, weight: .medium))
                        }
                        .foregroundColor(Color.dynamicTextSecondary(theme: themeManager.currentTheme))
                        HStack(spacing: 6) {
                            Image(systemName: "person.2")
                                .font(.system(size: 12))
                            Text("\(ev.participantsCount)/\(ev.maxParticipants)")
                                .font(.system(size: 12, weight: .medium))
                        }
                        .foregroundColor(Color.dynamicTextSecondary(theme: themeManager.currentTheme))
                        Spacer()
                    }
                }
                .padding(14)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.dynamicSurface(theme: themeManager.currentTheme))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Color.dynamicBorder(theme: themeManager.currentTheme), lineWidth: 0.5)
                        )
                )
            } else {
                // Fallback: selector de evento (solo si no viene preseleccionado)
                HStack {
                    Image(systemName: "calendar")
                        .foregroundColor(Color.dynamicAccent(theme: themeManager.currentTheme))
                    Picker("Evento", selection: Binding(get: {
                        selectedEvent?.id ?? -1
                    }, set: { newId in
                        selectedEvent = eventService.events.first(where: { $0.id == newId })
                        Task { await updateRegistrationStatus() }
                    })) {
                        Text("Selecciona un evento").tag(-1)
                        ForEach(eventService.events) { ev in
                            Text(ev.title).tag(ev.id)
                        }
                    }
                    .pickerStyle(.menu)
                    Spacer()
                }
            }
        }
    }

    private var searchBar: some View {
        HStack(spacing: 12) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(Color.dynamicTextSecondary(theme: themeManager.currentTheme))
            
            TextField("Search by name or email", text: $searchText)
                .textFieldStyle(.plain)
                .font(.system(size: 16))
                .foregroundColor(Color.dynamicText(theme: themeManager.currentTheme))
                .autocorrectionDisabled()
            
            if !searchText.isEmpty {
                Button(action: { 
                    withAnimation(.easeInOut(duration: 0.2)) {
                        searchText = ""
                    }
                }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 16))
                        .foregroundColor(Color.dynamicTextSecondary(theme: themeManager.currentTheme))
                }
                .transition(.scale.combined(with: .opacity))
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.dynamicSurface(theme: themeManager.currentTheme))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(
                            searchText.isEmpty ? 
                            Color.clear : 
                            Color.dynamicAccent(theme: themeManager.currentTheme).opacity(0.3),
                            lineWidth: 1
                        )
                )
        )
        .animation(.easeInOut(duration: 0.2), value: searchText.isEmpty)
    }

    private func modernUserRow(_ user: SelectableUser) -> some View {
        return HStack(spacing: 16) {
            // Avatar placeholder mejorado
            ZStack {
                Circle()
                    .fill(
                        user.isAlreadyRegistered ? 
                        Color.green.opacity(0.1) :
                        Color.dynamicAccent(theme: themeManager.currentTheme).opacity(0.1)
                    )
                    .frame(width: 44, height: 44)
                
                if user.isAlreadyRegistered {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundColor(.green)
                } else {
                    Text(String(user.name.prefix(1)).uppercased())
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(Color.dynamicAccent(theme: themeManager.currentTheme))
                }
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(user.name)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(
                        user.isAlreadyRegistered ? 
                        Color.dynamicTextSecondary(theme: themeManager.currentTheme) :
                        Color.dynamicText(theme: themeManager.currentTheme)
                    )
                
                Text(user.email)
                    .font(.system(size: 14))
                    .foregroundColor(Color.dynamicTextSecondary(theme: themeManager.currentTheme))
            }
            
            Spacer()
            
            // Estado visual mejorado
            ZStack {
                if user.isAlreadyRegistered {
                    Text("Registered")
                        .font(.caption.weight(.medium))
                        .foregroundColor(.green)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(
                            Capsule().fill(Color.green.opacity(0.1))
                        )
                } else {
                    Button(action: { toggle(user) }) {
                        Image(systemName: selectedUserIds.contains(user.id) ? 
                              "checkmark.circle.fill" : "circle")
                            .font(.system(size: 24, weight: .medium))
                            .foregroundColor(
                                selectedUserIds.contains(user.id) ? 
                                Color.dynamicAccent(theme: themeManager.currentTheme) : 
                                Color.dynamicTextSecondary(theme: themeManager.currentTheme).opacity(0.5)
                            )
                    }
                    .scaleEffect(selectedUserIds.contains(user.id) ? 1.1 : 1.0)
                    .animation(.spring(response: 0.3), value: selectedUserIds.contains(user.id))
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .contentShape(Rectangle())
        .onTapGesture { 
            withAnimation(.spring(response: 0.3)) {
                toggle(user) 
            }
        }
        .opacity(user.isAlreadyRegistered ? 0.6 : 1.0)
        .animation(.spring(response: 0.5, dampingFraction: 0.7), value: user.isAlreadyRegistered)
    }
    
    private func toggle(_ user: SelectableUser) {
        // No permitir seleccionar usuarios ya registrados
        guard !user.isAlreadyRegistered else { return }
        
        // Haptic feedback
        let impactFeedback = UIImpactFeedbackGenerator(style: .light)
        impactFeedback.impactOccurred()
        
        if selectedUserIds.contains(user.id) {
            selectedUserIds.remove(user.id)
        } else {
            selectedUserIds.insert(user.id)
        }
    }

    private var statusMessages: some View {
        VStack(spacing: 8) {
            if let error = errorMessage {
                HStack(spacing: 8) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(.red)
                    Text(error)
                        .font(.callout)
                        .foregroundColor(.red)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.red.opacity(0.1))
                )
                .transition(.scale.combined(with: .opacity))
            }
            
            if let success = successMessage {
                HStack(spacing: 8) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                    Text(success)
                        .font(.callout)
                        .foregroundColor(.green)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.green.opacity(0.1))
                )
                .transition(.scale.combined(with: .opacity))
            }
        }
        .animation(.spring(response: 0.4), value: errorMessage != nil)
        .animation(.spring(response: 0.4), value: successMessage != nil)
    }
    
    private var modernActionBar: some View {
        VStack(spacing: 16) {
            // Quick actions si hay usuarios seleccionados
            if !selectedUserIds.isEmpty {
                HStack(spacing: 12) {
                    Button("Select All") { 
                        withAnimation(.easeInOut(duration: 0.3)) {
                            selectAll(true) 
                        }
                    }
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(Color.dynamicAccent(theme: themeManager.currentTheme))
                    
                    Divider()
                        .frame(height: 16)
                    
                    Button("Clear Selection") { 
                        withAnimation(.easeInOut(duration: 0.3)) {
                            selectAll(false) 
                        }
                    }
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(Color.dynamicTextSecondary(theme: themeManager.currentTheme))
                    
                    Spacer()
                }
                .transition(.slide.combined(with: .opacity))
            }
            
            // Main CTA
            Button(action: register) {
                HStack(spacing: 12) {
                    if isLoading {
                        ProgressView()
                            .tint(.white)
                            .scaleEffect(0.8)
                    } else {
                        Image(systemName: "person.crop.circle.badge.plus")
                            .font(.system(size: 16, weight: .semibold))
                    }
                    
                    Text(isLoading ? "Registering..." : "Register \(selectedUserIds.count) user\(selectedUserIds.count == 1 ? "" : "s")")
                        .font(.system(size: 16, weight: .semibold))
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 52)
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(
                            (selectedEvent == nil || selectedUserIds.isEmpty || isLoading) ? 
                            Color.gray.opacity(0.5) : 
                            Color.dynamicAccent(theme: themeManager.currentTheme)
                        )
                )
                .scaleEffect(isLoading ? 0.98 : 1.0)
                .animation(.easeInOut(duration: 0.2), value: isLoading)
            }
            .disabled(selectedEvent == nil || selectedUserIds.isEmpty || isLoading)
        }
    }
    
    private func selectAll(_ value: Bool) {
        if value {
            // Solo seleccionar usuarios que no estén ya registrados
            selectedUserIds = Set(selectableUsers.filter { !$0.isAlreadyRegistered }.map { $0.id })
        } else {
            selectedUserIds.removeAll()
        }
    }

    private func register() {
        guard let event = selectedEvent else { return }
        let ids = Array(selectedUserIds)
        guard !ids.isEmpty else { return }
        isLoading = true
        errorMessage = nil
        successMessage = nil
        Task {
            let ok = await eventService.bulkRegisterUsersToEvent(eventId: event.id, userIds: ids)
            await MainActor.run {
                if ok {
                    successMessage = "Users registered successfully"
                    // Marcar inmediatamente como registrados a los usuarios seleccionados para una mejor respuesta visual
                    let justRegistered = Set(ids)
                    withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                        self.selectableUsers = self.selectableUsers.map { user in
                            var updated = user
                            if justRegistered.contains(user.id) {
                                updated.isAlreadyRegistered = true
                            }
                            return updated
                        }
                        // Limpiar selección
                        selectedUserIds.removeAll()
                    }
                    Task {
                        await updateRegistrationStatus()
                        await MainActor.run {
                            isLoading = false
                        }
                    }
                } else {
                    isLoading = false
                    errorMessage = eventService.joinEventErrorMessage ?? "Could not register users"
                }
            }
        }
    }

    private func updateRegistrationStatus() async {
        guard let targetEvent = selectedEvent else { return }
        
        print("🔄 Actualizando estado de registración después del registro masivo...")
        
        // Recargar las participaciones del evento
        await eventService.fetchEventParticipations(eventId: targetEvent.id)
        
        let registeredUserIds = eventService.eventParticipations
            .filter { $0.eventId == targetEvent.id }
            .map { $0.memberId }
        
        // Actualizar la lista de usuarios seleccionables
        await MainActor.run {
            self.selectableUsers = self.selectableUsers.map { user in
                var updatedUser = user
                updatedUser.isAlreadyRegistered = registeredUserIds.contains(user.id)
                return updatedUser
            }
        }
        
        print("✅ Estado de registración actualizado")
    }

    private func loadData() async {
        isLoading = true
        errorMessage = nil
        
        print("🔄 BulkRegistrationView: Iniciando carga de datos...")
        
        // Ensure events are loaded
        if eventService.events.isEmpty {
            print("📅 Cargando eventos...")
            await eventService.fetchEvents()
        }
        
        // Configurar el servicio de usuarios del gym
        GymUserService.shared.authService = authService
        
        // Try real endpoint; fallback to mock
        if let real = await GymUserService.shared.fetchUsersForCurrentGym() {
            print("✅ Usuarios reales obtenidos: \(real.count)")
            
            // Marcar usuarios ya registrados si hay un evento seleccionado
            let updatedUsers = await markAlreadyRegisteredUsers(users: real)
            
            await MainActor.run {
                self.selectableUsers = updatedUsers
                self.isLoading = false
            }
        } else {
            print("⚠️ Usando usuarios mock...")
            let mock = await makeMockUsers()
            await MainActor.run {
                self.selectableUsers = mock
                self.isLoading = false
            }
        }
    }
    
    private func markAlreadyRegisteredUsers(users: [SelectableUser]) async -> [SelectableUser] {
        guard let targetEvent = selectedEvent ?? preselectedEvent else {
            return users
        }
        
        print("🔍 Verificando usuarios ya registrados en evento \(targetEvent.id)...")
        
        // Obtener participaciones del evento si no están cargadas
        await eventService.fetchEventParticipations(eventId: targetEvent.id)
        
        let registeredUserIds = eventService.eventParticipations
            .filter { $0.eventId == targetEvent.id }
            .map { $0.memberId }
        
        print("👥 Usuarios ya registrados: \(registeredUserIds)")
        
        return users.map { user in
            var updatedUser = user
            updatedUser.isAlreadyRegistered = registeredUserIds.contains(user.id)
            if updatedUser.isAlreadyRegistered {
                print("✅ Usuario \(user.name) (ID: \(user.id)) ya está registrado")
            }
            return updatedUser
        }
    }

    private func makeMockUsers() async -> [SelectableUser] {
        let names = [
            (1, "Ana Pérez", "ana@gym.com"),
            (2, "Luis Gómez", "luis@gym.com"),
            (3, "María López", "maria@gym.com"),
            (4, "Carlos Ruiz", "carlos@gym.com"),
            (5, "Sofía Díaz", "sofia@gym.com")
        ]
        return names.map { SelectableUser(id: $0.0, name: $0.1, email: $0.2, role: "MEMBER", profilePicture: nil) }
    }
}

#Preview {
    BulkRegistrationView()
        .environmentObject(ThemeManager())
        .environmentObject(AuthServiceDirect())
        .environmentObject(EventService())
        .environmentObject(GymService.shared)
}
