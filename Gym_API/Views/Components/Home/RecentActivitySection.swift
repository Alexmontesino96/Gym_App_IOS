import SwiftUI

// MARK: - Recent Activity Section
struct HomeRecentActivitySection: View {
    let themeManager: ThemeManager
    let classService: ClassService
    let eventService: EventService
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @State private var hasLoadedOnce = false

    private var recentActivities: [ActivityItem] {
        var activities: [ActivityItem] = []
        
        // Add completed classes from last 7 days
        let now = Date()
        let sevenDaysAgo = Calendar.current.date(byAdding: .day, value: -7, to: now) ?? now
        
        let completedClasses = classService.classes.filter { gymClass in
            let wasRegistered = classService.userRegistrationStatus[gymClass.id] ?? false
            let isCompleted = gymClass.endTime < now
            let isRecent = gymClass.endTime > sevenDaysAgo
            return wasRegistered && isCompleted && isRecent
        }
        
        for gymClass in completedClasses {
            activities.append(ActivityItem(
                id: "class-\(gymClass.id)",
                type: .completedClass,
                title: gymClass.name,
                subtitle: "Clase completada",
                timestamp: gymClass.endTime,
                icon: "checkmark.circle.fill",
                color: .green
            ))
        }
        
        // Add completed events from last 7 days
        let completedEvents = eventService.events.filter { event in
            let isCompleted = event.endTime < now
            let isRecent = event.endTime > sevenDaysAgo
            return isCompleted && isRecent
        }
        
        for event in completedEvents {
            activities.append(ActivityItem(
                id: "event-\(event.id)",
                type: .completedEvent,
                title: event.title,
                subtitle: "Evento finalizado",
                timestamp: event.endTime,
                icon: "calendar.badge.checkmark",
                color: .blue
            ))
        }
        
        // Sort by timestamp (most recent first) and limit to 4
        return activities.sorted { $0.timestamp > $1.timestamp }.prefix(4).map { $0 }
    }
    
    var body: some View {
        // Mostrar skeleton solo si NO ha cargado nunca Y los servicios están cargando
        let isInitialLoading = !hasLoadedOnce && (classService.isLoading || eventService.isLoading)

        if isInitialLoading {
            return AnyView(ActivityListSkeleton(themeManager: themeManager)
                .onAppear {
                    // Dar un timeout para evitar skeleton infinito
                    DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                        hasLoadedOnce = true
                    }
                })
        }

        // Marcar como cargado si los servicios no están cargando
        if !classService.isLoading && !eventService.isLoading && !hasLoadedOnce {
            DispatchQueue.main.async {
                hasLoadedOnce = true
            }
        }

        // Si ya terminó de cargar y hay actividades, mostrarlas
        if !recentActivities.isEmpty {
            return AnyView(
                VStack(spacing: 16) {
                    // Header unificado
                    SectionHeaderView(
                        title: "Actividad Reciente",
                        ctaTitle: nil,
                        themeManager: themeManager
                    )
                    .padding(.horizontal, 0)

                    // Activities list
                    ZStack {
                        RoundedRectangle(cornerRadius: 16)
                            .fill(Color.dynamicSurface(theme: themeManager.currentTheme))
                            .overlay(
                                RoundedRectangle(cornerRadius: 16)
                                    .stroke(Color.dynamicBorder(theme: themeManager.currentTheme), lineWidth: 1)
                            )

                        VStack(spacing: 0) {
                            ForEach(Array(recentActivities.enumerated()), id: \.element.id) { index, activity in
                                activityRowView(for: activity)

                                // Divider between items (except last)
                                if index < recentActivities.count - 1 {
                                    Rectangle()
                                        .fill(Color.dynamicTextSecondary(theme: themeManager.currentTheme).opacity(0.2))
                                        .frame(height: 1)
                                        .padding(.horizontal, 16)
                                }
                            }
                        }
                        .padding(16)
                    }
                    .padding(.horizontal, 0)
                }
            )
        }

