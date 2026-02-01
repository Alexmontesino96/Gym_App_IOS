//
//  SessionPill.swift
//  Gym_API
//
//  Componente minimalista para mostrar sesión etiquetada en posts
//

import SwiftUI
import Foundation

// MARK: - SessionPillContainer

/// Container view que carga y muestra una sesión etiquetada
struct SessionPillContainer: View {
    @StateObject private var cacheService = SessionCacheService.shared
    @EnvironmentObject var themeManager: ThemeManager

    let sessionTag: PostTag
    @State private var session: AttendedClass?
    @State private var isLoading = true

    var body: some View {
        Group {
            if isLoading {
                // Placeholder mientras carga
                HStack(spacing: 6) {
                    ProgressView()
                        .scaleEffect(0.8)
                    Text("Cargando sesión...")
                        .font(.system(size: 12))
                        .foregroundColor(.gray)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(
                    RoundedRectangle(cornerRadius: 14)
                        .fill(Color.gray.opacity(0.1))
                )
                .sessionShimmering()
            } else if let session = session {
                // Mostrar el pill con la sesión cargada
                SessionPill(session: session)
                    .environmentObject(themeManager)
                    .transition(.opacity.combined(with: .scale))
            }
        }
        .task {
            await loadSession()
        }
    }

    private func loadSession() async {
        isLoading = true

        // SIEMPRE mostrar una sesión de prueba para verificar que funciona
        // Los nombres varían según el ID para simular diferentes clases
        let classNames = ["HIIT Cardio", "Yoga Flow", "CrossFit", "Spinning", "Boxing", "Pilates"]
        let instructors = ["Sarah Miller", "John Doe", "Emma Wilson", "Mike Johnson", "Lisa Chen", "Tom Smith"]
        let index = sessionTag.tagId % classNames.count

        let mockSession = AttendedClass(
            id: sessionTag.tagId,
            classId: 100 + sessionTag.tagId,
            className: classNames[index],
            instructor: instructors[index],
            startTime: Date().addingTimeInterval(-3600),
            endTime: Date().addingTimeInterval(-1800),
            checkinTime: Date().addingTimeInterval(-3600),
            checkoutTime: Date().addingTimeInterval(-1800)
        )

        // Simular delay de red muy corto
        try? await Task.sleep(nanoseconds: 100_000_000) // 0.1 segundos

        withAnimation(.easeInOut(duration: 0.3)) {
            self.session = mockSession
            self.isLoading = false
        }

        print("🏷️ SessionPillContainer: Loaded session for tag \(sessionTag.tagId) - \(mockSession.className)")
    }
}

// MARK: - Shimmer Effect

extension View {
    func sessionShimmering() -> some View {
        self.modifier(SessionShimmerModifier())
    }
}

struct SessionShimmerModifier: ViewModifier {
    @State private var phase = 0.0

    func body(content: Content) -> some View {
        content
            .overlay(
                LinearGradient(
                    colors: [
                        Color.clear,
                        Color.white.opacity(0.3),
                        Color.clear
                    ],
                    startPoint: .leading,
                    endPoint: .trailing
                )
                .rotationEffect(.degrees(30))
                .offset(x: phase * 200 - 100)
                .mask(content)
            )
            .onAppear {
                withAnimation(
                    .linear(duration: 1.5)
                    .repeatForever(autoreverses: false)
                ) {
                    phase = 1
                }
            }
    }
}

/// Pill compacta que muestra información de sesión con drawer expandible
struct SessionPill: View {
    let session: AttendedClass
    @State private var isExpanded = false
    @State private var showFullDetails = false
    @EnvironmentObject var themeManager: ThemeManager

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Pill compacta siempre visible
            pillView

