//
//  AnimatedTabTransition.swift
//  Gym_API
//
//  Componente para animar transiciones entre tabs de forma minimalista
//  Usa fade + slide sutil para dar sensación de profundidad sin ser intrusivo
//

import SwiftUI

// MARK: - Animated Tab Content Wrapper

/// Wrapper que añade animación de entrada/salida al contenido de cada tab
struct AnimatedTabContent<Content: View>: View {
    let content: Content
    let isSelected: Bool
    @State private var opacity: Double = 1.0
    @State private var yOffset: CGFloat = 0

    init(isSelected: Bool, @ViewBuilder content: () -> Content) {
        self.isSelected = isSelected
        self.content = content()
    }

    var body: some View {
        content
            .opacity(opacity)
            .offset(y: yOffset)
            .onChange(of: isSelected) { _, newValue in
                if newValue {
                    // Tab seleccionado: animar entrada
                    animateIn()
                } else {
                    // Tab deseleccionado: animar salida
                    animateOut()
                }
            }
            .onAppear {
                if isSelected {
                    animateIn()
                }
            }
    }

    private func animateIn() {
        // Iniciar desde estado oculto
        opacity = 0.7
        yOffset = 12

        // Animar a visible
        withAnimation(.easeOut(duration: 0.22)) {
            opacity = 1.0
            yOffset = 0
        }
    }

    private func animateOut() {
        // Animar a oculto (rápido)
        withAnimation(.easeIn(duration: 0.15)) {
            opacity = 0.7
            yOffset = -8
        }
    }
}

// MARK: - Tab Icon Animation

/// Modificador para animar el icono del tab seleccionado
struct TabIconPulseModifier: ViewModifier {
    let isSelected: Bool
    @State private var scale: CGFloat = 1.0

    func body(content: Content) -> some View {
        content
            .scaleEffect(scale)
            .onChange(of: isSelected) { _, newValue in
                if newValue {
                    pulseAnimation()
                }
            }
    }

    private func pulseAnimation() {
        // Pulse rápido y sutil
        withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
            scale = 1.15
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
            withAnimation(.spring(response: 0.35, dampingFraction: 0.7)) {
                scale = 1.0
            }
        }
    }
}

extension View {
    /// Aplica animación de pulse al icono cuando es seleccionado
    func tabIconPulse(isSelected: Bool) -> some View {
        self.modifier(TabIconPulseModifier(isSelected: isSelected))
    }
}

// MARK: - Tab Bar Indicator Line

/// Línea indicadora animada que se mueve entre tabs
struct AnimatedTabIndicator: View {
    let tabCount: Int
    let selectedTab: Int
    @EnvironmentObject var themeManager: ThemeManager

    var body: some View {
        GeometryReader { geometry in
            let tabWidth = geometry.size.width / CGFloat(tabCount)
            let indicatorWidth = tabWidth * 0.6 // 60% del ancho del tab
            let xOffset = (tabWidth * CGFloat(selectedTab)) + (tabWidth - indicatorWidth) / 2

            VStack {
                Spacer()

                // Línea indicadora
                Rectangle()
                    .fill(Color.dynamicAccent(theme: themeManager.currentTheme))
                    .frame(width: indicatorWidth, height: 3)
                    .cornerRadius(1.5)
                    .offset(x: xOffset)
                    .animation(.spring(response: 0.4, dampingFraction: 0.8), value: selectedTab)
            }
        }
        .frame(height: 49) // Altura estándar de UITabBar
    }
}

// MARK: - Transition Effect Enum

enum TabTransitionEffect {
    case fadeSlide      // Fade + slide vertical (default)
    case scale          // Scale + fade
    case slideHorizontal // Slide horizontal + fade
    case minimal        // Solo fade muy rápido

    var duration: Double {
        switch self {
        case .fadeSlide: return 0.22
        case .scale: return 0.25
        case .slideHorizontal: return 0.28
        case .minimal: return 0.15
        }
    }

    var animation: Animation {
        switch self {
        case .fadeSlide:
            return .easeOut(duration: duration)
        case .scale:
            return .spring(response: 0.4, dampingFraction: 0.8)
        case .slideHorizontal:
            return .interpolatingSpring(stiffness: 300, damping: 30)
        case .minimal:
            return .easeInOut(duration: duration)
        }
    }
}

// MARK: - Custom Tab View Wrapper

/// Wrapper opcional para TabView que añade efectos de transición personalizados
struct AnimatedTabView<Content: View>: View {
    @Binding var selection: Int
    let effect: TabTransitionEffect
    let content: Content
    @EnvironmentObject var themeManager: ThemeManager

    init(
        selection: Binding<Int>,
        effect: TabTransitionEffect = .fadeSlide,
        @ViewBuilder content: () -> Content
    ) {
        self._selection = selection
        self.effect = effect
        self.content = content()
    }

    var body: some View {
        ZStack {
            TabView(selection: $selection) {
                content
            }

            // Indicador personalizado opcional (comentado por defecto)
            // AnimatedTabIndicator(tabCount: 5, selectedTab: selection)
            //     .allowsHitTesting(false)
        }
    }
}

// MARK: - Preview

#Preview {
    struct PreviewWrapper: View {
        @State private var selectedTab = 0
        @StateObject private var themeManager = ThemeManager()

        var body: some View {
            VStack {
                TabView(selection: $selectedTab) {
                    AnimatedTabContent(isSelected: selectedTab == 0) {
                        VStack {
                            Text("Home Tab")
                                .font(.largeTitle)
                            Text("Swipe o toca tabs para ver la animación")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    .tabItem {
                        Image(systemName: "house.fill")
                            .tabIconPulse(isSelected: selectedTab == 0)
                        Text("Home")
                    }
                    .tag(0)

                    AnimatedTabContent(isSelected: selectedTab == 1) {
                        Text("Classes Tab")
                            .font(.largeTitle)
                    }
                    .tabItem {
                        Image(systemName: "dumbbell.fill")
                            .tabIconPulse(isSelected: selectedTab == 1)
                        Text("Classes")
                    }
                    .tag(1)

                    AnimatedTabContent(isSelected: selectedTab == 2) {
                        Text("Events Tab")
                            .font(.largeTitle)
                    }
                    .tabItem {
                        Image(systemName: "calendar.fill")
                            .tabIconPulse(isSelected: selectedTab == 2)
                        Text("Events")
                    }
                    .tag(2)
                }
            }
            .environmentObject(themeManager)
        }
    }

    return PreviewWrapper()
}
