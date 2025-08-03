//
//  PermissionsSetupView.swift
//  Gym_API
//
//  Created by Assistant on 8/3/25.
//
//  Vista educativa para solicitar permisos necesarios con explicaciones claras de beneficios

import SwiftUI
import UserNotifications
import AVFoundation

struct PermissionsSetupView: View {
    @EnvironmentObject var themeManager: ThemeManager
    @EnvironmentObject var onboardingManager: OnboardingManager
    @State private var currentPermissionIndex = 0
    @State private var showContent = false
    @State private var permissionStates: [PermissionType: PermissionStatus] = [:]
    @State private var allPermissionsRequested = false
    
    private let permissions = PermissionType.allCases
    
    var body: some View {
        ZStack {
            // Dynamic background
            LinearGradient(
                gradient: Gradient(colors: [
                    Color.dynamicBackground(theme: themeManager.currentTheme),
                    Color.dynamicAccent(theme: themeManager.currentTheme).opacity(0.08)
                ]),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Header section
                headerSection
                
                // Permission cards
                permissionCardsSection
                
                // Navigation section
                navigationSection
                
                Spacer(minLength: 40)
            }
        }
        .onAppear {
            startInitialAnimation()
            checkCurrentPermissionStates()
        }
    }
    
    // MARK: - Header Section
    
    private var headerSection: some View {
        VStack(spacing: 20) {
            HStack {
                Button(action: {
                    onboardingManager.previousStep()
                }) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 18, weight: .medium))
                        .foregroundColor(Color.dynamicText(theme: themeManager.currentTheme))
                        .frame(width: 32, height: 32)
                        .background(
                            Circle()
                                .fill(Color.dynamicSurface(theme: themeManager.currentTheme))
                                .shadow(color: .black.opacity(0.1), radius: 5, x: 0, y: 2)
                        )
                }
                
                Spacer()
                
