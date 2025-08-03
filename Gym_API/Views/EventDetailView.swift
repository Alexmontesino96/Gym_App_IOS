import SwiftUI
import MapKit


struct EventDetailView: View {
    @EnvironmentObject var authService: AuthServiceDirect
    @EnvironmentObject var eventService: EventService
    @EnvironmentObject var themeManager: ThemeManager
    @Environment(\.dismiss) private var dismiss
    
    let eventId: Int
    @State private var initialRegistrationState: Bool?
    
    var body: some View {
        ZStack {
                Color.dynamicBackground(theme: themeManager.currentTheme).ignoresSafeArea()
                
                if eventService.isLoadingDetail {
                    ModernLoadingView()
                } else if let eventDetail = eventService.eventDetail {
                    EventDetailContent(
                        eventDetail: eventDetail, 
                        eventService: eventService, 
                        authService: authService,
                        initialRegistrationState: initialRegistrationState
                    )
                } else if let errorMessage = eventService.detailErrorMessage {
                    ModernErrorView(
                        message: errorMessage,
                        onRetry: {
                            Task {
                                await eventService.fetchEventDetail(eventId: eventId)
                            }
                        }
                    )
                } else {
                    EmptyView()
                }
            }
        .navigationTitle("Event")
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button(action: { dismiss() }) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(Color.dynamicAccent(theme: themeManager.currentTheme))
                }
            }
        }
        .onAppear {
            // Capturar el estado inicial antes de cargar
            initialRegistrationState = eventService.isUserRegistered(eventId: eventId)
            
            eventService.authService = authService
            Task {
                await eventService.fetchEventDetailData(eventId: eventId)
            }
        }
    }
}

struct EventDetailContent: View {
    @EnvironmentObject var themeManager: ThemeManager
    let eventDetail: EventDetail
    @ObservedObject var eventService: EventService
    let authService: AuthServiceDirect
    let initialRegistrationState: Bool?
    @State private var showingEventChat = false
    @State private var selectedChatEvent: Event?
    @State private var currentRegistrationState: Bool?
    @State private var shakeOffset: CGFloat = 0
    
    var body: some View {
        ScrollView(showsIndicators: false) {
            LazyVStack(alignment: .leading, spacing: 20) {
                // Event Header Card (now includes image)
                EventHeaderCard(eventDetail: eventDetail)
                
                // Description Section - Moved after image
                if !eventDetail.description.isEmpty {
                    EventDescriptionSection(description: eventDetail.description)
                }
                
                // Event Details Section
                EventDetailsSection(eventDetail: eventDetail)
                
                // Action Buttons Section
                EventActionButtons(
                    eventDetail: eventDetail,
                    eventService: eventService,
                    authService: authService,
                    currentRegistrationState: $currentRegistrationState,
                    shakeOffset: $shakeOffset,
                    showingEventChat: $showingEventChat,
                    selectedChatEvent: $selectedChatEvent
                )
                
                // Participants Section
                if currentRegistrationState ?? eventService.isUserRegistered(eventId: eventDetail.id) {
                    ParticipantsSection(eventService: eventService)
                }
                
                // Error message for join event
                if let joinError = eventService.joinEventErrorMessage {
                    ErrorMessageCard(message: joinError)
                }
                
                // Bottom spacing
                Spacer(minLength: 80)
            }
            .padding(.horizontal, 16)
        }
        .offset(x: shakeOffset)
        .background(
            NavigationLink(
                destination: selectedChatEvent.map { event in
                    EventChatView(
                        eventId: String(event.id),
                        eventTitle: event.title,
                        authService: authService
                    )
                },
                isActive: $showingEventChat,
                label: { EmptyView() }
            )
        )
        .onAppear {
            // Inicializar el estado actual con el estado inicial si está disponible
            if currentRegistrationState == nil {
                currentRegistrationState = initialRegistrationState
            }
        }
        .onChange(of: eventService.userRegistrationStatus[eventDetail.id]) {
            // Actualizar el estado cuando cambie en el servicio
            if let newRegistrationState = eventService.userRegistrationStatus[eventDetail.id] {
                currentRegistrationState = newRegistrationState
            }
        }
    }
    
