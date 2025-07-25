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
        .navigationTitle("Event Details")
        .navigationBarTitleDisplayMode(.large)
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
            LazyVStack(alignment: .leading, spacing: 24) {
                // Event Header Card
                EventHeaderCard(eventDetail: eventDetail)
                
                // Event Details Section
                EventDetailsSection(eventDetail: eventDetail)
                
                // Description Section
                if !eventDetail.description.isEmpty {
                    EventDescriptionSection(description: eventDetail.description)
                }
                
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
                Spacer(minLength: 100)
            }
            .padding(.horizontal, 20)
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
        VStack(spacing: 0) {
            // Status Badge
            HStack {
                EventStatusBadge(status: eventDetail.status)
                Spacer()
                Text("Event #\(eventDetail.id)")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(Color.dynamicTextSecondary(theme: themeManager.currentTheme))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color.dynamicSurface(theme: themeManager.currentTheme).opacity(0.1))
                    .clipShape(Capsule())
            }
            .padding(.bottom, 16)
            
            // Title
            HStack {
                Text(eventDetail.title)
                    .font(.system(size: 32, weight: .bold))
                    .foregroundColor(Color.dynamicText(theme: themeManager.currentTheme))
                    .lineLimit(3)
                    .multilineTextAlignment(.leading)
                Spacer()
            }
            .padding(.bottom, 16)
            
            // Event Image with modern design
            ModernEventImageView()
        }
        .padding(24)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(
                    LinearGradient(
                        colors: [
                            Color.dynamicSurface(theme: themeManager.currentTheme).opacity(0.1),
                            Color.dynamicSurface(theme: themeManager.currentTheme).opacity(0.05)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(
                            LinearGradient(
                                colors: [
                                    Color.dynamicAccent(theme: themeManager.currentTheme).opacity(0.3),
                                    Color.dynamicAccent(theme: themeManager.currentTheme).opacity(0.1)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1
                        )
                )
        )
    }
}

struct EventStatusBadge: View {
    @EnvironmentObject var themeManager: ThemeManager
    let status: EventStatus
    
    var body: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(statusColor)
                .frame(width: 8, height: 8)
            
            Text(statusText.uppercased())
                .font(.system(size: 12, weight: .bold))
                .foregroundColor(statusColor)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(statusColor.opacity(0.1))
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
            // Background with modern gradient
            RoundedRectangle(cornerRadius: 16)
                .fill(
                    LinearGradient(
                        colors: [
                            Color.dynamicAccent(theme: themeManager.currentTheme).opacity(0.2),
                            Color.dynamicAccent(theme: themeManager.currentTheme).opacity(0.1)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(height: 180)
            
            // Modern pattern overlay
            ModernPatternView()
                .clipShape(RoundedRectangle(cornerRadius: 16))
            
            // Central icon
            VStack(spacing: 8) {
                Image(systemName: "calendar.badge.clock")
                    .font(.system(size: 32, weight: .light))
                    .foregroundColor(Color.dynamicAccent(theme: themeManager.currentTheme))
                
                Text("Event")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(Color.dynamicAccent(theme: themeManager.currentTheme).opacity(0.7))
            }
        }
    }
}

struct ModernPatternView: View {
    @EnvironmentObject var themeManager: ThemeManager
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Circular patterns
                ForEach(0..<5) { i in
                    Circle()
                        .stroke(Color.dynamicAccent(theme: themeManager.currentTheme).opacity(0.1), lineWidth: 1)
                        .frame(width: CGFloat(40 + i * 20), height: CGFloat(40 + i * 20))
                        .position(
                            x: geometry.size.width * 0.8,
                            y: geometry.size.height * 0.3
                        )
                }
                
                ForEach(0..<3) { i in
                    Circle()
                        .stroke(Color.dynamicAccent(theme: themeManager.currentTheme).opacity(0.05), lineWidth: 1)
                        .frame(width: CGFloat(60 + i * 30), height: CGFloat(60 + i * 30))
                        .position(
                            x: geometry.size.width * 0.2,
                            y: geometry.size.height * 0.7
                        )
                }
            }
        }
    }
}

struct EventDetailsSection: View {
    @EnvironmentObject var themeManager: ThemeManager
    let eventDetail: EventDetail
    
