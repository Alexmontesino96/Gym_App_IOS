import SwiftUI

// MARK: - Comeback View
/// Vista principal de re-engagement cuando el usuario tiene racha en 0
/// Muestra mensaje personalizado según días de inactividad y motiva a agendar clase
struct ComebackView: View {
    @EnvironmentObject var themeManager: ThemeManager
    @Environment(\.dismiss) private var dismiss

    let daysInactive: Int
    let userName: String
    let lastClass: String?
    let bestStreak: Int
    let onScheduleClass: () -> Void

    @State private var isPresented = false
    @State private var classWasScheduled = false
    @State private var cachedMessage: ComebackMessage?
    @State private var cachedQuote: String?
    @State private var classScheduledObserver: NSObjectProtocol?

    // MARK: - Computed Properties

    private var message: ComebackMessage {
        // Usar mensaje cacheado para evitar cambios durante drag
        cachedMessage ?? ComebackMessage(
            emoji: "🌟",
            title: "¡Hola!",
            message: "Cargando...",
            tone: .encouraging,
            urgency: .medium
        )
    }

    // MARK: - Body

    var body: some View {
        // Sheet nativo - sin ZStack, background ni drag gesture manual
        ScrollView {
            VStack(spacing: 24) {
                // Hero section con mensaje emocional
                ComebackHeroSection(
                    message: message,
                    userName: userName,
                    theme: themeManager.currentTheme
                )
                .padding(.top, 20)

                // Tarjeta de última actividad
                LastActivityCard(
                    lastClass: lastClass,
                    daysAgo: daysInactive,
                    bestStreak: bestStreak,
                    theme: themeManager.currentTheme
                )
                .padding(.horizontal, 20)

                // Quote motivacional (solo para días 8+)
                if daysInactive >= 8 {
                    motivationalQuote
                        .padding(.horizontal, 20)
                }

                // CTAs
                ComebackCTASection(
                    theme: themeManager.currentTheme,
                    urgency: message.urgency,
                    onScheduleClass: {
                        dismissView()  // Cierra temporalmente
                        onScheduleClass()
                    },
                    onDismiss: {
                        dismissViewAndMarkShown()  // Cierra Y marca como mostrado
                    }
                )
                .padding(.horizontal, 20)
                .padding(.bottom, 32)
            }
        }
        .background(Color.dynamicBackground(theme: themeManager.currentTheme))
        .opacity(isPresented ? 1.0 : 0.0)
        .onAppear {
            // Cachear mensaje al inicio para evitar cambios durante drag
            if cachedMessage == nil {
                cachedMessage = ComebackMessageProvider.getMessage(
                    daysInactive: daysInactive,
                    userName: userName
                )
            }

            // Cachear quote al inicio para evitar cambios durante drag
            if cachedQuote == nil {
                cachedQuote = getMotivationalQuote()
            }

            withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                isPresented = true
            }

            // Track view shown event
            trackComebackViewShown()

            // Setup listener para agendamiento exitoso
            setupClassScheduledListener()
        }
        .onChange(of: classWasScheduled) { _, newValue in
            if newValue {
                // Usuario agendó clase exitosamente
                dismissViewWithSuccess()
            }
        }
        .onDisappear {
            // Remover observer al cerrar la vista
            if let observer = classScheduledObserver {
                NotificationCenter.default.removeObserver(observer)
                classScheduledObserver = nil
            }
        }
    }

    // MARK: - Subviews

    private var motivationalQuote: some View {
        VStack(spacing: 8) {
            Image(systemName: "quote.opening")
                .font(.system(size: 16))
                .foregroundColor(Color.dynamicTextSecondary(theme: themeManager.currentTheme).opacity(0.5))

            Text(cachedQuote ?? "")
                .font(.system(size: 15, weight: .medium, design: .rounded))
                .foregroundColor(Color.dynamicTextSecondary(theme: themeManager.currentTheme))
                .multilineTextAlignment(.center)
                .italic()
                .lineLimit(3)

            Image(systemName: "quote.closing")
                .font(.system(size: 16))
                .foregroundColor(Color.dynamicTextSecondary(theme: themeManager.currentTheme).opacity(0.5))
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.dynamicSurface(theme: themeManager.currentTheme).opacity(0.5))
        )
    }

    // MARK: - Helper Methods

    private func dismissView() {
        let impact = UIImpactFeedbackGenerator(style: .soft)
        impact.impactOccurred()

        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
            isPresented = false
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            dismiss()
        }

        // NO marcar como mostrado - permite reapertura
        debugLog("🔄 [ComebackView] Modal cerrado temporalmente - Puede reabrirse")
    }

    private func dismissViewWithSuccess() {
        let notification = UINotificationFeedbackGenerator()
        notification.notificationOccurred(.success)

        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
            isPresented = false
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            dismiss()
        }

        // Marcar como mostrado solo cuando hay agendamiento exitoso
        markAsShownToday()
        debugLog("✅ [ComebackView] Usuario agendó clase - Modal cerrado hasta mañana")
    }

    private func dismissViewAndMarkShown() {
        let impact = UIImpactFeedbackGenerator(style: .soft)
        impact.impactOccurred()

        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
            isPresented = false
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            dismiss()
        }

        // Marcar como mostrado cuando usuario pospone explícitamente
        markAsShownToday()
        debugLog("⏰ [ComebackView] Usuario pospuso - Modal no aparecerá hasta mañana")
    }

    private func setupClassScheduledListener() {
        // Remover observer anterior si existe (prevenir duplicados)
        if let observer = classScheduledObserver {
            NotificationCenter.default.removeObserver(observer)
        }

        // Agregar observer y guardarlo para poder removerlo después
        classScheduledObserver = NotificationCenter.default.addObserver(
            forName: .classScheduledSuccessfully,
            object: nil,
            queue: .main
        ) { [self] _ in
            // Solo procesar si la vista sigue presente
            guard isPresented else { return }

            debugLog("✅ [ComebackView] Notificación de clase agendada recibida")
            classWasScheduled = true
        }
    }

    private func getMotivationalQuote() -> String {
        let quotes = [
            "El día más difícil es el primero. ¡Tú puedes!",
            "No se trata de ser el mejor, sino de ser mejor que ayer.",
            "Tu cuerpo puede soportar casi cualquier cosa. Es tu mente la que necesitas convencer.",
            "El dolor que sientes hoy será la fuerza que sentirás mañana.",
            "Cada experto fue alguna vez un principiante.",
            "La motivación es lo que te pone en marcha. El hábito es lo que te mantiene en movimiento."
        ]
        return quotes.randomElement() ?? quotes[0]
    }

    private func markAsShownToday() {
        let today = Calendar.current.startOfDay(for: Date())
        UserDefaults.standard.set(today, forKey: "lastComebackViewShown")
    }

    private func trackComebackViewShown() {
        // TODO: Implementar tracking con analytics
        debugLog("📊 Comeback view shown - Days inactive: \(daysInactive), Urgency: \(message.urgency)")
    }
}

// MARK: - Helper Extension for Showing Comeback View

extension ComebackView {
    /// Verifica si la vista de comeback debe mostrarse hoy
    static func shouldShowToday() -> Bool {
        guard let lastShown = UserDefaults.standard.object(forKey: "lastComebackViewShown") as? Date else {
            return true
        }

        let today = Calendar.current.startOfDay(for: Date())
        let lastShownDay = Calendar.current.startOfDay(for: lastShown)

        return today > lastShownDay
    }
}

// MARK: - Preview
#Preview {
    ZStack {
        Color.gray.ignoresSafeArea()

        ComebackView(
            daysInactive: 5,
            userName: "Alex",
            lastClass: "Spinning Avanzado",
            bestStreak: 12,
            onScheduleClass: {
                print("Schedule class tapped")
            }
        )
        .environmentObject(ThemeManager())
    }
}
