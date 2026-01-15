//
//  StoryCreationView.swift
//  Gym_API
//
//  Instagram-style story creation
//

import SwiftUI

struct StoryCreationView: View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var storyService: StoryService

    @State private var draft = StoryDraft()
    @State private var selectedTextIndex: Int?
    @State private var showingTextEditor = false
    @State private var isPublishing = false
    @State private var currentColorIndex = 0
    @State private var showingImagePicker = false

    // Instagram-style gradient backgrounds
    private let backgroundGradients: [[Color]] = [
        [Color(hex: "#833AB4") ?? Color.purple, Color(hex: "#FD1D1D") ?? Color.red, Color(hex: "#FCB045") ?? Color.orange],
        [Color(hex: "#667EEA") ?? Color.blue, Color(hex: "#764BA2") ?? Color.purple],
        [Color(hex: "#F857A6") ?? Color.pink, Color(hex: "#FF5858") ?? Color.red],
        [Color(hex: "#43E97B") ?? Color.green, Color(hex: "#38F9D7") ?? Color.cyan],
        [Color(hex: "#FA709A") ?? Color.pink, Color(hex: "#FEE140") ?? Color.yellow],
        [Color.black, Color.black] // Solid black
    ]

    var body: some View {
        ZStack {
            // Background
            currentBackground
                .ignoresSafeArea()
                .onTapGesture {
                    // Tap to add text
                    showingTextEditor = true
                }

            // Text elements (draggable)
            ForEach(Array(draft.textElements.enumerated()), id: \.element.id) { index, element in
                DraggableTextView(
                    element: element,
                    isSelected: selectedTextIndex == index,
                    onTap: {
                        selectedTextIndex = index
                    },
                    onDelete: {
                        withAnimation {
                            draft.textElements.remove(at: index)
                            selectedTextIndex = nil
                        }
                    }
                )
            }

            // Floating camera button (only if no image)
            if draft.backgroundImage == nil {
                Button(action: { showingImagePicker = true }) {
                    VStack(spacing: 12) {
                        Image(systemName: "camera.fill")
                            .font(.system(size: 40))
                            .foregroundColor(.white)
                        Text("Añadir foto")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.white)
                    }
                    .frame(width: 140, height: 140)
                    .background(
                        Circle()
                            .fill(Color.white.opacity(0.2))
                            .overlay(
                                Circle()
                                    .stroke(Color.white, lineWidth: 2)
                            )
                    )
                }
            }

            // Top toolbar
            VStack {
                topToolbar
                Spacer()
                bottomToolbar
            }
        }
        .ignoresSafeArea()
        .sheet(isPresented: $showingTextEditor) {
            InstagramTextEditor(draft: $draft)
                .presentationDetents([.large])
                .presentationDragIndicator(.hidden)
        }
        .sheet(isPresented: $showingImagePicker) {
            StoryImagePicker(image: $draft.backgroundImage)
        }
    }

    // MARK: - Background
    @ViewBuilder
    private var currentBackground: some View {
        if let image = draft.backgroundImage {
            Image(uiImage: image)
                .resizable()
                .scaledToFill()
        } else {
            LinearGradient(
                colors: backgroundGradients[currentColorIndex],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
    }

    // MARK: - Top Toolbar
    private var topToolbar: some View {
        HStack {
            // Close button
            Button(action: { dismiss() }) {
                Image(systemName: "xmark")
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(width: 36, height: 36)
            }

            Spacer()

            // Text tool
            Button(action: { showingTextEditor = true }) {
                Text("Aa")
                    .font(.system(size: 26, weight: .bold))
                    .foregroundColor(.white)
                    .frame(width: 40, height: 40)
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 50)
    }

    // MARK: - Bottom Toolbar
    private var bottomToolbar: some View {
        VStack(spacing: 20) {
            // Color selector (only visible when NO background image)
            if draft.backgroundImage == nil {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(backgroundGradients.indices, id: \.self) { index in
                            Button(action: {
                                withAnimation(.spring(response: 0.3)) {
                                    currentColorIndex = index
                                }
                                let impactFeedback = UIImpactFeedbackGenerator(style: .light)
                                impactFeedback.impactOccurred()
                            }) {
                                ZStack {
                                    if backgroundGradients[index].count > 1 {
                                        LinearGradient(
                                            colors: backgroundGradients[index],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        )
                                    } else {
                                        backgroundGradients[index][0]
                                    }
                                }
                                .frame(width: 36, height: 36)
                                .clipShape(Circle())
                                .overlay(
                                    Circle()
                                        .stroke(Color.white, lineWidth: currentColorIndex == index ? 3 : 0)
                                )
                                .shadow(color: .black.opacity(0.2), radius: 4, x: 0, y: 2)
                            }
                        }
                    }
                    .padding(.horizontal, 20)
                }
            }

            // Publish button
            Button(action: publishStory) {
                HStack(spacing: 12) {
                    if isPublishing {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                    } else {
                        Image(systemName: "arrow.right.circle.fill")
                            .font(.system(size: 22))
                        Text("Tu historia")
                            .font(.system(size: 17, weight: .semibold))
                    }
                }
                .foregroundColor(draft.hasContent ? .black : .white.opacity(0.5))
                .frame(maxWidth: .infinity)
                .frame(height: 56)
                .background(
                    Capsule()
                        .fill(draft.hasContent ? Color.white : Color.white.opacity(0.3))
                )
            }
            .disabled(isPublishing || !draft.hasContent)
            .padding(.horizontal, 20)
            .padding(.bottom, 40)
        }
    }

    // MARK: - Publish Story
    private func publishStory() {
        guard draft.hasContent else { return }

        isPublishing = true

        Task {
            let renderer = ImageRenderer(content: StoryPreviewContent(draft: draft))
            renderer.scale = 3.0

            guard let image = renderer.uiImage else {
                await MainActor.run {
                    isPublishing = false
                }
                return
            }

            // Convertir imagen a JPEG data
            guard let imageData = image.jpegData(compressionQuality: 0.8) else {
                await MainActor.run {
                    isPublishing = false
                }
                return
            }

            let createdStory = await storyService.createStory(
                type: .image,
                caption: draft.caption.isEmpty ? nil : draft.caption,
                mediaData: imageData,
                duration: draft.duration
            )

            await MainActor.run {
                isPublishing = false
                if createdStory != nil {
                    dismiss()
                }
            }
        }
    }
}

