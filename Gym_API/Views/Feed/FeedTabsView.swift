import SwiftUI

/// Vista con tabs segmentados para Timeline, Explore y Location feeds
struct FeedTabsView: View {
    @EnvironmentObject var themeManager: ThemeManager
    @EnvironmentObject var postService: PostService
    @EnvironmentObject var authService: AuthServiceDirect

    @State private var selectedTab: FeedTab = .timeline
    @State private var showingCreatePost = false

    enum FeedTab: String, CaseIterable {
        case timeline = "Timeline"
        case explore = "Explorar"
        case location = "Ubicación"

        var icon: String {
            switch self {
            case .timeline: return "clock"
            case .explore: return "compass"
            case .location: return "location"
            }
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header con tabs
            headerSection

            // Feed content según tab seleccionado
            TabView(selection: $selectedTab) {
                TimelineFeedView()
                    .tag(FeedTab.timeline)

                ExploreFeedView()
                    .tag(FeedTab.explore)

                LocationFeedView()
                    .tag(FeedTab.location)
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
        }
        .sheet(isPresented: $showingCreatePost) {
            CreatePostView()
                .environmentObject(themeManager)
                .environmentObject(postService)
                .environmentObject(authService)
        }
    }

    // MARK: - Header Section

    private var headerSection: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Feed Social")
                    .font(.system(size: 24, weight: .bold))
                    .foregroundColor(Color.dynamicText(theme: themeManager.currentTheme))

                Spacer()

                // Create post button
                Button(action: {
                    showingCreatePost = true
                }) {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 28))
                        .foregroundColor(Color.dynamicAccent(theme: themeManager.currentTheme))
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)
            .padding(.bottom, 12)

            // Segmented control
            segmentedControl
                .padding(.horizontal, 16)
                .padding(.bottom, 12)

            Divider()
        }
        .background(Color.dynamicBackground(theme: themeManager.currentTheme))
    }

    private var segmentedControl: some View {
        HStack(spacing: 0) {
            ForEach(FeedTab.allCases, id: \.self) { tab in
                tabButton(tab)
            }
        }
        .background(Color.dynamicSurface(theme: themeManager.currentTheme))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    private func tabButton(_ tab: FeedTab) -> some View {
        Button(action: {
            withAnimation(.spring(response: 0.3)) {
                selectedTab = tab
            }
        }) {
            HStack(spacing: 6) {
                Image(systemName: tab.icon)
                    .font(.system(size: 14))
                Text(tab.rawValue)
                    .font(.system(size: 14, weight: .medium))
            }
            .foregroundColor(selectedTab == tab ? .white : Color.dynamicText(theme: themeManager.currentTheme))
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(selectedTab == tab ? Color.dynamicAccent(theme: themeManager.currentTheme) : Color.clear)
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Timeline Feed View

struct TimelineFeedView: View {
    @EnvironmentObject var themeManager: ThemeManager
    @StateObject private var viewModel = SocialFeedViewModel(feedType: .timeline)

    var body: some View {
        FeedContentView(viewModel: viewModel)
            .environmentObject(themeManager)
    }
}

// MARK: - Explore Feed View

struct ExploreFeedView: View {
    @EnvironmentObject var themeManager: ThemeManager
    @StateObject private var viewModel = SocialFeedViewModel(feedType: .explore)

    var body: some View {
        FeedContentView(viewModel: viewModel)
            .environmentObject(themeManager)
    }
}

// MARK: - Location Feed View

struct LocationFeedView: View {
    @EnvironmentObject var themeManager: ThemeManager
    @State private var selectedLocation: String = ""
    @State private var showingLocationPicker = false
    @StateObject private var viewModel: SocialFeedViewModel

    init() {
        _viewModel = StateObject(wrappedValue: SocialFeedViewModel(feedType: .location("")))
    }

    var body: some View {
        VStack(spacing: 0) {
            // Location search bar
            locationSearchBar

            // Feed content
            FeedContentView(viewModel: viewModel)
                .environmentObject(themeManager)
        }
    }

    private var locationSearchBar: some View {
        HStack(spacing: 12) {
            Image(systemName: "magnifyingglass")
                .foregroundColor(.gray)

            TextField("Buscar ubicación", text: $selectedLocation)
                .font(.system(size: 15))
                .submitLabel(.search)
                .onSubmit {
                    searchLocation()
                }

            if !selectedLocation.isEmpty {
                Button(action: {
                    selectedLocation = ""
                    searchLocation()
                }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.gray)
                }
            }
        }
        .padding(12)
        .background(Color.dynamicSurface(theme: themeManager.currentTheme))
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
    }

    private func searchLocation() {
        // Recrear viewModel con nueva ubicación
        let newViewModel = SocialFeedViewModel(feedType: .location(selectedLocation))
        Task {
            await newViewModel.loadInitial()
        }
    }
}

// MARK: - Feed Content View (Compartida)

struct FeedContentView: View {
    @EnvironmentObject var themeManager: ThemeManager
    @ObservedObject var viewModel: SocialFeedViewModel

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                if viewModel.isLoading && viewModel.posts.isEmpty {
                    // Loading skeleton
                    ForEach(0..<5, id: \.self) { _ in
                        PostCardSkeleton()
                            .environmentObject(themeManager)
                    }
                } else if viewModel.shouldShowEmptyState {
                    // Empty state
                    emptyStateView
                } else if viewModel.shouldShowError {
                    // Error state
                    errorView
                } else {
                    // Posts list
                    ForEach(viewModel.posts) { post in
                        PostCard(post: post)
                            .environmentObject(themeManager)
                            .onAppear {
                                // Load more when reaching last item
                                if post.id == viewModel.posts.last?.id {
                                    Task {
                                        await viewModel.loadMore()
                                    }
                                }
                            }

                        Divider()
                            .padding(.horizontal, 16)
                    }

                    // Loading more indicator
                    if viewModel.isLoadingMore {
                        HStack {
                            Spacer()
                            ProgressView()
                                .padding()
                            Spacer()
                        }
                    }
                }
            }
        }
        .refreshable {
            await viewModel.refresh()
        }
        .task {
            if viewModel.posts.isEmpty {
                await viewModel.loadInitial()
            }
        }
    }

    private var emptyStateView: some View {
        VStack(spacing: 20) {
            Spacer()

            Image(systemName: "photo.on.rectangle.angled")
                .font(.system(size: 60))
                .foregroundColor(.gray.opacity(0.5))

            Text("No hay posts todavía")
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(Color.dynamicText(theme: themeManager.currentTheme))

            Text("Sé el primero en compartir algo")
                .font(.system(size: 14))
                .foregroundColor(.gray)

            Spacer()
        }
        .frame(maxWidth: .infinity)
        .padding(40)
    }

    private var errorView: some View {
        VStack(spacing: 16) {
            Spacer()

            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 50))
                .foregroundColor(.red)

            Text("Error al cargar posts")
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(Color.dynamicText(theme: themeManager.currentTheme))

            if let error = viewModel.errorMessage {
                Text(error)
                    .font(.system(size: 14))
                    .foregroundColor(.gray)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }

            Button(action: {
                Task {
                    await viewModel.refresh()
                }
            }) {
                Text("Reintentar")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 12)
                    .background(Color.dynamicAccent(theme: themeManager.currentTheme))
                    .clipShape(RoundedRectangle(cornerRadius: 10))
            }

            Spacer()
        }
        .frame(maxWidth: .infinity)
        .padding(40)
    }
}