    // Función para crear el efecto de sacudida
    private func shakeView() {
        withAnimation(.easeInOut(duration: 0.1)) {
            shakeOffset = -8
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            withAnimation(.easeInOut(duration: 0.1)) {
                shakeOffset = 8
            }
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            withAnimation(.easeInOut(duration: 0.1)) {
                shakeOffset = -4
            }
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            withAnimation(.easeInOut(duration: 0.1)) {
                shakeOffset = 4
            }
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
            withAnimation(.easeInOut(duration: 0.1)) {
                shakeOffset = 0
            }
        }
    }
}

// MARK: - Modern Components

struct EventHeaderCard: View {
    @EnvironmentObject var themeManager: ThemeManager
    let eventDetail: EventDetail
    
    var body: some View {
        VStack(spacing: 20) {
            // Status Badge and Title Section
            VStack(spacing: 12) {
                HStack {
                    EventStatusBadge(status: eventDetail.status)
                    Spacer()
                }
                
                HStack {
                    Text(eventDetail.title)
                        .font(.system(size: 28, weight: .bold))
                        .foregroundColor(Color.dynamicText(theme: themeManager.currentTheme))
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                    Spacer()
                }
            }
            
            // Event Image - Now more prominent
            ModernEventImageView()
        }
        .padding(20)
    }
}

struct EventStatusBadge: View {
    @EnvironmentObject var themeManager: ThemeManager
    let status: EventStatus
    
    var body: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(statusColor)
                .frame(width: 6, height: 6)
            
            Text(statusText)
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(statusColor)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(statusColor.opacity(0.08))
        .clipShape(Capsule())
    }
    
    private var statusColor: Color {
        switch status {
        case .scheduled: return .blue
        case .active: return .green
        case .completed: return .gray
        case .cancelled: return .red
        }
    }
    
    private var statusText: String {
        switch status {
        case .scheduled: return "Programado"
        case .active: return "Activo"
        case .completed: return "Completado"
        case .cancelled: return "Cancelado"
        }
    }
}

struct ModernEventImageView: View {
    @EnvironmentObject var themeManager: ThemeManager
    
    var body: some View {
        ZStack {
            // Simple background
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.dynamicSurface(theme: themeManager.currentTheme).opacity(0.05))
                .frame(height: 200)
            
            // Minimal icon
            Image(systemName: "calendar")
                .font(.system(size: 28, weight: .ultraLight))
                .foregroundColor(Color.dynamicAccent(theme: themeManager.currentTheme).opacity(0.6))
        }
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.dynamicSurface(theme: themeManager.currentTheme).opacity(0.1), lineWidth: 0.5)
        )
    }
}


struct EventDetailsSection: View {
    @EnvironmentObject var themeManager: ThemeManager
    let eventDetail: EventDetail
    
    var body: some View {
        VStack(spacing: 16) {
            // Location
            DetailRow(
                icon: "location",
                title: "Location",
                value: eventDetail.location
            )
            
            // Date and Time
            DetailRow(
                icon: "calendar",
                title: "Date & Time",
                value: eventDetail.dayTimeString
            )
            
            // Participants
            DetailRow(
                icon: "person.2",
                title: "Participants",
                value: "\(eventDetail.participantsCount)/\(eventDetail.maxParticipants)"
            )
        }
        .padding(.horizontal, 20)
    }
}

struct DetailRow: View {
    @EnvironmentObject var themeManager: ThemeManager
    let icon: String
    let title: String
    let value: String
    
    var body: some View {
        HStack(spacing: 12) {
            // Icon
            Image(systemName: icon)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(Color.dynamicTextSecondary(theme: themeManager.currentTheme))
                .frame(width: 20, height: 20)
            
            // Content
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(Color.dynamicTextSecondary(theme: themeManager.currentTheme))
                
                Text(value)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(Color.dynamicText(theme: themeManager.currentTheme))
            }
            
            Spacer()
        }
    }
}