// MARK: - Draggable Text View
struct DraggableTextView: View {
    let element: StoryTextElement
    let isSelected: Bool
    let onTap: () -> Void
    let onDelete: () -> Void

    @State private var offset = CGSize.zero
    @State private var scale: CGFloat = 1.0
    @State private var lastScale: CGFloat = 1.0

    var body: some View {
        VStack(spacing: 8) {
            Text(element.text)
                .font(element.font.systemFont)
                .foregroundColor(element.textColor)
                .multilineTextAlignment(.center)
                .padding(.horizontal, element.backgroundColor != nil ? 16 : 0)
                .padding(.vertical, element.backgroundColor != nil ? 8 : 0)
                .background(
                    Group {
                        if let bgColor = element.backgroundColor {
                            RoundedRectangle(cornerRadius: 8)
                                .fill(bgColor)
                        }
                    }
                )
                .scaleEffect(scale * element.scale)
                .rotationEffect(element.rotation)
                .shadow(color: .black.opacity(0.3), radius: 2, x: 0, y: 1)
        }
        .position(
            x: element.position.x * UIScreen.main.bounds.width + offset.width,
            y: element.position.y * UIScreen.main.bounds.height + offset.height
        )
        .gesture(
            DragGesture()
                .onChanged { value in
                    offset = value.translation
                }
                .onEnded { _ in
                    offset = .zero
                }
        )
        .gesture(
            MagnificationGesture()
                .onChanged { value in
                    scale = lastScale * value
                }
                .onEnded { value in
                    lastScale = scale
                }
        )
        .onTapGesture {
            onTap()
        }
        .onLongPressGesture {
            let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
            impactFeedback.impactOccurred()
            onDelete()
        }
    }
}

// MARK: - Instagram Text Editor
struct InstagramTextEditor: View {
    @Binding var draft: StoryDraft
    @Environment(\.dismiss) var dismiss

    @State private var text: String = ""
    @State private var selectedFont: StoryFont = .bold
    @State private var selectedColorIndex = 0
    @State private var hasBackground: Bool = false
    @FocusState private var isTextFieldFocused: Bool

    private let textColors: [Color] = [
        .white,
        .black,
        Color(hex: "#FF3B30") ?? .red,
        Color(hex: "#FF9500") ?? .orange,
        Color(hex: "#FFCC00") ?? .yellow,
        Color(hex: "#34C759") ?? .green,
        Color(hex: "#007AFF") ?? .blue,
        Color(hex: "#5856D6") ?? .purple,
        Color(hex: "#FF2D55") ?? .pink
    ]

