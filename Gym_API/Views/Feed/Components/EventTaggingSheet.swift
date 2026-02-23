//
//  EventTaggingSheet.swift
//  Gym_API
//
//  Vista modal para seleccionar un evento para etiquetar en el post
//

import SwiftUI

/// Vista modal para seleccionar un evento para etiquetar en el post
struct EventTaggingSheet: View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var eventService: EventService
    @EnvironmentObject var themeManager: ThemeManager

    @Binding var selectedEvent: Event?
    let onSelection: (Event) -> Void

    @State private var events: [Event] = []
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var searchText = ""

    var body: some View {
        NavigationView {
            ZStack {
                Color.dynamicBackground(theme: themeManager.currentTheme)
                    .ignoresSafeArea()

                if isLoading {
                    loadingView
                } else if let error = errorMessage {
                    errorView(error)
                } else if filteredEvents.isEmpty {
                    emptyStateView
                } else {
                    contentView
                }
            }
            .navigationTitle("Etiquetar Evento")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancelar") {
                        dismiss()
                    }
                    .foregroundColor(.dynamicText(theme: themeManager.currentTheme))
                }
            }
            .searchable(text: $searchText, prompt: "Buscar evento...")
        }
        .task {
            await loadEvents()
        }
    }

    // MARK: - Filtered Events

    private var filteredEvents: [Event] {
        if searchText.isEmpty {
            return events
        }
        return events.filter { event in
            event.title.localizedCaseInsensitiveContains(searchText) ||
            event.location.localizedCaseInsensitiveContains(searchText)
        }
    }

    // MARK: - Subviews

    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
                .progressViewStyle(CircularProgressViewStyle(tint: .dynamicAccent(theme: themeManager.currentTheme)))
                .scaleEffect(1.2)

            Text("Cargando eventos...")
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
                Text("Error al cargar eventos")
                    .font(.headline)
                    .foregroundColor(.dynamicText(theme: themeManager.currentTheme))

                Text(error)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }

            Button {
                Task {
                    await loadEvents()
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
                Text(searchText.isEmpty ? "No hay eventos disponibles" : "Sin resultados")
                    .font(.title3.bold())
                    .foregroundColor(.dynamicText(theme: themeManager.currentTheme))

                Text(searchText.isEmpty
                     ? "No hay eventos programados actualmente"
                     : "No se encontraron eventos con '\(searchText)'")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
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

                    Text("Selecciona el evento que quieres etiquetar en tu post")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding(.horizontal)
                .padding(.top, 8)

                // Lista de eventos
                LazyVStack(spacing: 12) {
                    ForEach(filteredEvents) { event in
                        EventTagCard(
                            event: event,
                            isSelected: selectedEvent?.id == event.id
                        )
                        .onTapGesture {
                            selectEvent(event)
                        }
                    }
                }
                .padding(.horizontal)
                .padding(.bottom, 20)
            }
        }
    }

    // MARK: - Actions

    private func loadEvents() async {
        isLoading = true
        errorMessage = nil

        // Fetch upcoming and recent events
        await eventService.fetchEvents(
            skip: 0,
            limit: 50,
            status: nil,  // All statuses
            onlyAvailable: false
        )

        // Filter to show upcoming and recently completed events
        let now = Date()
        let weekAgo = Calendar.current.date(byAdding: .day, value: -7, to: now) ?? now

        events = eventService.events.filter { event in
            // Show events from last 7 days or upcoming
            event.startTime > weekAgo || event.status == .active || event.status == .scheduled
        }.sorted { $0.startTime > $1.startTime }  // Most recent first

        if eventService.errorMessage != nil {
            errorMessage = "No se pudieron cargar los eventos. Intenta de nuevo."
        }

        isLoading = false
    }

    private func selectEvent(_ event: Event) {
        // Haptic feedback
        let generator = UISelectionFeedbackGenerator()
        generator.selectionChanged()

        selectedEvent = event
        onSelection(event)

        // Pequeña demora para que el usuario vea la selección
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            dismiss()
        }
    }
}

