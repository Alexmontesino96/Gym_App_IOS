//
//  ClientSessionsView.swift
//  Gym_API
//
//  Pantalla S10 del diseño: las sesiones del cliente, próximas e historial.
//
//  Fase 1: se alimenta de los datos que YA existen (las sesiones en las que el cliente está
//  inscrito). Cuando llegue el módulo de entrenamiento, cada fila añadirá foco del día,
//  modalidad presencial u online y bloque del programa.
//

import SwiftUI

struct ClientSessionsView: View {
    @EnvironmentObject var themeManager: ThemeManager
    @EnvironmentObject var classService: ClassService

    /// Abre la conversación con el entrenador. El diseño remata la lista de próximas con
    /// «Pedir sesión extra · tu coach confirma en el chat», y sin esto esa tarjeta sería
    /// otro botón que no lleva a ningún sitio.
    var onAskCoach: (() -> Void)? = nil

    @State private var tab: SessionsTab = .upcoming

    private enum SessionsTab: String, CaseIterable {
        case upcoming, history

        var title: String {
            switch self {
            case .upcoming: return "Upcoming"
            case .history: return "History"
            }
        }
    }

    private var registered: [GymClass] {
        classService.classes.filter { classService.userRegistrationStatus[$0.id] ?? false }
    }

    private var upcoming: [GymClass] {
        let now = Date()
        return registered.filter { $0.startTime > now }.sorted { $0.startTime < $1.startTime }
    }

    private var history: [GymClass] {
        let now = Date()
        return registered.filter { $0.startTime <= now }.sorted { $0.startTime > $1.startTime }
    }

    private var visible: [GymClass] {
        tab == .upcoming ? upcoming : history
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                picker

                if visible.isEmpty {
                    emptyState
                } else {
                    ScrollView(showsIndicators: false) {
                        LazyVStack(spacing: 10) {
                            ForEach(visible) { session in
                                SessionRow(
                                    session: session,
                                    isPast: tab == .history,
                                    isNext: tab == .upcoming && session.id == upcoming.first?.id
                                )
                            }

                            if tab == .upcoming, onAskCoach != nil {
                                askForSessionCard
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.bottom, 100)
                    }
                }
            }
            .padding(.top, 8)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .background(Color.dynamicBackground(theme: themeManager.currentTheme).ignoresSafeArea())
            .navigationTitle("Sessions")
            .navigationBarTitleDisplayMode(.large)
            .task { await loadWideRange() }
            .refreshable { await loadWideRange() }
        }
    }

    /// Carga un rango amplio de sesiones.
    ///
    /// No sirve `loadSessionsForDateIfNeeded(date: Date())`: fija la ventana en [hoy−3d, hoy+7d]
    /// y, si esa fecha ya cae dentro del rango cargado, retorna sin pedir nada. Con eso el
    /// historial nunca podría enseñar más de tres días hacia atrás. Aquí se pide el rango
    /// explícito que necesita esta pantalla.
    private func loadWideRange() async {
        let calendar = Calendar.current
        let today = Date()
        let start = calendar.date(byAdding: .day, value: -120, to: today) ?? today
        let end = calendar.date(byAdding: .day, value: 30, to: today) ?? today
        await classService.fetchSessionsByDateRange(startDate: start, endDate: end, limit: 200)

        // Y las INSCRIPCIONES, que es la otra mitad de la interseccion. Antes esto solo cargaba
        // las sesiones: `upcoming` cruza `classService.classes` con `userRegistrationStatus`, y
        // ese diccionario lo rellenaba una ventana de [hoy-3, hoy+7], asi que de tres sesiones
        // inscritas se veia una. `fetchMyClasses` no tiene ventana (el servidor filtra a futuro)
        // y fusiona, y la de participaciones cubre ademas el historial por tramos.
        await classService.fetchMyClasses(limit: 200)
        await classService.loadParticipationStatus(startDate: start, endDate: end)
    }

    private var picker: some View {
        HStack(spacing: 4) {
            ForEach(SessionsTab.allCases, id: \.self) { item in
                pickerButton(for: item)
            }
        }
        .padding(4)
        .background(Color.dynamicSurface(theme: themeManager.currentTheme))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.dynamicBorder(theme: themeManager.currentTheme).opacity(0.15), lineWidth: 1)
        )
        .padding(.horizontal, 16)
    }

    @ViewBuilder
    private func pickerButton(for item: SessionsTab) -> some View {
        let isSelected: Bool = (tab == item)
        let fill: Color = isSelected
            ? Color.dynamicText(theme: themeManager.currentTheme)
            : Color.clear
        let label: Color = isSelected
            ? Color.dynamicBackground(theme: themeManager.currentTheme)
            : Color.dynamicTextSecondary(theme: themeManager.currentTheme)

        Button {
            HapticManager.shared.buttonTap()
            withAnimation(.easeInOut(duration: 0.2)) { tab = item }
        } label: {
            Text(item.title)
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(label)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
                .background(RoundedRectangle(cornerRadius: 9).fill(fill))
        }
        .buttonStyle(.plain)
    }

    /// Remate de la lista de próximas. No hay endpoint para solicitar una sesión, así que
    /// no se finge uno: lleva a la conversación, que es donde de verdad se acuerda.
    private var askForSessionCard: some View {
        Button { onAskCoach?() } label: {
            HStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.dynamicSurface2(theme: themeManager.currentTheme))
                        .frame(width: 36, height: 36)
                    Image(systemName: "plus")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(Color.dynamicTextSecondary(theme: themeManager.currentTheme))
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text("Ask for another session")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(Color.dynamicText(theme: themeManager.currentTheme))
                    Text("Your coach confirms it in chat")
                        .font(.system(size: 11))
                        .foregroundColor(Color.dynamicTextTertiary(theme: themeManager.currentTheme))
                }

                Spacer(minLength: 0)
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 22)
                    .stroke(
                        Color.dynamicBorder(theme: themeManager.currentTheme).opacity(0.3),
                        style: StrokeStyle(lineWidth: 1, dash: [5, 4])
                    )
            )
        }
        .buttonStyle(.plain)
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "calendar.badge.exclamationmark")
                .font(.system(size: 38, weight: .light))
                .foregroundColor(Color.dynamicTextTertiary(theme: themeManager.currentTheme))
            Text(tab == .upcoming ? "No upcoming sessions" : "No completed sessions yet")
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(Color.dynamicText(theme: themeManager.currentTheme))
            Text(tab == .upcoming
                 ? "Whatever your trainer schedules for you shows up here."
                 : "Your first completed session will show up in this history.")
                .font(.system(size: 14))
                .foregroundColor(Color.dynamicTextSecondary(theme: themeManager.currentTheme))
                .multilineTextAlignment(.center)
        }
        .padding(.horizontal, 40)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Fila de sesión

