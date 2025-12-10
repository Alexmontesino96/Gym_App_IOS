import SwiftUI

/// Horizontal carousel showing gym rankings with profile photos
struct RankingsCarousel: View {
    @EnvironmentObject var activityService: ActivityService
    @EnvironmentObject var themeManager: ThemeManager

    @State private var selectedType: RankingType = .attendance
    @State private var selectedPeriod: RankingPeriod = .daily
    @State private var animateIn = false
    @State private var showFullRankings = false

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header with period selector
            headerView

            // Rankings content
            if activityService.isLoadingRankings && activityService.currentRankings.isEmpty {
                loadingView
            } else if activityService.currentRankings.isEmpty {
                emptyStateView
            } else {
                rankingsContent
            }
        }
        .opacity(animateIn ? 1 : 0)
        .offset(y: animateIn ? 0 : 20)
        .onAppear {
            withAnimation(.easeOut(duration: 0.5)) {
                animateIn = true
            }
        }
        .onChange(of: selectedType) { _, newType in
            Task {
                await activityService.fetchRankings(type: newType, period: selectedPeriod)
            }
        }
        .onChange(of: selectedPeriod) { _, newPeriod in
            Task {
                await activityService.fetchRankings(type: selectedType, period: newPeriod)
            }
        }
        .sheet(isPresented: $showFullRankings) {
            FullRankingsView(
                type: selectedType,
                period: selectedPeriod
            )
            .environmentObject(activityService)
            .environmentObject(themeManager)
        }
    }

    // MARK: - Header

    private var headerView: some View {
        VStack(spacing: 12) {
            HStack {
                HStack(spacing: 8) {
                    Image(systemName: "trophy.fill")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.yellow)

                    Text("RANKINGS")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(Color.dynamicTextSecondary(theme: themeManager.currentTheme))
                        .tracking(1)
                }

                Spacer()

                Button(action: {
                    HapticManager.shared.buttonTap()
                    showFullRankings = true
                }) {
                    Text("Ver todos")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(Color.dynamicAccent(theme: themeManager.currentTheme))
                }
            }

            // Period selector
            periodSelector
        }
    }

    // MARK: - Period Selector

    private var periodSelector: some View {
        HStack(spacing: 8) {
            ForEach(RankingPeriod.allCases, id: \.self) { period in
                Button(action: {
                    HapticManager.shared.buttonTap()
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                        selectedPeriod = period
                    }
                }) {
                    Text(period.displayName)
                        .font(.system(size: 12, weight: selectedPeriod == period ? .bold : .medium))
                        .foregroundColor(
                            selectedPeriod == period
                                ? .white
                                : Color.dynamicTextSecondary(theme: themeManager.currentTheme)
                        )
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(
                            Capsule()
                                .fill(
                                    selectedPeriod == period
                                        ? Color.dynamicAccent(theme: themeManager.currentTheme)
                                        : Color.dynamicSurface(theme: themeManager.currentTheme)
                                )
                        )
                }
                .buttonStyle(PlainButtonStyle())
            }

            Spacer()
        }
    }

    // MARK: - Rankings Content

    private var rankingsContent: some View {
        VStack(spacing: 12) {
            // Type cards carousel
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(RankingType.allCases, id: \.self) { type in
                        RankingTypeCard(
                            type: type,
                            isSelected: selectedType == type,
                            rankings: selectedType == type ? activityService.currentRankings : [],
                            unit: activityService.rankingsUnit,
                            theme: themeManager.currentTheme,
                            onTap: {
                                HapticManager.shared.buttonTap()
                                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                    selectedType = type
                                }
                            }
                        )
                    }
                }
                .padding(.horizontal, 4)
            }

            // Top 3 podium for selected type
            if !activityService.currentRankings.isEmpty {
                top3Podium
            }
        }
    }

    // MARK: - Top 3 Podium

    private var top3Podium: some View {
        HStack(spacing: 16) {
            ForEach(activityService.currentRankings.prefix(3), id: \.position) { entry in
                PodiumEntry(
                    entry: entry,
                    unit: activityService.rankingsUnit,
                    theme: themeManager.currentTheme
                )
            }
        }
        .padding(.top, 8)
    }

    // MARK: - Loading View

    private var loadingView: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ForEach(0..<3, id: \.self) { _ in
                    RankingCardSkeleton(theme: themeManager.currentTheme)
                }
            }
            .padding(.horizontal, 4)
        }
    }

    // MARK: - Empty State

    private var emptyStateView: some View {
        VStack(spacing: 12) {
            Image(systemName: "chart.bar.xaxis")
                .font(.system(size: 36, weight: .light))
                .foregroundColor(Color.dynamicTextSecondary(theme: themeManager.currentTheme).opacity(0.5))

            Text("Rankings no disponibles")
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(Color.dynamicTextSecondary(theme: themeManager.currentTheme))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 24)
    }
}

