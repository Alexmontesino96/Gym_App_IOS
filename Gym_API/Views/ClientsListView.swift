//
//  ClientsListView.swift
//  Gym_API
//
//  Lista de clientes del entrenador personal.
//
//  Con la salida pública dirigida a entrenadores, esta pantalla pasa a ser una de las principales
//  del producto, así que deja de mostrar los tres nombres de ejemplo que tenía y se alimenta de
//  GET /gyms/users?role=MEMBER, que es la pertenencia real al espacio de trabajo.
//
//  Lo que todavía NO se puede mostrar por cliente, y por eso no se inventa:
//    - sesiones del mes: no existe el módulo de entrenamiento
//    - estado activo o inactivo: la pertenencia no lleva ese dato
//  Ver PLAN_MODO_CLIENTE_PT.md.
//

import SwiftUI
import TrainingCore

struct ClientsListView: View {
    /// Lleva a la pestaña de mensajes. La posee `TrainerMainTabView`, igual que en el panel.
    var onGoToMessages: () -> Void = {}

    @EnvironmentObject var workspaceContext: WorkspaceContextService
    @EnvironmentObject var themeManager: ThemeManager
    @EnvironmentObject var coachingService: CoachingService
    @EnvironmentObject var trainingService: TrainingService

    @State private var searchText = ""
    @State private var showingInvite = false
    @State private var path = NavigationPath()
    @State private var filter: ClientsFilter = .all

    private var theme: ThemeManager.AppTheme { themeManager.currentTheme }

    /// El filtro de la visión §8.3. «All» es lo de siempre; «Needs attention» deja solo a quien
    /// el servidor ha marcado con alguna razón.
    private enum ClientsFilter: String, CaseIterable, Identifiable {
        case all = "All"
        case needsAttention = "Needs attention"

        var id: String { rawValue }
    }

    /// El módulo puede estar apagado en el espacio: sin él no hay resumen, y sin resumen no hay
    /// ni segunda línea ni filtro. Falla cerrado, como el resto del módulo.
    private var isTrainingEnabled: Bool {
        workspaceContext.isFeatureEnabled(\.training)
    }

    private var summary: TrainingClientsSummary? {
        isTrainingEnabled ? trainingService.clientsSummary : nil
    }

    private func attentionSummary(for client: ClientSummary) -> TrainingClientSummary? {
        summary?.client(withId: client.id)
    }

    /// El orden de severidad lo decide el SERVIDOR (razones ↓, `days_silent` ↓, nombre). Aquí
    /// solo se respeta: reordenar en el teléfono daría dos listas distintas para los mismos datos.
    private var attentionOrder: [Int: Int] {
        guard let flagged = summary?.needingAttention else { return [:] }
        return Dictionary(uniqueKeysWithValues: flagged.enumerated().map { ($0.element.userId, $0.offset) })
    }

    private var filteredClients: [ClientSummary] {
        var clients = coachingService.clients

        if !searchText.isEmpty {
            clients = clients.filter { client in
                client.displayName.localizedCaseInsensitiveContains(searchText)
                    || (client.email?.localizedCaseInsensitiveContains(searchText) ?? false)
            }
        }

        guard filter == .needsAttention, summary != nil else { return clients }
        let order = attentionOrder
        return clients
            .filter { order[$0.id] != nil }
            .sorted { (order[$0.id] ?? .max) < (order[$1.id] ?? .max) }
    }

    /// Cuántos hay marcados, para la píldora del filtro. Nulo mientras el resumen no ha llegado:
    /// un cero afirmaría que nadie necesita nada.
    private var attentionCount: Int? {
        summary?.needingAttention.count
    }

