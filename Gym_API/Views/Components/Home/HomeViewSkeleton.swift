import SwiftUI

/// Skeleton específico para la vista Home durante la carga de datos
struct HomeViewSkeleton: View {
    @EnvironmentObject var themeManager: ThemeManager
    @State private var shimmerOffset: CGFloat = -200

    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(spacing: 20) {
                // Hero Section Skeleton
                heroSectionSkeleton

                // Streak Indicator Skeleton
                HStack {
                    streakSkeleton
                    Spacer()
                }
                .padding(.horizontal, 20)

                // Next Class Card Skeleton
                nextClassSkeleton

                // Quick Actions Skeleton
                quickActionsSkeleton

                // Featured Event Skeleton
                featuredEventSkeleton

                Spacer(minLength: 100)
            }
            .padding(.horizontal, 16)
        }
        .safeAreaPadding(.top, 16)
        .onAppear {
            startShimmer()
        }
    }

    // MARK: - Skeleton Components

    private var heroSectionSkeleton: some View {
        VStack(spacing: 20) {
            HStack(alignment: .top, spacing: 16) {
                VStack(alignment: .leading, spacing: 8) {
                    // Greeting skeleton
                    SkeletonView(width: 200, height: 28, cornerRadius: 8)

                    // Motivational question skeleton
                    SkeletonView(width: 160, height: 16, cornerRadius: 6)
                        .padding(.top, 4)
                }

                Spacer()

                // Avatar skeleton
                Circle()
                    .fill(skeletonBaseColor)
                    .frame(width: 80, height: 80)
                    .overlay(shimmerOverlay.clipShape(Circle()))
            }
        }
        .padding(.horizontal, 20)
    }

    private var streakSkeleton: some View {
        HStack(spacing: 10) {
            Circle()
                .fill(skeletonBaseColor)
                .frame(width: 16, height: 16)

            SkeletonView(width: 120, height: 14, cornerRadius: 8)
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 12)
        .background(
            Capsule()
                .fill(Color.dynamicSurface(theme: themeManager.currentTheme))
                .overlay(shimmerOverlay.clipShape(Capsule()))
        )
    }

    private var nextClassSkeleton: some View {
        VStack(spacing: 12) {
            HStack {
                SkeletonView(width: 120, height: 18, cornerRadius: 6)
                Spacer()
                SkeletonView(width: 60, height: 14, cornerRadius: 5)
            }

            HStack(spacing: 12) {
                // Icon
                RoundedRectangle(cornerRadius: 12)
                    .fill(skeletonBaseColor)
                    .frame(width: 50, height: 50)

                VStack(alignment: .leading, spacing: 8) {
                    SkeletonView(width: 150, height: 16, cornerRadius: 4)
                    SkeletonView(width: 100, height: 14, cornerRadius: 4)
                }

                Spacer()
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.dynamicSurface(theme: themeManager.currentTheme))
                .overlay(shimmerOverlay.clipShape(RoundedRectangle(cornerRadius: 16)))
        )
    }

    private var quickActionsSkeleton: some View {
        VStack(spacing: 12) {
            HStack {
                SkeletonView(width: 120, height: 18, cornerRadius: 6)
                Spacer()
            }

            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible()),
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 12) {
                ForEach(0..<4, id: \.self) { _ in
                    actionButtonSkeleton
                }
            }
        }
    }

    private var actionButtonSkeleton: some View {
        VStack(spacing: 8) {
            Circle()
                .fill(skeletonBaseColor)
                .frame(width: 60, height: 60)
                .overlay(shimmerOverlay.clipShape(Circle()))

            SkeletonView(width: 50, height: 12, cornerRadius: 4)
        }
    }

    private var featuredEventSkeleton: some View {
        VStack(spacing: 16) {
            HStack {
                SkeletonView(width: 140, height: 18, cornerRadius: 6)
                Spacer()
                SkeletonView(width: 60, height: 14, cornerRadius: 5)
            }

            VStack(spacing: 20) {
                HStack(spacing: 16) {
                    // Event icon
                    Circle()
                        .fill(skeletonBaseColor)
                        .frame(width: 50, height: 50)

                    VStack(alignment: .leading, spacing: 8) {
                        SkeletonView(width: 180, height: 20, cornerRadius: 6)
                        SkeletonView(width: 140, height: 14, cornerRadius: 4)
                    }

                    Spacer()

                    SkeletonView(width: 60, height: 24, cornerRadius: 12)
                }

                // Description
                VStack(spacing: 4) {
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
            .padding(24)
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(Color.dynamicSurface(theme: themeManager.currentTheme))
                    .overlay(shimmerOverlay.clipShape(RoundedRectangle(cornerRadius: 20)))
            )
        }
        .padding(.horizontal, 4)
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

#Preview {
    HomeViewSkeleton()
        .environmentObject(ThemeManager())
        .background(Color.dynamicBackground(theme: .dark))
}
