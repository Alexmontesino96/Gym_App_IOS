//
//  GymSelectionView.swift
//  Gym_API
//
//  Created by Assistant on 7/29/25.
//

import SwiftUI

struct GymSelectionView: View {
    @EnvironmentObject var themeManager: ThemeManager
    @EnvironmentObject var authService: AuthServiceDirect
    @StateObject private var gymService = GymService.shared
    @State private var isLoading = false
    @State private var selectedGym: GymInfo?
    @State private var showOnboarding = false
    
    let onGymSelected: (GymInfo) -> Void
    
    var body: some View {
        let _ = print("🔍 GymSelectionView - isLoadingGyms: \(gymService.isLoadingGyms), myGyms.count: \(gymService.myGyms.count)")
        let _ = print("🔍 GymSelectionView - hasCompletedOnboarding: \(UserDefaults.standard.bool(forKey: "hasCompletedOnboarding"))")
        
        // Show onboarding directly if no gyms and not loading
        if !gymService.isLoadingGyms && gymService.myGyms.isEmpty {
            // Check if user has completed onboarding before
            if UserDefaults.standard.bool(forKey: "hasCompletedOnboarding") {
                // User already saw onboarding, go directly to available gyms
                let _ = print("✅ Mostrando AvailableGymsView (usuario ya vio onboarding)")
                AvailableGymsView(showCancelButton: false)
                    .environmentObject(themeManager)
                    .environmentObject(gymService)
                    .environmentObject(authService)
            } else {
                // First time user, show onboarding
                let _ = print("✅ Mostrando OnboardingView (primera vez)")
                OnboardingView()
                    .environmentObject(themeManager)
                    .environmentObject(gymService)
                    .onDisappear {
                        // Mark onboarding as completed when user leaves the view
                        UserDefaults.standard.set(true, forKey: "hasCompletedOnboarding")
                    }
            }
        } else {
            ZStack {
                Color.dynamicBackground(theme: themeManager.currentTheme).ignoresSafeArea()
                
                VStack(spacing: 32) {
                    // Header
                    VStack(spacing: 16) {
                        Image(systemName: "building.2.fill")
                            .font(.system(size: 64))
                            .foregroundColor(Color.dynamicAccent(theme: themeManager.currentTheme))
                        
                        VStack(spacing: 8) {
                            Text("Select Your Gym")
                                .font(.system(size: 28, weight: .bold))
                                .foregroundColor(Color.dynamicText(theme: themeManager.currentTheme))
                            
                            Text(gymService.hasSelectedGym ? "Confirm your gym selection" : "Choose which gym you want to access")
                                .font(.system(size: 16, weight: .regular))
                                .foregroundColor(Color.dynamicTextSecondary(theme: themeManager.currentTheme))
                                .multilineTextAlignment(.center)
                        }
                    }
                    .padding(.top, 60)
                    
                    // Gym List
                    if gymService.isLoadingGyms {
                        ProgressView("Loading your gyms...")
                            .progressViewStyle(CircularProgressViewStyle(tint: Color.dynamicAccent(theme: themeManager.currentTheme)))
                            .foregroundColor(Color.dynamicText(theme: themeManager.currentTheme))
                } else {
                    ScrollView {
                        LazyVStack(spacing: 16) {
                            ForEach(gymService.myGyms) { gym in
                                GymSelectionCard(
                                    gym: gym,
                                    isSelected: selectedGym?.id == gym.id,
                                    themeManager: themeManager,
                                    onTap: { 
                                        selectedGym = gym
                                    }
                                )
                            }
                        }
                        .padding(.horizontal, 20)
                    }
                }
                
                Spacer()
                
                // Continue Button
                if let selectedGym = selectedGym {
                    Button(action: {
                        isLoading = true
                        onGymSelected(selectedGym)
                    }) {
                        HStack {
                            if isLoading {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                    .scaleEffect(0.8)
                            } else {
                                Text("Continue")
                                    .font(.system(size: 18, weight: .semibold))
                            }
                        }
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 56)
                        .background(Color.dynamicAccent(theme: themeManager.currentTheme))
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                    }
                    .disabled(isLoading)
                    .padding(.horizontal, 20)
                    .padding(.bottom, 40)
                    }
                }
            }
            .onAppear {
                loadGyms()
                // Pre-seleccionar el gym si hay uno en storage
                if let currentGym = gymService.currentGym {
                    selectedGym = currentGym
                }
            }
        }
    }
    
    private func loadGyms() {
        Task {
            await gymService.getMyGyms(forceRefresh: true)
        }
    }
}

struct GymSelectionCard: View {
    let gym: GymInfo
    let isSelected: Bool
    let themeManager: ThemeManager
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 16) {
                // Gym Icon/Logo
                ZStack {
                    Circle()
                        .fill(Color.dynamicAccent(theme: themeManager.currentTheme))
                        .frame(width: 60, height: 60)
                    
                    if let logoUrl = gym.logoUrl, !logoUrl.isEmpty {
                        AsyncImage(url: URL(string: logoUrl)) { image in
                            image
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                        } placeholder: {
                            Image(systemName: "building.2.fill")
                                .font(.system(size: 24))
                                .foregroundColor(.white)
                        }
                        .frame(width: 60, height: 60)
                        .clipShape(Circle())
                    } else {
                        Image(systemName: "building.2.fill")
                            .font(.system(size: 24))
                            .foregroundColor(.white)
                    }
                }
                
                // Gym Info
                VStack(alignment: .leading, spacing: 8) {
                    Text(gym.name)
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(Color.dynamicText(theme: themeManager.currentTheme))
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                    
                    HStack(spacing: 8) {
                        Image(systemName: gym.roleIcon)
                            .font(.system(size: 12))
                            .foregroundColor(Color.dynamicAccent(theme: themeManager.currentTheme))
                        
                        Text(gym.roleDisplayName)
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(Color.dynamicAccent(theme: themeManager.currentTheme))
                    }
                    
                    if !gym.address.isEmpty {
                        HStack(spacing: 4) {
                            Image(systemName: "location.fill")
                                .font(.system(size: 10))
                                .foregroundColor(Color.dynamicTextSecondary(theme: themeManager.currentTheme))
                            
                            Text(gym.address)
                                .font(.system(size: 12))
                                .foregroundColor(Color.dynamicTextSecondary(theme: themeManager.currentTheme))
                                .lineLimit(1)
                        }
                    }
                }
                
                Spacer()
                
                // Selection Indicator
                ZStack {
                    Circle()
                        .stroke(
                            isSelected ? Color.dynamicAccent(theme: themeManager.currentTheme) : Color.dynamicBorder(theme: themeManager.currentTheme),
                            lineWidth: 2
                        )
                        .frame(width: 24, height: 24)
                    
                    if isSelected {
                        Circle()
                            .fill(Color.dynamicAccent(theme: themeManager.currentTheme))
                            .frame(width: 12, height: 12)
                    }
                }
            }
            .padding(20)
            .background(Color.dynamicSurface(theme: themeManager.currentTheme))
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(
                        isSelected ? Color.dynamicAccent(theme: themeManager.currentTheme) : Color.clear,
                        lineWidth: 2
                    )
            )
            .clipShape(RoundedRectangle(cornerRadius: 16))
        }
        .buttonStyle(PlainButtonStyle())
    }
}

#Preview {
    GymSelectionView { gym in
        print("Selected gym: \(gym.name)")
    }
    .environmentObject(ThemeManager())
    .environmentObject(AuthServiceDirect())
}