            // Drawer expandido con animación
            if isExpanded {
                SessionDetailsDrawer(
                    session: session,
                    onClose: {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                            isExpanded = false
                        }
                    },
                    onViewDetails: {
                        showFullDetails = true
                    }
                )
                .transition(.asymmetric(
                    insertion: .move(edge: .top).combined(with: .opacity),
                    removal: .move(edge: .top).combined(with: .opacity)
                ))
                .zIndex(1)
            }
        }
        .sheet(isPresented: $showFullDetails) {
            SessionFullDetailsSheet(session: session)
                .environmentObject(themeManager)
        }
    }

    private var pillView: some View {
        Button(action: {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                isExpanded.toggle()

                // Haptic feedback
                let impactFeedback = UIImpactFeedbackGenerator(style: .light)
                impactFeedback.prepare()
                impactFeedback.impactOccurred()
            }
        }) {
            HStack(spacing: 6) {
                // Icono con animación de rotación
                Image(systemName: iconForClass(session.className))
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(Color(hex: "#D93333") ?? .red)
                    .rotationEffect(.degrees(isExpanded ? 15 : 0))
                    .animation(.spring(response: 0.3), value: isExpanded)

                // Texto principal
                Text("\(session.className)")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(Color(hex: "#D93333") ?? .red)

                // Separador
                Text("•")
                    .font(.system(size: 10))
                    .foregroundColor((Color(hex: "#D93333") ?? .red).opacity(0.6))

                // Tiempo
                Text(session.timeAgoText)
                    .font(.system(size: 11))
                    .foregroundColor((Color(hex: "#D93333") ?? .red).opacity(0.8))

                // Indicador de expansión
                Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundColor((Color(hex: "#D93333") ?? .red).opacity(0.6))
                    .animation(.spring(response: 0.3), value: isExpanded)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill((Color(hex: "#D93333") ?? .red).opacity(0.1))
                    .overlay(
                        RoundedRectangle(cornerRadius: 14)
                            .stroke(
                                session.isRecentlyCompleted ?
                                (Color(hex: "#D93333") ?? .red).opacity(0.4) :
                                (Color(hex: "#D93333") ?? .red).opacity(0.2),
                                lineWidth: 1
                            )
                    )
            )
            .scaleEffect(session.isRecentlyCompleted ? 1.02 : 1.0)
            .animation(
                session.isRecentlyCompleted ?
                Animation.easeInOut(duration: 2.0).repeatForever(autoreverses: true) : nil,
                value: session.isRecentlyCompleted
            )
        }
        .buttonStyle(PlainButtonStyle())
    }

    private func iconForClass(_ className: String) -> String {
        let lowercased = className.lowercased()
        if lowercased.contains("yoga") { return "figure.yoga" }
        if lowercased.contains("pilates") { return "figure.pilates" }
        if lowercased.contains("run") || lowercased.contains("cardio") { return "figure.run" }
        if lowercased.contains("cross") || lowercased.contains("hiit") { return "figure.strengthtraining.functional" }
        if lowercased.contains("box") || lowercased.contains("fight") { return "figure.boxing" }
        if lowercased.contains("cycle") || lowercased.contains("spin") { return "figure.outdoor.cycle" }
        if lowercased.contains("dance") || lowercased.contains("zumba") { return "figure.dance" }
        if lowercased.contains("swim") { return "figure.pool.swim" }
        return "figure.highintensity.intervaltraining"
    }
}

/// Drawer expandido con detalles de la sesión
struct SessionDetailsDrawer: View {
    let session: AttendedClass
    let onClose: () -> Void
    let onViewDetails: () -> Void
    @EnvironmentObject var themeManager: ThemeManager
    @State private var appearAnimation = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header con información principal
            HStack(alignment: .top) {
                // Icono grande
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color(hex: "#D93333") ?? .red,
                                    Color(hex: "#FF6B6B") ?? Color.red.opacity(0.8)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 40, height: 40)