// MARK: - Ranking Type Card

struct RankingTypeCard: View {
    let type: RankingType
    let isSelected: Bool
    let rankings: [RankingEntry]
    let unit: String
    let theme: ThemeManager.AppTheme
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 12) {
                // Icon
                ZStack {
                    Circle()
                        .fill(typeColor.opacity(0.15))
                        .frame(width: 50, height: 50)

                    Image(systemName: type.icon)
                        .font(.system(size: 22, weight: .semibold))
                        .foregroundColor(typeColor)
                }

                // Type name
                Text(type.displayName)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(Color.dynamicText(theme: theme))

                // Leader preview (if selected and has data)
                if isSelected, let leader = rankings.first {
                    VStack(spacing: 4) {
                        // Avatar stack
                        avatarStack

                        Text(leader.displayName)
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(Color.dynamicTextSecondary(theme: theme))
                            .lineLimit(1)

                        Text("#1 • \(leader.value) \(unit)")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(typeColor)
                    }
                }
            }
            .frame(width: 120, height: isSelected ? 180 : 120)
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color.dynamicSurface(theme: theme))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(
                                isSelected ? typeColor : Color.clear,
                                lineWidth: 2
                            )
                    )
            )
            .shadow(
                color: isSelected ? typeColor.opacity(0.2) : Color.clear,
                radius: 8,
                x: 0,
                y: 4
            )
        }
        .buttonStyle(PlainButtonStyle())
    }

    private var avatarStack: some View {
        HStack(spacing: -8) {
            ForEach(rankings.prefix(3), id: \.position) { entry in
                if let userId = entry.userId {
                    AsyncImage(url: URL(string: "https://gymapi-eh6m.onrender.com/api/v1/users/\(userId)/profile-photo")) { image in
                        image
                            .resizable()
                            .scaledToFill()
                    } placeholder: {
                        Circle()
                            .fill(typeColor.opacity(0.3))
                            .overlay(
                                Text(String(entry.displayName.prefix(1)))
                                    .font(.system(size: 10, weight: .bold))
                                    .foregroundColor(.white)
                            )
                    }
                    .frame(width: 28, height: 28)
                    .clipShape(Circle())
                    .overlay(
                        Circle()
                            .stroke(Color.dynamicSurface(theme: theme), lineWidth: 2)
                    )
                } else {
                    Circle()
                        .fill(typeColor.opacity(0.3))
                        .frame(width: 28, height: 28)
                        .overlay(
                            Text(String(entry.displayName.prefix(1)))
                                .font(.system(size: 10, weight: .bold))
                                .foregroundColor(.white)
                        )
                        .overlay(
                            Circle()
                                .stroke(Color.dynamicSurface(theme: theme), lineWidth: 2)
                        )
                }
            }
        }
    }

    private var typeColor: Color {
        switch type {
        case .attendance: return .blue
        case .consistency: return .orange
        case .improvement: return .green
        case .activity: return .purple
        case .dedication: return .red
        }
    }
}

// MARK: - Podium Entry

struct PodiumEntry: View {
    let entry: RankingEntry
    let unit: String
    let theme: ThemeManager.AppTheme

    var body: some View {
        VStack(spacing: 8) {
            // Position medal
            ZStack {
                Circle()
                    .fill(medalColor)
                    .frame(width: 24, height: 24)

                Text("\(entry.position)")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(.white)
            }

            // Avatar
            if let userId = entry.userId {
                AsyncImage(url: URL(string: "https://gymapi-eh6m.onrender.com/api/v1/users/\(userId)/profile-photo")) { image in
                    image
                        .resizable()
                        .scaledToFill()
                } placeholder: {
                    avatarPlaceholder
                }
                .frame(width: 48, height: 48)
                .clipShape(Circle())
                .overlay(
                    Circle()
                        .stroke(medalColor, lineWidth: 2)
                )
            } else {
                avatarPlaceholder
                    .frame(width: 48, height: 48)
                    .overlay(
                        Circle()
                            .stroke(medalColor, lineWidth: 2)
                    )
            }

            // Name
            Text(entry.displayName)
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(Color.dynamicText(theme: theme))
                .lineLimit(1)

            // Value
            Text("\(entry.value) \(unit)")
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(Color.dynamicTextSecondary(theme: theme))
        }
        .frame(maxWidth: .infinity)
    }

