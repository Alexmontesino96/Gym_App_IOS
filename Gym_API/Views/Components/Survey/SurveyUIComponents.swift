import SwiftUI

// MARK: - Glassmorphic TextField
struct GlassmorphicTextField: View {
    let placeholder: String
    @Binding var text: String
    let icon: String?
    @EnvironmentObject var themeManager: ThemeManager
    @FocusState private var isFocused: Bool
    
    var body: some View {
        HStack(spacing: 12) {
            if let icon = icon {
                Image(systemName: icon)
                    .foregroundColor(.accentColor)
                    .font(.system(size: 16))
                    .frame(width: 20)
            }
            
            TextField(placeholder, text: $text)
                .textFieldStyle(PlainTextFieldStyle())
                .foregroundColor(Color.dynamicText(theme: themeManager.currentTheme))
                .focused($isFocused)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background(
            ZStack {
                // Glassmorphism effect
                RoundedRectangle(cornerRadius: 12)
                    .fill(
                        Color.dynamicSurface(theme: themeManager.currentTheme)
                            .opacity(themeManager.currentTheme == .dark ? 0.3 : 0.8)
                    )
                
                RoundedRectangle(cornerRadius: 12)
                    .stroke(
                        LinearGradient(
                            gradient: Gradient(colors: [
                                Color.white.opacity(isFocused ? 0.3 : 0.1),
                                Color.white.opacity(0.05)
                            ]),
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1
                    )
            }
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(
                    isFocused ? Color.accentColor : Color.clear,
                    lineWidth: 2
                )
                .animation(.easeInOut(duration: 0.2), value: isFocused)
        )
    }
}

// MARK: - Glassmorphic Text Editor
struct GlassmorphicTextEditor: View {
    let placeholder: String
    @Binding var text: String
    let minHeight: CGFloat
    @EnvironmentObject var themeManager: ThemeManager
    @FocusState private var isFocused: Bool
    
    var body: some View {
        ZStack(alignment: .topLeading) {
            if text.isEmpty {
                Text(placeholder)
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 12)
            }
            
            TextEditor(text: $text)
                .textFieldStyle(PlainTextFieldStyle())
                .foregroundColor(Color.dynamicText(theme: themeManager.currentTheme))
                .focused($isFocused)
                .padding(8)
                .scrollContentBackground(.hidden)
                .background(Color.clear)
        }
        .frame(minHeight: minHeight)
        .background(
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .fill(
                        Color.dynamicSurface(theme: themeManager.currentTheme)
                            .opacity(themeManager.currentTheme == .dark ? 0.3 : 0.8)
                    )
                
                RoundedRectangle(cornerRadius: 12)
                    .stroke(
                        LinearGradient(
                            gradient: Gradient(colors: [
                                Color.white.opacity(isFocused ? 0.3 : 0.1),
                                Color.white.opacity(0.05)
                            ]),
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1
                    )
            }
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(
                    isFocused ? Color.accentColor : Color.clear,
                    lineWidth: 2
                )
                .animation(.easeInOut(duration: 0.2), value: isFocused)
        )
    }
}

// MARK: - Animated Radio Button
struct AnimatedRadioButton: View {
    let label: String
    let isSelected: Bool
    let action: () -> Void
    @EnvironmentObject var themeManager: ThemeManager
    @State private var isPressed = false
    
    var body: some View {
        Button(action: {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                action()
                // Haptic feedback
                let impactFeedback = UIImpactFeedbackGenerator(style: .light)
                impactFeedback.impactOccurred()
            }
        }) {
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .stroke(
                            isSelected ? Color.accentColor : Color.secondary.opacity(0.5),
                            lineWidth: 2
                        )
                        .frame(width: 24, height: 24)
                    
                    if isSelected {
                        Circle()
                            .fill(Color.accentColor)
                            .frame(width: 14, height: 14)
                            .transition(.scale.combined(with: .opacity))
                    }
                }
                .scaleEffect(isPressed ? 0.95 : 1.0)
                