    var body: some View {
        VStack(spacing: 0) {
            // Section Title
            HStack {
                Text("Event Details")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(Color.dynamicText(theme: themeManager.currentTheme))
                Spacer()
            }
            .padding(.bottom, 16)
            
            VStack(spacing: 16) {
                // Location
                DetailRow(
                    icon: "location.fill",
                    title: "Location",
                    value: eventDetail.location
                )
                
                Divider()
                    .background(Color.dynamicSurface(theme: themeManager.currentTheme).opacity(0.2))
                
                // Date and Time
                DetailRow(
                    icon: "calendar",
                    title: "Date & Time",
                    value: eventDetail.dayTimeString
                )
                
                Divider()
                    .background(Color.dynamicSurface(theme: themeManager.currentTheme).opacity(0.2))
                
                // Participants
                DetailRow(
                    icon: "person.2.fill",
                    title: "Participants",
                    value: "\(eventDetail.participantsCount)/\(eventDetail.maxParticipants)"
                )
                
                Divider()
                    .background(Color.dynamicSurface(theme: themeManager.currentTheme).opacity(0.2))
                
                // Creator
                DetailRow(
                    icon: "person.badge.key.fill",
                    title: "Creator",
                    value: "User #\(eventDetail.creatorId)"
                )
            }
        }
        .padding(24)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Color.dynamicSurface(theme: themeManager.currentTheme).opacity(0.1))
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(Color.dynamicSurface(theme: themeManager.currentTheme).opacity(0.2), lineWidth: 1)
                )
        )
    }
}

struct DetailRow: View {
    @EnvironmentObject var themeManager: ThemeManager
    let icon: String
    let title: String
    let value: String
    
    var body: some View {
        HStack(spacing: 16) {
            // Icon
            Image(systemName: icon)
                .font(.system(size: 18))
                .foregroundColor(Color.dynamicAccent(theme: themeManager.currentTheme))
                .frame(width: 24, height: 24)
            
            // Content
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(Color.dynamicTextSecondary(theme: themeManager.currentTheme))
                
                Text(value)
                    .font(.system(size: 16, weight: .semibold))
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
        VStack(alignment: .leading, spacing: 0) {
            // Section Title
            HStack {
                Text("Description")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(Color.dynamicText(theme: themeManager.currentTheme))
                Spacer()
            }
            .padding(.bottom, 16)
            
            Text(description)
                .font(.system(size: 16, weight: .regular))
                .foregroundColor(Color.dynamicText(theme: themeManager.currentTheme).opacity(0.85))
                .lineSpacing(4)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(24)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Color.dynamicSurface(theme: themeManager.currentTheme).opacity(0.1))
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(Color.dynamicSurface(theme: themeManager.currentTheme).opacity(0.2), lineWidth: 1)
                )
        )
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
        VStack(spacing: 16) {
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
                HStack(spacing: 16) {
                    if eventService.isJoiningEvent {
                        LoadingDotsView()
                    } else {
                        Image(systemName: getButtonIcon(for: eventDetail))
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundColor(.white)
                        
                        Text(getButtonText(for: eventDetail))
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundColor(.white)
                    }
                }
                .frame(maxWidth: .infinity)
                .frame(height: 56)
                .background(
                    Capsule()
                        .fill(getButtonColor(for: eventDetail))
                        .overlay(
                            Capsule()
                                .stroke(Color.white.opacity(0.1), lineWidth: 1)
                        )
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
                    HStack(spacing: 16) {
                        Image(systemName: "bubble.left.and.bubble.right.fill")
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundColor(Color.dynamicAccent(theme: themeManager.currentTheme))
                        
                        Text("Event Chat")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundColor(Color.dynamicText(theme: themeManager.currentTheme))
                        
                        Spacer()
                        
                        Image(systemName: "chevron.right")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(Color.dynamicTextSecondary(theme: themeManager.currentTheme))
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 56)
                    .padding(.horizontal, 20)
                    .background(
                        Capsule()
                            .fill(Color.dynamicSurface(theme: themeManager.currentTheme).opacity(0.1))
                            .overlay(
                                Capsule()
                                    .stroke(Color.dynamicAccent(theme: themeManager.currentTheme).opacity(0.3), lineWidth: 1.5)
                            )
                    )
                }
            }
        }
        .padding(24)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Color.dynamicSurface(theme: themeManager.currentTheme).opacity(0.05))
        )
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
        VStack(alignment: .leading, spacing: 0) {
            // Section Header
            HStack {
                Text("Participantes")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(Color.dynamicText(theme: themeManager.currentTheme))
                
                Spacer()
                
                if eventService.isLoadingParticipations {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: Color.dynamicAccent(theme: themeManager.currentTheme)))
                        .scaleEffect(0.8)
                } else {
                    Text("(\(eventService.eventParticipations.count))")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(Color.dynamicTextSecondary(theme: themeManager.currentTheme))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color.dynamicSurface(theme: themeManager.currentTheme).opacity(0.1))
                        .clipShape(Capsule())
                }
            }
            .padding(.bottom, 20)
            
            // Participants Content
            if eventService.isLoadingParticipations {
                // Loading state
                VStack(spacing: 12) {
                    ForEach(0..<3, id: \.self) { _ in
                        ParticipantSkeletonRow()
                    }
                }
            } else if let errorMessage = eventService.participationsErrorMessage {
                // Error state
                VStack(spacing: 16) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 32))
                        .foregroundColor(.red)
                    
                    Text("Error al cargar participantes")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(Color.dynamicText(theme: themeManager.currentTheme))
                    
                    Text(errorMessage)
                        .font(.system(size: 14))
                        .foregroundColor(Color.dynamicTextSecondary(theme: themeManager.currentTheme))
                        .multilineTextAlignment(.center)
                        .lineLimit(3)
                }
                .padding(.vertical, 32)
            } else if eventService.eventParticipations.isEmpty {
                // Empty state
                VStack(spacing: 16) {
                    Image(systemName: "person.slash.fill")
                        .font(.system(size: 32))
                        .foregroundColor(Color.dynamicTextSecondary(theme: themeManager.currentTheme).opacity(0.5))
                    
                    Text("No participants yet")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(Color.dynamicText(theme: themeManager.currentTheme))
                    
                    Text("Be the first to join this event")
                        .font(.system(size: 14))
                        .foregroundColor(Color.dynamicTextSecondary(theme: themeManager.currentTheme).opacity(0.7))
                }
                .padding(.vertical, 32)
            } else {
                // Participants list
                VStack(spacing: 0) {
                    ForEach(eventService.eventParticipations) { participation in
                        ParticipantRow(
                            participation: participation,
                            userProfile: eventService.userProfiles[participation.memberId],
                            eventDetail: eventService.eventDetail
                        )
                        
                        if participation.id != eventService.eventParticipations.last?.id {
                            Divider()
                                .background(Color.dynamicSurface(theme: themeManager.currentTheme).opacity(0.2))
                        }
                    }
                }
            }
        }
        .padding(24)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Color.dynamicSurface(theme: themeManager.currentTheme).opacity(0.1))
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(Color.dynamicSurface(theme: themeManager.currentTheme).opacity(0.2), lineWidth: 1)
                )
        )
    }
}

