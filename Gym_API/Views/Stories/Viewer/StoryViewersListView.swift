import SwiftUI

struct StoryViewersListView: View {
    @EnvironmentObject var storyService: StoryService
    @EnvironmentObject var themeManager: ThemeManager
    @Environment(\.dismiss) var dismiss

    let storyId: Int

    @State private var viewers: [StoryViewer] = []
    @State private var isLoading: Bool = false
    @State private var errorMessage: String?
    @State private var searchText: String = ""

    private var filteredViewers: [StoryViewer] {
        guard !searchText.isEmpty else { return viewers.sorted { $0.viewedAt > $1.viewedAt } }
        return viewers.filter { $0.viewerName.localizedCaseInsensitiveContains(searchText) }
            .sorted { $0.viewedAt > $1.viewedAt }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color.dynamicBackground(theme: themeManager.currentTheme).ignoresSafeArea()

                VStack(spacing: 0) {
                    searchBar

                    if isLoading {
                        ProgressView("Cargando espectadores...")
                            .padding()
                    } else if let error = errorMessage {
                        ErrorStateView(
                            title: "No se pudo cargar",
                            message: error,
                            onRetry: { Task { await load() } }
                        )
                        .padding()
                    } else if filteredViewers.isEmpty {
                        emptyState
                    } else {
                        List(filteredViewers) { viewer in
                            viewerRow(viewer)
                                .listRowBackground(Color.dynamicSurface(theme: themeManager.currentTheme))
                        }
                        .listStyle(.plain)
                    }
                }
            }
            .navigationTitle("Visto por")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cerrar") { dismiss() }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Text("\(viewers.count)")
                        .foregroundColor(.secondary)
                        .accessibilityLabel("Total de espectadores: \(viewers.count)")
                }
            }
            .task { await load() }
            .refreshable { await load(force: true) }
        }
    }

    private var searchBar: some View {
        HStack {
            Image(systemName: "magnifyingglass").foregroundColor(.secondary)
            TextField("Buscar por nombre", text: $searchText)
                .textInputAutocapitalization(.words)
                .disableAutocorrection(true)
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.dynamicSurface(theme: themeManager.currentTheme))
        )
        .padding(.horizontal)
        .padding(.top, 8)
    }

    private var emptyState: some View {
        VStack(spacing: 8) {
            Image(systemName: "eye.slash")
                .font(.system(size: 36))
                .foregroundColor(.secondary)
            Text("Aún sin espectadores")
                .font(.headline)
                .foregroundColor(Color.dynamicText(theme: themeManager.currentTheme))
            Text("Cuando alguien vea tu historia, aparecerá aquí.")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .padding(.top, 40)
    }

    @ViewBuilder
    private func viewerRow(_ viewer: StoryViewer) -> some View {
        HStack(spacing: 12) {
            CachedAsyncImage(url: viewer.viewerAvatar) { image in
                image
                    .resizable()
                    .scaledToFill()
                    .frame(width: 44, height: 44)
                    .clipShape(Circle())
            } placeholder: {
                Circle()
                    .fill(Color.gray.opacity(0.3))
                    .frame(width: 44, height: 44)
                    .overlay(
                        Image(systemName: "person.fill").foregroundColor(.white)
                    )
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(viewer.viewerName)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(Color.dynamicText(theme: themeManager.currentTheme))
                HStack(spacing: 6) {
                    Text(viewer.formattedViewTime)
                        .font(.caption)
                        .foregroundColor(.secondary)
                    if let secs = viewer.viewDurationSeconds {
                        Text("• \(secs)s")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }

            Spacer()
        }
        .padding(.vertical, 6)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(viewer.viewerName), visto hace \(viewer.formattedViewTime)")
    }

    private func load(force: Bool = false) async {
        await MainActor.run { isLoading = true; errorMessage = nil }
        let result = await storyService.fetchViewers(storyId: storyId)
        await MainActor.run {
            if let list = result {
                self.viewers = list
                self.isLoading = false
            } else {
                self.errorMessage = "No se pudo obtener la lista de espectadores"
                self.isLoading = false
            }
        }
    }
}

