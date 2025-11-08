//
//  ClientsListView.swift
//  Gym_API
//
//  Created by Claude Code on 2025-01-25
//

import SwiftUI

struct ClientsListView: View {
    @EnvironmentObject var workspaceContext: WorkspaceContextService
    @EnvironmentObject var themeManager: ThemeManager

    @State private var searchText = ""
    @State private var selectedFilter: ClientFilter = .active
    @State private var showingAddClient = false
    @State private var isRefreshing = false

    // Mock data - TODO: Replace with actual service call
    @State private var clients: [TrainerClient] = [
        TrainerClient(id: 1, name: "John Doe", email: "john@example.com", status: .active, sessionsThisMonth: 8, joinDate: Date()),
        TrainerClient(id: 2, name: "Jane Smith", email: "jane@example.com", status: .active, sessionsThisMonth: 12, joinDate: Date()),
        TrainerClient(id: 3, name: "Bob Johnson", email: "bob@example.com", status: .inactive, sessionsThisMonth: 0, joinDate: Date())
    ]

    var filteredClients: [TrainerClient] {
        clients
            .filter { client in
                switch selectedFilter {
                case .all:
                    return true
                case .active:
                    return client.status == .active
                case .inactive:
                    return client.status == .inactive
                }
            }
            .filter { client in
                searchText.isEmpty || client.name.localizedCaseInsensitiveContains(searchText) || client.email.localizedCaseInsensitiveContains(searchText)
            }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Stats Header
                statsHeader

                // Filter Picker
                filterPicker

                // Search Bar
                searchBar

                // Clients List
                if filteredClients.isEmpty {
                    emptyStateView
                } else {
                    clientsList
                }
            }
            .background(Color.dynamicSurface(theme: themeManager.currentTheme))
            .navigationTitle(workspaceContext.getCapitalizedTerm("clients"))
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        showingAddClient = true
                    }) {
                        Image(systemName: "plus.circle.fill")
                            .foregroundColor(themeManager.currentTheme == .dark ?
                                Color(red: 0.85, green: 0.2, blue: 0.2) :
                                Color(red: 61.0/255.0, green: 190.0/255.0, blue: 208.0/255.0))
                    }
                }
            }
            .refreshable {
                await refreshClients()
            }
            .sheet(isPresented: $showingAddClient) {
                AddClientView()
            }
        }
    }

    // MARK: - Stats Header

    private var statsHeader: some View {
        HStack(spacing: 16) {
            ClientStatBadge(
                value: "\(clients.filter { $0.status == .active }.count)",
                label: "Active",
                color: .green,
                theme: themeManager.currentTheme
            )

            ClientStatBadge(
                value: "\(clients.count)",
                label: "Total",
                color: .blue,
                theme: themeManager.currentTheme
            )

            if let stats = workspaceContext.stats,
               case .trainer(let metrics) = stats.metrics {
                ClientStatBadge(
                    value: "\(Int(metrics.capacityPercentage))%",
                    label: "Capacity",
                    color: metrics.capacityPercentage >= 90 ? .orange : .purple,
                    theme: themeManager.currentTheme
                )
            }
        }
        .padding()
        .background(Color.dynamicSurface(theme: themeManager.currentTheme))
    }

    // MARK: - Filter Picker

    private var filterPicker: some View {
        Picker("Filter", selection: $selectedFilter) {
            ForEach(ClientFilter.allCases, id: \.self) { filter in
                Text(filter.rawValue.capitalized)
                    .tag(filter)
            }
        }
        .pickerStyle(.segmented)
        .padding(.horizontal)
        .padding(.vertical, 8)
    }

    // MARK: - Search Bar

    private var searchBar: some View {
        HStack {
            Image(systemName: "magnifyingglass")
                .foregroundColor(.secondary)

            TextField("Search \(workspaceContext.getTerm("clients"))...", text: $searchText)
                .textFieldStyle(.plain)
                .autocorrectionDisabled()

            if !searchText.isEmpty {
                Button(action: {
                    searchText = ""
                }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color.dynamicSurface(theme: themeManager.currentTheme))
        )
        .padding(.horizontal)
        .padding(.bottom, 8)
    }

    // MARK: - Clients List

    private var clientsList: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                ForEach(filteredClients) { client in
                    NavigationLink(destination: ClientDetailView(client: client)) {
                        ClientRow(client: client, theme: themeManager.currentTheme)
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
            .padding()
        }
    }

    // MARK: - Empty State

    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Image(systemName: "person.2.slash")
                .font(.system(size: 60))
                .foregroundColor(.secondary)

            Text("No \(workspaceContext.getTerm("clients")) found")
                .font(.headline)
                .foregroundColor(Color.dynamicText(theme: themeManager.currentTheme))

            Text(searchText.isEmpty ?
                "Add your first \(workspaceContext.getTerm("client")) to get started" :
                "Try adjusting your search or filters")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)

            if searchText.isEmpty {
                Button(action: {
                    showingAddClient = true
                }) {
                    Text("Add \(workspaceContext.getCapitalizedTerm("client"))")
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                        .padding(.horizontal, 24)
                        .padding(.vertical, 12)
                        .background(
                            RoundedRectangle(cornerRadius: 10)
                                .fill(themeManager.currentTheme == .dark ?
                                    Color(red: 0.85, green: 0.2, blue: 0.2) :
                                    Color(red: 61.0/255.0, green: 190.0/255.0, blue: 208.0/255.0))
                        )
                }
                .padding(.top, 8)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }

    // MARK: - Data Methods

    private func refreshClients() async {
        isRefreshing = true
        // TODO: Call actual service to fetch clients
        try? await Task.sleep(nanoseconds: 1_000_000_000)
        isRefreshing = false
    }
}

