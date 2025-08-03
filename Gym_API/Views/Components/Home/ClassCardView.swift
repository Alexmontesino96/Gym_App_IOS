import SwiftUI

// MARK: - Class Action State Management
enum ClassActionState {
    case available
    case registered
    case full 
    case live
    case completed
    case cancelled
    
    struct ActionConfig {
        let text: String
        let icon: String
        let primaryColor: Color
        let backgroundColor: Color
        let isDisabled: Bool
        
        init(text: String, icon: String, primaryColor: Color, backgroundColor: Color? = nil, isDisabled: Bool = false) {
            self.text = text
            self.icon = icon
            self.primaryColor = primaryColor
            self.backgroundColor = backgroundColor ?? primaryColor.opacity(0.1)
            self.isDisabled = isDisabled
        }
    }
    
    func config(theme: ThemeManager.AppTheme) -> ActionConfig {
        switch self {
        case .available:
            return ActionConfig(
                text: "Join",
                icon: "plus.circle.fill",
                primaryColor: Color.dynamicAccent(theme: theme)
            )
        case .registered:
            return ActionConfig(
                text: "Registered",
                icon: "checkmark.circle.fill",
                primaryColor: Color(red: 0.22, green: 0.78, blue: 0.22), // Verde fitness
                isDisabled: true
            )
        case .full:
            return ActionConfig(
                text: "Full",
                icon: "person.2.fill",
                primaryColor: Color.gray,
                isDisabled: true
            )
        case .live:
            return ActionConfig(
                text: "Live",
                icon: "dot.radiowaves.left.and.right",
                primaryColor: Color.dynamicAccent(theme: theme),
                isDisabled: true
            )
        case .completed:
            return ActionConfig(
                text: "Completed",
                icon: "checkmark.seal.fill",
                primaryColor: Color.gray,
                isDisabled: true
            )
        case .cancelled:
            return ActionConfig(
                text: "Cancelled",
                icon: "xmark.circle.fill",
                primaryColor: Color.red,
                isDisabled: true
            )
        }
    }
}

// MARK: - Reusable Components

/// Componente reutilizable para mostrar estadísticas en formato pill
struct StatsPill: View {
    let text: String
    let icon: String?
    let color: Color
    let theme: ThemeManager.AppTheme
    
    init(_ text: String, icon: String? = nil, color: Color, theme: ThemeManager.AppTheme) {
        self.text = text
        self.icon = icon
        self.color = color
        self.theme = theme
    }
    
    var body: some View {
        HStack(spacing: 4) {
            if let icon = icon {
                Image(systemName: icon)
                    .font(.system(size: 10, weight: .semibold))
            }
            Text(text)
                .font(.system(size: 11, weight: .semibold))
        }
        .foregroundColor(color)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(
            Capsule()
                .fill(color.opacity(0.15))
                .overlay(
                    Capsule()
                        .stroke(color.opacity(0.3), lineWidth: 1)
                )
        )
    }
}

/// Indicador Live con animación de pulso
struct LiveIndicator: View {
    let theme: ThemeManager.AppTheme
    @State private var isPulsing = false
    
    var body: some View {
        HStack(spacing: 4) {
            Circle()
                .fill(Color.dynamicAccent(theme: theme))
                .frame(width: 6, height: 6)
                .scaleEffect(isPulsing ? 1.2 : 1.0)
                .opacity(isPulsing ? 0.7 : 1.0)
                .animation(.easeInOut(duration: 1.0).repeatForever(autoreverses: true), value: isPulsing)
            
            Text("LIVE")
                .font(.system(size: 10, weight: .bold))
                .foregroundColor(Color.dynamicAccent(theme: theme))
        }
        .onAppear {
            isPulsing = true
        }
    }
}

/// Iconos específicos para tipos de clases fitness
struct ClassTypeIcon: View {
    let className: String
    let theme: ThemeManager.AppTheme
    
