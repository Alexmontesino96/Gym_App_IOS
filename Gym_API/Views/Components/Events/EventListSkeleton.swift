import SwiftUI

/// Skeleton específico para la lista de eventos en EventsView
struct EventListSkeleton: View {
    @EnvironmentObject var themeManager: ThemeManager
    @State private var shimmerOffset: CGFloat = -200
    let eventCount: Int

    init(eventCount: Int = 5) {
        self.eventCount = eventCount
    }

    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(spacing: 20) {
                // Filter chips skeleton
                filterChipsSkeleton

                // Event cards
                ForEach(0..<eventCount, id: \.self) { index in
                    eventCardSkeleton
                        .opacity(1.0 - (Double(index) * 0.1))
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 16)
        }
        .onAppear {
            startShimmer()
        }
    }

    // MARK: - Skeleton Components

    private var filterChipsSkeleton: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ForEach(0..<4, id: \.self) { _ in
                    SkeletonView(width: 80, height: 32, cornerRadius: 16)
                }
            }
        }
        .padding(.vertical, 8)
    }

    private var eventCardSkeleton: some View {
        VStack(spacing: 16) {
            // Header with icon and status
            HStack(spacing: 16) {
                // Event icon
                ZStack {
                    Circle()
                        .fill(skeletonBaseColor)
                        .frame(width: 50, height: 50)
                        .overlay(shimmerOverlay.clipShape(Circle()))
                }

                VStack(alignment: .leading, spacing: 8) {
                    SkeletonView(width: 180, height: 20, cornerRadius: 6)
                    SkeletonView(width: 140, height: 14, cornerRadius: 4)
                }

                Spacer()

                // Status badge
                SkeletonView(width: 60, height: 24, cornerRadius: 12)
            }

            // Description
            VStack(spacing: 6) {
                HStack {
                    SkeletonView(height: 14, cornerRadius: 4)
                    Spacer()
                }
                HStack {
                    SkeletonView(width: 200, height: 14, cornerRadius: 4)
                    Spacer()
                }
            }

            // Action buttons
            HStack(spacing: 12) {
                SkeletonView(width: 120, height: 40, cornerRadius: 20)
                SkeletonView(width: 80, height: 40, cornerRadius: 20)
                Spacer()
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Color.dynamicSurface(theme: themeManager.currentTheme))
                .overlay(shimmerOverlay.clipShape(RoundedRectangle(cornerRadius: 20)))
        )
    }

    // MARK: - Shimmer Effect

    private var shimmerOverlay: some View {
        LinearGradient(
            colors: [
                Color.clear,
                Color.white.opacity(themeManager.currentTheme == .dark ? 0.1 : 0.2),
                Color.clear
            ],
            startPoint: .leading,
            endPoint: .trailing
        )
        .offset(x: shimmerOffset)
    }

    private var skeletonBaseColor: Color {
        themeManager.currentTheme == .dark
            ? Color.gray.opacity(0.3)
            : Color.gray.opacity(0.2)
    }

    private func startShimmer() {
        withAnimation(
            .linear(duration: 1.5)
            .repeatForever(autoreverses: false)
        ) {
            shimmerOffset = 400
        }
    }
}

/// Skeleton compacto para un evento individual (vista previa)
struct CompactEventSkeleton: View {
    @EnvironmentObject var themeManager: ThemeManager
    @State private var shimmerOffset: CGFloat = -200

    var body: some View {
        HStack(spacing: 16) {
            // Date badge
            VStack(spacing: 4) {
                SkeletonView(width: 40, height: 16, cornerRadius: 4)
                SkeletonView(width: 30, height: 20, cornerRadius: 4)
            }
            .frame(width: 60, height: 60)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(skeletonBaseColor)
            )

            // Event info
            VStack(alignment: .leading, spacing: 8) {
                SkeletonView(width: 160, height: 18, cornerRadius: 5)
                HStack(spacing: 8) {
                    SkeletonView(width: 70, height: 12, cornerRadius: 3)
                    Circle()
                        .fill(skeletonBaseColor)
                        .frame(width: 4, height: 4)
                    SkeletonView(width: 50, height: 12, cornerRadius: 3)
                }
            }

            Spacer()

            // Arrow
            Image(systemName: "chevron.right")
                .foregroundColor(Color.dynamicTextSecondary(theme: themeManager.currentTheme).opacity(0.3))
                .font(.system(size: 14, weight: .semibold))
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.dynamicSurface(theme: themeManager.currentTheme))
                .overlay(shimmerOverlay.clipShape(RoundedRectangle(cornerRadius: 16)))
        )
        .onAppear {
            startShimmer()
        }
    }

    private var shimmerOverlay: some View {
        LinearGradient(
            colors: [
                Color.clear,
                Color.white.opacity(themeManager.currentTheme == .dark ? 0.1 : 0.2),
                Color.clear
            ],
            startPoint: .leading,
            endPoint: .trailing
        )
        .offset(x: shimmerOffset)
    }

    private var skeletonBaseColor: Color {
        themeManager.currentTheme == .dark
            ? Color.gray.opacity(0.3)
            : Color.gray.opacity(0.2)
    }

    private func startShimmer() {
        withAnimation(
            .linear(duration: 1.5)
            .repeatForever(autoreverses: false)
        ) {
            shimmerOffset = 200
        }
    }
}

#Preview {
    VStack {
        Text("Event List Skeleton")
            .font(.title2)
            .padding()

        EventListSkeleton(eventCount: 3)
    }
    .environmentObject(ThemeManager())
    .background(Color.dynamicBackground(theme: .dark))
}