        // Si no hay actividades, no mostrar nada (EmptyView)
        return AnyView(EmptyView())
    }

    // MARK: - Activity Row View

    private func activityRowView(for activity: ActivityItem) -> some View {
        HStack(spacing: 12) {
            // Activity icon
            ZStack {
                Circle()
                    .fill(activity.color.opacity(0.15))
                    .frame(width: 40, height: 40)

                Image(systemName: activity.icon)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(activity.color)
            }

            // Activity info
            VStack(alignment: .leading, spacing: 4) {
                Text(activity.title)
                    .font(.cappedDynamicSystem(size: 15, weight: .semibold, maxSize: 19))
                    .foregroundColor(Color.dynamicText(theme: themeManager.currentTheme))
                    .lineLimit(1)

                Text(activity.subtitle)
                    .font(.cappedDynamicSystem(size: 13, weight: .medium, maxSize: 17))
                    .foregroundColor(Color.dynamicTextSecondary(theme: themeManager.currentTheme))
                    .lineLimit(1)
            }

            Spacer()

            // Timestamp
            Text(relativeTimeString(for: activity.timestamp))
                .font(.cappedDynamicSystem(size: 11, weight: .medium, maxSize: 14))
                .foregroundColor(Color.dynamicTextSecondary(theme: themeManager.currentTheme))
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 16)
    }

    private func relativeTimeString(for date: Date) -> String {
        let now = Date()
        let timeInterval = now.timeIntervalSince(date)
        let days = Int(timeInterval / 86400)
        let hours = Int(timeInterval / 3600)
        let minutes = Int(timeInterval / 60)

        if days > 0 {
            return "Hace \(days) día\(days > 1 ? "s" : "")"
        } else if hours > 0 {
            return "Hace \(hours) hora\(hours > 1 ? "s" : "")"
        } else if minutes > 0 {
            return "Hace \(minutes) min"
        } else {
            return "Ahora mismo"
        }
    }
}

// MARK: - Activity Item Model
struct ActivityItem: Identifiable {
    let id: String
    let type: ActivityType
    let title: String
    let subtitle: String
    let timestamp: Date
    let icon: String
    let color: Color

    enum ActivityType {
        case completedClass
        case completedEvent
        case achievement
        case milestone
    }
}

#Preview {
    HomeRecentActivitySection(
        themeManager: ThemeManager(),
        classService: ClassService(),
        eventService: EventService()
    )
    .padding()
    .background(Color.dynamicBackground(theme: .dark))
}

// MARK: - Activity List Skeleton
struct ActivityListSkeleton: View {
    let themeManager: ThemeManager
    
    var body: some View {
        VStack(spacing: 16) {
            SectionHeaderView(title: "Actividad Reciente", themeManager: themeManager)
            ZStack {
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color.dynamicSurface(theme: themeManager.currentTheme))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(Color.dynamicBorder(theme: themeManager.currentTheme), lineWidth: 1)
                    )
                VStack(spacing: 12) {
                    ForEach(0..<4, id: \.self) { index in
                        HStack(spacing: 12) {
                            SkeletonView(width: 40, height: 40, cornerRadius: 20)
                            VStack(alignment: .leading, spacing: 8) {
                                SkeletonView(width: 160, height: 16, cornerRadius: 4)
                                SkeletonView(width: 120, height: 14, cornerRadius: 4)
                            }
                            Spacer()
                            VStack(alignment: .trailing, spacing: 6) {
                                SkeletonView(width: 60, height: 12, cornerRadius: 3)
                                SkeletonView(width: 50, height: 10, cornerRadius: 3)
                            }
                        }
                        .padding(.vertical, 6)
                        if index < 3 {
                            Rectangle()
                                .fill(Color.dynamicTextSecondary(theme: themeManager.currentTheme).opacity(0.2))
                                .frame(height: 1)
                                .padding(.horizontal, 16)
                        }
                    }
                }
                .padding(16)
            }
        }
    }
}
