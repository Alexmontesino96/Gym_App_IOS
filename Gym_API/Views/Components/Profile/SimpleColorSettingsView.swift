import SwiftUI

struct SimpleColorSettingsView: View {
    @EnvironmentObject var themeManager: ThemeManager
    @Environment(\.dismiss) private var dismiss
    @State private var selectedTheme: ThemeManager.AppTheme = .light
    
    var body: some View {
        NavigationView {
            VStack(spacing: 16) {
                // Theme selector
                HStack {
                    Text("Theme")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(Color.dynamicText(theme: themeManager.currentTheme))
                    Spacer()
                    Picker("Theme", selection: $selectedTheme) {
                        Text("Light").tag(ThemeManager.AppTheme.light)
                        Text("Dark").tag(ThemeManager.AppTheme.dark)
                    }
                    .pickerStyle(.segmented)
                    .frame(width: 180)
                    .onChange(of: selectedTheme) { newValue in
                        themeManager.setTheme(newValue)
                    }
                }
                .padding(.horizontal, 20)
                
                // Accent options grid
                let options = selectedTheme == .light ? ThemeManager.lightAccentOptions : ThemeManager.darkAccentOptions
                let currentHex = themeManager.accentHex(for: selectedTheme)
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: 5), spacing: 12) {
                    ForEach(options, id: \.self) { hex in
                        let color = Color(hex: hex) ?? .gray
                        ZStack {
                            Circle()
                                .fill(color)
                                .frame(width: 34, height: 34)
                                .overlay(
                                    Circle().stroke(Color.dynamicSurface(theme: themeManager.currentTheme), lineWidth: 2)
                                )
                            if hex == currentHex {
                                Image(systemName: "checkmark")
                                    .font(.system(size: 12, weight: .bold))
                                    .foregroundColor(.white)
                            }
                        }
                        .onTapGesture {
                            themeManager.setAccentHex(hex, for: selectedTheme)
                        }
                    }
                }
                .padding(.horizontal, 20)
                
                Spacer()
            }
            .padding(.top, 20)
            .background(Color.dynamicBackground(theme: themeManager.currentTheme).ignoresSafeArea())
            .navigationTitle("Customize Colors")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Close") { dismiss() }
                        .foregroundColor(Color.dynamicAccent(theme: themeManager.currentTheme))
                }
            }
        }
        .onAppear { selectedTheme = themeManager.currentTheme }
    }
}

#Preview {
    SimpleColorSettingsView()
        .environmentObject(ThemeManager())
}

