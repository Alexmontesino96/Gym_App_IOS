//
//  StoryCreation.swift
//  Gym_API
//
//  Models for story creation workflow
//

import SwiftUI
import UIKit

// MARK: - Story Draft
/// Represents a story being created
struct StoryDraft {
    var id = UUID()
    var backgroundImage: UIImage?
    var backgroundColor: Color = .red
    var textElements: [StoryTextElement] = []
    var drawings: [StoryDrawing] = []
    var stickers: [StorySticker] = []
    var caption: String = ""
    var duration: Int = 5

    var hasContent: Bool {
        backgroundImage != nil || !textElements.isEmpty || !drawings.isEmpty
    }
}

// MARK: - Story Text Element
struct StoryTextElement: Identifiable {
    let id = UUID()
    var text: String
    var font: StoryFont = .bold
    var textColor: Color = .white
    var backgroundColor: Color?
    var position: CGPoint = CGPoint(x: 0.5, y: 0.5) // Normalized 0-1
    var scale: CGFloat = 1.0
    var rotation: Angle = .zero
    var alignment: TextAlignment = .center
}

// MARK: - Story Drawing
struct StoryDrawing: Identifiable {
    let id = UUID()
    var paths: [DrawingPath]
    var color: Color
    var lineWidth: CGFloat
}

struct DrawingPath {
    var points: [CGPoint]
}

// MARK: - Story Sticker
struct StorySticker: Identifiable {
    let id = UUID()
    var type: StickerType
    var position: CGPoint = CGPoint(x: 0.5, y: 0.5)
    var scale: CGFloat = 1.0
    var rotation: Angle = .zero
}

enum StickerType {
    case emoji(String)
    case gif(String)
    case location(String)
    case mention(String)
    case poll(String, [String])
    case countdown(Date)
}

// MARK: - Story Fonts
enum StoryFont: String, CaseIterable {
    case classic = "Classic"
    case modern = "Modern"
    case neon = "Neon"
    case typewriter = "Typewriter"
    case strong = "Strong"
    case bold = "Bold"

    var systemFont: Font {
        switch self {
        case .classic:
            return .system(size: 32, weight: .regular, design: .serif)
        case .modern:
            return .system(size: 32, weight: .medium, design: .default)
        case .neon:
            return .system(size: 32, weight: .bold, design: .rounded)
        case .typewriter:
            return .system(size: 32, weight: .regular, design: .monospaced)
        case .strong:
            return .system(size: 32, weight: .heavy, design: .default)
        case .bold:
            return .system(size: 32, weight: .bold, design: .default)
        }
    }

    func uiFont(size: CGFloat) -> UIFont {
        switch self {
        case .classic:
            return UIFont.systemFont(ofSize: size, weight: .regular)
        case .modern:
            return UIFont.systemFont(ofSize: size, weight: .medium)
        case .neon:
            return UIFont.systemFont(ofSize: size, weight: .bold)
        case .typewriter:
            return UIFont.monospacedSystemFont(ofSize: size, weight: .regular)
        case .strong:
            return UIFont.systemFont(ofSize: size, weight: .heavy)
        case .bold:
            return UIFont.systemFont(ofSize: size, weight: .bold)
        }
    }
}

// MARK: - Story Background Type
enum StoryBackgroundType {
    case camera
    case color(Color)
    case gradient([Color])
    case image(UIImage)
}

// MARK: - Story Tool
enum StoryTool {
    case text
    case draw
    case sticker
    case background
}

// MARK: - Drawing Colors
struct DrawingColor {
    static let colors: [Color] = [
        .white,
        .black,
        Color(red: 0.85, green: 0.26, blue: 0.22), // Red
        Color(red: 1.0, green: 0.42, blue: 0.0),   // Orange
        Color(red: 1.0, green: 0.8, blue: 0.0),    // Yellow
        Color(red: 0.3, green: 0.69, blue: 0.31),  // Green
        Color(red: 0.13, green: 0.59, blue: 0.95), // Blue
        Color(red: 0.61, green: 0.15, blue: 0.69), // Purple
        Color(red: 0.91, green: 0.12, blue: 0.39)  // Pink
    ]
}

// MARK: - Text Alignment
enum TextAlignment {
    case left
    case center
    case right

    var swiftUIAlignment: Alignment {
        switch self {
        case .left: return .leading
        case .center: return .center
        case .right: return .trailing
        }
    }
}
