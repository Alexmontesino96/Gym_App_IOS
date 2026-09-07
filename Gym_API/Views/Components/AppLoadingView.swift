import SwiftUI

// MARK: - App Loading View
/// Reusable loading screen matching the splash design — used during auth check,
/// workspace loading, and any transition where the app needs to load data.

struct AppLoadingView: View {
    @EnvironmentObject var themeManager: ThemeManager

    @State private var cachedImage: UIImage?
    @State private var avatarScale: CGFloat = 0.3
    @State private var avatarOpacity: Double = 0
    @State private var greetingOpacity: Double = 0
    @State private var greetingOffset: CGFloat = 20
    @State private var nameOpacity: Double = 0
    @State private var nameOffset: CGFloat = 20
    @State private var phraseIndex = 0
    @State private var phraseOpacity: Double = 0
    @State private var loadingOpacity: Double = 0
    @State private var haloOpacity: Double = 0
    @State private var phraseTimer: Timer?

    // Del tema, no cableado: este es el primer color que ve cualquiera al abrir la app, y
    // seguia lima aunque el usuario hubiera elegido otro acento.
    private var accentColor: Color { Color.dynamicAccent(theme: themeManager.currentTheme) }

    private var greeting: String {
        let hour = Calendar.current.component(.hour, from: Date())
        if hour < 12 { return "Good morning," }
        if hour < 19 { return "Good afternoon," }
        return "Good evening,"
    }

    private var userName: String {
        // Priority: cached profile first name > cached full name > auth0 name > fallback
        if let firstName = UserDefaults.standard.string(forKey: "cached_profile_first_name"), !firstName.isEmpty {
            return firstName
        }
        if let fullName = UserDefaults.standard.string(forKey: "cached_profile_name"), !fullName.isEmpty {
            return fullName.components(separatedBy: " ").first ?? fullName
        }
        if let authName = UserDefaults.standard.string(forKey: "saved_user_name"), !authName.contains("@") {
            return authName.components(separatedBy: " ").first ?? authName
        }
        return "..."
    }

    private var userInitial: String {
        let name = userName
        return name == "..." ? "G" : String(name.prefix(1)).uppercased()
    }

    private let phrases = [
        "Setting things up",
        "Loading your profile",
        "Syncing your data",
        "Getting your space ready",
        "Almost there…",
    ]