// MARK: - EventTagCard Component

struct EventTagCard: View {
    let event: Event
    let isSelected: Bool
    @EnvironmentObject var themeManager: ThemeManager

    var body: some View {
        HStack(spacing: 12) {
            // Ícono del evento
            ZStack {
                Circle()
                    .fill(
                        isSelected
                        ? Color.dynamicAccent(theme: themeManager.currentTheme)
                        : Color.dynamicAccent(theme: themeManager.currentTheme).opacity(0.15)
                    )
                    .frame(width: 56, height: 56)

                Image(systemName: iconForEvent)
                    .font(.system(size: 24, weight: .semibold))
                    .foregroundColor(
                        isSelected
                        ? .white
                        : Color.dynamicAccent(theme: themeManager.currentTheme)
                    )
            }

            // Información del evento
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text(event.title)
                        .font(.subheadline.bold())
                        .foregroundColor(.dynamicText(theme: themeManager.currentTheme))
                        .lineLimit(1)

                    statusBadge
                }

                HStack(spacing: 12) {
                    // Fecha y hora
                    HStack(spacing: 4) {
                        Image(systemName: "calendar")
                            .font(.caption2)
                        Text(event.dayTimeString)
                            .font(.caption)
                    }
                    .foregroundColor(.secondary)

                    // Ubicación
                    HStack(spacing: 4) {
                        Image(systemName: "mappin")
                            .font(.caption2)
                        Text(event.location)
                            .font(.caption)
                            .lineLimit(1)
                    }
                    .foregroundColor(.secondary)
                }

                // Participantes
                HStack(spacing: 4) {
                    Image(systemName: "person.2.fill")
                        .font(.caption2)
                    Text("\(event.participantsCount)/\(event.maxParticipants) participantes")
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

    @ViewBuilder
    private var statusBadge: some View {
        let (text, color) = statusInfo

        if !text.isEmpty {
            Text(text)
                .font(.caption2.bold())
                .foregroundColor(.white)
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(
                    Capsule()
                        .fill(color)
                )
        }
    }

    private var statusInfo: (String, Color) {
        switch event.status {
        case .active:
            return ("EN VIVO", .green)
        case .cancelled:
            return ("CANCELADO", .red)
        case .completed:
            return ("FINALIZADO", .gray)
        case .scheduled:
            if event.isToday {
                return ("HOY", .blue)
            }
            return ("", .clear)
        }
    }

    private var iconForEvent: String {
        let title = event.title.lowercased()

        if title.contains("yoga") { return "figure.yoga" }
        if title.contains("run") || title.contains("carrera") { return "figure.run" }
        if title.contains("swim") || title.contains("natacion") { return "figure.pool.swim" }
        if title.contains("cycling") || title.contains("ciclismo") || title.contains("spin") { return "figure.outdoor.cycle" }
        if title.contains("box") || title.contains("boxing") { return "figure.boxing" }
        if title.contains("dance") || title.contains("baile") || title.contains("zumba") { return "figure.dance" }
        if title.contains("crossfit") || title.contains("fitness") { return "figure.strengthtraining.functional" }
        if title.contains("workshop") || title.contains("taller") { return "person.3.fill" }
        if title.contains("competicion") || title.contains("competition") || title.contains("torneo") { return "trophy.fill" }
        if title.contains("pilates") { return "figure.pilates" }
        if title.contains("hiit") || title.contains("cardio") { return "figure.highintensity.intervaltraining" }

        return "calendar.circle.fill"
    }
}

// MARK: - Preview

#if DEBUG
struct EventTaggingSheet_Previews: PreviewProvider {
    static var previews: some View {
        EventTaggingSheet(
            selectedEvent: .constant(nil),
            onSelection: { _ in }
        )
        .environmentObject(ServiceContainer.shared.eventService)
        .environmentObject(ThemeManager())
    }
}
#endif
