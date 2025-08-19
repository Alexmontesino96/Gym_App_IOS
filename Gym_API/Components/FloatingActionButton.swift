//
//  FloatingActionButton.swift
//  Gym_API
//
//  Created by Assistant on 8/18/25.
//

import SwiftUI

// MARK: - Floating Action Button
struct FloatingActionButton: View {
    let icon: String
    let action: () -> Void
    let themeManager: ThemeManager
    let size: CGFloat
    let backgroundColor: Color?
    let foregroundColor: Color?
    
    @State private var isPressed = false
    
    init(
        icon: String,
        themeManager: ThemeManager,
        size: CGFloat = 60,
        backgroundColor: Color? = nil,
        foregroundColor: Color? = nil,
        action: @escaping () -> Void
    ) {
        self.icon = icon
        self.themeManager = themeManager
        self.size = size
        self.backgroundColor = backgroundColor
        self.foregroundColor = foregroundColor
        self.action = action
    }
    
    var body: some View {
        Button(action: {
            // Haptic feedback
            let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
            impactFeedback.impactOccurred()
            action()
        }) {
            ZStack {
                // Shadow background
                Circle()
                    .fill(Color.black.opacity(0.15))
                    .frame(width: size + 4, height: size + 4)
                    .offset(y: 2)
                
                // Main button
                Circle()
                    .fill(
                        backgroundColor ?? Color.dynamicAccent(theme: themeManager.currentTheme)
                    )
                    .frame(width: size, height: size)
                
                // Icon
                Image(systemName: icon)
                    .font(.system(size: size * 0.35, weight: .semibold))
                    .foregroundColor(
                        foregroundColor ?? .white
                    )
            }
        }
        .scaleEffect(isPressed ? 0.95 : 1.0)
        .animation(.spring(response: 0.3, dampingFraction: 0.6), value: isPressed)
        .onPressGesture(
            onPressed: { isPressed = true },
            onEnded: { isPressed = false }
        )
        .accessibilityLabel("Add new item")
        .accessibilityHint("Double tap to add")
    }
}

// MARK: - Small Floating Action Button
struct SmallFloatingActionButton: View {
    let icon: String
    let action: () -> Void
    let themeManager: ThemeManager
    let backgroundColor: Color?
    
    @State private var isPressed = false
    
    init(
        icon: String,
        themeManager: ThemeManager,
        backgroundColor: Color? = nil,
        action: @escaping () -> Void
    ) {
        self.icon = icon
        self.themeManager = themeManager
        self.backgroundColor = backgroundColor
        self.action = action
    }
    
    var body: some View {
        Button(action: {
            let impactFeedback = UIImpactFeedbackGenerator(style: .light)
            impactFeedback.impactOccurred()
            action()
        }) {
            ZStack {
                Circle()
                    .fill(backgroundColor ?? Color.dynamicAccent(theme: themeManager.currentTheme))
                    .frame(width: 44, height: 44)
                
                Image(systemName: icon)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.white)
            }
        }
        .scaleEffect(isPressed ? 0.9 : 1.0)
        .animation(.spring(response: 0.2, dampingFraction: 0.7), value: isPressed)
        .onPressGesture(
            onPressed: { isPressed = true },
            onEnded: { isPressed = false }
        )
    }
}

// MARK: - Expandable Floating Action Button
struct ExpandableFloatingActionButton: View {
    let mainIcon: String
    let actions: [FABAction]
    let themeManager: ThemeManager
    
    @State private var isExpanded = false
    @State private var isPressed = false
    
    var body: some View {
        VStack(spacing: 16) {
            // Action buttons (shown when expanded)
            if isExpanded {
                ForEach(actions.indices, id: \.self) { index in
                    let action = actions[index]
                    
                    HStack {
                        Spacer()
                        
                        // Label
                        Text(action.label)
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(Color.dynamicText(theme: themeManager.currentTheme))
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(
                                RoundedRectangle(cornerRadius: 20)
                                    .fill(Color.dynamicSurface(theme: themeManager.currentTheme))
                                    .shadow(color: Color.black.opacity(0.1), radius: 4, x: 0, y: 2)
                            )
                        
                        // Action button
                        SmallFloatingActionButton(
                            icon: action.icon,
                            themeManager: themeManager,
                            backgroundColor: action.color
                        ) {
                            action.action()
                            withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                                isExpanded = false
                            }
                        }
                    }
                    .transition(.asymmetric(
                        insertion: .move(edge: .trailing).combined(with: .opacity),
                        removal: .move(edge: .trailing).combined(with: .opacity)
                    ))
                    .animation(.spring(response: 0.3, dampingFraction: 0.8).delay(Double(index) * 0.1), value: isExpanded)
                }
            }
            
            // Main button
            FloatingActionButton(
                icon: isExpanded ? "xmark" : mainIcon,
                themeManager: themeManager
            ) {
                withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                    isExpanded.toggle()
                }
            }
        }
    }
}

