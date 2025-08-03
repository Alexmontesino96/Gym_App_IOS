//
//  MyGymView.swift
//  Gym_API
//
//  Created by Assistant on 7/26/25.
//

import SwiftUI
import MapKit

struct MyGymView: View {
    @EnvironmentObject var themeManager: ThemeManager
    @EnvironmentObject var authService: AuthServiceDirect
    @StateObject private var gymService = GymService.shared
    @StateObject private var classService = ClassService.shared ?? ClassService()
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            ZStack {
                Color.dynamicBackground(theme: themeManager.currentTheme)
                    .ignoresSafeArea()
                
                mainContent
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                toolbarContent
            }
        }
        .onAppear {
            setupService()
        }
    }
    
    @ViewBuilder
    private var mainContent: some View {
        if gymService.isLoadingGyms {
            GymLoadingView()
        } else if let gym = gymService.currentGym {
            ScrollView {
                VStack(spacing: 24) {
                    GymHeaderSection(gym: gym, themeManager: themeManager)
                    GymInfoSection(gym: gym, themeManager: themeManager)
                    GymContactSection(gym: gym, themeManager: themeManager)
                    MyMembershipSection(gym: gym, themeManager: themeManager)
                    GymQuickAccessSection(gym: gym, themeManager: themeManager, gymService: gymService, classService: classService)
                }
                .padding(.bottom, 32)
            }
        } else {
            EmptyGymView(themeManager: themeManager)
        }
    }
    
    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .navigationBarLeading) {
            Button(action: { dismiss() }) {
                Image(systemName: "xmark")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(Color.dynamicText(theme: themeManager.currentTheme))
            }
        }
        
        ToolbarItem(placement: .principal) {
            Text("My Gym")
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(Color.dynamicText(theme: themeManager.currentTheme))
        }
        
        if gymService.myGyms.count > 1 {
            ToolbarItem(placement: .navigationBarTrailing) {
                gymSelector
            }
        }
    }
    
    private var gymSelector: some View {
        Menu {
            ForEach(gymService.myGyms) { gym in
                Button(action: {
                    gymService.selectGym(gym)
                    Task {
                        await gymService.getRegularGymHours()
                    }
                }) {
                    Label(gym.name, systemImage: gym == gymService.currentGym ? "checkmark.circle.fill" : "circle")
                }
            }
        } label: {
            Image(systemName: "building.2")
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(Color.dynamicAccent(theme: themeManager.currentTheme))
        }
    }
    
    private func setupService() {
        gymService.authService = authService
        
        // Clear cache to ensure we get fresh data
        gymService.clearCache()
        
        Task {
            // Force refresh to get latest data including correct role
            await gymService.getMyGyms(forceRefresh: true)
            // Load gym hours after getting gyms
            if gymService.currentGym != nil {
                await gymService.getRegularGymHours()
            }
            // Load trainers
            await classService.loadTrainers()
        }
    }
}

// MARK: - Header Section
struct GymHeaderSection: View {
    let gym: GymInfo
    let themeManager: ThemeManager
    
    var body: some View {
        VStack(spacing: 16) {
            // Logo or Placeholder
            if let logoUrl = gym.logoUrl, let url = URL(string: logoUrl) {
                AsyncImage(url: url) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                } placeholder: {
                    Image(systemName: "building.2.fill")
                        .font(.system(size: 60))
                        .foregroundColor(Color.dynamicAccent(theme: themeManager.currentTheme))
                }
                .frame(width: 120, height: 120)
                .clipShape(RoundedRectangle(cornerRadius: 20))
            } else {
                Circle()
                    .fill(Color.dynamicAccent(theme: themeManager.currentTheme).opacity(0.1))
                    .frame(width: 120, height: 120)
                    .overlay(
                        Image(systemName: "building.2.fill")
                            .font(.system(size: 60))
                            .foregroundColor(Color.dynamicAccent(theme: themeManager.currentTheme))
                    )
            }
            
            // Gym Name
            Text(gym.name)
                .font(.system(size: 28, weight: .bold))
                .foregroundColor(Color.dynamicText(theme: themeManager.currentTheme))
                .multilineTextAlignment(.center)
            
            // Role Badge
            HStack(spacing: 6) {
                Image(systemName: gym.roleIcon)
                    .font(.system(size: 14))
                Text(gym.roleDisplayName)
                    .font(.system(size: 14, weight: .medium))
            }
            .foregroundColor(.white)
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(Color.dynamicAccent(theme: themeManager.currentTheme))
            .clipShape(Capsule())
        }
        .padding(.top, 20)
    }
}