    var body: some View {
        ZStack {
            Color.dynamicBackground(theme: themeManager.currentTheme)
                .ignoresSafeArea()

            // Halo
            Circle()
                .fill(
                    RadialGradient(
                        colors: [accentColor.opacity(0.18), .clear],
                        center: .center,
                        startRadius: 0,
                        endRadius: 260
                    )
                )
                .frame(width: 520, height: 520)
                .opacity(haloOpacity)
                .blur(radius: 40)
                .offset(y: -120)

            VStack(spacing: 0) {
                Spacer()

                // Avatar (cached image or gradient fallback)
                Group {
                    if let image = cachedImage {
                        Image(uiImage: image)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: 80, height: 80)
                            .clipShape(Circle())
                    } else {
                        Circle()
                            .fill(
                                accentColor
                            )
                            .frame(width: 80, height: 80)
                            .overlay(
                                Text(userInitial)
                                    .font(.system(size: 30, weight: .bold))
                                    .foregroundColor(ThemeManager.accentInkForCurrentAccent(theme: themeManager.currentTheme))
                            )
                    }
                }
                .shadow(color: .black.opacity(0.3), radius: 16, y: 6)
                .scaleEffect(avatarScale)
                .opacity(avatarOpacity)
                .padding(.bottom, 24)

                // Greeting
                Text(greeting)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(Color.dynamicText(theme: themeManager.currentTheme).opacity(0.45))
                    .opacity(greetingOpacity)
                    .offset(y: greetingOffset)
                    .padding(.bottom, 4)

                // Name
                Text(userName)
                    .font(.system(size: 36, weight: .bold))
                    .tracking(-1.4)
                    .foregroundColor(Color.dynamicText(theme: themeManager.currentTheme))
                    .opacity(nameOpacity)
                    .offset(y: nameOffset)
                    .padding(.bottom, 24)

                // Phrase pill
                HStack(spacing: 8) {
                    Circle()
                        .fill(accentColor)
                        .frame(width: 6, height: 6)

                    Text(phrases[phraseIndex])
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(Color.dynamicText(theme: themeManager.currentTheme).opacity(0.55))
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(Color.dynamicSurface(theme: themeManager.currentTheme))
                .clipShape(Capsule())
                .overlay(Capsule().stroke(Color.white.opacity(0.08), lineWidth: 1))
                .opacity(phraseOpacity)
                .id("loading_phrase_\(phraseIndex)")
                .animation(.easeInOut(duration: 0.3), value: phraseIndex)

                Spacer()

                // Loading bar
                VStack(spacing: 12) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 100)
                            .fill(Color.dynamicText(theme: themeManager.currentTheme).opacity(0.08))
                            .frame(width: 56, height: 3)

                        LoadingSlidingBar(color: accentColor)
                            .frame(width: 56, height: 3)
                            .clipShape(RoundedRectangle(cornerRadius: 100))
                    }

                    Text("Getting your day ready")
                        .font(.system(size: 11, weight: .medium))
                        .tracking(0.3)
                        .foregroundColor(Color.dynamicText(theme: themeManager.currentTheme).opacity(0.3))
                }
                .opacity(loadingOpacity)
                .padding(.bottom, 56)
            }
        }
        .onAppear {
            loadCachedAvatar()
            startAnimations()
        }
        .onDisappear { phraseTimer?.invalidate() }
    }

    private func loadCachedAvatar() {
        // 1. Try disk cache first (instant, no network)
        if let data = try? Data(contentsOf: AppLoadingView.avatarCacheURL),
           let image = UIImage(data: data) {
            cachedImage = image
            return
        }

        // 2. Try downloading from saved URL in background
        if let urlString = UserDefaults.standard.string(forKey: "saved_user_picture"),
           let url = URL(string: urlString) {
            Task {
                if let (data, _) = try? await URLSession.shared.data(from: url),
                   let image = UIImage(data: data) {
                    await MainActor.run { cachedImage = image }
                    // Save to disk for next launch
                    AppLoadingView.saveAvatarToCache(data)
                }
            }
        }
    }

    // MARK: - Static cache helpers (callable from anywhere)

    private static var avatarCacheURL: URL {
        FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("profile_avatar.jpg")
    }

    static func saveAvatarToCache(_ data: Data) {
        try? data.write(to: avatarCacheURL)
    }

    static func saveAvatarFromURL(_ urlString: String) {
        guard let url = URL(string: urlString) else { return }
        Task {
            if let (data, _) = try? await URLSession.shared.data(from: url) {
                saveAvatarToCache(data)
            }
        }
    }

    static func clearCachedAvatar() {
        try? FileManager.default.removeItem(at: avatarCacheURL)
    }

    private func startAnimations() {
        withAnimation(.easeOut(duration: 0.8)) { haloOpacity = 1 }

        withAnimation(.spring(response: 0.5, dampingFraction: 0.6).delay(0.05)) {
            avatarScale = 1.0
            avatarOpacity = 1.0
        }

        withAnimation(.easeOut(duration: 0.4).delay(0.12)) {
            greetingOpacity = 1
            greetingOffset = 0
        }

        withAnimation(.easeOut(duration: 0.4).delay(0.2)) {
            nameOpacity = 1
            nameOffset = 0
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
            withAnimation(.easeOut(duration: 0.3)) { phraseOpacity = 1 }
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
            withAnimation(.easeInOut(duration: 0.3)) { loadingOpacity = 1 }
        }

        phraseTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { _ in
            phraseIndex = (phraseIndex + 1) % phrases.count
        }
    }
}

// MARK: - Loading Sliding Bar

private struct LoadingSlidingBar: View {
    let color: Color
    @State private var offset: CGFloat = -1.0

    var body: some View {
        GeometryReader { geo in
            RoundedRectangle(cornerRadius: 100)
                .fill(color)
                .frame(width: geo.size.width * 0.4)
                .offset(x: geo.size.width * offset)
                .onAppear {
                    withAnimation(
                        .easeInOut(duration: 1.6)
                        .repeatForever(autoreverses: false)
                    ) {
                        offset = 1.5
                    }
                }
        }
    }
}
