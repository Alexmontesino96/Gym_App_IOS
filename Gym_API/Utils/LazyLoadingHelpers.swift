//
//  LazyLoadingHelpers.swift
//  Gym_API
//
//  Helpers y modificadores para implementar lazy loading universal
//  Created as part of performance optimization phase
//

import SwiftUI
import Combine

// MARK: - Lazy Loading Configuration
struct LazyLoadingConfiguration {
    /// Threshold for converting VStack to LazyVStack
    static let minItemsForLazyStack = 5

    /// Threshold for converting HStack to LazyHStack
    static let minItemsForLazyHStack = 10

    /// Threshold for converting Grid to LazyVGrid
    static let minItemsForLazyGrid = 20

    /// Enable lazy loading globally
    static var isEnabled = true

    /// Debug mode to log conversions
    static var debugMode = false
}

// MARK: - Smart Stack View
/// Automatically chooses between VStack and LazyVStack based on content
struct SmartVStack<Content: View>: View {
    let alignment: HorizontalAlignment
    let spacing: CGFloat?
    let content: Content
    let itemCount: Int
    let pinnedViews: PinnedScrollableViews

    init(
        alignment: HorizontalAlignment = .center,
        spacing: CGFloat? = nil,
        itemCount: Int = 0,
        pinnedViews: PinnedScrollableViews = [],
        @ViewBuilder content: () -> Content
    ) {
        self.alignment = alignment
        self.spacing = spacing
        self.itemCount = itemCount
        self.pinnedViews = pinnedViews
        self.content = content()
    }

    var body: some View {
        if shouldUseLazyStack {
            ScrollView {
                LazyVStack(alignment: alignment, spacing: spacing, pinnedViews: pinnedViews) {
                    content
                }
            }
            .onAppear {
                if LazyLoadingConfiguration.debugMode {
                    Logger.shared.debug("Using LazyVStack for \(itemCount) items", category: .performance)
                }
            }
        } else {
            VStack(alignment: alignment, spacing: spacing) {
                content
            }
        }
    }

    private var shouldUseLazyStack: Bool {
        LazyLoadingConfiguration.isEnabled &&
        itemCount >= LazyLoadingConfiguration.minItemsForLazyStack
    }
}

// MARK: - Smart HStack
struct SmartHStack<Content: View>: View {
    let alignment: VerticalAlignment
    let spacing: CGFloat?
    let content: Content
    let itemCount: Int

    init(
        alignment: VerticalAlignment = .center,
        spacing: CGFloat? = nil,
        itemCount: Int = 0,
        @ViewBuilder content: () -> Content
    ) {
        self.alignment = alignment
        self.spacing = spacing
        self.itemCount = itemCount
        self.content = content()
    }

    var body: some View {
        if shouldUseLazyStack {
            ScrollView(.horizontal) {
                LazyHStack(alignment: alignment, spacing: spacing) {
                    content
                }
            }
            .onAppear {
                if LazyLoadingConfiguration.debugMode {
                    Logger.shared.debug("Using LazyHStack for \(itemCount) items", category: .performance)
                }
            }
        } else {
            HStack(alignment: alignment, spacing: spacing) {
                content
            }
        }
    }

    private var shouldUseLazyStack: Bool {
        LazyLoadingConfiguration.isEnabled &&
        itemCount >= LazyLoadingConfiguration.minItemsForLazyHStack
    }
}


// MARK: - Lazy Loading View Modifier
struct LazyLoadingModifier: ViewModifier {
    @State private var isVisible = false
    let onAppear: (() -> Void)?
    let onDisappear: (() -> Void)?

    func body(content: Content) -> some View {
        content
            .onAppear {
                if !isVisible {
                    isVisible = true
                    onAppear?()
                }
            }
            .onDisappear {
                isVisible = false
                onDisappear?()
            }
    }
}

extension View {
    func lazyLoading(
        onAppear: (() -> Void)? = nil,
        onDisappear: (() -> Void)? = nil
    ) -> some View {
        modifier(LazyLoadingModifier(onAppear: onAppear, onDisappear: onDisappear))
    }
}


// MARK: - Load More View
struct LoadMoreView: View {
    @Binding var isLoading: Bool
    let action: () async -> Void

    var body: some View {
        HStack {
            if isLoading {
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle())
                Text("Cargando más...")
                    .foregroundColor(.secondary)
            } else {
                Button("Cargar más") {
                    Task {
                        isLoading = true
                        await action()
                        isLoading = false
                    }
                }
            }
        }
        .frame(maxWidth: .infinity)
        .padding()
    }
}

// MARK: - Virtualized Grid
struct VirtualizedGrid<Item: Identifiable, Content: View>: View {
    let items: [Item]
    let columns: [GridItem]
    let spacing: CGFloat
    let content: (Item) -> Content

