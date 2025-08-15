import SwiftUI
import UIKit

struct CircularImageCropperView: View {
    let image: UIImage
    let onCancel: () -> Void
    let onCropped: (UIImage) -> Void
    
    @State private var scale: CGFloat = 1.0
    @State private var lastScale: CGFloat = 1.0
    @State private var offset: CGSize = .zero
    @State private var lastOffset: CGSize = .zero
    
    // Crop square size
    private let cropSize: CGFloat = 300
    private let minScale: CGFloat = 1.0
    private let maxScale: CGFloat = 4.0
    
    var body: some View {
        VStack(spacing: 16) {
            Text("Adjust your photo")
                .font(.system(size: 18, weight: .semibold))
                .padding(.top, 16)

            // Cropping area (simple and reliable)
            ZStack {
                // Image with gestures, clipped to circle for preview
                imageView
                    .frame(width: cropSize, height: cropSize)
                    .clipShape(Circle())
                    .overlay(
                        Circle().stroke(Color.white.opacity(0.8), lineWidth: 2)
                    )
                    .shadow(radius: 8)
            }
            .frame(width: cropSize, height: cropSize)
            
            HStack(spacing: 12) {
                Button(action: onCancel) {
                    Text("Cancel")
                        .foregroundColor(.primary)
                        .frame(maxWidth: .infinity)
                        .frame(height: 48)
                        .background(Color(UIColor.secondarySystemBackground))
                        .cornerRadius(12)
                }
                
                Button(action: { onCropped(cropImage()) }) {
                    Text("Use Photo")
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 48)
                        .background(Color.accentColor)
                        .cornerRadius(12)
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
        }
        .onAppear {
            // Start at 1.0 (aspectFit already applied by SwiftUI)
            scale = 1.0
            lastScale = 1.0
        }
    }
    
    private var imageView: some View {
        let drag = DragGesture()
            .onChanged { value in
                offset = CGSize(width: lastOffset.width + value.translation.width, height: lastOffset.height + value.translation.height)
            }
            .onEnded { _ in
                lastOffset = offset
            }
        
        let magnify = MagnificationGesture()
            .onChanged { value in
                var newScale = lastScale * value
                newScale = min(max(newScale, minScaleToCover()), maxScale)
                scale = newScale
            }
            .onEnded { _ in
                lastScale = scale
            }
        
        return Image(uiImage: image)
            .resizable()
            .aspectRatio(contentMode: .fit)
            .scaleEffect(scale)
            .offset(offset)
            .gesture(drag)
            .gesture(magnify)
            .background(Color.clear)
    }
    
    private func baseFitScale() -> CGFloat {
        // Scale factor used by .aspectRatio(.fit) inside a square frame
        let imgW = image.size.width
        let imgH = image.size.height
        return min(cropSize / imgW, cropSize / imgH)
    }
    
    private func minScaleToCover() -> CGFloat { 1.0 }
    
    private func cropImage() -> UIImage {
        // Render a square image matching the crop area
        let scaleFactor = UIScreen.main.scale
        let outputSize = CGSize(width: cropSize * scaleFactor, height: cropSize * scaleFactor)
        
        UIGraphicsBeginImageContextWithOptions(outputSize, true, 1.0)
        defer { UIGraphicsEndImageContext() }
        guard let ctx = UIGraphicsGetCurrentContext() else { return image }
        
        // Fill background (black) to avoid transparent corners
        UIColor.black.setFill()
        ctx.fill(CGRect(origin: .zero, size: outputSize))
        
        // Compute draw rect for the original image using current scale/offset
        let imgW = image.size.width
        let imgH = image.size.height
        let fit = baseFitScale()
        let effectiveScale = fit * scale
        let drawW = imgW * effectiveScale * scaleFactor
        let drawH = imgH * effectiveScale * scaleFactor
        let originX = ((cropSize * scaleFactor) - drawW) / 2.0 + offset.width * scaleFactor
        let originY = ((cropSize * scaleFactor) - drawH) / 2.0 + offset.height * scaleFactor
        let drawRect = CGRect(x: originX, y: originY, width: drawW, height: drawH)
        
        image.draw(in: drawRect)
        let square = UIGraphicsGetImageFromCurrentImageContext() ?? image
        
        return square
    }
}
