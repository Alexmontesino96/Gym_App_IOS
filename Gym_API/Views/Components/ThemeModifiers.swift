import SwiftUI

// MARK: - Theme-Aware ViewModifiers
/// Colección de ViewModifiers reutilizables para aplicar estilos consistentes con el tema actual

// MARK: - Basic Theme Modifier
struct ThemeAwareModifier: ViewModifier {
    let themeManager: ThemeManager
    
    func body(content: Content) -> some View {
        content
            .foregroundColor(Color.dynamicText(theme: themeManager.currentTheme))
            .background(Color.dynamicSurface(theme: themeManager.currentTheme))
    }
}

// MARK: - Theme Background Modifier
struct ThemeBackgroundModifier: ViewModifier {
    let themeManager: ThemeManager
    let ignoresSafeArea: Bool
    
    init(themeManager: ThemeManager, ignoresSafeArea: Bool = true) {
        self.themeManager = themeManager
        self.ignoresSafeArea = ignoresSafeArea
    }
    
    func body(content: Content) -> some View {
        content
            .background(
                Color.dynamicBackground(theme: themeManager.currentTheme)
                    .ignoresSafeArea(ignoresSafeArea ? .all : [])
            )
    }
}

// MARK: - Theme Card Modifier
struct ThemeCardModifier: ViewModifier {
    let themeManager: ThemeManager
    let cornerRadius: CGFloat
    let shadowRadius: CGFloat
    let padding: EdgeInsets
    
    init(
        themeManager: ThemeManager,
        cornerRadius: CGFloat = 16,
        shadowRadius: CGFloat = 5,
        padding: EdgeInsets = EdgeInsets(top: 16, leading: 16, bottom: 16, trailing: 16)
    ) {
        self.themeManager = themeManager
        self.cornerRadius = cornerRadius
        self.shadowRadius = shadowRadius
        self.padding = padding
    }
    
    func body(content: Content) -> some View {
        content
            .padding(padding)
            .background(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .fill(Color.dynamicSurface(theme: themeManager.currentTheme))
                    .shadow(color: Color.black.opacity(0.1), radius: shadowRadius, x: 0, y: 2)
            )
    }
}

// MARK: - Theme Button Modifier
struct ThemeButtonModifier: ViewModifier {
    let themeManager: ThemeManager
    let style: ButtonStyle
    let cornerRadius: CGFloat
    
    enum ButtonStyle {
        case primary
        case secondary
        case destructive
        case ghost
    }
    
    init(themeManager: ThemeManager, style: ButtonStyle = .primary, cornerRadius: CGFloat = 12) {
        self.themeManager = themeManager
        self.style = style
        self.cornerRadius = cornerRadius
    }
    
    func body(content: Content) -> some View {
        content
            .foregroundColor(foregroundColor)
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(backgroundColor)
            .cornerRadius(cornerRadius)
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .stroke(borderColor, lineWidth: borderWidth)
            )
    }
    
    private var foregroundColor: Color {
        switch style {
        case .primary:
            return .white
        case .secondary:
            return Color.dynamicText(theme: themeManager.currentTheme)
        case .destructive:
            return .white
        case .ghost:
            return .red
        }
    }
    
    private var backgroundColor: Color {
        switch style {
        case .primary:
            return .red
        case .secondary:
            return Color.dynamicSurface(theme: themeManager.currentTheme)
        case .destructive:
            return .red
        case .ghost:
            return Color.clear
        }
    }
    
    private var borderColor: Color {
        switch style {
        case .primary, .destructive:
            return Color.clear
        case .secondary:
            return Color.dynamicText(theme: themeManager.currentTheme).opacity(0.2)
        case .ghost:
            return .red
        }
    }
    
    private var borderWidth: CGFloat {
        switch style {
        case .primary, .destructive:
            return 0
        case .secondary, .ghost:
            return 1
        }
    }
}

// MARK: - Theme Text Field Modifier
struct ThemeTextFieldModifier: ViewModifier {
    let themeManager: ThemeManager
    let cornerRadius: CGFloat
    let borderWidth: CGFloat
    
    init(themeManager: ThemeManager, cornerRadius: CGFloat = 8, borderWidth: CGFloat = 1) {
        self.themeManager = themeManager
        self.cornerRadius = cornerRadius
        self.borderWidth = borderWidth
    }
    
