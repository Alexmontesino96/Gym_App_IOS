import SwiftUI

// MARK: - Quick Actions Grid
/// 4-column grid matching prototype: Community, Planes, Scan meal, Mi QR
struct QuickActionsGrid: View {
    let onCommunity: () -> Void
    let onPlans: () -> Void
    let onScanMeal: () -> Void
    let onMyQR: () -> Void

    @EnvironmentObject var themeManager: ThemeManager

    private var actions: [(icon: String, label: String, action: () -> Void)] {
        [
            ("square.grid.2x2", "Community", onCommunity),
            ("fork.knife", "Planes", onPlans),
            ("camera.fill", "Escanear", onScanMeal),
            ("qrcode", "Mi QR", onMyQR),
        ]
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Section label
            Text("ACCIONES RÁPIDAS")
                .font(.system(size: 9, weight: .bold))
                .tracking(1.0)
                .foregroundColor(Color.dynamicText(theme: themeManager.currentTheme).opacity(0.5))

            // Grid
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 4), spacing: 8) {
                ForEach(Array(actions.enumerated()), id: \.offset) { _, action in
                    Button(action: {
                        HapticManager.shared.buttonTap()
                        action.action()
                    }) {
                        VStack(spacing: 8) {
                            // Icon container
                            Image(systemName: action.icon)
                                .font(.system(size: 18))
                                .foregroundColor(Color.dynamicText(theme: themeManager.currentTheme))
                                .frame(width: 36, height: 36)
                                .background(Color.dynamicSurface2(theme: themeManager.currentTheme))
                                .clipShape(RoundedRectangle(cornerRadius: 12))

                            // Label
                            Text(action.label)
                                .font(.system(size: 11, weight: .medium))
                                .foregroundColor(Color.dynamicText(theme: themeManager.currentTheme))
                                .multilineTextAlignment(.center)
                                .lineLimit(2)
                                .lineSpacing(1)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .padding(.horizontal, 8)
                        .background(Color.dynamicSurface(theme: themeManager.currentTheme))
                        .clipShape(RoundedRectangle(cornerRadius: 22))
                        .overlay(
                            RoundedRectangle(cornerRadius: 22)
                                .stroke(Color.white.opacity(0.08), lineWidth: 1)
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
}
