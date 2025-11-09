//
//  StoryCreatorView.swift
//  Gym_API
//
//  Instagram-style camera interface with live preview
//

import SwiftUI
import Photos

struct StoryCreatorView: View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var storyService: StoryService
    @StateObject private var camera = CameraManager()

    @State private var showingTextEditor = false
    @State private var showingImagePicker = false
    @State private var isPublishing = false
    @State private var draft = StoryDraft()
    @State private var lastPhotoThumbnail: UIImage?

    // New state for text-only story mode
    @State private var isTextStoryMode = false
    @State private var currentGradientIndex = 0

    // Instagram gradients for text stories (must match colors in CreatorTextEditor)
    // Order: white, black, red, orange, yellow, green, blue, purple, pink
    private let textGradients: [[Color]] = [
        [Color.white, Color(hex: "#f0f0f0") ?? Color.white.opacity(0.9)], // White
        [Color.black, Color.gray.opacity(0.8)], // Black
        [Color(hex: "#D93333") ?? Color.red, Color(hex: "#FF6B6B") ?? Color.red.opacity(0.8)], // Red
        [Color(hex: "#FD1D1D") ?? Color.red, Color(hex: "#FCB045") ?? Color.orange], // Orange
        [Color(hex: "#FCB045") ?? Color.orange, Color(hex: "#f5af19") ?? Color.yellow], // Yellow
        [Color(hex: "#43e97b") ?? Color.green, Color(hex: "#38f9d7") ?? Color.green.opacity(0.8)], // Green
        [Color(hex: "#4facfe") ?? Color.blue, Color(hex: "#00f2fe") ?? Color.blue.opacity(0.8)], // Blue
        [Color(hex: "#833AB4") ?? Color.purple, Color(hex: "#FD1D1D") ?? Color.red, Color(hex: "#FCB045") ?? Color.orange], // Purple
        [Color(hex: "#f093fb") ?? Color.pink, Color(hex: "#f5576c") ?? Color.pink.opacity(0.8)] // Pink
    ]

    var body: some View {
        ZStack {
            // Background layer
            if isTextStoryMode {
                // Text story mode - show gradient background
                LinearGradient(
                    colors: textGradients[currentGradientIndex],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()
                .onTapGesture {
                    // Tap to change gradient
                    withAnimation {
                        currentGradientIndex = (currentGradientIndex + 1) % textGradients.count
                    }
                }
            } else if !camera.isTaken {
                // Camera mode - show live camera
                StoryCameraView(camera: camera)
                    .ignoresSafeArea()
            } else if let capturedImage = camera.capturedImage {
                // Photo captured - show preview
                Image(uiImage: capturedImage)
                    .resizable()
                    .scaledToFill()
                    .ignoresSafeArea()
            }

            // Text overlay (for text story mode)
            if isTextStoryMode && !draft.textElements.isEmpty {
                ForEach(draft.textElements.indices, id: \.self) { index in
                    Text(draft.textElements[index].text)
                        .font(draft.textElements[index].font.systemFont)
                        .foregroundColor(draft.textElements[index].textColor)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 40)
                }
            }

            // Top controls
            VStack {
                topBar
                Spacer()
            }

            // Bottom controls
            VStack {
                Spacer()

                if isTextStoryMode || camera.isTaken {
                    // Show publish button for text story or captured photo
                    publishBar
                } else {
                    // Show camera controls
                    cameraControlsBar
                }
            }
        }
        .statusBarHidden(true)
        .sheet(isPresented: $showingTextEditor) {
            CreatorTextEditor(draft: $draft, onComplete: { gradientIndex in
                // When user finishes adding text, switch to text story mode
                if !draft.textElements.isEmpty {
                    currentGradientIndex = gradientIndex
                    isTextStoryMode = true
                }
            })
            .presentationDetents([.large])
            .presentationDragIndicator(.hidden)
        }
        .sheet(isPresented: $showingImagePicker) {
            CreatorImagePicker(image: $draft.backgroundImage)
                .onDisappear {
                    if draft.backgroundImage != nil {
                        // TODO: Navigate to editor with image
                    }
                }
        }
        .onAppear {
            loadLastPhoto()
        }
        .alert("Permiso de cámara", isPresented: $camera.alert) {
            Button("Configuración") {
                UIApplication.shared.open(URL(string: UIApplication.openSettingsURLString)!)
            }
            Button("Cancelar", role: .cancel) {
                dismiss()
            }
        } message: {
            Text("Por favor permite el acceso a la cámara en Configuración")
        }
    }

    // MARK: - Top Bar
    private var topBar: some View {
        HStack {
            // Close button
            Button(action: {
                if isTextStoryMode {
                    // If in text mode, go back to camera
                    isTextStoryMode = false
                    draft.textElements.removeAll()
                } else {
                    dismiss()
                }
            }) {
                Image(systemName: isTextStoryMode ? "arrow.left" : "xmark")
                    .font(.system(size: 24, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(width: 44, height: 44)
                    .background(
                        Circle()
                            .fill(Color.black.opacity(0.3))
                    )
            }

            Spacer()

            // Settings (flash, etc) - only show in camera mode
            if !camera.isTaken && !isTextStoryMode {
                Button(action: {}) {
                    Image(systemName: "bolt.slash.fill")
                        .font(.system(size: 20))
                        .foregroundColor(.white)
                        .frame(width: 44, height: 44)
                        .background(
                            Circle()
                                .fill(Color.black.opacity(0.3))
                        )
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 50)
    }

    // MARK: - Camera Controls Bar (Instagram layout)
    private var cameraControlsBar: some View {
        HStack(alignment: .center, spacing: 0) {
            // Gallery button (left)
            Button(action: { showingImagePicker = true }) {
                if let thumbnail = lastPhotoThumbnail {
                    Image(uiImage: thumbnail)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 45, height: 45)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(Color.white, lineWidth: 2)
                        )
                } else {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.white.opacity(0.3))
                        .frame(width: 45, height: 45)
                        .overlay(
                            Image(systemName: "photo.on.rectangle")
                                .foregroundColor(.white)
                                .font(.system(size: 20))
                        )
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.leading, 24)

            // Capture button (center)
            Button(action: {
                camera.takePicture()
            }) {
                ZStack {
                    Circle()
                        .stroke(Color.white, lineWidth: 4)
                        .frame(width: 72, height: 72)

                    Circle()
                        .fill(Color.white)
                        .frame(width: 60, height: 60)
                }
            }
            .frame(maxWidth: .infinity)

            // Text button (right)
            Button(action: { showingTextEditor = true }) {
                VStack(spacing: 4) {
                    Text("Aa")
                        .font(.system(size: 28, weight: .bold))
                        .foregroundColor(.white)
                    Text("Texto")
                        .font(.system(size: 11))
                        .foregroundColor(.white)
                }
            }
            .frame(maxWidth: .infinity, alignment: .trailing)
            .padding(.trailing, 24)
        }
        .padding(.bottom, 40)
    }

    // MARK: - Publish Bar
    private var publishBar: some View {
        HStack(spacing: 40) {
            // Retake/Back button
            Button(action: {
                if isTextStoryMode {
                    isTextStoryMode = false
                    draft.textElements.removeAll()
                } else {
                    camera.retake()
                }
            }) {
                Text(isTextStoryMode ? "Editar" : "Repetir")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 12)
                    .background(
                        Capsule()
                            .fill(Color.white.opacity(0.3))
                    )
            }

            // Publish button
            Button(action: {
                publishStory()
            }) {
                HStack(spacing: 8) {
                    if isPublishing {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .black))
                    } else {
                        Text("Tu historia")
                            .font(.system(size: 16, weight: .semibold))
                        Image(systemName: "arrow.right")
                            .font(.system(size: 14, weight: .bold))
                    }
                }
                .foregroundColor(.black)
                .padding(.horizontal, 24)
                .padding(.vertical, 12)
                .background(
                    Capsule()
                        .fill(Color.white)
                )
            }
            .disabled(isPublishing)
        }
        .padding(.bottom, 40)
    }

    // MARK: - Publish Story
    private func publishStory() {
        isPublishing = true

        Task {
            var mediaData: Data? = nil
            var caption = ""
            var storyType: StoryType = .image // Always use .image now

            if isTextStoryMode {
                // Text story - render as image
                caption = draft.textElements.map { $0.text }.joined(separator: "\n")

                // Generate image from text and gradient
                if let renderedImage = renderTextStoryAsImage() {
                    mediaData = renderedImage.jpegData(compressionQuality: 0.8)
                } else {
                    print("DEBUG: ❌ Failed to render text story as image")
                    await MainActor.run {
                        isPublishing = false
                    }
                    return
                }
            } else if let capturedImage = camera.capturedImage {
                // Photo story
                mediaData = capturedImage.jpegData(compressionQuality: 0.8)
            }

            let createdStory = await storyService.createStory(
                type: storyType,
                caption: caption,
                mediaData: mediaData,
                workoutData: nil,
                privacy: .public,
                duration: 24
            )

            await MainActor.run {
                isPublishing = false
                if createdStory != nil {
                    print("DEBUG: ✅ Story published successfully")
                    dismiss()
                } else {
                    print("DEBUG: ❌ Failed to publish story")
                }
            }
        }
    }

    // MARK: - Render Text Story as Image
    private func renderTextStoryAsImage() -> UIImage? {
        // Story size (9:16 aspect ratio, Instagram standard)
        let size = CGSize(width: 1080, height: 1920)

        let renderer = UIGraphicsImageRenderer(size: size)

        return renderer.image { context in
            // Draw gradient background
            let gradient = textGradients[currentGradientIndex]
            let colors = gradient.map { $0.cgColor } as CFArray

            guard let cgGradient = CGGradient(
                colorsSpace: CGColorSpaceCreateDeviceRGB(),
                colors: colors,
                locations: nil
            ) else { return }

            context.cgContext.drawLinearGradient(
                cgGradient,
                start: CGPoint(x: 0, y: 0),
                end: CGPoint(x: size.width, y: size.height),
                options: []
            )

            // Draw text elements
            for element in draft.textElements {
                let paragraphStyle = NSMutableParagraphStyle()
                paragraphStyle.alignment = .center

                let attributes: [NSAttributedString.Key: Any] = [
                    .font: element.font.uiFont(size: 80), // Larger for high-res
                    .foregroundColor: UIColor(element.textColor),
                    .paragraphStyle: paragraphStyle
                ]

                let attributedString = NSAttributedString(string: element.text, attributes: attributes)

                // Calculate text size and position (centered)
                let textSize = attributedString.size()
                let textRect = CGRect(
                    x: (size.width - textSize.width) / 2,
                    y: (size.height - textSize.height) / 2,
                    width: textSize.width,
                    height: textSize.height
                )

                // Draw background if needed
                if let bgColor = element.backgroundColor {
                    let bgRect = textRect.insetBy(dx: -40, dy: -20)
                    UIColor(bgColor).setFill()
                    let path = UIBezierPath(roundedRect: bgRect, cornerRadius: 16)
                    path.fill()
                }

                attributedString.draw(in: textRect)
            }
        }
    }

    private func loadLastPhoto() {
        let fetchOptions = PHFetchOptions()
        fetchOptions.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]
        fetchOptions.fetchLimit = 1

        let fetchResult = PHAsset.fetchAssets(with: .image, options: fetchOptions)

        guard let lastAsset = fetchResult.firstObject else { return }

        let manager = PHImageManager.default()
        let options = PHImageRequestOptions()
        options.isSynchronous = true
        options.deliveryMode = .fastFormat

        manager.requestImage(
            for: lastAsset,
            targetSize: CGSize(width: 100, height: 100),
            contentMode: .aspectFill,
            options: options
        ) { image, _ in
            if let image = image {
                DispatchQueue.main.async {
                    self.lastPhotoThumbnail = image
                }
            }
        }
    }
}

