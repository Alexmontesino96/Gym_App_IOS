//
//  TrainerDashboardView.swift
//  Gym_API
//
//  Created by Claude Code on 2025-01-25
//

import SwiftUI

struct TrainerDashboardView: View {
    @EnvironmentObject var workspaceContext: WorkspaceContextService
    @EnvironmentObject var authService: AuthServiceDirect
    @EnvironmentObject var themeManager: ThemeManager

    /// Navegación de pestañas, que la posee TrainerMainTabView.
    var onGoToClients: () -> Void = {}
    var onGoToMessages: () -> Void = {}

    @State private var isRefreshing = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // Welcome Header
                    welcomeHeader

                    // Stats Cards
                    if let stats = workspaceContext.stats,
                       case .trainer(let trainerMetrics) = stats.metrics {
                        statsGrid(metrics: trainerMetrics)
                    } else {
                        loadingStatsView
                    }

                    // Quick Actions
                    quickActionsSection

                    // Today's Schedule
                    todayScheduleSection

                    // Recent Activity
                    recentActivitySection
                }
                .padding()
            }
            .background(Color.dynamicSurface(theme: themeManager.currentTheme))
            .navigationTitle("Dashboard")
            .navigationBarTitleDisplayMode(.large)
            .refreshable {
                await refreshData()
            }
            .task {
                await loadInitialData()
            }
        }
    }

    // MARK: - Welcome Header

    private var welcomeHeader: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("Welcome back,")
                    .font(.subheadline)
                    .foregroundColor(.secondary)

                Text(authService.user?.name ?? "Trainer")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(Color.dynamicText(theme: themeManager.currentTheme))
            }

            Spacer()

            // Profile Image or Icon
            Circle()
                .fill(LinearGradient(
                    colors: [
                        themeManager.currentTheme == .dark ?
                            Color(red: 0.85, green: 0.2, blue: 0.2) :
                            Color(red: 61.0/255.0, green: 190.0/255.0, blue: 208.0/255.0),
                        themeManager.currentTheme == .dark ?
                            Color(red: 0.7, green: 0.15, blue: 0.15) :
                            Color(red: 41.0/255.0, green: 170.0/255.0, blue: 188.0/255.0)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ))
                .frame(width: 50, height: 50)
                .overlay(
                    Image(systemName: "person.fill")
                        .foregroundColor(.white)
                )
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.dynamicSurface(theme: themeManager.currentTheme))
                .shadow(color: Color.black.opacity(0.1), radius: 8, x: 0, y: 4)
        )
    }

    // MARK: - Stats Grid

    private func statsGrid(metrics: TrainerMetrics) -> some View {
        LazyVGrid(columns: [
            GridItem(.flexible()),
            GridItem(.flexible())
        ], spacing: 16) {
            // Active Clients
            // Sin plan contratado no hay tope, así que no se pinta ni «of N max» ni barra de
            // progreso: una barra sobre un límite inexistente es un dato inventado.
            StatCard(
                title: workspaceContext.getCapitalizedTerm("clients"),
                value: "\(metrics.activeClients)",
                subtitle: metrics.maxClients.map { "of \($0) max" } ?? "active",
                icon: "person.2.fill",
                color: metrics.maxClients != nil && metrics.capacityPercentage >= 90
                    ? Color.orange
                    : Color.blue,
                progress: metrics.maxClients != nil ? metrics.capacityPercentage / 100 : nil,
                theme: themeManager.currentTheme
            )

            // Sessions This Week
            StatCard(
                title: "Sessions",
                value: "\(metrics.sessionsThisWeek)",
                subtitle: "this week",
                icon: "figure.walk",
                color: Color.green,
                theme: themeManager.currentTheme
            )

            // Retención e ingresos: RETIRADOS a propósito.
            // El backend los devolvía escritos a fuego (95 % y 45.000) con un TODO, y aquí se
            // pintaban como si fueran del entrenador. Volverán cuando se calculen de verdad.
            // Mientras tanto se muestra la ocupación, que sí sale de datos reales, y SOLO cuando
            // hay un tope contra el que medirla.
            if metrics.maxClients != nil {
                StatCard(
                    title: "Capacity",
                    value: "\(Int(metrics.capacityPercentage.rounded()))%",
                    subtitle: "of your client slots",
                    icon: "gauge.medium",
                    color: metrics.capacityPercentage >= 90 ? Color.warningYellow : Color.successGreen,
                    progress: min(metrics.capacityPercentage / 100, 1),
                    theme: themeManager.currentTheme
                )
            }
        }
    }

    // MARK: - Loading Stats View

    private var loadingStatsView: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.5)

            Text("Loading your stats...")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(40)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.dynamicSurface(theme: themeManager.currentTheme))
        )
    }

    // MARK: - Quick Actions Section

    private var quickActionsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Quick Actions")
                .font(.headline)
                .foregroundColor(Color.dynamicText(theme: themeManager.currentTheme))
                .padding(.horizontal, 4)

            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 12) {
                // Antes había cuatro botones y tres no llevaban a ninguna parte: dos con el
                // cuerpo vacío y un TODO, y el de agenda a una pantalla sin backend. Un botón
                // inerte en la pantalla de aterrizaje del producto es peor que no tenerlo.
                // Se conservan solo los que navegan de verdad.
                QuickActionButton(
                    title: "View \(workspaceContext.getCapitalizedTerm("clients"))",
                    icon: "person.2.fill",
                    color: Color.green,
                    theme: themeManager.currentTheme
                ) {
                    onGoToClients()
                }

                QuickActionButton(
                    title: "Messages",
                    icon: "message.fill",
                    color: Color.purple,
                    theme: themeManager.currentTheme
                ) {
                    onGoToMessages()
                }
            }
        }
    }

    // MARK: - Today Schedule Section

    private var todayScheduleSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Today's Schedule")
                    .font(.headline)
                    .foregroundColor(Color.dynamicText(theme: themeManager.currentTheme))

                Spacer()
                // "Ver todo" llevaba a AppointmentsView, que también está sobre datos de
                // ejemplo. Se oculta hasta que exista el módulo de sesiones.
            }
            .padding(.horizontal, 4)

            // Sin datos de ejemplo: el módulo de sesiones 1:1 no existe todavía, así que aquí
            // se declara el estado real en vez de enseñar tres clientes inventados, que es lo
            // que había antes y llegaría al entrenador tal cual en el producto publicado.
            HStack(spacing: 10) {
                Image(systemName: "calendar")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(Color.dynamicTextTertiary(theme: themeManager.currentTheme))
                Text("You cannot schedule sessions from the app yet.")
                    .font(.system(size: 14))
                    .foregroundColor(Color.dynamicTextSecondary(theme: themeManager.currentTheme))
                    .fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 0)
            }
            .padding(14)
            .background(Color.dynamicSurface(theme: themeManager.currentTheme))
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(
                        Color.dynamicBorder(theme: themeManager.currentTheme).opacity(0.15),
                        style: StrokeStyle(lineWidth: 1, dash: [4, 4])
                    )
            )
        }
    }

    // MARK: - Recent Activity Section

    private var recentActivitySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Recent Activity")
                .font(.headline)
                .foregroundColor(Color.dynamicText(theme: themeManager.currentTheme))
                .padding(.horizontal, 4)

            // TODO: Connect to actual activity data from API
            VStack(spacing: 8) {
                HStack {
                    Image(systemName: "clock.fill")
                        .foregroundColor(.secondary)
                    Text("Your clients' activity will show up here.")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    Spacer()
                }
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .fill(Color.dynamicSurface(theme: themeManager.currentTheme))
                )
            }
        }
    }

    // MARK: - Data Loading

    private func loadInitialData() async {
        if workspaceContext.stats == nil {
            await workspaceContext.fetchStats()
        }
    }

    private func refreshData() async {
        isRefreshing = true
        await workspaceContext.fetchStats(forceRefresh: true)
        isRefreshing = false
    }

}