    private var fitnessIcon: String {
        let lowercaseName = className.lowercased()
        
        if lowercaseName.contains("box") {
            return "figure.boxing"
        } else if lowercaseName.contains("yoga") {
            return "figure.mind.and.body"
        } else if lowercaseName.contains("run") || lowercaseName.contains("cardio") {
            return "figure.run"
        } else if lowercaseName.contains("strength") || lowercaseName.contains("weight") {
            return "dumbbell.fill"
        } else if lowercaseName.contains("dance") {
            return "figure.dance"
        } else if lowercaseName.contains("cycle") || lowercaseName.contains("spin") {
            return "figure.indoor.cycle"
        } else if lowercaseName.contains("swim") {
            return "figure.pool.swim"
        } else if lowercaseName.contains("climb") {
            return "figure.climbing"
        } else {
            return "figure.strengthtraining.traditional"
        }
    }
    
    var body: some View {
        Image(systemName: fitnessIcon)
            .font(.system(size: 16, weight: .semibold))
            .foregroundColor(Color.dynamicAccent(theme: theme))
            .frame(width: 20, height: 20)
    }
}

/// Botón de acción moderno con micro-animaciones
struct ModernActionButton: View {
    let config: ClassActionState.ActionConfig
    let isLoading: Bool
    let action: () -> Void
    let theme: ThemeManager.AppTheme
    
    @State private var isPressed = false
    
    var body: some View {
        Button(action: {
            print("🔴 Botón presionado - Disabled: \(config.isDisabled), Loading: \(isLoading)")
            if !config.isDisabled && !isLoading {
                print("🔴 Ejecutando acción del botón")
                action()
            } else {
                print("❌ Botón deshabilitado - No se ejecutará acción")
            }
        }) {
            HStack(spacing: 6) {
                if isLoading {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        .scaleEffect(0.8)
                } else {
                    Image(systemName: config.icon)
                        .font(.system(size: 12, weight: .semibold))
                    Text(config.text)
                        .font(.system(size: 14, weight: .semibold))
                }
            }
            .foregroundColor(config.isDisabled ? Color.dynamicTextSecondary(theme: theme) : .white)
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(config.isDisabled ? Color.dynamicSurface(theme: theme) : config.primaryColor)
                    .overlay(
                        config.isDisabled ?
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color.dynamicBorder(theme: theme), lineWidth: 1) : nil
                    )
            )
            .scaleEffect(isPressed ? 0.95 : 1.0)
            .opacity(config.isDisabled ? 0.6 : 1.0)
        }
        .disabled(config.isDisabled || isLoading)
        .onLongPressGesture(minimumDuration: 0, maximumDistance: .infinity, pressing: { pressing in
            withAnimation(.easeInOut(duration: 0.1)) {
                isPressed = pressing
            }
        }, perform: {})
    }
}

// MARK: - Main Class Card View
struct ClassCardView: View {
    @EnvironmentObject var themeManager: ThemeManager
    let gymClass: GymClass
    @EnvironmentObject var classService: ClassService
    @State private var trainerImageURL: String = ""
    @State private var cardPressed = false
    @State private var cachedActionState: ClassActionState = .available
    @State private var lastStateUpdateTime: Date = Date()
    
