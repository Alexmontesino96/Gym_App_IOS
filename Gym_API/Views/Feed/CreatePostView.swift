import SwiftUI
import PhotosUI
import CropViewController

/// Vista para crear un nuevo post con selección de imágenes y crop estilo Instagram
struct CreatePostView: View {
    @EnvironmentObject var themeManager: ThemeManager
    @StateObject private var viewModel = CreatePostViewModel()
    @Environment(\.dismiss) private var dismiss

    // MARK: - State

    @State private var selectedPhotoItems: [PhotosPickerItem] = []
    @State private var isProcessingPhotos = false
    @State private var showPhotoPicker = false
    @State private var currentPhotoIndex = 0
    @State private var photosToProcess: [UIImage] = []
    @State private var showCropView = false
    @State private var currentImageToCrop: UIImage?

    var body: some View {
        NavigationView {
            ZStack {
                Color.dynamicBackground(theme: themeManager.currentTheme)
                    .ignoresSafeArea()

                if viewModel.selectedImages.isEmpty {
                    // PASO 1: Seleccionar fotos
                    photoSelectionView
                } else {
                    // PASO 2: Composición del post
                    postCompositionView
                }

                // Loading overlay
                if isProcessingPhotos || viewModel.isPosting {
                    loadingOverlay
                }
            }
            .navigationTitle("Nuevo Post")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancelar") {
                        dismiss()
                    }
                    .foregroundColor(.red)
                }

                if !viewModel.selectedImages.isEmpty {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button(action: {
                            Task {
                                if let _ = await viewModel.createPost() {
                                    dismiss()
                                }
                            }
                        }) {
                            Text("Publicar")
                                .bold()
                        }
                        .disabled(!viewModel.canPost || viewModel.isPosting)
                    }
                }
            }
            .alert("Error", isPresented: .constant(viewModel.errorMessage != nil)) {
                Button("OK") {
                    viewModel.errorMessage = nil
                }
            } message: {
                if let error = viewModel.errorMessage {
                    Text(error)
                }
            }
        }
        .photosPicker(
            isPresented: $showPhotoPicker,
            selection: $selectedPhotoItems,
            maxSelectionCount: 10,
            matching: .images
        )
        .onChange(of: selectedPhotoItems) { newItems in
            guard !newItems.isEmpty else { return }
            processSelectedPhotos(newItems)
        }
        .fullScreenCover(isPresented: $showCropView) {
            if let image = currentImageToCrop {
                CropViewControllerWrapper(
                    image: image,
                    isPresented: $showCropView,
                    onCropped: { croppedImage, aspectRatio in
                        viewModel.addImage(croppedImage)
                        if let ratio = aspectRatio {
                            viewModel.selectedAspectRatio = ratio
                        }
                        processNextPhoto()
                    }
                )
                .ignoresSafeArea()
            }
        }
    }

    // MARK: - Photo Selection View

    private var photoSelectionView: some View {
        VStack(spacing: 32) {
            Spacer()

            // Icono grande
            Image(systemName: "photo.on.rectangle.angled")
                .font(.system(size: 80))
                .foregroundColor(.gray)

            VStack(spacing: 12) {
                Text("Selecciona tus fotos")
                    .font(.title2)
                    .bold()
                    .foregroundColor(Color.dynamicText(theme: themeManager.currentTheme))

                Text("Podrás recortar cada foto en el formato que prefieras")
                    .font(.subheadline)
                    .foregroundColor(.gray)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }

            Button(action: {
                showPhotoPicker = true
            }) {
                HStack {
                    Image(systemName: "photo.fill")
                    Text("Abrir Galería")
                }
                .font(.headline)
                .foregroundColor(.white)
                .frame(maxWidth: 280)
                .padding(.vertical, 16)
                .background(Color.red)
                .cornerRadius(12)
            }

            Text("Máximo 10 fotos")
                .font(.caption)
                .foregroundColor(.gray)

            Spacer()
        }
        .padding()
    }

    // MARK: - Post Composition View

    private var postCompositionView: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {

                // Grid de imágenes seleccionadas
                LazyVGrid(columns: [
                    GridItem(.flexible()),
                    GridItem(.flexible()),
                    GridItem(.flexible())
                ], spacing: 8) {
                    ForEach(Array(viewModel.selectedImages.enumerated()), id: \.offset) { index, image in
                        ZStack(alignment: .topTrailing) {
                            Image(uiImage: image)
                                .resizable()
                                .scaledToFill()
                                .frame(width: 110, height: 110)
                                .clipped()
                                .cornerRadius(8)

                            // Botón eliminar
                            Button(action: {
                                withAnimation {
                                    viewModel.removeImage(at: index)
                                }
                            }) {
                                Image(systemName: "xmark.circle.fill")
                                    .font(.system(size: 24))
                                    .foregroundColor(.white)
                                    .background(Circle().fill(Color.black.opacity(0.6)))
                            }
                            .padding(8)
                        }
                    }

                    // Botón agregar más fotos
                    if viewModel.selectedImages.count < 10 {
                        Button(action: {
                            showPhotoPicker = true
                        }) {
                            ZStack {
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(Color.gray.opacity(0.2))
                                    .frame(width: 110, height: 110)

                                Image(systemName: "plus")
                                    .font(.system(size: 32))
                                    .foregroundColor(.gray)
                            }
                        }
                    }
                }
                .padding(.horizontal)

                Divider()

                // Caption
                VStack(alignment: .leading, spacing: 8) {
                    Text("Descripción")
                        .font(.headline)
                        .foregroundColor(Color.dynamicText(theme: themeManager.currentTheme))

                    TextEditor(text: $viewModel.caption)
                        .frame(minHeight: 120)
                        .padding(8)
                        .background(Color.dynamicSurface(theme: themeManager.currentTheme))
                        .cornerRadius(8)
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                        )

                    HStack {
                        Spacer()
                        Text(viewModel.captionCountText)
                            .font(.caption)
                            .foregroundColor(viewModel.isCaptionLimitReached ? .red : .gray)
                    }
                }
                .padding(.horizontal)

                Divider()

                // Ubicación
                VStack(alignment: .leading, spacing: 8) {
                    Text("Ubicación (opcional)")
                        .font(.headline)
                        .foregroundColor(Color.dynamicText(theme: themeManager.currentTheme))

                    HStack {
                        Image(systemName: "location.fill")
                            .foregroundColor(.gray)

                        TextField("Agrega una ubicación", text: $viewModel.location)
                            .padding(.vertical, 12)
                    }
                    .padding(.horizontal, 12)
                    .background(Color.dynamicSurface(theme: themeManager.currentTheme))
                    .cornerRadius(8)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                    )
                }
                .padding(.horizontal)

                Divider()

                // Privacidad
                VStack(alignment: .leading, spacing: 8) {
                    Text("Privacidad")
                        .font(.headline)
                        .foregroundColor(Color.dynamicText(theme: themeManager.currentTheme))

                    Picker("Privacidad", selection: $viewModel.privacy) {
                        Text("Público").tag(Privacy.public)
                        Text("Privado").tag(Privacy.private)
                    }
                    .pickerStyle(.segmented)
                }
                .padding(.horizontal)

                // Info
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Image(systemName: "info.circle")
                            .foregroundColor(.blue)
                        Text("Tus fotos fueron recortadas en formato Instagram")
                            .font(.caption)
                            .foregroundColor(.gray)
                    }

                    HStack {
                        Image(systemName: "photo.stack")
                            .foregroundColor(.blue)
                        Text("\(viewModel.selectedImages.count) imagen\(viewModel.selectedImages.count == 1 ? "" : "es") • Tamaño estimado: \(viewModel.estimatedTotalSize)")
                            .font(.caption)
                            .foregroundColor(.gray)
                    }
                }
                .padding(.horizontal)
                .padding(.bottom, 32)
            }
            .padding(.top)
        }
    }

    // MARK: - Loading Overlay

    private var loadingOverlay: some View {
        ZStack {
            Color.black.opacity(0.6)
                .ignoresSafeArea()

            VStack(spacing: 20) {
                ProgressView()
                    .scaleEffect(1.5)
                    .tint(.white)

                if viewModel.isPosting {
                    Text("Publicando...")
                        .foregroundColor(.white)
                        .font(.headline)

                    if viewModel.uploadProgress > 0 {
                        ProgressView(value: viewModel.uploadProgress)
                            .frame(width: 200)
                            .tint(.white)
                    }
                } else {
                    Text("Procesando fotos...")
                        .foregroundColor(.white)
                        .font(.headline)
                }
            }
            .padding(32)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color.black.opacity(0.8))
            )
        }
    }

    // MARK: - Helper Methods

    /// Procesa las fotos seleccionadas del PhotosPicker
    private func processSelectedPhotos(_ items: [PhotosPickerItem]) {
        isProcessingPhotos = true
        photosToProcess = []
        currentPhotoIndex = 0

        Task {
            // Cargar todas las imágenes
            for item in items {
                if let data = try? await item.loadTransferable(type: Data.self),
                   let image = UIImage(data: data) {
                    photosToProcess.append(image)
                }
            }

            await MainActor.run {
                isProcessingPhotos = false
                selectedPhotoItems = [] // Reset picker selection

                // Comenzar a procesar la primera foto
                if !photosToProcess.isEmpty {
                    processNextPhoto()
                }
            }
        }
    }

    /// Procesa la siguiente foto en la cola
    private func processNextPhoto() {
        guard currentPhotoIndex < photosToProcess.count else {
            // Terminamos de procesar todas las fotos
            photosToProcess = []
            currentPhotoIndex = 0
            return
        }

        currentImageToCrop = photosToProcess[currentPhotoIndex]
        currentPhotoIndex += 1
        showCropView = true
    }
}

