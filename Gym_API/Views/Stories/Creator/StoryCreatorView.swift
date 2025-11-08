//
//  StoryCreatorView.swift
//  Gym_API
//
//  Created on November 2024
//

import SwiftUI
import PhotosUI

struct StoryCreatorView: View {
    @EnvironmentObject var storyService: StoryService
    @EnvironmentObject var authService: AuthServiceDirect
    @EnvironmentObject var themeManager: ThemeManager
    @Environment(\.dismiss) var dismiss

    @State private var selectedType: StoryType = .image
    @State private var caption = ""
    @State private var privacy: StoryPrivacy = .public
    @State private var duration: Int = 24

    // Image/Video states
    @State private var selectedImage: UIImage?
    @State private var showingImagePicker = false
    @State private var showingCamera = false

    // Workout states
    @State private var exercise = ""
    @State private var weight = ""
    @State private var reps = ""
    @State private var sets = ""
    @State private var workoutNotes = ""

    // Text story states
    @State private var storyText = ""
    @State private var selectedGradient = 0

    // UI states
    @State private var showingPrivacyPicker = false
    @State private var isPublishing = false

    private let gradients: [[Color]] = {
        let gradient1 = [Color(hex: "D93333") ?? Color.red, Color(hex: "FF6B6B") ?? Color.red.opacity(0.8)]
        let gradient2 = [Color(hex: "667eea") ?? Color.purple, Color(hex: "764ba2") ?? Color.purple.opacity(0.8)]
        let gradient3 = [Color(hex: "f093fb") ?? Color.pink, Color(hex: "f5576c") ?? Color.pink.opacity(0.8)]
        let gradient4 = [Color(hex: "4facfe") ?? Color.blue, Color(hex: "00f2fe") ?? Color.blue.opacity(0.8)]
        let gradient5 = [Color(hex: "43e97b") ?? Color.green, Color(hex: "38f9d7") ?? Color.green.opacity(0.8)]
        return [gradient1, gradient2, gradient3, gradient4, gradient5]
    }()