    @State private var visibleItems: Set<Item.ID> = []

    var body: some View {
        ScrollView {
            LazyVGrid(columns: columns, spacing: spacing) {
                ForEach(items) { item in
                    content(item)
                        .onAppear {
                            visibleItems.insert(item.id)
                            if LazyLoadingConfiguration.debugMode {
                                Logger.shared.verbose("Grid item appeared: \(item.id)", category: .performance)
                            }
                        }
                        .onDisappear {
                            visibleItems.remove(item.id)
                        }
                }
            }
        }
        .onDisappear {
            // Clean up when grid is not visible
            visibleItems.removeAll()
        }
    }
}

// MARK: - Performance Monitor
class LazyLoadingPerformanceMonitor: ObservableObject {
    static let shared = LazyLoadingPerformanceMonitor()

    @Published var visibleViews: Int = 0
    @Published var totalViews: Int = 0
    @Published var memoryUsage: Double = 0

    private var timer: Timer?

    private init() {
        startMonitoring()
    }

    private func startMonitoring() {
        timer = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: true) { _ in
            self.updateMetrics()
        }
    }

    private func updateMetrics() {
        Task { @MainActor in
            let info = ProcessInfo.processInfo
            memoryUsage = Double(info.physicalMemory) / 1_073_741_824 // Convert to GB

            Logger.shared.verbose("Lazy Loading Metrics - Visible: \(visibleViews), Total: \(totalViews), Memory: \(String(format: "%.2f", memoryUsage))GB", category: .performance)
        }
    }

    func recordViewAppeared() {
        visibleViews += 1
        totalViews += 1
    }

    func recordViewDisappeared() {
        visibleViews = max(0, visibleViews - 1)
    }

    deinit {
        timer?.invalidate()
    }
}

// MARK: - Lazy Image Loader
struct LazyImage: View {
    let url: String
    let placeholder: AnyView
    let cacheKey: String?

    @StateObject private var loader = ImageLoaderService()
    @State private var hasAppeared = false

    init(
        url: String,
        cacheKey: String? = nil,
        placeholder: () -> some View = { ProgressView() }
    ) {
        self.url = url
        self.cacheKey = cacheKey
        self.placeholder = AnyView(placeholder())
    }

    var body: some View {
        Group {
            if let image = loader.image {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
            } else {
                placeholder
            }
        }
        .onAppear {
            if !hasAppeared {
                hasAppeared = true
                loader.loadImage(from: url, cacheKeyOverride: cacheKey)
            }
        }
        .onDisappear {
            // Note: ImageLoaderService doesn't expose cancellable tasks
            // The loader will continue in background but cached for future use
        }
    }
}

// MARK: - Deferred View
/// Delays rendering of complex views until actually needed
struct DeferredView<Content: View>: View {
    let content: () -> Content
    @State private var shouldRender = false

    var body: some View {
        Group {
            if shouldRender {
                content()
            } else {
                Color.clear
                    .onAppear {
                        // Delay rendering by one frame
                        DispatchQueue.main.async {
                            shouldRender = true
                        }
                    }
            }
        }
    }
}

// MARK: - Recycled List
/// List that recycles views for better memory management
struct RecycledList<Item: Identifiable & Hashable, Content: View>: View {
    let items: [Item]
    let viewPool: Int
    let content: (Item) -> Content

    @State private var visibleRange: Range<Int> = 0..<0

    init(
        items: [Item],
        viewPool: Int = 20,
        @ViewBuilder content: @escaping (Item) -> Content
    ) {
        self.items = items
        self.viewPool = viewPool
        self.content = content
    }

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(Array(items.enumerated()), id: \.element) { index, item in
                        content(item)
                            .id(item)
                            .onAppear {
                                updateVisibleRange(for: index)
                            }
                    }
                }
            }
        }
    }

    private func updateVisibleRange(for index: Int) {
        let start = max(0, index - viewPool / 2)
        let end = min(items.count, index + viewPool / 2)
        visibleRange = start..<end

        if LazyLoadingConfiguration.debugMode {
            Logger.shared.verbose("Visible range updated: \(start)-\(end)", category: .performance)
        }
    }
}

// MARK: - View Extension for Easy Conversion
extension View {
    /// Wrap view in optimized scroll view with lazy loading
    func lazyScrollView(
        axis: Axis.Set = .vertical,
        showsIndicators: Bool = true
    ) -> some View {
        ScrollView(axis, showsIndicators: showsIndicators) {
            if axis == .vertical {
                LazyVStack {
                    self
                }
            } else {
                LazyHStack {
                    self
                }
            }
        }
    }

    /// Convert regular stack to lazy stack if needed
    func autoLazy(threshold: Int = 5) -> some View {
        SmartVStack(itemCount: threshold) {
            self
        }
    }
}