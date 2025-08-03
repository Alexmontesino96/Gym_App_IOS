//
//  TrainersView.swift
//  Gym_API
//
//  Created by Assistant on 7/26/25.
//

import SwiftUI

struct TrainersView: View {
    @EnvironmentObject var themeManager: ThemeManager
    @EnvironmentObject var classService: ClassService
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
            loadTrainers()
        }
    }
    
    @ViewBuilder
    private var mainContent: some View {
        if classService.trainers.isEmpty {
            // Show skeleton loading for trainers
            CardSkeletonLoading(cardCount: 6, themeManager: themeManager)
        } else {
            ScrollView {
                VStack(spacing: 16) {
                    TrainersHeaderInfo()
                    TrainersGridSection(trainers: classService.trainers)
                }
                .padding(.bottom, 32)
            }
        }
    }
    
    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .navigationBarLeading) {
            Button(action: { dismiss() }) {
                Image(systemName: "chevron.left")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(Color.dynamicText(theme: themeManager.currentTheme))
            }
        }
        
        ToolbarItem(placement: .principal) {
            Text("Trainers")
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(Color.dynamicText(theme: themeManager.currentTheme))
        }
        
        ToolbarItem(placement: .navigationBarTrailing) {
            Button(action: { refreshTrainers() }) {
                Image(systemName: "arrow.clockwise")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(Color.dynamicAccent(theme: themeManager.currentTheme))
            }
        }
    }
    
    private func loadTrainers() {
        Task {
            await classService.loadTrainers()
        }
    }
    
    private func refreshTrainers() {
        Task {
            await classService.loadTrainers()
        }
    }
}

// MARK: - Trainers Header Info
struct TrainersHeaderInfo: View {
    @EnvironmentObject var themeManager: ThemeManager
    @EnvironmentObject var classService: ClassService
    
    var body: some View {
        VStack(spacing: 12) {
            Text("Meet Our Team")
                .font(.system(size: 24, weight: .bold))
                .foregroundColor(Color.dynamicText(theme: themeManager.currentTheme))
            
            Text("\(classService.trainers.count) Professional Trainers")
                .font(.system(size: 16))
                .foregroundColor(Color.dynamicTextSecondary(theme: themeManager.currentTheme))
        }
        .padding(.top, 20)
    }
}

// MARK: - Trainers Grid Section
struct TrainersGridSection: View {
    let trainers: [UserPublicProfile]
    @EnvironmentObject var themeManager: ThemeManager
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Our Trainers")
                .font(.system(size: 20, weight: .semibold))
                .foregroundColor(Color.dynamicText(theme: themeManager.currentTheme))
                .padding(.horizontal, 20)
            
            LazyVGrid(columns: [
                GridItem(.flexible(), spacing: 16),
                GridItem(.flexible(), spacing: 16)
            ], spacing: 16) {
                ForEach(trainers, id: \.id) { trainer in
                    TrainerCard(trainer: trainer)
                }
            }
            .padding(.horizontal, 20)
        }
    }
}

// MARK: - Trainer Card
struct TrainerCard: View {
    let trainer: UserPublicProfile
    @EnvironmentObject var themeManager: ThemeManager
    
    var body: some View {
        VStack(spacing: 12) {
            // Profile image or placeholder
            ProfileAvatar.large(pictureURL: trainer.picture ?? "", showBorder: true)
            
            VStack(spacing: 4) {
                // Name
                Text(trainer.fullName)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(Color.dynamicText(theme: themeManager.currentTheme))
                    .lineLimit(1)
                
                // Role
                Text(trainer.role.capitalized)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(Color.dynamicAccent(theme: themeManager.currentTheme))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 2)
                    .background(Color.dynamicAccent(theme: themeManager.currentTheme).opacity(0.1))
                    .clipShape(Capsule())
                
                // Bio (if available)
                if let bio = trainer.bio, !bio.isEmpty {
                    Text(bio)
                        .font(.system(size: 11))
                        .foregroundColor(Color.dynamicTextSecondary(theme: themeManager.currentTheme))
                        .lineLimit(2)
                        .multilineTextAlignment(.center)
                        .padding(.top, 4)
                }
                
                // Active status
                HStack(spacing: 4) {
                    Circle()
                        .fill(trainer.isActive ? Color.green : Color.red)
                        .frame(width: 6, height: 6)
                    Text(trainer.isActive ? "Active" : "Inactive")
                        .font(.system(size: 10))
                        .foregroundColor(trainer.isActive ? Color.green : Color.red)
                }
                .padding(.top, 2)
            }
        }
        .padding(16)
        .background(Color.dynamicSurface(theme: themeManager.currentTheme))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(
            color: Color.black.opacity(themeManager.currentTheme == .dark ? 0.3 : 0.08),
            radius: 8,
            x: 0,
            y: 2
        )
    }
}

// MARK: - Empty Trainers View
struct EmptyTrainersView: View {
    @EnvironmentObject var themeManager: ThemeManager
    
    var body: some View {
        VStack(spacing: 24) {
            Image(systemName: "person.2.badge.minus")
                .font(.system(size: 64))
                .foregroundColor(Color.dynamicTextSecondary(theme: themeManager.currentTheme).opacity(0.5))
            
            VStack(spacing: 8) {
                Text("No Trainers Available")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundColor(Color.dynamicText(theme: themeManager.currentTheme))
                
                Text("No trainers are currently available at this gym")
                    .font(.system(size: 16))
                    .foregroundColor(Color.dynamicTextSecondary(theme: themeManager.currentTheme))
                    .multilineTextAlignment(.center)
            }
        }
        .padding(.horizontal, 32)
    }
}

// MARK: - Preview
#Preview {
    TrainersView()
        .environmentObject(ThemeManager())
        .environmentObject(ClassService())
}