struct EventDescriptionSection: View {
    @EnvironmentObject var themeManager: ThemeManager
    let description: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Description")
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(Color.dynamicTextSecondary(theme: themeManager.currentTheme))
            
            Text(description)
                .font(.system(size: 15, weight: .regular))
                .foregroundColor(Color.dynamicText(theme: themeManager.currentTheme))
                .lineSpacing(2)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.horizontal, 20)
    }
}

struct EventActionButtons: View {
    @EnvironmentObject var themeManager: ThemeManager
    let eventDetail: EventDetail
    @ObservedObject var eventService: EventService
    let authService: AuthServiceDirect
    @Binding var currentRegistrationState: Bool?
    @Binding var shakeOffset: CGFloat
    @Binding var showingEventChat: Bool
    @Binding var selectedChatEvent: Event?
    
    var body: some View {
        VStack(spacing: 12) {
            // Main Action Button
            Button(action: {
                if eventDetail.status == .completed {
                    shakeView()
                    return
                }
                
                Task {
                    let wasRegistered = currentRegistrationState ?? eventService.isUserRegistered(eventId: eventDetail.id)
                    
                    if wasRegistered {
                        await eventService.cancelEvent(eventId: eventDetail.id)
                    } else {
                        await eventService.joinEvent(eventId: eventDetail.id)
                    }
                    
                    currentRegistrationState = eventService.isUserRegistered(eventId: eventDetail.id)
                }
            }) {
                HStack(spacing: 12) {
                    if eventService.isJoiningEvent {
                        LoadingDotsView()
                    } else {
                        Image(systemName: getButtonIcon(for: eventDetail))
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.white)
                        
                        Text(getButtonText(for: eventDetail))
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.white)
                    }
                }
                .frame(maxWidth: .infinity)
                .frame(height: 48)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(getButtonColor(for: eventDetail))
                )
            }
            .disabled(shouldDisableButton(for: eventDetail) || eventService.isJoiningEvent)
            
            // Chat Button
            if currentRegistrationState ?? eventService.isUserRegistered(eventId: eventDetail.id) {
                Button(action: {
                    selectedChatEvent = Event(
                        id: eventDetail.id,
                        title: eventDetail.title,
                        description: eventDetail.description,
                        startTime: Date(),
                        endTime: Date().addingTimeInterval(3600),
                        location: eventDetail.location,
                        maxParticipants: eventDetail.maxParticipants,
                        status: eventDetail.status,
                        creatorId: 0,
                        createdAt: Date(),
                        updatedAt: Date(),
                        participantsCount: eventDetail.participantsCount
                    )
                    showingEventChat = true
                }) {
                    HStack(spacing: 12) {
                        Image(systemName: "bubble.left")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(Color.dynamicText(theme: themeManager.currentTheme))
                        
                        Text("Event Chat")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(Color.dynamicText(theme: themeManager.currentTheme))
                        
                        Spacer()
                        
                        Image(systemName: "chevron.right")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(Color.dynamicTextSecondary(theme: themeManager.currentTheme))
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 48)
                    .padding(.horizontal, 16)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color.dynamicSurface(theme: themeManager.currentTheme).opacity(0.05))
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(Color.dynamicSurface(theme: themeManager.currentTheme).opacity(0.1), lineWidth: 1)
                            )
                    )
                }
            }
        }
        .padding(.horizontal, 20)
    }
    
    private func shakeView() {
        withAnimation(.easeInOut(duration: 0.1)) {
            shakeOffset = -8
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            withAnimation(.easeInOut(duration: 0.1)) {
                shakeOffset = 8
            }
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            withAnimation(.easeInOut(duration: 0.1)) {
                shakeOffset = -4
            }
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            withAnimation(.easeInOut(duration: 0.1)) {
                shakeOffset = 4
            }
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
            withAnimation(.easeInOut(duration: 0.1)) {
                shakeOffset = 0
            }
        }
    }
    
    private func getButtonColor(for eventDetail: EventDetail) -> Color {
        switch eventDetail.status {
        case .completed:
            return Color.gray.opacity(0.6)
        case .cancelled:
            return Color.orange.opacity(0.6)
        case .scheduled, .active:
            if currentRegistrationState ?? eventService.isUserRegistered(eventId: eventDetail.id) {
                return themeManager.currentTheme == .light ? .red.opacity(0.8) : Color(red: 0.15, green: 0.15, blue: 0.15)
            } else if eventDetail.isFullyBooked {
                return Color(red: 0.15, green: 0.15, blue: 0.15)
            } else {
                return Color.dynamicAccent(theme: themeManager.currentTheme)
            }
        }
    }
    
    private func getButtonIcon(for eventDetail: EventDetail) -> String {
        switch eventDetail.status {
        case .completed:
            return "checkmark.circle.fill"
        case .cancelled:
            return "xmark.circle.fill"
        case .scheduled, .active:
            if currentRegistrationState ?? eventService.isUserRegistered(eventId: eventDetail.id) {
                return "xmark"
            } else if eventDetail.isFullyBooked {
                return "person.fill.xmark"
            } else {
                return "person.fill.checkmark"
            }
        }
    }
    
    private func getButtonText(for eventDetail: EventDetail) -> String {
        switch eventDetail.status {
        case .completed:
            let isRegistered = currentRegistrationState ?? eventService.isUserRegistered(eventId: eventDetail.id)
            return isRegistered ? "Completado - Participaste" : "Evento Completado"
        case .cancelled:
            return "Evento Cancelado"
        case .scheduled, .active:
            if currentRegistrationState ?? eventService.isUserRegistered(eventId: eventDetail.id) {
                return "Cancelar Registro"
            } else if eventDetail.isFullyBooked {
                return "Evento Lleno"
            } else {
                return "Unirse (\(eventDetail.participantsCount)/\(eventDetail.maxParticipants))"
            }
        }
    }
    
    private func shouldDisableButton(for eventDetail: EventDetail) -> Bool {
        let isRegistered = currentRegistrationState ?? eventService.isUserRegistered(eventId: eventDetail.id)
        return eventDetail.status == .cancelled ||
               (!isRegistered && eventDetail.isFullyBooked)
    }
}

