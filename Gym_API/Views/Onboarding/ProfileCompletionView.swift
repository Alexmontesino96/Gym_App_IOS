import SwiftUI

struct ProfileCompletionView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var authService: AuthServiceDirect
    @EnvironmentObject var themeManager: ThemeManager
    @StateObject private var profileService = UserProfileService.shared
    
    @State private var firstName = ""
    @State private var lastName = ""
    @State private var selectedYear = Calendar.current.component(.year, from: Date()) - 25
    @State private var selectedHeight = 170
    @State private var selectedWeight = 70
    @State private var bio = ""
    
    @State private var currentStep = 0
    @State private var isLoading = false
    @State private var showingIntro = true
    @State private var errorMessage: String?
    @State private var showingError = false
    
    var onCompletion: () -> Void
    
    init(onCompletion: @escaping () -> Void) {
        self.onCompletion = onCompletion
    }
    
    var body: some View {
        ZStack {
            // Dynamic Background
            Color.dynamicBackground(theme: themeManager.currentTheme)
                .ignoresSafeArea()
            
            if showingIntro {
                introScreen
            } else {
                profileFormScreen
            }
        }
        .alert("Error", isPresented: $showingError) {
            Button("OK") { }
        } message: {
            Text(errorMessage ?? "An error occurred")
        }
        .onAppear {
            setupServices()
            loadExistingProfile()
        }
    }
    
    // MARK: - Intro Screen
    private var introScreen: some View {
        VStack(spacing: 0) {
            Spacer()
            
            VStack(spacing: 32) {
                // Loading Animation
                VStack(spacing: 20) {
                    ZStack {
                        Circle()
                            .stroke(Color.dynamicAccent(theme: themeManager.currentTheme).opacity(0.2), lineWidth: 4)
                            .frame(width: 80, height: 80)
                        
                        Circle()
                            .trim(from: 0, to: 0.7)
                            .stroke(Color.dynamicAccent(theme: themeManager.currentTheme), 
                                    style: StrokeStyle(lineWidth: 4, lineCap: .round))
                            .frame(width: 80, height: 80)
                            .rotationEffect(.degrees(-90))
                            .animation(.linear(duration: 2).repeatForever(autoreverses: false), value: showingIntro)
                    }
                    
                    Image(systemName: "person.crop.circle.fill.badge.plus")
                        .font(.system(size: 50, weight: .medium))
                        .foregroundColor(Color.dynamicAccent(theme: themeManager.currentTheme))
                }
                
                // Welcome Message
                VStack(spacing: 16) {
                    Text("Creating Your Experience")
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                        .foregroundColor(Color.dynamicText(theme: themeManager.currentTheme))
                        .multilineTextAlignment(.center)
                    
                    Text("We need some basic information to create an amazing personalized experience tailored just for you!")
                        .font(.system(size: 18, weight: .medium))
                        .foregroundColor(Color.dynamicText(theme: themeManager.currentTheme).opacity(0.7))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32)
                        .lineLimit(nil)
                }
            }
            
            Spacer()
            
            // Continue Button
            Button(action: {
                withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                    showingIntro = false
                }
            }) {
                Text("Let's Get Started")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 56)
                    .background(
                        LinearGradient(
                            colors: [
                                Color.dynamicAccent(theme: themeManager.currentTheme),
                                Color.dynamicAccent(theme: themeManager.currentTheme).opacity(0.8)
                            ],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .cornerRadius(16)
                    .shadow(color: Color.dynamicAccent(theme: themeManager.currentTheme).opacity(0.3), 
                            radius: 8, x: 0, y: 4)
            }
            .padding(.horizontal, 32)
            .padding(.bottom, 50)
        }
    }
    
    // MARK: - Profile Form Screen
    private var profileFormScreen: some View {
        VStack(spacing: 0) {
            // Header with progress
            VStack(spacing: 20) {
                // Progress Indicator
                HStack(spacing: 8) {
                    ForEach(0..<3, id: \.self) { index in
                        RoundedRectangle(cornerRadius: 2)
                            .fill(index <= currentStep ? Color.dynamicAccent(theme: themeManager.currentTheme) : 
                                  Color.dynamicAccent(theme: themeManager.currentTheme).opacity(0.2))
                            .frame(height: 4)
                    }
                }
                .padding(.horizontal, 32)
                .padding(.top, 20)
                
                // Step Title
                Text(stepTitle)
                    .font(.system(size: 24, weight: .bold, design: .rounded))
                    .foregroundColor(Color.dynamicText(theme: themeManager.currentTheme))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }
            
            // Form Content
            TabView(selection: $currentStep) {
                nameStepView.tag(0)
                physicalStatsStepView.tag(1)
                bioStepView.tag(2)
            }
            .tabViewStyle(PageTabViewStyle(indexDisplayMode: .never))
            .animation(.easeInOut, value: currentStep)
            
            // Navigation Buttons
            VStack(spacing: 16) {
                Button(action: nextStep) {
                    HStack {
                        if isLoading && currentStep == 2 {
                            ProgressView()
                                .scaleEffect(0.9)
                                .tint(.white)
                        } else {
                            Text(currentStep == 2 ? "Complete Profile" : "Continue")
                                .font(.system(size: 18, weight: .semibold))
                        }
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 56)
                    .background(
                        LinearGradient(
                            colors: isStepValid ? [
                                Color.dynamicAccent(theme: themeManager.currentTheme),
                                Color.dynamicAccent(theme: themeManager.currentTheme).opacity(0.8)
                            ] : [Color.gray.opacity(0.3), Color.gray.opacity(0.2)],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .cornerRadius(16)
                    .disabled(!isStepValid || isLoading)
                }
                
                if currentStep > 0 {
                    Button("Back") {
                        withAnimation {
                            currentStep -= 1
                        }
                    }
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(Color.dynamicText(theme: themeManager.currentTheme).opacity(0.6))
                }
                
                Button("Skip for Now") {
                    onCompletion()
                }
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(Color.dynamicText(theme: themeManager.currentTheme).opacity(0.5))
            }
            .padding(.horizontal, 32)
            .padding(.bottom, 50)
        }
    }
    
    // MARK: - Step Views
    private var nameStepView: some View {
        VStack(spacing: 32) {
            Spacer()
            
            VStack(spacing: 24) {
                VStack(alignment: .leading, spacing: 16) {
                    Text("First Name")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(Color.dynamicText(theme: themeManager.currentTheme).opacity(0.7))
                    
                    TextField("Enter your first name", text: $firstName)
                        .font(.system(size: 20, weight: .medium))
                        .foregroundColor(Color.dynamicText(theme: themeManager.currentTheme))
                        .padding(.vertical, 16)
                        .padding(.horizontal, 20)
                        .background(
                            RoundedRectangle(cornerRadius: 16)
                                .fill(Color.dynamicSurface(theme: themeManager.currentTheme))
                                .stroke(Color.dynamicAccent(theme: themeManager.currentTheme).opacity(0.2), lineWidth: 1)
                        )
                }
                
                VStack(alignment: .leading, spacing: 16) {
                    Text("Last Name")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(Color.dynamicText(theme: themeManager.currentTheme).opacity(0.7))
                    
                    TextField("Enter your last name", text: $lastName)
                        .font(.system(size: 20, weight: .medium))
                        .foregroundColor(Color.dynamicText(theme: themeManager.currentTheme))
                        .padding(.vertical, 16)
                        .padding(.horizontal, 20)
                        .background(
                            RoundedRectangle(cornerRadius: 16)
                                .fill(Color.dynamicSurface(theme: themeManager.currentTheme))
                                .stroke(Color.dynamicAccent(theme: themeManager.currentTheme).opacity(0.2), lineWidth: 1)
                        )
                }
            }
            
            Spacer()
        }
        .padding(.horizontal, 32)
    }
    
    private var physicalStatsStepView: some View {
        VStack(spacing: 32) {
            Spacer()
            
            VStack(spacing: 40) {
                // Birth Year Picker
                VStack(spacing: 20) {
                    Text("Birth Year")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(Color.dynamicText(theme: themeManager.currentTheme))
                    
                    VStack {
                        Picker("Birth Year", selection: $selectedYear) {
                            ForEach(1940...Calendar.current.component(.year, from: Date()), id: \.self) { year in
                                Text("\(year)")
                                    .foregroundColor(Color.dynamicText(theme: themeManager.currentTheme))
                                    .tag(year)
                            }
                        }
                        .pickerStyle(WheelPickerStyle())
                        .frame(height: 120)
                    }
                    .padding(.horizontal, 20)
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(Color.dynamicSurface(theme: themeManager.currentTheme))
                            .stroke(Color.dynamicAccent(theme: themeManager.currentTheme).opacity(0.2), lineWidth: 1)
                    )
                }
                
                // Height and Weight Pickers
                HStack(spacing: 20) {
                    // Height Picker
                    VStack(spacing: 16) {
                        Text("Height")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(Color.dynamicText(theme: themeManager.currentTheme))
                        
                        VStack {
                            Picker("Height", selection: $selectedHeight) {
                                ForEach(140...220, id: \.self) { height in
                                    Text("\(height) cm")
                                        .foregroundColor(Color.dynamicText(theme: themeManager.currentTheme))
                                        .tag(height)
                                }
                            }
                            .pickerStyle(WheelPickerStyle())
                            .frame(height: 100)
                        }
                        .padding(.horizontal, 12)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color.dynamicSurface(theme: themeManager.currentTheme))
                                .stroke(Color.dynamicAccent(theme: themeManager.currentTheme).opacity(0.2), lineWidth: 1)
                        )
                    }
                    
                    // Weight Picker
                    VStack(spacing: 16) {
                        Text("Weight")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(Color.dynamicText(theme: themeManager.currentTheme))
                        
                        VStack {
                            Picker("Weight", selection: $selectedWeight) {
                                ForEach(35...200, id: \.self) { weight in
                                    Text("\(weight) kg")
                                        .foregroundColor(Color.dynamicText(theme: themeManager.currentTheme))
                                        .tag(weight)
                                }
                            }
                            .pickerStyle(WheelPickerStyle())
                            .frame(height: 100)
                        }
                        .padding(.horizontal, 12)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color.dynamicSurface(theme: themeManager.currentTheme))
                                .stroke(Color.dynamicAccent(theme: themeManager.currentTheme).opacity(0.2), lineWidth: 1)
                        )
                    }
                }
            }
            
            Spacer()
        }
        .padding(.horizontal, 32)
    }
    
    private var bioStepView: some View {
        VStack(spacing: 32) {
            Spacer()
            
            VStack(alignment: .leading, spacing: 24) {
                Text("Tell us about yourself")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(Color.dynamicText(theme: themeManager.currentTheme))
                
                TextField("Share your fitness goals, interests, or anything you'd like us to know (optional)", text: $bio, axis: .vertical)
                    .font(.system(size: 16, weight: .regular))
                    .foregroundColor(Color.dynamicText(theme: themeManager.currentTheme))
                    .padding(.vertical, 20)
                    .padding(.horizontal, 20)
                    .lineLimit(4...8)
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(Color.dynamicSurface(theme: themeManager.currentTheme))
                            .stroke(Color.dynamicAccent(theme: themeManager.currentTheme).opacity(0.2), lineWidth: 1)
                    )
                
                Text("This helps us personalize your gym experience and recommend activities you'll love!")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(Color.dynamicText(theme: themeManager.currentTheme).opacity(0.6))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 8)
            }
            
            Spacer()
        }
        .padding(.horizontal, 32)
    }
    
    // MARK: - Computed Properties
    private var stepTitle: String {
        switch currentStep {
        case 0: return "What's your name?"
        case 1: return "Tell us about yourself"
        case 2: return "Almost done!"
        default: return ""
        }
    }
    
    private var isStepValid: Bool {
        switch currentStep {
        case 0: return !firstName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
                       !lastName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        case 1: return true // Physical stats always valid with pickers
        case 2: return true // Bio is optional
        default: return false
        }
    }
    
    private func nextStep() {
        if currentStep == 2 {
            saveProfile()
        } else {
            withAnimation {
                currentStep += 1
            }
        }
    }
    
    private func saveProfile() {
        isLoading = true
        errorMessage = nil
        
        Task {
            // Crear fecha de nacimiento del año seleccionado
            let calendar = Calendar.current
            var dateComponents = DateComponents()
            dateComponents.year = selectedYear
            dateComponents.month = 1
            dateComponents.day = 1
            let birthDate = calendar.date(from: dateComponents) ?? Date()
            
            let success = await profileService.updateProfile(
                firstName: firstName.trimmingCharacters(in: .whitespacesAndNewlines),
                lastName: lastName.trimmingCharacters(in: .whitespacesAndNewlines),
                birthDate: birthDate,
                height: Double(selectedHeight),
                weight: Double(selectedWeight),
                bio: bio.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : bio
            )
            
            await MainActor.run {
                isLoading = false
                
                if success {
                    onCompletion()
                } else {
                    errorMessage = "Failed to update profile. Please try again."
                    showingError = true
                }
            }
        }
    }
    
    private func setupServices() {
        profileService.authService = authService
    }
    
    private func loadExistingProfile() {
        Task {
            await profileService.fetchUserProfile()
            
            await MainActor.run {
                if let profile = profileService.userProfile {
                    firstName = profile.firstName
                    lastName = profile.lastName
                    if let profileHeight = profile.height {
                        selectedHeight = Int(profileHeight)
                    }
                    if let profileWeight = profile.weight {
                        selectedWeight = Int(profileWeight)
                    }
                    if let profileBirthDate = profile.birthDate {
                        let calendar = Calendar.current
                        selectedYear = calendar.component(.year, from: profileBirthDate)
                    }
                    bio = profile.bio ?? ""
                }
            }
        }
    }
}

// MARK: - Custom Text Field Style
struct CustomTextFieldStyle: TextFieldStyle {
    func _body(configuration: TextField<Self._Label>) -> some View {
        configuration
            .padding()
            .background(Color(.systemGray6))
            .cornerRadius(12)
    }
}

// MARK: - Date Picker Sheet
struct DatePickerSheet: View {
    @Binding var selectedDate: Date
    @Binding var isPresented: Bool
    
    var body: some View {
        NavigationView {
            VStack {
                DatePicker(
                    "Birth Date",
                    selection: $selectedDate,
                    in: ...Date(),
                    displayedComponents: .date
                )
                .datePickerStyle(.wheel)
                .padding()
                
                Spacer()
            }
            .navigationTitle("Select Birth Date")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        isPresented = false
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        isPresented = false
                    }
                    .fontWeight(.semibold)
                }
            }
        }
    }
}

#Preview {
    ProfileCompletionView(onCompletion: {})
        .environmentObject(AuthServiceDirect())
}