                    Image(systemName: iconForClass(session.className))
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundColor(.white)
                }
                .scaleEffect(appearAnimation ? 1.0 : 0.8)
                .opacity(appearAnimation ? 1.0 : 0)

                VStack(alignment: .leading, spacing: 4) {
                    Text(session.className)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(Color.dynamicText(theme: themeManager.currentTheme))

                    HStack(spacing: 4) {
                        Image(systemName: "person.fill")
                            .font(.system(size: 10))
                        Text(session.instructor)
                            .font(.system(size: 13))
                    }
                    .foregroundColor(Color.dynamicTextSecondary(theme: themeManager.currentTheme))
                }

                Spacer()

                // Botón cerrar
                Button(action: onClose) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 20))
                        .foregroundColor(.gray.opacity(0.6))
                }
            }
            .padding(.horizontal, 12)
            .padding(.top, 12)

            // Métricas en línea
            HStack(spacing: 16) {
                MetricPill(
                    icon: "clock",
                    value: session.timeRange,
                    color: .blue
                )

                MetricPill(
                    icon: "timer",
                    value: session.attendanceDuration,
                    color: .orange
                )

                if session.isRecentlyCompleted {
                    MetricPill(
                        icon: "checkmark.circle.fill",
                        value: "Completado",
                        color: .green
                    )
                }
            }
            .padding(.horizontal, 12)

            // Divider
            Rectangle()
                .fill(Color.gray.opacity(0.2))
                .frame(height: 1)
                .padding(.horizontal, 12)

            // Botones de acción
            HStack(spacing: 12) {
                Button(action: onViewDetails) {
                    HStack(spacing: 6) {
                        Image(systemName: "info.circle.fill")
                            .font(.system(size: 14))
                        Text("Ver Detalles")
                            .font(.system(size: 13, weight: .medium))
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color(hex: "#D93333") ?? .red)
                    )
                }

                Button(action: shareSession) {
                    HStack(spacing: 6) {
                        Image(systemName: "square.and.arrow.up")
                            .font(.system(size: 14))
                        Text("Compartir")
                            .font(.system(size: 13, weight: .medium))
                    }
                    .foregroundColor(Color(hex: "#D93333") ?? .red)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color(hex: "#D93333") ?? .red, lineWidth: 1)
                    )
                }
            }
            .padding(.horizontal, 12)
            .padding(.bottom, 12)
        }
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.dynamicSurface(theme: themeManager.currentTheme))
                .shadow(color: .black.opacity(0.1), radius: 5, x: 0, y: 2)
        )
        .scaleEffect(appearAnimation ? 1.0 : 0.95)
        .opacity(appearAnimation ? 1.0 : 0)
        .onAppear {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                appearAnimation = true
            }
        }
    }

    private func iconForClass(_ className: String) -> String {
        let lowercased = className.lowercased()
        if lowercased.contains("yoga") { return "figure.yoga" }
        if lowercased.contains("pilates") { return "figure.pilates" }
        if lowercased.contains("run") || lowercased.contains("cardio") { return "figure.run" }
        if lowercased.contains("cross") || lowercased.contains("hiit") { return "figure.strengthtraining.functional" }
        if lowercased.contains("box") || lowercased.contains("fight") { return "figure.boxing" }
        if lowercased.contains("cycle") || lowercased.contains("spin") { return "figure.outdoor.cycle" }
        if lowercased.contains("dance") || lowercased.contains("zumba") { return "figure.dance" }
        if lowercased.contains("swim") { return "figure.pool.swim" }
        return "figure.highintensity.intervaltraining"
    }

    private func shareSession() {
        let text = "¡Completé \(session.className) con \(session.instructor)! 💪 \(session.attendanceDuration) de entrenamiento"

        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let window = windowScene.windows.first else { return }

        let activityVC = UIActivityViewController(activityItems: [text], applicationActivities: nil)

        if let popover = activityVC.popoverPresentationController {
            popover.sourceView = window.rootViewController?.view
            popover.sourceRect = CGRect(x: window.bounds.midX, y: window.bounds.midY, width: 0, height: 0)
        }

        window.rootViewController?.present(activityVC, animated: true)
    }
}

/// Pill de métrica compacta
struct MetricPill: View {
    let icon: String
    let value: String
    let color: Color

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 10))
                .foregroundColor(color)

            Text(value)
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(.gray)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(
            Capsule()
                .fill(color.opacity(0.1))
        )
    }
}

