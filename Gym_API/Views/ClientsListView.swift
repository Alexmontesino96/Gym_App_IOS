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

struct ClientsListView: View {
    @EnvironmentObject var workspaceContext: WorkspaceContextService
    @EnvironmentObject var themeManager: ThemeManager
    @EnvironmentObject var coachingService: CoachingService

    @State private var searchText = ""
    @State private var showingInvite = false

    private var theme: ThemeManager.AppTheme { themeManager.currentTheme }

    private var filteredClients: [ClientSummary] {
        guard !searchText.isEmpty else { return coachingService.clients }
        return coachingService.clients.filter { client in
            client.displayName.localizedCaseInsensitiveContains(searchText)
                || (client.email?.localizedCaseInsensitiveContains(searchText) ?? false)
        }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                header

                if !coachingService.clients.isEmpty {
                    searchBar
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
            .task { await coachingService.loadClients() }
            .refreshable { await coachingService.loadClients(forceRefresh: true) }
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
                    ClientRowView(client: client)
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

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: searchText.isEmpty ? "person.2" : "magnifyingglass")
                .font(.system(size: 36, weight: .light))
                .foregroundColor(Color.dynamicTextTertiary(theme: theme))

            Text(searchText.isEmpty ? "No clients yet" : "No results")
                .font(.system(size: 17, weight: .semibold))
                .foregroundColor(Color.dynamicText(theme: theme))

            Text(searchText.isEmpty
                 ? "Create an invitation code and share it with your first client."
                 : "Try another name or email.")
                .font(.system(size: 14))
                .foregroundColor(Color.dynamicTextSecondary(theme: theme))
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)

            if searchText.isEmpty {
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

    @EnvironmentObject var themeManager: ThemeManager

    private var theme: ThemeManager.AppTheme { themeManager.currentTheme }

    private var joinedText: String? {
        guard let joined = client.joinedAt else { return nil }
        let formatter = DateFormatter.localized(template: "MMMyyyy")
        return "Since \(formatter.string(from: joined))"
    }

    var body: some View {
        HStack(spacing: 12) {
            avatar

            VStack(alignment: .leading, spacing: 3) {
                Text(client.displayName)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(Color.dynamicText(theme: theme))
                    .lineLimit(1)

                if let detail = client.email ?? joinedText {
                    Text(detail)
                        .font(.system(size: 12))
                        .foregroundColor(Color.dynamicTextTertiary(theme: theme))
                        .lineLimit(1)
                }
            }

            Spacer(minLength: 0)

            if let joinedText, client.email != nil {
                Text(joinedText)
                    .font(.system(size: 11))
                    .foregroundColor(Color.dynamicTextTertiary(theme: theme))
            }
        }
        .padding(14)
        .background(Color.dynamicSurface(theme: theme))
        .clipShape(RoundedRectangle(cornerRadius: 22))
        .overlay(
            RoundedRectangle(cornerRadius: 22)
                .stroke(Color.dynamicBorder(theme: theme).opacity(0.15), lineWidth: 1)
        )
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
