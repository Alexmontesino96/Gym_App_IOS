import SwiftUI

// MARK: - Live Widgets Section
/// Exact replica of LiveWidgets from GymApp prototype:
/// 1. Pulse hero card (big count + zone bar + legend)
/// 2. Row of 2: Hot class + Live plan
/// 3. Activity ticker (rotating insight with dots)
struct LiveWidgetsSection: View {
    @EnvironmentObject var activityService: ActivityService
    @EnvironmentObject var themeManager: ThemeManager
    @EnvironmentObject var classService: ClassService

    @State private var insightIndex = 0
    @State private var pulseOpacity: Double = 1.0
    @State private var fallbackCount = Int.random(in: 15...35)
    @State private var showNutritionPlan = false
    @StateObject private var nutritionService = NutritionService.shared

    // Zone colors — exact from prototype
    private let zoneColorMap: [String: Color] = [
        "Strength": Color(hex: "#3B82F6")!,
        "Cardio": Color(hex: "#FF5A1F")!,
        "HIIT": Color(hex: "#D4FF3F")!,
        "Yoga": Color(hex: "#A78BFA")!,
        "Fuerza": Color(hex: "#3B82F6")!,
        "Funcional": Color(hex: "#4ADE80")!,
        "CrossFit": Color(hex: "#FF5A1F")!,
        "Pilates": Color(hex: "#A78BFA")!,
        "Boxing": Color(hex: "#FF5A1F")!,
        "Spinning": Color(hex: "#3B82F6")!,
    ]

    /// Displayed count: real data when available, fallback that fluctuates when 0
    private var displayCount: Int {
        activityService.totalTraining > 0 ? activityService.totalTraining : fallbackCount
    }

    private var zones: [(name: String, count: Int, color: Color)] {
        guard let byArea = activityService.realtimeStats?.byArea, !byArea.isEmpty else {
            // Fallback zones when no real data
            return [
                ("Strength", 9, Color(hex: "#3B82F6")!),
                ("Cardio", 7, Color(hex: "#FF5A1F")!),
                ("HIIT", 4, Color(hex: "#D4FF3F")!),
                ("Yoga", 3, Color(hex: "#A78BFA")!),
            ]
        }
        return byArea
            .sorted { $0.value > $1.value }
            .map { (name: $0.key, count: $0.value, color: zoneColorMap[$0.key] ?? Color(hex: "#D4FF3F")!) }
    }

    /// Hottest class: most booked, not full yet
    private var hotClass: GymClass? {
        let now = Date()
        return classService.classes
            .filter { $0.startTime > now && $0.currentParticipants < $0.maxParticipants }
            .sorted { $0.currentParticipants > $1.currentParticipants }
            .first
    }

    var body: some View {
        VStack(spacing: 10) {
            // 1. Pulse Hero Card
            pulseHeroCard

            // 2. Row of 2: Hot class + Live plan
            hotClassAndPlanRow

            // 3. Activity Ticker
            if !activityService.insights.isEmpty {
                insightTicker
            }
        }
        .onAppear {
            startPulseAnimation()
            startInsightRotation()
            startFallbackTimer()
        }
        .navigationDestination(isPresented: $showNutritionPlan) {
            NutritionPlanView()
                .environmentObject(themeManager)
                .environmentObject(NutritionService.shared)
        }
    }

    // ====================================================
    // MARK: - 1. PULSE HERO CARD
    // ====================================================

