//
//  StoryDesignTokens.swift
//  Gym_API
//
//  Design tokens extraídos de Stream Based Mobile UI Kit
//  y optimizados para Stories de Instagram
//

import SwiftUI

struct StoryDesignTokens {

    // MARK: - Tamaños (extraídos de Stream Figma)

    /// Tamaño del anillo exterior del avatar
    static let avatarRingSize: CGFloat = 84

    /// Tamaño de la imagen del avatar
    static let avatarImageSize: CGFloat = 76

    /// Ancho del anillo de progreso
    static let ringWidth: CGFloat = 3.0

    /// Altura de las barras de progreso
    static let progressBarHeight: CGFloat = 2

    /// Espaciado entre barras de progreso
    static let progressBarSpacing: CGFloat = 4

    /// Radio de esquinas para componentes
    static let cornerRadius: CGFloat = 12

    /// Tamaño del botón de agregar (+)
    static let addButtonSize: CGFloat = 24

    // MARK: - Espaciados

    /// Espaciado horizontal entre avatares
    static let avatarSpacing: CGFloat = 14

    /// Padding horizontal de la barra de stories
    static let barHorizontalPadding: CGFloat = 12

    /// Altura total de la barra de stories
    static let barHeight: CGFloat = 116

    /// Padding del contenido del viewer
    static let viewerContentPadding: CGFloat = 16

    // MARK: - Duraciones de animación

    /// Duración por defecto de cada story (segundos)
    static let defaultStoryDuration: TimeInterval = 5.0

    /// Duración de la animación de transición
    static let transitionDuration: TimeInterval = 0.3

    /// Duración de la animación de reacción
    static let reactionAnimationDuration: TimeInterval = 0.5

    /// Intervalo de actualización del timer
    static let timerInterval: TimeInterval = 0.05

    // MARK: - Gradientes de Instagram Stories

    /// Gradiente para stories no vistas (Instagram auténtico)
    static let instagramUnseenGradient = LinearGradient(
        gradient: Gradient(colors: [
            Color(red: 193/255, green: 53/255, blue: 132/255),  // Púrpura
            Color(red: 253/255, green: 29/255, blue: 29/255),   // Rojo
            Color(red: 252/255, green: 176/255, blue: 69/255)   // Naranja
        ]),
        startPoint: .topTrailing,
        endPoint: .bottomLeading
    )