// MARK: - CropViewController Wrapper for SwiftUI

/// Wrapper de SwiftUI para presentar TOCropViewController
struct CropViewControllerWrapper: UIViewControllerRepresentable {
    let image: UIImage
    @Binding var isPresented: Bool
    let onCropped: (UIImage, AspectRatio?) -> Void

    func makeUIViewController(context: Context) -> CropViewController {
        let cropViewController = CropViewController(image: image)
        cropViewController.delegate = context.coordinator

        // Configuración UI básica
        cropViewController.aspectRatioLockEnabled = false
        cropViewController.resetAspectRatioEnabled = true
        cropViewController.rotateButtonsHidden = false
        cropViewController.rotateClockwiseButtonHidden = false

        // Colores de la app
        let appRed = UIColor(red: 217/255, green: 51/255, blue: 51/255, alpha: 1.0)
        cropViewController.toolbar.tintColor = appRed
        cropViewController.toolbar.backgroundColor = .black

        // Textos en español
        cropViewController.doneButtonTitle = "Listo"
        cropViewController.cancelButtonTitle = "Cancelar"

        return cropViewController
    }

    func updateUIViewController(_ uiViewController: CropViewController, context: Context) {
        // No updates needed
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(isPresented: $isPresented, onCropped: onCropped)
    }

    class Coordinator: NSObject, CropViewControllerDelegate {
        @Binding var isPresented: Bool
        let onCropped: (UIImage, AspectRatio?) -> Void

        init(isPresented: Binding<Bool>, onCropped: @escaping (UIImage, AspectRatio?) -> Void) {
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

// MARK: - Preview

#Preview {
    CreatePostView()
        .environmentObject(ThemeManager())
}
