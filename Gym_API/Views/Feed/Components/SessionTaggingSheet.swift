//
//  SessionTaggingSheet.swift
//  Gym_API
//
//  Created by Claude on 2026-01-31.
//

import SwiftUI

/// Vista modal para seleccionar una sesión/clase para etiquetar en el post
struct SessionTaggingSheet: View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var attendanceService: AttendanceService
    @EnvironmentObject var themeManager: ThemeManager

    @Binding var selectedClass: AttendedClass?
    let onSelection: (AttendedClass) -> Void

    @State private var recentClasses: [AttendedClass] = []
    @State private var isLoading = false
    @State private var errorMessage: String?

    var body: some View {
        NavigationView {
            ZStack {
                Color.dynamicBackground(theme: themeManager.currentTheme)
                    .ignoresSafeArea()

                if isLoading {
                    loadingView
                } else if let error = errorMessage {
                    errorView(error)
                } else if recentClasses.isEmpty {
                    emptyStateView
                } else {
                    contentView
                }
            }
            .navigationTitle("Etiquetar Sesión")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancelar") {
                        dismiss()
                    }
                    .foregroundColor(.dynamicText(theme: themeManager.currentTheme))
                }
            }
        }
        .task {
            await loadRecentClasses()
        }
    }

    // MARK: - Subviews

    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
                .progressViewStyle(CircularProgressViewStyle(tint: .dynamicAccent(theme: themeManager.currentTheme)))
                .scaleEffect(1.2)

            Text("Cargando tus clases recientes...")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
    }

    private func errorView(_ error: String) -> some View {
        VStack(spacing: 24) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 56))
                .foregroundColor(.red)

            VStack(spacing: 8) {
                Text("Error al cargar clases")
                    .font(.headline)
                    .foregroundColor(.dynamicText(theme: themeManager.currentTheme))

                Text(error)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }

            Button {
                Task {
                    await loadRecentClasses()
                }
            } label: {
                Label("Reintentar", systemImage: "arrow.clockwise")
                    .font(.subheadline.bold())
                    .foregroundColor(.white)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 12)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color.dynamicAccent(theme: themeManager.currentTheme))
                    )
            }
        }
        .padding()
    }

    private var emptyStateView: some View {
        VStack(spacing: 24) {
            Image(systemName: "calendar.badge.exclamationmark")
                .font(.system(size: 72))
                .foregroundColor(.gray.opacity(0.5))

            VStack(spacing: 8) {
                Text("No hay clases recientes")
                    .font(.title3.bold())
                    .foregroundColor(.dynamicText(theme: themeManager.currentTheme))

                Text("No has asistido a ninguna clase en los últimos 7 días")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }

            Text("¡Asiste a una clase y comparte tu experiencia!")
                .font(.caption)
                .foregroundColor(.secondary)
                .italic()
        }
        .padding()
    }

    private var contentView: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                // Header informativo
                HStack {
                    Image(systemName: "info.circle")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    Text("Selecciona la clase que quieres etiquetar en tu post")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding(.horizontal)
                .padding(.top, 8)

                // Lista de clases
                LazyVStack(spacing: 12) {
                    ForEach(recentClasses) { attendedClass in
                        SessionCard(
                            attendedClass: attendedClass,
                            isSelected: selectedClass?.id == attendedClass.id
                        )
                        .onTapGesture {
                            selectClass(attendedClass)
                        }
                    }
                }
                .padding(.horizontal)
                .padding(.bottom, 20)
            }
        }
    }

    // MARK: - Actions

    private func loadRecentClasses() async {
        isLoading = true
        errorMessage = nil

        do {
            recentClasses = try await attendanceService.getRecentAttendedClasses()
            Logger.shared.info("Loaded \(recentClasses.count) recent classes", category: .network)
        } catch {
            Logger.shared.error("Failed to load recent classes: \(error)", category: .network)
            errorMessage = "No se pudieron cargar las clases. Intenta de nuevo."
        }

        isLoading = false
    }

    private func selectClass(_ attendedClass: AttendedClass) {
        // Haptic feedback
        let generator = UISelectionFeedbackGenerator()
        generator.selectionChanged()

        selectedClass = attendedClass
        onSelection(attendedClass)

        // Pequeña demora para que el usuario vea la selección
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            dismiss()
        }
    }
}

// MARK: - SessionCard Component

