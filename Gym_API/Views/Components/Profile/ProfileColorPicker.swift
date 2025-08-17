import SwiftUI

// MARK: - Profile Color Picker Sheet
struct ProfileColorPickerSheet: View {
    @EnvironmentObject var themeManager: ThemeManager
    @EnvironmentObject var colorCustomizationManager: ColorCustomizationManager
    @Binding var isPresented: Bool
    
    @State private var selectedColor: ProfileBackgroundColor
    @State private var isApplying = false
    
    init(isPresented: Binding<Bool>, currentColor: ProfileBackgroundColor) {
        self._isPresented = isPresented
        self._selectedColor = State(initialValue: currentColor)
    }
    
    var body: some View {
        NavigationView {
            ZStack {
                Color.dynamicBackground(theme: themeManager.currentTheme)
                    .ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 24) {
                        // Preview Section
                        profilePreviewSection
                        
                        // Color Palette Section
                        colorPaletteSection
                        
                        // Action Buttons
                        actionButtonsSection
                        
                        Spacer(minLength: 20)
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 20)
                }
            }
            .navigationTitle("Profile Theme")
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarBackButtonHidden(true)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        selectedColor = colorCustomizationManager.currentBackgroundColor
                        isPresented = false
                    }
                    .foregroundColor(.secondary)
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Apply") {
                        applySelectedColor()
                    }
                    .foregroundColor(Color.dynamicAccent(theme: themeManager.currentTheme))
                    .fontWeight(.semibold)
                    .disabled(isApplying || selectedColor == colorCustomizationManager.currentBackgroundColor)
                }
            }
        }
    }
    
    // MARK: - Preview Section
    private var profilePreviewSection: some View {
        VStack(spacing: 16) {
            HStack {
                Image(systemName: "eye")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(Color.dynamicText(theme: themeManager.currentTheme))
                
                Text("Preview")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(Color.dynamicText(theme: themeManager.currentTheme))
                
                Spacer()
            }
            
            // Mini profile preview
            ZStack {
                // Background with selected color
                LinearGradient(
                    colors: [
                        selectedColor.gradientColors[0],
                        selectedColor.gradientColors[1],
                        selectedColor.gradientColors[1].opacity(0.5),
                        Color.dynamicBackground(theme: themeManager.currentTheme).opacity(0.2)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .frame(height: 180)
                .cornerRadius(20)
                
                VStack(spacing: 12) {
                    // Profile image preview
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [
                                    selectedColor.accentColor.opacity(0.8),
                                    selectedColor.accentColor.opacity(0.4)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 80, height: 80)
                        .overlay(
                            Image(systemName: "person.fill")
                                .font(.system(size: 40, weight: .light))
                                .foregroundColor(.white.opacity(0.9))
                        )
                        .overlay(
                            Circle()
                                .stroke(
                                    LinearGradient(
                                        colors: [
                                            selectedColor.accentColor,
                                            Color.white.opacity(0.8)
                                        ],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    ),
                                    lineWidth: 3
                                )
                        )
                    
                    // Name preview
                    Text("Your Name")
                        .font(.system(size: 20, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                        .shadow(color: .black.opacity(0.3), radius: 2, x: 0, y: 1)
                }
            }
            
            Text(selectedColor.displayName)
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(Color.dynamicText(theme: themeManager.currentTheme))
        }
        .padding(.bottom, 8)
    }
    
    // MARK: - Color Palette Section
    private var colorPaletteSection: some View {
        VStack(spacing: 16) {
            HStack {
                Image(systemName: "paintpalette")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(Color.dynamicAccent(theme: themeManager.currentTheme))
                
                Text("Choose Theme")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(Color.dynamicText(theme: themeManager.currentTheme))
                
                Spacer()
            }
            
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: 3), spacing: 16) {
                ForEach(ProfileBackgroundColor.allCases, id: \.self) { color in
                    ColorOptionButton(
                        color: color,
                        isSelected: selectedColor == color,
                        isCurrent: colorCustomizationManager.currentBackgroundColor == color
                    ) {
                        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                            selectedColor = color
                        }
                        
                        // Haptic feedback
                        let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
                        impactFeedback.impactOccurred()
                    }
                }
            }
        }
    }
    
    // MARK: - Action Buttons Section
    private var actionButtonsSection: some View {
        VStack(spacing: 12) {
            // Apply Button
            Button(action: applySelectedColor) {
                HStack(spacing: 12) {
                    if isApplying {
                        ProgressView()
                            .scaleEffect(0.9)
                            .foregroundColor(.white)
                    } else {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 18, weight: .semibold))
                    }
                    
                    Text(isApplying ? "Applying..." : "Apply Theme")
                        .font(.system(size: 16, weight: .semibold))
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(
                    LinearGradient(
                        colors: [
                            selectedColor.gradientColors[0].opacity(isApplying ? 0.7 : 1.0),
                            selectedColor.gradientColors[1].opacity(isApplying ? 0.7 : 1.0)
                        ],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .cornerRadius(12)
                .shadow(
                    color: selectedColor.gradientColors[0].opacity(0.3),
                    radius: 8,
                    x: 0,
                    y: 4
                )
            }
            .disabled(isApplying || selectedColor == colorCustomizationManager.currentBackgroundColor)
            
            // Reset Button
            if colorCustomizationManager.currentBackgroundColor != .default_black {
                Button(action: resetToDefault) {
                    HStack(spacing: 8) {
                        Image(systemName: "arrow.clockwise")
                            .font(.system(size: 14, weight: .medium))
                        
                        Text("Reset to Default")
                            .font(.system(size: 14, weight: .medium))
                    }
                    .foregroundColor(Color.dynamicText(theme: themeManager.currentTheme).opacity(0.7))
                    .padding(.vertical, 12)
                }
                .buttonStyle(PlainButtonStyle())
            }
        }
    }
    
    // MARK: - Actions
    private func applySelectedColor() {
        guard selectedColor != colorCustomizationManager.currentBackgroundColor else { return }
        
        isApplying = true
        
        Task {
            await colorCustomizationManager.changeBackgroundColor(to: selectedColor)
            
            await MainActor.run {
                isApplying = false
                isPresented = false
                
                // Success haptic feedback
                let notificationFeedback = UINotificationFeedbackGenerator()
                notificationFeedback.notificationOccurred(.success)
            }
        }
    }
    
    private func resetToDefault() {
        selectedColor = .default_black
        
        Task {
            await colorCustomizationManager.resetToDefault()
        }
    }
}

// MARK: - Color Option Button
struct ColorOptionButton: View {
    let color: ProfileBackgroundColor
    let isSelected: Bool
    let isCurrent: Bool
    let action: () -> Void
    
    @State private var isPressed = false
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                // Color preview circle
                ZStack {
                    // Gradient background
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: color.gradientColors,
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 60, height: 60)
                    
                    // Selection indicator
                    if isSelected {
                        Circle()
                            .stroke(Color.white, lineWidth: 3)
                            .frame(width: 68, height: 68)
                        
                        Circle()
                            .stroke(color.accentColor, lineWidth: 2)
                            .frame(width: 72, height: 72)
                    }
                    
                    // Current indicator
                    if isCurrent && !isSelected {
                        Circle()
                            .stroke(Color.white.opacity(0.6), lineWidth: 2)
                            .frame(width: 65, height: 65)
                        
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 20, weight: .bold))
                            .foregroundColor(.white)
                            .background(
                                Circle()
                                    .fill(color.accentColor)
                                    .frame(width: 24, height: 24)
                            )
                            .offset(x: 20, y: -20)
                    }
                }
                
                // Color name
                Text(color.displayName)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(Color.primary.opacity(0.8))
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .frame(height: 32)
            }
            .scaleEffect(isPressed ? 0.95 : 1.0)
            .animation(.spring(response: 0.3, dampingFraction: 0.6), value: isPressed)
        }
        .buttonStyle(PlainButtonStyle())
        .onPressGesture(
            onPressed: { isPressed = true },
            onEnded: { isPressed = false }
        )
    }
}