                Button("Skip All") {
                    onboardingManager.completeOnboarding()
                }
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(Color.dynamicTextSecondary(theme: themeManager.currentTheme))
            }
            .padding(.horizontal, 24)
            .padding(.top, 20)
            .opacity(showContent ? 1.0 : 0.0)
            .animation(.easeOut(duration: 0.6).delay(0.2), value: showContent)
            
            VStack(spacing: 16) {
                // Icon animation
                ZStack {
                    ForEach(0..<3, id: \.self) { index in
                        Circle()
                            .fill(Color.dynamicAccent(theme: themeManager.currentTheme).opacity(0.1 - Double(index) * 0.03))
                            .frame(width: 100 + CGFloat(index * 20), height: 100 + CGFloat(index * 20))
                            .scaleEffect(showContent ? 1.0 : 0.3)
                            .animation(.spring(response: 0.8, dampingFraction: 0.6).delay(0.4 + Double(index) * 0.1), value: showContent)
                    }
                    
                    Image(systemName: "shield.checkered")
                        .font(.system(size: 40, weight: .medium))
                        .foregroundColor(Color.dynamicAccent(theme: themeManager.currentTheme))
                        .scaleEffect(showContent ? 1.0 : 0.3)
                        .animation(.spring(response: 0.8, dampingFraction: 0.6).delay(0.6), value: showContent)
                }
                
                VStack(spacing: 12) {
                    Text("Enable Key Features")
                        .font(.system(size: 32, weight: .bold))
                        .foregroundColor(Color.dynamicText(theme: themeManager.currentTheme))
                        .multilineTextAlignment(.center)
                        .opacity(showContent ? 1.0 : 0.0)
                        .scaleEffect(showContent ? 1.0 : 0.8)
                    
                    Text("We'll only ask for permissions that enhance your experience")
                        .font(.system(size: 17, weight: .medium))
                        .foregroundColor(Color.dynamicTextSecondary(theme: themeManager.currentTheme))
                        .multilineTextAlignment(.center)
                        .opacity(showContent ? 1.0 : 0.0)
                        .offset(y: showContent ? 0 : 20)
                }
                .padding(.horizontal, 32)
                .animation(.easeOut(duration: 0.8).delay(0.8), value: showContent)
            }
        }
    }
    
    // MARK: - Permission Cards Section
    
    private var permissionCardsSection: some View {
        VStack(spacing: 16) {
            ForEach(Array(permissions.enumerated()), id: \.element) { index, permission in
                PermissionCard(
                    permission: permission,
                    status: permissionStates[permission] ?? .notRequested,
                    isHighlighted: !allPermissionsRequested && index == currentPermissionIndex
                ) {
                    requestPermission(permission)
                }
                .opacity(showContent ? 1.0 : 0.0)
                .scaleEffect(showContent ? 1.0 : 0.8)
                .animation(.spring(response: 0.6, dampingFraction: 0.8).delay(1.0 + Double(index) * 0.1), value: showContent)
            }
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 30)
    }
    
    // MARK: - Navigation Section
    
    private var navigationSection: some View {
        VStack(spacing: 20) {
            // Progress indicator
            if !allPermissionsRequested {
                HStack(spacing: 8) {
                    ForEach(0..<permissions.count, id: \.self) { index in
                        Circle()
                            .fill(
                                index <= currentPermissionIndex
                                    ? Color.dynamicAccent(theme: themeManager.currentTheme)
                                    : Color.dynamicTextSecondary(theme: themeManager.currentTheme).opacity(0.3)
                            )
                            .frame(width: 8, height: 8)
                    }
                }
                .opacity(showContent ? 1.0 : 0.0)
                .animation(.easeOut(duration: 0.6).delay(1.4), value: showContent)
            }
            
            // Action button
            Button(action: {
                if allPermissionsRequested {
                    onboardingManager.completeOnboarding()
                } else {
                    requestAllPermissions()
                }
            }) {
                HStack(spacing: 12) {
                    Text(allPermissionsRequested ? "Continue to App" : "Enable All")
                        .font(.system(size: 18, weight: .semibold))
                    
                    Image(systemName: allPermissionsRequested ? "arrow.right" : "checkmark.shield")
                        .font(.system(size: 16, weight: .semibold))
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 56)
                .background(
                    RoundedRectangle(cornerRadius: 28)
                        .fill(Color.dynamicAccent(theme: themeManager.currentTheme))
                        .shadow(
                            color: Color.dynamicAccent(theme: themeManager.currentTheme).opacity(0.3),
                            radius: 20, x: 0, y: 10
                        )
                )
            }
            .scaleEffect(showContent ? 1.0 : 0.8)
            .opacity(showContent ? 1.0 : 0.0)
            .animation(.spring(response: 0.6, dampingFraction: 0.8).delay(1.6), value: showContent)
            .padding(.horizontal, 32)
            
            // Privacy note
            VStack(spacing: 8) {
                HStack(spacing: 8) {
                    Image(systemName: "lock.shield")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(Color.dynamicAccent(theme: themeManager.currentTheme))
                    
                    Text("Your privacy is protected")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(Color.dynamicText(theme: themeManager.currentTheme))
                }
                
                Text("You can change these permissions anytime in Settings")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(Color.dynamicTextSecondary(theme: themeManager.currentTheme))
                    .multilineTextAlignment(.center)
            }
            .opacity(showContent ? 0.8 : 0.0)
            .animation(.easeOut(duration: 0.6).delay(1.8), value: showContent)
        }
    }
    
    // MARK: - Helper Methods
    
    private func startInitialAnimation() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            withAnimation {
                showContent = true
            }
        }
    }
    
    private func checkCurrentPermissionStates() {
        for permission in permissions {
            checkPermissionStatus(permission) { status in
                DispatchQueue.main.async {
                    permissionStates[permission] = status
                }
            }
        }
    }
    
    private func requestPermission(_ permission: PermissionType) {
        switch permission {
        case .notifications:
            requestNotificationPermission()
        case .camera:
            requestCameraPermission()
        case .location:
            requestLocationPermission()
        }
    }
    
    private func requestAllPermissions() {
        for permission in permissions {
            requestPermission(permission)
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            allPermissionsRequested = true
            checkCurrentPermissionStates()
        }
    }
    
    // MARK: - Permission Requests
    
    private func requestNotificationPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound]) { granted, error in
            DispatchQueue.main.async {
                permissionStates[.notifications] = granted ? .granted : .denied
                if currentPermissionIndex == 0 {
                    currentPermissionIndex = min(currentPermissionIndex + 1, permissions.count - 1)
                }
            }
        }
    }
    
    private func requestCameraPermission() {
        AVCaptureDevice.requestAccess(for: .video) { granted in
            DispatchQueue.main.async {
                permissionStates[.camera] = granted ? .granted : .denied
                if currentPermissionIndex == 1 {
                    currentPermissionIndex = min(currentPermissionIndex + 1, permissions.count - 1)
                }
            }
        }
    }
    
    private func requestLocationPermission() {
        // Note: For location, you'd typically use CLLocationManager
        // For this demo, we'll simulate the permission
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            permissionStates[.location] = .granted // Simulate granted
            if currentPermissionIndex == 2 {
                allPermissionsRequested = true
            }
        }
    }
    
    private func checkPermissionStatus(_ permission: PermissionType, completion: @escaping (PermissionStatus) -> Void) {
        switch permission {
        case .notifications:
            UNUserNotificationCenter.current().getNotificationSettings { settings in
                switch settings.authorizationStatus {
                case .authorized, .provisional:
                    completion(.granted)
                case .denied:
                    completion(.denied)
                default:
                    completion(.notRequested)
                }
            }
            
        case .camera:
            let status = AVCaptureDevice.authorizationStatus(for: .video)
            switch status {
            case .authorized:
                completion(.granted)
            case .denied, .restricted:
                completion(.denied)
            default:
                completion(.notRequested)
            }
            
        case .location:
            // For demo purposes, assume not requested
            completion(.notRequested)
        }
    }
}

