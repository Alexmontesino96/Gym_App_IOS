//
//  OnboardingSliderView.swift
//  Gym_API
//
//  Carrusel de 5 slides de onboarding con hero illustrations
//  Train · Pulse · Feed · Chat · Plan
//

import SwiftUI

// MARK: - Slide Model

struct OnboardingSlide: Identifiable {
    let id: String
    let eyebrow: String
    let title: String
    let subtitle: String
    let accent: Color
    let accentInk: Color
    let glowColor: Color
}

private struct SlideLayoutMetrics {
    let heroOffsetY: CGFloat
    let copyGap: CGFloat
}

private let slides: [OnboardingSlide] = [
    OnboardingSlide(
        id: "train",
        eyebrow: "01 · TRAIN",
        title: "Book it,\nshow up, repeat",
        subtitle: "Your favorite class in one tap. QR check-in and a streak that holds.",
        accent: Color(hex: "#D4FF3F") ?? .green,
        accentInk: Color(hex: "#0A0A0A") ?? .black,
        glowColor: Color(hex: "#D4FF3F") ?? .green
    ),
    OnboardingSlide(
        id: "pulse",
        eyebrow: "02 · FEEL",
        title: "See who is\nthere right now",
        subtitle: "Pulse Hub: your gym in real time. See which classes are full and when to go.",
        accent: Color(hex: "#A78BFA") ?? .purple,
        accentInk: .white,
        glowColor: Color(hex: "#A78BFA") ?? .purple
    ),
    OnboardingSlide(
        id: "feed",
        eyebrow: "03 · SHARE",
        title: "Your progress\nhas an audience",
        subtitle: "Stories and posts inside your gym. No internet strangers, just your people.",
        accent: Color(hex: "#F472B6") ?? .pink,
        accentInk: .white,
        glowColor: Color(hex: "#F472B6") ?? .pink
    ),
    OnboardingSlide(
        id: "chat",
        eyebrow: "04 · TALK",
        title: "Your crew,\nalways close",
        subtitle: "Chat with your class group, your coach or the team. No phone numbers needed.",
        accent: Color(hex: "#60A5FA") ?? .blue,
        accentInk: .white,
        glowColor: Color(hex: "#60A5FA") ?? .blue
    ),
    OnboardingSlide(
        id: "plan",
        eyebrow: "05 · GROW",
        title: "A coach\nwho shows up",
        subtitle: "Live plans with your assigned trainer. Small groups, real attention.",
        accent: Color(hex: "#FF5A1F") ?? .orange,
        accentInk: .white,
        glowColor: Color(hex: "#FF5A1F") ?? .orange
    ),
]

// MARK: - Main View

struct OnboardingSliderView: View {
    var onFinish: () -> Void
    var onSkip: () -> Void

    @State private var currentIndex = 0
    @GestureState private var dragOffset: CGFloat = 0

    private var slide: OnboardingSlide { slides[currentIndex] }
    private var isLast: Bool { currentIndex == slides.count - 1 }

    var body: some View {
        GeometryReader { geo in
            let safeTop = geo.safeAreaInsets.top
            let safeBottom = geo.safeAreaInsets.bottom
            let heroHeight: CGFloat = geo.size.height >= 780 ? 320 : 300
            let bottomControlsInset = max(28, safeBottom + 12)
            let swipeTop = safeTop + 12
            let swipeBottomInset = bottomControlsInset + 72
            let swipeHeight = max(0, geo.size.height - swipeTop - swipeBottomInset)

            ZStack(alignment: .topLeading) {
                AuthDesign.bg.ignoresSafeArea()

                Circle()
                    .fill(
                        RadialGradient(
                            colors: [slide.glowColor.opacity(0.22), .clear],
                            center: .center,
                            startRadius: 0,
                            endRadius: 270
                        )
                    )
                    .frame(width: 540, height: 540)
                    .blur(radius: 40)
                    .position(x: geo.size.width / 2, y: 120)
                    .animation(.easeInOut(duration: 0.6), value: currentIndex)
                    .allowsHitTesting(false)

                topControls
                    .padding(.top, max(0, safeTop - 2))
                    .frame(width: geo.size.width, alignment: .topLeading)
                    .zIndex(2)

                HStack(spacing: 0) {
                    ForEach(Array(slides.enumerated()), id: \.element.id) { _, slideItem in
                        slidePage(for: slideItem, pageWidth: geo.size.width, pageHeight: swipeHeight, heroHeight: heroHeight)
                    }
                }
                .offset(x: -CGFloat(currentIndex) * geo.size.width + dragOffset)
                .animation(.interactiveSpring(response: 0.4, dampingFraction: 0.8), value: currentIndex)
                .gesture(
                    DragGesture()
                        .updating($dragOffset) { value, state, _ in
                            state = value.translation.width
                        }
                        .onEnded { value in
                            let threshold: CGFloat = 60
                            if value.translation.width < -threshold && currentIndex < slides.count - 1 {
                                currentIndex += 1
                            } else if value.translation.width > threshold && currentIndex > 0 {
                                currentIndex -= 1
                            }
                        }
                )
                .frame(width: geo.size.width, height: swipeHeight, alignment: .topLeading)
                .clipped()
                .offset(y: swipeTop)

                bottomControls
                    .padding(.bottom, bottomControlsInset)
                    .frame(width: geo.size.width, height: geo.size.height, alignment: .bottom)

                if isLast {
                    (
                        Text("+ 2,400")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(AuthDesign.ink2)
                        +
                        Text(" active members near you")
                            .font(.system(size: 11, weight: .regular))
                            .foregroundColor(AuthDesign.ink3)
                    )
                    .frame(width: geo.size.width, height: geo.size.height, alignment: .bottom)
                    .padding(.bottom, bottomControlsInset + 64)
                    .transition(.opacity)
                }
            }
        }
        .preferredColorScheme(.dark)
    }