// MARK: - FAB Action Model
struct FABAction {
    let icon: String
    let label: String
    let color: Color?
    let action: () -> Void
    
    init(icon: String, label: String, color: Color? = nil, action: @escaping () -> Void) {
        self.icon = icon
        self.label = label
        self.color = color
        self.action = action
    }
}

// MARK: - FAB Container (for positioning)
struct FABContainer<Content: View>: View {
    let content: Content
    let position: FABPosition
    let padding: EdgeInsets
    
    init(
        position: FABPosition = .bottomTrailing,
        padding: EdgeInsets = EdgeInsets(top: 0, leading: 0, bottom: 20, trailing: 20),
        @ViewBuilder content: () -> Content
    ) {
        self.content = content()
        self.position = position
        self.padding = padding
    }
    
    var body: some View {
        VStack {
            if position == .bottomTrailing || position == .bottomLeading {
                Spacer()
            }
            
            HStack {
                if position == .bottomTrailing || position == .topTrailing {
                    Spacer()
                }
                
                content
                    .padding(padding)
                
                if position == .bottomLeading || position == .topLeading {
                    Spacer()
                }
            }
            
            if position == .topTrailing || position == .topLeading {
                Spacer()
            }
        }
        .allowsHitTesting(true)
    }
}

// MARK: - FAB Position Enum
enum FABPosition {
    case topLeading
    case topTrailing
    case bottomLeading
    case bottomTrailing
}

// MARK: - Quick Create FAB (for events/classes)
struct QuickCreateFAB: View {
    let themeManager: ThemeManager
    let onCreateEvent: () -> Void
    let onCreateClass: () -> Void
    let canCreateEvents: Bool
    let canCreateClasses: Bool
    
    var body: some View {
        Group {
            if canCreateEvents && canCreateClasses {
                // Show expandable FAB with both options
                ExpandableFloatingActionButton(
                    mainIcon: "plus",
                    actions: [
                        FABAction(
                            icon: "figure.run",
                            label: "Crear Evento",
                            color: Color.dynamicAccent(theme: themeManager.currentTheme),
                            action: onCreateEvent
                        ),
                        FABAction(
                            icon: "dumbbell.fill",
                            label: "Crear Clase",
                            color: Color.blue,
                            action: onCreateClass
                        )
                    ],
                    themeManager: themeManager
                )
            } else if canCreateEvents {
                // Show simple FAB for events only
                FloatingActionButton(
                    icon: "plus",
                    themeManager: themeManager,
                    action: onCreateEvent
                )
            } else if canCreateClasses {
                // Show simple FAB for classes only
                FloatingActionButton(
                    icon: "plus",
                    themeManager: themeManager,
                    action: onCreateClass
                )
            }
        }
    }
}

// MARK: - Preview
#Preview {
    ZStack {
        Color.gray.opacity(0.1).ignoresSafeArea()
        
        VStack(spacing: 40) {
            // Simple FAB
            FloatingActionButton(
                icon: "plus",
                themeManager: ThemeManager(),
                action: { print("Simple FAB tapped") }
            )
            
            // Small FAB
            SmallFloatingActionButton(
                icon: "heart.fill",
                themeManager: ThemeManager(),
                backgroundColor: .red,
                action: { print("Small FAB tapped") }
            )
            
            // Expandable FAB
            ExpandableFloatingActionButton(
                mainIcon: "plus",
                actions: [
                    FABAction(icon: "figure.run", label: "Crear Evento", action: {}),
                    FABAction(icon: "dumbbell.fill", label: "Crear Clase", color: .blue, action: {}),
                    FABAction(icon: "person.2.fill", label: "Invitar", color: .green, action: {})
                ],
                themeManager: ThemeManager()
            )
        }
    }
    .environmentObject(ThemeManager())
}