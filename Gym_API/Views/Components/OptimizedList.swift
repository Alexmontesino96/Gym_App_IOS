//
//  OptimizedList.swift
//  Gym_API
//
//  Lista optimizada con view recycling y lazy loading
//  Mejora el performance para listas grandes
//

import SwiftUI

// MARK: - Optimized List View
struct OptimizedList<Item: Identifiable, Content: View>: View {
    let items: [Item]
    let spacing: CGFloat
    let showDividers: Bool
    let preloadThreshold: Int
    let content: (Item) -> Content
    let onReachEnd: (() -> Void)?
    let onRefresh: (() async -> Void)?

    @State private var visibleRange: Range<Int> = 0..<0
    @State private var scrollOffset: CGFloat = 0
    @State private var isRefreshing = false
    @EnvironmentObject var themeManager: ThemeManager

    init(
        items: [Item],
        spacing: CGFloat = DesignSystem.Spacing.sm,
        showDividers: Bool = false,
        preloadThreshold: Int = 5,
        onReachEnd: (() -> Void)? = nil,
        onRefresh: (() async -> Void)? = nil,
        @ViewBuilder content: @escaping (Item) -> Content
    ) {
        self.items = items
        self.spacing = spacing
        self.showDividers = showDividers
        self.preloadThreshold = preloadThreshold
        self.content = content
        self.onReachEnd = onReachEnd
        self.onRefresh = onRefresh
    }

    var body: some View {
        ScrollView {
            LazyVStack(spacing: spacing) {
                // Pull to refresh indicator
                if onRefresh != nil {
                    refreshIndicator
                }

                // Items
                ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                    VStack(spacing: 0) {
                        content(item)
                            .onAppear {
                                handleItemAppear(at: index)
                            }

                        if showDividers && index < items.count - 1 {
                            Divider()
                                .padding(.leading, DesignSystem.Spacing.md)
                        }
                    }
                }

                // Loading indicator at bottom
                if items.isEmpty {
                    emptyStateView
                }
            }
            .padding(.horizontal, DesignSystem.Spacing.md)
        }
        .refreshable {
            if let onRefresh = onRefresh {
                await onRefresh()
            }
        }
    }

    // MARK: - Refresh Indicator
    private var refreshIndicator: some View {
        HStack {
            if isRefreshing {
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle())
                    .scaleEffect(0.8)
                Text("Refreshing...")
                    .font(.caption)
                    .foregroundColor(Color.dynamicTextSecondary(theme: themeManager.currentTheme))
            }
        }
        .frame(height: isRefreshing ? 40 : 0)
        .opacity(isRefreshing ? 1 : 0)
        .animation(DesignSystem.Animation.medium, value: isRefreshing)
    }

    // MARK: - Empty State
    private var emptyStateView: some View {
        VStack(spacing: DesignSystem.Spacing.lg) {
            Image(systemName: "list.bullet")
                .font(.system(size: 60))
                .foregroundColor(Color.dynamicSurface(theme: themeManager.currentTheme).opacity(0.5))

            VStack(spacing: DesignSystem.Spacing.sm) {
                Text("No Items")
                    .font(.system(size: DesignSystem.FontSize.title, weight: .semibold))
                    .foregroundColor(Color.dynamicText(theme: themeManager.currentTheme))

                Text("There are no items to display")
                    .font(.system(size: DesignSystem.FontSize.body))
                    .foregroundColor(Color.dynamicText(theme: themeManager.currentTheme).opacity(0.7))
                    .multilineTextAlignment(.center)
            }
        }
        .padding(.vertical, DesignSystem.Spacing.xxl)
    }

    // MARK: - Helper Methods
    private func handleItemAppear(at index: Int) {
        // Update visible range
        updateVisibleRange(index)

        // Check if we need to load more
        if shouldLoadMore(at: index) {
            onReachEnd?()
        }
    }

    private func updateVisibleRange(_ index: Int) {
        let start = max(0, index - 10)
        let end = min(items.count, index + 10)
        visibleRange = start..<end
    }

    private func shouldLoadMore(at index: Int) -> Bool {
        return index >= items.count - preloadThreshold
    }
}

// MARK: - Paginated List
struct PaginatedList<Item: Identifiable, Content: View>: View {
    @Binding var items: [Item]
    let pageSize: Int
    let loadPage: (Int) async throws -> [Item]
    let content: (Item) -> Content

    @State private var currentPage = 1
    @State private var isLoadingMore = false
    @State private var hasMorePages = true
    @State private var errorMessage: String?
    @EnvironmentObject var themeManager: ThemeManager

    init(
        items: Binding<[Item]>,
        pageSize: Int = 20,
        loadPage: @escaping (Int) async throws -> [Item],
        @ViewBuilder content: @escaping (Item) -> Content
    ) {
        self._items = items
        self.pageSize = pageSize
        self.loadPage = loadPage
        self.content = content
    }

    var body: some View {
        OptimizedList(
            items: items,
            onReachEnd: loadMoreIfNeeded,
            onRefresh: refresh
        ) { item in
            content(item)
        }
        .overlay(loadingOverlay)
        .alert("Error", isPresented: .constant(errorMessage != nil)) {
            Button("OK") {
                errorMessage = nil
            }
        } message: {
            if let error = errorMessage {
                Text(error)
            }
        }
    }

