import SwiftUI

struct ClassCard: View {
    @EnvironmentObject var themeManager: ThemeManager
    let title: String
    let time: String
    let instructor: String
    
    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: "figure.martial.arts")
                .font(.system(size: 24))
                .foregroundColor(Color.dynamicAccent(theme: themeManager.currentTheme))
                .frame(width: 40, height: 40)
                .background(Color.dynamicAccent(theme: themeManager.currentTheme).opacity(0.2))
                .clipShape(Circle())
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(Color.dynamicText(theme: themeManager.currentTheme))
                
                Text("\(time) con \(instructor)")
                    .font(.system(size: 14))
                    .foregroundColor(Color.dynamicTextSecondary(theme: themeManager.currentTheme))
            }
            
            Spacer()
            
            Image(systemName: "chevron.right")
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(Color.dynamicTextSecondary(theme: themeManager.currentTheme))
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.dynamicSurface(theme: themeManager.currentTheme))
        )
    }
}

#Preview {
    ClassCard(
        title: "Boxing Fundamentals",
        time: "6:00 PM",
        instructor: "Carlos Rodriguez"
    )
    .environmentObject(ThemeManager())
}