struct LoadingDotsView: View {
    @State private var isAnimating = false
    
    var body: some View {
        HStack(spacing: 4) {
            ForEach(0..<3) { index in
                Circle()
                    .fill(Color.white)
                    .frame(width: 8, height: 8)
                    .opacity(0.7)
                    .scaleEffect(isAnimating ? 1.3 : 0.8)
                    .animation(
                        Animation.easeInOut(duration: 0.5)
                            .repeatForever()
                            .delay(Double(index) * 0.15),
                        value: isAnimating
                    )
            }
        }
        .onAppear { isAnimating = true }
        .onDisappear { isAnimating = false }
    }
}

struct ErrorMessageCard: View {
    @EnvironmentObject var themeManager: ThemeManager
    let message: String
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 16))
                .foregroundColor(.red)
            
            Text(message)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.red)
                .lineLimit(nil)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.red.opacity(0.1))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.red.opacity(0.3), lineWidth: 1)
                )
        )
    }
}

struct ModernLoadingView: View {
    @EnvironmentObject var themeManager: ThemeManager
    @State private var isAnimating = false
    
    var body: some View {
        VStack(spacing: 24) {
            // Loading animation
            ZStack {
                Circle()
                    .stroke(Color.dynamicAccent(theme: themeManager.currentTheme).opacity(0.2), lineWidth: 4)
                    .frame(width: 60, height: 60)
                
                Circle()
                    .trim(from: 0, to: 0.7)
                    .stroke(Color.dynamicAccent(theme: themeManager.currentTheme), style: StrokeStyle(lineWidth: 4, lineCap: .round))
                    .frame(width: 60, height: 60)
                    .rotationEffect(Angle(degrees: isAnimating ? 360 : 0))
                    .animation(Animation.linear(duration: 1).repeatForever(autoreverses: false), value: isAnimating)
            }
            
            Text("Cargando evento...")
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(Color.dynamicTextSecondary(theme: themeManager.currentTheme))
        }
        .onAppear { isAnimating = true }
        .onDisappear { isAnimating = false }
    }
}