// MARK: - Creator Text Editor
struct CreatorTextEditor: View {
    @Binding var draft: StoryDraft
    @Environment(\.dismiss) var dismiss
    let onComplete: (Int) -> Void

    @State private var text = ""
    @State private var selectedFont: StoryFont = .bold
    @State private var textColor: Color = .white
    @State private var hasBackground = false
    @State private var selectedBackgroundIndex = 0
    @FocusState private var isTextFieldFocused: Bool

    // Detectar si el fondo es claro para cambiar colores de UI
    private var isLightBackground: Bool {
        // Índices de fondos claros: 0 (white), 4 (yellow)
        return selectedBackgroundIndex == 0 || selectedBackgroundIndex == 4
    }

    private let colors: [Color] = [
        .white, .black, .red, .orange, .yellow, .green, .blue, .purple, .pink
    ]

    // Gradientes para cada color (must match colors array order)
    private let backgroundGradients: [[Color]] = [
        [Color.white, Color(hex: "#f0f0f0") ?? Color.white.opacity(0.9)], // White
        [Color.black, Color.gray.opacity(0.8)], // Black
        [Color(hex: "#D93333") ?? Color.red, Color(hex: "#FF6B6B") ?? Color.red.opacity(0.8)], // Red
        [Color(hex: "#FD1D1D") ?? Color.red, Color(hex: "#FCB045") ?? Color.orange], // Orange
        [Color(hex: "#FCB045") ?? Color.orange, Color(hex: "#f5af19") ?? Color.yellow], // Yellow
        [Color(hex: "#43e97b") ?? Color.green, Color(hex: "#38f9d7") ?? Color.green.opacity(0.8)], // Green
        [Color(hex: "#4facfe") ?? Color.blue, Color(hex: "#00f2fe") ?? Color.blue.opacity(0.8)], // Blue
        [Color(hex: "#833AB4") ?? Color.purple, Color(hex: "#FD1D1D") ?? Color.red, Color(hex: "#FCB045") ?? Color.orange], // Purple
        [Color(hex: "#f093fb") ?? Color.pink, Color(hex: "#f5576c") ?? Color.pink.opacity(0.8)] // Pink
    ]

