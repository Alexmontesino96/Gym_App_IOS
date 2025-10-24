//
//  DesignSystem.swift
//  Gym_API
//
//  Sistema de diseño unificado para componentes reutilizables
//  Fase 2 - Semana 3: Refactorización de Vistas
//

import SwiftUI

// MARK: - Design System Namespace
enum DesignSystem {

    // MARK: - Spacing Constants
    enum Spacing {
        static let xs: CGFloat = 4
        static let sm: CGFloat = 8
        static let md: CGFloat = 16
        static let lg: CGFloat = 24
        static let xl: CGFloat = 32
        static let xxl: CGFloat = 48
    }

    // MARK: - Corner Radius
    enum CornerRadius {
        static let small: CGFloat = 8
        static let medium: CGFloat = 12
        static let large: CGFloat = 16
        static let xl: CGFloat = 20
        static let round: CGFloat = 999
    }

    // MARK: - Font Sizes
    enum FontSize {
        static let caption: CGFloat = 12
        static let body: CGFloat = 16
        static let title: CGFloat = 20
        static let largeTitle: CGFloat = 28
        static let hero: CGFloat = 36
    }

    // MARK: - Shadows
    enum Shadow {
        static let light = ShadowStyle(radius: 4, y: 2, opacity: 0.1)
        static let medium = ShadowStyle(radius: 8, y: 4, opacity: 0.15)
        static let heavy = ShadowStyle(radius: 16, y: 8, opacity: 0.2)
        static let card = ShadowStyle(radius: 10, y: 5, opacity: 0.12)
    }

    struct ShadowStyle {
        let radius: CGFloat
        let y: CGFloat
        let opacity: Double
    }

    // MARK: - Animation
    enum Animation {
        static let fast = SwiftUI.Animation.easeInOut(duration: 0.2)
        static let medium = SwiftUI.Animation.easeInOut(duration: 0.3)
        static let slow = SwiftUI.Animation.easeInOut(duration: 0.5)
        static let spring = SwiftUI.Animation.spring(response: 0.4, dampingFraction: 0.8)
    }
}

// MARK: - Reusable Button Styles

struct PrimaryButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled
    @EnvironmentObject var themeManager: ThemeManager

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: DesignSystem.FontSize.body, weight: .semibold))
            .foregroundColor(.white)
            .padding(.vertical, DesignSystem.Spacing.md)
            .padding(.horizontal, DesignSystem.Spacing.lg)
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.medium)
                    .fill(Color.dynamicSurface(theme: themeManager.currentTheme))
                    .opacity(isEnabled ? 1 : 0.5)
            )
            .scaleEffect(configuration.isPressed ? 0.95 : 1)
            .animation(DesignSystem.Animation.fast, value: configuration.isPressed)
    }
}

struct SecondaryButtonStyle: ButtonStyle {
    @EnvironmentObject var themeManager: ThemeManager

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: DesignSystem.FontSize.body, weight: .medium))
            .foregroundColor(Color.dynamicText(theme: themeManager.currentTheme))
            .padding(.vertical, DesignSystem.Spacing.md)
            .padding(.horizontal, DesignSystem.Spacing.lg)
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.medium)
                    .stroke(Color.dynamicSurface(theme: themeManager.currentTheme), lineWidth: 2)
            )
            .scaleEffect(configuration.isPressed ? 0.95 : 1)
            .animation(DesignSystem.Animation.fast, value: configuration.isPressed)
    }
}

struct GhostButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: DesignSystem.FontSize.body))
            .opacity(configuration.isPressed ? 0.5 : 1)
            .animation(DesignSystem.Animation.fast, value: configuration.isPressed)
    }
}

struct IconButtonStyle: ButtonStyle {
    @EnvironmentObject var themeManager: ThemeManager
    let size: CGFloat

    init(size: CGFloat = 44) {
        self.size = size
    }

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .frame(width: size, height: size)
            .background(
                Circle()
                    .fill(Color.dynamicSurface(theme: themeManager.currentTheme).opacity(0.1))
            )
            .scaleEffect(configuration.isPressed ? 0.85 : 1)
            .animation(DesignSystem.Animation.fast, value: configuration.isPressed)
    }
}

// MARK: - Card Components