    func body(content: Content) -> some View {
        content
            .foregroundColor(Color.dynamicText(theme: themeManager.currentTheme))
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(Color.dynamicSurface(theme: themeManager.currentTheme))
            .cornerRadius(cornerRadius)
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .stroke(Color.dynamicText(theme: themeManager.currentTheme).opacity(0.2), lineWidth: borderWidth)
            )
    }
}

// MARK: - Theme List Row Modifier
struct ThemeListRowModifier: ViewModifier {
    let themeManager: ThemeManager
    let isFirst: Bool
    let isLast: Bool
    let cornerRadius: CGFloat
    
    init(themeManager: ThemeManager, isFirst: Bool = false, isLast: Bool = false, cornerRadius: CGFloat = 12) {
        self.themeManager = themeManager
        self.isFirst = isFirst
        self.isLast = isLast
        self.cornerRadius = cornerRadius
    }
    
    func body(content: Content) -> some View {
        content
            .foregroundColor(Color.dynamicText(theme: themeManager.currentTheme))
            .background(Color.dynamicSurface(theme: themeManager.currentTheme))
            .clipShape(
                RoundedCorners(
                    radius: cornerRadius,
                    corners: corners
                )
            )
            .overlay(
                RoundedCorners(
                    radius: cornerRadius,
                    corners: corners
                )
                .stroke(Color.dynamicText(theme: themeManager.currentTheme).opacity(0.1), lineWidth: 1)
            )
    }
    
    private var corners: UIRectCorner {
        if isFirst && isLast {
            return .allCorners
        } else if isFirst {
            return [.topLeft, .topRight]
        } else if isLast {
            return [.bottomLeft, .bottomRight]
        } else {
            return []
        }
    }
}

// MARK: - Theme Status Badge Modifier
struct ThemeStatusBadgeModifier: ViewModifier {
    let themeManager: ThemeManager
    let status: Status
    let size: Size
    
    enum Status {
        case active
        case inactive
        case warning
        case error
        case info
        
        var color: Color {
            switch self {
            case .active:
                return .green
            case .inactive:
                return .gray
            case .warning:
                return .orange
            case .error:
                return .red
            case .info:
                return .blue
            }
        }
    }
    
    enum Size {
        case small
        case medium
        case large
        
        var padding: EdgeInsets {
            switch self {
            case .small:
                return EdgeInsets(top: 4, leading: 8, bottom: 4, trailing: 8)
            case .medium:
                return EdgeInsets(top: 6, leading: 12, bottom: 6, trailing: 12)
            case .large:
                return EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16)
            }
        }
        
        var fontSize: Font {
            switch self {
            case .small:
                return .caption2
            case .medium:
                return .caption
            case .large:
                return .subheadline
            }
        }
    }
    
    func body(content: Content) -> some View {
        content
            .font(size.fontSize)
            .fontWeight(.medium)
            .foregroundColor(.white)
            .padding(size.padding)
            .background(status.color)
            .cornerRadius(size == .small ? 6 : (size == .medium ? 8 : 10))
    }
}

// MARK: - Theme Loading Modifier
struct ThemeLoadingModifier: ViewModifier {
    let themeManager: ThemeManager
    let isLoading: Bool
    let message: String
    
    init(themeManager: ThemeManager, isLoading: Bool, message: String = "Cargando...") {
        self.themeManager = themeManager
        self.isLoading = isLoading
        self.message = message
    }
    
    func body(content: Content) -> some View {
        ZStack {
            content
                .disabled(isLoading)
                .opacity(isLoading ? 0.5 : 1.0)
            
            if isLoading {
                VStack(spacing: 12) {
                    ProgressView()
                        .scaleEffect(1.2)
                        .progressViewStyle(CircularProgressViewStyle(tint: .red))
                    
                    Text(message)
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(Color.dynamicText(theme: themeManager.currentTheme))
                }
                .padding(24)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.dynamicSurface(theme: themeManager.currentTheme))
                        .shadow(color: Color.black.opacity(0.2), radius: 10, x: 0, y: 5)
                )
            }
        }
    }
}

// MARK: - Supporting Views
struct RoundedCorners: Shape {
    let radius: CGFloat
    let corners: UIRectCorner
    
