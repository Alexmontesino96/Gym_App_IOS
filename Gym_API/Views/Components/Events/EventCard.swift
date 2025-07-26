import SwiftUI

struct EventCard: View {
    let event: Event
    let onChatTap: (() -> Void)?
    
    @State private var navigateToDetail = false
    
    init(event: Event, onChatTap: (() -> Void)? = nil) {
        self.event = event
        self.onChatTap = onChatTap
    }
    
    var body: some View {
        ZStack {
            NavigationLink(destination: EventDetailView(eventId: event.id), isActive: $navigateToDetail) {
                EmptyView()
            }
            .opacity(0)
            
            ModernEventCardContent(event: event, onChatTapped: onChatTap ?? {})
                .onTapGesture {
                    navigateToDetail = true
                }
        }
    }
}

struct ModernEventCardContent: View {
    @EnvironmentObject var themeManager: ThemeManager
    @EnvironmentObject var eventService: EventService
    let event: Event
    let onChatTapped: () -> Void
    @State private var isLoading = false
    @State private var shakeOffset: CGFloat = 0
    
    // Función para crear el efecto de sacudida
    private func shakeCard() {
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
    
    var body: some View {
        ZStack {
            // Fondo de la tarjeta
            RoundedRectangle(cornerRadius: 20)
                .fill(Color.dynamicSurface(theme: themeManager.currentTheme))
            
            HStack(spacing: 0) {
                // Línea de acento lateral (diseño original)
                Rectangle()
                    .fill(Color.dynamicAccent(theme: themeManager.currentTheme))
                    .frame(width: 6)
                
                // Contenido principal
                VStack(alignment: .leading, spacing: 16) {
                    // Header: Badge + Título
                    VStack(alignment: .leading, spacing: 12) {
                        // Badge FITNESS EVENT
                        Text("FITNESS EVENT")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(Color.dynamicAccent(theme: themeManager.currentTheme))
                            .tracking(1.2)
                        
                        // Título principal
                        Text(event.title)
                            .font(.system(size: 24, weight: .bold))
                            .foregroundColor(Color.dynamicText(theme: themeManager.currentTheme))
                            .multilineTextAlignment(.leading)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    
                    // Detalles del evento
                    VStack(alignment: .leading, spacing: 12) {
                        // Ubicación
                        HStack(spacing: 12) {
                            Image(systemName: "location.fill")
                                .font(.system(size: 16))
                                .foregroundColor(Color.dynamicAccent(theme: themeManager.currentTheme))
                            
                            Text(event.location)
                                .font(.system(size: 16, weight: .regular))
                                .foregroundColor(Color.dynamicText(theme: themeManager.currentTheme))
                        }
                        
                        // Coach/Instructor
                        if !event.description.isEmpty {
                            HStack(spacing: 12) {
                                Image(systemName: "person.circle.fill")
                                    .font(.system(size: 16))
                                    .foregroundColor(Color.dynamicAccent(theme: themeManager.currentTheme))
                                
                                Text(getCoachName(from: event.description))
                                    .font(.system(size: 16, weight: .regular))
                                    .foregroundColor(Color.dynamicText(theme: themeManager.currentTheme))
                            }
                        }
                    }
                    
                    Spacer()
                    
                    // Sección inferior: Fecha/hora + Botones
                    HStack(alignment: .bottom) {
                        // Schedule section
                        VStack(alignment: .leading, spacing: 4) {
                            Text("SCHEDULE")
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundColor(Color.dynamicTextSecondary(theme: themeManager.currentTheme))
                                .tracking(1.2)
                            
                            HStack(spacing: 8) {
                                Image(systemName: "calendar")
                                    .font(.system(size: 14))
                                    .foregroundColor(Color.dynamicTextSecondary(theme: themeManager.currentTheme))
                                
                                Text(formatEventDateFull(event.startTime))
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundColor(Color.dynamicText(theme: themeManager.currentTheme))
                                    .lineLimit(1)
                                    .minimumScaleFactor(0.8)
                            }
                        }
                        
                        Spacer()
                        
                        // Botones de acción
                        actionButtonsContainer
                    }
                }
                .padding(.leading, 24)
                .padding(.trailing, 12)
                .padding(.vertical, 24)
            }
        }
        .frame(minHeight: 220)
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .overlay(
            // Indicador circular para eventos completados donde el usuario participó
            Group {
                if event.status == .completed && eventService.isUserRegistered(eventId: event.id) {
                    Circle()
                        .fill(Color.dynamicAccent(theme: themeManager.currentTheme))
                        .frame(width: 12, height: 12)
                        .overlay(
                            Circle()
                                .stroke(Color.dynamicSurface(theme: themeManager.currentTheme), lineWidth: 2)
                        )
                        .padding(.top, 12)
                        .padding(.trailing, 12)
                }
            },
            alignment: .topTrailing
        )
        .offset(x: shakeOffset)
    }
    
    @ViewBuilder
    private var actionButtonsContainer: some View {
        ZStack {
            // Área para evitar que los toques pasen a la tarjeta
            Color.clear
                .contentShape(Rectangle())
                .allowsHitTesting(true)
                .onTapGesture { }
            
            if event.status == .completed && eventService.isUserRegistered(eventId: event.id) {
                // Eventos completados donde el usuario participó: mensajes motivacionales + chat
                let hoursAfterEvent = Date().timeIntervalSince(event.endTime) / 3600
                let showChatButton = hoursAfterEvent <= 24
                
                if showChatButton {
                    VStack(spacing: 0) {
                        Text(getMotivationalMessage())
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(Color.dynamicText(theme: themeManager.currentTheme))
                            .multilineTextAlignment(.center)
                            .lineSpacing(1)
                            .fixedSize(horizontal: false, vertical: true)
                            .padding(.horizontal, 4)
                            .padding(.top, 4)
                        
                        Spacer(minLength: 2)
                        
                        Button(action: {
                            print("💬 Opening chat for completed event: \(event.title)")
                            onChatTapped()
                        }) {
                            HStack(spacing: 5) {
                                Image(systemName: "bubble.left.fill")
                                    .font(.system(size: 12, weight: .medium))
                                Text("Chat")
                                    .font(.system(size: 13, weight: .semibold))
                            }
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                            .background(
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(Color.dynamicAccent(theme: themeManager.currentTheme))
                            )
                        }
                        .padding(.horizontal, 8)
                        .padding(.bottom, 3)
                    }
                    .frame(width: 110, height: 40)
                } else {
                    VStack {
                        Spacer()
                        Text(getMotivationalMessage())
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(Color.dynamicText(theme: themeManager.currentTheme))
                            .multilineTextAlignment(.center)
                            .lineSpacing(2)
                            .fixedSize(horizontal: false, vertical: true)
                            .padding(.horizontal, 8)
                        Spacer()
                    }
                    .frame(width: 110, height: 40)
                }
            } else {
                // Botón doble estándar (diseño original)
                ZStack {
                    Capsule()
                        .fill(Color.dynamicSurface(theme: themeManager.currentTheme))
                        .overlay(
                            Capsule()
                                .stroke(Color.dynamicBorder(theme: themeManager.currentTheme), lineWidth: 1)
                        )
                    
                    if isLoading {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: Color.dynamicAccent(theme: themeManager.currentTheme)))
                            .scaleEffect(0.8)
                    } else if eventService.isUserRegistered(eventId: event.id) {
                        // Usuario registrado: Chat + Cancel
                        HStack(spacing: 0) {
                            // Botón Chat (40%)
                            Button(action: {
                                print("💬 Opening chat for event: \(event.title)")
                                onChatTapped()
                            }) {
                                Image(systemName: "bubble.left")
                                    .font(.system(size: 16, weight: .medium))
                                    .foregroundColor(Color.dynamicAccent(theme: themeManager.currentTheme))
                            }
                            .frame(maxWidth: 44, maxHeight: .infinity)
                            
                            // Divider
                            Rectangle()
                                .fill(Color.dynamicBorder(theme: themeManager.currentTheme).opacity(0.5))
                                .frame(width: 0.5, height: 24)
                            
                            // Botón Cancel (60%)
                            Button(action: {
                                if !isLoading {
                                    print("🚫 Cancelling event: \(event.title)")
                                    isLoading = true
                                    Task {
                                        await eventService.cancelEvent(eventId: event.id)
                                        try? await Task.sleep(nanoseconds: 500_000_000)
                                        withAnimation(.easeInOut(duration: 0.3)) {
                                            isLoading = false
                                        }
                                    }
                                }
                            }) {
                                Text("Cancel")
                                    .font(.system(size: 15, weight: .semibold))
                                    .foregroundColor(.red)
                            }
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                        }
                    } else {
                        // Usuario no registrado: botón único
                        Button(action: {
                            if event.participantsCount < event.maxParticipants && !isLoading {
                                print("🎯 Joining event: \(event.title)")
                                isLoading = true
                                Task {
                                    await eventService.joinEvent(eventId: event.id)
                                    try? await Task.sleep(nanoseconds: 500_000_000)
                                    withAnimation(.easeInOut(duration: 0.3)) {
                                        isLoading = false
                                    }
                                }
                            }
                        }) {
                            HStack(spacing: 8) {
                                Image(systemName: event.participantsCount >= event.maxParticipants ? "person.fill.xmark" : "person.fill.checkmark")
                                    .font(.system(size: 16))
                                
                                Text(buttonText)
                                    .font(.system(size: 16, weight: .semibold))
                            }
                            .foregroundColor(.white)
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .background(
                            Capsule()
                                .fill(
                                    event.participantsCount >= event.maxParticipants ?
                                    Color.gray.opacity(0.7) :
                                    Color.dynamicAccent(theme: themeManager.currentTheme)
                                )
                        )
                        .disabled(event.participantsCount >= event.maxParticipants)
                    }
                }
                .frame(width: 110, height: 40)
                .offset(x: 20)
            }
        }
        .animation(.easeInOut(duration: 0.3), value: eventService.isUserRegistered(eventId: event.id))
        .animation(.easeInOut(duration: 0.3), value: isLoading)
    }
    
    // Computed properties para el botón
    private var buttonText: String {
        if eventService.isUserRegistered(eventId: event.id) {
            return "Registered"
        } else if event.participantsCount >= event.maxParticipants {
            return "Full"
        } else {
            return "Join"
        }
    }
    
    private func getCoachName(from description: String?) -> String {
        guard let description = description else { return "Coach" }
        if description.localizedCaseInsensitiveContains("john") {
            return "Coach John"
        } else if description.localizedCaseInsensitiveContains("bruce") {
            return "Coach Bruce K"
        } else if description.localizedCaseInsensitiveContains("david") {
            return "Coach David"
        } else if description.localizedCaseInsensitiveContains("caucaú") {
            return "Coach Caucaú"
        } else if description.localizedCaseInsensitiveContains("miami") {
            return "Coach David"
        }
        return "Coach"
    }
    
    // Función para obtener mensaje motivacional aleatorio en inglés
    private func getMotivationalMessage() -> String {
        let motivationalMessages = [
            "Keep going and you'll reach the stars!",
            "Great job! Every step counts towards your goals",
            "You're stronger than you think - keep pushing!",
            "Amazing work! Your dedication inspires others",
            "Well done! Success is built one workout at a time",
            "Fantastic effort! You're on the path to greatness",
            "Incredible commitment! Your future self will thank you",
            "Outstanding! Champions are made in moments like these",
            "Excellent work! You're becoming unstoppable",
            "Bravo! Your consistency is your superpower",
            "Impressive! You're writing your success story",
            "Wonderful! Every challenge makes you stronger",
            "Superb dedication! You're leveling up every day",
            "Awesome progress! Your journey inspires us all",
            "Magnificent effort! You're building something great"
        ]
        return motivationalMessages.randomElement() ?? "Great job participating!"
    }
    
    private func formatEventDateFull(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEE, MMM d • h:mm a"
        return formatter.string(from: date)
    }
}

struct EventCardSkeleton: View {
    @EnvironmentObject var themeManager: ThemeManager
    @State private var animationOffset: CGFloat = -200
    
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 20)
                .fill(Color.dynamicSurface(theme: themeManager.currentTheme))
            
