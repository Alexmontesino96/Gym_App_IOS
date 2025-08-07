//
//  LoadingAnimations.swift
//  Gym_API
//
//  Created by Assistant on 7/26/25.
//

import SwiftUI

// MARK: - Enhanced Loading View
struct EnhancedLoadingView: View {
    let message: String
    let themeManager: ThemeManager
    
    @State private var isAnimating = false
    @State private var animationPhase = 0
    @State private var scale: CGFloat = 0.5
    @State private var opacity: Double = 0
    
    init(message: String = "Loading...", themeManager: ThemeManager) {
        self.message = message
        self.themeManager = themeManager
    }
    
    var body: some View {
        VStack(spacing: 20) {
            // Animated dots loading
            HStack(spacing: 6) {
                ForEach(0..<3, id: \.self) { index in
                    Circle()
                        .fill(Color.dynamicAccent(theme: themeManager.currentTheme))
                        .frame(width: 8, height: 8)
                        .scaleEffect(animationPhase == index ? 1.4 : 0.8)
                        .opacity(animationPhase == index ? 1.0 : 0.4)
                        .animation(
                            .spring(response: 0.3, dampingFraction: 0.6, blendDuration: 0.1),
                            value: animationPhase
                        )
                }
            }
            .scaleEffect(scale)
            
            Text(message)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(Color.dynamicTextSecondary(theme: themeManager.currentTheme))
                .opacity(opacity)
        }
        .onAppear {
            withAnimation(.easeOut(duration: 0.4)) {
                scale = 1.0
                opacity = 1.0
            }
            startAnimations()
        }
    }
    
    private func startAnimations() {
        isAnimating = true
        
        Timer.scheduledTimer(withTimeInterval: 0.25, repeats: true) { _ in
            withAnimation(.easeInOut(duration: 0.2)) {
                animationPhase = (animationPhase + 1) % 3
            }
        }
    }
}

// MARK: - Pulse Loading View
struct PulseLoadingView: View {
    let message: String
    let themeManager: ThemeManager
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    
    @State private var scale: CGFloat = 1.0
    @State private var opacity: Double = 1.0
    @State private var rotation: Double = 0
    
    init(message: String = "Loading...", themeManager: ThemeManager) {
        self.message = message
        self.themeManager = themeManager
    }
    
    var body: some View {
        VStack(spacing: dynamicTypeSize.adjustedSpacing(12)) {
            ZStack {
                // Outer pulse ring
                Circle()
                    .stroke(Color.dynamicAccent(theme: themeManager.currentTheme).opacity(0.3), lineWidth: 2)
                    .frame(
                        width: min(50 * dynamicTypeSize.scalingFactor, 70),
                        height: min(50 * dynamicTypeSize.scalingFactor, 70)
                    )
                    .scaleEffect(scale)
                    .opacity(1.0 - (scale * 0.3))
                
                // Inner solid circle
                Circle()
                    .fill(Color.dynamicAccent(theme: themeManager.currentTheme))
                    .frame(
                        width: min(24 * dynamicTypeSize.scalingFactor, 35),
                        height: min(24 * dynamicTypeSize.scalingFactor, 35)
                    )
                    .rotationEffect(.degrees(rotation))
            }
            .animation(
                .easeInOut(duration: 1.2).repeatForever(autoreverses: false),
                value: scale
            )
            .animation(
                .linear(duration: 2.0).repeatForever(autoreverses: false),
                value: rotation
            )
            .accessibilityHidden(true) // Hide decorative loading animation
            
            Text(message)
                .font(.cappedDynamicSystem(size: 13, weight: .medium, maxSize: 17))
                .foregroundColor(Color.dynamicTextSecondary(theme: themeManager.currentTheme))
                .opacity(opacity)
                .dynamicTypeSupport(maxLines: 2)
        }
        .onAppear {
            scale = 1.8
            rotation = 360
            
            withAnimation(.easeInOut(duration: 0.3)) {
                opacity = 1.0
            }
        }
        // Accessibility: Announce loading state
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(message)
        .accessibilityAddTraits([.updatesFrequently])
        .accessibilityValue("Loading in progress")
    }
}

// MARK: - Shimmer Loading View
struct ShimmerLoadingView: View {
    let themeManager: ThemeManager
    