    private func slidePage(for slideItem: OnboardingSlide, pageWidth: CGFloat, pageHeight: CGFloat, heroHeight: CGFloat) -> some View {
        let layout = layoutMetrics(for: slideItem)

        return ZStack(alignment: .topLeading) {
            heroIllustration(for: slideItem)
                .frame(width: pageWidth - 32, height: heroHeight)
                .offset(x: 16, y: layout.heroOffsetY)

            VStack(alignment: .leading, spacing: 0) {
                Text(slideItem.eyebrow)
                    .font(.system(size: 10, weight: .bold))
                    .tracking(2.2)
                    .foregroundColor(slideItem.accent)
                    .padding(.bottom, 12)

                Text(slideItem.title)
                    .font(.system(size: 36, weight: .bold))
                    .tracking(-1.44)
                    .lineSpacing(-4)
                    .foregroundColor(AuthDesign.ink)
                    .padding(.bottom, 14)

                Text(slideItem.subtitle)
                    .font(.system(size: 15, weight: .regular))
                    .lineSpacing(3)
                    .foregroundColor(AuthDesign.ink2)
                    .frame(maxWidth: 320, alignment: .leading)
            }
            .padding(.horizontal, 28)
            .frame(width: pageWidth, alignment: .leading)
            .offset(y: heroHeight + layout.copyGap)
        }
        .frame(width: pageWidth, height: pageHeight, alignment: .topLeading)
    }

    private func layoutMetrics(for slideItem: OnboardingSlide) -> SlideLayoutMetrics {
        switch slideItem.id {
        case "pulse":
            return SlideLayoutMetrics(heroOffsetY: -4, copyGap: 14)
        case "feed":
            return SlideLayoutMetrics(heroOffsetY: -1, copyGap: 18)
        case "chat":
            return SlideLayoutMetrics(heroOffsetY: -5, copyGap: 10)
        case "plan":
            return SlideLayoutMetrics(heroOffsetY: -4, copyGap: 10)
        default:
            return SlideLayoutMetrics(heroOffsetY: -6, copyGap: 8)
        }
    }

    // MARK: - Top Controls

    private var topControls: some View {
        HStack {
            // Dots
            HStack(spacing: 6) {
                ForEach(Array(slides.enumerated()), id: \.element.id) { index, _ in
                    Capsule()
                        .fill(index == currentIndex ? slide.accent : AuthDesign.surface2)
                        .frame(width: index == currentIndex ? 24 : 8, height: 4)
                        .animation(.spring(response: 0.35, dampingFraction: 0.7), value: currentIndex)
                }
            }

            Spacer()

            // Skip button
            if !isLast {
                Button(action: onSkip) {
                    Text("Skip")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(AuthDesign.ink3)
                        .padding(.vertical, 6)
                        .padding(.horizontal, 4)
                }
            }
        }
        .padding(.horizontal, 24)
    }

    // MARK: - Bottom Controls

    private var bottomControls: some View {
        HStack(spacing: 12) {
            // Back button (only if not first)
            if currentIndex > 0 {
                Button(action: { currentIndex -= 1 }) {
                    Image(systemName: "arrow.left")
                        .font(.system(size: 18, weight: .medium))
                        .foregroundColor(AuthDesign.ink)
                        .frame(width: 52, height: 52)
                        .background(
                            Circle()
                                .fill(AuthDesign.surface)
                                .overlay(Circle().stroke(AuthDesign.border, lineWidth: 1))
                        )
                }
                .transition(.scale.combined(with: .opacity))
            }

            // CTA button
            Button(action: {
                if isLast {
                    onFinish()
                } else {
                    currentIndex += 1
                }
            }) {
                HStack(spacing: 8) {
                    Text(isLast ? "Empezar ahora" : "Siguiente")
                        .font(.system(size: 15, weight: .bold))
                        .tracking(-0.15)
                    Image(systemName: "arrow.right")
                        .font(.system(size: 16, weight: .medium))
                }
                .foregroundColor(slide.accentInk)
                .frame(maxWidth: .infinity)
                .frame(height: 52)
                .background(
                    Capsule()
                        .fill(slide.accent)
                        .shadow(color: slide.accent.opacity(0.4), radius: 15, y: 6)
                )
            }
            .animation(.easeInOut(duration: 0.3), value: currentIndex)
        }
        .padding(.horizontal, 24)
        .animation(.spring(response: 0.3, dampingFraction: 0.8), value: currentIndex)
    }

    // MARK: - Hero Illustrations

    @ViewBuilder
    private func heroIllustration(for slideItem: OnboardingSlide) -> some View {
        switch slideItem.id {
        case "train": heroTrain
        case "pulse": heroPulse
        case "feed": heroFeed
        case "chat": heroChat
        case "plan": heroPlan
        default: EmptyView()
        }
    }

