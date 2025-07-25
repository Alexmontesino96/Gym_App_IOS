import SwiftUI

struct ThemeSettingsView: View {
    @EnvironmentObject var themeManager: ThemeManager
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            VStack(spacing: 24) {
                // Header
                VStack(spacing: 8) {
                    Image(systemName: "paintbrush.fill")
                        .font(.system(size: 50))
                        .foregroundColor(Color.dynamicAccent(theme: themeManager.currentTheme))
                    
                    Text("Apariencia")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                        .foregroundColor(Color.dynamicText(theme: themeManager.currentTheme))
                    
                    Text("Elige el tema que prefieras")
                        .font(.subheadline)
                        .foregroundColor(Color.dynamicTextSecondary(theme: themeManager.currentTheme))
                }
                .padding(.top, 20)
                
                // Theme Options
                VStack(spacing: 16) {
                    ForEach(ThemeManager.AppTheme.allCases, id: \.self) { theme in
                        ThemeOptionCard(
                            theme: theme,
                            isSelected: themeManager.currentTheme == theme,
                            currentTheme: themeManager.currentTheme
                        ) {
                            withAnimation(.easeInOut(duration: 0.3)) {
                                themeManager.setTheme(theme)
                            }
                        }
                    }
                }
                .padding(.horizontal, 20)
                
                Spacer()
                
                // Quick Toggle Button
                Button(action: {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        themeManager.toggleTheme()
                    }
                }) {
                    HStack {
                        Image(systemName: themeManager.currentTheme == .dark ? "sun.max.fill" : "moon.fill")
                        Text("Cambiar a \(themeManager.currentTheme == .dark ? "Claro" : "Oscuro")")
                    }
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
                    .background(Color.dynamicAccent(theme: themeManager.currentTheme))
                    .cornerRadius(12)
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 30)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color.dynamicBackground(theme: themeManager.currentTheme))
            .navigationTitle("Tema")
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarBackButtonHidden(true)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Close") {
                        dismiss()
                    }
                    .foregroundColor(Color.dynamicAccent(theme: themeManager.currentTheme))
                }
            }
        }
    }
}

struct ThemeOptionCard: View {
    let theme: ThemeManager.AppTheme
    let isSelected: Bool
    let currentTheme: ThemeManager.AppTheme
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 16) {
                // Theme Preview
                VStack(spacing: 4) {
                    // Preview rectangles
                    HStack(spacing: 2) {
                        Rectangle()
                            .fill(theme == .light ? Color.lightBackgroundPrimary : Color.darkBackgroundPrimary)
                            .frame(width: 20, height: 20)
                            .cornerRadius(4)
                        
                        Rectangle()
                            .fill(theme == .light ? Color.lightSurfacePrimary : Color.darkSurfacePrimary)
                            .frame(width: 20, height: 20)
                            .cornerRadius(4)
                    }
                    
                    HStack(spacing: 2) {
                        Rectangle()
                            .fill(theme == .light ? Color.lightAccentPrimary : Color.darkAccentPrimary)
                            .frame(width: 20, height: 20)
                            .cornerRadius(4)
                        
                        Rectangle()
                            .fill(theme == .light ? Color.lightTextPrimary : Color.darkTextPrimary)
                            .frame(width: 20, height: 20)
                            .cornerRadius(4)
                    }
                }
                
                // Theme Info
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(theme.displayName)
                            .font(.headline)
                            .foregroundColor(Color.dynamicText(theme: currentTheme))
                        
                        Spacer()
                        
                        if isSelected {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(Color.dynamicAccent(theme: currentTheme))
                                .font(.title2)
                        }
                    }
                    
                    Text(theme == .light ? "Interfaz clara y limpia" : "Interfaz oscura y elegante")
                        .font(.subheadline)
                        .foregroundColor(Color.dynamicTextSecondary(theme: currentTheme))
                }
                
                Spacer()
            }
            .padding(16)
            .background(Color.dynamicSurface(theme: currentTheme))
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(
                        isSelected ? Color.dynamicAccent(theme: currentTheme) : Color.dynamicBorder(theme: currentTheme),
                        lineWidth: isSelected ? 2 : 1
                    )
            )
            .scaleEffect(isSelected ? 1.02 : 1.0)
            .animation(.easeInOut(duration: 0.2), value: isSelected)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

#Preview {
    ThemeSettingsView()
        .environmentObject(ThemeManager())
} 