    var body: some View {
        NavigationView {
            mainContent
                .navigationTitle("Nueva Historia")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .navigationBarLeading) {
                        cancelButton
                    }
                }
                .sheet(isPresented: $showingImagePicker) {
                    ImagePicker(sourceType: .photoLibrary, selectedImage: $selectedImage, isPresented: $showingImagePicker)
                }
                .sheet(isPresented: $showingCamera) {
                    ImagePicker(sourceType: .camera, selectedImage: $selectedImage, isPresented: $showingCamera)
                }
                .sheet(isPresented: $showingPrivacyPicker) {
                    PrivacyPickerView(selectedPrivacy: $privacy)
                        .presentationDetents([.height(300)])
                }
                .alert("Historia Publicada", isPresented: .constant(storyService.successMessage != nil)) {
                    Button("OK") {
                        storyService.successMessage = nil
                        dismiss()
                    }
                } message: {
                    Text(storyService.successMessage ?? "")
                }
                .alert("Error", isPresented: .constant(storyService.errorMessage != nil)) {
                    Button("OK") {
                        storyService.errorMessage = nil
                    }
                } message: {
                    Text(storyService.errorMessage ?? "")
                }
        }
    }

    private var mainContent: some View {
        ZStack {
            Color.dynamicBackground(theme: themeManager.currentTheme)
                .ignoresSafeArea()

            VStack(spacing: 0) {
                typeSelectorView
                ScrollView {
                    VStack(spacing: 20) {
                        contentView
                        captionInputView
                        settingsView
                        publishButton
                    }
                    .padding(.vertical, 20)
                }
            }
        }
    }

    private var cancelButton: some View {
        Button("Cancelar") {
            dismiss()
        }
        .foregroundColor(Color(hex: "D93333") ?? Color.red)
    }

    private var typeSelectorView: some View {
        StoryTypeSelector(selectedType: $selectedType)
            .padding(.horizontal)
            .padding(.vertical, 8)
    }

    @ViewBuilder
    private var captionInputView: some View {
        if selectedType != .text {
            VStack(alignment: .leading, spacing: 8) {
                Label("Caption", systemImage: "text.bubble")
                    .font(.subheadline)
                    .foregroundColor(Color.dynamicText(theme: themeManager.currentTheme))

                TextField("Agrega un caption...", text: $caption, axis: .vertical)
                    .textFieldStyle(.roundedBorder)
                    .lineLimit(3...5)
            }
            .padding(.horizontal)
        }
    }

    private var settingsView: some View {
        VStack(spacing: 16) {
            privacySelectorButton
            durationSelectorView
        }
        .padding(.horizontal)
    }

    private var privacySelectorButton: some View {
        Button(action: { showingPrivacyPicker = true }) {
            HStack {
                Image(systemName: privacy.icon)
                Text(privacy.displayName)
                Spacer()
                Image(systemName: "chevron.right")
            }
            .foregroundColor(Color.dynamicText(theme: themeManager.currentTheme))
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.dynamicSurface(theme: themeManager.currentTheme))
            )
        }
    }

    private var durationSelectorView: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Duración", systemImage: "timer")
                .font(.subheadline)
                .foregroundColor(Color.dynamicText(theme: themeManager.currentTheme))

            Picker("Duración", selection: $duration) {
                Text("1 hora").tag(1)
                Text("6 horas").tag(6)
                Text("12 horas").tag(12)
                Text("24 horas").tag(24)
                Text("48 horas").tag(48)
            }
            .pickerStyle(SegmentedPickerStyle())
        }
    }

    private var publishButton: some View {
        Button(action: publishStory) {
            Group {
                if isPublishing {
                    HStack {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        Text("Publicando...")
                    }
                } else {
                    HStack {
                        Image(systemName: "paperplane.fill")
                        Text("Compartir Historia")
                    }
                }
            }
        }
        .font(.headline)
        .foregroundColor(.white)
        .frame(maxWidth: .infinity)
        .padding()
        .background(publishButtonBackground)
        .padding(.horizontal)
        .disabled(!canPublish || isPublishing)
        .opacity(canPublish ? 1 : 0.5)
    }

    private var publishButtonBackground: some View {
        RoundedRectangle(cornerRadius: 16)
            .fill(
                LinearGradient(
                    colors: [Color(hex: "D93333") ?? Color.red, Color(hex: "FF6B6B") ?? Color.red.opacity(0.8)],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
    }

    // MARK: - Content Views
    @ViewBuilder
    private var contentView: some View {
        switch selectedType {
        case .image, .video:
            mediaContentView
        case .text:
            textContentView
        case .workout:
            workoutContentView
        case .achievement:
            achievementContentView
        }
    }

    private var mediaContentView: some View {
        VStack(spacing: 16) {
            if let image = selectedImage {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
                    .frame(maxHeight: 400)
                    .cornerRadius(12)
                    .padding(.horizontal)

                Button("Cambiar foto") {
                    showingImagePicker = true
                }
                .foregroundColor(Color(hex: "D93333"))
            } else {
                VStack(spacing: 20) {
                    Image(systemName: selectedType == .image ? "camera.fill" : "video.fill")
                        .font(.system(size: 60))
                        .foregroundColor(Color.dynamicText(theme: themeManager.currentTheme).opacity(0.5))

                    HStack(spacing: 20) {
                        Button(action: { showingCamera = true }) {
                            Label("Cámara", systemImage: "camera")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.borderedProminent)

                        Button(action: { showingImagePicker = true }) {
                            Label("Galería", systemImage: "photo")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.bordered)
                    }
                    .padding(.horizontal)
                }
                .frame(height: 300)
                .frame(maxWidth: .infinity)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.dynamicSurface(theme: themeManager.currentTheme))
                )
                .padding(.horizontal)
            }
        }
    }

    private var textContentView: some View {
        VStack(spacing: 16) {
            // Text story preview
            ZStack {
                LinearGradient(
                    colors: gradients[selectedGradient],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .frame(height: 400)
                .cornerRadius(12)

                ZStack {
                    if storyText.isEmpty {
                        Text("Escribe tu historia...")
                            .font(.title2)
                            .foregroundColor(.white.opacity(0.5))
                            .padding(30)
                    }

                    TextEditor(text: $storyText)
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                        .multilineTextAlignment(.center)
                        .scrollContentBackground(.hidden)
                        .background(Color.clear)
                        .padding(30)
                }
            }
            .padding(.horizontal)

            // Gradient selector
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(0..<gradients.count, id: \.self) { index in
                        Button(action: { selectedGradient = index }) {
                            LinearGradient(
                                colors: gradients[index],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                            .frame(width: 50, height: 50)
                            .cornerRadius(12)
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(
                                        selectedGradient == index ? Color.white : Color.clear,
                                        lineWidth: 3
                                    )
                            )
                        }
                    }
                }
                .padding(.horizontal)
            }
        }
    }

    private var workoutContentView: some View {
        VStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 16) {
                TextField("Ejercicio", text: $exercise)
                    .textFieldStyle(.roundedBorder)

                HStack(spacing: 12) {
                    TextField("Peso", text: $weight)
                        .keyboardType(.decimalPad)
                        .textFieldStyle(.roundedBorder)

                    Picker("Unidad", selection: .constant("kg")) {
                        Text("kg").tag("kg")
                        Text("lb").tag("lb")
                    }
                    .pickerStyle(SegmentedPickerStyle())
                }

                HStack(spacing: 12) {
                    TextField("Reps", text: $reps)
                        .keyboardType(.numberPad)
                        .textFieldStyle(.roundedBorder)

                    TextField("Sets", text: $sets)
                        .keyboardType(.numberPad)
                        .textFieldStyle(.roundedBorder)
                }

                TextField("Notas (opcional)", text: $workoutNotes, axis: .vertical)
                    .textFieldStyle(.roundedBorder)
                    .lineLimit(2...4)
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.dynamicSurface(theme: themeManager.currentTheme))
            )
            .padding(.horizontal)
        }
    }

    private var achievementContentView: some View {
        VStack(spacing: 16) {
            Image(systemName: "trophy.fill")
                .font(.system(size: 80))
                .foregroundColor(.yellow)
                .padding()
                .background(
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [Color(hex: "FFD700") ?? Color.yellow, Color(hex: "FFA500") ?? Color.orange],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                )

            Text("¡Comparte tu logro!")
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(Color.dynamicText(theme: themeManager.currentTheme))

            TextField("Describe tu logro...", text: $caption, axis: .vertical)
                .textFieldStyle(.roundedBorder)
                .lineLimit(3...5)
                .padding(.horizontal)
        }
    }

    // MARK: - Computed Properties
    private var canPublish: Bool {
        switch selectedType {
        case .image, .video:
            return selectedImage != nil
        case .text:
            return !storyText.isEmpty
        case .workout:
            return !exercise.isEmpty
        case .achievement:
            return !caption.isEmpty
        }
    }

    // MARK: - Actions
    private func publishStory() {
        print("DEBUG:📤 StoryCreator: Iniciando publicación de story")
        print("DEBUG:📊 StoryCreator: Tipo: \(selectedType.rawValue), Privacidad: \(privacy.rawValue)")

        isPublishing = true

        Task {
            var workoutData: WorkoutData? = nil

            if selectedType == .workout {
                print("DEBUG:🏋️ StoryCreator: Preparando datos de workout")
                workoutData = WorkoutData(
                    exercise: exercise,
                    weight: Double(weight),
                    weightUnit: "kg",
                    reps: Int(reps),
                    sets: Int(sets),
                    durationMinutes: nil,
                    caloriesBurned: nil,
                    notes: workoutNotes.isEmpty ? nil : workoutNotes
                )
            }

            let storyCaption = selectedType == .text ? storyText : caption
            let mediaData = selectedImage?.jpegData(compressionQuality: 0.8)

            _ = await storyService.createStory(
                type: selectedType,
                caption: storyCaption,
                mediaData: mediaData,
                workoutData: workoutData,
                privacy: privacy,
                duration: duration
            )

            await MainActor.run {
                isPublishing = false
                if storyService.successMessage != nil {
                    // Story was created successfully, dismiss will happen after alert
                }
            }
        }
    }
}

