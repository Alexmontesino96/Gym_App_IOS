import SwiftUI

struct AvailableGymsView: View {
    @EnvironmentObject var themeManager: ThemeManager
    @EnvironmentObject var gymService: GymService
    @EnvironmentObject var authService: AuthServiceDirect
    @State private var searchText = ""
    @State private var isAnimating = false
    @State private var selectedGym: Gym?
    @State private var showingGymDetail = false
    @State private var showingLogin = false
    @Environment(\.dismiss) private var dismiss
    
    // Optional parameter to determine if Cancel button should be shown
    var showCancelButton: Bool = true
    
    var filteredGyms: [Gym] {
        if searchText.isEmpty {
            return gymService.allGyms
        }
        return gymService.allGyms.filter { gym in
            gym.name.localizedCaseInsensitiveContains(searchText) ||
            (gym.address?.localizedCaseInsensitiveContains(searchText) ?? false) ||
            (gym.description?.localizedCaseInsensitiveContains(searchText) ?? false)
        }
    }
    
    var body: some View {
        let _ = print("🔍 AvailableGymsView - authService.isAuthenticated: \(authService.isAuthenticated)")
        let _ = print("🔍 AvailableGymsView - user email: \(authService.user?.email ?? "No user")")
        
        NavigationView {
            ZStack {
                Color.dynamicBackground(theme: themeManager.currentTheme).ignoresSafeArea()
                
                VStack(spacing: 0) {
                    // Header
                    VStack(alignment: .leading, spacing: 16) {
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Choose Your Gym")
                                    .font(.system(size: 28, weight: .bold))
                                    .foregroundColor(Color.dynamicText(theme: themeManager.currentTheme))
                                
                                Text("Find the perfect place to start your fitness journey")
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundColor(Color.dynamicTextSecondary(theme: themeManager.currentTheme))
                            }
                            
                            Spacer()
                            
                            // Account menu
                            if authService.isAuthenticated {
                                Menu {
                                    Text("Logged in as:")
                                        .font(.caption)
                                    Text(authService.user?.email ?? "User")
                                        .font(.caption.bold())
                                    Divider()
                                    Button("Sign Out") {
                                        Task {
                                            await authService.logout()
                                        }
                                    }
                                } label: {
                                    HStack(spacing: 4) {
                                        Image(systemName: "person.circle.fill")
                                        Text("Account")
                                    }
                                    .font(.system(size: 16, weight: .medium))
                                    .foregroundColor(Color.dynamicAccent(theme: themeManager.currentTheme))
                                }
                            } else {
                                Button("Log In") {
                                    showingLogin = true
                                }
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(Color.dynamicAccent(theme: themeManager.currentTheme))
                            }
                        }
                        
                        // Search Bar
                        HStack {
                            Image(systemName: "magnifyingglass")
                                .foregroundColor(Color.dynamicTextSecondary(theme: themeManager.currentTheme))
                                .font(.system(size: 16))
                            
                            TextField("Search gyms...", text: $searchText)
                                .textFieldStyle(PlainTextFieldStyle())
                                .foregroundColor(Color.dynamicText(theme: themeManager.currentTheme))
                                .autocorrectionDisabled()
                            
                            if !searchText.isEmpty {
                                Button(action: {
                                    searchText = ""
                                }) {
                                    Image(systemName: "xmark.circle.fill")
                                        .foregroundColor(Color.dynamicTextSecondary(theme: themeManager.currentTheme))
                                        .font(.system(size: 16))
                                }
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color.dynamicSurface(theme: themeManager.currentTheme))
                        )
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 16)
                    .background(Color.dynamicBackground(theme: themeManager.currentTheme))
                    
                    // Gyms List
                    if gymService.isLoadingAllGyms {
                        VStack(spacing: 16) {
                            ProgressView()
                                .scaleEffect(1.2)
                                .tint(Color.dynamicAccent(theme: themeManager.currentTheme))
                            
                            Text("Loading gyms...")
                                .font(.system(size: 16, weight: .medium))
                                .foregroundColor(Color.dynamicTextSecondary(theme: themeManager.currentTheme))
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    } else if filteredGyms.isEmpty {
                        VStack(spacing: 16) {
                            Image(systemName: searchText.isEmpty ? "building.2" : "magnifyingglass")
                                .font(.system(size: 48))
                                .foregroundColor(Color.dynamicTextSecondary(theme: themeManager.currentTheme))
                            
                            Text(searchText.isEmpty ? "No gyms available" : "No gyms found")
                                .font(.system(size: 18, weight: .medium))
                                .foregroundColor(Color.dynamicTextSecondary(theme: themeManager.currentTheme))
                            
                            Text(searchText.isEmpty ? "Check back later for new gyms" : "Try different search terms")
                                .font(.system(size: 14))
                                .foregroundColor(Color.dynamicTextSecondary(theme: themeManager.currentTheme).opacity(0.7))
                                .multilineTextAlignment(.center)
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    } else {
                        ScrollView {
                            LazyVStack(spacing: 16) {
                                ForEach(Array(filteredGyms.enumerated()), id: \.element.id) { index, gym in
                                    GymCard(gym: gym) {
                                        selectedGym = gym
                                        showingGymDetail = true
                                    }
                                    .padding(.horizontal, 20)
                                    .scaleEffect(isAnimating ? 1.0 : 0.8)
                                    .opacity(isAnimating ? 1.0 : 0.0)
                                    .animation(
                                        .spring(response: 0.6, dampingFraction: 0.8)
                                        .delay(Double(index) * 0.1),
                                        value: isAnimating
                                    )
                                }
                                
                                Spacer(minLength: 100)
                            }
                            .padding(.top, 8)
                        }
                        .refreshable {
                            await gymService.getAllGyms(forceRefresh: true)
                        }
                    }
                }
            }
        }
        .onAppear {
            // No need for authService since the endpoint is now public
            Task {
                await gymService.getAllGyms()
                withAnimation {
                    isAnimating = true
                }
            }
        }
        .sheet(item: $selectedGym) { gym in
            GymDetailView(gym: gym)
                .environmentObject(themeManager)
                .environmentObject(gymService)
        }
        .navigationBarHidden(true)
        .fullScreenCover(isPresented: $showingLogin) {
            LoginViewDirect()
                .environmentObject(themeManager)
        }
    }
}

