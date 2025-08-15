import SwiftUI

struct SectionHeaderView: View {
    let title: String
    let ctaTitle: String?
    let onTapCTA: (() -> Void)?
    let themeManager: ThemeManager
    
    init(title: String, ctaTitle: String? = nil, themeManager: ThemeManager, onTapCTA: (() -> Void)? = nil) {
        self.title = title
        self.ctaTitle = ctaTitle
        self.themeManager = themeManager
        self.onTapCTA = onTapCTA
    }
    
    var body: some View {
        HStack {
            Text(title)
                .font(.system(size: 20, weight: .semibold))
                .foregroundColor(Color.dynamicText(theme: themeManager.currentTheme))
                .minimumScaleFactor(0.9)
                .lineLimit(1)
            Spacer()
            if let ctaTitle = ctaTitle, let onTapCTA = onTapCTA {
                Button(action: onTapCTA) {
                    Text(LocalizedStringKey(ctaTitle))
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(Color.dynamicAccent(theme: themeManager.currentTheme))
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(LocalizedStringKey(ctaTitle))
            }
        }
    }
}

