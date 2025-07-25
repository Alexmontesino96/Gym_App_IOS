//
//  MediaPickerView.swift
//  Gym_API
//
//  Created by Assistant on 7/24/25.
//
//  Vista para seleccionar fotos/videos desde la galería

import SwiftUI
import PhotosUI

struct MediaPickerView: View {
    @Binding var isPresented: Bool
    let onMediaSelected: ([MediaItem]) -> Void
    @State private var selectedItems: [PhotosPickerItem] = []
    @State private var selectedMedia: [MediaItem] = []
    @EnvironmentObject var themeManager: ThemeManager
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Header
                HStack {
                    Button("Cancel") {
                        isPresented = false
                    }
                    .foregroundColor(Color.dynamicAccent(theme: themeManager.currentTheme))
                    
                    Spacer()
                    
                    Text("Select Media")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundColor(Color.dynamicText(theme: themeManager.currentTheme))
                    
                    Spacer()
                    
                    Button("Send") {
                        onMediaSelected(selectedMedia)
                        isPresented = false
                    }
                    .foregroundColor(Color.dynamicAccent(theme: themeManager.currentTheme))
                    .disabled(selectedMedia.isEmpty)
                }
                .padding()
                .background(Color.dynamicSurface(theme: themeManager.currentTheme))
                
                // Photos Picker
                PhotosPicker(
                    selection: $selectedItems,
                    maxSelectionCount: 10,
                    matching: .any(of: [.images, .videos]),
                    photoLibrary: .shared()
                ) {
                    VStack(spacing: 16) {
                        Image(systemName: "photo.on.rectangle.angled")
                            .font(.system(size: 60))
                            .foregroundColor(Color.dynamicAccent(theme: themeManager.currentTheme))
                        
                        Text("Toca para seleccionar fotos o videos")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(Color.dynamicText(theme: themeManager.currentTheme))
                        
                        if !selectedMedia.isEmpty {
                            Text("\(selectedMedia.count) elementos seleccionados")
                                .font(.system(size: 14))
                                .foregroundColor(Color.dynamicTextSecondary(theme: themeManager.currentTheme))
                        }
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
                .onChange(of: selectedItems) { _, items in
                    Task {
                        await loadSelectedMedia(from: items)
                    }
                }
                
                // Selected Media Preview
                if !selectedMedia.isEmpty {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 12) {
                            ForEach(selectedMedia) { item in
                                MediaThumbnailView(
                                    item: item,
                                    onRemove: {
                                        selectedMedia.removeAll { $0.id == item.id }
                                    }
                                )
                            }
                        }
                        .padding()
                    }
                    .frame(height: 120)
                    .background(Color.dynamicBackground(theme: themeManager.currentTheme))
                }
            }
            .background(Color.dynamicBackground(theme: themeManager.currentTheme))
            .navigationBarHidden(true)
        }
    }
    
    private func loadSelectedMedia(from items: [PhotosPickerItem]) async {
        var loadedMedia: [MediaItem] = []
        
        for item in items {
            if let data = try? await item.loadTransferable(type: Data.self) {
                // Determinar si es imagen o video
                if let image = UIImage(data: data) {
                    loadedMedia.append(MediaItem(type: .image(image)))
                } else {
                    // Es un video, guardar temporalmente
                    let tempURL = FileManager.default.temporaryDirectory
                        .appendingPathComponent("\(UUID().uuidString).mp4")
                    
                    do {
                        try data.write(to: tempURL)
                        let thumbnail = await MediaUploadService.shared.generateVideoThumbnail(from: tempURL)
                        loadedMedia.append(MediaItem(type: .video(tempURL, thumbnail: thumbnail)))
                    } catch {
                        print("Error guardando video: \(error)")
                    }
                }
            }
        }
        
        await MainActor.run {
            selectedMedia = loadedMedia
        }
    }
}

// MARK: - Media Item
struct MediaItem: Identifiable {
    let id = UUID()
    let type: MediaType
}

// MARK: - Media Thumbnail View
struct MediaThumbnailView: View {
    let item: MediaItem
    let onRemove: () -> Void
    @EnvironmentObject var themeManager: ThemeManager
    
    var body: some View {
        ZStack(alignment: .topTrailing) {
            // Thumbnail
            Group {
                switch item.type {
                case .image(let image):
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 80, height: 80)
                        .clipped()
                        .cornerRadius(8)
                    
                case .video(_, let thumbnail):
                    ZStack {
                        if let thumbnail = thumbnail {
                            Image(uiImage: thumbnail)
                                .resizable()
                                .scaledToFill()
                        } else {
                            Color.gray.opacity(0.3)
                        }
                        
                        Image(systemName: "play.circle.fill")
                            .font(.system(size: 30))
                            .foregroundColor(.white)
                            .shadow(radius: 2)
                    }
                    .frame(width: 80, height: 80)
                    .clipped()
                    .cornerRadius(8)
                    
                case .voice(_, let duration):
                    ZStack {
                        Color.dynamicAccent(theme: themeManager.currentTheme).opacity(0.2)
                        
                        VStack(spacing: 4) {
                            Image(systemName: "mic.fill")
                                .font(.system(size: 20))
                                .foregroundColor(Color.dynamicAccent(theme: themeManager.currentTheme))
                            
                            Text("\(Int(duration))s")
                                .font(.system(size: 10, weight: .medium))
                                .foregroundColor(Color.dynamicText(theme: themeManager.currentTheme))
                        }
                    }
                    .frame(width: 80, height: 80)
                    .clipped()
                    .cornerRadius(8)
                }
            }
            
            // Remove button
            Button(action: onRemove) {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 20))
                    .foregroundColor(.white)
                    .background(Color.black.opacity(0.6))
                    .clipShape(Circle())
            }
            .offset(x: 8, y: -8)
        }
    }
}

// MARK: - Quick Camera Button
struct QuickCameraButton: View {
    let onImageCaptured: (UIImage) -> Void
    @State private var showCamera = false
    @EnvironmentObject var themeManager: ThemeManager
    
    var body: some View {
        Button(action: {
            showCamera = true
        }) {
            Image(systemName: "camera.fill")
                .font(.system(size: 20))
                .foregroundColor(Color.dynamicAccent(theme: themeManager.currentTheme))
        }
        .sheet(isPresented: $showCamera) {
            CameraView(onImageCaptured: onImageCaptured)
        }
    }
}

// MARK: - Camera View (Simplified)
struct CameraView: UIViewControllerRepresentable {
    let onImageCaptured: (UIImage) -> Void
    @Environment(\.dismiss) var dismiss
    
    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.delegate = context.coordinator
        picker.sourceType = .camera
        picker.allowsEditing = false
        return picker
    }
    
    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let parent: CameraView
        
        init(_ parent: CameraView) {
            self.parent = parent
        }
        
        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
            if let image = info[.originalImage] as? UIImage {
                parent.onImageCaptured(image)
            }
            parent.dismiss()
        }
        
        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            parent.dismiss()
        }
    }
}