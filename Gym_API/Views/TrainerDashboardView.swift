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

    @State private var showingAllAppointments = false
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
            StatCard(
                title: workspaceContext.getCapitalizedTerm("clients"),
                value: "\(metrics.activeClients)",
                subtitle: "of \(metrics.maxClients) max",
                icon: "person.2.fill",
                color: metrics.capacityPercentage >= 90 ? Color.orange : Color.blue,
                progress: metrics.capacityPercentage / 100,
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

            // Client Retention
            StatCard(
                title: "Retention",
                value: "\(Int(metrics.clientRetentionRate))%",
                subtitle: "client retention",
                icon: "heart.circle.fill",
                color: Color.orange,
                theme: themeManager.currentTheme
            )

            // Revenue
            StatCard(
                title: "Revenue",
                value: formatCurrency(metrics.revenueThisMonth),
                subtitle: "this month",
                icon: "dollarsign.circle.fill",
                color: Color.purple,
                theme: themeManager.currentTheme
            )
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
                QuickActionButton(
                    title: "New \(workspaceContext.getCapitalizedTerm("session"))",
                    icon: "plus.circle.fill",
                    color: Color.blue,
                    theme: themeManager.currentTheme
                ) {
                    // TODO: Navigate to new session creation
                }

                QuickActionButton(
                    title: "View \(workspaceContext.getCapitalizedTerm("clients"))",
                    icon: "person.2.fill",
                    color: Color.green,
                    theme: themeManager.currentTheme
                ) {
                    // TODO: Navigate to clients list
                }

                if workspaceContext.isFeatureEnabled(\.showAppointments) {
                    QuickActionButton(
                        title: "Schedule",
                        icon: "calendar",
                        color: Color.orange,
                        theme: themeManager.currentTheme
                    ) {
                        showingAllAppointments = true
                    }
                }

                QuickActionButton(
                    title: "Messages",
                    icon: "message.fill",
                    color: Color.purple,
                    theme: themeManager.currentTheme
                ) {
                    // TODO: Navigate to messages
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

                Button(action: {
                    showingAllAppointments = true
                }) {
                    Text("View All")
                        .font(.subheadline)
                        .foregroundColor(themeManager.currentTheme == .dark ?
                            Color(red: 0.85, green: 0.2, blue: 0.2) :
                            Color(red: 61.0/255.0, green: 190.0/255.0, blue: 208.0/255.0))
                }
            }
            .padding(.horizontal, 4)

            // Placeholder for appointments
            VStack(spacing: 12) {
                AppointmentRow(
                    time: "10:00 AM",
                    clientName: "Sample Client 1",
                    sessionType: "Personal Training",
                    theme: themeManager.currentTheme
                )

                AppointmentRow(
                    time: "2:00 PM",
                    clientName: "Sample Client 2",
                    sessionType: "Consultation",
                    theme: themeManager.currentTheme
                )

                AppointmentRow(
                    time: "4:00 PM",
                    clientName: "Sample Client 3",
                    sessionType: "Follow-up",
                    theme: themeManager.currentTheme
                )
            }
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
                    Text("Activity feed will appear here")
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

    // MARK: - Helpers

    private func formatCurrency(_ amount: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "USD"
        formatter.maximumFractionDigits = 0
        return formatter.string(from: NSNumber(value: amount)) ?? "$0"
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

// MARK: - Appointment Row Component

struct AppointmentRow: View {
    let time: String
    let clientName: String
    let sessionType: String
    let theme: ThemeManager.AppTheme

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(time)
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(.secondary)
            }
            .frame(width: 70, alignment: .leading)

            VStack(alignment: .leading, spacing: 4) {
                Text(clientName)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(Color.dynamicText(theme: theme))

                Text(sessionType)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color.dynamicSurface(theme: theme))
        )
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