struct ParticipantRow: View {
    let participation: EventParticipation
    let userProfile: UserProfile?
    let eventDetail: EventDetail?
    @EnvironmentObject var themeManager: ThemeManager
    
    var body: some View {
        HStack(spacing: 12) {
            // Avatar
            if let userProfile = userProfile,
               !userProfile.picture.isEmpty,
               let url = URL(string: userProfile.picture) {
                AsyncImage(url: url) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } placeholder: {
                    Image(systemName: "person.circle.fill")
                        .font(.system(size: 24))
                        .foregroundColor(.gray)
                }
                .frame(width: 40, height: 40)
                .clipShape(Circle())
            } else {
                Image(systemName: "person.circle.fill")
                    .font(.system(size: 24))
                    .foregroundColor(.gray)
                    .frame(width: 40, height: 40)
            }
            
            // Info
            VStack(alignment: .leading, spacing: 4) {
                Text(userProfile?.fullName ?? "Usuario #\(participation.memberId)")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.white)
                    .lineLimit(1)
                    .truncationMode(.tail)
                
                HStack(spacing: 8) {
                    // Status
                    HStack(spacing: 4) {
                        Circle()
                            .fill(statusColor(for: participation.status))
                            .frame(width: 8, height: 8)
                        
                        Text(statusText(for: participation.status))
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.gray)
                    }
                    
                    // Role with creator indicator
                    if let userProfile = userProfile {
                        let isCreator = eventDetail?.creatorId == participation.memberId
                        let roleText = isCreator ? "• Creador" : "• \(userProfile.displayRole)"
                        let roleColor = isCreator ? Color.dynamicAccent(theme: themeManager.currentTheme) : Color.dynamicTextSecondary(theme: themeManager.currentTheme).opacity(0.7)
                        
                        Text(roleText)
                            .font(.system(size: 12, weight: isCreator ? .semibold : .regular))
                            .foregroundColor(roleColor)
                            .lineLimit(1)
                    }
                }
            }
            .layoutPriority(1)
            
            Spacer(minLength: 8)
            
            // Join date
            VStack(alignment: .trailing, spacing: 2) {
                Text("Joined")
                    .font(.system(size: 9))
                    .foregroundColor(.gray.opacity(0.7))
                
                Text(formatJoinDate(participation.registeredAt))
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.gray)
            }
            .frame(minWidth: 60)
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 20)
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
        HStack(spacing: 12) {
            // Avatar skeleton
            Circle()
                .fill(Color.gray.opacity(0.3))
                .frame(width: 40, height: 40)
            
            // Info skeleton
            VStack(alignment: .leading, spacing: 4) {
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color.gray.opacity(0.3))
                    .frame(height: 16)
                    .frame(maxWidth: 140)
                
                HStack(spacing: 8) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.gray.opacity(0.3))
                        .frame(width: 60, height: 12)
                    
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.gray.opacity(0.3))
                        .frame(width: 70, height: 12)
                }
            }
            .layoutPriority(1)
            
            Spacer(minLength: 8)
            
            // Date skeleton
            VStack(alignment: .trailing, spacing: 2) {
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color.gray.opacity(0.3))
                    .frame(width: 40, height: 9)
                
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color.gray.opacity(0.3))
                    .frame(width: 50, height: 11)
            }
            .frame(minWidth: 60)
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 20)
    }
}

#Preview {
    EventDetailView(eventId: 1)
        .environmentObject(AuthServiceDirect())
        .environmentObject(EventService())
}