// MARK: - Post Card Skeleton

struct PostCardSkeleton: View {
    @EnvironmentObject var themeManager: ThemeManager
    @State private var isAnimating = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            HStack(spacing: 12) {
                Circle()
                    .fill(Color.gray.opacity(0.3))
                    .frame(width: 40, height: 40)

                VStack(alignment: .leading, spacing: 4) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.gray.opacity(0.3))
                        .frame(width: 120, height: 12)

                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.gray.opacity(0.2))
                        .frame(width: 80, height: 10)
                }

                Spacer()
            }

            // Image placeholder
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.gray.opacity(0.3))
                .frame(height: 300)

            // Caption lines
            VStack(alignment: .leading, spacing: 6) {
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color.gray.opacity(0.3))
                    .frame(height: 10)

                RoundedRectangle(cornerRadius: 4)
                    .fill(Color.gray.opacity(0.2))
                    .frame(width: 200, height: 10)
            }

            // Actions
            HStack(spacing: 20) {
                ForEach(0..<3) { _ in
                    Circle()
                        .fill(Color.gray.opacity(0.3))
                        .frame(width: 24, height: 24)
                }
            }
        }
        .padding(16)
        .opacity(isAnimating ? 0.5 : 1.0)
        .animation(.easeInOut(duration: 1.0).repeatForever(autoreverses: true), value: isAnimating)
        .onAppear {
            isAnimating = true
        }
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        FeedTabsView()
            .environmentObject(ThemeManager())
            .environmentObject(PostService.shared)
            .environmentObject(AuthServiceDirect())
    }
}