struct GymCard: View {
    let gym: Gym
    let onTap: () -> Void
    @EnvironmentObject var themeManager: ThemeManager
    
    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(gym.name)
                            .font(.system(size: 20, weight: .bold))
                            .foregroundColor(Color.dynamicText(theme: themeManager.currentTheme))
                            .multilineTextAlignment(.leading)
                        
                        if let address = gym.address {
                            HStack(spacing: 6) {
                                Image(systemName: "location.fill")
                                    .font(.system(size: 12))
                                    .foregroundColor(Color.dynamicAccent(theme: themeManager.currentTheme))
                                
                                Text(address)
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundColor(Color.dynamicTextSecondary(theme: themeManager.currentTheme))
                            }
                        }
                        
                        if let description = gym.description {
                            Text(description)
                                .font(.system(size: 14))
                                .foregroundColor(Color.dynamicTextSecondary(theme: themeManager.currentTheme))
                                .lineLimit(2)
                        }
                    }
                    
                    Spacer()
                    
                    Image(systemName: "arrow.right.circle.fill")
                        .font(.system(size: 24))
                        .foregroundColor(Color.dynamicAccent(theme: themeManager.currentTheme))
                }
                
                // Contact info
                if gym.phone != nil || gym.email != nil {
                    HStack(spacing: 16) {
                        if let phone = gym.phone {
                            HStack(spacing: 6) {
                                Image(systemName: "phone.fill")
                                    .font(.system(size: 12))
                                    .foregroundColor(Color.dynamicAccent(theme: themeManager.currentTheme))
                                
                                Text(phone)
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundColor(Color.dynamicTextSecondary(theme: themeManager.currentTheme))
                            }
                        }
                        
                        if let email = gym.email {
                            HStack(spacing: 6) {
                                Image(systemName: "envelope.fill")
                                    .font(.system(size: 12))
                                    .foregroundColor(Color.dynamicAccent(theme: themeManager.currentTheme))
                                
                                Text(email)
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundColor(Color.dynamicTextSecondary(theme: themeManager.currentTheme))
                            }
                        }
                        
                        Spacer()
                    }
                }
            }
            .padding(20)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color.dynamicSurface(theme: themeManager.currentTheme))
                    .shadow(
                        color: Color.black.opacity(themeManager.currentTheme == .dark ? 0.3 : 0.1),
                        radius: 8,
                        x: 0,
                        y: 2
                    )
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

