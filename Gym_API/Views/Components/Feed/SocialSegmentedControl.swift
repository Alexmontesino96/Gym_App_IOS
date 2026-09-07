import SwiftUI

// MARK: - Social Tab Enum

enum SocialTab: String, CaseIterable {
    case feed
    case chats
}

// MARK: - SocialSegmentedControl
/// Segmented control with sliding indicator matching prototype:
/// Grid 2 cols, surface bg, ink sliding indicator, badges

struct SocialSegmentedControl: View {
    @Binding var activeTab: SocialTab
    let unreadCount: Int
    let hasNewStories: Bool

    @EnvironmentObject var themeManager: ThemeManager
    @Namespace private var animation

    var body: some View {
        HStack(spacing: 0) {
            // Feed tab
            tabButton(
                tab: .feed,
                icon: "square.grid.2x2",
                label: "Feed",
                badge: hasNewStoriesBadge
            )

            // Chats tab
            tabButton(
                tab: .chats,
                icon: "bubble.left.and.bubble.right",
                label: "Chats",
                badge: unreadBadge
            )
        }
        .padding(3)
        .background(Color.dynamicSurface(theme: themeManager.currentTheme))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.white.opacity(0.08), lineWidth: 1)
        )
        .padding(.horizontal, 20)
    }

    // MARK: - Tab Button

    private func tabButton(tab: SocialTab, icon: String, label: String, badge: AnyView) -> some View {
        Button(action: {
            withAnimation(.spring(response: 0.25, dampingFraction: 0.85)) {
                activeTab = tab
            }
        }) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 14))

                Text(label)
                    .font(.system(size: 13, weight: .semibold))
                    .tracking(-0.06)

                badge
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .foregroundColor(
                activeTab == tab
                    ? Color.dynamicBackground(theme: themeManager.currentTheme)
                    : Color.dynamicText(theme: themeManager.currentTheme).opacity(0.6)
            )
            .background(
                ZStack {
                    if activeTab == tab {
                        RoundedRectangle(cornerRadius: 9)
                            .fill(Color.dynamicText(theme: themeManager.currentTheme))
                            .matchedGeometryEffect(id: "tab_indicator", in: animation)
                    }
                }
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Badges

    private var hasNewStoriesBadge: AnyView {
        if hasNewStories && activeTab != .feed {
            return AnyView(
                Circle()
                    .fill(Color(hex: "#D4FF3F")!)
                    .frame(width: 6, height: 6)
            )
        }
        return AnyView(EmptyView())
    }

    private var unreadBadge: AnyView {
        if unreadCount > 0 && activeTab != .chats {
            return AnyView(
                Text("\(unreadCount)")
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .foregroundColor(Color.accentInk)
                    .frame(minWidth: 18, minHeight: 16)
                    .padding(.horizontal, 5)
                    .background(Color(hex: "#D4FF3F")!)
                    .clipShape(Capsule())
            )
        }
        return AnyView(EmptyView())
    }
}
