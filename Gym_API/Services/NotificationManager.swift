import SwiftUI
import Combine

// MARK: - Achievement Notification Model
struct AchievementNotification: Identifiable, Equatable {
    let id = UUID()
    let title: String
    let subtitle: String
    let icon: String
    let theme: ThemeManager.AppTheme
    let duration: TimeInterval
    
    static func == (lhs: AchievementNotification, rhs: AchievementNotification) -> Bool {
        lhs.id == rhs.id
    }
}

// MARK: - Notification Manager
@MainActor
class NotificationManager: ObservableObject {
    static let shared = NotificationManager()
    
    @Published var currentNotification: AchievementNotification?
    @Published var notificationQueue: [AchievementNotification] = []
    
    private var hideTimer: Timer?
    private var isProcessingQueue = false
    private var recentNotifications: Set<String> = [] // Para evitar duplicados
    private var recentNotificationsCleanupTimer: Timer?
    
    // Sistema de consolidación para clases completadas
    private var pendingClassCompletions: Set<Int> = []
    private var pendingClassNames: [Int: String] = [:]
    private var consolidationTimer: Timer?
    private let consolidationDelay: TimeInterval = 1.0 // 1 segundo para consolidar
    
    private init() {}
    
    // MARK: - Public Methods
    
    /// Añade una nueva notificación a la cola
    func showNotification(
        title: String,
        subtitle: String = "",
        icon: String = "checkmark.circle.fill",
        theme: ThemeManager.AppTheme,
        duration: TimeInterval = 1.5
    ) {
        print("📥 [NotificationManager] showNotification called: '\(title)'")
        
        let notification = AchievementNotification(
            title: title,
            subtitle: subtitle,
            icon: icon,
            theme: theme,
            duration: duration
        )
        
        notificationQueue.append(notification)
        print("📨 Notification queued: \(title) (Queue size: \(notificationQueue.count))")
        
        processQueueIfNeeded()
    }
    
    /// Muestra una notificación de clase completada (con consolidación)
    func showClassCompletedNotification(classId: Int, className: String, theme: ThemeManager.AppTheme) {
        // Asegurar que esto se ejecute en el hilo principal de forma sincrónica
        if Thread.isMainThread {
            addClassCompletion(classId: classId, className: className, theme: theme)
        } else {
            DispatchQueue.main.sync {
                addClassCompletion(classId: classId, className: className, theme: theme)
            }
        }
    }
    
    private func addClassCompletion(classId: Int, className: String, theme: ThemeManager.AppTheme) {
        let notificationId = "class_completed_\(classId)"
        print("🔍 [NotificationManager] Adding class completion: \(classId) (\(className))")
        
        // Verificar si ya se procesó esta clase recientemente
        if recentNotifications.contains(notificationId) {
            print("🔄 Class \(classId) already processed recently, skipping")
            return
        }
        
        // Agregar a recientes inmediatamente
        recentNotifications.insert(notificationId)
        
        // Agregar a pendientes para consolidación
        pendingClassCompletions.insert(classId)
        pendingClassNames[classId] = className
        
        print("📋 [NotificationManager] Pending completions: \(pendingClassCompletions.count)")
        
        // Cancelar timer anterior si existe
        consolidationTimer?.invalidate()
        
        // Iniciar nuevo timer de consolidación
        consolidationTimer = Timer.scheduledTimer(withTimeInterval: consolidationDelay, repeats: false) { _ in
            Task { @MainActor in
                self.processConsolidatedNotification(theme: theme)
            }
        }
        
        // Limpiar cache después de 2 horas para evitar duplicados en diferentes pantallas
        DispatchQueue.main.asyncAfter(deadline: .now() + 7200.0) {
            self.recentNotifications.remove(notificationId)
        }
    }
    
