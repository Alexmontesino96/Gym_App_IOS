import SwiftUI
import Auth0

// MARK: - Coach Selector View
struct CoachSelectorView: View {
    // MARK: - Environment Objects
    @EnvironmentObject var themeManager: ThemeManager
    @EnvironmentObject var authService: AuthServiceDirect
    
    // MARK: - State Objects
    @StateObject private var chatService = ChatService.shared
    
    // MARK: - Bindings
    @Binding var isPresented: Bool
    
    // MARK: - Completion Handler
    let onCoachSelected: (UserProfile) -> Void
    
    // MARK: - State Variables
    @State private var searchText = ""
    @State private var isLoading = true
    @State private var coaches: [UserProfile] = []
    @State private var errorMessage: String?
    @State private var hasInitialized = false
    
    // MARK: - Computed Properties
    private var filteredCoaches: [UserProfile] {
        if searchText.isEmpty {
            return coaches
        } else {
            return coaches.filter { coach in
                coach.fullName.localizedCaseInsensitiveContains(searchText) ||
                (coach.role.localizedCaseInsensitiveContains(searchText)) ||
                (coach.gymRole?.localizedCaseInsensitiveContains(searchText) == true)
            }
        }
    }
    
    private var isCurrentUserCoach: Bool {
        // Check if current user has coach role
        return authService.user?.isCoach ?? false
    }
    
    // MARK: - Body
    var body: some View {
        NavigationView {
            ZStack {
                Color.dynamicBackground(theme: themeManager.currentTheme)
                    .ignoresSafeArea()
                
                VStack(spacing: 0) {
                    // Search Bar
                    searchBarView
                    
                    // Content
                    contentView
                }
            }
            .navigationTitle("Select Coach")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        isPresented = false
                    }
                    .foregroundColor(Color.dynamicAccent(theme: themeManager.currentTheme))
                }
            }
            .onAppear {
                initializeIfNeeded()
            }
        }
    }
    
    // MARK: - Search Bar View
    private var searchBarView: some View {
        HStack(spacing: 12) {
            // Search icon
            Image(systemName: "magnifyingglass")
                .foregroundColor(.secondary)
                .font(.system(size: 16, weight: .medium))
            
            // Search field
            TextField("Search coaches...", text: $searchText)
                .textFieldStyle(PlainTextFieldStyle())
                .autocorrectionDisabled()
            
            // Clear button
            if !searchText.isEmpty {
                Button(action: { searchText = "" }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.secondary)
                        .font(.system(size: 16))
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.dynamicSurface(theme: themeManager.currentTheme))
                .stroke(
                    Color.dynamicAccent(theme: themeManager.currentTheme).opacity(0.2),
                    lineWidth: 1
                )
        )
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
    }
    
    // MARK: - Content View
    private var contentView: some View {
        Group {
            if isLoading {
                loadingView
            } else if let error = errorMessage {
                errorView(error)
            } else if filteredCoaches.isEmpty {
                emptyStateView
            } else {
                coachesList
            }
        }
    }
    
    // MARK: - Loading View
    private var loadingView: some View {
        VStack(spacing: 20) {
            ProgressView()
                .progressViewStyle(CircularProgressViewStyle(
                    tint: Color.dynamicAccent(theme: themeManager.currentTheme)
                ))
                .scaleEffect(1.2)
            
            Text("Loading coaches...")
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(Color.dynamicTextSecondary(theme: themeManager.currentTheme))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    // MARK: - Error View
    private func errorView(_ error: String) -> some View {
        VStack(spacing: 20) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 48, weight: .light))
                .foregroundColor(.orange)
            
            Text("Error loading coaches")
                .font(.system(size: 20, weight: .semibold))
                .foregroundColor(Color.dynamicText(theme: themeManager.currentTheme))
            
            Text(error)
                .font(.system(size: 14))
                .foregroundColor(Color.dynamicTextSecondary(theme: themeManager.currentTheme))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 20)
            
            Button(action: {
                Task { await loadCoaches() }
            }) {
                HStack(spacing: 8) {
                    Image(systemName: "arrow.clockwise")
                    Text("Try again")
                }
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(.white)
                .padding(.horizontal, 24)
                .padding(.vertical, 12)
                .background(
                    RoundedRectangle(cornerRadius: 20)
                        .fill(Color.dynamicAccent(theme: themeManager.currentTheme))
                )
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(40)
    }
    
    // MARK: - Empty State View
    private var emptyStateView: some View {
        VStack(spacing: 24) {
            Image(systemName: searchText.isEmpty ? "person.badge.shield.checkmark" : "magnifyingglass")
                .font(.system(size: 48, weight: .light))
                .foregroundColor(Color.dynamicAccent(theme: themeManager.currentTheme))
            
            VStack(spacing: 12) {
                Text(searchText.isEmpty ? "No coaches found" : "No coaches match your search")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundColor(Color.dynamicText(theme: themeManager.currentTheme))
                
                Text(searchText.isEmpty ? 
                     "There are no coaches available in your gym at the moment." :
                     "Try adjusting your search terms to find the coach you're looking for.")
                    .font(.system(size: 16))
                    .foregroundColor(Color.dynamicTextSecondary(theme: themeManager.currentTheme))
                    .multilineTextAlignment(.center)
                    .lineLimit(nil)
                    .padding(.horizontal, 20)
            }
            
            if !searchText.isEmpty {
                Button(action: { searchText = "" }) {
                    Text("Clear search")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(Color.dynamicAccent(theme: themeManager.currentTheme))
                        .padding(.horizontal, 20)
                        .padding(.vertical, 10)
                        .background(
                            RoundedRectangle(cornerRadius: 20)
                                .stroke(Color.dynamicAccent(theme: themeManager.currentTheme), lineWidth: 1.5)
                        )
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(40)
    }
    
    // MARK: - Coaches List
    private var coachesList: some View {
        ScrollView {
            LazyVStack(spacing: 1) {
                ForEach(filteredCoaches) { coach in
                    CoachRowView(
                        coach: coach,
                        themeManager: themeManager,
                        onTap: {
                            // Haptic feedback
                            let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
                            impactFeedback.impactOccurred()
                            
                            // Call completion handler
                            onCoachSelected(coach)
                            
                            // Dismiss view
                            isPresented = false
                        }
                    )
                }
                
                // Bottom padding
                Color.clear
                    .frame(height: 20)
            }
        }
        .refreshable {
            await loadCoaches()
        }
    }
    
    // MARK: - Methods
    private func initializeIfNeeded() {
        guard !hasInitialized else { return }
        hasInitialized = true
        
        Task {
            await loadCoaches()
        }
    }
    
    private func loadCoaches() async {
        print("🏃‍♂️ Iniciando carga de coaches...")
        
        await MainActor.run {
            isLoading = true
            errorMessage = nil
        }
        
        // Configure authService
        chatService.authService = authService
        
        // Load gym members
        await chatService.loadGymMembers()
        
        // Get all coaches from the service
        let allCoaches = await chatService.getAvailableCoaches()

        await MainActor.run {
            // Use the filtered coaches from service
            self.coaches = allCoaches

            self.isLoading = false

            print("✅ Coaches cargados: \(self.coaches.count)")
            for coach in self.coaches {
                print("   - \(coach.fullName) (\(coach.role)) - Gym Role: \(coach.gymRole ?? "N/A")")
            }
        }
    }
}

// MARK: - Preview
#Preview {
    CoachSelectorView(
        isPresented: .constant(true),
        onCoachSelected: { _ in }
    )
    .environmentObject(ThemeManager())
    .environmentObject(AuthServiceDirect())
}