    var body: some View {
        VStack(spacing: 0) {
            // Header con indicador de estado
            if currentActionState == .live {
                HStack {
                    LiveIndicator(theme: themeManager.currentTheme)
                    Spacer()
                }
                .padding(.horizontal, 20)
                .padding(.top, 12)
                .padding(.bottom, 8)
            }
            
            // Contenido principal
            VStack(alignment: .leading, spacing: 16) {
                // Header: Título y tiempo
                VStack(alignment: .leading, spacing: 8) {
                    HStack(alignment: .top, spacing: 12) {
                        // Icono de tipo de clase
                        ClassTypeIcon(className: gymClass.name, theme: themeManager.currentTheme)
                        
                        VStack(alignment: .leading, spacing: 4) {
                            // Nombre de clase con jerarquía optimizada (17pt)
                            Text(gymClass.name)
                                .font(.system(size: 17, weight: .bold))
                                .foregroundColor(Color.dynamicText(theme: themeManager.currentTheme))
                                .lineLimit(1)
                                .accessibilityLabel("Class name: \(gymClass.name)")
                            
                            // Tiempo con mejor formato
                            HStack(spacing: 6) {
                                Image(systemName: "clock")
                                    .font(.system(size: 12))
                                    .foregroundColor(Color.dynamicTextSecondary(theme: themeManager.currentTheme))
                                Text(formattedTimeWithDuration)
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundColor(Color.dynamicTextSecondary(theme: themeManager.currentTheme))
                            }
                        }
                        
                        Spacer()
                    }
                }
                
                // Stats Pills compactos
                HStack(spacing: 8) {
                    StatsPill(
                        "\(duration)min",
                        icon: "timer",
                        color: Color.dynamicTextSecondary(theme: themeManager.currentTheme),
                        theme: themeManager.currentTheme
                    )
                    
                    StatsPill(
                        spotsText,
                        icon: availableSpots > 0 ? "person.2" : "person.2.fill",
                        color: spotsColor,
                        theme: themeManager.currentTheme
                    )
                    
                    StatsPill(
                        difficultyText,
                        color: difficultyColor,
                        theme: themeManager.currentTheme
                    )
                    
                    Spacer()
                }
                
                // Bottom: Instructor y Action
                HStack(spacing: 12) {
                    // Instructor info compacto con estado de error
                    HStack(spacing: 8) {
                        AsyncImage(url: URL(string: trainerImageURL)) { phase in
                            switch phase {
                            case .success(let image):
                                image
                                    .resizable()
                                    .aspectRatio(contentMode: .fill)
                                    .frame(width: 32, height: 32)
                                    .clipShape(Circle())
                            case .failure(_), .empty:
                                Circle()
                                    .fill(Color.dynamicSurface(theme: themeManager.currentTheme))
                                    .frame(width: 32, height: 32)
                                    .overlay(
                                        Group {
                                            if classService.isLoadingTrainers {
                                                ProgressView()
                                                    .progressViewStyle(CircularProgressViewStyle(tint: Color.dynamicTextSecondary(theme: themeManager.currentTheme)))
                                                    .scaleEffect(0.8)
                                            } else if classService.authenticationError {
                                                Image(systemName: "exclamationmark.triangle.fill")
                                                    .font(.system(size: 12))
                                                    .foregroundColor(.orange)
                                            } else {
                                                Image(systemName: "person.fill")
                                                    .font(.system(size: 14))
                                                    .foregroundColor(Color.dynamicTextSecondary(theme: themeManager.currentTheme))
                                            }
                                        }
                                    )
                            @unknown default:
                                Circle()
                                    .fill(Color.dynamicSurface(theme: themeManager.currentTheme))
                                    .frame(width: 32, height: 32)
                            }
                        }
                        
                        VStack(alignment: .leading, spacing: 0) {
                            Text(instructorDisplayName)
                                .font(.system(size: 13, weight: .medium))
                                .foregroundColor(
                                    classService.authenticationError ? 
                                    .orange : Color.dynamicText(theme: themeManager.currentTheme)
                                )
                                .lineLimit(1)
                        }
                    }
                    
                    Spacer()
                    
                    // Action button moderno
                    if currentActionState == .registered {
                        HStack(spacing: 8) {
                            ModernActionButton(
                                config: currentActionState.config(theme: themeManager.currentTheme),
                                isLoading: false,
                                action: {},
                                theme: themeManager.currentTheme
                            )
                            
                            // Botón cancelar compacto
                            Button(action: {
                                print("🔴 Cancelando registro para clase \(gymClass.id): \(gymClass.name)")
                                Task {
                                    await classService.cancelClassRegistration(classId: gymClass.id, reason: "User cancelled from app")
                                    print("✅ Proceso de cancelación completado para \(gymClass.id)")
                                }
                            }) {
                                if classService.cancellingClassIds.contains(gymClass.id) {
                                    ProgressView()
                                        .progressViewStyle(CircularProgressViewStyle(tint: .red))
                                        .scaleEffect(0.7)
                                } else {
                                    Image(systemName: "xmark")
                                        .font(.system(size: 10, weight: .semibold))
                                }
                            }
                            .foregroundColor(.red)
                            .frame(width: 28, height: 28)
                            .background(
                                Circle()
                                    .stroke(Color.red.opacity(0.3), lineWidth: 1)
                            )
                        }
                    } else {
                        ModernActionButton(
                            config: currentActionState.config(theme: themeManager.currentTheme),
                            isLoading: isLoadingAction,
                            action: {
                                print("🔴 Intentando unirse a la clase \(gymClass.id): \(gymClass.name)")
                                Task {
                                    await classService.joinClass(classId: gymClass.id)
                                    print("✅ Proceso de unirse a clase completado para \(gymClass.id)")
                                }
                            },
                            theme: themeManager.currentTheme
                        )
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, currentActionState == .live ? 8 : 16)
            .padding(.bottom, 16)
        }
        .background(
            // Glassmorphism effect
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.dynamicSurface(theme: themeManager.currentTheme))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(
                            currentActionState == .live ? 
                            Color.dynamicAccent(theme: themeManager.currentTheme).opacity(0.3) :
                            Color.dynamicBorder(theme: themeManager.currentTheme).opacity(0.1),
                            lineWidth: currentActionState == .live ? 1.5 : 0.5
                        )
                )
                .shadow(
                    color: Color.black.opacity(themeManager.currentTheme == .dark ? 0.1 : 0.05),
                    radius: 8,
                    x: 0,
                    y: 2
                )
        )
        .scaleEffect(cardPressed ? 0.98 : 1.0)
        .animation(.spring(response: 0.3, dampingFraction: 0.8, blendDuration: 0), value: cardPressed)
        .onAppear {
            print("🔍 ClassCardView onAppear - Clase: \(gymClass.name)")
            print("🔍 AuthService configurado: \(classService.authService != nil)")
            print("🔍 Trainers en cache: \(classService.trainers.count)")
            
            // Cargar trainers si no están cargados o hay error de autenticación
            if classService.trainers.isEmpty || classService.authenticationError {
                print("🔍 Cargando trainers porque el cache está vacío o hay error de auth")
                Task {
                    await classService.loadTrainers()
                    updateTrainerImage()
                }
            } else {
                print("🔍 Usando trainers del cache")
                updateTrainerImage()
            }
        }
        .onChange(of: classService.trainers.count) { _, _ in
            updateTrainerImage()
        }
        .onChange(of: classService.userRegistrationStatus) { _, _ in
            // Forzar recálculo del estado cuando cambie el estado de registro
            DispatchQueue.main.async {
                self.lastStateUpdateTime = Date().addingTimeInterval(-10) // Forzar recálculo
                print("🔄 Forzando actualización de estado para clase \(gymClass.id)")
            }
        }
        .onChange(of: classService.joiningClassIds.count) { _, _ in
            // Forzar recálculo cuando termine una operación de join
            if !classService.joiningClassIds.contains(gymClass.id) {
                DispatchQueue.main.async {
                    self.lastStateUpdateTime = Date().addingTimeInterval(-10) // Forzar recálculo
                    print("🔄 Operación de join completada, forzando actualización para clase \(gymClass.id)")
                }
            }
        }
        .onTapGesture {
            // Micro-animación de tap
            withAnimation(.easeInOut(duration: 0.1)) {
                cardPressed = true
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                withAnimation(.easeInOut(duration: 0.1)) {
                    cardPressed = false
                }
            }
            
            // Si hay error de autenticación, intentar recargar trainers
            if classService.authenticationError {
                print("🔄 Reintentando cargar trainers después de tap en tarjeta con error de auth")
                Task {
                    await classService.loadTrainers()
                }
            }
        }
    }
    