    var body: some View {
        NavigationStack(path: $path) {
            VStack(spacing: 0) {
                header

                if !coachingService.clients.isEmpty {
                    searchBar
                    if isTrainingEnabled { filterPicker }
                }

                content
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .background(Color.dynamicBackground(theme: theme).ignoresSafeArea())
            .navigationTitle(workspaceContext.getCapitalizedTerm("clients"))
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button { showingInvite = true } label: {
                        Image(systemName: "person.badge.plus")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(Color.dynamicAccent(theme: theme))
                    }
                    .accessibilityLabel("Invite a client")
                }
            }
            .navigationDestination(for: TrainerTrainingRoute.self) { route in
                TrainerTrainingDestination(route: route, path: $path, onMessage: onGoToMessages)
            }
            .task { await load() }
            .refreshable { await load(force: true) }
            .sheet(isPresented: $showingInvite, onDismiss: {
                // El cliente puede haber canjeado ya; se refresca para que aparezca.
                Task { await coachingService.loadClients(forceRefresh: true) }
            }) {
                InviteClientSheet()
                    .environmentObject(themeManager)
                    .environmentObject(GymService.shared)
            }
        }
    }


    // MARK: - Cabecera

    private var header: some View {
        HStack(spacing: 12) {
            countBadge(
                value: "\(coachingService.clients.count)",
                label: coachingService.clients.count == 1 ? "client" : "clients"
            )

            if let maxClients = workspaceContext.context?.workspace.maxClients, maxClients > 0 {
                countBadge(value: "\(maxClients)", label: "seats")
            }

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 14)
    }

    private func countBadge(value: String, label: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(value)
                .font(.system(size: 24, weight: .bold, design: .monospaced))
                .tracking(-1.0)
                .foregroundColor(Color.dynamicText(theme: theme))
            Text(label.uppercased())
                .font(.system(size: 9, weight: .bold))
                .tracking(0.8)
                .foregroundColor(Color.dynamicTextTertiary(theme: theme))
        }
    }

    private var searchBar: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 14))
                .foregroundColor(Color.dynamicTextTertiary(theme: theme))

            TextField("Search", text: $searchText)
                .font(.system(size: 15))
                .foregroundColor(Color.dynamicText(theme: theme))
                .autocorrectionDisabled()
                .textInputAutocapitalization(.never)

            if !searchText.isEmpty {
                Button { searchText = "" } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 15))
                        .foregroundColor(Color.dynamicTextTertiary(theme: theme))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(12)
        .background(Color.dynamicSurface(theme: theme))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.dynamicBorder(theme: theme).opacity(0.15), lineWidth: 1)
        )
        .padding(.horizontal, 16)
        .padding(.bottom, 12)
    }

    // MARK: - Carga

    /// La pertenencia y el triage se piden a la vez: la fila necesita las dos cosas y esperar
    /// una detrás de otra dejaría la segunda línea vacía medio segundo.
    private func load(force: Bool = false) async {
        async let clients: Void = coachingService.loadClients(forceRefresh: force)
        async let attention: Void = loadClientsSummary()
        _ = await (clients, attention)
    }

    /// Falla cerrado: sin el módulo, la ruta responde 403 y no hay nada que pedir.
    private func loadClientsSummary() async {
        guard isTrainingEnabled else { return }
        await trainingService.fetchClientsSummary()
    }

    // MARK: - Filtro (visión §8.3)

    /// «Needs attention (3)» cuando se sabe cuántos son; solo el nombre mientras no ha llegado
    /// el resumen.
    private func label(for option: ClientsFilter) -> String {
        guard option == .needsAttention, let attentionCount, attentionCount > 0 else { return option.rawValue }
        return "\(option.rawValue) (\(attentionCount))"
    }

    private var filterPicker: some View {
        VStack(spacing: 8) {
            Picker("Filter", selection: $filter) {
                ForEach(ClientsFilter.allCases) { option in
                    Text(label(for: option)).tag(option)
                }
            }
            .pickerStyle(.segmented)

            // El resumen no cargó: se dice, y la lista sigue estando entera debajo.
            if trainingService.clientsSummaryState == .failed && summary == nil {
                TrainingRetryRow(
                    message: "Couldn't load who needs attention.",
                    retryTitle: "Retry",
                    onRetry: { Task { await trainingService.fetchClientsSummary() } }
                )
            }
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 12)
    }

    // MARK: - Contenido

    @ViewBuilder
    private var content: some View {
        switch coachingService.clientsState {
        case .loading, .idle where coachingService.clients.isEmpty:
            loadingList
        case .failed where coachingService.clients.isEmpty:
            errorState
        default:
            if filteredClients.isEmpty {
                emptyState
            } else {
                clientsList
            }
        }
    }

    private var clientsList: some View {
        ScrollView(showsIndicators: false) {
            LazyVStack(spacing: 10) {
                ForEach(filteredClients) { client in
                    NavigationLink(value: TrainerTrainingRoute.clientDetail(TrainingClientRef(client: client))) {
                        ClientRowView(client: client, summary: attentionSummary(for: client))
                    }
                    .buttonStyle(.plain)
                    .accessibilityHint("Opens the client's programs and logs.")
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 100)
        }
    }

    private var loadingList: some View {
        VStack(spacing: 10) {
            ForEach(0..<4, id: \.self) { _ in
                HStack(spacing: 12) {
                    SkeletonView(width: 44, height: 44, cornerRadius: 22)
                    VStack(alignment: .leading, spacing: 6) {
                        SkeletonView(width: 150, height: 14, cornerRadius: 4)
                        SkeletonView(width: 100, height: 11, cornerRadius: 4)
                    }
                    Spacer(minLength: 0)
                }
                .padding(14)
                .background(Color.dynamicSurface(theme: theme))
                .clipShape(RoundedRectangle(cornerRadius: 22))
            }
        }
        .padding(.horizontal, 16)
    }

    private var errorState: some View {
        VStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 34, weight: .light))
                .foregroundColor(Color.dynamicTextTertiary(theme: theme))
            Text("Could not load your client list")
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(Color.dynamicText(theme: theme))
                .multilineTextAlignment(.center)
            Button {
                Task { await coachingService.loadClients(forceRefresh: true) }
            } label: {
                Text("Try again")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(ThemeManager.accentInkForCurrentAccent(theme: theme))
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(Capsule().fill(Color.dynamicAccent(theme: theme)))
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 40)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    /// El filtro está puesto y no queda nadie: la buena noticia, no un error. Con una búsqueda
    /// escrita no aplica: ahí el vacío es de la búsqueda, y decir «everyone's on track» mentiría.
    private var isAllClearEmpty: Bool {
        filter == .needsAttention && searchText.isEmpty && summary != nil && !coachingService.clients.isEmpty
    }

    private var emptyIcon: String {
        if isAllClearEmpty { return "checkmark.circle" }
        return searchText.isEmpty ? "person.2" : "magnifyingglass"
    }

    private var emptyTitle: String {
        if isAllClearEmpty { return "Everyone's on track" }
        return searchText.isEmpty ? "No clients yet" : "No results"
    }

    private var emptyMessage: String {
        if isAllClearEmpty {
            return "Nobody has missed a session, gone quiet or left a check-in pending."
        }
        return searchText.isEmpty
            ? "Create an invitation code and share it with your first client."
            : "Try another name or email."
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: emptyIcon)
                .font(.system(size: 36, weight: .light))
                .foregroundColor(Color.dynamicTextTertiary(theme: theme))

            Text(emptyTitle)
                .font(.system(size: 17, weight: .semibold))
                .foregroundColor(Color.dynamicText(theme: theme))

            Text(emptyMessage)
                .font(.system(size: 14))
                .foregroundColor(Color.dynamicTextSecondary(theme: theme))
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)

            if isAllClearEmpty {
                Button { filter = .all } label: {
                    Text("Show all clients")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(ThemeManager.accentInkForCurrentAccent(theme: theme))
                        .padding(.horizontal, 18)
                        .padding(.vertical, 10)
                        .background(Capsule().fill(Color.dynamicAccent(theme: theme)))
                }
                .buttonStyle(.plain)
                .padding(.top, 4)
            } else if searchText.isEmpty {
                Button { showingInvite = true } label: {
                    Text("Invite a client")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(ThemeManager.accentInkForCurrentAccent(theme: theme))
                        .padding(.horizontal, 18)
                        .padding(.vertical, 10)
                        .background(Capsule().fill(Color.dynamicAccent(theme: theme)))
                }
                .buttonStyle(.plain)
                .padding(.top, 4)
            }
        }
        .padding(.horizontal, 40)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Fila de cliente