struct GymDetailView: View {
    let gym: Gym
    @EnvironmentObject var themeManager: ThemeManager
    @EnvironmentObject var gymService: GymService
    @Environment(\.dismiss) private var dismiss
    @State private var isJoining = false
    @State private var gymDetail: GymDetail?
    @State private var isLoadingDetails = true
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    if isLoadingDetails {
                        // Loading state
                        VStack(spacing: 16) {
                            ProgressView()
                                .scaleEffect(1.2)
                                .tint(Color.dynamicAccent(theme: themeManager.currentTheme))
                            
                            Text("Loading gym details...")
                                .font(.system(size: 16, weight: .medium))
                                .foregroundColor(Color.dynamicTextSecondary(theme: themeManager.currentTheme))
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .padding(.top, 100)
                    } else if let detail = gymDetail {
                        // Header
                        VStack(alignment: .leading, spacing: 12) {
                            Text(detail.name)
                                .font(.system(size: 32, weight: .bold))
                                .foregroundColor(Color.dynamicText(theme: themeManager.currentTheme))
                            
                            if let address = detail.address {
                                HStack(spacing: 8) {
                                    Image(systemName: "location.fill")
                                        .foregroundColor(Color.dynamicAccent(theme: themeManager.currentTheme))
                                    
                                    Text(address)
                                        .font(.system(size: 16, weight: .medium))
                                        .foregroundColor(Color.dynamicTextSecondary(theme: themeManager.currentTheme))
                                }
                            }
                        }
                        .padding(.horizontal, 20)
                        
                        // Description
                        if let description = detail.description, !description.isEmpty {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("About")
                                    .font(.system(size: 20, weight: .bold))
                                    .foregroundColor(Color.dynamicText(theme: themeManager.currentTheme))
                                
                                Text(description)
                                    .font(.system(size: 16))
                                    .foregroundColor(Color.dynamicTextSecondary(theme: themeManager.currentTheme))
                                    .lineSpacing(4)
                            }
                            .padding(.horizontal, 20)
                        }
                        
                        // Operating Hours
                        if !detail.gymHours.isEmpty {
                            VStack(alignment: .leading, spacing: 16) {
                                Text("Operating Hours")
                                    .font(.system(size: 20, weight: .bold))
                                    .foregroundColor(Color.dynamicText(theme: themeManager.currentTheme))
                                
                                VStack(spacing: 8) {
                                    ForEach(detail.gymHours.sorted(by: { $0.dayOfWeek < $1.dayOfWeek })) { hour in
                                        HStack {
                                            Text(hour.dayName)
                                                .font(.system(size: 16, weight: .medium))
                                                .foregroundColor(Color.dynamicText(theme: themeManager.currentTheme))
                                                .frame(minWidth: 80, alignment: .leading)
                                            
                                            Spacer()
                                            
                                            Text(hour.displayTime)
                                                .font(.system(size: 15, weight: .medium))
                                                .foregroundColor(hour.isClosed ? 
                                                    Color.dynamicTextSecondary(theme: themeManager.currentTheme) :
                                                    Color.dynamicAccent(theme: themeManager.currentTheme))
                                        }
                                        .padding(.vertical, 4)
                                    }
                                }
                                .padding(16)
                                .background(
                                    RoundedRectangle(cornerRadius: 12)
                                        .fill(Color.dynamicSurface(theme: themeManager.currentTheme))
                                )
                            }
                            .padding(.horizontal, 20)
                        }
                        
                        // Membership Plans
                        if !detail.membershipPlans.isEmpty {
                            VStack(alignment: .leading, spacing: 16) {
                                Text("Membership Plans")
                                    .font(.system(size: 20, weight: .bold))
                                    .foregroundColor(Color.dynamicText(theme: themeManager.currentTheme))
                                
                                VStack(spacing: 12) {
                                    ForEach(detail.membershipPlans) { plan in
                                        MembershipPlanCard(plan: plan, themeManager: themeManager)
                                    }
                                }
                            }
                            .padding(.horizontal, 20)
                        }
                        
                        // Available Features/Modules
                        if !detail.modules.isEmpty {
                            let enabledModules = detail.modules.filter { $0.isEnabled }
                            if !enabledModules.isEmpty {
                                VStack(alignment: .leading, spacing: 16) {
                                    Text("Available Features")
                                        .font(.system(size: 20, weight: .bold))
                                        .foregroundColor(Color.dynamicText(theme: themeManager.currentTheme))
                                    
                                    LazyVGrid(columns: [
                                        GridItem(.flexible()),
                                        GridItem(.flexible())
                                    ], spacing: 12) {
                                        ForEach(enabledModules) { module in
                                            HStack(spacing: 8) {
                                                Image(systemName: "checkmark.circle.fill")
                                                    .font(.system(size: 14))
                                                    .foregroundColor(Color.dynamicAccent(theme: themeManager.currentTheme))
                                                
                                                Text(module.moduleName)
                                                    .font(.system(size: 14, weight: .medium))
                                                    .foregroundColor(Color.dynamicText(theme: themeManager.currentTheme))
                                                    .lineLimit(2)
                                                
                                                Spacer()
                                            }
                                            .padding(12)
                                            .background(
                                                RoundedRectangle(cornerRadius: 8)
                                                    .fill(Color.dynamicSurface(theme: themeManager.currentTheme))
                                            )
                                        }
                                    }
                                }
                                .padding(.horizontal, 20)
                            }
                        }
                        
                        // Contact Information
                        VStack(alignment: .leading, spacing: 16) {
                            Text("Contact Information")
                                .font(.system(size: 20, weight: .bold))
                                .foregroundColor(Color.dynamicText(theme: themeManager.currentTheme))
                            
                            VStack(spacing: 12) {
                                if let phone = detail.phone, !phone.isEmpty {
                                    ContactRow(icon: "phone.fill", title: "Phone", value: phone)
                                }
                                
                                if let email = detail.email, !email.isEmpty {
                                    ContactRow(icon: "envelope.fill", title: "Email", value: email)
                                }
                                
                                ContactRow(icon: "clock.fill", title: "Timezone", value: detail.timezone)
                            }
                        }
                        .padding(.horizontal, 20)
                        
                        Spacer(minLength: 100)
                    } else {
                        // Error state
                        VStack(spacing: 16) {
                            Image(systemName: "exclamationmark.triangle")
                                .font(.system(size: 48))
                                .foregroundColor(Color.dynamicTextSecondary(theme: themeManager.currentTheme))
                            
                            Text("Could not load gym details")
                                .font(.system(size: 18, weight: .medium))
                                .foregroundColor(Color.dynamicText(theme: themeManager.currentTheme))
                            
                            Button("Try Again") {
                                loadGymDetails()
                            }
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(Color.dynamicAccent(theme: themeManager.currentTheme))
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .padding(.top, 100)
                    }
                }
                .padding(.top, 20)
            }
            .background(Color.dynamicBackground(theme: themeManager.currentTheme))
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Close") {
                        dismiss()
                    }
                    .foregroundColor(Color.dynamicAccent(theme: themeManager.currentTheme))
                }
            }
            .safeAreaInset(edge: .bottom) {
                if gymDetail != nil {
                    Button(action: {
                        // TODO: Implement join gym functionality
                        print("Joining gym: \(gym.name)")
                    }) {
                        HStack {
                            if isJoining {
                                ProgressView()
                                    .scaleEffect(0.8)
                                    .tint(.white)
                            } else {
                                Image(systemName: "plus.circle.fill")
                                    .font(.system(size: 16))
                            }
                            
                            Text(isJoining ? "Joining..." : "Request to Join")
                                .font(.system(size: 18, weight: .semibold))
                        }
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 56)
                        .background(
                            RoundedRectangle(cornerRadius: 16)
                                .fill(Color.dynamicAccent(theme: themeManager.currentTheme))
                        )
                    }
                    .disabled(isJoining)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 16)
                    .background(
                        Color.dynamicBackground(theme: themeManager.currentTheme)
                            .ignoresSafeArea()
                    )
                }
            }
        }
        .onAppear {
            loadGymDetails()
        }
    }
    
    private func loadGymDetails() {
        isLoadingDetails = true
        Task {
            let details = await gymService.getGymDetails(gymId: gym.id)
            await MainActor.run {
                gymDetail = details
                isLoadingDetails = false
            }
        }
    }
}