            HStack(spacing: 0) {
                Rectangle()
                    .fill(Color.dynamicAccent(theme: themeManager.currentTheme).opacity(0.3))
                    .frame(width: 6)
                
                VStack(alignment: .leading, spacing: 16) {
                    VStack(alignment: .leading, spacing: 12) {
                        Rectangle()
                            .fill(Color.dynamicTextSecondary(theme: themeManager.currentTheme).opacity(0.3))
                            .frame(width: 100, height: 12)
                        
                        Rectangle()
                            .fill(Color.dynamicTextSecondary(theme: themeManager.currentTheme).opacity(0.3))
                            .frame(width: 200, height: 20)
                    }
                    
                    VStack(alignment: .leading, spacing: 8) {
                        Rectangle()
                            .fill(Color.dynamicTextSecondary(theme: themeManager.currentTheme).opacity(0.3))
                            .frame(width: 150, height: 16)
                        
                        Rectangle()
                            .fill(Color.dynamicTextSecondary(theme: themeManager.currentTheme).opacity(0.3))
                            .frame(width: 120, height: 16)
                    }
                    
                    Spacer()
                    
                    HStack {
                        Rectangle()
                            .fill(Color.dynamicTextSecondary(theme: themeManager.currentTheme).opacity(0.3))
                            .frame(width: 80, height: 16)
                        
                        Spacer()
                        
                        Rectangle()
                            .fill(Color.dynamicTextSecondary(theme: themeManager.currentTheme).opacity(0.3))
                            .frame(width: 60, height: 30)
                            .clipShape(Capsule())
                    }
                }
                .padding(.leading, 24)
                .padding(.trailing, 12)
                .padding(.vertical, 24)
            }
            
            // Efecto shimmer
            Rectangle()
                .fill(
                    LinearGradient(
                        gradient: Gradient(colors: [
                            Color.clear,
                            Color.white.opacity(0.3),
                            Color.clear
                        ]),
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .offset(x: animationOffset)
                .clipped()
        }
        .frame(minHeight: 220)
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .onAppear {
            withAnimation(Animation.linear(duration: 1.5).repeatForever(autoreverses: false)) {
                animationOffset = 400
            }
        }
    }
}

#Preview {
    let sampleEvent = Event(
        id: 1,
        title: "Boxing Training",
        description: "High intensity boxing session with Coach John",
        startTime: Date(),
        endTime: Date().addingTimeInterval(3600),
        location: "Main Gym",
        maxParticipants: 10,
        status: .active,
        creatorId: 1,
        createdAt: Date(),
        updatedAt: Date(),
        participantsCount: 5
    )
    
    EventCard(event: sampleEvent)
        .environmentObject(ThemeManager())
        .environmentObject(EventService())
        .padding()
}