    var body: some View {
        ZStack {
            // Fondo con gradiente según el color seleccionado
            LinearGradient(
                colors: backgroundGradients[selectedBackgroundIndex],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            VStack {
                // Top bar
                HStack {
                    Button("Cancelar") {
                        dismiss()
                    }
                    .foregroundColor(isLightBackground ? .black : .white)

                    Spacer()

                    Button("Listo") {
                        saveText()
                    }
                    .foregroundColor(isLightBackground ? .black : .white)
                    .fontWeight(.semibold)
                    .disabled(text.isEmpty)
                }
                .padding()

                Spacer()

                // Text input
                TextField("Escribe algo...", text: $text, axis: .vertical)
                    .font(selectedFont.systemFont)
                    .foregroundColor(textColor)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, hasBackground ? 16 : 0)
                    .padding(.vertical, hasBackground ? 8 : 0)
                    .background(hasBackground ? textColor.opacity(0.3) : Color.clear)
                    .cornerRadius(8)
                    .focused($isTextFieldFocused)
                    .padding(.horizontal, 32)

                Spacer()

                // Font selector
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 20) {
                        ForEach(StoryFont.allCases, id: \.self) { font in
                            Button(action: {
                                selectedFont = font
                                let impactFeedback = UIImpactFeedbackGenerator(style: .light)
                                impactFeedback.impactOccurred()
                            }) {
                                Text(font.rawValue)
                                    .font(font.systemFont)
                                    .foregroundColor(
                                        selectedFont == font
                                            ? (isLightBackground ? .black : .white)
                                            : (isLightBackground ? .black.opacity(0.5) : .white.opacity(0.5))
                                    )
                                    .scaleEffect(selectedFont == font ? 1.1 : 1.0)
                            }
                        }
                    }
                    .padding(.horizontal)
                }
                .padding(.vertical, 8)

                // Color selector
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 16) {
                        ForEach(Array(colors.enumerated()), id: \.element) { index, color in
                            Button(action: {
                                withAnimation(.easeInOut(duration: 0.3)) {
                                    selectedBackgroundIndex = index
                                    // Si el fondo es claro, el texto debe ser oscuro
                                    if index == 0 || index == 4 { // white o yellow
                                        textColor = .black
                                    } else {
                                        textColor = color
                                    }
                                }
                                let impactFeedback = UIImpactFeedbackGenerator(style: .light)
                                impactFeedback.impactOccurred()
                            }) {
                                Circle()
                                    .fill(color)
                                    .frame(width: 32, height: 32)
                                    .overlay(
                                        Circle()
                                            .stroke(
                                                isLightBackground ? Color.black : Color.white,
                                                lineWidth: selectedBackgroundIndex == index ? 3 : 0
                                            )
                                    )
                            }
                        }
                    }
                    .padding(.horizontal)
                }
                .padding(.vertical, 8)

                // Background toggle
                Button(action: {
                    hasBackground.toggle()
                    let impactFeedback = UIImpactFeedbackGenerator(style: .light)
                    impactFeedback.impactOccurred()
                }) {
                    HStack {
                        Image(systemName: hasBackground ? "checkmark.square.fill" : "square")
                        Text("Con fondo")
                    }
                    .foregroundColor(isLightBackground ? .black : .white)
                    .padding(.vertical, 12)
                }

                Spacer().frame(height: 40)
            }
        }
        .onAppear {
            isTextFieldFocused = true
        }
    }

    private func saveText() {
        guard !text.isEmpty else { return }

        let newElement = StoryTextElement(
            text: text,
            font: selectedFont,
            textColor: textColor,
            backgroundColor: hasBackground ? textColor.opacity(0.3) : nil,
            position: CGPoint(x: 0.5, y: 0.5),
            scale: 1.0,
            rotation: .zero,
            alignment: .center
        )

        draft.textElements.append(newElement)
        dismiss()

        // Call completion handler to switch to text story mode and pass gradient index
        onComplete(selectedBackgroundIndex)
    }
}

// MARK: - Creator Image Picker
struct CreatorImagePicker: UIViewControllerRepresentable {
    @Binding var image: UIImage?
    @Environment(\.dismiss) var dismiss

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.delegate = context.coordinator
        picker.sourceType = .photoLibrary
        return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let parent: CreatorImagePicker

        init(_ parent: CreatorImagePicker) {
            self.parent = parent
        }

        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
            if let uiImage = info[.originalImage] as? UIImage {
                parent.image = uiImage
            }
            parent.dismiss()
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            parent.dismiss()
        }
    }
}

// MARK: - Preview
struct StoryCreatorView_Previews: PreviewProvider {
    static var previews: some View {
        StoryCreatorView()
            .environmentObject(StoryService())
            .environmentObject(AuthServiceDirect())
            .environmentObject(ThemeManager())
    }
}
