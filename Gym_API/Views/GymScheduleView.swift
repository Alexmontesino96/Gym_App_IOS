//
//  GymScheduleView.swift
//  Gym_API
//
//  Created by Assistant on 7/26/25.
//

import SwiftUI

struct GymScheduleView: View {
    @EnvironmentObject var themeManager: ThemeManager
    @EnvironmentObject var gymService: GymService
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
            loadGymHours()
        }
    }
    
    @ViewBuilder
    private var mainContent: some View {
        if gymService.isLoadingHours {
            ScheduleLoadingView()
        } else if gymService.gymHours.isEmpty {
            EmptyScheduleView()
        } else {
            ScrollView {
                VStack(spacing: 16) {
                    if let gym = gymService.currentGym {
                        GymHeaderInfo(gym: gym)
                    }
                    
                    WeeklyScheduleSection(hours: gymService.gymHours)
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
            Text("Schedule")
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(Color.dynamicText(theme: themeManager.currentTheme))
        }
        
        ToolbarItem(placement: .navigationBarTrailing) {
            Button(action: { refreshSchedule() }) {
                Image(systemName: "arrow.clockwise")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(Color.dynamicAccent(theme: themeManager.currentTheme))
            }
        }
    }
    
    private func loadGymHours() {
        Task {
            await gymService.getRegularGymHours()
        }
    }
    
    private func refreshSchedule() {
        Task {
            await gymService.getRegularGymHours(forceRefresh: true)
        }
    }
}

// MARK: - Gym Header Info
struct GymHeaderInfo: View {
    let gym: GymInfo
    @EnvironmentObject var themeManager: ThemeManager
    
    var body: some View {
        VStack(spacing: 12) {
            Text(gym.name)
                .font(.system(size: 24, weight: .bold))
                .foregroundColor(Color.dynamicText(theme: themeManager.currentTheme))
            
            Text("Regular Operating Hours")
                .font(.system(size: 16))
                .foregroundColor(Color.dynamicTextSecondary(theme: themeManager.currentTheme))
        }
        .padding(.top, 20)
    }
}

// MARK: - Weekly Schedule Section
struct WeeklyScheduleSection: View {
    let hours: [GymHours]
    @EnvironmentObject var themeManager: ThemeManager
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Weekly Schedule")
                .font(.system(size: 20, weight: .semibold))
                .foregroundColor(Color.dynamicText(theme: themeManager.currentTheme))
                .padding(.horizontal, 20)
            
            VStack(spacing: 8) {
                ForEach(sortedHours, id: \.id) { dayHours in
                    DayScheduleRow(hours: dayHours)
                }
            }
            .padding(.horizontal, 20)
        }
    }
    
    private var sortedHours: [GymHours] {
        return hours.sorted { $0.dayOfWeek < $1.dayOfWeek }
    }
}

// MARK: - Day Schedule Row
struct DayScheduleRow: View {
    let hours: GymHours
    @EnvironmentObject var themeManager: ThemeManager
    
    var body: some View {
        HStack {
            // Day name
            Text(hours.dayName)
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(Color.dynamicText(theme: themeManager.currentTheme))
                .frame(width: 80, alignment: .leading)
            
            Spacer()
            
            // Hours or closed status
            HStack(spacing: 8) {
                if hours.isOpen {
                    HStack(spacing: 4) {
                        Image(systemName: "clock")
                            .font(.system(size: 12))
                            .foregroundColor(Color.dynamicAccent(theme: themeManager.currentTheme))
                        
                        Text(hours.hoursDisplay)
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(Color.dynamicText(theme: themeManager.currentTheme))
                    }
                } else {
                    HStack(spacing: 4) {
                        Image(systemName: "xmark.circle")
                            .font(.system(size: 12))
                            .foregroundColor(.red)
                        
                        Text("Closed")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.red)
                    }
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(
                hours.isOpen ? 
                Color.dynamicAccent(theme: themeManager.currentTheme).opacity(0.1) :
                Color.red.opacity(0.1)
            )
            .clipShape(Capsule())
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color.dynamicSurface(theme: themeManager.currentTheme))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

// MARK: - Schedule Loading View
struct ScheduleLoadingView: View {
    @EnvironmentObject var themeManager: ThemeManager
    
    var body: some View {
        EnhancedLoadingView(message: "Loading schedule...", themeManager: themeManager)
    }
}

// MARK: - Empty Schedule View
struct EmptyScheduleView: View {
    @EnvironmentObject var themeManager: ThemeManager
    
    var body: some View {
        VStack(spacing: 24) {
            Image(systemName: "clock.badge.xmark")
                .font(.system(size: 64))
                .foregroundColor(Color.dynamicTextSecondary(theme: themeManager.currentTheme).opacity(0.5))
            
            VStack(spacing: 8) {
                Text("No Schedule Available")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundColor(Color.dynamicText(theme: themeManager.currentTheme))
                
                Text("The gym schedule is not available at the moment")
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
    GymScheduleView()
        .environmentObject(ThemeManager())
}