struct CardView<Content: View>: View {
    @EnvironmentObject var themeManager: ThemeManager
    let content: Content
    var padding: CGFloat = DesignSystem.Spacing.md
    var cornerRadius: CGFloat = DesignSystem.CornerRadius.large

    init(padding: CGFloat = DesignSystem.Spacing.md,
         cornerRadius: CGFloat = DesignSystem.CornerRadius.large,
         @ViewBuilder content: () -> Content) {
        self.padding = padding
        self.cornerRadius = cornerRadius
        self.content = content()
    }

    var body: some View {
        content
            .padding(padding)
            .background(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .fill(Color.dynamicBackground(theme: themeManager.currentTheme))
                    .shadow(
                        color: .black.opacity(DesignSystem.Shadow.card.opacity),
                        radius: DesignSystem.Shadow.card.radius,
                        y: DesignSystem.Shadow.card.y
                    )
            )
    }
}

struct GlassCardView<Content: View>: View {
    @EnvironmentObject var themeManager: ThemeManager
    let content: Content
    var padding: CGFloat = DesignSystem.Spacing.md

    init(padding: CGFloat = DesignSystem.Spacing.md,
         @ViewBuilder content: () -> Content) {
        self.padding = padding
        self.content = content()
    }

    var body: some View {
        content
            .padding(padding)
            .background(
                RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.large)
                    .fill(.ultraThinMaterial)
                    .overlay(
                        RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.large)
                            .stroke(Color.white.opacity(0.1), lineWidth: 1)
                    )
            )
    }
}

// MARK: - Form Components

struct FormTextField: View {
    @EnvironmentObject var themeManager: ThemeManager
    let title: String
    @Binding var text: String
    var placeholder: String = ""
    var isSecure: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.xs) {
            Text(title)
                .font(.caption)
                .foregroundColor(Color.dynamicText(theme: themeManager.currentTheme).opacity(0.7))

            Group {
                if isSecure {
                    SecureField(placeholder, text: $text)
                } else {
                    TextField(placeholder, text: $text)
                }
            }
            .padding(DesignSystem.Spacing.md)
            .background(
                RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.small)
                    .fill(Color.dynamicBackground(theme: themeManager.currentTheme))
                    .overlay(
                        RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.small)
                            .stroke(Color.dynamicSurface(theme: themeManager.currentTheme).opacity(0.2), lineWidth: 1)
                    )
            )
        }
    }
}


struct FormPicker<SelectionValue: Hashable, Content: View>: View {
    @EnvironmentObject var themeManager: ThemeManager
    let title: String
    @Binding var selection: SelectionValue
    let content: Content

    init(title: String,
         selection: Binding<SelectionValue>,
         @ViewBuilder content: () -> Content) {
        self.title = title
        self._selection = selection
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.xs) {
            Text(title)
                .font(.caption)
                .foregroundColor(Color.dynamicText(theme: themeManager.currentTheme).opacity(0.7))

            Picker(title, selection: $selection) {
                content
            }
            .pickerStyle(MenuPickerStyle())
            .padding(DesignSystem.Spacing.md)
            .background(
                RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.small)
                    .fill(Color.dynamicBackground(theme: themeManager.currentTheme))
            )
        }
    }
}

// MARK: - List Components

struct ListItemView<Content: View>: View {
    let content: Content
    var showDivider: Bool = true

    init(showDivider: Bool = true,
         @ViewBuilder content: () -> Content) {
        self.showDivider = showDivider
        self.content = content()
    }

    var body: some View {
        VStack(spacing: 0) {
            content
                .padding(.vertical, DesignSystem.Spacing.md)
                .padding(.horizontal, DesignSystem.Spacing.md)

            if showDivider {
                Divider()
                    .padding(.leading, DesignSystem.Spacing.md)
            }
        }
    }
}

// MARK: - Badge Component

struct BadgeView: View {
    @EnvironmentObject var themeManager: ThemeManager
    let text: String
    var color: Color?

    var body: some View {
        Text(text)
            .font(.caption)
            .fontWeight(.semibold)
            .padding(.horizontal, DesignSystem.Spacing.sm)
            .padding(.vertical, DesignSystem.Spacing.xs)
            .background(
                Capsule()
                    .fill(color ?? Color.dynamicSurface(theme: themeManager.currentTheme))
            )
            .foregroundColor(.white)
    }
}

// MARK: - Loading Indicator