struct ModernErrorView: View {
    @EnvironmentObject var themeManager: ThemeManager
    let message: String
    let onRetry: () -> Void
    
    var body: some View {
        VStack(spacing: 24) {
            // Error icon
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 48))
                .foregroundColor(.red)
            
            VStack(spacing: 12) {
                Text("Error")
                    .font(.system(size: 24, weight: .bold))
                    .foregroundColor(Color.dynamicText(theme: themeManager.currentTheme))
                
                Text(message)
                    .font(.system(size: 16))
                    .foregroundColor(Color.dynamicTextSecondary(theme: themeManager.currentTheme))
                    .multilineTextAlignment(.center)
                    .lineLimit(nil)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.horizontal, 40)
            
            Button(action: onRetry) {
                HStack(spacing: 12) {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 16, weight: .semibold))
                    Text("Retry")
                        .font(.system(size: 16, weight: .semibold))
                }
                .foregroundColor(.white)
                .padding(.horizontal, 24)
                .padding(.vertical, 12)
                .background(Color.dynamicAccent(theme: themeManager.currentTheme))
                .clipShape(Capsule())
            }
        }
        .padding(40)
    }
}

// MARK: - Legacy Components (kept for compatibility)

struct MapPlaceholder: View {
    var body: some View {
        ZStack {
            // Background map style
            RoundedRectangle(cornerRadius: 16)
                .fill(
                    LinearGradient(
                        colors: [Color.blue.opacity(0.2), Color.green.opacity(0.2)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
            
            // Grid lines to simulate map
            VStack(spacing: 0) {
                ForEach(0..<8) { _ in
                    Rectangle()
                        .fill(Color.white.opacity(0.1))
                        .frame(height: 1)
                    Spacer()
                }
            }
            
            HStack(spacing: 0) {
                ForEach(0..<6) { _ in
                    Rectangle()
                        .fill(Color.white.opacity(0.1))
                        .frame(width: 1)
                    Spacer()
                }
            }
            
            // Simulated route
            Path { path in
                path.move(to: CGPoint(x: 50, y: 150))
                path.addCurve(
                    to: CGPoint(x: 250, y: 100),
                    control1: CGPoint(x: 120, y: 80),
                    control2: CGPoint(x: 180, y: 60)
                )
                path.addCurve(
                    to: CGPoint(x: 300, y: 80),
                    control1: CGPoint(x: 270, y: 90),
                    control2: CGPoint(x: 285, y: 85)
                )
            }
            .stroke(Color.red, style: StrokeStyle(lineWidth: 4, lineCap: .round))
            
            // Start point
            Circle()
                .fill(Color.green)
                .frame(width: 12, height: 12)
                .position(x: 50, y: 150)
            
            // End point
            Circle()
                .fill(Color.red)
                .frame(width: 12, height: 12)
                .position(x: 300, y: 80)
        }
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
}


struct ParticipantsSection: View {
    @EnvironmentObject var themeManager: ThemeManager
    @ObservedObject var eventService: EventService
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Section Header
            HStack {
                Text("Participants")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(Color.dynamicTextSecondary(theme: themeManager.currentTheme))
                
                Spacer()
                
                if eventService.isLoadingParticipations {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: Color.dynamicAccent(theme: themeManager.currentTheme)))
                        .scaleEffect(0.7)
                } else {
                    Text("\(eventService.eventParticipations.count)")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(Color.dynamicTextSecondary(theme: themeManager.currentTheme))
                }
            }
            
            // Participants Content
            if eventService.isLoadingParticipations {
                // Loading state
                VStack(spacing: 8) {
                    ForEach(0..<2, id: \.self) { _ in
                        ParticipantSkeletonRow()
                    }
                }
            } else if eventService.eventParticipations.isEmpty {
                // Empty state
                Text("No participants yet")
                    .font(.system(size: 14))
                    .foregroundColor(Color.dynamicTextSecondary(theme: themeManager.currentTheme))
                    .padding(.vertical, 8)
            } else {
                // Participants list
                VStack(spacing: 8) {
                    ForEach(eventService.eventParticipations) { participation in
                        ParticipantRow(
                            participation: participation,
                            userProfile: eventService.userProfiles[participation.memberId],
                            eventDetail: eventService.eventDetail
                        )
                    }
                }
            }
        }
        .padding(.horizontal, 20)
    }
}