    private var avatarPlaceholder: some View {
        Circle()
            .fill(
                LinearGradient(
                    gradient: Gradient(colors: [medalColor, medalColor.opacity(0.6)]),
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .overlay(
                Text(String(entry.displayName.prefix(1)).uppercased())
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(.white)
            )
    }

    private var medalColor: Color {
        switch entry.position {
        case 1: return Color(red: 1.0, green: 0.84, blue: 0.0) // Gold
        case 2: return Color(red: 0.75, green: 0.75, blue: 0.75) // Silver
        case 3: return Color(red: 0.8, green: 0.5, blue: 0.2) // Bronze
        default: return .gray
        }
    }
}

// MARK: - Ranking Card Skeleton

struct RankingCardSkeleton: View {
    let theme: ThemeManager.AppTheme
    @State private var isAnimating = false

    var body: some View {
        VStack(spacing: 12) {
            Circle()
                .fill(Color.dynamicSurface(theme: theme))
                .frame(width: 50, height: 50)

            RoundedRectangle(cornerRadius: 4)
                .fill(Color.dynamicSurface(theme: theme))
                .frame(width: 60, height: 14)
        }
        .frame(width: 120, height: 120)
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.dynamicSurface(theme: theme).opacity(0.5))
        )
        .opacity(isAnimating ? 0.5 : 1.0)
        .animation(
            .easeInOut(duration: 1.0).repeatForever(autoreverses: true),
            value: isAnimating
        )
        .onAppear {
            isAnimating = true
        }
    }
}

// MARK: - Full Rankings View (Sheet)

struct FullRankingsView: View {
    let type: RankingType
    let period: RankingPeriod

    @EnvironmentObject var activityService: ActivityService
    @EnvironmentObject var themeManager: ThemeManager
    @Environment(\.dismiss) var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(spacing: 12) {
                    ForEach(activityService.currentRankings, id: \.position) { entry in
                        FullRankingRow(
                            entry: entry,
                            unit: activityService.rankingsUnit,
                            theme: themeManager.currentTheme
                        )
                    }
                }
                .padding()
            }
            .background(Color.dynamicBackground(theme: themeManager.currentTheme))
            .navigationTitle("\(type.displayName) - \(period.displayName)")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Cerrar") {
                        dismiss()
                    }
                }
            }
        }
    }
}

struct FullRankingRow: View {
    let entry: RankingEntry
    let unit: String
    let theme: ThemeManager.AppTheme

    var body: some View {
        HStack(spacing: 16) {
            // Position
            ZStack {
                Circle()
                    .fill(positionColor)
                    .frame(width: 32, height: 32)

                Text("\(entry.position)")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(.white)
            }

            // Avatar
            if let userId = entry.userId {
                AsyncImage(url: URL(string: "https://gymapi-eh6m.onrender.com/api/v1/users/\(userId)/profile-photo")) { image in
                    image
                        .resizable()
                        .scaledToFill()
                } placeholder: {
                    avatarPlaceholder
                }
                .frame(width: 44, height: 44)
                .clipShape(Circle())
            } else {
                avatarPlaceholder
                    .frame(width: 44, height: 44)
            }

            // Name
            VStack(alignment: .leading, spacing: 2) {
                Text(entry.displayName)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(Color.dynamicText(theme: theme))

                Text("\(entry.value) \(unit)")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(Color.dynamicTextSecondary(theme: theme))
            }

            Spacer()
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.dynamicSurface(theme: theme))
        )
    }

    private var avatarPlaceholder: some View {
        Circle()
            .fill(positionColor.opacity(0.3))
            .overlay(
                Text(String(entry.displayName.prefix(1)).uppercased())
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(positionColor)
            )
    }

    private var positionColor: Color {
        switch entry.position {
        case 1: return Color(red: 1.0, green: 0.84, blue: 0.0)
        case 2: return Color(red: 0.75, green: 0.75, blue: 0.75)
        case 3: return Color(red: 0.8, green: 0.5, blue: 0.2)
        default: return .gray
        }
    }
}

// MARK: - Preview

#Preview {
    ScrollView {
        RankingsCarousel()
            .padding()
    }
    .background(Color.black)
    .withServiceContainer()
}
