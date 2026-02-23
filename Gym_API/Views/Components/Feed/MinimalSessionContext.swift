//
//  MinimalSessionContext.swift
//  Gym_API
//
//  Componente minimalista para mostrar contexto de sesión
//  Diseño: 2 líneas de información esencial sin elementos decorativos
//

import SwiftUI

/// Contexto minimalista de sesión - Solo información esencial
struct MinimalSessionContext: View {
    let session: AttendedClass
    @EnvironmentObject var themeManager: ThemeManager

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            // Línea 1: Tipo de ejercicio • Enfoque
            Text(firstLine)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(Color.dynamicText(theme: themeManager.currentTheme))

            // Línea 2: Contexto temporal • Duración
            Text(secondLine)
                .font(.system(size: 13, weight: .regular))
                .foregroundColor(Color.dynamicTextSecondary(theme: themeManager.currentTheme))
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    // MARK: - Computed Properties

    private var firstLine: String {
        // Determinar tipo de ejercicio basado en el nombre de la clase
        let exerciseType = getExerciseType(from: session.className)
        let focus = getExerciseFocus(from: session.className)

        if !focus.isEmpty {
            return "\(exerciseType) • \(focus)"
        } else {
            return exerciseType
        }
    }

    private var secondLine: String {
        let timeContext = getRelativeTime(from: session.startTime)
        let duration = formatDuration()
        return "\(timeContext) • \(duration)"
    }

    // MARK: - Helper Methods

    private func getExerciseType(from className: String) -> String {
        let lowercased = className.lowercased()

        if lowercased.contains("yoga") {
            return "Yoga"
        } else if lowercased.contains("hiit") || lowercased.contains("cardio") {
            return "Cardio Training"
        } else if lowercased.contains("strength") || lowercased.contains("weight") {
            return "Strength Training"
        } else if lowercased.contains("crossfit") {
            return "CrossFit"
        } else if lowercased.contains("spin") || lowercased.contains("cycling") {
            return "Cycling"
        } else if lowercased.contains("pilates") {
            return "Pilates"
        } else if lowercased.contains("box") {
            return "Boxing"
        } else if lowercased.contains("run") {
            return "Running"
        } else {
            return className
        }
    }

    private func getExerciseFocus(from className: String) -> String {
        let lowercased = className.lowercased()

        if lowercased.contains("upper") {
            return "Upper Body"
        } else if lowercased.contains("lower") || lowercased.contains("leg") {
            return "Lower Body"
        } else if lowercased.contains("core") || lowercased.contains("abs") {
            return "Core"
        } else if lowercased.contains("full") || lowercased.contains("hiit") || lowercased.contains("crossfit") {
            return "Full Body"
        } else if lowercased.contains("beginner") {
            return "Beginner"
        } else if lowercased.contains("advanced") {
            return "Advanced"
        } else if lowercased.contains("power") {
            return "Power"
        } else if lowercased.contains("flow") {
            return "Flow"
        } else {
            return ""
        }
    }

    private func getRelativeTime(from date: Date) -> String {
        let calendar = Calendar.current
        let now = Date()
        let timeFormatter = DateFormatter()
        timeFormatter.timeStyle = .short

        if calendar.isDateInToday(date) {
            return "Today at \(timeFormatter.string(from: date))"
        } else if calendar.isDateInYesterday(date) {
            return "Yesterday at \(timeFormatter.string(from: date))"
        } else if let daysAgo = calendar.dateComponents([.day], from: date, to: now).day,
                  daysAgo < 7 {
            let dayFormatter = DateFormatter()
            dayFormatter.dateFormat = "EEEE" // Monday, Tuesday, etc.
            return "\(dayFormatter.string(from: date)) at \(timeFormatter.string(from: date))"
        } else {
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "MMM d 'at' h:mm a"
            return dateFormatter.string(from: date)
        }
    }

    private func formatDuration() -> String {
        let duration = session.endTime.timeIntervalSince(session.startTime)
        let minutes = Int(duration / 60)

        if minutes < 60 {
            return "\(minutes) min"
        } else {
            let hours = minutes / 60
            let remainingMinutes = minutes % 60
            if remainingMinutes > 0 {
                return "\(hours)h \(remainingMinutes)min"
            } else {
                return "\(hours) hour\(hours > 1 ? "s" : "")"
            }
        }
    }
}

/// Container simple para el contexto de sesión
struct SessionContextContainer: View {
    let sessionTag: PostTag
    @State private var session: AttendedClass?
    @State private var isLoading = true
    @EnvironmentObject var themeManager: ThemeManager

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if isLoading {
                // Placeholder mientras carga - siempre visible para que .task se ejecute
                HStack(spacing: 6) {
                    ProgressView()
                        .scaleEffect(0.7)
                    Text("Loading session...")
                        .font(.system(size: 12))
                        .foregroundColor(.gray)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
            } else if let session = session {
                let _ = print("✅ SessionContextContainer: Displaying session context for ID: \(sessionTag.tagId)")
                MinimalSessionContext(session: session)
                    .environmentObject(themeManager)
            }
        }
        .onAppear {
            print("🎬 SessionContextContainer: onAppear for tag ID: \(sessionTag.tagId)")
            loadSessionSync()
        }
    }

    private func loadSessionSync() {
        print("🔄 SessionContextContainer: Starting load for tag ID: \(sessionTag.tagId)")

        Task { @MainActor in
            print("🔍 SessionContextContainer: Fetching session ID: \(sessionTag.tagId)")

            let cacheService = SessionCacheService.shared
            if let realSession = await cacheService.getSession(id: sessionTag.tagId) {
                print("✅ SessionContextContainer: Loaded session: \(realSession.className)")
                self.session = realSession
            } else {
                print("⚠️ SessionContextContainer: Using fallback for ID: \(sessionTag.tagId)")
                self.session = createMinimalFallback()
            }

            self.isLoading = false
        }
    }

    private func createMinimalFallback() -> AttendedClass {
        let now = Date()
        let startTime = now.addingTimeInterval(-3600)
        let endTime = now.addingTimeInterval(-1800)

        return AttendedClass(
            id: sessionTag.tagId,
            classId: 100 + sessionTag.tagId,
            className: "Training Session",
            instructor: "",
            startTime: startTime,
            endTime: endTime,
            checkinTime: startTime,
            checkoutTime: endTime
        )
    }
}