private struct SessionRow: View {
    let session: GymClass
    let isPast: Bool
    var isNext: Bool = false

    @EnvironmentObject var themeManager: ThemeManager

    /// Minutos de la sesión, para el historial. El diseño enseña además esfuerzo percibido y
    /// marcas personales, que necesitan un registro de entrenamiento que todavía no existe.
    private var durationMinutes: Int {
        max(Int(session.endTime.timeIntervalSince(session.startTime) / 60), 1)
    }

    /// Sitio si el entrenador lo ha puesto; si no, quién imparte.
    /// El diseño enseña sitio y modalidad. La modalidad no existe en el modelo de sesión.
    private var secondaryDetail: String {
        if let room = session.room, !room.isEmpty { return room }
        return session.instructor
    }

    private var dayLabel: String {
        DateFormatter.localized(template: "EEE")
            .string(from: session.startTime)
            .uppercased()
    }

    private var dayNumber: String {
        DateFormatter.localized(template: "d").string(from: session.startTime)
    }

    /// Reloj de 12 o de 24 horas según el sitio, en lugar de "HH:mm" fijo.
    private var timeRange: String {
        let formatter = DateFormatter.localized(template: "jmm")
        return "\(formatter.string(from: session.startTime))–\(formatter.string(from: session.endTime))"
    }

    var body: some View {
        HStack(spacing: 14) {
            VStack(spacing: 2) {
                Text(dayLabel)
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundColor(Color.dynamicTextTertiary(theme: themeManager.currentTheme))
                Text(dayNumber)
                    .font(.system(size: 18, weight: .bold, design: .monospaced))
                    .foregroundColor(Color.dynamicText(theme: themeManager.currentTheme))
            }
            .frame(width: 56)
            .padding(.vertical, 8)
            .background(Color.dynamicSurface2(theme: themeManager.currentTheme))
            .clipShape(RoundedRectangle(cornerRadius: 12))

            VStack(alignment: .leading, spacing: 3) {
                Text(session.name)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(Color.dynamicText(theme: themeManager.currentTheme))
                    .lineLimit(1)
                HStack(spacing: 6) {
                    Text(timeRange)
                        .font(.system(size: 12, weight: .semibold, design: .monospaced))
                        .foregroundColor(Color.dynamicTextSecondary(theme: themeManager.currentTheme))
                    Text("·")
                        .foregroundColor(Color.dynamicTextTertiary(theme: themeManager.currentTheme))
                    Text(isPast ? "\(durationMinutes) min" : secondaryDetail)
                        .font(.system(size: 12))
                        .foregroundColor(Color.dynamicTextTertiary(theme: themeManager.currentTheme))
                        .lineLimit(1)
                }
            }

            Spacer(minLength: 0)

            if isNext {
                Text("NEXT")
                    .font(.system(size: 9, weight: .bold))
                    .tracking(0.6)
                    .foregroundColor(Color.accentInk)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Capsule().fill(Color.dynamicAccent(theme: themeManager.currentTheme)))
            } else if isPast {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 16))
                    .foregroundColor(Color.dynamicAccent(theme: themeManager.currentTheme))
            }
        }
        .padding(14)
        .background(Color.dynamicSurface(theme: themeManager.currentTheme))
        .clipShape(RoundedRectangle(cornerRadius: 22))
        .overlay(
            RoundedRectangle(cornerRadius: 22)
                .stroke(
                    isNext
                        ? Color.dynamicAccent(theme: themeManager.currentTheme)
                        : Color.dynamicBorder(theme: themeManager.currentTheme).opacity(0.15),
                    lineWidth: 1
                )
        )
        .opacity(isPast ? 0.75 : 1)
    }
}