struct SessionCard: View {
    let attendedClass: AttendedClass
    let isSelected: Bool
    @EnvironmentObject var themeManager: ThemeManager

    var body: some View {
        HStack(spacing: 12) {
            // Ícono de la clase
            ZStack {
                Circle()
                    .fill(
                        isSelected
                        ? Color.dynamicAccent(theme: themeManager.currentTheme)
                        : Color.dynamicAccent(theme: themeManager.currentTheme).opacity(0.15)
                    )
                    .frame(width: 56, height: 56)

                Image(systemName: iconForClass)
                    .font(.system(size: 24, weight: .semibold))
                    .foregroundColor(
                        isSelected
                        ? .white
                        : Color.dynamicAccent(theme: themeManager.currentTheme)
                    )
            }

            // Información de la clase
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text(attendedClass.className)
                        .font(.subheadline.bold())
                        .foregroundColor(.dynamicText(theme: themeManager.currentTheme))
                        .lineLimit(1)

                    if let badge = attendedClass.statusBadge {
                        Text(badge.text)
                            .font(.caption2.bold())
                            .foregroundColor(.white)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(
                                Capsule()
                                    .fill(colorForBadge(badge.color))
                            )
                    }
                }

                HStack(spacing: 12) {
                    // Instructor
                    HStack(spacing: 4) {
                        Image(systemName: "person.fill")
                            .font(.caption2)
                        Text(attendedClass.instructor)
                            .font(.caption)
                    }
                    .foregroundColor(.secondary)

                    // Fecha y hora
                    HStack(spacing: 4) {
                        Image(systemName: "calendar")
                            .font(.caption2)
                        Text("\(attendedClass.displayDate), \(attendedClass.timeRange)")
                            .font(.caption)
                    }
                    .foregroundColor(.secondary)
                }

                // Duración de asistencia
                HStack(spacing: 4) {
                    Image(systemName: "timer")
                        .font(.caption2)
                    Text("Asististe \(attendedClass.attendanceDuration)")
                        .font(.caption)
                }
                .foregroundColor(.secondary)
            }

            Spacer()

            // Indicador de selección
            if isSelected {
                Image(systemName: "checkmark.circle.fill")
                    .font(.title2)
                    .foregroundColor(.dynamicAccent(theme: themeManager.currentTheme))
            } else {
                Circle()
                    .stroke(Color.gray.opacity(0.3), lineWidth: 2)
                    .frame(width: 24, height: 24)
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.dynamicCard(theme: themeManager.currentTheme))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(
                            isSelected
                            ? Color.dynamicAccent(theme: themeManager.currentTheme)
                            : Color.clear,
                            lineWidth: 2
                        )
                )
                .shadow(
                    color: Color.black.opacity(
                        themeManager.currentTheme == .dark ? 0.2 : 0.05
                    ),
                    radius: isSelected ? 8 : 4,
                    x: 0,
                    y: 2
                )
        )
        .scaleEffect(isSelected ? 1.02 : 1.0)
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isSelected)
    }

    private var iconForClass: String {
        let className = attendedClass.className.lowercased()

        if className.contains("yoga") {
            return "figure.yoga"
        } else if className.contains("crossfit") || className.contains("cross") {
            return "figure.strengthtraining.traditional"
        } else if className.contains("hiit") || className.contains("cardio") {
            return "figure.highintensity.intervaltraining"
        } else if className.contains("spin") || className.contains("cycling") {
            return "figure.outdoor.cycle"
        } else if className.contains("box") {
            return "figure.boxing"
        } else if className.contains("pilates") {
            return "figure.pilates"
        } else if className.contains("dance") || className.contains("zumba") {
            return "figure.dance"
        } else if className.contains("swim") || className.contains("aqua") {
            return "figure.pool.swim"
        } else {
            return "figure.run"
        }
    }

    private func colorForBadge(_ colorString: String) -> Color {
        switch colorString {
        case "green":
            return .green
        case "blue":
            return .blue
        case "orange":
            return .orange
        default:
            return .gray
        }
    }
}

// MARK: - Preview

#if DEBUG
struct SessionTaggingSheet_Previews: PreviewProvider {
    static var previews: some View {
        SessionTaggingSheet(
            selectedClass: .constant(nil),
            onSelection: { _ in }
        )
        .environmentObject(ServiceContainer.shared.attendanceService)
        .environmentObject(ThemeManager())
    }
}
#endif