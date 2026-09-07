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
        .navigationTitle("")
        .navigationBarHidden(true)
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
                    event: nil,
                    onPaymentComplete: { success in
                        showingPaymentSheet = false
                        currentPaymentIntent = nil
                        currentParticipationId = nil
                        if success {
                            Task {
                                await eventService.fetchEventDetailData(eventId: eventId)
                            }
                        }
                    }
                )
                .environmentObject(themeManager)
            }
        }
    }
}

// MARK: - Event Detail Content (Prototype-matched design)

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
    @State private var going = false
    @State private var creatorProfile: UserProfile?
    @Binding var showingPaymentSheet: Bool
    @Binding var currentPaymentIntent: PaymentIntent?
    @Binding var currentParticipationId: Int?
    @StateObject private var chatService = ChatService.shared
    @Environment(\.dismiss) private var dismiss

    private var category: EventCategory {
        let text = "\(eventDetail.title) \(eventDetail.description)".lowercased()
        if text.contains("run") || text.contains("carrera") || text.contains("maratón") || text.contains("maraton") || text.contains("10k") || text.contains("5k") || text.contains("hyrox") {
            return .race
        }
        if text.contains("workshop") || text.contains("taller") || text.contains("nutrición") || text.contains("nutricion") || text.contains("charla") {
            return .workshop
        }
        if text.contains("retiro") || text.contains("retreat") || text.contains("wellness") || text.contains("mindful") {
            return .retreat
        }
        if text.contains("outdoor") || text.contains("sunrise") || text.contains("hike") || text.contains("playa") || text.contains("montaña") || text.contains("ruta") {
            return .outdoor
        }
        if text.contains("solidar") || text.contains("charity") || text.contains("benéfic") || text.contains("benefic") || text.contains("donación") {
            return .charity
        }
        if text.contains("social") || text.contains("fiesta") || text.contains("meetup") || text.contains("encuentro") {
            return .social
        }
        return .other
    }

    private var heroColor: Color { category.color }

    private var isFree: Bool {
        !(eventDetail.isPaid ?? false) || (eventDetail.priceCents ?? 0) == 0
    }

    private var priceText: String {
        if isFree { return "GRATIS" }
        let cents = eventDetail.priceCents ?? 0
        let currency = eventDetail.currency ?? "EUR"
        if currency.uppercased() == "EUR" { return "€\(cents / 100)" }
        return "\(cents / 100) \(currency)"
    }

    private var capacityPct: Double {
        guard eventDetail.maxParticipants > 0 else { return 0 }
        return Double(activeParticipantsCount) / Double(eventDetail.maxParticipants) * 100
    }

    private var isAlmostFull: Bool { capacityPct > 80 }

    private var isRegistered: Bool {
        currentRegistrationState ?? eventService.isUserRegistered(eventId: eventDetail.id)
    }

    private var activeParticipantsCount: Int {
        eventService.eventParticipations.filter { participation in
            switch participation.status {
            case .registered, .attended, .waitlist:
                return true
            case .pendingPayment:
                return participation.paymentStatus == .paid
            case .cancelled, .noShow:
                return false
            }
        }.count
    }

    // MARK: - Body

    var body: some View {
        ZStack(alignment: .bottom) {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 0) {
                    // 1. HERO (320px)
                    heroSection

                    // 2. DATE + TIME card (overlapping hero)
                    dateTimeCard
                        .padding(.horizontal, 20)
                        .offset(y: -28)
                        .zIndex(3)

                    // 3. LOCATION + MAP
                    locationCard
                        .padding(.horizontal, 20)
                        .padding(.top, -8)

                    // 4. WHO IS GOING
                    whoIsGoingCard
                        .padding(.horizontal, 20)
                        .padding(.top, 20)

                    // 5. DESCRIPTION
                    descriptionSection
                        .padding(.horizontal, 20)
                        .padding(.top, 24)

                    // 6. AGENDA (if we have start/end time)
                    agendaSection
                        .padding(.horizontal, 20)
                        .padding(.top, 24)

                    // 7. ORGANIZER (if we have creator info)
                    organizerSection
                        .padding(.horizontal, 20)
                        .padding(.top, 24)

                    // 8. REFUND POLICY (paid events only)
                    if !isFree {
                        refundPolicyCard
                            .padding(.horizontal, 20)
                            .padding(.top, 24)
                    }

                    // 9. PARTICIPANTS (if registered)
                    if isRegistered {
                        ParticipantsSection(eventService: eventService)
                            .padding(.top, 24)
                    }

                    // Error message
                    if let joinError = eventService.joinEventErrorMessage {
                        ErrorMessageCard(message: joinError)
                            .padding(.horizontal, 20)
                            .padding(.top, 16)
                    }

                    // Bottom spacing for sticky CTA
                    Spacer(minLength: 120)
                }
            }
            .offset(x: shakeOffset)

            // 10. STICKY CTA
            stickyCTA
        }
        .ignoresSafeArea(edges: .top)
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
            if currentRegistrationState == nil {
                currentRegistrationState = initialRegistrationState
            }
            going = isRegistered

            // Cargar perfil del creador
            Task {
                creatorProfile = await UserDataCacheService.shared.getUserProfile(eventDetail.creatorId)
            }

            if chatService.chatRooms.isEmpty && !isLoadingChatRooms {
                Task {
                    isLoadingChatRooms = true
                    await chatService.getMyRooms()
                    isLoadingChatRooms = false
                }
            }
        }
        .onChange(of: eventService.userRegistrationStatus[eventDetail.id]) {
            if let newRegistrationState = eventService.userRegistrationStatus[eventDetail.id] {
                currentRegistrationState = newRegistrationState
                going = newRegistrationState
            }
        }
        .onReceive(eventService.$userRegistrationStatus) { dict in
            currentRegistrationState = dict[eventDetail.id]
            going = dict[eventDetail.id] ?? false
        }
    }

    // MARK: - 1. Hero Section (320px)

    private var heroSection: some View {
        ZStack(alignment: .top) {
            // Background gradient
            ZStack {
                LinearGradient(
                    colors: [heroColor, heroColor.opacity(0.5), Color(hex: "#0A0A0A")!.opacity(0.7)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )

                // Decorative overlays
                RadialGradient(
                    colors: [Color.black.opacity(0.55), .clear],
                    center: UnitPoint(x: 0.7, y: 1.0),
                    startRadius: 0,
                    endRadius: 200
                )

                RadialGradient(
                    colors: [Color.white.opacity(0.2), .clear],
                    center: UnitPoint(x: 0.3, y: 0.2),
                    startRadius: 0,
                    endRadius: 150
                )
            }
            .frame(height: 320)
            .clipShape(UnevenRoundedRectangle(bottomLeadingRadius: 32, bottomTrailingRadius: 32))

            VStack {
                // Top bar
                HStack {
                    // Back button
                    Button(action: { dismiss() }) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.white)
                            .frame(width: 40, height: 40)
                            .background(Color.black.opacity(0.4))
                            .clipShape(Circle())
                            .overlay(Circle().stroke(Color.white.opacity(0.15), lineWidth: 1))
                    }

                    Spacer()

                    HStack(spacing: 8) {
                        Button(action: {}) {
                            Image(systemName: "bookmark")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(.white)
                                .frame(width: 40, height: 40)
                                .background(Color.black.opacity(0.4))
                                .clipShape(Circle())
                                .overlay(Circle().stroke(Color.white.opacity(0.15), lineWidth: 1))
                        }

                        Button(action: {}) {
                            Image(systemName: "paperplane.fill")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(.white)
                                .frame(width: 40, height: 40)
                                .background(Color.black.opacity(0.4))
                                .clipShape(Circle())
                                .overlay(Circle().stroke(Color.white.opacity(0.15), lineWidth: 1))
                        }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 56)

                Spacer()

                // Bottom: badges + title
                VStack(alignment: .leading, spacing: 12) {
                    // Category + price badges
                    HStack(spacing: 6) {
                        // Category badge
                        HStack(spacing: 4) {
                            Image(systemName: category.icon)
                                .font(.system(size: 10))
                            Text(category.label)
                                .font(.system(size: 10, weight: .bold))
                                .tracking(0.8)
                        }
                        .foregroundColor(heroColor)
                        .padding(.horizontal, 11)
                        .padding(.vertical, 5)
                        .background(Color.black.opacity(0.7))
                        .clipShape(Capsule())

                        // Price badge
                        if isFree {
                            Text("GRATIS")
                                .font(.system(size: 10, weight: .heavy))
                                .tracking(0.8)
                                .foregroundColor(Color.accentInk)
                                .padding(.horizontal, 11)
                                .padding(.vertical, 5)
                                .background(Color(hex: "#D4FF3F")!)
                                .clipShape(Capsule())
                        } else {
                            Text(priceText)
                                .font(.system(size: 11, weight: .bold, design: .monospaced))
                                .foregroundColor(Color(hex: "#0A0A0A")!)
                                .padding(.horizontal, 11)
                                .padding(.vertical, 5)
                                .background(Color.white)
                                .clipShape(Capsule())
                        }
                    }

                    // Title
                    Text(eventDetail.title)
                        .font(.system(size: 28, weight: .bold))
                        .tracking(-0.6)
                        .foregroundColor(.white)
                        .lineLimit(3)
                        .shadow(color: .black.opacity(0.4), radius: 10, y: 2)
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 50)
            }
        }
        .frame(height: 320)
    }

    // MARK: - 2. Date + Time Card

    private var dateTimeCard: some View {
        HStack(spacing: 14) {
            // Date block
            VStack(spacing: 2) {
                Text(dayLabel)
                    .font(.system(size: 9, weight: .bold, design: .monospaced))
                    .tracking(1.0)
                    .opacity(0.55)
                Text(dateNumber)
                    .font(.system(size: 22, weight: .bold, design: .monospaced))
                    .tracking(-0.4)
                Text(monthLabel)
                    .font(.system(size: 9, weight: .bold, design: .monospaced))
                    .tracking(1.0)
                    .opacity(0.75)
            }
            .foregroundColor(Color.dynamicBackground(theme: themeManager.currentTheme))
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(Color.dynamicText(theme: themeManager.currentTheme))
            .clipShape(RoundedRectangle(cornerRadius: 12))

            // Date text + time
            VStack(alignment: .leading, spacing: 2) {
                Text(eventDetail.dayTimeString)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(Color.dynamicText(theme: themeManager.currentTheme))

                HStack(spacing: 6) {
                    Image(systemName: "clock")
                        .font(.system(size: 12))
                    Text(timeRangeString)
                        .font(.system(size: 12, weight: .semibold, design: .monospaced))
                }
                .foregroundColor(Color.dynamicText(theme: themeManager.currentTheme).opacity(0.6))
            }

            Spacer()
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.dynamicCard(theme: themeManager.currentTheme))
                .shadow(color: .black.opacity(0.3), radius: 16, y: 6)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.white.opacity(0.08), lineWidth: 1)
        )
    }

    // MARK: - 3. Location + Map Card

    private var locationCard: some View {
        VStack(spacing: 0) {
            // Stylized map
            ZStack {
                // Map background
                LinearGradient(
                    colors: [heroColor.opacity(0.06), Color.dynamicSurface(theme: themeManager.currentTheme)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )

                // Grid pattern
                Canvas { context, size in
                    let gridSize: CGFloat = 20
                    let path = Path { p in
                        // Horizontal lines
                        var y: CGFloat = 0
                        while y <= size.height {
                            p.move(to: CGPoint(x: 0, y: y))
                            p.addLine(to: CGPoint(x: size.width, y: y))
                            y += gridSize
                        }
                        // Vertical lines
                        var x: CGFloat = 0
                        while x <= size.width {
                            p.move(to: CGPoint(x: x, y: 0))
                            p.addLine(to: CGPoint(x: x, y: size.height))
                            x += gridSize
                        }
                    }
                    context.stroke(path, with: .color(Color.white.opacity(0.06)), lineWidth: 0.8)

                    // Road lines
                    let road1 = Path { p in
                        p.move(to: CGPoint(x: 0, y: size.height * 0.7))
                        p.addQuadCurve(to: CGPoint(x: size.width, y: size.height * 0.55),
                                       control: CGPoint(x: size.width * 0.5, y: size.height * 0.65))
                    }
                    context.stroke(road1, with: .color(Color.dynamicText(theme: themeManager.currentTheme).opacity(0.15)), lineWidth: 1.5)

                    let road2 = Path { p in
                        p.move(to: CGPoint(x: size.width * 0.15, y: 0))
                        p.addLine(to: CGPoint(x: size.width * 0.22, y: size.height))
                    }
                    context.stroke(road2, with: .color(Color.dynamicText(theme: themeManager.currentTheme).opacity(0.15)), lineWidth: 1.5)

                    // Park area
                    let park = Path(roundedRect: CGRect(x: size.width * 0.3, y: size.height * 0.2, width: size.width * 0.25, height: size.height * 0.35), cornerRadius: 6)
                    context.fill(park, with: .color(heroColor.opacity(0.12)))

                    // Pin - outer rings
                    let pinCenter = CGPoint(x: size.width * 0.5, y: size.height * 0.5)
                    context.fill(Circle().path(in: CGRect(x: pinCenter.x - 18, y: pinCenter.y - 18, width: 36, height: 36)), with: .color(heroColor.opacity(0.18)))
                    context.fill(Circle().path(in: CGRect(x: pinCenter.x - 10, y: pinCenter.y - 10, width: 20, height: 20)), with: .color(heroColor.opacity(0.3)))
                    context.fill(Circle().path(in: CGRect(x: pinCenter.x - 6, y: pinCenter.y - 6, width: 12, height: 12)), with: .color(heroColor))
                    context.fill(Circle().path(in: CGRect(x: pinCenter.x - 2, y: pinCenter.y - 2, width: 4, height: 4)), with: .color(.white))
                }
            }
            .frame(height: 110)

            // Location info
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(eventDetail.location)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(Color.dynamicText(theme: themeManager.currentTheme))
                }

                Spacer()

                Button(action: {}) {
                    HStack(spacing: 4) {
                        Text("Ver mapa")
                            .font(.system(size: 12, weight: .semibold))
                        Image(systemName: "arrow.right")
                            .font(.system(size: 10, weight: .semibold))
                    }
                    .foregroundColor(Color.dynamicText(theme: themeManager.currentTheme))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(Color.dynamicSurface(theme: themeManager.currentTheme).opacity(0.8))
                    .clipShape(Capsule())
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .overlay(alignment: .top) {
                Rectangle()
                    .fill(Color.white.opacity(0.08))
                    .frame(height: 1)
            }
        }
        .background(Color.dynamicSurface(theme: themeManager.currentTheme))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.white.opacity(0.08), lineWidth: 1)
        )
    }

    // MARK: - 4. Who Is Going

    private var whoIsGoingCard: some View {
        VStack(spacing: 12) {
            // Header
            HStack {
                Text("QUIÉN VA")
                    .font(.system(size: 9, weight: .bold))
                    .tracking(1.0)
                    .foregroundColor(Color.dynamicText(theme: themeManager.currentTheme).opacity(0.5))

                Spacer()

                if isAlmostFull {
                    HStack(spacing: 4) {
                        Image(systemName: "flame.fill")
                            .font(.system(size: 11))
                        Text("CASI LLENO")
                            .font(.system(size: 10, weight: .bold))
                            .tracking(0.6)
                    }
                    .foregroundColor(Color(hex: "#FF5A1F")!)
                }
            }

            // Avatars + count
            HStack(spacing: 8) {
                // Avatar stack
                HStack(spacing: -8) {
                    ForEach(0..<min(5, max(activeParticipantsCount, 1)), id: \.self) { i in
                        Circle()
                            .fill(attendeeColors[i % attendeeColors.count])
                            .frame(width: 32, height: 32)
                            .overlay(Circle().stroke(Color.dynamicSurface(theme: themeManager.currentTheme), lineWidth: 2))
                    }
                }

                // Count
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 0) {
                        Text("\(activeParticipantsCount)")
                            .font(.system(size: 18, weight: .bold, design: .monospaced))
                            .tracking(-0.4)
                            .foregroundColor(Color.dynamicText(theme: themeManager.currentTheme))
                        Text("/\(eventDetail.maxParticipants)")
                            .font(.system(size: 18, weight: .medium, design: .monospaced))
                            .foregroundColor(Color.dynamicText(theme: themeManager.currentTheme).opacity(0.3))
                    }
                    Text("plazas")
                        .font(.system(size: 11))
                        .foregroundColor(Color.dynamicText(theme: themeManager.currentTheme).opacity(0.5))
                }

                Spacer()
            }

            // Segmented capacity bar
            HStack(spacing: 2) {
                ForEach(0..<12, id: \.self) { idx in
                    let cellPct = Double(idx + 1) / 12.0 * 100.0
                    let filled = cellPct <= capacityPct + 4
                    Rectangle()
                        .fill(filled ? barColor : Color.dynamicSurface(theme: themeManager.currentTheme).opacity(0.5))
                        .frame(height: 5)
                        .clipShape(RoundedRectangle(cornerRadius: 1))
                }
            }

            // Registered badge
            if isRegistered {
                HStack(spacing: 6) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 13))
                        .foregroundColor(Color(hex: "#D4FF3F")!)

                    Text("Vas a este evento")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(Color.dynamicText(theme: themeManager.currentTheme))
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .fill(Color(hex: "#D4FF3F")!.opacity(0.1))
                        .overlay(
                            RoundedRectangle(cornerRadius: 10)
                                .stroke(Color(hex: "#D4FF3F")!.opacity(0.25), lineWidth: 1)
                        )
                )
            }
        }
        .padding(16)
        .background(Color.dynamicSurface(theme: themeManager.currentTheme))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.white.opacity(0.08), lineWidth: 1)
        )
    }

    private var barColor: Color {
        if capacityPct > 90 { return Color(hex: "#FF5A5A")! }
        if capacityPct > 75 { return Color(hex: "#FF5A1F")! }
        return heroColor
    }

    // MARK: - 5. Description

    private var descriptionSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("DESCRIPCIÓN")
                .font(.system(size: 9, weight: .bold))
                .tracking(1.0)
                .foregroundColor(Color.dynamicText(theme: themeManager.currentTheme).opacity(0.5))

            Text(eventDetail.description)
                .font(.system(size: 14))
                .foregroundColor(Color.dynamicText(theme: themeManager.currentTheme).opacity(0.7))
                .lineSpacing(4)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    // MARK: - 6. Agenda

    private var agendaSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("AGENDA")
                .font(.system(size: 9, weight: .bold))
                .tracking(1.0)
                .foregroundColor(Color.dynamicText(theme: themeManager.currentTheme).opacity(0.5))

            ZStack(alignment: .leading) {
                // Timeline line
                Rectangle()
                    .fill(Color.white.opacity(0.08))
                    .frame(width: 1)
                    .padding(.leading, 55)
                    .padding(.vertical, 12)

                VStack(spacing: 14) {
                    agendaRow(time: startTimeString, item: "Inicio del evento")

                    if let endTime = eventDetail.endTime as Date? {
                        let formatter = DateFormatter()
                        let _ = formatter.dateFormat = "HH:mm"
                        agendaRow(time: formatter.string(from: endTime), item: "Fin del evento")
                    }
                }
            }
        }
    }

    private func agendaRow(time: String, item: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            // Time
            Text(time)
                .font(.system(size: 11, weight: .bold, design: .monospaced))
                .tracking(-0.2)
                .foregroundColor(Color.dynamicText(theme: themeManager.currentTheme))
                .frame(width: 40, alignment: .trailing)

            // Dot
            Circle()
                .fill(Color.dynamicBackground(theme: themeManager.currentTheme))
                .frame(width: 10, height: 10)
                .overlay(
                    Circle()
                        .stroke(heroColor, lineWidth: 2)
                )
                .padding(.top, 3)

            // Item text
            Text(item)
                .font(.system(size: 13))
                .foregroundColor(Color.dynamicText(theme: themeManager.currentTheme).opacity(0.7))
                .lineSpacing(2)
        }
    }

    // MARK: - 7. Organizer

    private var organizerSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("ORGANIZADOR")
                .font(.system(size: 9, weight: .bold))
                .tracking(1.0)
                .foregroundColor(Color.dynamicText(theme: themeManager.currentTheme).opacity(0.5))

            HStack(spacing: 12) {
                // Avatar con foto real o fallback a iniciales
                if let pictureURL = creatorPictureURL, !pictureURL.isEmpty {
                    ProfileAvatar(pictureURL: pictureURL, size: 48)
                } else {
                    Circle()
                        .fill(heroColor)
                        .frame(width: 48, height: 48)
                        .overlay(
                            Text(creatorInitials)
                                .font(.system(size: 16, weight: .bold))
                                .foregroundColor(.white)
                        )
                }

                // Info
                VStack(alignment: .leading, spacing: 2) {
                    Text(creatorName)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(Color.dynamicText(theme: themeManager.currentTheme))

                    Text(creatorRole)
                        .font(.system(size: 11))
                        .foregroundColor(Color.dynamicText(theme: themeManager.currentTheme).opacity(0.5))
                }

                Spacer()

                // Chat button
                if isRegistered {
                    Button(action: { navigateToEventChat() }) {
                        Image(systemName: "bubble.left.fill")
                            .font(.system(size: 14))
                            .foregroundColor(Color.dynamicText(theme: themeManager.currentTheme))
                            .frame(width: 40, height: 40)
                            .background(Color.dynamicSurface(theme: themeManager.currentTheme))
                            .clipShape(Circle())
                            .overlay(Circle().stroke(Color.white.opacity(0.08), lineWidth: 1))
                    }
                }
            }
            .padding(14)
            .background(Color.dynamicSurface(theme: themeManager.currentTheme))
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(Color.white.opacity(0.08), lineWidth: 1)
            )
        }
    }

    // MARK: - 8. Refund Policy

    private var refundPolicyCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("POLÍTICA DE REEMBOLSO")
                .font(.system(size: 9, weight: .bold))
                .tracking(1.0)
                .foregroundColor(Color.dynamicText(theme: themeManager.currentTheme).opacity(0.5))

            VStack(spacing: 10) {
                // Policy name + deadline
                HStack {
                    Text(refundPolicyLabel)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(Color.dynamicText(theme: themeManager.currentTheme))

                    if let pct = eventDetail.partialRefundPercentage, eventDetail.refundPolicy == .partialRefund {
                        Text("· \(pct)%")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(Color.dynamicText(theme: themeManager.currentTheme).opacity(0.5))
                    }

                    Spacer()

                    if let hours = eventDetail.refundDeadlineHours {
                        HStack(spacing: 4) {
                            Image(systemName: "clock")
                                .font(.system(size: 11))
                            Text("\(hours)h")
                                .font(.system(size: 11, weight: .semibold, design: .monospaced))
                        }
                        .foregroundColor(Color.dynamicText(theme: themeManager.currentTheme).opacity(0.6))
                    }
                }

                // Policy description
                Text(refundPolicyDescription)
                    .font(.system(size: 11))
                    .foregroundColor(Color.dynamicText(theme: themeManager.currentTheme).opacity(0.5))
                    .lineSpacing(2)
            }
            .padding(14)
            .background(Color.dynamicSurface(theme: themeManager.currentTheme))
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(Color.white.opacity(0.08), lineWidth: 1)
            )
        }
    }

    // MARK: - 10. Sticky CTA

    private var stickyCTA: some View {
        VStack(spacing: 0) {
            // Gradient fade
            LinearGradient(
                colors: [Color.dynamicBackground(theme: themeManager.currentTheme).opacity(0), Color.dynamicBackground(theme: themeManager.currentTheme)],
                startPoint: .top,
                endPoint: .center
            )
            .frame(height: 30)
            .allowsHitTesting(false)

            HStack(spacing: 10) {
                // Price (if paid)
                if !isFree {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("TOTAL")
                            .font(.system(size: 9, weight: .bold))
                            .tracking(0.8)
                            .foregroundColor(Color.dynamicText(theme: themeManager.currentTheme).opacity(0.5))

                        Text(priceText)
                            .font(.system(size: 22, weight: .bold, design: .monospaced))
                            .tracking(-0.4)
                            .foregroundColor(Color.dynamicText(theme: themeManager.currentTheme))
                    }
                }

                // CTA button
                Button(action: { handleCTATap() }) {
                    HStack(spacing: 8) {
                        if eventService.isJoiningEvent {
                            LoadingDotsView()
                        } else if isRegistered {
                            Image(systemName: "checkmark")
                                .font(.system(size: 16, weight: .bold))
                            Text("Registrado")
                                .font(.system(size: 16, weight: .bold))
                        } else if isFree {
                            Text("Registrarse")
                                .font(.system(size: 16, weight: .bold))
                            Image(systemName: "arrow.right")
                                .font(.system(size: 16, weight: .semibold))
                        } else {
                            Text("Completar Pago")
                                .font(.system(size: 16, weight: .bold))
                            Image(systemName: "arrow.right")
                                .font(.system(size: 16, weight: .semibold))
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 52)
                    .foregroundColor(isRegistered ? Color.dynamicText(theme: themeManager.currentTheme) : Color.accentInk)
                    .background(
                        RoundedRectangle(cornerRadius: 14)
                            .fill(isRegistered ? Color.dynamicSurface(theme: themeManager.currentTheme) : Color(hex: "#D4FF3F")!)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 14)
                            .stroke(isRegistered ? Color.white.opacity(0.14) : Color.clear, lineWidth: 1)
                    )
                }
                .disabled(shouldDisableButton || eventService.isJoiningEvent)
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 32)
            .padding(.top, 6)
            .background(Color.dynamicBackground(theme: themeManager.currentTheme))
        }
    }

    // MARK: - Action Handlers

    private func handleCTATap() {
        HapticManager.shared.buttonTap()

        if eventDetail.status == .completed {
            shakeView()
            return
        }

        Task {
            let wasRegistered = isRegistered

            if wasRegistered {
                // Cancel
                if eventDetail.isPaid == true {
                    let refundResult = await paymentService.cancelWithRefund(eventId: eventDetail.id)
                    if refundResult?.success == true {
                        await eventService.fetchEventDetailData(eventId: eventDetail.id)
                    }
                } else {
                    await eventService.cancelEvent(eventId: eventDetail.id)
                }
            } else {
                // Register
                if eventDetail.isPaid == true {
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
                        } else {
                            await eventService.fetchEventDetailData(eventId: eventDetail.id)
                            currentRegistrationState = eventService.isUserRegistered(eventId: eventDetail.id)
                        }
                    }
                } else {
                    await eventService.joinEvent(eventId: eventDetail.id)
                    currentRegistrationState = eventService.isUserRegistered(eventId: eventDetail.id)
                }
            }
        }
    }

    private func navigateToEventChat() {
        Task {
            if chatService.chatRooms.isEmpty {
                await chatService.getMyRooms()
            }

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

            NotificationCenter.default.post(
                name: .openEventChat,
                object: event
            )
        }
    }

    private var shouldDisableButton: Bool {
        eventDetail.status == .cancelled ||
        (!isRegistered && eventDetail.isFullyBooked)
    }

    private func shakeView() {
        withAnimation(.easeInOut(duration: 0.1)) { shakeOffset = -8 }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            withAnimation(.easeInOut(duration: 0.1)) { shakeOffset = 8 }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            withAnimation(.easeInOut(duration: 0.1)) { shakeOffset = -4 }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            withAnimation(.easeInOut(duration: 0.1)) { shakeOffset = 4 }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
            withAnimation(.easeInOut(duration: 0.1)) { shakeOffset = 0 }
        }
    }

    // MARK: - Helpers

    private var startTimeString: String {
        let f = DateFormatter()
        f.dateFormat = "HH:mm"
        f.timeZone = TimeZone.current
        return f.string(from: eventDetail.startTime)
    }

    private var timeRangeString: String {
        let f = DateFormatter()
        f.dateFormat = "HH:mm"
        f.timeZone = TimeZone.current
        let start = f.string(from: eventDetail.startTime)
        let end = f.string(from: eventDetail.endTime)
        return "\(start) – \(end)"
    }

    private var dayLabel: String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "es_ES")
        f.dateFormat = "EEE"
        f.timeZone = TimeZone.current
        return f.string(from: eventDetail.startTime).uppercased()
    }

    private var dateNumber: String {
        let f = DateFormatter()
        f.dateFormat = "dd"
        f.timeZone = TimeZone.current
        return f.string(from: eventDetail.startTime)
    }

    private var monthLabel: String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "es_ES")
        f.dateFormat = "MMM"
        f.timeZone = TimeZone.current
        return f.string(from: eventDetail.startTime).uppercased()
    }

    private var creatorName: String {
        // 1. Usar perfil cargado directamente via UserDataCacheService
        if let profile = creatorProfile {
            return profile.fullName
        }
        // 2. Intentar desde el cache global (puede estar cargado por participaciones)
        if let profile = UserDataCacheService.shared.userProfiles[eventDetail.creatorId] {
            return profile.fullName
        }
        // 3. Fallback: nombre del gimnasio actual
        if let gymName = GymService.shared.currentGym?.name {
            return gymName
        }
        return "Organizador"
    }

    private var creatorRole: String {
        // Obtener rol del creador desde su perfil
        if let profile = creatorProfile ?? UserDataCacheService.shared.userProfiles[eventDetail.creatorId] {
            // Priorizar displayGymRole (formateado), luego displayRole
            if let gymRole = profile.displayGymRole {
                return gymRole
            }
            return profile.displayRole
        }
        // Fallback
        return "Equipo organizador"
    }

    private var creatorPictureURL: String? {
        if let profile = creatorProfile ?? UserDataCacheService.shared.userProfiles[eventDetail.creatorId] {
            return profile.picture
        }
        return nil
    }

    private var creatorInitials: String {
        let name = creatorName
        let parts = name.split(separator: " ")
        if parts.count >= 2 {
            return "\(parts[0].prefix(1))\(parts[1].prefix(1))".uppercased()
        }
        return String(name.prefix(2)).uppercased()
    }

    private var refundPolicyLabel: String {
        switch eventDetail.refundPolicy {
        case .fullRefund: return "Reembolso completo"
        case .partialRefund: return "Reembolso parcial"
        case .noRefund: return "Sin reembolso"
        case .credit: return "Crédito"
        case .none: return "Sin política"
        }
    }

    private var refundPolicyDescription: String {
        let hours = eventDetail.refundDeadlineHours ?? 24
        switch eventDetail.refundPolicy {
        case .fullRefund:
            return "Reembolso 100% si cancelas hasta \(hours)h antes del evento."
        case .partialRefund:
            let pct = eventDetail.partialRefundPercentage ?? 50
            return "Reembolso del \(pct)% si cancelas hasta \(hours)h antes del evento."
        case .noRefund:
            return "Sin reembolso una vez confirmado el pago."
        case .credit:
            return "Crédito para otros eventos del gimnasio si cancelas hasta \(hours)h antes."
        case .none:
            return ""
        }
    }

    private let attendeeColors: [Color] = [
        Color(hex: "#FF5A1F")!,
        Color(hex: "#A78BFA")!,
        Color(hex: "#3B82F6")!,
        Color(hex: "#4ADE80")!,
        Color(hex: "#F472B6")!,
    ]
}

