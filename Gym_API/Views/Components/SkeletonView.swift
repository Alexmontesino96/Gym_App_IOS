import SwiftUI

/// Componente reutilizable para mostrar animaciones de esqueleto durante la carga
struct SkeletonView: View {
    let width: CGFloat?
    let height: CGFloat
    let cornerRadius: CGFloat
    
    @State private var isAnimating = false
    @EnvironmentObject var themeManager: ThemeManager
    
    init(width: CGFloat? = nil, height: CGFloat = 20, cornerRadius: CGFloat = 8) {
        self.width = width
        self.height = height
        self.cornerRadius = cornerRadius
    }
    
    var body: some View {
        RoundedRectangle(cornerRadius: cornerRadius)
            .fill(
                LinearGradient(
                    gradient: Gradient(colors: [
                        skeletonBaseColor,
                        skeletonHighlightColor,
                        skeletonBaseColor
                    ]),
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .frame(width: width, height: height)
            .scaleEffect(x: isAnimating ? 1.0 : 0.95, y: 1.0)
            .opacity(isAnimating ? 0.6 : 1.0)
            .animation(
                Animation.easeInOut(duration: 1.2)
                    .repeatForever(autoreverses: true),
                value: isAnimating
            )
            .onAppear {
                isAnimating = true
            }
    }
    
    private var skeletonBaseColor: Color {
        themeManager.currentTheme == .dark 
            ? Color.gray.opacity(0.3)
            : Color.gray.opacity(0.2)
    }
    
    private var skeletonHighlightColor: Color {
        themeManager.currentTheme == .dark 
            ? Color.gray.opacity(0.4)
            : Color.gray.opacity(0.3)
    }
}

/// Skeleton específico para filas de conversación
struct ConversationRowSkeleton: View {
    @EnvironmentObject var themeManager: ThemeManager
    
    var body: some View {
        HStack(spacing: 16) {
            // Avatar skeleton
            Circle()
                .fill(skeletonBaseColor)
                .frame(width: 56, height: 56)
                .overlay(
                    Circle()
                        .fill(
                            LinearGradient(
                                gradient: Gradient(colors: [
                                    Color.clear,
                                    skeletonHighlightColor,
                                    Color.clear
                                ]),
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .scaleEffect(shimmerScale)
                        .animation(
                            Animation.easeInOut(duration: 1.5)
                                .repeatForever(autoreverses: false),
                            value: shimmerScale
                        )
                )
            
            // Content skeleton
            VStack(alignment: .leading, spacing: 8) {
                // Top row
                HStack {
                    SkeletonView(width: 120, height: 16, cornerRadius: 4)
                    Spacer()
                    SkeletonView(width: 50, height: 12, cornerRadius: 3)
                }
                
                // Bottom row
                HStack {
                    SkeletonView(width: 200, height: 14, cornerRadius: 4)
                    Spacer()
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }
    
    @State private var shimmerScale: CGFloat = 0.8
    
    private var skeletonBaseColor: Color {
        themeManager.currentTheme == .dark 
            ? Color.gray.opacity(0.3)
            : Color.gray.opacity(0.2)
    }
    
    private var skeletonHighlightColor: Color {
        themeManager.currentTheme == .dark 
            ? Color.white.opacity(0.1)
            : Color.white.opacity(0.4)
    }
}

/// Skeleton específico para mensajes
struct MessageBubbleSkeleton: View {
    let isFromCurrentUser: Bool
    @EnvironmentObject var themeManager: ThemeManager
    
    var body: some View {
        HStack(alignment: .bottom, spacing: 8) {
            if isFromCurrentUser {
                Spacer(minLength: 60)
            } else {
                // Avatar skeleton
                Circle()
                    .fill(skeletonBaseColor)
                    .frame(width: 32, height: 32)
            }
            
            VStack(alignment: isFromCurrentUser ? .trailing : .leading, spacing: 4) {
                // Message bubble skeleton
                VStack(alignment: isFromCurrentUser ? .trailing : .leading, spacing: 4) {
                    SkeletonView(
                        width: CGFloat.random(in: 100...250),
                        height: 40,
                        cornerRadius: 20
                    )
                    
                    SkeletonView(width: 60, height: 12, cornerRadius: 3)
                }
            }
            
            if !isFromCurrentUser {
                Spacer(minLength: 60)
            }
        }
        .padding(.vertical, 2)
    }
    
    private var skeletonBaseColor: Color {
        themeManager.currentTheme == .dark 
            ? Color.gray.opacity(0.3)
            : Color.gray.opacity(0.2)
    }
}

/// Lista de skeletons para conversaciones
struct ConversationListSkeleton: View {
    let count: Int
    
    init(count: Int = 8) {
        self.count = count
    }
    
    var body: some View {
        LazyVStack(spacing: 1) {
            ForEach(0..<count, id: \.self) { index in
                ConversationRowSkeleton()
                    .opacity(1.0 - (Double(index) * 0.1))
                
                if index < count - 1 {
                    Divider()
                        .background(Color.gray.opacity(0.2))
                        .padding(.leading, 72)
                }
            }
        }
    }
}

/// Lista de skeletons para mensajes
struct MessageListSkeleton: View {
    let count: Int
    
    init(count: Int = 10) {
        self.count = count
    }
    
    var body: some View {
        LazyVStack(spacing: 8) {
            ForEach(0..<count, id: \.self) { index in
                MessageBubbleSkeleton(
                    isFromCurrentUser: Bool.random()
                )
                .opacity(1.0 - (Double(index) * 0.05))
            }
        }
        .padding(.horizontal)
    }
}

// MARK: - Convenience Extensions
extension SkeletonView {
    /// Skeleton pequeño para elementos secundarios
    static func small() -> SkeletonView {
        SkeletonView(width: 60, height: 12, cornerRadius: 3)
    }
    
    /// Skeleton mediano para títulos
    static func medium() -> SkeletonView {
        SkeletonView(width: 120, height: 16, cornerRadius: 4)
    }
    
    /// Skeleton grande para contenido principal
    static func large() -> SkeletonView {
        SkeletonView(width: 200, height: 20, cornerRadius: 6)
    }
    
    /// Skeleton circular para avatares
    static func circle(size: CGFloat = 40) -> some View {
        Circle()
            .fill(Color.gray.opacity(0.3))
            .frame(width: size, height: size)
    }
}

#Preview {
    VStack(spacing: 20) {
        ConversationListSkeleton(count: 5)
        
        Divider()
        
        MessageListSkeleton(count: 5)
    }
    .environmentObject(ThemeManager())
    .padding()
}