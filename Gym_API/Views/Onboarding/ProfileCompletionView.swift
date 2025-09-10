import SwiftUI
import Auth0

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
            
            VStack(spacing: 40) {
                // Main Icon with gradient background
                ZStack {
                    // Gradient background circle
                    LinearGradient(
                        gradient: Gradient(colors: [
                            Color.dynamicAccent(theme: themeManager.currentTheme),
                            Color.dynamicAccent(theme: themeManager.currentTheme).opacity(0.7)
                        ]),
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                    .frame(width: 120, height: 120)
                    .clipShape(Circle())
                    .shadow(color: Color.dynamicAccent(theme: themeManager.currentTheme).opacity(0.3), 
                            radius: 20, x: 0, y: 10)
                    
                    Image(systemName: "figure.walk")
                        .font(.system(size: 60, weight: .medium))
                        .foregroundColor(.white)
                }
                
                // Welcome Message
                VStack(spacing: 16) {
                    Text("Complete Your Profile")
                        .font(.system(size: 32, weight: .bold, design: .rounded))
                        .foregroundColor(Color.dynamicText(theme: themeManager.currentTheme))
                        .multilineTextAlignment(.center)
                    
                    Text("Help us personalize your fitness journey")
                        .font(.system(size: 18, weight: .medium))
                        .foregroundColor(Color.dynamicText(theme: themeManager.currentTheme).opacity(0.7))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32)
                }
                
                // Info cards
                VStack(spacing: 16) {
                    ProfileInfoRow(icon: "person.fill", text: "Basic Information", theme: themeManager.currentTheme)
                    ProfileInfoRow(icon: "ruler.fill", text: "Physical Metrics", theme: themeManager.currentTheme)
                    ProfileInfoRow(icon: "text.quote", text: "About You (Optional)", theme: themeManager.currentTheme)
                }
                .padding(.horizontal, 40)
            }
            
            Spacer()
            
            // Bottom section with progress and button
            VStack(spacing: 24) {
                // Progress dots indicator
                HStack(spacing: 8) {
                    ForEach(0..<4) { index in
                        Circle()
                            .fill(index == 0 ? 
                                  Color.dynamicAccent(theme: themeManager.currentTheme) :
                                  Color.dynamicText(theme: themeManager.currentTheme).opacity(0.2))
                            .frame(width: 8, height: 8)
                            .animation(.easeInOut, value: currentStep)
                    }
                }
                
                // Continue Button with gradient
                Button(action: {
                    withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                        showingIntro = false
                    }
                }) {
                    HStack(spacing: 8) {
                        Text("Let's Get Started")
                            .font(.system(size: 18, weight: .semibold))
                        
                        Image(systemName: "arrow.right")
                            .font(.system(size: 16, weight: .semibold))
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 56)
                    .background(
                        LinearGradient(
                            gradient: Gradient(colors: [
                                Color.dynamicAccent(theme: themeManager.currentTheme),
                                Color.dynamicAccent(theme: themeManager.currentTheme).opacity(0.8)
                            ]),
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .cornerRadius(16)
                    .shadow(color: Color.dynamicAccent(theme: themeManager.currentTheme).opacity(0.3), 
                            radius: 8, x: 0, y: 4)
                }
                .padding(.horizontal, 32)
                
                // Skip option
                Button(action: {
                    // Permitir saltar el onboarding por ahora
                    onCompletion()
                }) {
                    Text("Skip for now")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(Color.dynamicText(theme: themeManager.currentTheme).opacity(0.5))
                        .underline()
                }
            }
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
            
            // Spacer para separar el contenido del formulario de los botones
            Spacer(minLength: 32)
            
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
            
            // Agregar más espaciado en la vista de estadísticas físicas para separar de los botones
            Spacer(minLength: 24)
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

// MARK: - Supporting Views
struct ProfileInfoRow: View {
    let icon: String
    let text: String
    let theme: ThemeManager.AppTheme
    
    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: icon)
                .font(.system(size: 20, weight: .medium))
                .foregroundColor(Color.dynamicAccent(theme: theme))
                .frame(width: 30)
            
            Text(text)
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(Color.dynamicText(theme: theme).opacity(0.8))
            
            Spacer()
            
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 20))
                .foregroundColor(Color.dynamicText(theme: theme).opacity(0.2))
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.dynamicSurface(theme: theme))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.dynamicText(theme: theme).opacity(0.1), lineWidth: 1)
                )
        )
    }
}

#Preview {
    ProfileCompletionView(onCompletion: {})
        .environmentObject(AuthServiceDirect())
        .environmentObject(ThemeManager())
}