                Text(label)
                    .foregroundColor(Color.dynamicText(theme: themeManager.currentTheme))
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(.vertical, 12)
            .padding(.horizontal, 16)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(
                        isSelected 
                            ? Color.accentColor.opacity(0.1)
                            : Color.dynamicSurface(theme: themeManager.currentTheme).opacity(0.5)
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(
                        isSelected ? Color.accentColor.opacity(0.3) : Color.clear,
                        lineWidth: 1
                    )
            )
        }
        .buttonStyle(PlainButtonStyle())
        .onLongPressGesture(minimumDuration: .infinity, maximumDistance: .infinity,
                           pressing: { pressing in
                               isPressed = pressing
                           },
                           perform: {})
    }
}

// MARK: - Pulsating Checkbox
struct PulsatingCheckbox: View {
    let label: String
    @Binding var isChecked: Bool
    @EnvironmentObject var themeManager: ThemeManager
    @State private var scale: CGFloat = 1.0
    
    var body: some View {
        Button(action: {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                isChecked.toggle()
                scale = 1.2
                
                // Haptic feedback
                let impactFeedback = UIImpactFeedbackGenerator(style: .light)
                impactFeedback.impactOccurred()
                
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                        scale = 1.0
                    }
                }
            }
        }) {
            HStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(
                            isChecked ? Color.accentColor : Color.secondary.opacity(0.5),
                            lineWidth: 2
                        )
                        .frame(width: 24, height: 24)
                    
                    if isChecked {
                        Image(systemName: "checkmark")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(.white)
                            .frame(width: 24, height: 24)
                            .background(Color.accentColor)
                            .cornerRadius(6)
                            .transition(.scale.combined(with: .opacity))
                    }
                }
                .scaleEffect(scale)
                
                Text(label)
                    .foregroundColor(Color.dynamicText(theme: themeManager.currentTheme))
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(.vertical, 12)
            .padding(.horizontal, 16)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(
                        isChecked 
                            ? Color.accentColor.opacity(0.1)
                            : Color.dynamicSurface(theme: themeManager.currentTheme).opacity(0.5)
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(
                        isChecked ? Color.accentColor.opacity(0.3) : Color.clear,
                        lineWidth: 1
                    )
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Scale Slider
struct ModernScaleSlider: View {
    @Binding var value: Double
    let range: ClosedRange<Double>
    let step: Double
    @EnvironmentObject var themeManager: ThemeManager
    @State private var isDragging = false
    
    var body: some View {
        VStack(spacing: 16) {
            // Value Display
            Text("\(Int(value))")
                .font(.system(size: 32, weight: .bold, design: .rounded))
                .foregroundColor(Color.accentColor)
                .scaleEffect(isDragging ? 1.1 : 1.0)
                .animation(.spring(response: 0.3), value: isDragging)
            
            // Slider
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    // Track
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.secondary.opacity(0.2))
                        .frame(height: 8)
                    
                    // Progress
                    RoundedRectangle(cornerRadius: 4)
                        .fill(
                            LinearGradient(
                                gradient: Gradient(colors: [Color.blue, Color.purple]),
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(
                            width: CGFloat((value - range.lowerBound) / (range.upperBound - range.lowerBound)) * geometry.size.width,
                            height: 8
                        )
                    
                    // Thumb
                    Circle()
                        .fill(Color.white)
                        .frame(width: 28, height: 28)
                        .shadow(color: Color.black.opacity(0.2), radius: 4, x: 0, y: 2)
                        .overlay(
                            Circle()
                                .fill(Color.accentColor)
                                .frame(width: 20, height: 20)
                        )
                        .offset(x: CGFloat((value - range.lowerBound) / (range.upperBound - range.lowerBound)) * (geometry.size.width - 28))
                        .scaleEffect(isDragging ? 1.2 : 1.0)
                        .animation(.spring(response: 0.3), value: isDragging)
                        .gesture(
                            DragGesture()
                                .onChanged { drag in
                                    isDragging = true
                                    let newValue = range.lowerBound + (drag.location.x / geometry.size.width) * (range.upperBound - range.lowerBound)
                                    value = min(max(newValue, range.lowerBound), range.upperBound)
                                    value = (value / step).rounded() * step
                                }
                                .onEnded { _ in
                                    isDragging = false
                                    let impactFeedback = UIImpactFeedbackGenerator(style: .light)
                                    impactFeedback.impactOccurred()
                                }
                        )
                }
            }
            .frame(height: 28)
            
            // Labels
            HStack {
                Text("\(Int(range.lowerBound))")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Spacer()
                Text("\(Int(range.upperBound))")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.dynamicSurface(theme: themeManager.currentTheme).opacity(0.5))
        )
    }
}