private struct ClientRowView: View {
    let client: ClientSummary
    /// Lo que el triage sabe de este cliente. Nulo con el módulo apagado o mientras carga: la
    /// fila vuelve entonces a ser la de siempre, sin inventarse un estado.
    var summary: TrainingClientSummary?

    @EnvironmentObject var themeManager: ThemeManager

    private var theme: ThemeManager.AppTheme { themeManager.currentTheme }

    private var joinedText: String? {
        guard let joined = client.joinedAt else { return nil }
        let formatter = DateFormatter.localized(template: "MMMyyyy")
        return "Since \(formatter.string(from: joined))"
    }

    /// La segunda línea: «Trained yesterday · 71% adherence». Sin resumen, lo de antes.
    private var secondLine: String? {
        summary?.statusLine ?? client.email ?? joinedText
    }

    /// Solo quien tiene razones lleva chips. Al que va bien no se le pone nada: la ausencia de
    /// marca es la buena noticia (visión §8.3).
    private var attentionTexts: [String] {
        summary?.attentionTexts ?? []
    }

    /// Lo que oye VoiceOver: nombre, cómo va y por qué mirarlo, en una sola frase.
    private var accessibilityText: String {
        var parts = [client.displayName]
        if let secondLine, !secondLine.isEmpty { parts.append(secondLine) }
        if let summary, summary.needsAttention { parts.append(summary.attentionText) }
        return parts.joined(separator: ". ")
    }