struct MembershipPlanCard: View {
    let plan: MembershipPlan
    let themeManager: ThemeManager
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(plan.name)
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(Color.dynamicText(theme: themeManager.currentTheme))
                    
                    Text(plan.description)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(Color.dynamicTextSecondary(theme: themeManager.currentTheme))
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 2) {
                    Text(plan.formattedPrice)
                        .font(.system(size: 20, weight: .bold))
                        .foregroundColor(Color.dynamicAccent(theme: themeManager.currentTheme))
                    
                    Text(plan.billingIntervalDisplay)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(Color.dynamicTextSecondary(theme: themeManager.currentTheme))
                }
            }
            
            if plan.maxBookingsPerMonth > 0 {
                HStack(spacing: 6) {
                    Image(systemName: "calendar")
                        .font(.system(size: 12))
                        .foregroundColor(Color.dynamicAccent(theme: themeManager.currentTheme))
                    
                    Text("\(plan.maxBookingsPerMonth) bookings per month")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(Color.dynamicTextSecondary(theme: themeManager.currentTheme))
                }
            }
            
            if plan.durationDays > 0 {
                HStack(spacing: 6) {
                    Image(systemName: "clock")
                        .font(.system(size: 12))
                        .foregroundColor(Color.dynamicAccent(theme: themeManager.currentTheme))
                    
                    Text("\(plan.durationDays) days duration")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(Color.dynamicTextSecondary(theme: themeManager.currentTheme))
                }
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.dynamicSurface(theme: themeManager.currentTheme))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.dynamicAccent(theme: themeManager.currentTheme).opacity(0.2), lineWidth: 1)
                )
        )
    }
}

struct ContactRow: View {
    let icon: String
    let title: String
    let value: String
    @EnvironmentObject var themeManager: ThemeManager
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 16))
                .foregroundColor(Color.dynamicAccent(theme: themeManager.currentTheme))
                .frame(width: 20)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(Color.dynamicTextSecondary(theme: themeManager.currentTheme))
                
                Text(value)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(Color.dynamicText(theme: themeManager.currentTheme))
            }
            
            Spacer()
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.dynamicSurface(theme: themeManager.currentTheme))
        )
    }
}

#Preview {
    AvailableGymsView()
        .environmentObject(ThemeManager())
        .environmentObject(GymService.shared)
        .environmentObject(AuthServiceDirect())
}