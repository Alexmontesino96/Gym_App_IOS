import SwiftUI
import MapKit


struct EventDetailView: View {
    @EnvironmentObject var authService: AuthServiceDirect
    @EnvironmentObject var eventService: EventService
    @EnvironmentObject var themeManager: ThemeManager
    @StateObject private var paymentService = EventPaymentService()
    @Environment(\.dismiss) private var dismiss

    let eventId: Int
    @State private var initialRegistrationState: Bool?
    @State private var showingPaymentSheet = false
    @State private var currentPaymentIntent: PaymentIntent?
    @State private var currentParticipationId: Int?
    
    var body: some View {
        ZStack {
                Color.dynamicBackground(theme: themeManager.currentTheme).ignoresSafeArea()
                
                if eventService.isLoadingDetail {
                    ModernLoadingView()
                } else if let eventDetail = eventService.eventDetail {
                    EventDetailContent(
                        eventDetail: eventDetail,
                        eventService: eventService,
                        paymentService: paymentService,
                        authService: authService,
                        initialRegistrationState: initialRegistrationState,
                        showingPaymentSheet: $showingPaymentSheet,
                        currentPaymentIntent: $currentPaymentIntent,
                        currentParticipationId: $currentParticipationId
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
            paymentService.authService = authService
            Task {
                await eventService.fetchEventDetailData(eventId: eventId)
            }
        }
        .sheet(isPresented: $showingPaymentSheet) {
            if let paymentIntent = currentPaymentIntent {
                EventPaymentView(
                    paymentIntent: paymentIntent,
                    participationId: currentParticipationId,
                    event: nil,  // No tenemos acceso al objeto Event aquí, solo eventDetail
                    onPaymentComplete: { success in
                        showingPaymentSheet = false
                        currentPaymentIntent = nil
                        currentParticipationId = nil
                        if success {
                            // Actualizar datos del evento solo si el pago fue exitoso
                            // fetchEventDetailData() actualizará automáticamente el estado de registro
                            Task {
                                await eventService.fetchEventDetailData(eventId: eventId)
                            }
                        }
                        // Si success == false (usuario canceló), no actualizar nada
                    }
                )
                .environmentObject(themeManager)
            }
        }
    }
}

struct EventDetailContent: View {
    @EnvironmentObject var themeManager: ThemeManager
    let eventDetail: EventDetail
    @ObservedObject var eventService: EventService
    @ObservedObject var paymentService: EventPaymentService
    let authService: AuthServiceDirect
    let initialRegistrationState: Bool?
    @State private var showingEventChat = false
    @State private var selectedChatEvent: Event?
    @State private var currentRegistrationState: Bool?
    @State private var shakeOffset: CGFloat = 0
    @State private var isLoadingChatRooms = false
    @Binding var showingPaymentSheet: Bool
    @Binding var currentPaymentIntent: PaymentIntent?
    @Binding var currentParticipationId: Int?
    @StateObject private var chatService = ChatService.shared

    // Computed property para contar participantes activos (mismo filtro que ParticipantsSection)
    private var activeParticipantsCount: Int {
        eventService.eventParticipations.filter { participation in
            switch participation.status {
            case .registered, .attended, .waitlist:
                return true
            case .pendingPayment:
                // Incluir PENDING_PAYMENT solo si el pago ya se completó
                return participation.paymentStatus == .paid
            case .cancelled, .noShow:
                return false
            }
        }.count
    }

    var body: some View {
        ScrollView(showsIndicators: false) {
            LazyVStack(alignment: .leading, spacing: 20) {
                // Event Header Card (now includes image)
                EventHeaderCard(eventDetail: eventDetail)
                
                // Description Section - Moved after image
                if !eventDetail.description.isEmpty {
                    EventDescriptionSection(description: eventDetail.description)
                }

                // Payment Info Card - Mostrar si es evento de pago
                if eventDetail.isPaid == true {
                    PaymentInfoCard(eventDetail: eventDetail)
                        .padding(.horizontal, 16)
                }

                // Event Details Section
                EventDetailsSection(
                    eventDetail: eventDetail,
                    activeParticipantsCount: activeParticipantsCount
                )

                // Registration Status Card
                RegistrationStatusCard(
                    eventDetail: eventDetail,
                    currentRegistrationState: currentRegistrationState
                )
                .padding(.horizontal, 16)

                // Action Buttons Section
                EventActionButtons(
                    eventDetail: eventDetail,
                    eventService: eventService,
                    paymentService: paymentService,
                    chatService: chatService,
                    authService: authService,
                    currentRegistrationState: $currentRegistrationState,
                    shakeOffset: $shakeOffset,
                    showingEventChat: $showingEventChat,
                    selectedChatEvent: $selectedChatEvent,
                    showingPaymentSheet: $showingPaymentSheet,
                    currentPaymentIntent: $currentPaymentIntent,
                    currentParticipationId: $currentParticipationId
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
                        streamChannelId: chatService.chatRooms.first(where: { $0.eventId == event.id })?.streamChannelId,
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

            // Cargar las salas de chat si no están cargadas
            if chatService.chatRooms.isEmpty && !isLoadingChatRooms {
                Task {
                    print("📱 [EventDetailContent] Cargando salas de chat...")
                    isLoadingChatRooms = true
                    await chatService.getMyRooms()
                    isLoadingChatRooms = false
                    print("📱 [EventDetailContent] Salas cargadas: \(chatService.chatRooms.count)")

                    // Log para debug
                    if let eventRoom = chatService.chatRooms.first(where: { $0.eventId == eventDetail.id }) {
                        print("📱 [EventDetailContent] Encontrada sala para evento \(eventDetail.id): \(eventRoom.streamChannelId ?? "sin ID")")
                    } else {
                        print("📱 [EventDetailContent] No se encontró sala para evento \(eventDetail.id)")
                    }
                }
            }
        }
        .onChange(of: eventService.userRegistrationStatus[eventDetail.id]) {
            // Actualizar el estado cuando cambie en el servicio
            if let newRegistrationState = eventService.userRegistrationStatus[eventDetail.id] {
                currentRegistrationState = newRegistrationState
            }
        }
        // Observa cualquier cambio general en el diccionario y sincroniza el estado local
        .onReceive(eventService.$userRegistrationStatus) { dict in
            currentRegistrationState = dict[eventDetail.id]
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
    @State private var showingShareSheet = false

    var body: some View {
        VStack(spacing: 0) {
            // Hero Section Compacto (100px)
            ZStack {
                // Gradient Background
                LinearGradient(
                    colors: [
                        Color.dynamicAccent(theme: themeManager.currentTheme).opacity(0.85),
                        Color.dynamicAccent(theme: themeManager.currentTheme).opacity(0.6)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )

                // Pattern decorativo sutil
                HStack(spacing: 60) {
                    Image(systemName: "figure.run")
                        .font(.system(size: 40, weight: .ultraLight))
                        .foregroundColor(.white.opacity(0.1))
                        .rotationEffect(.degrees(-15))

                    Image(systemName: "dumbbell.fill")
                        .font(.system(size: 36, weight: .ultraLight))
                        .foregroundColor(.white.opacity(0.08))
                        .rotationEffect(.degrees(20))

                    Image(systemName: "figure.boxing")
                        .font(.system(size: 42, weight: .ultraLight))
                        .foregroundColor(.white.opacity(0.09))
                        .rotationEffect(.degrees(-10))
                }
                .blur(radius: 1)

                // Contenido Principal
                HStack(spacing: 16) {
                    VStack(alignment: .leading, spacing: 10) {
                        // Status Badge
                        EventStatusBadge(status: eventDetail.status)

                        // Título
                        Text(eventDetail.title)
                            .font(.system(size: 22, weight: .bold))
                            .foregroundColor(.white)
                            .lineLimit(2)

                        // Info rápida
                        HStack(spacing: 16) {
                            QuickInfoItem(icon: "calendar", text: eventDetail.shortDateString)
                            QuickInfoItem(icon: "clock.fill", text: eventDetail.shortTimeString)
                            if eventDetail.isPaid == true, let price = eventDetail.formattedPrice {
                                QuickInfoItem(icon: "creditcard.fill", text: price)
                            }
                        }
                        .font(.system(size: 13, weight: .medium))
                    }

                    Spacer()
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 16)
            }
            .frame(height: 140)
            .clipShape(RoundedRectangle(cornerRadius: 20))
            .shadow(color: Color.black.opacity(0.15), radius: 12, y: 6)
        }
        .padding(.horizontal, 16)
        .padding(.top, 8)
    }
}

// MARK: - Quick Info Item Helper
struct QuickInfoItem: View {
    let icon: String
    let text: String

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 12, weight: .semibold))
            Text(text)
        }
        .foregroundColor(.white.opacity(0.95))
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
    @State private var isAnimating = false

    var body: some View {
        ZStack {
            // Gradient background más atractivo
            RoundedRectangle(cornerRadius: 16)
                .fill(
                    LinearGradient(
                        colors: [
                            Color.dynamicAccent(theme: themeManager.currentTheme).opacity(0.15),
                            Color.dynamicAccent(theme: themeManager.currentTheme).opacity(0.08),
                            Color.dynamicSurface(theme: themeManager.currentTheme).opacity(0.05)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(height: 200)

            // Pattern decorativo con múltiples íconos
            HStack(spacing: 40) {
                VStack(spacing: 40) {
                    Image(systemName: "figure.run")
                        .font(.system(size: 32, weight: .light))
                        .foregroundColor(Color.dynamicAccent(theme: themeManager.currentTheme).opacity(0.15))
                        .rotationEffect(.degrees(-15))

                    Image(systemName: "dumbbell.fill")
                        .font(.system(size: 28, weight: .light))
                        .foregroundColor(Color.dynamicAccent(theme: themeManager.currentTheme).opacity(0.12))
                        .rotationEffect(.degrees(20))
                }
                .offset(x: -30, y: isAnimating ? -10 : 10)

                VStack(spacing: 40) {
                    Image(systemName: "heart.fill")
                        .font(.system(size: 24, weight: .light))
                        .foregroundColor(Color.dynamicAccent(theme: themeManager.currentTheme).opacity(0.1))
                        .rotationEffect(.degrees(25))

                    Image(systemName: "calendar.badge.clock")
                        .font(.system(size: 36, weight: .light))
                        .foregroundColor(Color.dynamicAccent(theme: themeManager.currentTheme).opacity(0.2))
                        .scaleEffect(isAnimating ? 1.05 : 1.0)
                }
                .offset(y: isAnimating ? 10 : -10)

                VStack(spacing: 40) {
                    Image(systemName: "bolt.fill")
                        .font(.system(size: 26, weight: .light))
                        .foregroundColor(Color.dynamicAccent(theme: themeManager.currentTheme).opacity(0.11))
                        .rotationEffect(.degrees(-20))

                    Image(systemName: "figure.boxing")
                        .font(.system(size: 30, weight: .light))
                        .foregroundColor(Color.dynamicAccent(theme: themeManager.currentTheme).opacity(0.13))
                        .rotationEffect(.degrees(15))
                }
                .offset(x: 30, y: isAnimating ? -10 : 10)
            }
            .blur(radius: 0.5)

            // Ícono principal más prominente
            VStack(spacing: 8) {
                Image(systemName: "calendar.badge.exclamationmark")
                    .font(.system(size: 56, weight: .medium))
                    .foregroundColor(Color.dynamicAccent(theme: themeManager.currentTheme).opacity(0.7))
                    .shadow(color: Color.dynamicAccent(theme: themeManager.currentTheme).opacity(0.2), radius: 20, x: 0, y: 10)
                    .scaleEffect(isAnimating ? 1.0 : 0.95)
            }
        }
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(
                    LinearGradient(
                        colors: [
                            Color.dynamicAccent(theme: themeManager.currentTheme).opacity(0.2),
                            Color.dynamicSurface(theme: themeManager.currentTheme).opacity(0.1)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1
                )
        )
        .onAppear {
            withAnimation(.easeInOut(duration: 3).repeatForever(autoreverses: true)) {
                isAnimating = true
            }
        }
    }
}


struct EventDetailsSection: View {
    @EnvironmentObject var themeManager: ThemeManager
    let eventDetail: EventDetail
    let activeParticipantsCount: Int

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

            // Participants - Usar activeParticipantsCount para consistencia
            DetailRow(
                icon: "person.2",
                title: "Participants",
                value: "\(activeParticipantsCount)/\(eventDetail.maxParticipants)"
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
    @ObservedObject var paymentService: EventPaymentService
    @ObservedObject var chatService: ChatService
    let authService: AuthServiceDirect
    @Binding var currentRegistrationState: Bool?
    @Binding var shakeOffset: CGFloat
    @Binding var showingEventChat: Bool
    @Binding var selectedChatEvent: Event?
    @Binding var showingPaymentSheet: Bool
    @Binding var currentPaymentIntent: PaymentIntent?
    @Binding var currentParticipationId: Int?
    @State private var isPressed = false

    var body: some View {
        VStack(spacing: 12) {
            // Enhanced Main Action Button
            Button(action: {
                HapticManager.shared.buttonTap()

                if eventDetail.status == .completed {
                    shakeView()
                    return
                }

                Task {
                    let wasRegistered = currentRegistrationState ?? eventService.isUserRegistered(eventId: eventDetail.id)

                    if wasRegistered {
                        // Cancelar registro, puede incluir reembolso
                        if eventDetail.isPaid == true {
                            let refundResult = await paymentService.cancelWithRefund(eventId: eventDetail.id)
                            if refundResult?.success == true {
                                await eventService.fetchEventDetailData(eventId: eventDetail.id)
                            }
                        } else {
                            await eventService.cancelEvent(eventId: eventDetail.id)
                        }
                    } else {
                        // Registrarse en el evento
                        if eventDetail.isPaid == true {
                            // Evento de pago - necesita proceso de pago
                            if let participation = await paymentService.registerForPaidEvent(eventId: eventDetail.id) {
                                if participation.paymentRequired == true,
                                   let clientSecret = participation.paymentClientSecret {
                                    currentPaymentIntent = PaymentIntent(
                                        clientSecret: clientSecret,
                                        paymentIntentId: participation.paymentIntentId ?? "",
                                        stripeAccountId: participation.stripeAccountId,
                                        amount: participation.paymentAmount ?? 0,
                                        currency: participation.paymentCurrency ?? "EUR",
                                        paymentDeadline: participation.paymentDeadline
                                    )
                                    currentParticipationId = participation.id
                                    showingPaymentSheet = true
                                    // NO actualizar estado aquí - esperar a que se complete el pago
                                } else {
                                    // Registro exitoso sin pago requerido
                                    await eventService.fetchEventDetailData(eventId: eventDetail.id)
                                    currentRegistrationState = eventService.isUserRegistered(eventId: eventDetail.id)
                                }
                            }
                        } else {
                            // Evento gratuito
                            await eventService.joinEvent(eventId: eventDetail.id)
                            currentRegistrationState = eventService.isUserRegistered(eventId: eventDetail.id)
                        }
                    }
                }
            }) {
                ZStack {
                    // Background con gradiente mejorado
                    RoundedRectangle(cornerRadius: 14)
                        .fill(getButtonGradient(for: eventDetail))
                        .shadow(
                            color: getButtonColor(for: eventDetail).opacity(0.3),
                            radius: isPressed ? 8 : 12,
                            y: isPressed ? 2 : 6
                        )

                    // Contenido del botón
                    HStack(spacing: 14) {
                        if eventService.isJoiningEvent {
                            LoadingDotsView()
                        } else {
                            // Ícono con symbolRenderingMode
                            Image(systemName: getButtonIcon(for: eventDetail))
                                .font(.system(size: 18, weight: .semibold))
                                .symbolRenderingMode(.hierarchical)

                            VStack(spacing: 2) {
                                Text(getButtonPrimaryText(for: eventDetail))
                                    .font(.system(size: 16, weight: .bold))

                                if let secondaryText = getButtonSecondaryText(for: eventDetail) {
                                    Text(secondaryText)
                                        .font(.system(size: 12, weight: .medium))
                                        .opacity(0.9)
                                }
                            }

                            Spacer()

                            // Badge de precio si aplica
                            if let priceLabel = getPriceLabel(for: eventDetail) {
                                Text(priceLabel)
                                    .font(.system(size: 15, weight: .bold))
                                    .padding(.horizontal, 14)
                                    .padding(.vertical, 6)
                                    .background(
                                        Capsule()
                                            .fill(Color.white.opacity(0.25))
                                    )
                            }
                        }
                    }
                    .padding(.horizontal, 20)
                    .foregroundColor(.white)
                }
                .frame(height: 58)
            }
            .scaleEffect(isPressed ? 0.97 : 1.0)
            .disabled(shouldDisableButton(for: eventDetail) || eventService.isJoiningEvent)
            .simultaneousGesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { _ in
                        withAnimation(.easeInOut(duration: 0.15)) {
                            isPressed = true
                        }
                    }
                    .onEnded { _ in
                        withAnimation(.easeInOut(duration: 0.15)) {
                            isPressed = false
                        }
                    }
            )
            
            // Chat Button
            if currentRegistrationState ?? eventService.isUserRegistered(eventId: eventDetail.id) {
                Button(action: {
                    Task {
                        // Cargar las salas si no están disponibles
                        if chatService.chatRooms.isEmpty {
                            print("💬 [EventActionButtons] Cargando salas de chat antes de navegar...")
                            await chatService.getMyRooms()
                            print("💬 [EventActionButtons] Salas cargadas: \(chatService.chatRooms.count)")
                        }

                        // Verificar si tenemos el streamChannelId
                        let eventRoom = chatService.chatRooms.first(where: { $0.eventId == eventDetail.id })
                        if let streamChannelId = eventRoom?.streamChannelId {
                            print("💬 [EventActionButtons] Navegando con streamChannelId: \(streamChannelId)")
                        } else {
                            print("⚠️ [EventActionButtons] No se encontró streamChannelId para evento \(eventDetail.id)")
                        }

                        // Navegar al tab de Social/Mensajes y abrir el chat del evento
                        let event = Event(
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
                            participantsCount: eventDetail.participantsCount,
                            isPaid: eventDetail.isPaid,
                            priceCents: eventDetail.priceCents,
                            currency: eventDetail.currency,
                            refundPolicy: eventDetail.refundPolicy,
                            refundDeadlineHours: eventDetail.refundDeadlineHours,
                            partialRefundPercentage: eventDetail.partialRefundPercentage,
                            stripeProductId: eventDetail.stripeProductId,
                            stripePriceId: eventDetail.stripePriceId
                        )

                        // Send notification to navigate to Social tab
                        NotificationCenter.default.post(
                            name: .openEventChat,
                            object: event
                        )

                        print("🔥 Navigating to Social tab with event chat: \(event.title)")
                    }
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
            let isRegistered = currentRegistrationState ?? eventService.isUserRegistered(eventId: eventDetail.id)
            if isRegistered {
                // Si está registrado y es de pago, mostrar posibilidad de reembolso
                if eventDetail.isPaid == true && eventDetail.canStillRefund {
                    return "Cancelar con Reembolso"
                }
                return "Cancelar Registro"
            } else if eventDetail.isFullyBooked {
                return "Evento Lleno"
            } else {
                // Mostrar precio si es de pago
                if eventDetail.isPaid == true, let price = eventDetail.formattedPrice {
                    return "Registrarse - \(price)"
                } else {
                    return "Unirse (\(eventDetail.participantsCount)/\(eventDetail.maxParticipants))"
                }
            }
        }
    }
    
    private func shouldDisableButton(for eventDetail: EventDetail) -> Bool {
        let isRegistered = currentRegistrationState ?? eventService.isUserRegistered(eventId: eventDetail.id)
        return eventDetail.status == .cancelled ||
               (!isRegistered && eventDetail.isFullyBooked)
    }

    // MARK: - Enhanced Button Helpers
    private func getButtonGradient(for eventDetail: EventDetail) -> LinearGradient {
        let baseColor = getButtonColor(for: eventDetail)

        return LinearGradient(
            colors: [
                baseColor,
                baseColor.opacity(0.85)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    private func getButtonPrimaryText(for eventDetail: EventDetail) -> String {
        switch eventDetail.status {
        case .completed:
            let isRegistered = currentRegistrationState ?? eventService.isUserRegistered(eventId: eventDetail.id)
            return isRegistered ? "Participaste" : "Completado"
        case .cancelled:
            return "Cancelado"
        case .scheduled, .active:
            let isRegistered = currentRegistrationState ?? eventService.isUserRegistered(eventId: eventDetail.id)
            if isRegistered {
                return eventDetail.canStillRefund ? "Cancelar Registro" : "Cancelar"
            } else if eventDetail.isFullyBooked {
                return "Evento Lleno"
            } else {
                return "Registrarse Ahora"
            }
        }
    }

    private func getButtonSecondaryText(for eventDetail: EventDetail) -> String? {
        switch eventDetail.status {
        case .completed, .cancelled:
            return nil
        case .scheduled, .active:
            let isRegistered = currentRegistrationState ?? eventService.isUserRegistered(eventId: eventDetail.id)
            if isRegistered {
                if eventDetail.canStillRefund {
                    return "Reembolso disponible"
                }
                return nil
            } else if eventDetail.isFullyBooked {
                return "No hay espacios"
            } else {
                let spots = eventDetail.availableSpots
                return "\(spots) espacio\(spots == 1 ? "" : "s") disponible\(spots == 1 ? "" : "s")"
            }
        }
    }

    private func getPriceLabel(for eventDetail: EventDetail) -> String? {
        let isRegistered = currentRegistrationState ?? eventService.isUserRegistered(eventId: eventDetail.id)

        // Solo mostrar precio si no está registrado y es evento de pago
        if !isRegistered, eventDetail.isPaid == true, let price = eventDetail.formattedPrice {
            return price
        }

        return nil
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


// MARK: - Registration Status Card
struct RegistrationStatusCard: View {
    @EnvironmentObject var themeManager: ThemeManager
    let eventDetail: EventDetail
    let currentRegistrationState: Bool?

    var isRegistered: Bool {
        currentRegistrationState ?? false
    }

    var body: some View {
        VStack(spacing: 16) {
            // Status principal con ícono grande
            HStack(spacing: 18) {
                // Ícono destacado
                ZStack {
                    Circle()
                        .fill(statusColor.opacity(0.18))
                        .frame(width: 64, height: 64)

                    Image(systemName: statusIcon)
                        .font(.system(size: 28, weight: .semibold))
                        .foregroundColor(statusColor)
                        .symbolRenderingMode(.hierarchical)
                }

                // Información del estado
                VStack(alignment: .leading, spacing: 6) {
                    Text(statusTitle)
                        .font(.system(size: 19, weight: .bold))
                        .foregroundColor(Color.dynamicText(theme: themeManager.currentTheme))

                    Text(statusSubtitle)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(Color.dynamicTextSecondary(theme: themeManager.currentTheme))
                        .lineLimit(2)
                }

                Spacer()
            }

            // Pills informativos
            if !infoPills.isEmpty {
                HStack(spacing: 8) {
                    ForEach(infoPills, id: \.text) { pill in
                        InfoPill(
                            icon: pill.icon,
                            text: pill.text,
                            color: pill.color
                        )
                    }
                }
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(statusColor.opacity(0.08))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(statusColor.opacity(0.3), lineWidth: 1.5)
                )
                .shadow(color: statusColor.opacity(0.15), radius: 12, y: 6)
        )
    }

    // MARK: - Computed Properties
    private var statusColor: Color {
        if eventDetail.status == .completed {
            return .gray
        } else if eventDetail.status == .cancelled {
            return .red
        } else if isRegistered {
            return .green
        } else if eventDetail.isFullyBooked {
            return .orange
        } else {
            return Color.dynamicAccent(theme: themeManager.currentTheme)
        }
    }

    private var statusIcon: String {
        if eventDetail.status == .completed {
            return isRegistered ? "checkmark.seal.fill" : "clock.badge.checkmark.fill"
        } else if eventDetail.status == .cancelled {
            return "xmark.circle.fill"
        } else if isRegistered {
            return "checkmark.circle.fill"
        } else if eventDetail.isFullyBooked {
            return "exclamationmark.triangle.fill"
        } else {
            return "calendar.badge.plus"
        }
    }

    private var statusTitle: String {
        if eventDetail.status == .completed {
            return isRegistered ? "¡Participaste!" : "Evento Finalizado"
        } else if eventDetail.status == .cancelled {
            return "Evento Cancelado"
        } else if isRegistered {
            return "Estás Registrado"
        } else if eventDetail.isFullyBooked {
            return "Evento Lleno"
        } else {
            return "Inscripción Disponible"
        }
    }

    private var statusSubtitle: String {
        if eventDetail.status == .completed {
            return isRegistered ? "Gracias por asistir a este evento" : "Este evento ya ha finalizado"
        } else if eventDetail.status == .cancelled {
            return "Este evento ha sido cancelado"
        } else if isRegistered {
            return "Recibirás recordatorios antes del evento"
        } else if eventDetail.isFullyBooked {
            return "No quedan espacios disponibles"
        } else {
            let spots = eventDetail.availableSpots
            return "\(spots) espacio\(spots == 1 ? "" : "s") disponible\(spots == 1 ? "" : "s")"
        }
    }

    private var infoPills: [(icon: String, text: String, color: Color)] {
        var pills: [(icon: String, text: String, color: Color)] = []

        // Solo mostrar pills si el usuario está registrado y el evento no está cancelado/completado
        guard isRegistered, eventDetail.status == .scheduled || eventDetail.status == .active else {
            return pills
        }

        // Reembolsable
        if eventDetail.isPaid == true, eventDetail.canStillRefund {
            pills.append((
                icon: "arrow.uturn.left.circle.fill",
                text: "Reembolsable",
                color: .green
            ))
        }

        // Tiempo hasta el evento
        let hours = Int(eventDetail.hoursUntilEvent)
        if hours > 0 && hours < 48 {
            pills.append((
                icon: "clock.fill",
                text: "\(hours)h restantes",
                color: .orange
            ))
        }

        return pills
    }
}

// MARK: - Info Pill Component
struct InfoPill: View {
    let icon: String
    let text: String
    let color: Color

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 12, weight: .semibold))

            Text(text)
                .font(.system(size: 12, weight: .semibold))
        }
        .foregroundColor(color)
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(
            Capsule()
                .fill(color.opacity(0.15))
        )
    }
}

// MARK: - Payment Info Card
struct PaymentInfoCard: View {
    @EnvironmentObject var themeManager: ThemeManager
    let eventDetail: EventDetail

    var body: some View {
        VStack(spacing: 18) {
            // Header con precio destacado
            HStack(alignment: .top, spacing: 16) {
                // Ícono de pago
                ZStack {
                    Circle()
                        .fill(Color.green.opacity(0.15))
                        .frame(width: 48, height: 48)

                    Image(systemName: "creditcard.fill")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundColor(.green)
                }

                VStack(alignment: .leading, spacing: 6) {
                    Text("Inversión")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(Color.dynamicTextSecondary(theme: themeManager.currentTheme))

                    Text(eventDetail.formattedPrice ?? "Gratuito")
                        .font(.system(size: 32, weight: .bold))
                        .foregroundColor(Color.dynamicText(theme: themeManager.currentTheme))
                }

                Spacer()

                // Badge de pago seguro
                VStack(spacing: 4) {
                    Image(systemName: "checkmark.shield.fill")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.green)

                    Text("Pago\nSeguro")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundColor(.green)
                        .multilineTextAlignment(.center)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 8)
                .background(
                    Capsule()
                        .fill(Color.green.opacity(0.12))
                )
            }

            // Divider
            Rectangle()
                .fill(Color.dynamicBorder(theme: themeManager.currentTheme).opacity(0.3))
                .frame(height: 1)

            // Política de cancelación
            if let refundPolicy = eventDetail.refundPolicy {
                VStack(alignment: .leading, spacing: 14) {
                    HStack(spacing: 8) {
                        Image(systemName: "info.circle.fill")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(Color.dynamicAccent(theme: themeManager.currentTheme))

                        Text("Política de Cancelación")
                            .font(.system(size: 15, weight: .bold))
                            .foregroundColor(Color.dynamicText(theme: themeManager.currentTheme))
                    }

                    VStack(spacing: 10) {
                        // Full refund option
                        if refundPolicy == .fullRefund || refundPolicy == .partialRefund {
                            RefundPolicyRow(
                                icon: "checkmark.circle.fill",
                                condition: "Antes de \(eventDetail.refundDeadlineHours ?? 24)h",
                                refund: "100% reembolso",
                                color: .green
                            )
                        }

                        // Partial refund option
                        if refundPolicy == .partialRefund, let percentage = eventDetail.partialRefundPercentage {
                            RefundPolicyRow(
                                icon: "percent",
                                condition: "Después del límite",
                                refund: "\(percentage)% reembolso",
                                color: .orange
                            )
                        }

                        // No refund
                        if refundPolicy == .noRefund {
                            RefundPolicyRow(
                                icon: "xmark.circle.fill",
                                condition: "Sin reembolso",
                                refund: "No reembolsable",
                                color: .red
                            )
                        }

                        // Credit option
                        if refundPolicy == .credit {
                            RefundPolicyRow(
                                icon: "giftcard.fill",
                                condition: "Crédito disponible",
                                refund: "100% en crédito",
                                color: .purple
                            )
                        }
                    }
                }
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.dynamicCard(theme: themeManager.currentTheme))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Color.green.opacity(0.2), lineWidth: 1.5)
                )
                .shadow(color: Color.black.opacity(0.08), radius: 12, y: 6)
        )
    }
}

// MARK: - Refund Policy Row
struct RefundPolicyRow: View {
    @EnvironmentObject var themeManager: ThemeManager
    let icon: String
    let condition: String
    let refund: String
    let color: Color

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(color)
                .frame(width: 24)

            VStack(alignment: .leading, spacing: 2) {
                Text(condition)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(Color.dynamicText(theme: themeManager.currentTheme))

                Text(refund)
                    .font(.system(size: 12, weight: .regular))
                    .foregroundColor(Color.dynamicTextSecondary(theme: themeManager.currentTheme))
            }

            Spacer()

            Image(systemName: "arrow.right")
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(Color.dynamicTextSecondary(theme: themeManager.currentTheme).opacity(0.5))
        }
        .padding(.vertical, 4)
    }
}

struct ParticipantsSection: View {
    @EnvironmentObject var themeManager: ThemeManager
    @ObservedObject var eventService: EventService

    // Filtrar solo participantes activos (excluir pending sin pagar, cancelled, noShow)
    private var activeParticipants: [EventParticipation] {
        eventService.eventParticipations.filter { participation in
            switch participation.status {
            case .registered, .attended, .waitlist:
                return true
            case .pendingPayment:
                // Incluir PENDING_PAYMENT solo si el pago ya se completó
                return participation.paymentStatus == .paid
            case .cancelled, .noShow:
                return false
            }
        }
    }

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
                    Text("\(activeParticipants.count)")
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
            } else if activeParticipants.isEmpty {
                // Empty state
                Text("No participants yet")
                    .font(.system(size: 14))
                    .foregroundColor(Color.dynamicTextSecondary(theme: themeManager.currentTheme))
                    .padding(.vertical, 8)
            } else {
                // Participants list - solo participantes activos
                VStack(spacing: 8) {
                    ForEach(activeParticipants) { participation in
                        ParticipantRow(
                            participation: participation,
                            userProfile: UserDataCacheService.shared.userProfiles[participation.memberId],
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
