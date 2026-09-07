import SwiftUI

// MARK: - EventCategoryFilter
/// Horizontal scroll pills for filtering events by category
struct EventCategoryFilter: View {
    @Binding var selectedCategory: EventCategory?
    @EnvironmentObject var themeManager: ThemeManager

    private let categories: [EventCategory?] = [nil] + EventCategory.allCases.filter { $0 != .other }

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(Array(categories.enumerated()), id: \.offset) { _, cat in
                    filterPill(category: cat)
                }
            }
            .padding(.horizontal, 20)
        }
    }

    private func filterPill(category: EventCategory?) -> some View {
        let isActive = selectedCategory == category

        return Button(action: {
            HapticManager.shared.buttonTap()
            withAnimation(.easeInOut(duration: 0.2)) {
                selectedCategory = category
            }
        }) {
            Text(category?.filterLabel ?? "Todos")
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(
                    isActive
                        ? Color.dynamicBackground(theme: themeManager.currentTheme)
                        : Color.dynamicText(theme: themeManager.currentTheme).opacity(0.7)
                )
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(
                    isActive
                        ? Color.dynamicText(theme: themeManager.currentTheme)
                        : Color.dynamicSurface(theme: themeManager.currentTheme)
                )
                .clipShape(Capsule())
                .overlay(
                    Capsule()
                        .stroke(
                            isActive ? Color.clear : Color.white.opacity(0.08),
                            lineWidth: 1
                        )
                )
        }
        .buttonStyle(.plain)
    }
}