/// Sheet completo con todos los detalles
struct SessionFullDetailsSheet: View {
    let session: AttendedClass
    @EnvironmentObject var themeManager: ThemeManager
    @Environment(\.dismiss) var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // Header visual
                    ZStack {
                        Circle()
                            .fill(
                                LinearGradient(
                                    colors: [
                                        Color(hex: "#D93333") ?? .red,
                                        Color(hex: "#FF6B6B") ?? Color.red.opacity(0.8)
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: 100, height: 100)

                        Image(systemName: iconForClass(session.className))
                            .font(.system(size: 50, weight: .semibold))
                            .foregroundColor(.white)
                    }
                    .padding(.top, 20)

                    VStack(spacing: 8) {
                        Text(session.className)
                            .font(.system(size: 28, weight: .bold))
                            .foregroundColor(Color.dynamicText(theme: themeManager.currentTheme))

                        if let badge = session.statusBadge {
                            Text(badge.text)
                                .font(.system(size: 12, weight: .semibold))
                                .padding(.horizontal, 12)
                                .padding(.vertical, 4)
                                .background(
                                    Capsule()
                                        .fill(Color(badge.color).opacity(0.15))
                                )
                                .foregroundColor(Color(badge.color))
                        }
                    }

                    // Grid de información
                    LazyVGrid(
                        columns: [
                            GridItem(.flexible()),
                            GridItem(.flexible())
                        ],
                        spacing: 16
                    ) {
                        DetailCard(
                            icon: "person.fill",
                            title: "Instructor",
                            value: session.instructor
                        )

                        DetailCard(
                            icon: "calendar",
                            title: "Fecha",
                            value: session.displayDate
                        )

                        DetailCard(
                            icon: "clock",
                            title: "Horario",
                            value: session.timeRange
                        )

                        DetailCard(
                            icon: "timer",
                            title: "Duración",
                            value: session.attendanceDuration
                        )

                        DetailCard(
                            icon: "arrow.right.circle",
                            title: "Check-in",
                            value: formatTime(session.checkinTime)
                        )

                        if let checkout = session.checkoutTime {
                            DetailCard(
                                icon: "arrow.left.circle",
                                title: "Check-out",
                                value: formatTime(checkout)
                            )
                        }
                    }
                    .padding(.horizontal, 20)

                    // Progress visual
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Progreso de la Sesión")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.gray)

                        SessionProgressBar(
                            progress: calculateProgress(),
                            color: progressColor()
                        )

                        HStack {
                            Text("\(Int(calculateProgress() * 100))% completado")
                                .font(.system(size: 12))
                                .foregroundColor(.gray)

                            Spacer()

                            Text(progressMessage())
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(progressColor())
                        }
                    }
                    .padding(.horizontal, 20)

                    Spacer(minLength: 40)
                }
            }
            .navigationTitle("Detalles de Sesión")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Cerrar") {
                        dismiss()
                    }
                    .foregroundColor(Color(hex: "#D93333") ?? .red)
                }
            }
        }
    }

    private func iconForClass(_ className: String) -> String {
        let lowercased = className.lowercased()
        if lowercased.contains("yoga") { return "figure.yoga" }
        if lowercased.contains("pilates") { return "figure.pilates" }
        if lowercased.contains("run") || lowercased.contains("cardio") { return "figure.run" }
        if lowercased.contains("cross") || lowercased.contains("hiit") { return "figure.strengthtraining.functional" }
        if lowercased.contains("box") || lowercased.contains("fight") { return "figure.boxing" }
        if lowercased.contains("cycle") || lowercased.contains("spin") { return "figure.outdoor.cycle" }
        if lowercased.contains("dance") || lowercased.contains("zumba") { return "figure.dance" }
        if lowercased.contains("swim") { return "figure.pool.swim" }
        return "figure.highintensity.intervaltraining"
    }

    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }

    private func calculateProgress() -> Double {
        guard let checkout = session.checkoutTime else { return 0.5 }
        let totalDuration = session.endTime.timeIntervalSince(session.startTime)
        let attendedDuration = checkout.timeIntervalSince(session.checkinTime)
        return min(1.0, attendedDuration / totalDuration)
    }

    private func progressColor() -> Color {
        let progress = calculateProgress()
        if progress >= 0.9 { return .green }
        if progress >= 0.6 { return .orange }
        return .red
    }

    private func progressMessage() -> String {
        let progress = calculateProgress()
        if progress >= 0.9 { return "¡Sesión completa!" }
        if progress >= 0.6 { return "Buen progreso" }
        return "Sesión parcial"
    }
}

/// Card de detalle individual
struct DetailCard: View {
    let icon: String
    let title: String
    let value: String
    @EnvironmentObject var themeManager: ThemeManager

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 20))
                .foregroundColor(Color(hex: "#D93333") ?? .red)

            Text(title)
                .font(.system(size: 11))
                .foregroundColor(.gray)

            Text(value)
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(Color.dynamicText(theme: themeManager.currentTheme))
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.dynamicSurface(theme: themeManager.currentTheme))
        )
    }
}

/// Barra de progreso visual
struct SessionProgressBar: View {
    let progress: Double
    let color: Color

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                // Fondo
                RoundedRectangle(cornerRadius: 4)
                    .fill(color.opacity(0.2))

                // Progreso
                RoundedRectangle(cornerRadius: 4)
                    .fill(color)
                    .frame(width: geometry.size.width * CGFloat(progress))
                    .animation(.spring(response: 0.5, dampingFraction: 0.8), value: progress)
            }
        }
        .frame(height: 8)
    }
}