// MARK: - Info Section
struct GymInfoSection: View {
    let gym: GymInfo
    let themeManager: ThemeManager
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("About")
                .font(.system(size: 20, weight: .semibold))
                .foregroundColor(Color.dynamicText(theme: themeManager.currentTheme))
            
            Text(gym.description)
                .font(.system(size: 16))
                .foregroundColor(Color.dynamicTextSecondary(theme: themeManager.currentTheme))
                .lineSpacing(4)
            
            // Status
            HStack {
                Circle()
                    .fill(gym.isActive ? Color.green : Color.red)
                    .frame(width: 8, height: 8)
                Text(gym.statusText)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(gym.isActive ? Color.green : Color.red)
            }
        }
        .padding(.horizontal, 20)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// MARK: - Contact Section
struct GymContactSection: View {
    let gym: GymInfo
    let themeManager: ThemeManager
    @State private var showingMapAlert = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Contact")
                .font(.system(size: 20, weight: .semibold))
                .foregroundColor(Color.dynamicText(theme: themeManager.currentTheme))
            
            VStack(spacing: 12) {
                // Address
                GymContactRow(
                    icon: "map",
                    title: "Address",
                    value: gym.address.isEmpty ? "No address available" : gym.address,
                    action: {
                        openInMaps(address: gym.address)
                    },
                    actionIcon: "map.fill",
                    themeManager: themeManager
                )
                
                // Phone
                GymContactRow(
                    icon: "phone",
                    title: "Phone",
                    value: gym.phone,
                    action: {
                        callPhone(gym.phone)
                    },
                    actionIcon: "phone.fill",
                    themeManager: themeManager
                )
                
                // Email
                GymContactRow(
                    icon: "envelope",
                    title: "Email",
                    value: gym.email,
                    action: {
                        sendEmail(gym.email)
                    },
                    actionIcon: "envelope.fill",
                    themeManager: themeManager
                )
            }
        }
        .padding(.horizontal, 20)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
    
    private func openInMaps(address: String) {
        let escapedAddress = address.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        if let url = URL(string: "maps://?q=\(escapedAddress)") {
            UIApplication.shared.open(url)
        }
    }
    
    private func callPhone(_ phone: String) {
        let cleanPhone = phone.replacingOccurrences(of: " ", with: "").replacingOccurrences(of: "-", with: "")
        if let url = URL(string: "tel://\(cleanPhone)") {
            UIApplication.shared.open(url)
        }
    }
    
    private func sendEmail(_ email: String) {
        if let url = URL(string: "mailto:\(email)") {
            UIApplication.shared.open(url)
        }
    }
}

// MARK: - Contact Row
struct GymContactRow: View {
    let icon: String
    let title: String
    let value: String
    let action: () -> Void
    let actionIcon: String
    let themeManager: ThemeManager
    
    var body: some View {
        HStack {
            Image(systemName: icon)
                .font(.system(size: 20))
                .foregroundColor(Color.dynamicAccent(theme: themeManager.currentTheme))
                .frame(width: 30)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 12))
                    .foregroundColor(Color.dynamicTextSecondary(theme: themeManager.currentTheme))
                Text(value)
                    .font(.system(size: 16))
                    .foregroundColor(Color.dynamicText(theme: themeManager.currentTheme))
            }
            
            Spacer()
            
            Button(action: action) {
                Image(systemName: actionIcon)
                    .font(.system(size: 16))
                    .foregroundColor(.white)
                    .frame(width: 36, height: 36)
                    .background(Color.dynamicAccent(theme: themeManager.currentTheme))
                    .clipShape(Circle())
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color.dynamicSurface(theme: themeManager.currentTheme))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

// MARK: - Membership Section
struct MyMembershipSection: View {
    let gym: GymInfo
    let themeManager: ThemeManager
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("My Membership")
                .font(.system(size: 20, weight: .semibold))
                .foregroundColor(Color.dynamicText(theme: themeManager.currentTheme))
            