    // MARK: - Computed Properties
    
    /// Obtiene el estado actual con caching para evitar re-evaluaciones innecesarias
    private var currentActionState: ClassActionState {
        let now = Date()
        let timeSinceLastUpdate = now.timeIntervalSince(lastStateUpdateTime)
        
        // Re-evaluar solo si han pasado más de 2 segundos o si cambió el estado de registro
        let shouldRecalculate = timeSinceLastUpdate > 2.0 || 
                               (cachedActionState != .registered && classService.isUserRegistered(classId: gymClass.id)) ||
                               (cachedActionState == .registered && !classService.isUserRegistered(classId: gymClass.id))
        
        if shouldRecalculate {
            cachedActionState = calculateActionState()
            lastStateUpdateTime = now
            print("🔄 Estado recalculado para clase \(gymClass.id): \(cachedActionState)")
        }
        
        return cachedActionState
    }
    
    /// Calcula el estado actual de la clase para la UI
    private func calculateActionState() -> ClassActionState {
        print("🔍 Evaluando estado para clase \(gymClass.id): \(gymClass.name)")
        let now = Date()
        
        // Verificar si está cancelada
        if gymClass.status == .cancelled {
            return .cancelled
        }
        
        // Verificar si está completada
        if gymClass.status == .completed || now > gymClass.endTime {
            return .completed
        }
        
        // Verificar si está en vivo
        if now >= gymClass.startTime && now <= gymClass.endTime {
            return .live
        }
        
        // Verificar si está registrado
        let isRegistered = classService.isUserRegistered(classId: gymClass.id)
        print("🔍 Usuario registrado en clase \(gymClass.id): \(isRegistered)")
        print("🔍 Estado actual en userRegistrationStatus: \(classService.userRegistrationStatus[gymClass.id] ?? false)")
        if isRegistered {
            let state = ClassActionState.registered
            print("✅ Estado final para clase \(gymClass.id): \(state)")
            return state
        }
        
        // Verificar si está llena
        if gymClass.currentParticipants >= gymClass.maxParticipants {
            return .full
        }
        
        // Por defecto, disponible
        let state = ClassActionState.available
        print("🔍 Estado final para clase \(gymClass.id): \(state)")
        return state
    }
    