    var body: some View {
        ZStack {
            // Background (same as story)
            LinearGradient(
                colors: [draft.backgroundColor, draft.backgroundColor.opacity(0.8)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
            .onTapGesture {
                isTextFieldFocused = false
            }

            VStack(spacing: 0) {
                // Top bar
                HStack {
                    Button("Cancelar") {
                        dismiss()
                    }
                    .foregroundColor(.white)

                    Spacer()

                    // Background toggle
                    Button(action: {
                        hasBackground.toggle()
                        let impactFeedback = UIImpactFeedbackGenerator(style: .light)
                        impactFeedback.impactOccurred()
                    }) {
                        Image(systemName: hasBackground ? "a.square.fill" : "a.square")
                            .font(.system(size: 24))
                            .foregroundColor(.white)
                    }

                    Spacer()

                    Button("Listo") {
                        addTextElement()
                    }
                    .foregroundColor(.white)
                    .fontWeight(.semibold)
                    .disabled(text.isEmpty)
                }
                .padding()

                Spacer()

                // Text preview (center)
                if !text.isEmpty {
                    Text(text)
                        .font(selectedFont.systemFont)
                        .foregroundColor(textColors[selectedColorIndex])
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, hasBackground ? 20 : 0)
                        .padding(.vertical, hasBackground ? 12 : 0)
                        .background(
                            Group {
                                if hasBackground {
                                    RoundedRectangle(cornerRadius: 8)
                                        .fill(textColors[selectedColorIndex].opacity(0.3))
                                }
                            }
                        )
                        .padding(.horizontal, 40)
                }

                Spacer()

                // Controls
                VStack(spacing: 24) {
                    // Text input
                    TextField("Escribe algo...", text: $text, axis: .vertical)
                        .font(.title2)
                        .foregroundColor(.white)
                        .multilineTextAlignment(.center)
                        .focused($isTextFieldFocused)
                        .padding()
                        .lineLimit(5)

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
                                        .font(font.systemFont.weight(selectedFont == font ? .bold : .regular))
                                        .foregroundColor(.white)
                                        .opacity(selectedFont == font ? 1.0 : 0.6)
                                        .scaleEffect(selectedFont == font ? 1.1 : 1.0)
                                }
                            }
                        }
                        .padding(.horizontal, 24)
                    }

                    // Color picker
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 16) {
                            ForEach(textColors.indices, id: \.self) { index in
                                Button(action: {
                                    selectedColorIndex = index
                                    let impactFeedback = UIImpactFeedbackGenerator(style: .light)
                                    impactFeedback.impactOccurred()
                                }) {
                                    Circle()
                                        .fill(textColors[index])
                                        .frame(width: 40, height: 40)
                                        .overlay(
                                            Circle()
                                                .stroke(Color.white, lineWidth: selectedColorIndex == index ? 3 : 0)
                                        )
                                        .shadow(color: .black.opacity(0.2), radius: 4, x: 0, y: 2)
                                }
                            }
                        }
                        .padding(.horizontal, 24)
                    }
                }
                .padding(.bottom, 40)
            }
        }
        .onAppear {
            isTextFieldFocused = true
        }
    }

    private func addTextElement() {
        guard !text.isEmpty else { return }

        let element = StoryTextElement(
            text: text,
            font: selectedFont,
            textColor: textColors[selectedColorIndex],
            backgroundColor: hasBackground ? textColors[selectedColorIndex].opacity(0.3) : nil,
            position: CGPoint(x: 0.5, y: 0.5)
        )

        draft.textElements.append(element)
        dismiss()
    }
}

// MARK: - Story Preview Content
struct StoryPreviewContent: View {
    let draft: StoryDraft

    var body: some View {
        GeometryReader { geometry in
            let storyFrame = StoryDimensions.calculateStoryFrame(for: geometry.size)

            ZStack {
                // Background for letterboxing
                Color.black

                // Story content in 9:16 container
                ZStack {
                    if let image = draft.backgroundImage {
                        InstagramStoryImageView(
                            imageURL: nil,
                            localImage: image
                        )
                    } else {
                        LinearGradient(
                            colors: [draft.backgroundColor, draft.backgroundColor.opacity(0.8)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    }

                    ForEach(draft.textElements) { textElement in
                        Text(textElement.text)
                            .font(textElement.font.systemFont)
                            .foregroundColor(textElement.textColor)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, textElement.backgroundColor != nil ? 16 : 0)
                            .padding(.vertical, textElement.backgroundColor != nil ? 8 : 0)
                            .background(
                                Group {
                                    if let bgColor = textElement.backgroundColor {
                                        RoundedRectangle(cornerRadius: 8)
                                            .fill(bgColor)
                                    }
                                }
                            )
                            .position(
                                x: textElement.position.x * storyFrame.width,
                                y: textElement.position.y * storyFrame.height
                            )
                            .scaleEffect(textElement.scale)
                            .rotationEffect(textElement.rotation)
                    }
                }
                .frame(width: storyFrame.width, height: storyFrame.height)
                .position(x: geometry.size.width / 2, y: geometry.size.height / 2)
                .clipped()
            }
        }
    }
}

// MARK: - Story Image Picker
struct StoryImagePicker: UIViewControllerRepresentable {
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
        let parent: StoryImagePicker

        init(_ parent: StoryImagePicker) {
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
struct StoryCreationView_Previews: PreviewProvider {
    static var previews: some View {
        StoryCreationView()
            .environmentObject(StoryService())
    }
}