// MARK: - NPS Scale View
struct NPSScaleView: View {
    @Binding var value: Int?
    @EnvironmentObject var themeManager: ThemeManager
    
    var body: some View {
        VStack(spacing: 16) {
            HStack(spacing: 8) {
                ForEach(0...10, id: \.self) { score in
                    Button(action: {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                            value = score
                            let impactFeedback = UIImpactFeedbackGenerator(style: .light)
                            impactFeedback.impactOccurred()
                        }
                    }) {
                        Text("\(score)")
                            .font(.system(size: 14, weight: .medium))
                            .frame(width: 28, height: 28)
                            .background(
                                Circle()
                                    .fill(value == score ? npsColor(for: score) : Color.secondary.opacity(0.2))
                            )
                            .foregroundColor(value == score ? .white : .secondary)
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
            
            // Labels
            HStack {
                Text("Not likely")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Spacer()
                Text("Very likely")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }
    
    private func npsColor(for score: Int) -> Color {
        switch score {
        case 0...6: return .red
        case 7...8: return .orange
        case 9...10: return .green
        default: return .gray
        }
    }
}

// MARK: - Yes/No Toggle
struct YesNoToggle: View {
    @Binding var value: Bool?
    @EnvironmentObject var themeManager: ThemeManager
    
    var body: some View {
        HStack(spacing: 16) {
            Button(action: {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                    value = true
                    let impactFeedback = UIImpactFeedbackGenerator(style: .light)
                    impactFeedback.impactOccurred()
                }
            }) {
                HStack {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(value == true ? .white : .green)
                    Text("Yes")
                        .fontWeight(.medium)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .fill(value == true ? Color.green : Color.green.opacity(0.2))
                )
                .foregroundColor(value == true ? .white : .green)
            }
            .buttonStyle(PlainButtonStyle())
            
            Button(action: {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                    value = false
                    let impactFeedback = UIImpactFeedbackGenerator(style: .light)
                    impactFeedback.impactOccurred()
                }
            }) {
                HStack {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(value == false ? .white : .red)
                    Text("No")
                        .fontWeight(.medium)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .fill(value == false ? Color.red : Color.red.opacity(0.2))
                )
                .foregroundColor(value == false ? .white : .red)
            }
            .buttonStyle(PlainButtonStyle())
        }
    }
}

// MARK: - Gradient Action Button
struct GradientActionButton: View {
    let title: String
    let icon: String?
    let action: () -> Void
    let isEnabled: Bool
    @EnvironmentObject var themeManager: ThemeManager
    @State private var isPressed = false
    
    var body: some View {
        Button(action: {
            if isEnabled {
                action()
                let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
                impactFeedback.impactOccurred()
            }
        }) {
            HStack(spacing: 8) {
                Text(title)
                    .font(.system(size: 16, weight: .semibold))
                
                if let icon = icon {
                    Image(systemName: icon)
                        .font(.system(size: 14, weight: .semibold))
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(
                LinearGradient(
                    gradient: Gradient(colors: isEnabled ? [Color.blue, Color.purple] : [Color.gray]),
                    startPoint: .leading,
                    endPoint: .trailing
                )
                .opacity(isEnabled ? 1.0 : 0.5)
            )
            .foregroundColor(.white)
            .cornerRadius(12)
            .scaleEffect(isPressed ? 0.95 : 1.0)
            .animation(.spring(response: 0.3, dampingFraction: 0.6), value: isPressed)
        }
        .buttonStyle(PlainButtonStyle())
        .disabled(!isEnabled)
        .onLongPressGesture(minimumDuration: .infinity, maximumDistance: .infinity,
                           pressing: { pressing in
                               if isEnabled {
                                   isPressed = pressing
                               }
                           },
                           perform: {})
    }
}