    /// Estado de carga para acciones
    private var isLoadingAction: Bool {
        let isLoading = classService.joiningClassIds.contains(gymClass.id)
        if isLoading {
            print("🔄 Clase \(gymClass.id) está en proceso de join")
        }
        return isLoading
    }
    
    /// Duración de la clase en minutos
    private var duration: Int {
        let duration = gymClass.endTime.timeIntervalSince(gymClass.startTime)
        return Int(duration / 60)
    }
    
    /// Plazas disponibles
    private var availableSpots: Int {
        return gymClass.maxParticipants - gymClass.currentParticipants
    }
    
    /// Hora formateada con duración
    private var formattedTimeWithDuration: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"
        
        // Obtener las zonas horarias
        let userTimezone = TimeZone.current
        let gymTimezoneString = gymClass.gymTimezone ?? "America/New_York"
        let gymTimezone = TimeZone(identifier: gymTimezoneString) ?? TimeZone.current
        
        // Si las zonas horarias son iguales, no hacer conversión
        if userTimezone.identifier == gymTimezone.identifier {
            formatter.timeZone = TimeZone.current
        } else {
            // Si son diferentes, usar la zona horaria del gimnasio
            formatter.timeZone = gymTimezone
        }
        
        return formatter.string(from: gymClass.startTime)
    }
    
    /// Nombre del instructor con manejo de errores
    private var instructorDisplayName: String {
        if classService.authenticationError {
            return "Login required"
        } else if classService.isLoadingTrainers {
            return "Loading..."
        } else if classService.trainersErrorMessage != nil {
            return "Error loading"
        } else {
            return gymClass.instructor
        }
    }
    
    /// Actualiza la imagen del trainer desde el servicio
    private func updateTrainerImage() {
        print("🔍 Actualizando imagen del trainer ID: \(gymClass.trainerId)")
        print("🔍 Trainers disponibles: \(classService.trainers.count)")
        
        if let trainer = classService.getTrainer(trainerId: gymClass.trainerId) {
            let pictureURL = trainer.picture ?? ""
            print("✅ Trainer encontrado: \(trainer.fullName), Picture URL: \(pictureURL)")
            DispatchQueue.main.async {
                self.trainerImageURL = pictureURL
            }
        } else {
            print("❌ Trainer no encontrado para ID: \(gymClass.trainerId)")
            DispatchQueue.main.async {
                self.trainerImageURL = ""
            }
        }
    }
    
    /// Texto de dificultad
    private var difficultyText: String {
        switch gymClass.difficulty {
        case .beginner: return "Beginner"
        case .intermediate: return "Intermediate" 
        case .advanced: return "Advanced"
        }
    }
    
    /// Color de dificultad
    private var difficultyColor: Color {
        switch gymClass.difficulty {
        case .beginner: return Color(red: 0.22, green: 0.78, blue: 0.22) // Verde
        case .intermediate: return Color(red: 0.96, green: 0.62, blue: 0.04) // Naranja
        case .advanced: return Color(red: 0.94, green: 0.27, blue: 0.27) // Rojo
        }
    }
    
    /// Texto de plazas disponibles
    private var spotsText: String {
        if availableSpots <= 0 {
            return "Full"
        } else if availableSpots == 1 {
            return "1 spot"
        } else {
            return "\(availableSpots) spots"
        }
    }
    
    /// Color para plazas disponibles
    private var spotsColor: Color {
        if availableSpots <= 0 {
            return Color.gray
        } else if availableSpots <= 3 {
            return Color(red: 0.94, green: 0.27, blue: 0.27) // Rojo - pocas plazas
        } else {
            return Color(red: 0.96, green: 0.62, blue: 0.04) // Naranja - disponible
        }
    }
}

