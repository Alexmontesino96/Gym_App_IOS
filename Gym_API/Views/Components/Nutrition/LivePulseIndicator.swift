import SwiftUI

// MARK: - LivePulseIndicator

/// Indicador de pulso animado para elementos "LIVE"
/// Muestra un circulo con efecto de pulso para indicar actividad en tiempo real
struct LivePulseIndicator: View {
    // MARK: - Properties

    let size: CGFloat
    let color: Color

    @State private var isPulsing = false

    // MARK: - Initialization

    init(size: CGFloat = 12, color: Color = .red) {
        self.size = size
        self.color = color
    }

    // MARK: - Body

    var body: some View {
        ZStack {
            // Circulo exterior animado (pulso)
            Circle()
                .stroke(color, lineWidth: 2)
                .frame(width: size * 1.67, height: size * 1.67)
                .scaleEffect(isPulsing ? 1.5 : 1.0)
                .opacity(isPulsing ? 0.0 : 0.6)

            // Circulo interior solido
            Circle()
                .fill(color)
                .frame(width: size, height: size)
        }
        .onAppear {
            withAnimation(
                .easeInOut(duration: 1.5)
                .repeatForever(autoreverses: false)
            ) {
                isPulsing = true
            }
        }
    }
}

// MARK: - LiveBadge

/// Badge completo con indicador LIVE y texto
struct LiveBadge: View {
    @EnvironmentObject var themeManager: ThemeManager

    let showText: Bool
    let size: LiveBadgeSize

    enum LiveBadgeSize {
        case small
        case medium
        case large

        var indicatorSize: CGFloat {
            switch self {
            case .small: return 8
            case .medium: return 10
            case .large: return 12
            }
        }

        var fontSize: CGFloat {
            switch self {
            case .small: return 10
            case .medium: return 12
            case .large: return 14
            }
        }

        var horizontalPadding: CGFloat {
            switch self {
            case .small: return 8
            case .medium: return 10
            case .large: return 12
            }
        }

        var verticalPadding: CGFloat {
            switch self {
            case .small: return 4
            case .medium: return 6
            case .large: return 8
            }
        }
    }

    init(showText: Bool = true, size: LiveBadgeSize = .medium) {
        self.showText = showText
        self.size = size
    }

    var body: some View {
        HStack(spacing: 6) {
            LivePulseIndicator(size: size.indicatorSize)

            if showText {
                Text("LIVE")
                    .font(.system(size: size.fontSize, weight: .bold))
                    .foregroundColor(.red)
            }
        }
        .padding(.horizontal, size.horizontalPadding)
        .padding(.vertical, size.verticalPadding)
        .background(
            Capsule()
                .fill(Color.red.opacity(0.15))
        )
    }
}

// MARK: - PlanTypeBadge

/// Badge para mostrar el tipo de plan de nutricion
/// Soporta modo compacto para uso en grids y listas
struct PlanTypeBadge: View {
    let planType: PlanType
    var compact: Bool = false

    @EnvironmentObject var themeManager: ThemeManager

    var body: some View {
        HStack(spacing: compact ? 4 : 6) {
            switch planType {
            case .live:
                LivePulseIndicator(size: compact ? 6 : 8)
                Text("LIVE")
            case .template:
                Image(systemName: "doc.text")
                    .font(.system(size: compact ? 9 : 10))
                Text("FLEXIBLE")
            case .archived:
                Image(systemName: "archivebox")
                    .font(.system(size: compact ? 9 : 10))
                Text("ARCHIVED")
            }
        }
        .font(.system(size: compact ? 9 : 11, weight: .bold))
        .foregroundColor(badgeColor)
        .padding(.horizontal, compact ? 8 : 12)
        .padding(.vertical, compact ? 4 : 6)
        .background(
            Capsule()
                .fill(badgeColor.opacity(0.15))
        )
    }

    private var badgeColor: Color {
        switch planType {
        case .live: return .red
        case .template: return .blue
        case .archived: return .purple
        }
    }
}

// MARK: - Preview

#Preview {
    VStack(spacing: 20) {
        // Live Pulse Indicator
        HStack(spacing: 20) {
            LivePulseIndicator(size: 8)
            LivePulseIndicator(size: 12)
            LivePulseIndicator(size: 16, color: .green)
        }

        Divider()

        // Live Badge variations
        VStack(spacing: 12) {
            LiveBadge(size: .small)
            LiveBadge(size: .medium)
            LiveBadge(size: .large)
            LiveBadge(showText: false, size: .medium)
        }

        Divider()

        // Plan Type Badges
        VStack(spacing: 12) {
            PlanTypeBadge(planType: .live)
            PlanTypeBadge(planType: .template)
            PlanTypeBadge(planType: .archived)
        }
    }
    .padding()
    .background(Color.black)
    .environmentObject(ThemeManager())
}