// MARK: - Permission Types and Status

enum PermissionType: CaseIterable {
    case notifications
    case camera
    case location
    
    var title: String {
        switch self {
        case .notifications: return "Notifications"
        case .camera: return "Camera Access"
        case .location: return "Location Services"
        }
    }
    
    var subtitle: String {
        switch self {
        case .notifications: return "Stay updated with class schedules and workout reminders"
        case .camera: return "Take progress photos and scan QR codes at the gym"
        case .location: return "Find nearby gyms and get location-based recommendations"
        }
    }
    
    var icon: String {
        switch self {
        case .notifications: return "bell.fill"
        case .camera: return "camera.fill"
        case .location: return "location.fill"
        }
    }
    
    var benefits: [String] {
        switch self {
        case .notifications:
            return [
                "Class reminders",
                "Workout notifications",
                "Community updates"
            ]
        case .camera:
            return [
                "Progress photos",
                "QR code scanning",
                "Profile pictures"
            ]
        case .location:
            return [
                "Nearby gym discovery",
                "Location-based tips",
                "Auto check-ins"
            ]
        }
    }
    
    var color: Color {
        switch self {
        case .notifications: return .blue
        case .camera: return .green
        case .location: return .orange
        }
    }
}

enum PermissionStatus {
    case notRequested
    case granted
    case denied
    
    var statusText: String {
        switch self {
        case .notRequested: return "Not Requested"
        case .granted: return "Granted"
        case .denied: return "Denied"
        }
    }
    
    var statusColor: Color {
        switch self {
        case .notRequested: return .gray
        case .granted: return .green
        case .denied: return .red
        }
    }
    
    var icon: String {
        switch self {
        case .notRequested: return "circle"
        case .granted: return "checkmark.circle.fill"
        case .denied: return "xmark.circle.fill"
        }
    }
}

// MARK: - Permission Card Component

struct PermissionCard: View {
    let permission: PermissionType
    let status: PermissionStatus
    let isHighlighted: Bool
    let action: () -> Void
    @EnvironmentObject var themeManager: ThemeManager
    @State private var isPressed = false
    
    var body: some View {
        VStack(spacing: 0) {
            // Main card content
            HStack(spacing: 16) {
                // Icon section
                ZStack {
                    Circle()
                        .fill(permission.color.opacity(0.15))
                        .frame(width: 50, height: 50)
                    
                    Image(systemName: permission.icon)
                        .font(.system(size: 24, weight: .medium))
                        .foregroundColor(permission.color)
                }
                
                // Text content
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text(permission.title)
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundColor(Color.dynamicText(theme: themeManager.currentTheme))
                        
                        Spacer()
                        
                        // Status indicator
                        HStack(spacing: 4) {
                            Image(systemName: status.icon)
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(status.statusColor)
                            
                            Text(status.statusText)
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(status.statusColor)
                        }
                    }
                    
                    Text(permission.subtitle)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(Color.dynamicTextSecondary(theme: themeManager.currentTheme))
                        .lineLimit(2)
                }
                
                Spacer()
            }
            .padding(20)
            
            // Benefits section (only show if highlighted)
            if isHighlighted && status == .notRequested {
                VStack(spacing: 12) {
                    Divider()
                        .background(Color.dynamicTextSecondary(theme: themeManager.currentTheme).opacity(0.2))
                    
                    VStack(alignment: .leading, spacing: 8) {
                        Text("This enables:")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(Color.dynamicText(theme: themeManager.currentTheme))
                        
                        ForEach(permission.benefits, id: \.self) { benefit in
                            HStack(spacing: 8) {
                                Image(systemName: "checkmark.circle.fill")
                                    .font(.system(size: 12))
                                    .foregroundColor(.green)
                                
                                Text(benefit)
                                    .font(.system(size: 13, weight: .medium))
                                    .foregroundColor(Color.dynamicTextSecondary(theme: themeManager.currentTheme))
                                
                                Spacer()
                            }
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 16)
                }
                .transition(.scale.combined(with: .opacity))
            }
        }
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.dynamicSurface(theme: themeManager.currentTheme))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(
                            isHighlighted && status == .notRequested
                                ? permission.color.opacity(0.5)
                                : Color.clear,
                            lineWidth: 2
                        )
                )
                .shadow(
                    color: isHighlighted
                        ? permission.color.opacity(0.2)
                        : Color.black.opacity(0.1),
                    radius: isHighlighted ? 15 : 8,
                    x: 0,
                    y: isHighlighted ? 8 : 4
                )
        )
        .scaleEffect(isPressed ? 0.98 : (isHighlighted ? 1.02 : 1.0))
        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: isHighlighted)
        .animation(.easeInOut(duration: 0.1), value: isPressed)
        .onTapGesture {
            if status == .notRequested {
                isPressed = true
                
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    isPressed = false
                    action()
                }
            }
        }
    }
}

#Preview {
    PermissionsSetupView()
        .environmentObject(ThemeManager())
        .environmentObject(OnboardingManager())
}