    func path(in rect: CGRect) -> Path {
        let path = UIBezierPath(
            roundedRect: rect,
            byRoundingCorners: corners,
            cornerRadii: CGSize(width: radius, height: radius)
        )
        return Path(path.cgPath)
    }
}

// MARK: - View Extensions
extension View {
    /// Aplica estilos básicos respetando el tema actual
    func themeAware(themeManager: ThemeManager) -> some View {
        self.modifier(ThemeAwareModifier(themeManager: themeManager))
    }
    
    /// Aplica fondo dinámico respetando el tema actual
    func themeBackground(themeManager: ThemeManager, ignoresSafeArea: Bool = true) -> some View {
        self.modifier(ThemeBackgroundModifier(themeManager: themeManager, ignoresSafeArea: ignoresSafeArea))
    }
    
    /// Aplica estilos de tarjeta respetando el tema actual
    func themeCard(
        themeManager: ThemeManager,
        cornerRadius: CGFloat = 16,
        shadowRadius: CGFloat = 5,
        padding: EdgeInsets = EdgeInsets(top: 16, leading: 16, bottom: 16, trailing: 16)
    ) -> some View {
        self.modifier(ThemeCardModifier(
            themeManager: themeManager,
            cornerRadius: cornerRadius,
            shadowRadius: shadowRadius,
            padding: padding
        ))
    }
    
    /// Aplica estilos de botón respetando el tema actual
    func themeButton(
        themeManager: ThemeManager,
        style: ThemeButtonModifier.ButtonStyle = .primary,
        cornerRadius: CGFloat = 12
    ) -> some View {
        self.modifier(ThemeButtonModifier(
            themeManager: themeManager,
            style: style,
            cornerRadius: cornerRadius
        ))
    }
    
    /// Aplica estilos de campo de texto respetando el tema actual
    func themeTextField(
        themeManager: ThemeManager,
        cornerRadius: CGFloat = 8,
        borderWidth: CGFloat = 1
    ) -> some View {
        self.modifier(ThemeTextFieldModifier(
            themeManager: themeManager,
            cornerRadius: cornerRadius,
            borderWidth: borderWidth
        ))
    }
    
    /// Aplica estilos de fila de lista respetando el tema actual
    func themeListRow(
        themeManager: ThemeManager,
        isFirst: Bool = false,
        isLast: Bool = false,
        cornerRadius: CGFloat = 12
    ) -> some View {
        self.modifier(ThemeListRowModifier(
            themeManager: themeManager,
            isFirst: isFirst,
            isLast: isLast,
            cornerRadius: cornerRadius
        ))
    }
    
    /// Aplica estilos de badge de estado respetando el tema actual
    func themeStatusBadge(
        themeManager: ThemeManager,
        status: ThemeStatusBadgeModifier.Status,
        size: ThemeStatusBadgeModifier.Size = .medium
    ) -> some View {
        self.modifier(ThemeStatusBadgeModifier(
            themeManager: themeManager,
            status: status,
            size: size
        ))
    }
    
    /// Aplica overlay de carga respetando el tema actual
    func themeLoading(
        themeManager: ThemeManager,
        isLoading: Bool,
        message: String = "Cargando..."
    ) -> some View {
        self.modifier(ThemeLoadingModifier(
            themeManager: themeManager,
            isLoading: isLoading,
            message: message
        ))
    }
}

// MARK: - Usage Examples
/*
 
 // Uso básico:
 Text("Hola mundo")
     .themeAware(themeManager: themeManager)
 
 // Fondo temático:
 VStack {
     // contenido
 }
 .themeBackground(themeManager: themeManager)
 
 // Tarjeta temática:
 VStack {
     Text("Contenido de la tarjeta")
 }
 .themeCard(themeManager: themeManager)
 
 // Botón temático:
 Text("Botón Primario")
     .themeButton(themeManager: themeManager, style: .primary)
 
 // Campo de texto temático:
 TextField("Buscar...", text: $searchText)
     .themeTextField(themeManager: themeManager)
 
 // Badge de estado:
 Text("Activo")
     .themeStatusBadge(themeManager: themeManager, status: .active)
 
 // Vista con loading:
 VStack {
     // contenido
 }
 .themeLoading(themeManager: themeManager, isLoading: isLoading, message: "Cargando datos...")
 
 */