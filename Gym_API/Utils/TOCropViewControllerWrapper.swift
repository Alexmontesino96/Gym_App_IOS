//
//  TOCropViewControllerWrapper.swift
//  Gym_API
//
//  Created by Claude Code
//  Wrapper para TOCropViewController con formatos Instagram
//

import Foundation
import SwiftUI
import UIKit
import CropViewController

/// Wrapper para configurar y usar TOCropViewController con formatos Instagram
class TOCropViewControllerWrapper {

    /// Presenta el crop view controller con los aspect ratios de Instagram
    /// - Parameters:
    ///   - image: Imagen a recortar
    ///   - presentingViewController: View controller que presenta el crop
    ///   - completion: Callback con la imagen recortada y el aspect ratio seleccionado
    @MainActor
    static func presentCropViewController(
        image: UIImage,
        from presentingViewController: UIViewController,
        completion: @escaping (UIImage?, AspectRatio?) -> Void
    ) {
        // Crear crop view controller básico
        let cropViewController = CropViewController(image: image)
        cropViewController.delegate = CropViewControllerDelegateHandler(completion: completion)

        // MARK: - Configuración UI básica
        // Permitir que el usuario ajuste el ratio libremente
        cropViewController.aspectRatioLockEnabled = false
        cropViewController.resetAspectRatioEnabled = true
        cropViewController.rotateButtonsHidden = false
        cropViewController.rotateClockwiseButtonHidden = false

        // MARK: - Personalización de colores (tema de la app)
        let appRed = UIColor(red: 217/255, green: 51/255, blue: 51/255, alpha: 1.0)
        cropViewController.toolbar.tintColor = appRed
        cropViewController.toolbar.backgroundColor = .black

        // MARK: - Textos en español
        cropViewController.doneButtonTitle = "Listo"
        cropViewController.cancelButtonTitle = "Cancelar"

        // Presentar en fullscreen
        cropViewController.modalPresentationStyle = .fullScreen

        presentingViewController.present(cropViewController, animated: true)
    }

    /// Calcula el aspect ratio real de una imagen recortada
    static func calculateAspectRatio(from image: UIImage) -> AspectRatio {
        let ratio = image.size.width / image.size.height

        // Tolerancia de ±5% para detectar el formato
        if abs(ratio - 1.0) < 0.05 {
            return .square1x1
        } else if abs(ratio - 0.8) < 0.05 {
            return .portrait4x5
        } else if abs(ratio - 1.91) < 0.1 {
            return .landscape1_91x1
        }

        // Fallback: elegir el más cercano
        if ratio < 0.9 {
            return .portrait4x5
        } else if ratio > 1.5 {
            return .landscape1_91x1
        } else {
            return .square1x1
        }
    }
}

// MARK: - Delegate Handler

/// Handler del delegate de CropViewController
private class CropViewControllerDelegateHandler: NSObject, CropViewControllerDelegate {
    private let completion: (UIImage?, AspectRatio?) -> Void

    init(completion: @escaping (UIImage?, AspectRatio?) -> Void) {
        self.completion = completion
    }

    func cropViewController(_ cropViewController: CropViewController, didCropToImage image: UIImage, withRect cropRect: CGRect, angle: Int) {
        // Calcular el aspect ratio de la imagen recortada
        let aspectRatio = TOCropViewControllerWrapper.calculateAspectRatio(from: image)

        cropViewController.dismiss(animated: true) {
            self.completion(image, aspectRatio)
        }
    }

    func cropViewController(_ cropViewController: CropViewController, didFinishCancelled cancelled: Bool) {
        cropViewController.dismiss(animated: true) {
            self.completion(nil, nil)
        }
    }
}

// MARK: - SwiftUI Wrapper (Opcional)

/// Wrapper SwiftUI para TOCropViewController
struct ImageCropView: UIViewControllerRepresentable {
    let image: UIImage
    @Binding var isPresented: Bool
    let onCropped: (UIImage, AspectRatio) -> Void

    func makeUIViewController(context: Context) -> CropViewController {
        let cropViewController = CropViewController(image: image)
        cropViewController.delegate = context.coordinator

        // Configuración UI básica
        cropViewController.aspectRatioLockEnabled = false
        cropViewController.resetAspectRatioEnabled = true
        cropViewController.rotateButtonsHidden = false
        cropViewController.rotateClockwiseButtonHidden = false

        let appRed = UIColor(red: 217/255, green: 51/255, blue: 51/255, alpha: 1.0)
        cropViewController.toolbar.tintColor = appRed
        cropViewController.toolbar.backgroundColor = .black

        cropViewController.doneButtonTitle = "Listo"
        cropViewController.cancelButtonTitle = "Cancelar"

        return cropViewController
    }

    func updateUIViewController(_ uiViewController: CropViewController, context: Context) {
        // No need to update
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(isPresented: $isPresented, onCropped: onCropped)
    }

    class Coordinator: NSObject, CropViewControllerDelegate {
        @Binding var isPresented: Bool
        let onCropped: (UIImage, AspectRatio) -> Void

        init(isPresented: Binding<Bool>, onCropped: @escaping (UIImage, AspectRatio) -> Void) {
            self._isPresented = isPresented
            self.onCropped = onCropped
        }

        func cropViewController(_ cropViewController: CropViewController, didCropToImage image: UIImage, withRect cropRect: CGRect, angle: Int) {
            let aspectRatio = TOCropViewControllerWrapper.calculateAspectRatio(from: image)
            isPresented = false
            onCropped(image, aspectRatio)
        }

        func cropViewController(_ cropViewController: CropViewController, didFinishCancelled cancelled: Bool) {
            isPresented = false
        }
    }
}