// MARK: - Reusable Components (kept for compatibility)

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
                    Text("Reintentar")
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

struct ParticipantsSection: View {
    @EnvironmentObject var themeManager: ThemeManager
    @ObservedObject var eventService: EventService

    private var activeParticipants: [EventParticipation] {
        eventService.eventParticipations.filter { participation in
            switch participation.status {
            case .registered, .attended, .waitlist:
                return true
            case .pendingPayment:
                return participation.paymentStatus == .paid
            case .cancelled, .noShow:
                return false
            }
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("PARTICIPANTES")
                    .font(.system(size: 9, weight: .bold))
                    .tracking(1.0)
                    .foregroundColor(Color.dynamicText(theme: themeManager.currentTheme).opacity(0.5))

                Spacer()

                if eventService.isLoadingParticipations {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: Color.dynamicAccent(theme: themeManager.currentTheme)))
                        .scaleEffect(0.7)
                } else {
                    Text("\(activeParticipants.count)")
                        .font(.system(size: 14, weight: .medium, design: .monospaced))
                        .foregroundColor(Color.dynamicText(theme: themeManager.currentTheme).opacity(0.5))
                }
            }

            if eventService.isLoadingParticipations {
                VStack(spacing: 8) {
                    ForEach(0..<2, id: \.self) { _ in
                        ParticipantSkeletonRow()
                    }
                }
            } else if activeParticipants.isEmpty {
                Text("No hay participantes aún")
                    .font(.system(size: 14))
                    .foregroundColor(Color.dynamicText(theme: themeManager.currentTheme).opacity(0.5))
                    .padding(.vertical, 8)
            } else {
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
            ProfileAvatar.small(
                pictureURL: userProfile?.picture ?? "",
                showBorder: false
            )

            VStack(alignment: .leading, spacing: 2) {
                Text(userProfile?.fullName ?? "User #\(participation.memberId)")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(Color.dynamicText(theme: themeManager.currentTheme))
                    .lineLimit(1)
                    .truncationMode(.tail)

                if let userProfile = userProfile {
                    let isCreator = eventDetail?.creatorId == participation.memberId
                    Text(isCreator ? "Creador" : userProfile.displayRole)
                        .font(.system(size: 12, weight: .regular))
                        .foregroundColor(Color.dynamicText(theme: themeManager.currentTheme).opacity(0.5))
                        .lineLimit(1)
                }
            }

            Spacer()
        }
        .padding(.vertical, 8)
    }
}

struct ParticipantSkeletonRow: View {
    var body: some View {
        HStack(spacing: 10) {
            Circle()
                .fill(Color.gray.opacity(0.2))
                .frame(width: 28, height: 28)

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

// MARK: - DetailRow (fila de detalle reutilizable)

struct DetailRow: View {
    @EnvironmentObject var themeManager: ThemeManager
    let icon: String
    let title: String
    let value: String

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(Color.dynamicTextSecondary(theme: themeManager.currentTheme))
                .frame(width: 20, height: 20)

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

#Preview {
    EventDetailView(eventId: 1)
        .environmentObject(AuthServiceDirect())
        .environmentObject(EventService())
        .environmentObject(ThemeManager())
        .environmentObject(EventPaymentService.shared)
}