    private func processConsolidatedNotification(theme: ThemeManager.AppTheme) {
        let completedCount = pendingClassCompletions.count
        
        guard completedCount > 0 else {
            print("⚠️ [NotificationManager] No pending completions to process")
            return
        }
        
        print("🎯 [NotificationManager] Processing \(completedCount) consolidated completions")
        
        if completedCount == 1 {
            // Una sola clase - mostrar notificación específica
            let classId = pendingClassCompletions.first!
            let className = pendingClassNames[classId] ?? "Class"
            
            showNotification(
                title: "¡Clase Completada!",
                subtitle: className,
                icon: "trophy.fill",
                theme: theme,
                duration: 2.0
            )
        } else {
            // Múltiples clases - mostrar notificación de racha
            let streakEmojis = ["🔥", "💪", "⚡", "🌟", "🚀"]
            let randomEmoji = streakEmojis.randomElement() ?? "🔥"
            
            showNotification(
                title: "¡Racha Increíble! \(randomEmoji)",
                subtitle: "\(completedCount) clases completadas",
                icon: "flame.fill",
                theme: theme,
                duration: 3.0
            )
        }
        
        // Limpiar estado de consolidación
        pendingClassCompletions.removeAll()
        pendingClassNames.removeAll()
        consolidationTimer?.invalidate()
        consolidationTimer = nil
    }
    
    /// Muestra notificación consolidada para múltiples logros
    func showMultipleClassesCompleted(count: Int, theme: ThemeManager.AppTheme) {
        showNotification(
            title: "\(count) Classes Completed!",
            subtitle: "Amazing streak! Keep it up! 🔥",
            icon: "trophy.fill",
            theme: theme,
            duration: 2.0
        )
    }
    
    /// Fuerza el ocultamiento de la notificación actual
    func hideCurrentNotification() {
        hideTimer?.invalidate()
        hideTimer = nil
        
        // Animación de salida más suave y elegante
        withAnimation(.spring(response: 0.6, dampingFraction: 0.8, blendDuration: 0.2)) {
            currentNotification = nil
        }
        
        // Procesar siguiente en la cola después de la animación
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
            self.processQueueIfNeeded()
        }
    }
    
    /// Limpia toda la cola de notificaciones
    func clearQueue() {
        notificationQueue.removeAll()
        hideCurrentNotification()
        isProcessingQueue = false
        print("🗑️ Notification queue cleared")
    }
    
    // MARK: - Private Methods
    
    private func processQueueIfNeeded() {
        guard !isProcessingQueue else { return }
        guard currentNotification == nil else { return }
        guard !notificationQueue.isEmpty else { return }
        
        isProcessingQueue = true
        let nextNotification = notificationQueue.removeFirst()
        
        print("📱 Showing notification: \(nextNotification.title)")
        
        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
            currentNotification = nextNotification
        }
        
        // Configurar timer para auto-hide con animación suave
        hideTimer = Timer.scheduledTimer(withTimeInterval: nextNotification.duration, repeats: false) { _ in
            Task { @MainActor in
                withAnimation(.spring(response: 0.6, dampingFraction: 0.8, blendDuration: 0.2)) {
                    self.hideCurrentNotification()
                }
                self.isProcessingQueue = false
            }
        }
    }
}

// MARK: - Notification Overlay View
struct NotificationOverlay: View {
    @StateObject private var notificationManager = NotificationManager.shared
    let selectedTab: Int

    var body: some View {
        ZStack {
            if let notification = notificationManager.currentNotification,
               shouldShow(notification) {
                VStack {
                    AchievementNotificationView(notification: notification)
                        .padding(.top, 60) // Debajo del navigation bar
                    Spacer()
                }
                .zIndex(1000)
                .transition(.asymmetric(
                    insertion: .move(edge: .top).combined(with: .opacity).combined(with: .scale(scale: 0.9)),
                    removal: .move(edge: .top).combined(with: .opacity).combined(with: .scale(scale: 0.95))
                ))
                .onTapGesture {
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                        notificationManager.hideCurrentNotification()
                    }
                }
                .gesture(
                    DragGesture()
                        .onEnded { value in
                            // Swipe hacia arriba o hacia los lados para descartar
                            if value.translation.height < -30 || abs(value.translation.width) > 50 {
                                withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                                    notificationManager.hideCurrentNotification()
                                }
                            }
                        }
                )
            }
        }
        .allowsHitTesting(notificationManager.currentNotification != nil)
    }

    private func shouldShow(_ notification: AchievementNotification) -> Bool {
        // Mostrar notificaciones de clase completada solo en la pestaña de Clases (index 1)
        if isClassCompletion(notification) {
            return selectedTab == 1
        }
        return true
    }

    private func isClassCompletion(_ notification: AchievementNotification) -> Bool {
        let title = notification.title.lowercased()
        return title.contains("clase completada") ||
               title.contains("class completed") ||
               title.contains("clases completadas") ||
               title.contains("classes completed")
    }
}