// MARK: - Story Type Selector
struct StoryTypeSelector: View {
    @Binding var selectedType: StoryType
    @EnvironmentObject var themeManager: ThemeManager

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ForEach(StoryType.allCases, id: \.self) { type in
                    StoryTypeButton(
                        type: type,
                        isSelected: selectedType == type,
                        action: { selectedType = type }
                    )
                }
            }
        }
    }
}

// MARK: - Story Type Button
struct StoryTypeButton: View {
    let type: StoryType
    let isSelected: Bool
    let action: () -> Void
    @EnvironmentObject var themeManager: ThemeManager

    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Image(systemName: type.icon)
                    .font(.title2)
                Text(type.displayName)
                    .font(.caption)
            }
            .foregroundColor(isSelected ? .white : Color.dynamicText(theme: themeManager.currentTheme))
            .frame(width: 80, height: 60)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(
                        isSelected ?
                        LinearGradient(
                            colors: [Color(hex: "D93333") ?? Color.red, Color(hex: "FF6B6B") ?? Color.red.opacity(0.8)],
                            startPoint: .leading,
                            endPoint: .trailing
                        ) :
                        LinearGradient(
                            colors: [Color.dynamicSurface(theme: themeManager.currentTheme)],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
            )
        }
    }
}

// MARK: - Privacy Picker View
struct PrivacyPickerView: View {
    @Binding var selectedPrivacy: StoryPrivacy
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var themeManager: ThemeManager

    var body: some View {
        NavigationView {
            List(StoryPrivacy.allCases, id: \.self) { privacy in
                Button(action: {
                    selectedPrivacy = privacy
                    dismiss()
                }) {
                    HStack {
                        Image(systemName: privacy.icon)
                            .frame(width: 30)
                        Text(privacy.displayName)
                        Spacer()
                        if selectedPrivacy == privacy {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(Color(hex: "D93333") ?? Color.red)
                        }
                    }
                }
                .foregroundColor(Color.dynamicText(theme: themeManager.currentTheme))
            }
            .navigationTitle("Privacidad")
            .navigationBarTitleDisplayMode(.inline)
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