struct ParticipantRow: View {
    let participation: EventParticipation
    let userProfile: UserProfile?
    let eventDetail: EventDetail?
    @EnvironmentObject var themeManager: ThemeManager
    
    var body: some View {
        HStack(spacing: 10) {
            // Avatar
            ProfileAvatar.small(
                pictureURL: userProfile?.picture ?? "",
                showBorder: false
            )
            
            // Info
            VStack(alignment: .leading, spacing: 2) {
                Text(userProfile?.fullName ?? "User #\(participation.memberId)")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(Color.dynamicText(theme: themeManager.currentTheme))
                    .lineLimit(1)
                    .truncationMode(.tail)
                
                if let userProfile = userProfile {
                    let isCreator = eventDetail?.creatorId == participation.memberId
                    Text(isCreator ? "Creator" : userProfile.displayRole)
                        .font(.system(size: 12, weight: .regular))
                        .foregroundColor(Color.dynamicTextSecondary(theme: themeManager.currentTheme))
                        .lineLimit(1)
                }
            }
            
            Spacer()
        }
        .padding(.vertical, 8)
    }
    
    private func statusColor(for status: String) -> Color {
        switch status {
        case "REGISTERED": return .green
        case "CANCELLED": return .red
        case "ATTENDED": return .blue
        default: return .gray
        }
    }
    
    private func statusText(for status: String) -> String {
        switch status {
        case "REGISTERED": return "Registrado"
        case "CANCELLED": return "Cancelado"
        case "ATTENDED": return "Asistió"
        default: return status
        }
    }
    
    private func formatJoinDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        formatter.locale = Locale(identifier: "es_ES")
        
        let dateString = formatter.string(from: date)
        
        // Hacer formato más consistente y compacto
        let components = Calendar.current.dateComponents([.day, .month, .year], from: date)
        if let day = components.day, let month = components.month, let year = components.year {
            let monthNames = ["", "Ene", "Feb", "Mar", "Abr", "May", "Jun",
                             "Jul", "Ago", "Sep", "Oct", "Nov", "Dic"]
            let yearShort = year % 100
            return "\(day) \(monthNames[month]) '\(String(format: "%02d", yearShort))"
        }
        
        return dateString
    }
}

struct ParticipantSkeletonRow: View {
    var body: some View {
        HStack(spacing: 10) {
            // Avatar skeleton
            Circle()
                .fill(Color.gray.opacity(0.2))
                .frame(width: 28, height: 28)
            
            // Info skeleton
            VStack(alignment: .leading, spacing: 4) {
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color.gray.opacity(0.2))
                    .frame(height: 14)
                    .frame(maxWidth: 120)
                
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color.gray.opacity(0.2))
                    .frame(width: 60, height: 12)
            }
            
            Spacer()
        }
        .padding(.vertical, 8)
    }
}

#Preview {
    EventDetailView(eventId: 1)
        .environmentObject(AuthServiceDirect())
        .environmentObject(EventService())
}