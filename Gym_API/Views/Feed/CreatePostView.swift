import SwiftUI
import PhotosUI

/// Vista completa para crear posts con múltiples imágenes, privacidad, ubicación y progreso
struct CreatePostView: View {
    @EnvironmentObject var themeManager: ThemeManager
    @StateObject private var viewModel = CreatePostViewModel()
    @Environment(\.dismiss) var dismiss

    @State private var selectedItems: [PhotosPickerItem] = []
    @State private var showingLocationPicker = false
    @State private var showSuccessAnimation = false

    var body: some View {
        NavigationStack {
            ZStack {
                Color.dynamicBackground(theme: themeManager.currentTheme)
                    .ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 20) {
                        // Images gallery
                        imagesSection

                        // Caption input
                        captionSection

                        // Location selector
                        locationSection

                        // Privacy selector
                        privacySection

                        // Upload progress
                        if viewModel.isPosting {
                            uploadProgressSection
                        }

                        // Error message
                        if let error = viewModel.errorMessage {
                            errorView(error)
                        }

                        // Info section
                        infoSection
                    }
                    .padding()
                }
            }
            .navigationTitle("Nuevo Post")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancelar") {
                        dismiss()
                    }
                    .foregroundColor(Color.dynamicText(theme: themeManager.currentTheme))
                    .disabled(viewModel.isPosting)
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        Task {
                            await publishPost()
                        }
                    }) {
                        if viewModel.isPosting {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle())
                                .scaleEffect(0.8)
                        } else {
                            Text("Publicar")
                                .fontWeight(.semibold)
                        }
                    }
                    .foregroundColor(viewModel.canPost ? Color.dynamicAccent(theme: themeManager.currentTheme) : .gray)
                    .disabled(!viewModel.canPost || viewModel.isPosting)
                }
            }
            .onChange(of: selectedItems) { _, newItems in
                Task {
                    await loadImages(from: newItems)
                }
            }
            .overlay {
                if showSuccessAnimation {
                    successOverlay
                }
            }
        }
    }

    // MARK: - Images Section

    private var imagesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label("Imágenes", systemImage: "photo.on.rectangle.angled")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(Color.dynamicText(theme: themeManager.currentTheme))

                Spacer()

                Text(viewModel.imageCountText)
                    .font(.system(size: 14))
                    .foregroundColor(.gray)
            }

            if viewModel.selectedImages.isEmpty {
                // Empty state
                PhotosUI.PhotosPicker(
                    selection: $selectedItems,
                    maxSelectionCount: 10,
                    matching: .images
                ) {
                    VStack(spacing: 12) {
                        Image(systemName: "photo.on.rectangle.angled")
                            .font(.system(size: 48))
                            .foregroundColor(.gray.opacity(0.5))

                        Text("Seleccionar imágenes")
                            .font(.system(size: 16, weight: .semibold))

                        Text("Hasta 10 imágenes")
                            .font(.system(size: 14))
                            .foregroundColor(.gray)
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 200)
                    .background(Color.dynamicSurface(theme: themeManager.currentTheme))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color.dynamicBorder(theme: themeManager.currentTheme), lineWidth: 1)
                    )
                }
            } else {
                // Images grid
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                    ForEach(Array(viewModel.selectedImages.enumerated()), id: \.offset) { index, image in
                        ZStack(alignment: .topTrailing) {
                            Image(uiImage: image)
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                                .frame(width: 110, height: 110)
                                .clipShape(RoundedRectangle(cornerRadius: 8))

                            // Remove button
                            Button(action: {
                                withAnimation(.spring(response: 0.3)) {
                                    viewModel.removeImage(at: index)
                                }
                            }) {
                                Image(systemName: "xmark.circle.fill")
                                    .font(.system(size: 20))
                                    .foregroundColor(.white)
                                    .background(Circle().fill(Color.black.opacity(0.5)))
                            }
                            .padding(4)

                            // Image number badge
                            VStack {
                                Spacer()
                                HStack {
                                    Text("\(index + 1)")
                                        .font(.system(size: 12, weight: .bold))
                                        .foregroundColor(.white)
                                        .padding(4)
                                        .background(Circle().fill(Color.black.opacity(0.6)))
                                        .padding(4)
                                    Spacer()
                                }
                            }
                        }
                    }

                    // Add more button
                    if viewModel.selectedImages.count < 10 {
                        PhotosUI.PhotosPicker(
                            selection: $selectedItems,
                            maxSelectionCount: 10 - viewModel.selectedImages.count,
                            matching: .images
                        ) {
                            VStack(spacing: 8) {
                                Image(systemName: "plus.circle")
                                    .font(.system(size: 32))
                                Text("Agregar")
                                    .font(.system(size: 12))
                            }
                            .foregroundColor(.gray)
                            .frame(width: 110, height: 110)
                            .background(Color.dynamicSurface(theme: themeManager.currentTheme))
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(
                                        Color.dynamicBorder(theme: themeManager.currentTheme),
                                        style: StrokeStyle(lineWidth: 1, dash: [5])
                                    )
                            )
                        }
                    }
                }
            }
        }
    }

    // MARK: - Caption Section

    private var captionSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Descripción", systemImage: "text.alignleft")
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(Color.dynamicText(theme: themeManager.currentTheme))

            TextField("¿Qué quieres compartir?", text: $viewModel.caption, axis: .vertical)
                .font(.system(size: 15))
                .foregroundColor(Color.dynamicText(theme: themeManager.currentTheme))
                .padding()
                .background(Color.dynamicSurface(theme: themeManager.currentTheme))
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(viewModel.isCaptionLimitReached ? Color.red : Color.dynamicBorder(theme: themeManager.currentTheme), lineWidth: 1)
                )
                .lineLimit(5...15)

            HStack {
                Spacer()
                Text(viewModel.captionCountText)
                    .font(.system(size: 12))
                    .foregroundColor(viewModel.isCaptionLimitReached ? .red : .gray)
            }
        }
    }

    // MARK: - Location Section

    private var locationSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Ubicación", systemImage: "location")
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(Color.dynamicText(theme: themeManager.currentTheme))

            TextField("Agregar ubicación (opcional)", text: $viewModel.location)
                .font(.system(size: 15))
                .foregroundColor(Color.dynamicText(theme: themeManager.currentTheme))
                .padding()
                .background(Color.dynamicSurface(theme: themeManager.currentTheme))
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.dynamicBorder(theme: themeManager.currentTheme), lineWidth: 1)
                )
        }
    }

    // MARK: - Privacy Section

    private var privacySection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Privacidad", systemImage: "lock.shield")
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(Color.dynamicText(theme: themeManager.currentTheme))

            HStack(spacing: 12) {
                privacyButton(.public, icon: "globe", title: "Público")
                privacyButton(.private, icon: "lock.fill", title: "Privado")
            }
        }
    }

    private func privacyButton(_ privacy: Privacy, icon: String, title: String) -> some View {
        Button(action: {
            withAnimation(.spring(response: 0.3)) {
                viewModel.privacy = privacy
            }
        }) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 14))
                Text(title)
                    .font(.system(size: 14, weight: .medium))
            }
            .foregroundColor(viewModel.privacy == privacy ? .white : Color.dynamicText(theme: themeManager.currentTheme))
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(viewModel.privacy == privacy ? Color.dynamicAccent(theme: themeManager.currentTheme) : Color.dynamicSurface(theme: themeManager.currentTheme))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(viewModel.privacy == privacy ? Color.clear : Color.dynamicBorder(theme: themeManager.currentTheme), lineWidth: 1)
            )
        }
    }

    // MARK: - Upload Progress Section

    private var uploadProgressSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "arrow.up.circle")
                    .foregroundColor(Color.dynamicAccent(theme: themeManager.currentTheme))
                Text("Subiendo post...")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(Color.dynamicText(theme: themeManager.currentTheme))
                Spacer()
                Text("\(Int(viewModel.uploadProgress * 100))%")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(Color.dynamicAccent(theme: themeManager.currentTheme))
            }

            ProgressView(value: viewModel.uploadProgress)
                .progressViewStyle(LinearProgressViewStyle(tint: Color.dynamicAccent(theme: themeManager.currentTheme)))
        }
        .padding()
        .background(Color.dynamicSurface(theme: themeManager.currentTheme))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.dynamicBorder(theme: themeManager.currentTheme), lineWidth: 1)
        )
    }

    // MARK: - Info Section

    private var infoSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            if !viewModel.selectedImages.isEmpty {
                HStack {
                    Image(systemName: "info.circle")
                        .font(.system(size: 12))
                    Text("Tamaño estimado: \(viewModel.estimatedTotalSize)")
                        .font(.system(size: 12))
                    Spacer()
                }
                .foregroundColor(.gray)
            }

            HStack {
                Image(systemName: "checkmark.shield")
                    .font(.system(size: 12))
                Text("Las imágenes se comprimirán automáticamente")
                    .font(.system(size: 12))
                Spacer()
            }
            .foregroundColor(.gray)
        }
    }

    // MARK: - Error View

    private func errorView(_ message: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundColor(.red)
            Text(message)
                .font(.system(size: 14))
                .foregroundColor(.red)
            Spacer()
        }
        .padding()
        .background(Color.red.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    // MARK: - Success Overlay

    private var successOverlay: some View {
        ZStack {
            Color.black.opacity(0.4)
                .ignoresSafeArea()

            VStack(spacing: 16) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 60))
                    .foregroundColor(.green)

                Text("Post publicado")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(.white)
            }
            .padding(40)
            .background(Color.dynamicSurface(theme: themeManager.currentTheme))
            .clipShape(RoundedRectangle(cornerRadius: 20))
            .shadow(radius: 20)
        }
        .transition(.opacity)
    }

    // MARK: - Actions

    private func loadImages(from items: [PhotosPickerItem]) async {
        var loadedImages: [UIImage] = []

        for item in items {
            if let data = try? await item.loadTransferable(type: Data.self),
               let image = UIImage(data: data) {
                loadedImages.append(image)
            }
        }

        await MainActor.run {
            viewModel.addImages(loadedImages)
            selectedItems = [] // Clear selection
        }
    }

    private func publishPost() async {
        print("🎬 [CreatePostView] publishPost() llamado")

        if let post = await viewModel.createPost() {
            print("✅ [CreatePostView] Post creado exitosamente - ID: \(post.id)")

            // Show success animation
            withAnimation {
                showSuccessAnimation = true
            }

            // Dismiss after delay
            try? await Task.sleep(nanoseconds: 1_500_000_000) // 1.5 seconds

            print("👋 [CreatePostView] Cerrando vista...")
            await MainActor.run {
                dismiss()
            }
        } else {
            print("❌ [CreatePostView] createPost() retornó nil")
        }
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        CreatePostView()
            .environmentObject(ThemeManager())
    }
}