// MARK: - Achievement Notification View
struct AchievementNotificationView: View {
    let notification: AchievementNotification
    
    @State private var scale: CGFloat = 0.3
    @State private var opacity: Double = 0.0
    @State private var iconScale: CGFloat = 0.5
    @State private var glowIntensity: Double = 0.0
    @State private var isDisappearing: Bool = false
    @State private var slideOffset: CGFloat = 0
    
    var isStreakNotification: Bool {
        notification.icon == "flame.fill"
    }
    
    var body: some View {
        HStack(spacing: 16) {
            // Icono de logro con animación especial
            ZStack {
                // Glow effect para notificaciones de racha
                if isStreakNotification {
                    Circle()
                        .fill(Color.dynamicAccent(theme: notification.theme))
                        .frame(width: 50, height: 50)
                        .opacity(glowIntensity)
                        .scaleEffect(1.3)
                        .blur(radius: 4)
                }
                
                // Círculo principal con gradiente
                Circle()
                    .fill(
                        LinearGradient(
                            gradient: Gradient(colors: [
                                Color.dynamicAccent(theme: notification.theme),
                                Color.dynamicAccent(theme: notification.theme).opacity(0.8)
                            ]),
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 48, height: 48)
                    .overlay(
                        Circle()
                            .stroke(.white.opacity(0.2), lineWidth: 1)
                    )
                
                // Icono con escala animada
                Image(systemName: notification.icon)
                    .font(.system(size: isStreakNotification ? 24 : 22, weight: .bold))
                    .foregroundColor(.white)
                    .scaleEffect(iconScale)
            }
            
            // Contenido de texto mejorado
            VStack(alignment: .leading, spacing: 4) {
                Text(notification.title)
                    .font(.system(size: 17, weight: .bold, design: .rounded))
                    .foregroundColor(Color.dynamicText(theme: notification.theme))
                    .lineLimit(1)
                
                if !notification.subtitle.isEmpty {
                    Text(notification.subtitle)
                        .font(.system(size: 15, weight: .medium))
                        .foregroundColor(Color.dynamicTextSecondary(theme: notification.theme))
                        .lineLimit(1)
                }
            }
            
            Spacer()
            
            // Indicador visual adicional para rachas
            if isStreakNotification {
                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(Color.dynamicAccent(theme: notification.theme))
                    .opacity(0.7)
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(
                            LinearGradient(
                                gradient: Gradient(colors: [
                                    Color.dynamicAccent(theme: notification.theme).opacity(0.4),
                                    Color.dynamicAccent(theme: notification.theme).opacity(0.1)
                                ]),
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1.5
                        )
                )
        )
        .shadow(
            color: Color.dynamicAccent(theme: notification.theme).opacity(0.2),
            radius: isStreakNotification ? 16 : 12,
            x: 0,
            y: 8
        )
        .shadow(
            color: Color.black.opacity(notification.theme == .dark ? 0.3 : 0.1),
            radius: 8,
            x: 0,
            y: 4
        )
        .scaleEffect(isDisappearing ? 0.95 : scale)
        .opacity(isDisappearing ? 0.0 : opacity)
        .offset(x: slideOffset, y: 0)
        .rotationEffect(.degrees(isDisappearing ? -2 : 0))
        .onAppear {
            // Animación de entrada
            withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) {
                scale = 1.0
                opacity = 1.0
            }
            
            withAnimation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.1)) {
                iconScale = 1.0
            }
            
            if isStreakNotification {
                withAnimation(.easeInOut(duration: 1.5).repeatCount(2, autoreverses: true).delay(0.2)) {
                    glowIntensity = 0.3
                }
            }
            
            // Programar animación de salida suave
            DispatchQueue.main.asyncAfter(deadline: .now() + notification.duration - 0.5) {
                withAnimation(.spring(response: 0.4, dampingFraction: 0.9)) {
                    isDisappearing = true
                    slideOffset = 50
                }
            }
        }
        .padding(.horizontal, 20)
    }
}

// MARK: - Environment Key for Notification Manager
struct NotificationManagerKey: EnvironmentKey {
    static let defaultValue = NotificationManager.shared
}

extension EnvironmentValues {
    var notificationManager: NotificationManager {
        get { self[NotificationManagerKey.self] }
        set { self[NotificationManagerKey.self] = newValue }
    }
}