struct LoadingView: View {
    @EnvironmentObject var themeManager: ThemeManager
    var message: String = "Cargando..."

    var body: some View {
        VStack(spacing: DesignSystem.Spacing.md) {
            ProgressView()
                .progressViewStyle(CircularProgressViewStyle())
                .scaleEffect(1.5)
                .tint(Color.dynamicSurface(theme: themeManager.currentTheme))

            Text(message)
                .font(.system(size: DesignSystem.FontSize.body))
                .foregroundColor(Color.dynamicText(theme: themeManager.currentTheme))
        }
        .padding(DesignSystem.Spacing.xl)
    }
}



// MARK: - Avatar View

struct AvatarView: View {
    let url: String?
    let size: CGFloat
    var initials: String = "?"

    @EnvironmentObject var themeManager: ThemeManager

    var body: some View {
        Group {
            if let url = url, !url.isEmpty {
                AsyncImage(url: URL(string: url)) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } placeholder: {
                    initialsView
                }
            } else {
                initialsView
            }
        }
        .frame(width: size, height: size)
        .clipShape(Circle())
    }

    private var initialsView: some View {
        Text(initials)
            .font(.system(size: size * 0.4, weight: .semibold))
            .foregroundColor(.white)
            .frame(width: size, height: size)
            .background(
                Circle()
                    .fill(Color.dynamicSurface(theme: themeManager.currentTheme))
            )
    }
}

// MARK: - Tab Bar Item

struct TabBarItemView: View {
    @EnvironmentObject var themeManager: ThemeManager
    let icon: String
    let title: String
    let isSelected: Bool

    var body: some View {
        VStack(spacing: DesignSystem.Spacing.xs) {
            Image(systemName: icon)
                .font(.system(size: 24))

            Text(title)
                .font(.caption2)
        }
        .foregroundColor(
            isSelected
                ? Color.dynamicSurface(theme: themeManager.currentTheme)
                : Color.dynamicText(theme: themeManager.currentTheme).opacity(0.5)
        )
        .animation(DesignSystem.Animation.fast, value: isSelected)
    }
}


// MARK: - Chip/Tag View

struct ChipView: View {
    @EnvironmentObject var themeManager: ThemeManager
    let text: String
    var isSelected: Bool = false
    var action: (() -> Void)? = nil

    var body: some View {
        Button(action: action ?? {}) {
            Text(text)
                .font(.system(size: DesignSystem.FontSize.body))
                .padding(.horizontal, DesignSystem.Spacing.md)
                .padding(.vertical, DesignSystem.Spacing.sm)
                .background(
                    Capsule()
                        .fill(isSelected
                            ? Color.dynamicSurface(theme: themeManager.currentTheme)
                            : Color.dynamicBackground(theme: themeManager.currentTheme)
                        )
                        .overlay(
                            Capsule()
                                .stroke(Color.dynamicSurface(theme: themeManager.currentTheme), lineWidth: 1)
                                .opacity(isSelected ? 0 : 1)
                        )
                )
                .foregroundColor(isSelected ? .white : Color.dynamicText(theme: themeManager.currentTheme))
        }
        .disabled(action == nil)
        .animation(DesignSystem.Animation.fast, value: isSelected)
    }
}

// MARK: - Progress Bar

struct ProgressBarView: View {
    @EnvironmentObject var themeManager: ThemeManager
    let value: Double // 0.0 to 1.0
    var height: CGFloat = 8

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: height / 2)
                    .fill(Color.dynamicBackground(theme: themeManager.currentTheme))

                RoundedRectangle(cornerRadius: height / 2)
                    .fill(Color.dynamicSurface(theme: themeManager.currentTheme))
                    .frame(width: geometry.size.width * min(max(value, 0), 1))
                    .animation(DesignSystem.Animation.medium, value: value)
            }
        }
        .frame(height: height)
    }
}

// MARK: - Extension for Easy Access

extension View {
    func cardStyle(padding: CGFloat = DesignSystem.Spacing.md,
                   cornerRadius: CGFloat = DesignSystem.CornerRadius.large) -> some View {
        CardView(padding: padding, cornerRadius: cornerRadius) {
            self
        }
    }

    func glassCardStyle(padding: CGFloat = DesignSystem.Spacing.md) -> some View {
        GlassCardView(padding: padding) {
            self
        }
    }
}