    // MARK: Hero - Train
    private var heroTrain: some View {
        GeometryReader { geo in
            let mainCardWidth = geo.size.width - 16
            let sideCardX = geo.size.width - 170

            ZStack(alignment: .topLeading) {
                RoundedRectangle(cornerRadius: 16)
                    .fill(AuthDesign.surface)
                    .overlay(RoundedRectangle(cornerRadius: 16).stroke(AuthDesign.border, lineWidth: 1))
                    .frame(width: 200, height: 80)
                    .overlay(
                        HStack(spacing: 10) {
                            VStack(spacing: 2) {
                                Text("19")
                                    .font(.system(size: 9, weight: .semibold))
                                    .foregroundColor(AuthDesign.ink3)
                                Text("30")
                                    .font(.system(size: 13, weight: .bold, design: .monospaced))
                                    .foregroundColor(AuthDesign.ink)
                            }
                            .padding(.vertical, 6)
                            .frame(width: 44)
                            .background(RoundedRectangle(cornerRadius: 10).fill(AuthDesign.surface2))

                            VStack(alignment: .leading, spacing: 2) {
                                Text("Total Strength")
                                    .font(.system(size: 12, weight: .semibold))
                                    .foregroundColor(AuthDesign.ink)
                                Text("Jordan P. · 60 min")
                                    .font(.system(size: 10, weight: .regular))
                                    .foregroundColor(AuthDesign.ink3)
                            }

                            Spacer(minLength: 0)
                        }
                        .padding(12)
                    )
                    .rotationEffect(.degrees(6))
                    .offset(x: sideCardX, y: 60)

                RoundedRectangle(cornerRadius: 22)
                    .fill(
                        LinearGradient(
                            colors: [Color(hex: "#D4FF3F") ?? .green, Color(hex: "#B5E54A") ?? .green],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: mainCardWidth, height: 190)
                    .overlay(alignment: .topTrailing) {
                        Circle()
                            .fill(
                                RadialGradient(
                                    colors: [Color.black.opacity(0.08), .clear],
                                    center: .center,
                                    startRadius: 0,
                                    endRadius: 70
                                )
                            )
                            .frame(width: 140, height: 140)
                            .offset(x: 40, y: -40)
                    }
                    .overlay(alignment: .topLeading) {
                        VStack(alignment: .leading, spacing: 0) {
                            HStack(spacing: 6) {
                                Circle()
                                    .fill(Color(hex: "#0A0A0A") ?? .black)
                                    .frame(width: 6, height: 6)
                                Text("LIVE")
                                    .font(.system(size: 9, weight: .heavy))
                                    .tracking(1.44)
                                Spacer()
                                Text("TODAY")
                                    .font(.system(size: 10, weight: .semibold))
                                    .opacity(0.6)
                            }
                            .foregroundColor(Color(hex: "#0A0A0A") ?? .black)
                            .padding(.bottom, 14)

                            Text("Functional HIIT")
                                .font(.system(size: 24, weight: .bold))
                                .tracking(-0.72)
                                .foregroundColor(Color(hex: "#0A0A0A") ?? .black)
                                .padding(.bottom, 4)

                            Text("6:30 PM · Casey R. · Studio 2")
                                .font(.system(size: 11, weight: .medium))
                                .foregroundColor(Color(hex: "#0A0A0A") ?? .black)
                                .opacity(0.75)
                                .padding(.bottom, 14)

                            Spacer(minLength: 0)

                            HStack(alignment: .center) {
                                HStack(spacing: -8) {
                                    ForEach(Array(["#FF5A1F", "#A78BFA", "#3B82F6"].enumerated()), id: \.offset) { i, hex in
                                        Circle()
                                            .fill(Color(hex: hex) ?? .gray)
                                            .frame(width: 22, height: 22)
                                            .overlay(
                                                Text(["JL", "MR", "DV"][i])
                                                    .font(.system(size: 9, weight: .bold))
                                                    .foregroundColor(.white)
                                            )
                                            .overlay(Circle().stroke(Color(hex: "#D4FF3F") ?? .green, lineWidth: 2))
                                    }

                                    Text("+9")
                                        .font(.system(size: 9, weight: .bold))
                                        .foregroundColor(Color(hex: "#D4FF3F") ?? .green)
                                        .padding(.horizontal, 7)
                                        .frame(height: 22)
                                        .background(Capsule().fill(Color.black.opacity(0.85)))
                                }

                                Spacer(minLength: 12)

                                HStack(spacing: 4) {
                                    Image(systemName: "qrcode")
                                        .font(.system(size: 11, weight: .medium))
                                    Text("Check-in")
                                        .font(.system(size: 10, weight: .bold))
                                }
                                .foregroundColor(Color(hex: "#D4FF3F") ?? .green)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 6)
                                .background(Capsule().fill(Color.black.opacity(0.85)))
                            }
                        }
                        .padding(18)
                    }
                    .clipShape(RoundedRectangle(cornerRadius: 22))
                    .rotationEffect(.degrees(-3))
                    .shadow(color: .black.opacity(0.5), radius: 30, y: 15)
                    .shadow(color: Color(hex: "#D4FF3F")?.opacity(0.25) ?? .clear, radius: 20)
                    .offset(x: 8, y: 12)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .overlay(alignment: .bottomLeading) {
                HStack(spacing: 8) {
                    Circle()
                        .fill(Color(hex: "#FF5A1F")?.opacity(0.16) ?? .clear)
                        .frame(width: 24, height: 24)
                        .overlay(
                            Image(systemName: "flame.fill")
                                .font(.system(size: 13, weight: .medium))
                                .foregroundColor(Color(hex: "#FF5A1F") ?? .orange)
                        )

                    VStack(alignment: .leading, spacing: 1) {
                        Text("STREAK")
                            .font(.system(size: 9, weight: .semibold))
                            .tracking(0.54)
                            .foregroundColor(AuthDesign.ink3)
                        Text("12 days")
                            .font(.system(size: 14, weight: .bold, design: .monospaced))
                            .foregroundColor(AuthDesign.ink)
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(
                    Capsule()
                        .fill(AuthDesign.surface)
                        .overlay(Capsule().stroke(AuthDesign.border, lineWidth: 1))
                        .shadow(color: .black.opacity(0.3), radius: 8, y: 4)
                )
                .padding(.leading, 16)
                .padding(.bottom, 30)
            }
        }
    }

    // MARK: Hero - Pulse
    private var heroPulse: some View {
        GeometryReader { geo in
            let peeps: [(x: CGFloat, y: CGFloat, size: CGFloat, start: String, end: String, initials: String)] = [
                (40, 6, 38, "#FF5A1F", "#FFB347", "MR"),
                (112, 0, 54, "#A78BFA", "#60A5FA", "CR"),
                (198, 14, 44, "#4ADE80", "#D4FF3F", "JL"),
                (262, 52, 38, "#F472B6", "#FB7185", "NV"),
                (20, 78, 42, "#60A5FA", "#818CF8", "DK"),
                (92, 94, 48, "#FBBF24", "#FF8A4C", "SA"),
                (200, 98, 50, "#34D399", "#60A5FA", "TM"),
            ]
            let counterY = geo.size.height - 164
            let pillY = geo.size.height - 60

            ZStack(alignment: .topLeading) {
                ForEach(Array(peeps.enumerated()), id: \.offset) { _, peep in
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [Color(hex: peep.start) ?? .gray, Color(hex: peep.end) ?? .gray],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: peep.size, height: peep.size)
                        .overlay(
                            Text(peep.initials)
                                .font(.system(size: peep.size * 0.32, weight: .bold))
                                .foregroundColor(.white)
                        )
                        .overlay(Circle().stroke(AuthDesign.bg, lineWidth: 3))
                        .shadow(color: .black.opacity(0.4), radius: 8, y: 4)
                        .offset(x: peep.x, y: peep.y)
                }

                Circle()
                    .fill(Color(hex: "#A78BFA") ?? .purple)
                    .frame(width: 14, height: 14)
                    .overlay(Circle().stroke(AuthDesign.bg, lineWidth: 3))
                    .offset(x: 148, y: 38)

                RoundedRectangle(cornerRadius: 20)
                    .fill(AuthDesign.surface)
                    .overlay(RoundedRectangle(cornerRadius: 20).stroke(AuthDesign.border, lineWidth: 1))
                    .frame(width: geo.size.width - 24, height: 100)
                    .overlay(
                        HStack {
                            VStack(alignment: .leading, spacing: 0) {
                                HStack(spacing: 6) {
                                    Circle()
                                        .fill(Color(hex: "#A78BFA") ?? .purple)
                                        .frame(width: 6, height: 6)
                                    Text("LIVE")
                                        .font(.system(size: 10, weight: .bold))
                                        .tracking(1.6)
                                        .foregroundColor(Color(hex: "#A78BFA") ?? .purple)
                                }
                                .padding(.bottom, 6)

                                Text("847")
                                    .font(.system(size: 38, weight: .bold))
                                    .tracking(-1.52)
                                    .foregroundColor(AuthDesign.ink)

                                Text("training now")
                                    .font(.system(size: 12, weight: .regular))
                                    .foregroundColor(AuthDesign.ink3)
                                    .padding(.top, 4)
                            }

                            Spacer(minLength: 16)

                            HStack(alignment: .bottom, spacing: 4) {
                                ForEach(Array([0.4, 0.6, 0.3, 0.7, 0.5, 0.85, 0.65].enumerated()), id: \.offset) { i, value in
                                    RoundedRectangle(cornerRadius: 3)
                                        .fill(i == 5 ? Color(hex: "#A78BFA") ?? .purple : AuthDesign.surface2)
                                        .frame(width: 6, height: CGFloat(value) * 50)
                                }
                            }
                            .frame(height: 50)
                        }
                        .padding(18)
                    )
                    .shadow(color: .black.opacity(0.3), radius: 16, y: 8)
                    .offset(x: 12, y: counterY)

                HStack(spacing: 8) {
                    RoundedRectangle(cornerRadius: 7)
                        .fill(Color(hex: "#FF5A1F") ?? .orange)
                        .frame(width: 22, height: 22)
                        .overlay(
                            Image(systemName: "flame.fill")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(.white)
                        )

                    (
                        Text("Spin Power · ")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(AuthDesign.ink)
                        +
                        Text("full 18/18")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(Color(hex: "#FF5A1F") ?? .orange)
                    )

                    Spacer(minLength: 8)

                    Text("2m")
                        .font(.system(size: 10, weight: .regular, design: .monospaced))
                        .foregroundColor(AuthDesign.ink3)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .frame(width: geo.size.width - 44)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color(hex: "#FF5A1F")?.opacity(0.12) ?? .clear)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Color(hex: "#FF5A1F")?.opacity(0.32) ?? .clear, lineWidth: 1)
                        )
                )
                .offset(x: 22, y: pillY)
            }
        }
    }

    // MARK: Hero - Feed
    private var heroFeed: some View {
        GeometryReader { geo in
            let stories: [(label: String, initials: String, start: String, end: String, isNew: Bool)] = [
                ("You", "+", "#FF5A1F", "#F472B6", true),
                ("Casey", "CR", "#A78BFA", "#60A5FA", true),
                ("Maya", "MR", "#FF5A1F", "#FFB347", true),
                ("Jamie", "JL", "#4ADE80", "#D4FF3F", false),
                ("Nora", "NV", "#F472B6", "#FB7185", true),
            ]
            let cardWidth = geo.size.width - 16
            let cardTop: CGFloat = geo.size.height >= 320 ? 78 : 72
            let cardHeight = geo.size.height - cardTop - 12
            let mediaHeight = max(94, min(116, cardHeight - 118))
            let reactionBottomInset = max(32, cardHeight * 0.15)

            ZStack(alignment: .topLeading) {
                HStack(spacing: 10) {
                    ForEach(Array(stories.enumerated()), id: \.offset) { _, story in
                        VStack(spacing: 4) {
                            Circle()
                                .stroke(
                                    story.isNew ?
                                    AngularGradient(
                                        colors: [
                                            Color(hex: "#F472B6") ?? .pink,
                                            Color(hex: "#FF5A1F") ?? .orange,
                                            Color(hex: "#D4FF3F") ?? .green,
                                            Color(hex: "#60A5FA") ?? .blue,
                                            Color(hex: "#F472B6") ?? .pink
                                        ],
                                        center: .center
                                    ) :
                                    AngularGradient(colors: [AuthDesign.surface2, AuthDesign.surface2], center: .center),
                                    lineWidth: 2.5
                                )
                                .frame(width: 52, height: 52)
                                .overlay(
                                    Circle()
                                        .fill(
                                            LinearGradient(
                                                colors: [Color(hex: story.start) ?? .gray, Color(hex: story.end) ?? .gray],
                                                startPoint: .topLeading,
                                                endPoint: .bottomTrailing
                                            )
                                        )
                                        .padding(4)
                                        .overlay(
                                            Text(story.initials)
                                                .font(.system(size: 17, weight: .bold))
                                                .foregroundColor(.white)
                                        )
                                )

                            Text(story.label)
                                .font(.system(size: 9, weight: .medium))
                                .foregroundColor(AuthDesign.ink3)
                        }
                    }
                }
                .frame(width: geo.size.width - 16, alignment: .leading)
                .offset(x: 8, y: 4)

                VStack(alignment: .leading, spacing: 0) {
                    HStack(spacing: 10) {
                        Circle()
                            .fill(
                                LinearGradient(
                                    colors: [Color(hex: "#FF5A1F") ?? .orange, Color(hex: "#FFB347") ?? .yellow],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: 34, height: 34)
                            .overlay(
                                Text("MR")
                                    .font(.system(size: 12, weight: .bold))
                                    .foregroundColor(.white)
                            )

                        VStack(alignment: .leading, spacing: 1) {
                            Text("Maya Rivers")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundColor(AuthDesign.ink)
                            Text("2h ago · Functional HIIT 🔥")
                                .font(.system(size: 10, weight: .regular))
                                .foregroundColor(AuthDesign.ink3)
                        }

                        Spacer(minLength: 0)

                        Text("···")
                            .font(.system(size: 16, weight: .medium))
                            .tracking(1)
                            .foregroundColor(AuthDesign.ink3)
                    }
                    .padding(.horizontal, 12)
                    .padding(.top, 12)
                    .padding(.bottom, 8)

                    ZStack(alignment: .topLeading) {
                        LinearGradient(
                            colors: [Color(hex: "#F472B6") ?? .pink, Color(hex: "#A78BFA") ?? .purple, Color(hex: "#60A5FA") ?? .blue],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                        .frame(height: mediaHeight)
                        .overlay(
                            Rectangle()
                                .fill(
                                    RadialGradient(
                                        colors: [Color.white.opacity(0.25), .clear],
                                        center: UnitPoint(x: 0.3, y: 0.3),
                                        startRadius: 0,
                                        endRadius: 120
                                    )
                                )
                        )

                        HStack(spacing: 5) {
                            Image(systemName: "star.fill")
                                .font(.system(size: 11, weight: .medium))
                            Text("PR · 210 LB")
                                .font(.system(size: 10, weight: .heavy))
                                .tracking(1.0)
                        }
                        .foregroundColor(Color(hex: "#D4FF3F") ?? .green)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(Capsule().fill(Color.black.opacity(0.85)))
                        .padding(10)
                    }
                    .clipped()

                    HStack(spacing: 14) {
                        HStack(spacing: 5) {
                            Image(systemName: "heart.fill")
                                .font(.system(size: 16, weight: .medium))
                                .foregroundColor(Color(hex: "#F472B6") ?? .pink)
                            Text("42")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundColor(AuthDesign.ink)
                        }

                        HStack(spacing: 5) {
                            Image(systemName: "bubble.left")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(AuthDesign.ink2)
                            Text("8")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundColor(AuthDesign.ink)
                        }
                    }
                    .padding(.horizontal, 12)
                    .padding(.top, 10)
                    .padding(.bottom, 8)

                    (
                        Text("maya_rivers")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(AuthDesign.ink)
                        +
                        Text(" New deadlift PR 💪 Thanks coach!")
                            .font(.system(size: 12, weight: .regular))
                            .foregroundColor(AuthDesign.ink2)
                    )
                    .padding(.horizontal, 12)
                    .padding(.bottom, 12)
                    .lineLimit(1)
                    .minimumScaleFactor(0.9)
                    .lineSpacing(2)
                }
                .frame(width: cardWidth, height: cardHeight, alignment: .topLeading)
                .background(AuthDesign.surface)
                .clipShape(RoundedRectangle(cornerRadius: 20))
                .overlay(RoundedRectangle(cornerRadius: 20).stroke(AuthDesign.border, lineWidth: 1))
                .overlay(alignment: .bottomTrailing) {
                    HStack(spacing: 6) {
                        Circle()
                            .fill(
                                LinearGradient(
                                    colors: [Color(hex: "#A78BFA") ?? .purple, Color(hex: "#60A5FA") ?? .blue],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: 24, height: 24)
                            .overlay(
                                Text("CR")
                                    .font(.system(size: 10, weight: .bold))
                                    .foregroundColor(.white)
                            )

                        (
                            Text("Casey")
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundColor(AuthDesign.ink)
                            +
                            Text(" reacted 🔥")
                                .font(.system(size: 11, weight: .regular))
                                .foregroundColor(AuthDesign.ink2)
                        )
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(
                        Capsule()
                            .fill(AuthDesign.surface)
                            .overlay(Capsule().stroke(AuthDesign.border, lineWidth: 1))
                            .shadow(color: .black.opacity(0.3), radius: 8, y: 4)
                    )
                    .padding(.trailing, 16)
                    .padding(.bottom, reactionBottomInset)
                }
                .rotationEffect(.degrees(-1.5))
                .shadow(color: .black.opacity(0.5), radius: 30, y: 15)
                .shadow(color: Color(hex: "#F472B6")?.opacity(0.18) ?? .clear, radius: 20)
                .offset(x: 8, y: cardTop)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
    }

    // MARK: Hero - Chat
    private var heroChat: some View {
        GeometryReader { geo in
            ZStack(alignment: .topLeading) {
                VStack(spacing: 0) {
                    HStack {
                        Text("Chats")
                            .font(.system(size: 16, weight: .bold))
                            .tracking(-0.32)
                            .foregroundColor(AuthDesign.ink)

                        Spacer()

                        Text("4 new")
                            .font(.system(size: 10, weight: .bold, design: .monospaced))
                            .foregroundColor(.white)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(Capsule().fill(Color(hex: "#60A5FA") ?? .blue))
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 12)

                    Divider().background(AuthDesign.border)

                    chatRow(
                        symbol: "person.3.fill",
                        name: "Functional HIIT · Wed",
                        last: "Casey: Kettlebells tomorrow 💪",
                        time: "12:42",
                        unread: 3,
                        isGroup: true,
                        startColor: Color(hex: "#FF5A1F") ?? .orange,
                        endColor: Color(hex: "#FFB347") ?? .yellow
                    )

                    Divider().background(AuthDesign.border)

                    chatRow(
                        initials: "CR",
                        name: "Casey Rivera",
                        last: "Your plan is ready!",
                        time: "11:18",
                        unread: 1,
                        online: true,
                        startColor: Color(hex: "#A78BFA") ?? .purple,
                        endColor: Color(hex: "#60A5FA") ?? .blue
                    )

                    Divider().background(AuthDesign.border)

                    chatRow(
                        initials: "GF",
                        name: "GymFlow · Announcements",
                        last: "New class: Mobility 360",
                        time: "Yesterday",
                        unread: 0,
                        official: true,
                        startColor: Color(hex: "#D4FF3F") ?? .green,
                        endColor: Color(hex: "#4ADE80") ?? .green
                    )
                }
                .frame(width: geo.size.width - 16, alignment: .topLeading)
                .background(AuthDesign.surface)
                .clipShape(RoundedRectangle(cornerRadius: 22))
                .overlay(RoundedRectangle(cornerRadius: 22).stroke(AuthDesign.border, lineWidth: 1))
                .rotationEffect(.degrees(-1.5))
                .shadow(color: .black.opacity(0.5), radius: 30, y: 15)
                .shadow(color: Color(hex: "#60A5FA")?.opacity(0.18) ?? .clear, radius: 20)
                .offset(x: 8, y: 14)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .overlay(alignment: .bottomTrailing) {
                VStack(alignment: .trailing, spacing: 4) {
                    Text("Coming to HIIT today? 👀")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(
                            UnevenRoundedRectangle(
                                topLeadingRadius: 16,
                                bottomLeadingRadius: 16,
                                bottomTrailingRadius: 4,
                                topTrailingRadius: 16
                            )
                            .fill(Color(hex: "#60A5FA") ?? .blue)
                            .shadow(color: Color(hex: "#60A5FA")?.opacity(0.5) ?? .clear, radius: 12, y: 4)
                        )

                    Text("Casey · now")
                        .font(.system(size: 9, weight: .regular, design: .monospaced))
                        .foregroundColor(AuthDesign.ink3)
                }
                .padding(.trailing, 14)
                .padding(.bottom, 18)
            }
            .overlay(alignment: .bottomLeading) {
                HStack(spacing: 8) {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [Color(hex: "#4ADE80") ?? .green, Color(hex: "#D4FF3F") ?? .green],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 22, height: 22)
                        .overlay(
                            Text("JL")
                                .font(.system(size: 9, weight: .bold))
                                .foregroundColor(Color(hex: "#0A0A0A") ?? .black)
                        )

                    Text("typing ···")
                        .font(.system(size: 10, weight: .regular))
                        .foregroundColor(AuthDesign.ink2)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(
                    Capsule()
                        .fill(AuthDesign.surface)
                        .overlay(Capsule().stroke(AuthDesign.border, lineWidth: 1))
                        .shadow(color: .black.opacity(0.3), radius: 8, y: 4)
                )
                .padding(.leading, 18)
                .padding(.bottom, 22)
            }
        }
    }

    // MARK: Hero - Plan
    private var heroPlan: some View {
        GeometryReader { geo in
            let mainCardWidth = geo.size.width - 44
            let sideCardX = geo.size.width - 160

            ZStack(alignment: .topLeading) {
                RoundedRectangle(cornerRadius: 16)
                    .fill(AuthDesign.surface)
                    .overlay(RoundedRectangle(cornerRadius: 16).stroke(AuthDesign.border, lineWidth: 1))
                    .frame(width: 180, height: 96)
                    .overlay(
                        VStack(alignment: .leading, spacing: 0) {
                            RoundedRectangle(cornerRadius: 8)
                                .fill(
                                    LinearGradient(
                                        colors: [Color(hex: "#4ADE80") ?? .green, Color(hex: "#D4FF3F") ?? .green],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                                .frame(height: 40)
                                .padding(.bottom, 8)
                            Text("Veggie Endurance")
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundColor(AuthDesign.ink)
                            Text("Lucia T. · 30 days")
                                .font(.system(size: 9, weight: .regular))
                                .foregroundColor(AuthDesign.ink3)
                                .padding(.top, 2)
                        }
                        .padding(12)
                    )
                    .rotationEffect(.degrees(5))
                    .offset(x: sideCardX, y: 90)

                RoundedRectangle(cornerRadius: 22)
                    .fill(AuthDesign.surface)
                    .frame(width: mainCardWidth, height: 230)
                    .overlay(alignment: .topLeading) {
                        VStack(alignment: .leading, spacing: 0) {
                            ZStack(alignment: .topLeading) {
                                LinearGradient(
                                    colors: [
                                        Color(hex: "#FF5A1F") ?? .orange,
                                        Color(hex: "#FFB347") ?? .yellow,
                                        Color(red: 0.98, green: 0.98, blue: 0.97)
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                                .frame(height: 80)

                                HStack(spacing: 5) {
                                    Circle()
                                        .fill(Color(hex: "#FFB347") ?? .yellow)
                                        .frame(width: 4, height: 4)
                                    Text("LIVE · 47 ON PLAN")
                                        .font(.system(size: 8, weight: .heavy))
                                        .tracking(0.8)
                                }
                                .foregroundColor(Color(hex: "#FFB347") ?? .yellow)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Capsule().fill(Color.black.opacity(0.85)))
                                .padding(12)

                                Circle()
                                    .fill(
                                        LinearGradient(
                                            colors: [Color(hex: "#A78BFA") ?? .purple, Color(hex: "#60A5FA") ?? .blue],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        )
                                    )
                                    .frame(width: 50, height: 50)
                                    .overlay(
                                        Text("CR")
                                            .font(.system(size: 16, weight: .bold))
                                            .foregroundColor(.white)
                                    )
                                    .overlay(Circle().stroke(AuthDesign.surface, lineWidth: 3))
                                    .offset(x: mainCardWidth - 64, y: 58)
                            }
                            .frame(height: 80)

                            VStack(alignment: .leading, spacing: 0) {
                                Text("Macro Cut")
                                    .font(.system(size: 19, weight: .bold))
                                    .tracking(-0.475)
                                    .foregroundColor(AuthDesign.ink)
                                    .padding(.bottom, 2)

                                Text("Casey R. · Nutrition")
                                    .font(.system(size: 11, weight: .regular))
                                    .foregroundColor(AuthDesign.ink3)
                                    .padding(.bottom, 12)

                                HStack(alignment: .lastTextBaseline) {
                                    Text("DAY 12 / 28")
                                        .font(.system(size: 10, weight: .bold))
                                        .tracking(1.0)
                                        .foregroundColor(AuthDesign.ink3)
                                    Spacer()
                                    Text("43%")
                                        .font(.system(size: 10, weight: .semibold, design: .monospaced))
                                        .foregroundColor(AuthDesign.ink2)
                                }
                                .padding(.bottom, 6)

                                GeometryReader { progressGeo in
                                    RoundedRectangle(cornerRadius: 100)
                                        .fill(AuthDesign.surface2)
                                        .frame(height: 4)
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 100)
                                                .fill(
                                                    LinearGradient(
                                                        colors: [Color(hex: "#FF5A1F") ?? .orange, Color(hex: "#FFB347") ?? .yellow],
                                                        startPoint: .leading,
                                                        endPoint: .trailing
                                                    )
                                                )
                                                .frame(width: progressGeo.size.width * 0.43)
                                            , alignment: .leading
                                        )
                                }
                                .frame(height: 4)

                                HStack(spacing: 8) {
                                    ForEach(Array([("PROT", "140g"), ("CARB", "180g"), ("GRA", "60g")].enumerated()), id: \.offset) { _, macro in
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text(macro.0)
                                                .font(.system(size: 8, weight: .bold))
                                                .tracking(0.8)
                                                .foregroundColor(AuthDesign.ink3)
                                            Text(macro.1)
                                                .font(.system(size: 13, weight: .bold, design: .monospaced))
                                                .foregroundColor(AuthDesign.ink)
                                        }
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                    }
                                }
                                .padding(.top, 14)
                            }
                            .padding(.horizontal, 14)
                            .padding(.top, 12)
                        }
                    }
                    .clipShape(RoundedRectangle(cornerRadius: 22))
                    .overlay(RoundedRectangle(cornerRadius: 22).stroke(AuthDesign.border, lineWidth: 1))
                    .rotationEffect(.degrees(-2))
                    .shadow(color: .black.opacity(0.5), radius: 30, y: 15)
                    .shadow(color: Color(hex: "#FF5A1F")?.opacity(0.18) ?? .clear, radius: 20)
                    .offset(x: 8, y: 8)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .overlay(alignment: .bottomLeading) {
                HStack(spacing: 8) {
                    HStack(spacing: -7) {
                        ForEach(Array(["#FF5A1F", "#A78BFA", "#4ADE80"].enumerated()), id: \.offset) { _, hex in
                            Circle()
                                .fill(Color(hex: hex) ?? .gray)
                                .frame(width: 20, height: 20)
                                .overlay(Circle().stroke(AuthDesign.surface, lineWidth: 2))
                        }
                    }

                    (
                        Text("47")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(AuthDesign.ink)
                        +
                        Text(" active members")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(AuthDesign.ink2)
                    )
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(
                    Capsule()
                        .fill(AuthDesign.surface)
                        .overlay(Capsule().stroke(AuthDesign.border, lineWidth: 1))
                        .shadow(color: .black.opacity(0.3), radius: 8, y: 4)
                )
                .padding(.leading, 22)
                .padding(.bottom, 18)
            }
        }
    }

    // MARK: - Chat Row Helper

    private func chatRow(initials: String? = nil, symbol: String? = nil, name: String, last: String, time: String, unread: Int, isGroup: Bool = false, online: Bool = false, official: Bool = false, startColor: Color = Color(hex: "#A78BFA") ?? .purple, endColor: Color = Color(hex: "#60A5FA") ?? .blue) -> some View {
        HStack(spacing: 12) {
            // Avatar
            ZStack(alignment: .bottomTrailing) {
                RoundedRectangle(cornerRadius: isGroup ? 12 : 100)
                    .fill(LinearGradient(colors: [startColor, endColor], startPoint: .topLeading, endPoint: .bottomTrailing))
                    .frame(width: 42, height: 42)
                    .overlay(
                        Group {
                            if let symbol {
                                Image(systemName: symbol)
                                    .font(.system(size: 18, weight: .semibold))
                                    .foregroundColor(.white)
                            } else if let initials {
                                Text(initials)
                                    .font(.system(size: isGroup ? 18 : 14, weight: .bold))
                                    .foregroundColor(.white)
                            }
                        }
                    )
                if online {
                    Circle()
                        .fill(Color(hex: "#4ADE80") ?? .green)
                        .frame(width: 11, height: 11)
                        .overlay(Circle().stroke(AuthDesign.surface, lineWidth: 2))
                }
            }

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 5) {
                    Text(name)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(AuthDesign.ink)
                        .lineLimit(1)
                    if official {
                        Image(systemName: "checkmark.seal.fill")
                            .font(.system(size: 12))
                            .foregroundColor(Color(hex: "#60A5FA") ?? .blue)
                    }
                }
                Text(last)
                    .font(.system(size: 11, weight: unread > 0 ? .medium : .regular))
                    .foregroundColor(unread > 0 ? AuthDesign.ink2 : AuthDesign.ink3)
                    .lineLimit(1)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 4) {
                Text(time)
                    .font(.system(size: 10, weight: .semibold, design: .monospaced))
                    .foregroundColor(unread > 0 ? Color(hex: "#60A5FA") ?? .blue : AuthDesign.ink3)
                if unread > 0 {
                    Text("\(unread)")
                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                        .foregroundColor(.white)
                        .frame(minWidth: 18, minHeight: 18)
                        .background(Circle().fill(Color(hex: "#60A5FA") ?? .blue))
                }
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
    }
}

#Preview {
    OnboardingSliderView(onFinish: {}, onSkip: {})
}
