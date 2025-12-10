//
//  BadgeView.swift
//  Gym_API
//
//  Created by Claude on 3/12/2025.
//

import SwiftUI

/// Componente reutilizable para mostrar badges de notificación con contador
/// Usado para indicar mensajes no leídos, notificaciones pendientes, etc.
struct NotificationBadgeView: View {
    // MARK: - Properties
    let count: Int
    let size: BadgeSize

    // MARK: - Badge Size Enum

    enum BadgeSize {
        case small  // 16x16 - Para íconos pequeños en tabs
        case medium // 20x20 - Para íconos medianos
        case large  // 24x24 - Para headers y destacados

        var diameter: CGFloat {
            switch self {
            case .small: return 16
            case .medium: return 20
            case .large: return 24
            }
        }

        var fontSize: CGFloat {
            switch self {
            case .small: return 10
            case .medium: return 12
            case .large: return 14
            }
        }

        var padding: CGFloat {
            switch self {
            case .small: return 2
            case .medium: return 3
            case .large: return 4
            }
        }
    }

    // MARK: - Body

    var body: some View {
        if count > 0 {
            ZStack {
                // Círculo rojo de fondo
                Circle()
                    .fill(Color.red)
                    .frame(width: size.diameter, height: size.diameter)

                // Texto del contador
                Text(formattedCount)
                    .font(.system(size: size.fontSize, weight: .bold))
                    .foregroundColor(.white)
                    .minimumScaleFactor(0.5)
                    .lineLimit(1)
                    .padding(.horizontal, size.padding)
            }
            .shadow(color: Color.black.opacity(0.3), radius: 2, x: 0, y: 1)
            .transition(.scale.combined(with: .opacity))
            .animation(.spring(response: 0.3, dampingFraction: 0.6), value: count)
        }
    }

    // MARK: - Computed Properties

    /// Formatea el contador para mostrar (99+ si es mayor a 99)
    private var formattedCount: String {
        if count > 99 {
            return "99+"
        }
        return "\(count)"
    }
}

// MARK: - Badge Modifier Extension

extension View {
    /// Agrega un badge de notificación a cualquier vista
    /// - Parameters:
    ///   - count: Número de notificaciones
    ///   - size: Tamaño del badge
    ///   - alignment: Alineación del badge respecto a la vista
    ///   - offset: Offset adicional para ajuste fino
    func notificationBadge(
        count: Int,
        size: NotificationBadgeView.BadgeSize = .medium,
        alignment: Alignment = .topTrailing,
        offset: CGSize = CGSize(width: 8, height: -8)
    ) -> some View {
        overlay(alignment: alignment) {
            if count > 0 {
                NotificationBadgeView(count: count, size: size)
                    .offset(x: offset.width, y: offset.height)
            }
        }
    }
}

// MARK: - Previews

#Preview("Badge Sizes") {
    VStack(spacing: 30) {
        Text("Badge Sizes Demo")
            .font(.headline)

        HStack(spacing: 40) {
            VStack {
                NotificationBadgeView(count: 5, size: .small)
                Text("Small").font(.caption)
            }

            VStack {
                NotificationBadgeView(count: 42, size: .medium)
                Text("Medium").font(.caption)
            }

            VStack {
                NotificationBadgeView(count: 150, size: .large)
                Text("Large (99+)").font(.caption)
            }
        }

        Divider().padding(.vertical)

        Text("Badge Modifier Demo")
            .font(.headline)

        HStack(spacing: 40) {
            Image(systemName: "envelope")
                .font(.system(size: 30))
                .notificationBadge(count: 3, size: .small)

            Image(systemName: "bell")
                .font(.system(size: 30))
                .notificationBadge(count: 12, size: .medium)

            Image(systemName: "message")
                .font(.system(size: 30))
                .notificationBadge(count: 999, size: .large)
        }
    }
    .padding()
}

#Preview("Badge in Tab Bar Icon") {
    TabView {
        Text("Content")
            .tabItem {
                Label {
                    Text("Messages")
                } icon: {
                    Image(systemName: "message")
                        .notificationBadge(count: 5, size: .small, offset: CGSize(width: 10, height: -8))
                }
            }
    }
}

#Preview("Badge Animation") {
    struct AnimatedBadgePreview: View {
        @State private var count = 0

        var body: some View {
            VStack(spacing: 20) {
                NotificationBadgeView(count: count, size: .large)

                HStack(spacing: 20) {
                    Button("Increment") {
                        withAnimation {
                            count += 1
                        }
                    }
                    .buttonStyle(.borderedProminent)

                    Button("Decrement") {
                        withAnimation {
                            count = max(0, count - 1)
                        }
                    }
                    .buttonStyle(.bordered)

                    Button("Reset") {
                        withAnimation {
                            count = 0
                        }
                    }
                    .buttonStyle(.bordered)
                }
            }
            .padding()
        }
    }

    return AnimatedBadgePreview()
}
