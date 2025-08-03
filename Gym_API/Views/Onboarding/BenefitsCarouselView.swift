//
//  BenefitsCarouselView.swift
//  Gym_API
//
//  Created by Assistant on 8/3/25.
//
//  Carousel interactivo de beneficios del gym con animaciones fluidas y scroll automático

import SwiftUI

struct BenefitsCarouselView: View {
    @EnvironmentObject var themeManager: ThemeManager
    @EnvironmentObject var onboardingManager: OnboardingManager
    @State private var dragOffset: CGSize = .zero
    @State private var autoScrollTimer: Timer?
    @State private var showContent = false
    @State private var cardAnimation = false
    
    private let cardWidth: CGFloat = 280
    private let cardSpacing: CGFloat = 20
    private let autoScrollInterval: TimeInterval = 4.0
    
    var body: some View {
        ZStack {
            // Dynamic background
            LinearGradient(
                gradient: Gradient(colors: [
                    Color.dynamicBackground(theme: themeManager.currentTheme),
                    Color.dynamicAccent(theme: themeManager.currentTheme).opacity(0.1)
                ]),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Header section
                headerSection
                
                // Main carousel
                carouselSection
                
                // Navigation and controls
                navigationSection
                
                Spacer(minLength: 40)
            }
        }
        .onAppear {
            startInitialAnimation()
            startAutoScroll()
        }
        .onDisappear {
            stopAutoScroll()
        }
    }
    
    // MARK: - Header Section
    
    private var headerSection: some View {
        VStack(spacing: 16) {
            HStack {
                Button("Skip") {
                    onboardingManager.skipOnboarding()
                }
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(Color.dynamicTextSecondary(theme: themeManager.currentTheme))
                
                Spacer()
            }
            .padding(.horizontal, 24)
            .padding(.top, 20)
            
            VStack(spacing: 12) {
                Text("Why Choose GYM API?")
                    .font(.system(size: 32, weight: .bold))
                    .foregroundColor(Color.dynamicText(theme: themeManager.currentTheme))
                    .multilineTextAlignment(.center)
                    .opacity(showContent ? 1.0 : 0.0)
                    .scaleEffect(showContent ? 1.0 : 0.8)
                
                Text("Discover the benefits that make us different")
                    .font(.system(size: 17, weight: .medium))
                    .foregroundColor(Color.dynamicTextSecondary(theme: themeManager.currentTheme))
                    .multilineTextAlignment(.center)
                    .opacity(showContent ? 1.0 : 0.0)
                    .offset(y: showContent ? 0 : 20)
            }
            .padding(.horizontal, 24)
        }
        .animation(.easeOut(duration: 0.8).delay(0.3), value: showContent)
    }
    
    // MARK: - Carousel Section
    
    private var carouselSection: some View {
        VStack(spacing: 20) {
            // Cards container
            GeometryReader { geometry in
                HStack(spacing: cardSpacing) {
                    ForEach(Array(onboardingManager.benefits.enumerated()), id: \.element.id) { index, benefit in
                        BenefitCard(
                            benefit: benefit,
                            isActive: index == onboardingManager.currentBenefitIndex,
                            cardWidth: cardWidth
                        )
                        .scaleEffect(index == onboardingManager.currentBenefitIndex ? 1.0 : 0.85)
                        .opacity(index == onboardingManager.currentBenefitIndex ? 1.0 : 0.7)
                        .animation(.spring(response: 0.6, dampingFraction: 0.8), value: onboardingManager.currentBenefitIndex)
                        .opacity(showContent ? 1.0 : 0.0)
                        .scaleEffect(showContent ? 1.0 : 0.3)
                        .animation(.spring(response: 0.8, dampingFraction: 0.8).delay(Double(index) * 0.1), value: showContent)
                    }
                }
                .offset(x: calculateCarouselOffset(geometry: geometry))
                .gesture(
                    DragGesture()
                        .onChanged { value in
                            dragOffset = value.translation
                            stopAutoScroll()
                        }
                        .onEnded { value in
                            handleDragEnd(value: value)
                            startAutoScroll()
                        }
                )
            }
            .frame(height: 420)
            .clipped()
            
            // Page dots indicator
            pageDotsIndicator
        }
        .padding(.vertical, 40)
    }
    
