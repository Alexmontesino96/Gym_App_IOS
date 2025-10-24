import SwiftUI

/// Skeleton específico para la lista de clases en ClassesView
struct ClassListSkeleton: View {
    @EnvironmentObject var themeManager: ThemeManager
    @State private var shimmerOffset: CGFloat = -200
    let classCount: Int

    init(classCount: Int = 6) {
        self.classCount = classCount
    }

    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(spacing: 16) {
                // Week selector skeleton
                weekSelectorSkeleton

                // Class cards
                ForEach(0..<classCount, id: \.self) { index in
                    classCardSkeleton
                        .opacity(1.0 - (Double(index) * 0.08))
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

    private var weekSelectorSkeleton: some View {
        HStack(spacing: 12) {
            ForEach(0..<7, id: \.self) { _ in
                VStack(spacing: 8) {
                    SkeletonView(width: 30, height: 12, cornerRadius: 4)
                    Circle()
                        .fill(skeletonBaseColor)
                        .frame(width: 44, height: 44)
                        .overlay(shimmerOverlay.clipShape(Circle()))
                }
            }
        }
        .padding(.vertical, 12)
    }

    private var classCardSkeleton: some View {
        HStack(spacing: 16) {
            // Time section
            VStack(alignment: .center, spacing: 4) {
                SkeletonView(width: 50, height: 16, cornerRadius: 4)
                SkeletonView(width: 40, height: 12, cornerRadius: 3)
            }
            .frame(width: 60)

            // Divider
            Rectangle()
                .fill(skeletonBaseColor)
                .frame(width: 1)

            // Class info
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    VStack(alignment: .leading, spacing: 6) {
                        SkeletonView(width: 150, height: 18, cornerRadius: 5)
                        SkeletonView(width: 100, height: 14, cornerRadius: 4)
                    }

                    Spacer()

                    // Capacity badge
                    SkeletonView(width: 60, height: 24, cornerRadius: 12)
                }

                HStack(spacing: 12) {
                    // Trainer avatar
                    Circle()
                        .fill(skeletonBaseColor)
                        .frame(width: 32, height: 32)

                    VStack(alignment: .leading, spacing: 4) {
                        SkeletonView(width: 80, height: 12, cornerRadius: 3)
                        SkeletonView(width: 60, height: 10, cornerRadius: 3)
                    }

                    Spacer()
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

/// Skeleton compacto para una clase individual (modo lista)
struct CompactClassSkeleton: View {
    @EnvironmentObject var themeManager: ThemeManager
    @State private var shimmerOffset: CGFloat = -200

    var body: some View {
        HStack(spacing: 12) {
            // Icon/Image
            RoundedRectangle(cornerRadius: 12)
                .fill(skeletonBaseColor)
                .frame(width: 60, height: 60)
                .overlay(shimmerOverlay.clipShape(RoundedRectangle(cornerRadius: 12)))

            // Info
            VStack(alignment: .leading, spacing: 8) {
                SkeletonView(width: 140, height: 16, cornerRadius: 4)
                HStack(spacing: 8) {
                    SkeletonView(width: 60, height: 12, cornerRadius: 3)
                    SkeletonView(width: 40, height: 12, cornerRadius: 3)
                }
            }

            Spacer()

            // Action button
            SkeletonView(width: 70, height: 32, cornerRadius: 16)
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.dynamicSurface(theme: themeManager.currentTheme))
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
        Text("Class List Skeleton")
            .font(.title2)
            .padding()

        ClassListSkeleton(classCount: 3)
    }
    .environmentObject(ThemeManager())
    .background(Color.dynamicBackground(theme: .dark))
}
