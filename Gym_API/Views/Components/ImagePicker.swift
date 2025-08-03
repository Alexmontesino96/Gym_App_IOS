import SwiftUI
import UIKit
import PhotosUI

struct ImagePicker: UIViewControllerRepresentable {
    let sourceType: UIImagePickerController.SourceType
    @Binding var selectedImage: UIImage?
    @Binding var isPresented: Bool
    
    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = sourceType
        picker.allowsEditing = true
        picker.delegate = context.coordinator
        return picker
    }
    
    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let parent: ImagePicker
        
        init(_ parent: ImagePicker) {
            self.parent = parent
        }
        
        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
            if let editedImage = info[.editedImage] as? UIImage {
                parent.selectedImage = editedImage
            } else if let originalImage = info[.originalImage] as? UIImage {
                parent.selectedImage = originalImage
            }
            parent.isPresented = false
        }
        
        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            parent.isPresented = false
        }
    }
}

struct PhotosPicker: UIViewControllerRepresentable {
    @Binding var selectedImage: UIImage?
    @Binding var isPresented: Bool
    
    func makeUIViewController(context: Context) -> PHPickerViewController {
        var configuration = PHPickerConfiguration()
        configuration.filter = .images
        configuration.selectionLimit = 1
        
        let picker = PHPickerViewController(configuration: configuration)
        picker.delegate = context.coordinator
        return picker
    }
    
    func updateUIViewController(_ uiViewController: PHPickerViewController, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, PHPickerViewControllerDelegate {
        let parent: PhotosPicker
        
        init(_ parent: PhotosPicker) {
            self.parent = parent
        }
        
        func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
            parent.isPresented = false
            
            guard let provider = results.first?.itemProvider else { return }
            
            if provider.canLoadObject(ofClass: UIImage.self) {
                provider.loadObject(ofClass: UIImage.self) { image, _ in
                    DispatchQueue.main.async {
                        self.parent.selectedImage = image as? UIImage
                    }
                }
            }
        }
    }
}

struct ImagePickerSheet: View {
    @EnvironmentObject var themeManager: ThemeManager
    @Binding var selectedImage: UIImage?
    @Binding var isPresented: Bool
    @State private var showingCamera = false
    @State private var showingPhotoLibrary = false
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                VStack(spacing: 20) {
                    Text("Change Profile Photo")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(Color.dynamicText(theme: themeManager.currentTheme))
                        .padding(.top, 20)
                    
                    VStack(spacing: 16) {
                        // Camera Option
                        Button(action: {
                            if UIImagePickerController.isSourceTypeAvailable(.camera) {
                                showingCamera = true
                            }
                        }) {
                            HStack(spacing: 16) {
                                Image(systemName: "camera.fill")
                                    .font(.system(size: 20))
                                    .foregroundColor(Color.dynamicAccent(theme: themeManager.currentTheme))
                                    .frame(width: 24)
                                
                                Text("Take Photo")
                                    .font(.system(size: 16, weight: .medium))
                                    .foregroundColor(Color.dynamicText(theme: themeManager.currentTheme))
                                
                                Spacer()
                                
                                Image(systemName: "chevron.right")
                                    .font(.system(size: 14))
                                    .foregroundColor(Color.dynamicTextSecondary(theme: themeManager.currentTheme))
                            }
                            .padding(.horizontal, 20)
                            .padding(.vertical, 16)
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(Color.dynamicSurface(theme: themeManager.currentTheme))
                            )
                        }
                        .disabled(!UIImagePickerController.isSourceTypeAvailable(.camera))
                        
                        // Photo Library Option
                        Button(action: {
                            showingPhotoLibrary = true
                        }) {
                            HStack(spacing: 16) {
                                Image(systemName: "photo.fill")
                                    .font(.system(size: 20))
                                    .foregroundColor(Color.dynamicAccent(theme: themeManager.currentTheme))
                                    .frame(width: 24)
                                
                                Text("Choose from Library")
                                    .font(.system(size: 16, weight: .medium))
                                    .foregroundColor(Color.dynamicText(theme: themeManager.currentTheme))
                                
                                Spacer()
                                
                                Image(systemName: "chevron.right")
                                    .font(.system(size: 14))
                                    .foregroundColor(Color.dynamicTextSecondary(theme: themeManager.currentTheme))
                            }
                            .padding(.horizontal, 20)
                            .padding(.vertical, 16)
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(Color.dynamicSurface(theme: themeManager.currentTheme))
                            )
                        }
                    }
                    .padding(.horizontal, 20)
                    
                    Spacer()
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color.dynamicBackground(theme: themeManager.currentTheme))
            }
            .navigationBarItems(
                trailing: Button("Cancel") {
                    isPresented = false
                }
                .foregroundColor(Color.dynamicAccent(theme: themeManager.currentTheme))
            )
        }
        .sheet(isPresented: $showingCamera) {
            ImagePicker(sourceType: .camera, selectedImage: $selectedImage, isPresented: $showingCamera)
        }
        .sheet(isPresented: $showingPhotoLibrary) {
            PhotosPicker(selectedImage: $selectedImage, isPresented: $showingPhotoLibrary)
        }
        .onChange(of: selectedImage) { _, _ in
            if selectedImage != nil {
                isPresented = false
            }
        }
    }
}