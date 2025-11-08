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
    @State private var showingExploreGyms = false

    let onGymSelected: (GymInfo) -> Void

    var gyms: [GymInfo] {
        gymService.myGyms.filter { gym in
            gym.type == nil || gym.type?.lowercased() == "gym"
        }
    }

    var personalTrainers: [GymInfo] {
        gymService.myGyms.filter { gym in
            gym.isPersonalTrainer == true || gym.type?.lowercased() == "personal_trainer"
        }
    }

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
                // First time user - this case shouldn't happen anymore
                // as onboarding is handled by MainOnboardingView
                let _ = print("⚠️ GymSelectionView: Usuario sin onboarding completado")
                Text("Please complete onboarding first")
                    .font(.headline)
                    .foregroundColor(.secondary)
            }
        } else {
            ZStack(alignment: .bottom) {
                Color.dynamicBackground(theme: themeManager.currentTheme).ignoresSafeArea()

                // Main content
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
                        ScrollView(showsIndicators: false) {
                            LazyVStack(spacing: 0) {
                                // Gyms Section
                                if !gyms.isEmpty {
                                    GymSectionHeader(
                                        title: "Gyms",
                                        count: gyms.count,
                                        icon: "building.2.fill",
                                        themeManager: themeManager
                                    )

                                    LazyVStack(spacing: 16) {
                                        ForEach(gyms) { gym in
                                            GymSelectionCard(
                                                gym: gym,
                                                isSelected: selectedGym?.id == gym.id,
                                                isPersonalTrainer: false,
                                                themeManager: themeManager,
                                                onTap: {
                                                    selectedGym = gym
                                                }
                                            )
                                        }
                                    }
                                    .padding(.horizontal, 20)
                                    .padding(.bottom, 24)
                                }

                                // Personal Trainers Section
                                if !personalTrainers.isEmpty {
                                    GymSectionHeader(
                                        title: "Personal Trainers",
                                        count: personalTrainers.count,
                                        icon: "person.fill",
                                        themeManager: themeManager
                                    )

                                    LazyVStack(spacing: 16) {
                                        ForEach(personalTrainers) { gym in
                                            GymSelectionCard(
                                                gym: gym,
                                                isSelected: selectedGym?.id == gym.id,
                                                isPersonalTrainer: true,
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
                            .padding(.bottom, 200) // Space for floating buttons
                        }
                        .frame(maxWidth: .infinity)
                    }
                }
                .frame(maxHeight: .infinity, alignment: .top)
                .zIndex(0)

                // Floating buttons with shadow elevation
                VStack(spacing: 0) {
                    // Compact fade gradient (60pt)
                    LinearGradient(
                        colors: [
                            Color.clear,
                            Color.dynamicBackground(theme: themeManager.currentTheme).opacity(0.4),
                            Color.dynamicBackground(theme: themeManager.currentTheme).opacity(0.8),
                            Color.dynamicBackground(theme: themeManager.currentTheme)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                    .frame(height: 60)

                    // Buttons container
                    VStack(spacing: selectedGym == nil ? 0 : 14) {
                        // Continue Button (when gym is selected)
                        if let selectedGym = selectedGym {
                            Button(action: {
                                isLoading = true
                                onGymSelected(selectedGym)
                            }) {
                                HStack(spacing: 8) {
                                    if isLoading {
                                        ProgressView()
                                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                            .scaleEffect(0.8)
                                    } else {
                                        Image(systemName: "checkmark.circle.fill")
                                            .font(.system(size: 20))
                                        Text("Continuar con \(selectedGym.name)")
                                            .font(.system(size: 17, weight: .semibold))
                                            .lineLimit(1)
                                    }
                                }
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .frame(height: 56)
                                .background(Color.dynamicAccent(theme: themeManager.currentTheme))
                                .clipShape(RoundedRectangle(cornerRadius: 14))
                                .shadow(color: Color.black.opacity(0.15), radius: 12, x: 0, y: 4)
                                .shadow(color: Color.black.opacity(0.1), radius: 24, x: 0, y: 8)
                            }
                            .disabled(isLoading)
                        }

                        // Explore/Change Gym Button
                        Button(action: {
                            showingExploreGyms = true
                        }) {
                            if selectedGym == nil {
                                // Estado 1: Sin selección - Botón tipo card
                                HStack(spacing: 12) {
                                    Image(systemName: "magnifyingglass.circle.fill")
                                        .font(.system(size: 22))

                                    VStack(alignment: .leading, spacing: 2) {
                                        Text("Buscar Gimnasio")
                                            .font(.system(size: 17, weight: .semibold))
                                        Text("Encuentra tu gym ideal")
                                            .font(.system(size: 13, weight: .regular))
                                            .opacity(0.7)
                                    }

                                    Spacer()

                                    Image(systemName: "chevron.right")
                                        .font(.system(size: 14, weight: .semibold))
                                }
                                .foregroundColor(.white)
                                .padding(.horizontal, 20)
                                .frame(maxWidth: .infinity)
                                .frame(height: 64)
                                .background(Color.dynamicAccent(theme: themeManager.currentTheme))
                                .clipShape(RoundedRectangle(cornerRadius: 16))
                                .shadow(color: Color.black.opacity(0.15), radius: 12, x: 0, y: 4)
                                .shadow(color: Color.black.opacity(0.1), radius: 24, x: 0, y: 8)
                            } else {
                                // Estado 2: Con selección - Botón secundario
                                HStack(spacing: 8) {
                                    Image(systemName: "arrow.triangle.2.circlepath")
                                        .font(.system(size: 14))
                                    Text("Cambiar de Gimnasio")
                                        .font(.system(size: 15, weight: .medium))
                                }
                                .foregroundColor(Color.dynamicAccent(theme: themeManager.currentTheme))
                                .frame(maxWidth: .infinity)
                                .frame(height: 48)
                                .background(
                                    Color.dynamicAccent(theme: themeManager.currentTheme).opacity(0.1)
                                )
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                                .shadow(color: Color.black.opacity(0.1), radius: 8, x: 0, y: 2)
                                .shadow(color: Color.black.opacity(0.05), radius: 16, x: 0, y: 4)
                            }
                        }
                        .contentShape(Rectangle())
                    }
                    .fixedSize(horizontal: false, vertical: true)
                    .animation(.spring(response: 0.4, dampingFraction: 0.8), value: selectedGym)
                    .padding(.horizontal, 20)
                    .padding(.top, selectedGym == nil ? 12 : 10)
                    .padding(.bottom, 20)
                    .background(Color.dynamicBackground(theme: themeManager.currentTheme))
                }
                .ignoresSafeArea(edges: .bottom)
                .zIndex(1)
            }
            .onAppear {
                loadGyms()
                // Pre-seleccionar el gym si hay uno en storage
                if let currentGym = gymService.currentGym {
                    selectedGym = currentGym
                }
            }
            .sheet(isPresented: $showingExploreGyms) {
                AvailableGymsView(showCancelButton: true)
                    .environmentObject(themeManager)
                    .environmentObject(gymService)
                    .environmentObject(authService)
            }
        }
    }
    
    private func loadGyms() {
        Task {
            // No usar auto-selección aquí porque el usuario ya está en la pantalla de selección
            await gymService.getMyGyms(forceRefresh: true, autoSelectIfSingle: false)
        }
    }
}

struct GymSelectionCard: View {
    let gym: GymInfo
    let isSelected: Bool
    let isPersonalTrainer: Bool
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
                            Image(systemName: isPersonalTrainer ? "person.fill" : "building.2.fill")
                                .font(.system(size: 24))
                                .foregroundColor(.white)
                        }
                        .frame(width: 60, height: 60)
                        .clipShape(Circle())
                    } else {
                        Image(systemName: isPersonalTrainer ? "person.fill" : "building.2.fill")
                            .font(.system(size: 24))
                            .foregroundColor(.white)
                    }
                }

                // Gym Info
                VStack(alignment: .leading, spacing: 8) {
                    // Badge for Personal Trainer
                    if isPersonalTrainer {
                        Text("PERSONAL TRAINER")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundColor(.white)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 3)
                            .background(
                                RoundedRectangle(cornerRadius: 4)
                                    .fill(Color.dynamicAccent(theme: themeManager.currentTheme))
                            )
                    }

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

// MARK: - Gym Section Header

struct GymSectionHeader: View {
    let title: String
    let count: Int
    let icon: String
    let themeManager: ThemeManager

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .bold))
                .foregroundColor(Color.dynamicTextSecondary(theme: themeManager.currentTheme))

            Text(title.uppercased())
                .font(.system(size: 14, weight: .bold))
                .foregroundColor(Color.dynamicTextSecondary(theme: themeManager.currentTheme))

            Text("(\(count))")
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(Color.dynamicTextSecondary(theme: themeManager.currentTheme))

            Spacer()
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .padding(.top, 8)
    }
}

#Preview {
    GymSelectionView { gym in
        print("Selected gym: \(gym.name)")
    }
    .environmentObject(ThemeManager())
    .environmentObject(AuthServiceDirect())
}