    private var pulseHeroCard: some View {
        Button(action: { HapticManager.shared.buttonTap() }) {
            ZStack(alignment: .topTrailing) {
                // Decorative glow — top right
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [
                                Color(hex: "#D4FF3F")!.opacity(0.12),
                                .clear
                            ],
                            center: UnitPoint(x: 1, y: 0),
                            startRadius: 0,
                            endRadius: 120
                        )
                    )
                    .frame(width: 200, height: 200)
                    .offset(x: 60, y: -60)

                VStack(alignment: .leading, spacing: 0) {
                    // — Header row: [dot + EN VIVO] ... [Pulso del gym]
                    HStack(alignment: .center) {
                        HStack(spacing: 8) {
                            // Pulsing dot: 8x8, accent, boxShadow glow
                            ZStack {
                                Circle()
                                    .fill(Color(hex: "#D4FF3F")!.opacity(0.25))
                                    .frame(width: 16, height: 16)
                                Circle()
                                    .fill(Color(hex: "#D4FF3F")!)
                                    .frame(width: 8, height: 8)
                                    .opacity(pulseOpacity)
                            }

                            // "EN VIVO" — t-micro: 11px, 600, 0.14em, uppercase, accent
                            Text("EN VIVO")
                                .font(.system(size: 11, weight: .semibold))
                                .tracking(1.5) // ≈ 0.14em
                                .foregroundColor(Color(hex: "#D4FF3F")!)
                        }

                        Spacer()

                        // "Pulso del gym" — t-small override: 11px, 400, ink-2
                        Text("Pulso del gym")
                            .font(.system(size: 11, weight: .regular))
                            .foregroundColor(Color(hex: "#C4C4C0")!)
                    }
                    .padding(.bottom, 16)

                    // — Big number row: 64px mono + "entrenando ahora"
                    HStack(alignment: .firstTextBaseline, spacing: 16) {
                        Text("\(displayCount)")
                            .font(.system(size: 64, weight: .bold, design: .monospaced))
                            .tracking(-3.2) // -0.05em
                            .monospacedDigit()
                            .foregroundColor(Color(hex: "#F5F5F0")!)
                            .contentTransition(.numericText())
                            .animation(.easeInOut(duration: 0.4), value: displayCount)

                        Text("entrenando\nahora")
                            .font(.system(size: 15, weight: .medium))
                            .lineSpacing(2) // line-height 1.2 approx
                            .foregroundColor(Color(hex: "#C4C4C0")!)
                            .frame(maxWidth: 100, alignment: .leading)
                    }
                    .padding(.bottom, 14)

                    // — Zone segmented bar: height 6, radius 100, gap 2
                    GeometryReader { geo in
                        let totalCount = zones.reduce(0) { $0 + $1.count }
                        HStack(spacing: 2) {
                            ForEach(Array(zones.enumerated()), id: \.offset) { _, zone in
                                RoundedRectangle(cornerRadius: 3)
                                    .fill(zone.color)
                                    .frame(width: totalCount > 0
                                           ? (geo.size.width - CGFloat(max(zones.count - 1, 0)) * 2) * CGFloat(zone.count) / CGFloat(totalCount)
                                           : 0)
                            }
                        }
                    }
                    .frame(height: 6)
                    .background(
                        Capsule().fill(Color(hex: "#232323")!)
                    )
                    .padding(.bottom, 12)

                    // — Zone legend: row, gap 14, wrap
                    HStack(spacing: 14) {
                        ForEach(Array(zones.enumerated()), id: \.offset) { _, zone in
                            HStack(spacing: 6) {
                                // Dot: 6x6
                                Circle()
                                    .fill(zone.color)
                                    .frame(width: 6, height: 6)
                                // Name: 11px, 500, ink-3
                                Text(zone.name)
                                    .font(.system(size: 11, weight: .medium))
                                    .foregroundColor(Color(hex: "#8A8A86")!)
                                // Count: 11px, 700, mono, ink
                                Text("\(zone.count)")
                                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                                    .foregroundColor(Color(hex: "#F5F5F0")!)
                            }
                        }
                    }
                }
                .padding(18)
            }
            // Card background: linear-gradient 180deg surface → bg-elev
            .background(
                LinearGradient(
                    colors: [Color(hex: "#1A1A1A")!, Color(hex: "#141414")!],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
            .clipShape(RoundedRectangle(cornerRadius: 22))
            .overlay(
                RoundedRectangle(cornerRadius: 22)
                    .stroke(Color.white.opacity(0.08), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    // ====================================================
    // MARK: - 2. HOT CLASS + LIVE PLAN ROW
    // ====================================================

    private var hotClassAndPlanRow: some View {
        HStack(spacing: 10) {
            // Left: Hot class card
            hotClassCard

            // Right: Live nutrition plan card
            livePlanCard
        }
    }

    // — Hot Class Card
    private var hotClassCard: some View {
        Button(action: {
            HapticManager.shared.buttonTap()
            NotificationCenter.default.post(name: .openClassesTab, object: nil)
        }) {
            VStack(alignment: .leading, spacing: 0) {
                // Header: flame + "CASI LLENO"
                HStack(spacing: 6) {
                    Image(systemName: "flame.fill")
                        .font(.system(size: 14))
                        .foregroundColor(Color(hex: "#FF5A1F")!)
                    Text("CASI LLENO")
                        .font(.system(size: 9, weight: .semibold))
                        .tracking(1.3) // 0.12em
                        .foregroundColor(Color(hex: "#FF5A1F")!)
                }
                .padding(.bottom, 12)

                // Class name: 14px, 500
                Text(hotClass?.name ?? "Spinning Power")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(Color(hex: "#F5F5F0")!)
                    .lineLimit(1)
                    .padding(.bottom, 4)

                // Time · category: 11px
                Text(hotClassSubtitle)
                    .font(.system(size: 11, weight: .regular))
                    .foregroundColor(Color(hex: "#C4C4C0")!)
                    .lineLimit(1)

                // Capacity bars + spots remaining
                HStack(alignment: .bottom, spacing: 0) {
                    // 10 bars
                    HStack(spacing: 3) {
                        ForEach(0..<10, id: \.self) { idx in
                            RoundedRectangle(cornerRadius: 1)
                                .fill(idx < hotClassFilledBars ? Color(hex: "#FF5A1F")! : Color(hex: "#232323")!)
                                .frame(height: 4)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.trailing, 8)

                    // Spots text: "X lugar(es)"
                    Text(hotClassSpotsText)
                        .font(.system(size: 11, weight: .bold, design: .monospaced))
                        .foregroundColor(Color(hex: "#F5F5F0")!)
                        .lineLimit(1)
                        .fixedSize()
                }
                .padding(.top, 12)
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            // bg: gradient 135deg surface → mix(#FF5A1F 6%, surface)
            .background(
                LinearGradient(
                    colors: [Color(hex: "#1A1A1A")!, Color(hex: "#1C1816")!],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .clipShape(RoundedRectangle(cornerRadius: 22))
            .overlay(
                RoundedRectangle(cornerRadius: 22)
                    .stroke(Color(hex: "#FF5A1F")!.opacity(0.25), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    // — Live Plan Card (connected to real data)
    private var activePlan: ActivePlan? {
        nutritionService.activePlans.first
    }

    private var livePlanTitle: String {
        if let plan = activePlan {
            return "\(plan.planName) · \(planDurationLabel)"
        }
        if let plan = nutritionService.currentPlan {
            return "\(plan.title) · \(plan.durationDays)d"
        }
        return "Sin plan activo"
    }

    private var livePlanDay: Int {
        activePlan?.currentDay ?? nutritionService.currentPlan?.currentDay ?? 0
    }

    private var livePlanTotalDays: Int {
        nutritionService.currentPlan?.durationDays ?? 28
    }

    private var planDurationLabel: String {
        "\(livePlanTotalDays)d"
    }

    private var hasActivePlan: Bool {
        activePlan != nil || nutritionService.currentPlan != nil
    }

    private var livePlanCard: some View {
        Button(action: {
            HapticManager.shared.buttonTap()
            showNutritionPlan = true
        }) {
            ZStack(alignment: .topTrailing) {
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [Color(hex: "#D4FF3F")!.opacity(0.35), .clear],
                            center: .center,
                            startRadius: 0,
                            endRadius: 50
                        )
                    )
                    .frame(width: 100, height: 100)
                    .offset(x: 30, y: -30)

                VStack(alignment: .leading, spacing: 0) {
                    HStack(spacing: 6) {
                        Circle()
                            .fill(Color(hex: "#D4FF3F")!)
                            .frame(width: 6, height: 6)
                            .opacity(pulseOpacity)
                        Text(hasActivePlan ? "PLAN EN VIVO" : "NUTRICIÓN")
                            .font(.system(size: 9, weight: .semibold))
                            .tracking(1.3)
                            .foregroundColor(Color(hex: "#D4FF3F")!)
                    }
                    .padding(.bottom, 12)

                    Text(livePlanTitle)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(Color(hex: "#FAFAF7")!)
                        .lineLimit(1)
                        .padding(.bottom, 4)

                    Text(hasActivePlan ? "Nuevo día publicado" : "Explora planes")
                        .font(.system(size: 11, weight: .regular))
                        .foregroundColor(Color(hex: "#FAFAF7")!.opacity(0.65))

                    HStack(alignment: .firstTextBaseline) {
                        if hasActivePlan {
                            HStack(alignment: .firstTextBaseline, spacing: 4) {
                                Text("\(livePlanDay)")
                                    .font(.system(size: 22, weight: .bold, design: .monospaced))
                                    .tracking(-0.4)
                                    .foregroundColor(Color(hex: "#D4FF3F")!)
                                Text("/\(livePlanTotalDays)")
                                    .font(.system(size: 11, weight: .regular, design: .monospaced))
                                    .foregroundColor(Color(hex: "#FAFAF7")!.opacity(0.5))
                            }
                        }
                        Spacer()
                        Image(systemName: "arrow.right")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(Color(hex: "#D4FF3F")!)
                    }
                    .padding(.top, 12)
                }
                .padding(14)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                LinearGradient(
                    colors: [Color(hex: "#14140F")!, Color(hex: "#1A1A14")!],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .clipShape(RoundedRectangle(cornerRadius: 22))
            .overlay(
                RoundedRectangle(cornerRadius: 22)
                    .stroke(Color.white.opacity(0.08), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    // ====================================================
    // MARK: - 3. ACTIVITY TICKER
    // ====================================================

    private var insightTicker: some View {
        let safeIndex = insightIndex % max(activityService.insights.count, 1)
        let insight = activityService.insights.indices.contains(safeIndex)
            ? activityService.insights[safeIndex]
            : activityService.insights.first!

        return HStack(spacing: 12) {
            // Icon box: 32x32, radius 10, bg color 14%, icon 16px
            Image(systemName: insightIcon(for: insight.type))
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(insightColor(for: insight.type))
                .frame(width: 32, height: 32)
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .fill(insightColor(for: insight.type).opacity(0.14))
                )

            // Rotating text: 13px, 500, ink, -0.005em
            Text(insight.message)
                .font(.system(size: 13, weight: .medium))
                .tracking(-0.07) // -0.005em approx
                .foregroundColor(Color(hex: "#F5F5F0")!)
                .lineLimit(1)
                .frame(maxWidth: .infinity, alignment: .leading)
                .id("insight_\(safeIndex)")
                .transition(.asymmetric(
                    insertion: .move(edge: .bottom).combined(with: .opacity),
                    removal: .move(edge: .top).combined(with: .opacity)
                ))

            // Dots: gap 3, active=12x4 ink, inactive=4x4 surface-2
            HStack(spacing: 3) {
                ForEach(0..<min(activityService.insights.count, 4), id: \.self) { i in
                    RoundedRectangle(cornerRadius: 100)
                        .fill(i == safeIndex % min(activityService.insights.count, 4)
                              ? Color(hex: "#F5F5F0")!
                              : Color(hex: "#232323")!)
                        .frame(
                            width: i == safeIndex % min(activityService.insights.count, 4) ? 12 : 4,
                            height: 4
                        )
                        .animation(.easeOut(duration: 0.3), value: safeIndex)
                }
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(Color(hex: "#1A1A1A")!)
        .clipShape(RoundedRectangle(cornerRadius: 22))
        .overlay(
            RoundedRectangle(cornerRadius: 22)
                .stroke(Color.white.opacity(0.08), lineWidth: 1)
        )
    }

    // ====================================================
    // MARK: - Computed helpers
    // ====================================================

    private var hotClassSubtitle: String {
        guard let c = hotClass else { return "18:30 · Cycling" }
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return "\(formatter.string(from: c.startTime)) · \(c.name.components(separatedBy: " ").first ?? "")"
    }

    private var hotClassFilledBars: Int {
        guard let c = hotClass, c.maxParticipants > 0 else { return 9 }
        return min(Int(Double(c.currentParticipants) / Double(c.maxParticipants) * 10), 10)
    }

    private var hotClassSpotsText: String {
        guard let c = hotClass else { return "1 lugar" }
        let spots = c.maxParticipants - c.currentParticipants
        return "\(spots) \(spots == 1 ? "lugar" : "lugares")"
    }

    private func insightIcon(for type: String) -> String {
        switch type.lowercased() {
        case "realtime": return "flame.fill"
        case "record": return "medal.fill"
        case "achievement": return "star.fill"
        case "consistency": return "flame.fill"
        case "collective": return "chart.bar.fill"
        default: return "sparkles"
        }
    }

    private func insightColor(for type: String) -> Color {
        switch type.lowercased() {
        case "realtime": return Color(hex: "#FF5A1F")!
        case "record": return Color(hex: "#D4FF3F")!
        case "achievement": return Color(hex: "#FFB347")!
        case "consistency": return Color(hex: "#FF5A1F")!
        case "collective": return Color(hex: "#A78BFA")!
        default: return Color(hex: "#D4FF3F")!
        }
    }

    // ====================================================
    // MARK: - Timers
    // ====================================================

    /// Pulse dot: opacity 1→0.5→1, 1.4s, infinite
    private func startPulseAnimation() {
        withAnimation(
            .easeInOut(duration: 1.4)
            .repeatForever(autoreverses: true)
        ) {
            pulseOpacity = 0.5
        }
    }

    /// Fallback count: fluctuates ±1 every 2.8s between 15-35
    private func startFallbackTimer() {
        guard activityService.totalTraining == 0 else { return }
        Timer.scheduledTimer(withTimeInterval: 2.8, repeats: true) { _ in
            guard activityService.totalTraining == 0 else { return }
            withAnimation(.easeInOut(duration: 0.4)) {
                let delta = Bool.random() ? 1 : -1
                fallbackCount = max(15, min(35, fallbackCount + delta))
            }
        }
    }

    /// Insight rotation: every 3.2s
    private func startInsightRotation() {
        guard !activityService.insights.isEmpty else { return }
        Timer.scheduledTimer(withTimeInterval: 3.2, repeats: true) { _ in
            withAnimation(.easeInOut(duration: 0.35)) {
                insightIndex = (insightIndex + 1) % max(activityService.insights.count, 1)
            }
        }
    }
}