    // MARK: - Navigation Section
    
    private var navigationSection: some View {
        VStack(spacing: 24) {
            // Get Started button
            Button(action: {
                stopAutoScroll()
                onboardingManager.nextStep()
            }) {
                HStack(spacing: 12) {
                    Image(systemName: "arrow.right.circle.fill")
                        .font(.system(size: 20))
                    
                    Text("Get Started")
                        .font(.system(size: 18, weight: .semibold))
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 56)
                .background(
                    RoundedRectangle(cornerRadius: 28)
                        .fill(Color.dynamicAccent(theme: themeManager.currentTheme))
                        .shadow(color: Color.dynamicAccent(theme: themeManager.currentTheme).opacity(0.3), 
                               radius: 20, x: 0, y: 10)
                )
            }
            .scaleEffect(showContent ? 1.0 : 0.8)
            .opacity(showContent ? 1.0 : 0.0)
            .animation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.6), value: showContent)
            .padding(.horizontal, 32)
            
            // Auto-scroll indicator
            HStack(spacing: 8) {
                Image(systemName: "arrow.left.arrow.right")
                    .font(.system(size: 12))
                    .foregroundColor(Color.dynamicTextSecondary(theme: themeManager.currentTheme))
                
                Text("Swipe or wait for auto-scroll")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(Color.dynamicTextSecondary(theme: themeManager.currentTheme))
            }
            .opacity(showContent ? 0.7 : 0.0)
            .animation(.easeInOut(duration: 0.5).delay(1.0), value: showContent)
        }
    }
    
    // MARK: - Page Dots Indicator
    
    private var pageDotsIndicator: some View {
        HStack(spacing: 8) {
            ForEach(0..<onboardingManager.benefits.count, id: \.self) { index in
                Button(action: {
                    stopAutoScroll()
                    onboardingManager.goToBenefit(index)
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                        startAutoScroll()
                    }
                }) {
                    Circle()
                        .fill(
                            index == onboardingManager.currentBenefitIndex
                            ? Color.dynamicAccent(theme: themeManager.currentTheme)
                            : Color.dynamicTextSecondary(theme: themeManager.currentTheme).opacity(0.3)
                        )
                        .frame(width: index == onboardingManager.currentBenefitIndex ? 10 : 6,
                               height: index == onboardingManager.currentBenefitIndex ? 10 : 6)
                        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: onboardingManager.currentBenefitIndex)
                }
            }
        }
        .opacity(showContent ? 1.0 : 0.0)
        .animation(.easeInOut(duration: 0.5).delay(0.8), value: showContent)
    }
    
    // MARK: - Helper Methods
    
    private func calculateCarouselOffset(geometry: GeometryProxy) -> CGFloat {
        let centerX = geometry.size.width / 2
        let cardCenterOffset = cardWidth / 2
        let totalCardWidth = cardWidth + cardSpacing
        
        let baseOffset = centerX - cardCenterOffset - (CGFloat(onboardingManager.currentBenefitIndex) * totalCardWidth)
        
        return baseOffset + dragOffset.width
    }
    
    private func handleDragEnd(value: DragGesture.Value) {
        let threshold: CGFloat = 50
        
        withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
            if value.translation.width > threshold {
                // Swipe right - previous benefit
                let newIndex = max(0, onboardingManager.currentBenefitIndex - 1)
                onboardingManager.goToBenefit(newIndex)
            } else if value.translation.width < -threshold {
                // Swipe left - next benefit
                let newIndex = min(onboardingManager.benefits.count - 1, onboardingManager.currentBenefitIndex + 1)
                onboardingManager.goToBenefit(newIndex)
            }
            
            dragOffset = .zero
        }
    }
    
    private func startInitialAnimation() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            withAnimation {
                showContent = true
            }
        }
    }
    
    private func startAutoScroll() {
        stopAutoScroll()
        autoScrollTimer = Timer.scheduledTimer(withTimeInterval: autoScrollInterval, repeats: true) { _ in
            withAnimation(.spring(response: 0.8, dampingFraction: 0.8)) {
                onboardingManager.nextBenefit()
            }
        }
    }
    
    private func stopAutoScroll() {
        autoScrollTimer?.invalidate()
        autoScrollTimer = nil
    }
}