// MARK: - Stat Card Component

struct StatCard: View {
    let title: String
    let value: String
    let subtitle: String
    let icon: String
    let color: Color
    var progress: Double?
    let theme: ThemeManager.AppTheme

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: icon)
                    .foregroundColor(color)
                    .font(.title3)

                Spacer()
            }

            Text(value)
                .font(.title)
                .fontWeight(.bold)
                .foregroundColor(Color.dynamicText(theme: theme))

            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)

            Text(subtitle)
                .font(.caption2)
                .foregroundColor(.secondary)

            if let progress = progress {
                ProgressView(value: progress)
                    .tint(color)
                    .padding(.top, 4)
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.dynamicSurface(theme: theme))
                .shadow(color: Color.black.opacity(0.05), radius: 4, x: 0, y: 2)
        )
    }
}

// MARK: - Quick Action Button Component

struct QuickActionButton: View {
    let title: String
    let icon: String
    let color: Color
    let theme: ThemeManager.AppTheme
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundColor(color)

                Text(title)
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(Color.dynamicText(theme: theme))
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.dynamicSurface(theme: theme))
                    .shadow(color: Color.black.opacity(0.05), radius: 4, x: 0, y: 2)
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}


// MARK: - Note: ActivityRow component already exists in RecentActivitySection.swift
// Using placeholder for Recent Activity section until connected to actual data

// MARK: - Preview

#Preview {
    TrainerDashboardView()
        .environmentObject(WorkspaceContextService.shared)
        .environmentObject(AuthServiceDirect())
        .environmentObject(ThemeManager())
}