    var body: some View {
        HStack(spacing: 12) {
            avatar

            VStack(alignment: .leading, spacing: 3) {
                Text(client.displayName)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(Color.dynamicText(theme: theme))
                    .lineLimit(1)

                if let secondLine {
                    Text(secondLine)
                        .font(.system(size: 12))
                        .foregroundColor(Color.dynamicTextTertiary(theme: theme))
                        .lineLimit(1)
                }

                if !attentionTexts.isEmpty {
                    attentionChips
                }
            }

            Spacer(minLength: 0)

            if summary == nil, let joinedText, client.email != nil {
                Text(joinedText)
                    .font(.system(size: 11))
                    .foregroundColor(Color.dynamicTextTertiary(theme: theme))
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityText)
        .padding(14)
        .background(Color.dynamicSurface(theme: theme))
        .clipShape(RoundedRectangle(cornerRadius: 22))
        .overlay(
            RoundedRectangle(cornerRadius: 22)
                .stroke(Color.dynamicBorder(theme: theme).opacity(0.15), lineWidth: 1)
        )
    }

    /// Tres caben en la fila con el tipo grande; el resto se cuenta. VoiceOver las lee todas,
    /// que para eso `accessibilityText` no recorta.
    private static let maxChips = 3

    /// Las razones, una píldora cada una, en la tinta de aviso del tema (nunca `warningYellow`
    /// crudo: en tema claro no se lee).
    private var attentionChips: some View {
        HStack(spacing: 6) {
            ForEach(attentionTexts.prefix(Self.maxChips), id: \.self) { text in
                Text(text)
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundColor(Color.dynamicWarningText(theme: theme))
                    .lineLimit(1)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Capsule().fill(Color.dynamicWarningText(theme: theme).opacity(0.14)))
            }

            if attentionTexts.count > Self.maxChips {
                Text("+\(attentionTexts.count - Self.maxChips)")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundColor(Color.dynamicTextTertiary(theme: theme))
            }
        }
        .padding(.top, 2)
    }

    private var avatar: some View {
        Group {
            if let picture = client.pictureURL, !picture.isEmpty {
                OptimizedAsyncImage(
                    url: picture,
                    displaySize: CGSize(width: 44, height: 44),
                    placeholder: { AnyView(initialsCircle) },
                    errorView: { AnyView(initialsCircle) }
                )
                .frame(width: 44, height: 44)
                .clipShape(Circle())
            } else {
                initialsCircle
            }
        }
    }

    private var initialsCircle: some View {
        ZStack {
            Circle().fill(Color.dynamicSurface2(theme: theme))
            Text(client.initials)
                .font(.system(size: 15, weight: .bold))
                .foregroundColor(Color.dynamicTextSecondary(theme: theme))
        }
        .frame(width: 44, height: 44)
    }
}