// MARK: - Preview
#Preview {
    let sampleClasses = [
        GymClass(
            id: 1,
            name: "Boxing Fundamentals",
            description: "Learn the basics of boxing",
            instructor: "Coach Mike",
            trainerId: 1,
            startTime: Date().addingTimeInterval(3600), // En 1 hora
            endTime: Date().addingTimeInterval(7200), // 2 horas
            maxParticipants: 15,
            currentParticipants: 8,
            difficulty: .beginner,
            status: .available
        ),
        GymClass(
            id: 2,
            name: "Advanced Yoga Flow",
            description: "Dynamic yoga session",
            instructor: "Sarah Johnson",
            trainerId: 2,
            startTime: Date().addingTimeInterval(-1800), // Hace 30 min (en vivo)
            endTime: Date().addingTimeInterval(1800), // En 30 min
            maxParticipants: 12,
            currentParticipants: 7,
            difficulty: .advanced,
            status: .available
        ),
        GymClass(
            id: 3,
            name: "HIIT Training",
            description: "High intensity workout",
            instructor: "Coach Alex",
            trainerId: 3,
            startTime: Date().addingTimeInterval(1800), // En 30 min
            endTime: Date().addingTimeInterval(5400), // 1.5 horas
            maxParticipants: 10,
            currentParticipants: 10, // Llena
            difficulty: .intermediate,
            status: .available
        )
    ]
    
    VStack(spacing: 16) {
        ForEach(sampleClasses) { gymClass in
            ClassCardView(gymClass: gymClass)
        }
    }
    .padding()
    .background(Color.dynamicBackground(theme: .dark))
    .environmentObject(ThemeManager())
    .environmentObject(ClassService())
}