//
//  AspectRatio.swift
//  Gym_API
//
//  Created by Claude Code
//

import Foundation
import SwiftUI

/// Formatos de aspect ratio soportados al estilo Instagram
enum AspectRatio: String, CaseIterable, Identifiable, Codable {
    case square1x1 = "1:1"
    case portrait4x5 = "4:5"
    case landscape1_91x1 = "1.91:1"

    var id: String { rawValue }

    /// Ratio numérico (ancho / alto)
    var ratio: CGFloat {
        switch self {
        case .square1x1: return 1.0
        case .portrait4x5: return 0.8
        case .landscape1_91x1: return 1.91
        }
    }

    /// Tamaño de imagen recomendado por Instagram (ancho x alto en píxeles)
    var instagramSize: CGSize {
        switch self {
        case .square1x1: return CGSize(width: 1080, height: 1080)
        case .portrait4x5: return CGSize(width: 1080, height: 1350)
        case .landscape1_91x1: return CGSize(width: 1080, height: 566)
        }
    }

    /// Nombre para mostrar en UI
    var displayName: String {
        switch self {
        case .square1x1: return "Cuadrado"
        case .portrait4x5: return "Vertical"
        case .landscape1_91x1: return "Horizontal"
        }
    }

    /// Ícono SF Symbol
    var iconName: String {
        switch self {
        case .square1x1: return "square"
        case .portrait4x5: return "rectangle.portrait"
        case .landscape1_91x1: return "rectangle"
        }
    }

    /// Calcula la altura recomendada para un ancho dado
    func height(forWidth width: CGFloat) -> CGFloat {
        return width / ratio
    }

    /// Calcula el ancho recomendado para una altura dada
    func width(forHeight height: CGFloat) -> CGFloat {
        return height * ratio
    }

    /// Detecta el aspect ratio más cercano para una imagen dada
    static func detect(from imageSize: CGSize) -> AspectRatio {
        let imageRatio = imageSize.width / imageSize.height

        // Encuentra el ratio más cercano
        let ratios: [(AspectRatio, CGFloat)] = [
            (.square1x1, abs(imageRatio - 1.0)),
            (.portrait4x5, abs(imageRatio - 0.8)),
            (.landscape1_91x1, abs(imageRatio - 1.91))
        ]

        return ratios.min(by: { $0.1 < $1.1 })?.0 ?? .square1x1
    }
}
