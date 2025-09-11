import SwiftUI

// MARK: - Profile Metrics Container
struct ProfileMetricsContainer: View {
    let workouts: Int
    let weight: Double?
    let height: Double?
    let theme: ThemeManager.AppTheme
    @Binding var showCelebration: Bool
    
    @State private var containerOpacity = 0.0
    @State private var backgroundScale = 0.9
    @State private var glowAnimation = false
    @State private var hasAnimated = false
    
    // Check if profile is complete
    private var isProfileComplete: Bool {
        weight != nil && height != nil && workouts > 0
    }
    
    var body: some View {
        ZStack {
            // Background with its own scale animation
            RoundedRectangle(cornerRadius: 20)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(
                            Color.dynamicAccent(theme: theme).opacity(0.2),
                            lineWidth: 1
                        )
                )
                .shadow(
                    color: Color.black.opacity(0.1),
                    radius: 5,
                    x: 0,
                    y: 2
                )
                .scaleEffect(backgroundScale)
                .opacity(containerOpacity)
            
            // Content without scale effect
            HStack(spacing: 25) {
                // Workouts metric
                AnimatedProfileMetric(
                    icon: "dumbbell.fill",
                    value: "\(workouts)",
                    label: "Workouts",
                    color: Color.dynamicAccent(theme: theme),
                    delay: hasAnimated ? 0 : 0.3,
                    theme: theme
                )
                .frame(maxWidth: .infinity)
                
                // Weight metric
                AnimatedProfileMetric(
                    icon: "scalemass.fill",
                    value: weight != nil ? "\(Int(weight!)) kg" : "63 kg",
                    label: "Weight",
                    color: Color.dynamicAccent(theme: theme),
                    delay: hasAnimated ? 0 : 0.5,
                    theme: theme
                )
                .frame(maxWidth: .infinity)
                
                // Height metric
                AnimatedProfileMetric(
                    icon: "arrow.up.and.down",
                    value: height != nil ? "\(Int(height!)) cm" : "179 cm",
                    label: "Height",
                    color: Color.dynamicAccent(theme: theme),
                    delay: hasAnimated ? 0 : 0.7,
                    theme: theme
                )
                .frame(maxWidth: .infinity)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 14)
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 20)  // Margen externo para separar de los bordes
        .onAppear {
            if !hasAnimated {
                animateContainer()
            } else {
                backgroundScale = 1.0
                containerOpacity = 1.0
            }
        }
    }
    
    private func animateContainer() {
        // Background entrance animation only
        withAnimation(.spring(response: 0.8, dampingFraction: 0.7)) {
            backgroundScale = 1.0
            containerOpacity = 1.0
        }
        
        // Check for celebration after metrics load
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            checkForCelebration()
            hasAnimated = true
        }
    }
    
    private func checkForCelebration() {
        let celebrationKey = "ProfileCompletionCelebrationShown"
        let hasShownCelebration = UserDefaults.standard.bool(forKey: celebrationKey)
        
        if isProfileComplete && !hasShownCelebration {
            showCelebration = true
            UserDefaults.standard.set(true, forKey: celebrationKey)
            
            // Haptic feedback
            let generator = UIImpactFeedbackGenerator(style: .medium)
            generator.impactOccurred()
        }
    }
}

// MARK: - Enhanced Metrics Container with Edit
struct EnhancedProfileMetricsContainer: View {
    @ObservedObject var profileService: UserProfileService
    @ObservedObject var userStatsService: UserStatsService
    let theme: ThemeManager.AppTheme
    @Binding var showCelebration: Bool
    @State private var showingEditSheet = false
    
    var body: some View {
        VStack(spacing: 12) {
            ProfileMetricsContainer(
                workouts: userStatsService.userStats.monthlyClasses,
                weight: profileService.userProfile?.weight,
                height: profileService.userProfile?.height,
                theme: theme,
                showCelebration: $showCelebration
            )
            
            // Edit button
            if profileService.userProfile?.weight == nil || profileService.userProfile?.height == nil {
                Button(action: { showingEditSheet = true }) {
                    HStack(spacing: 6) {
                        Image(systemName: "pencil.circle.fill")
                            .font(.system(size: 14))
                        Text("Complete Your Profile")
                            .font(.system(size: 14, weight: .medium))
                    }
                    .foregroundColor(Color.dynamicAccent(theme: theme))
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(
                        Capsule()
                            .fill(Color.dynamicAccent(theme: theme).opacity(0.1))
                            .overlay(
                                Capsule()
                                    .stroke(Color.dynamicAccent(theme: theme).opacity(0.3), lineWidth: 1)
                            )
                    )
                }
                .sheet(isPresented: $showingEditSheet) {
                    ProfileMetricsEditSheet(
                        profileService: profileService,
                        theme: theme
                    )
                }
            }
        }
    }
}

// MARK: - Profile Metrics Edit Sheet
struct ProfileMetricsEditSheet: View {
    @ObservedObject var profileService: UserProfileService
    let theme: ThemeManager.AppTheme
    @Environment(\.dismiss) private var dismiss
    
    @State private var weight: String = ""
    @State private var height: String = ""
    @State private var isSaving = false
    
    var body: some View {
        NavigationView {
            VStack(spacing: 24) {
                Text("Complete Your Profile")
                    .font(.system(size: 24, weight: .bold))
                    .foregroundColor(Color.dynamicText(theme: theme))
                    .padding(.top, 20)
                
                VStack(spacing: 20) {
                    // Weight input
                    VStack(alignment: .leading, spacing: 8) {
                        Label("Weight (kg)", systemImage: "scalemass.fill")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(Color.dynamicTextSecondary(theme: theme))
                        
                        TextField("Enter weight", text: $weight)
                            .keyboardType(.decimalPad)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                    }
                    
                    // Height input
                    VStack(alignment: .leading, spacing: 8) {
                        Label("Height (cm)", systemImage: "arrow.up.and.down")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(Color.dynamicTextSecondary(theme: theme))
                        
                        TextField("Enter height", text: $height)
                            .keyboardType(.numberPad)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                    }
                }
                .padding(.horizontal, 20)
                
                Spacer()
                
                // Save button
                Button(action: saveMetrics) {
                    if isSaving {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                    } else {
                        Text("Save")
                            .font(.system(size: 16, weight: .semibold))
                    }
                }
                .frame(maxWidth: .infinity)
                .frame(height: 50)
                .background(Color.dynamicAccent(theme: theme))
                .foregroundColor(.white)
                .cornerRadius(12)
                .padding(.horizontal, 20)
                .disabled(isSaving || weight.isEmpty || height.isEmpty)
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Cancel") { dismiss() }
                        .foregroundColor(Color.dynamicAccent(theme: theme))
                }
            }
        }
        .onAppear {
            if let profile = profileService.userProfile {
                weight = profile.weight != nil ? "\(Int(profile.weight!))" : ""
                height = profile.height != nil ? "\(Int(profile.height!))" : ""
            }
        }
    }
    
    private func saveMetrics() {
        guard let weightValue = Double(weight),
              let heightValue = Double(height) else { return }
        
        isSaving = true
        
        Task {
            // Update profile with new metrics using the service method
            let success = await profileService.updateProfile(
                firstName: nil,
                lastName: nil,
                birthDate: nil,
                height: heightValue,
                weight: weightValue,
                bio: nil
            )
            
            if success {
                // Refresh the profile to get updated data
                await profileService.fetchUserProfile()
            }
            
            dismiss()
        }
    }
}