            VStack(spacing: 12) {
                HStack {
                    Label("Role", systemImage: gym.roleIcon)
                        .font(.system(size: 16))
                        .foregroundColor(Color.dynamicTextSecondary(theme: themeManager.currentTheme))
                    
                    Spacer()
                    
                    Text(gym.roleDisplayName)
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(Color.dynamicText(theme: themeManager.currentTheme))
                }
                
                Divider()
                    .background(Color.dynamicBorder(theme: themeManager.currentTheme))
                
                HStack {
                    Label("Member Since", systemImage: "calendar")
                        .font(.system(size: 16))
                        .foregroundColor(Color.dynamicTextSecondary(theme: themeManager.currentTheme))
                    
                    Spacer()
                    
                    Text(gym.memberSinceFormatted)
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(Color.dynamicText(theme: themeManager.currentTheme))
                }
                
                Divider()
                    .background(Color.dynamicBorder(theme: themeManager.currentTheme))
                
                HStack {
                    Label("Status", systemImage: "checkmark.circle")
                        .font(.system(size: 16))
                        .foregroundColor(Color.dynamicTextSecondary(theme: themeManager.currentTheme))
                    
                    Spacer()
                    
                    HStack(spacing: 6) {
                        Circle()
                            .fill(gym.isActive ? Color.green : Color.red)
                            .frame(width: 8, height: 8)
                        Text(gym.statusText)
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(gym.isActive ? Color.green : Color.red)
                    }
                }
            }
            .padding(16)
            .background(Color.dynamicSurface(theme: themeManager.currentTheme))
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .padding(.horizontal, 20)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// MARK: - Quick Access Section
struct GymQuickAccessSection: View {
    let gym: GymInfo
    let themeManager: ThemeManager
    let gymService: GymService
    let classService: ClassService
    @State private var showingSchedule = false
    @State private var showingTrainers = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Quick Access")
                .font(.system(size: 20, weight: .semibold))
                .foregroundColor(Color.dynamicText(theme: themeManager.currentTheme))
            
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
                GymQuickAccessButton(
                    icon: "clock",
                    title: "Schedule",
                    color: .blue,
                    themeManager: themeManager
                ) {
                    showingSchedule = true
                }
                
                GymQuickAccessButton(
                    icon: "person.2",
                    title: "Trainers",
                    color: .green,
                    themeManager: themeManager
                ) {
                    showingTrainers = true
                }
                
                GymQuickAccessButton(
                    icon: "figure.run",
                    title: "Classes",
                    color: .orange,
                    themeManager: themeManager
                ) {
                    // TODO: Navigate to classes
                }
                
                GymQuickAccessButton(
                    icon: "bubble.left.and.bubble.right",
                    title: "Gym Chat",
                    color: .purple,
                    themeManager: themeManager
                ) {
                    // TODO: Navigate to gym chat
                }
            }
        }
        .padding(.horizontal, 20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .sheet(isPresented: $showingSchedule) {
            GymScheduleView()
                .environmentObject(themeManager)
                .environmentObject(gymService)
        }
        .sheet(isPresented: $showingTrainers) {
            TrainersView()
                .environmentObject(themeManager)
                .environmentObject(classService)
        }
    }
}

// MARK: - Quick Access Button
struct GymQuickAccessButton: View {
    let icon: String
    let title: String
    let color: Color
    let themeManager: ThemeManager
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.system(size: 28))
                    .foregroundColor(color)
                
                Text(title)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(Color.dynamicText(theme: themeManager.currentTheme))
            }
            .frame(maxWidth: .infinity)
            .frame(height: 90)
            .background(Color.dynamicSurface(theme: themeManager.currentTheme))
            .clipShape(RoundedRectangle(cornerRadius: 16))
        }
    }
}

// MARK: - Empty View
struct EmptyGymView: View {
    let themeManager: ThemeManager
    
    var body: some View {
        VStack(spacing: 24) {
            Image(systemName: "building.2")
                .font(.system(size: 64))
                .foregroundColor(Color.dynamicTextSecondary(theme: themeManager.currentTheme).opacity(0.5))
            
            VStack(spacing: 8) {
                Text("No Gym Found")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundColor(Color.dynamicText(theme: themeManager.currentTheme))
                
                Text("You are not associated with any gym yet")
                    .font(.system(size: 16))
                    .foregroundColor(Color.dynamicTextSecondary(theme: themeManager.currentTheme))
                    .multilineTextAlignment(.center)
            }
        }
        .padding(.horizontal, 32)
    }
}

// MARK: - Loading View
struct GymLoadingView: View {
    @EnvironmentObject var themeManager: ThemeManager
    
    var body: some View {
        EnhancedLoadingView(message: "Loading gym information...", themeManager: themeManager)
    }
}

// MARK: - Preview
#Preview {
    MyGymView()
        .environmentObject(ThemeManager())
        .environmentObject(AuthServiceDirect())
}