    @State private var shimmerOffset: CGFloat = -200
    
    var body: some View {
        VStack(spacing: 16) {
            // Simulated content rows
            ForEach(0..<3, id: \.self) { _ in
                HStack(spacing: 12) {
                    // Avatar placeholder
                    Circle()
                        .fill(Color.dynamicTextSecondary(theme: themeManager.currentTheme).opacity(0.2))
                        .frame(width: 50, height: 50)
                        .overlay(shimmerOverlay)
                    
                    VStack(alignment: .leading, spacing: 8) {
                        // Title placeholder
                        Rectangle()
                            .fill(Color.dynamicTextSecondary(theme: themeManager.currentTheme).opacity(0.2))
                            .frame(height: 16)
                            .frame(maxWidth: .infinity)
                            .overlay(shimmerOverlay)
                        
                        // Subtitle placeholder
                        Rectangle()
                            .fill(Color.dynamicTextSecondary(theme: themeManager.currentTheme).opacity(0.2))
                            .frame(height: 12)
                            .frame(maxWidth: 200)
                            .overlay(shimmerOverlay)
                    }
                    
                    Spacer()
                }
                .padding(.horizontal, 20)
            }
        }
        .onAppear {
            startShimmer()
        }
    }
    
    private var shimmerOverlay: some View {
        LinearGradient(
            colors: [
                Color.clear,
                Color.white.opacity(0.4),
                Color.clear
            ],
            startPoint: .leading,
            endPoint: .trailing
        )
        .offset(x: shimmerOffset)
        .animation(
            .linear(duration: 1.5).repeatForever(autoreverses: false),
            value: shimmerOffset
        )
    }
    
    private func startShimmer() {
        shimmerOffset = 200
    }
}

// MARK: - Card Skeleton Loading
struct CardSkeletonLoading: View {
    let themeManager: ThemeManager
    let cardCount: Int
    
    @State private var opacity: Double = 0.3
    @State private var shimmerOffset: CGFloat = -200
    @State private var scale: CGFloat = 0.95
    
    init(cardCount: Int = 3, themeManager: ThemeManager) {
        self.cardCount = cardCount
        self.themeManager = themeManager
    }
    
    var body: some View {
        LazyVGrid(columns: [
            GridItem(.flexible()),
            GridItem(.flexible())
        ], spacing: 16) {
            ForEach(0..<cardCount, id: \.self) { index in
                VStack(spacing: 12) {
                    // Image placeholder with shimmer
                    Circle()
                        .fill(Color.dynamicTextSecondary(theme: themeManager.currentTheme).opacity(0.2))
                        .frame(width: 80, height: 80)
                        .overlay(shimmerOverlay)
                        .scaleEffect(scale)
                    
                    // Text placeholders with shimmer
                    Rectangle()
                        .fill(Color.dynamicTextSecondary(theme: themeManager.currentTheme).opacity(0.2))
                        .frame(height: 16)
                        .frame(maxWidth: 100)
                        .clipShape(RoundedRectangle(cornerRadius: 4))
                        .overlay(shimmerOverlay)
                    
                    Rectangle()
                        .fill(Color.dynamicTextSecondary(theme: themeManager.currentTheme).opacity(0.2))
                        .frame(height: 12)
                        .frame(maxWidth: 80)
                        .clipShape(RoundedRectangle(cornerRadius: 4))
                        .overlay(shimmerOverlay)
                }
                .padding(16)
                .background(Color.dynamicSurface(theme: themeManager.currentTheme))
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .scaleEffect(scale)
                .animation(
                    .easeInOut(duration: 0.6)
                    .delay(Double(index) * 0.1),
                    value: scale
                )
            }
        }
        .padding(.horizontal, 20)
        .onAppear {
            withAnimation(.easeOut(duration: 0.4)) {
                scale = 1.0
            }
            
            withAnimation(.linear(duration: 1.5).repeatForever(autoreverses: false)) {
                shimmerOffset = 200
            }
        }
    }
    
    private var shimmerOverlay: some View {
        LinearGradient(
            colors: [
                Color.clear,
                Color.white.opacity(0.3),
                Color.clear
            ],
            startPoint: .leading,
            endPoint: .trailing
        )
        .offset(x: shimmerOffset)
    }
}