// MARK: - Benefit Card Component

struct BenefitCard: View {
    let benefit: OnboardingBenefit
    let isActive: Bool
    let cardWidth: CGFloat
    @EnvironmentObject var themeManager: ThemeManager
    @State private var iconScale: CGFloat = 1.0
    
    var body: some View {
        VStack(spacing: 24) {
            // Icon section with animated background
            ZStack {
                // Animated background circle
                Circle()
                    .fill(benefit.accentColor.opacity(0.15))
                    .frame(width: 120, height: 120)
                    .scaleEffect(isActive ? 1.1 : 1.0)
                    .opacity(isActive ? 1.0 : 0.6)
                
                // Smaller accent circle
                Circle()
                    .fill(benefit.accentColor.opacity(0.25))
                    .frame(width: 80, height: 80)
                    .scaleEffect(isActive ? 1.0 : 0.8)
                
                // Main icon
                Image(systemName: benefit.icon)
                    .font(.system(size: 36, weight: .medium))
                    .foregroundColor(benefit.accentColor)
                    .scaleEffect(iconScale)
                    .onAppear {
                        if isActive {
                            withAnimation(.easeInOut(duration: 2.0).repeatForever(autoreverses: true)) {
                                iconScale = 1.1
                            }
                        }
                    }
                    .onChange(of: isActive) { newValue in
                        if newValue {
                            withAnimation(.easeInOut(duration: 2.0).repeatForever(autoreverses: true)) {
                                iconScale = 1.1
                            }
                        } else {
                            withAnimation(.easeInOut(duration: 0.3)) {
                                iconScale = 1.0
                            }
                        }
                    }
            }
            .animation(.spring(response: 0.6, dampingFraction: 0.8), value: isActive)
            
            // Text content
            VStack(spacing: 16) {
                VStack(spacing: 8) {
                    Text(benefit.title)
                        .font(.system(size: 24, weight: .bold))
                        .foregroundColor(Color.dynamicText(theme: themeManager.currentTheme))
                        .multilineTextAlignment(.center)
                        .lineLimit(2)
                    
                    Text(benefit.subtitle)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(benefit.accentColor)
                        .multilineTextAlignment(.center)
                        .lineLimit(2)
                }
                
                Text(benefit.description)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(Color.dynamicTextSecondary(theme: themeManager.currentTheme))
                    .multilineTextAlignment(.center)
                    .lineLimit(3)
                    .opacity(isActive ? 1.0 : 0.8)
            }
            
            Spacer(minLength: 20)
        }
        .padding(24)
        .frame(width: cardWidth)
        .background(
            RoundedRectangle(cornerRadius: 24)
                .fill(Color.dynamicSurface(theme: themeManager.currentTheme))
                .shadow(
                    color: isActive 
                        ? benefit.accentColor.opacity(0.2)
                        : Color.black.opacity(0.1),
                    radius: isActive ? 20 : 10,
                    x: 0,
                    y: isActive ? 10 : 5
                )
        )
        .overlay(
            RoundedRectangle(cornerRadius: 24)
                .stroke(
                    isActive 
                        ? benefit.accentColor.opacity(0.3)
                        : Color.clear,
                    lineWidth: 2
                )
        )
        .animation(.spring(response: 0.6, dampingFraction: 0.8), value: isActive)
    }
}

#Preview {
    BenefitsCarouselView()
        .environmentObject(ThemeManager())
        .environmentObject(OnboardingManager())
}