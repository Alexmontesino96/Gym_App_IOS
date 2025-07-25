import SwiftUI

struct QuickAccessGrid: View {
    @EnvironmentObject var themeManager: ThemeManager
    
    var items: [QuickAccessItem] {
        [
            QuickAccessItem(icon: "message", title: "Chat", color: Color.dynamicAccent(theme: themeManager.currentTheme)),
            QuickAccessItem(icon: "fork.knife", title: "Nutrition", color: Color.dynamicAccent(theme: themeManager.currentTheme)),
            QuickAccessItem(icon: "calendar", title: "Calendar", color: Color.dynamicAccent(theme: themeManager.currentTheme)),
            QuickAccessItem(icon: "chart.line.uptrend.xyaxis", title: "Progress", color: Color.dynamicAccent(theme: themeManager.currentTheme))
        ]
    }
    
    var body: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 16), count: 2), spacing: 16) {
            ForEach(items, id: \.title) { item in
                QuickAccessButton(item: item)
            }
        }
    }
}

struct QuickAccessButton: View {
    @EnvironmentObject var themeManager: ThemeManager
    let item: QuickAccessItem
    
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: item.icon)
                .font(.system(size: 24))
                .foregroundColor(item.color)
                .frame(width: 48, height: 48)
                .background(item.color.opacity(0.2))
                .clipShape(Circle())
            
            Text(item.title)
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(Color.dynamicText(theme: themeManager.currentTheme))
        }
    }
}

struct QuickAccessItem {
    let icon: String
    let title: String
    let color: Color
}

#Preview {
    QuickAccessGrid()
        .environmentObject(ThemeManager())
}