    // MARK: - Loading Overlay
    @ViewBuilder
    private var loadingOverlay: some View {
        if isLoadingMore {
            VStack {
                Spacer()
                HStack {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle())
                    Text("Loading more...")
                        .font(.caption)
                        .foregroundColor(Color.dynamicTextSecondary(theme: themeManager.currentTheme))
                }
                .padding()
                .background(
                    Capsule()
                        .fill(Color.dynamicBackground(theme: themeManager.currentTheme))
                        .shadow(
                            color: .black.opacity(DesignSystem.Shadow.light.opacity),
                            radius: DesignSystem.Shadow.light.radius,
                            y: DesignSystem.Shadow.light.y
                        )
                )
            }
            .padding(.bottom, DesignSystem.Spacing.lg)
        }
    }

    // MARK: - Loading Methods
    private func loadMoreIfNeeded() {
        guard !isLoadingMore && hasMorePages else { return }

        isLoadingMore = true

        Task {
            do {
                let newItems = try await loadPage(currentPage + 1)

                await MainActor.run {
                    if newItems.isEmpty || newItems.count < pageSize {
                        hasMorePages = false
                    } else {
                        currentPage += 1
                        items.append(contentsOf: newItems)
                    }
                    isLoadingMore = false
                }
            } catch {
                await MainActor.run {
                    errorMessage = error.localizedDescription
                    isLoadingMore = false
                }
            }
        }
    }

    private func refresh() async {
        currentPage = 1
        hasMorePages = true
        errorMessage = nil

        do {
            let newItems = try await loadPage(1)
            await MainActor.run {
                items = newItems
                if newItems.count < pageSize {
                    hasMorePages = false
                }
            }
        } catch {
            await MainActor.run {
                errorMessage = error.localizedDescription
            }
        }
    }
}

// MARK: - Section List
struct SectionedList<SectionID: Hashable, Item: Identifiable, Header: View, Content: View>: View {
    let sections: [(id: SectionID, title: String, items: [Item])]
    let header: (String) -> Header
    let content: (Item) -> Content

    @EnvironmentObject var themeManager: ThemeManager

    init(
        sections: [(id: SectionID, title: String, items: [Item])],
        @ViewBuilder header: @escaping (String) -> Header,
        @ViewBuilder content: @escaping (Item) -> Content
    ) {
        self.sections = sections
        self.header = header
        self.content = content
    }

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 0, pinnedViews: [.sectionHeaders]) {
                ForEach(sections, id: \.id) { section in
                    Section {
                        ForEach(section.items) { item in
                            content(item)
                                .padding(.horizontal, DesignSystem.Spacing.md)
                        }
                    } header: {
                        header(section.title)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, DesignSystem.Spacing.sm)
                            .padding(.horizontal, DesignSystem.Spacing.md)
                            .background(
                                Color.dynamicBackground(theme: themeManager.currentTheme)
                                    .opacity(0.95)
                            )
                    }
                }
            }
        }
    }
}

// MARK: - Grid List
struct OptimizedGrid<Item: Identifiable, Content: View>: View {
    let items: [Item]
    let columns: Int
    let spacing: CGFloat
    let content: (Item) -> Content

    private var gridColumns: [GridItem] {
        Array(repeating: GridItem(.flexible(), spacing: spacing), count: columns)
    }

    init(
        items: [Item],
        columns: Int = 2,
        spacing: CGFloat = DesignSystem.Spacing.md,
        @ViewBuilder content: @escaping (Item) -> Content
    ) {
        self.items = items
        self.columns = columns
        self.spacing = spacing
        self.content = content
    }

    var body: some View {
        ScrollView {
            LazyVGrid(columns: gridColumns, spacing: spacing) {
                ForEach(items) { item in
                    content(item)
                }
            }
            .padding(DesignSystem.Spacing.md)
        }
    }
}

// MARK: - Searchable List
struct SearchableList<Item: Identifiable, Content: View>: View {
    let items: [Item]
    let searchKeyPath: KeyPath<Item, String>
    let placeholder: String
    let content: (Item) -> Content

    @State private var searchText = ""
    @EnvironmentObject var themeManager: ThemeManager

    private var filteredItems: [Item] {
        if searchText.isEmpty {
            return items
        } else {
            return items.filter {
                $0[keyPath: searchKeyPath]
                    .localizedCaseInsensitiveContains(searchText)
            }
        }
    }

    init(
        items: [Item],
        searchKeyPath: KeyPath<Item, String>,
        placeholder: String = "Search...",
        @ViewBuilder content: @escaping (Item) -> Content
    ) {
        self.items = items
        self.searchKeyPath = searchKeyPath
        self.placeholder = placeholder
        self.content = content
    }

    var body: some View {
        VStack(spacing: 0) {
            // Search Bar
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(Color.dynamicTextSecondary(theme: themeManager.currentTheme))

                TextField(placeholder, text: $searchText)
                    .textFieldStyle(PlainTextFieldStyle())

                if !searchText.isEmpty {
                    Button(action: { searchText = "" }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(Color.dynamicTextSecondary(theme: themeManager.currentTheme))
                    }
                }
            }
            .padding(DesignSystem.Spacing.md)
            .background(
                RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.small)
                    .fill(Color.dynamicBackground(theme: themeManager.currentTheme))
            )
            .padding(DesignSystem.Spacing.md)

            // List
            OptimizedList(items: filteredItems) { item in
                content(item)
            }
        }
    }
}

// MARK: - Performance Monitor Extension
extension View {
    func measureListPerformance(label: String) -> some View {
        self.onAppear {
            let startTime = CFAbsoluteTimeGetCurrent()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                let timeElapsed = CFAbsoluteTimeGetCurrent() - startTime
                print("📊 List '\(label)' rendered in \(String(format: "%.3f", timeElapsed))s")
            }
        }
    }
}