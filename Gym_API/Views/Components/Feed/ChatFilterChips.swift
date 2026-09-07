import SwiftUI

// MARK: - Chat Filter

enum ChatFilter: String, CaseIterable {
    case all
    case unread
    case groups
    case direct
    case teams

    var label: String {
        switch self {
        case .all: return "All"
        case .unread: return "Unread"
        case .groups: return "Groups"
        case .direct: return "Direct"
        case .teams: return "Teams"
        }
    }

    var icon: String {
        switch self {
        case .all: return "square.grid.2x2"
        case .unread: return "circle.fill"
        case .groups: return "person.2"
        case .direct: return "person"
        case .teams: return "crown"
        }
    }
}

// MARK: - ChatFilterChips
/// Horizontal scroll filter chips for chat list

struct ChatFilterChips: View {
    @Binding var activeFilter: ChatFilter
    let unreadCount: Int

    @EnvironmentObject var themeManager: ThemeManager

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ForEach(ChatFilter.allCases, id: \.self) { filter in
                    chipButton(filter: filter)
                }
            }
            .padding(.horizontal, 20)
        }
    }

    private func chipButton(filter: ChatFilter) -> some View {
        let isActive = activeFilter == filter

        return Button(action: {
            withAnimation(.easeInOut(duration: 0.2)) {
                activeFilter = filter
            }
        }) {
            HStack(spacing: 6) {
                if filter == .unread {
                    // Small dot instead of icon for "unread"
                    Circle()
                        .fill(isActive
                            ? Color.dynamicBackground(theme: themeManager.currentTheme)
                            : Color(hex: "#D4FF3F")!
                        )
                        .frame(width: 6, height: 6)
                } else {
                    Image(systemName: filter.icon)
                        .font(.system(size: 12))
                }

                Text(filter.label)
                    .font(.system(size: 12, weight: .medium))

                // Show count for unread filter
                if filter == .unread && unreadCount > 0 {
                    Text("\(unreadCount)")
                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                        .foregroundColor(isActive
                            ? Color.dynamicBackground(theme: themeManager.currentTheme)
                            : Color(hex: "#D4FF3F")!
                        )
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .foregroundColor(
                isActive
                    ? Color.dynamicBackground(theme: themeManager.currentTheme)
                    : Color.dynamicText(theme: themeManager.currentTheme).opacity(0.6)
            )
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
