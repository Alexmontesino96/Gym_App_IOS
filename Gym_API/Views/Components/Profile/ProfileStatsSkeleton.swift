import SwiftUI

/// Skeleton específico para las estadísticas del perfil en ModernProfileView
struct ProfileStatsSkeleton: View {
    @EnvironmentObject var themeManager: ThemeManager
    @State private var shimmerOffset: CGFloat = -200

    var body: some View {
        VStack(spacing: 24) {
            // Header with avatar
            profileHeaderSkeleton

            // Stats grid
            statsGridSkeleton

            // Progress section
            progressSectionSkeleton

            // Recent activity
            recentActivitySkeleton
        }
        .padding(.horizontal, 20)
        .onAppear {
            startShimmer()
        }
    }

    // MARK: - Skeleton Components

    private var profileHeaderSkeleton: some View {
        VStack(spacing: 16) {
            // Avatar
            Circle()
                .fill(skeletonBaseColor)
                .frame(width: 100, height: 100)
                .overlay(shimmerOverlay.clipShape(Circle()))

            // Name and email
            VStack(spacing: 8) {
                SkeletonView(width: 160, height: 24, cornerRadius: 8)
                SkeletonView(width: 120, height: 14, cornerRadius: 5)
            }

            // Bio
            VStack(spacing: 6) {
                SkeletonView(width: 280, height: 14, cornerRadius: 4)
                SkeletonView(width: 240, height: 14, cornerRadius: 4)
            }
        }
        .padding(.vertical, 20)
    }

    private var statsGridSkeleton: some View {
        LazyVGrid(columns: [
            GridItem(.flexible()),
            GridItem(.flexible())
        ], spacing: 16) {
            ForEach(0..<4, id: \.self) { _ in
                statCardSkeleton
            }
        }
    }

    private var statCardSkeleton: some View {
        VStack(spacing: 12) {
            // Icon
            Circle()
                .fill(skeletonBaseColor)
                .frame(width: 44, height: 44)
                .overlay(shimmerOverlay.clipShape(Circle()))

            // Value
            SkeletonView(width: 60, height: 28, cornerRadius: 8)

            // Label
            SkeletonView(width: 80, height: 14, cornerRadius: 4)
        }
        .frame(maxWidth: .infinity)
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.dynamicSurface(theme: themeManager.currentTheme))
                .overlay(shimmerOverlay.clipShape(RoundedRectangle(cornerRadius: 16)))
        )
    }

    private var progressSectionSkeleton: some View {
        VStack(spacing: 16) {
            HStack {
                SkeletonView(width: 140, height: 20, cornerRadius: 6)
                Spacer()
            }

            VStack(spacing: 12) {
                // Progress bar
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        SkeletonView(width: 100, height: 14, cornerRadius: 4)
                        Spacer()
                        SkeletonView(width: 40, height: 14, cornerRadius: 4)
                    }

                    // Progress track
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 8)
                            .fill(skeletonBaseColor)
                            .frame(height: 12)

                        RoundedRectangle(cornerRadius: 8)
                            .fill(skeletonBaseColor.opacity(0.6))
                            .frame(width: 120, height: 12)
                    }
                }

                // Another progress item
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        SkeletonView(width: 80, height: 14, cornerRadius: 4)
                        Spacer()
                        SkeletonView(width: 40, height: 14, cornerRadius: 4)
                    }

                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 8)
                            .fill(skeletonBaseColor)
                            .frame(height: 12)

                        RoundedRectangle(cornerRadius: 8)
                            .fill(skeletonBaseColor.opacity(0.6))
                            .frame(width: 80, height: 12)
                    }
                }
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color.dynamicSurface(theme: themeManager.currentTheme))
                    .overlay(shimmerOverlay.clipShape(RoundedRectangle(cornerRadius: 16)))
            )
        }
    }

    private var recentActivitySkeleton: some View {
        VStack(spacing: 16) {
            HStack {
                SkeletonView(width: 140, height: 20, cornerRadius: 6)
                Spacer()
                SkeletonView(width: 60, height: 16, cornerRadius: 5)
            }

            VStack(spacing: 12) {
                ForEach(0..<3, id: \.self) { _ in
                    activityItemSkeleton
                }
            }
        }
    }

    private var activityItemSkeleton: some View {
        HStack(spacing: 12) {
            // Activity icon
            Circle()
                .fill(skeletonBaseColor)
                .frame(width: 40, height: 40)

            // Activity info
            VStack(alignment: .leading, spacing: 6) {
                SkeletonView(width: 140, height: 16, cornerRadius: 4)
                SkeletonView(width: 100, height: 12, cornerRadius: 3)
            }

            Spacer()

            // Time
            SkeletonView(width: 50, height: 12, cornerRadius: 3)
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.dynamicSurface(theme: themeManager.currentTheme))
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

/// Skeleton compacto para métricas individuales
struct MetricSkeleton: View {
    @EnvironmentObject var themeManager: ThemeManager
    @State private var shimmerOffset: CGFloat = -100

    var body: some View {
        HStack(spacing: 12) {
            // Icon
            Circle()
                .fill(skeletonBaseColor)
                .frame(width: 36, height: 36)

            VStack(alignment: .leading, spacing: 4) {
                SkeletonView(width: 60, height: 20, cornerRadius: 5)
                SkeletonView(width: 80, height: 12, cornerRadius: 3)
            }

            Spacer()
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.dynamicSurface(theme: themeManager.currentTheme))
                .overlay(shimmerOverlay.clipShape(RoundedRectangle(cornerRadius: 12)))
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
    ScrollView {
        ProfileStatsSkeleton()
    }
    .environmentObject(ThemeManager())
    .background(Color.dynamicBackground(theme: .dark))
}