// MARK: - Client Filter Enum

enum ClientFilter: String, CaseIterable {
    case all = "all"
    case active = "active"
    case inactive = "inactive"
}

// MARK: - Client Stat Badge Component

struct ClientStatBadge: View {
    let value: String
    let label: String
    let color: Color
    let theme: ThemeManager.AppTheme

    var body: some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(color)

            Text(label)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Client Row Component

struct ClientRow: View {
    let client: TrainerClient
    let theme: ThemeManager.AppTheme

    var body: some View {
        HStack(spacing: 12) {
            // Avatar
            Circle()
                .fill(LinearGradient(
                    colors: [
                        client.status == .active ? Color.green : Color.gray,
                        client.status == .active ? Color.green.opacity(0.7) : Color.gray.opacity(0.7)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ))
                .frame(width: 50, height: 50)
                .overlay(
                    Text(client.initials)
                        .font(.headline)
                        .foregroundColor(.white)
                )

            // Client Info
            VStack(alignment: .leading, spacing: 4) {
                Text(client.name)
                    .font(.headline)
                    .foregroundColor(Color.dynamicText(theme: theme))

                Text(client.email)
                    .font(.caption)
                    .foregroundColor(.secondary)

                HStack(spacing: 4) {
                    Image(systemName: "figure.walk")
                        .font(.caption2)

                    Text("\(client.sessionsThisMonth) sessions this month")
                        .font(.caption2)
                }
                .foregroundColor(.secondary)
            }

            Spacer()

            // Status Badge
            VStack(alignment: .trailing, spacing: 4) {
                StatusBadge(status: client.status, theme: theme)

                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.dynamicSurface(theme: theme))
                .shadow(color: Color.black.opacity(0.05), radius: 4, x: 0, y: 2)
        )
    }
}

// MARK: - Status Badge Component

struct StatusBadge: View {
    let status: ClientStatus
    let theme: ThemeManager.AppTheme

    var body: some View {
        Text(status.rawValue.capitalized)
            .font(.caption2)
            .fontWeight(.semibold)
            .foregroundColor(status == .active ? .green : .gray)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill((status == .active ? Color.green : Color.gray).opacity(0.1))
            )
    }
}

// MARK: - Trainer Client Model

struct TrainerClient: Identifiable {
    let id: Int
    let name: String
    let email: String
    let status: ClientStatus
    let sessionsThisMonth: Int
    let joinDate: Date

    var initials: String {
        let components = name.split(separator: " ")
        if components.count >= 2 {
            return String(components[0].prefix(1)) + String(components[1].prefix(1))
        } else if let first = components.first {
            return String(first.prefix(2))
        }
        return "?"
    }
}

enum ClientStatus: String {
    case active
    case inactive
}

// MARK: - Add Client View (Placeholder)

struct AddClientView: View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var workspaceContext: WorkspaceContextService
    @EnvironmentObject var themeManager: ThemeManager

    @State private var name = ""
    @State private var email = ""
    @State private var phone = ""

    var body: some View {
        NavigationStack {
            Form {
                Section(header: Text("\(workspaceContext.getCapitalizedTerm("client")) Information")) {
                    TextField("Full Name", text: $name)
                    TextField("Email", text: $email)
                        .keyboardType(.emailAddress)
                        .autocapitalization(.none)
                    TextField("Phone", text: $phone)
                        .keyboardType(.phonePad)
                }
            }
            .navigationTitle("Add \(workspaceContext.getCapitalizedTerm("client"))")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        // TODO: Save client
                        dismiss()
                    }
                    .disabled(name.isEmpty || email.isEmpty)
                }
            }
        }
    }
}

// MARK: - Client Detail View (Placeholder)

struct ClientDetailView: View {
    let client: TrainerClient
    @EnvironmentObject var themeManager: ThemeManager

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Client Header
                VStack(spacing: 12) {
                    Circle()
                        .fill(LinearGradient(
                            colors: [Color.blue, Color.blue.opacity(0.7)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ))
                        .frame(width: 80, height: 80)
                        .overlay(
                            Text(client.initials)
                                .font(.largeTitle)
                                .foregroundColor(.white)
                        )

                    Text(client.name)
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(Color.dynamicText(theme: themeManager.currentTheme))

                    Text(client.email)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .padding()

                // TODO: Add client details, sessions history, progress, etc.
                Text("Client details coming soon")
                    .foregroundColor(.secondary)
            }
            .padding()
        }
        .background(Color.dynamicSurface(theme: themeManager.currentTheme))
        .navigationTitle(client.name)
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - Preview

#Preview {
    ClientsListView()
        .environmentObject(WorkspaceContextService.shared)
        .environmentObject(ThemeManager())
}