    /// Gradiente para el tema rojo del gym (alternativo)
    static let gymRedGradient = LinearGradient(
        colors: [
            Color(hex: "D93333") ?? Color.red,
            Color(hex: "FF6B6B") ?? Color.red.opacity(0.8)
        ],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    /// Gradiente dorado para achievements
    static let goldenGradient = LinearGradient(
        gradient: Gradient(colors: [
            Color(red: 255/255, green: 215/255, blue: 0/255),   // Dorado brillante
            Color(red: 255/255, green: 165/255, blue: 0/255),   // Naranja dorado
            Color(red: 218/255, green: 165/255, blue: 32/255)   // Dorado oscuro
        ]),
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    // MARK: - Colores de Estado

    /// Color del anillo para stories vistas
    static let seenRingColor = Color.gray.opacity(0.3)

    /// Color del botón de agregar (Instagram azul)
    static let instagramBlue = Color(red: 0/255, green: 149/255, blue: 246/255)

    /// Color de fondo del viewer
    static let viewerBackgroundColor = Color.black

    /// Color de overlay de pausado
    static let pauseOverlayColor = Color.black.opacity(0.3)

    // MARK: - Tipografía

    /// Tamaño de fuente para username bajo avatar
    static let usernameFont: Font = .system(size: 11)

    /// Tamaño de fuente para caption
    static let captionFont: Font = .body

    /// Tamaño de fuente para stats
    static let statsFont: Font = .caption

    /// Tamaño de fuente para headers
    static let headerFont: Font = .footnote

    // MARK: - Opacidades

    /// Opacidad del material blur
    static let materialOpacity: Double = 0.8

    /// Opacidad del texto secundario
    static let secondaryTextOpacity: Double = 0.8

    /// Opacidad del background de caption
    static let captionBackgroundOpacity: Double = 0.2

    // MARK: - Umbrales de Gestos

    /// Distancia mínima para trigger de swipe horizontal
    static let swipeThresholdHorizontal: CGFloat = 100

    /// Distancia mínima para trigger de swipe vertical (dismiss)
    static let swipeThresholdVertical: CGFloat = 100

    /// Duración mínima de long press para pausar
    static let longPressDuration: TimeInterval = 0.1

    /// Proporción de pantalla para área de tap anterior (30%)
    static let previousTapAreaRatio: CGFloat = 0.3

    /// Proporción de pantalla para área de tap siguiente (30%)
    static let nextTapAreaRatio: CGFloat = 0.3

    // MARK: - Caché

    /// Tiempo de validez del caché (segundos)
    static let cacheValidityDuration: TimeInterval = 60

    /// Número de stories a pre-cargar
    static let preloadCount: Int = 3

    /// Límite de memoria para caché (MB)
    static let cacheMemoryLimit: Int = 50

    // MARK: - Límites de Contenido

    /// Tamaño máximo de imagen (MB)
    static let maxImageSizeMB: Int = 10

    /// Tamaño máximo de video (MB)
    static let maxVideoSizeMB: Int = 50

    /// Duración máxima de video (segundos)
    static let maxVideoDurationSeconds: Int = 60

    /// Número máximo de caracteres en caption
    static let maxCaptionLength: Int = 500

    // MARK: - Helpers

    /// Determina el gradiente correcto basado en el tema de la app
    static func ringGradient(for theme: ThemeManager.AppTheme, useInstagram: Bool = true) -> LinearGradient {
        if useInstagram {
            return instagramUnseenGradient
        } else {
            return gymRedGradient
        }
    }

    /// Calcula el tamaño del avatar interno considerando el padding del anillo
    static func innerAvatarSize(hasRing: Bool) -> CGFloat {
        return hasRing ? avatarImageSize : avatarRingSize - 6
    }

    /// Calcula el ancho del área de tap para navegación
    static func tapAreaWidth(screenWidth: CGFloat, ratio: CGFloat) -> CGFloat {
        return screenWidth * ratio
    }
}

// MARK: - Story Animation Presets

struct StoryAnimations {
    /// Animación de entrada de story
    static let storyEntry = Animation.spring(response: 0.3, dampingFraction: 0.8)

    /// Animación de salida de story
    static let storyExit = Animation.easeOut(duration: 0.2)

    /// Animación de progreso de barra
    static let progressBar = Animation.linear(duration: StoryDesignTokens.timerInterval)

    /// Animación de tap (scale effect)
    static let tapScale = Animation.easeInOut(duration: 0.1)

    /// Animación de reacción (bounce)
    static let reactionBounce = Animation.spring(response: 0.3, dampingFraction: 0.6)

    /// Animación de drag
    static let drag = Animation.spring()
}

// MARK: - Haptic Feedback Helpers

struct StoryHaptics {
    /// Feedback ligero para tap en avatar
    static func avatarTap() {
        let impactFeedback = UIImpactFeedbackGenerator(style: .light)
        impactFeedback.impactOccurred()
    }

    /// Feedback medio para navegación entre stories
    static func storyTransition() {
        let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
        impactFeedback.impactOccurred()
    }

    /// Feedback de éxito para reacción enviada
    static func reactionSent() {
        let notificationFeedback = UINotificationFeedbackGenerator()
        notificationFeedback.notificationOccurred(.success)
    }

    /// Feedback de error
    static func error() {
        let notificationFeedback = UINotificationFeedbackGenerator()
        notificationFeedback.notificationOccurred(.error)
    }
}
