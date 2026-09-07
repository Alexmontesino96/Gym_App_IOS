import SwiftUI

// MARK: - Modern Profile View (Prototype-matched design)
struct ModernProfileView: View {
    // MARK: - Environment & State
    @EnvironmentObject var authService: AuthServiceDirect
    @EnvironmentObject var themeManager: ThemeManager
    @EnvironmentObject var classService: ClassService
    @EnvironmentObject var eventService: EventService
    @StateObject private var colorCustomizationManager = ColorCustomizationManager.shared
    @StateObject private var profileService = UserProfileService.shared
    @StateObject private var userStatsService = UserStatsService.shared
    @StateObject private var imageService = UnifiedImageService.shared
    @StateObject private var gymService = GymService.shared
    @StateObject private var postService = PostService.shared

    @State private var showingSettings = false
    @State private var showingProfileOptions = false
    @State private var showingColorPicker = false
    @State private var showingImagePicker = false
    @State private var selectedImage: UIImage?
    @State private var showingEditProfile = false
    @State private var showingGymSelector = false
    @State private var showProfileCelebration = false
    @State private var showingQRCode = false
    @State private var showingDeleteAccount = false

    /// Misma derivación que `AuthenticatedView.rootForCurrentUser`, con el mismo triple respaldo:
    /// el backend no serializa `is_personal_trainer` en `/gyms/my` (es una @property de Python sin
    /// @computed_field), así que `type` es el que vale de verdad.
    private var isPersonalTrainerWorkspace: Bool {
        WorkspaceContextService.shared.isPersonalTrainer
            || (gymService.currentGym?.isPersonalTrainer ?? false)
            || gymService.currentGym?.type?.lowercased() == "personal_trainer"
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color.dynamicBackground(theme: themeManager.currentTheme)
                    .ignoresSafeArea()

                ScrollView(.vertical, showsIndicators: false) {
                    VStack(spacing: 20) {
                        // Header: "Profile" + settings
                        headerSection

                        // Profile card
                        profileCard

                        // Membership card
                        workspaceCard

                        // Settings list
                        settingsList

                        // Logout button
                        logoutButton

                        // Borrado de cuenta. Apple pide que se pueda hacer desde la app y
                        // que se encuentre sin buscar, así que va aquí y no dentro de ajustes.
                        deleteAccountButton

                        Spacer(minLength: 100)
                    }
                }

                // Loading overlay
                if profileService.isLoading {
                    Color.dynamicBackground(theme: themeManager.currentTheme).opacity(0.6)
                        .ignoresSafeArea()
                        .overlay(ProgressView())
                }
            }
            .navigationBarHidden(true)
            .sheet(isPresented: $showingSettings) {
                SettingsView(onThemeChangeRequest: {})
            }
            .sheet(isPresented: $showingImagePicker) {
                EnhancedImagePickerSheet(
                    selectedImage: $selectedImage,
                    isPresented: $showingImagePicker
                )
                .environmentObject(themeManager)
                .interactiveDismissDisabled(true)
            }
            .sheet(isPresented: $showingEditProfile) {
                EditProfileSheet()
                    .environmentObject(themeManager)
            }
            .sheet(isPresented: $showingGymSelector) {
                NavigationStack {
                    GymSelectionView { selected in
                        gymService.selectGym(selected)
                        showingGymSelector = false
                    }
                    .environmentObject(themeManager)
                    .environmentObject(authService)
                }
            }
            .sheet(isPresented: $showingColorPicker) {
                SimpleColorSettingsView()
                    .environmentObject(themeManager)
            }
            .sheet(isPresented: $showingQRCode) {
                QRCodeSheet(
                    qrCode: profileService.userProfile?.qrCode,
                    userName: profileService.userProfile?.fullName
                )
                .environmentObject(themeManager)
            }
        }
        .overlay(
            Group {
                if showProfileCelebration {
                    ProfileCompletionCelebration(
                        isShowing: $showProfileCelebration,
                        theme: themeManager.currentTheme
                    )
                    .zIndex(1000)
                }
            }
        )
        .onAppear {
            setupServices()
            loadData()
        }
        .onChange(of: selectedImage) { _, newImage in
            if let image = newImage {
                Task { await uploadProfileImage(image) }
            }
        }
    }

    // MARK: - Header

    private var headerSection: some View {
        HStack {
            Text("Profile")
                .font(.system(size: 28, weight: .bold))
                .tracking(-0.8)
                .foregroundColor(Color.dynamicText(theme: themeManager.currentTheme))

            Spacer()

            Button(action: { showingSettings = true }) {
                Image(systemName: "gearshape")
                    .font(.system(size: 18))
                    .foregroundColor(Color.dynamicText(theme: themeManager.currentTheme))
                    .frame(width: 40, height: 40)
                    .background(Color.dynamicSurface(theme: themeManager.currentTheme))
                    .clipShape(Circle())
                    .overlay(Circle().stroke(Color.white.opacity(0.08), lineWidth: 1))
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 16)
    }

    // MARK: - Profile Card

    private var profileCard: some View {
        VStack(spacing: 0) {
            // Avatar + Name + Member Since + QR
            HStack(spacing: 14) {
                // Avatar (tappable to change)
                Button(action: { showingImagePicker = true }) {
                    ZStack {
                        if let picture = profileService.userProfile?.picture,
                           let url = URL(string: picture) {
                            AsyncImage(url: url) { image in
                                image.resizable().aspectRatio(contentMode: .fill)
                            } placeholder: {
                                avatarPlaceholder
                            }
                            .frame(width: 64, height: 64)
                            .clipShape(Circle())
                        } else {
                            avatarPlaceholder
                        }
                    }
                }
                .buttonStyle(.plain)

                // Name + member since
                VStack(alignment: .leading, spacing: 4) {
                    Text(profileService.userProfile?.fullName ?? authService.user?.name ?? "Usuario")
                        .font(.system(size: 22, weight: .bold))
                        .tracking(-0.4)
                        .foregroundColor(Color.dynamicText(theme: themeManager.currentTheme))
                        .lineLimit(1)

                    if let memberSinceText {
                        // «Client since» en un espacio de entrenador: quien está aquí no es socio
                        // de un gimnasio, es cliente de una persona.
                        Text("\(isPersonalTrainerWorkspace ? "Client" : "Member") since \(memberSinceText)")
                            .font(.system(size: 12))
                            .foregroundColor(Color.dynamicText(theme: themeManager.currentTheme).opacity(0.5))
                    }
                }

                Spacer()

                // QR button
                Button(action: { showingQRCode = true }) {
                    Image(systemName: "qrcode")
                        .font(.system(size: 18))
                        .foregroundColor(Color.dynamicText(theme: themeManager.currentTheme))
                        .frame(width: 40, height: 40)
                        .background(Color.dynamicSurface(theme: themeManager.currentTheme))
                        .clipShape(Circle())
                        .overlay(Circle().stroke(Color.white.opacity(0.08), lineWidth: 1))
                }
            }

            // Stats row
            //
            // `statValue` distingue «cero de verdad» de «no se pudo cargar». Antes las dos cosas
            // se pintaban igual: `fetchComprehensiveStats` tiene cinco salidas silenciosas que
            // dejan el modelo vacio, y el endpoint esta limitado a 10 peticiones por minuto con
            // tres llamadores, asi que un 429 daba el mismo «0 / 0 / 0» que un usuario nuevo.
            HStack(spacing: 16) {
                statItem(value: statValue(userStatsService.userStats.monthlyClasses), label: "sessions", alignment: .leading)
                statItem(value: statValue(userStatsService.userStats.currentStreak), label: "streak", alignment: .center)
                statItem(value: statValue(userStatsService.achievements.count), label: "badges", alignment: .center)
            }
            .padding(.top, 20)
            .overlay(alignment: .top) {
                Rectangle()
                    .fill(Color.white.opacity(0.08))
                    .frame(height: 1)
                    .padding(.top, 16) // Match the padding before content
            }
        }
        .padding(20)
        .background(
            ZStack {
                Color.dynamicSurface(theme: themeManager.currentTheme)

                // Decorative gradient circle
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [Color(hex: "#D4FF3F")!.opacity(0.25), .clear],
                            center: .center,
                            startRadius: 0,
                            endRadius: 80
                        )
                    )
                    .frame(width: 160, height: 160)
                    .offset(x: 80, y: -40)
            }
            .clipShape(RoundedRectangle(cornerRadius: 22))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 22)
                .stroke(Color.white.opacity(0.08), lineWidth: 1)
        )
        .padding(.horizontal, 20)
    }

    /// Una cifra solo se pinta cuando se sabe. Si la carga fallo o sigue en curso y no hay nada
    /// que ensenar, se pinta el marcador: un cero afirma que no has entrenado, y eso puede ser
    /// falso.
    private func statValue(_ value: Int) -> String {
        if value > 0 { return "\(value)" }
        if userStatsService.isLoading || userStatsService.error != nil { return NumberFormat.placeholder }
        return "0"
    }

    private func statItem(value: String, label: String, alignment: HorizontalAlignment) -> some View {
        VStack(alignment: alignment == .leading ? .leading : .center, spacing: 2) {
            Text(value)
                .font(.system(size: 22, weight: .bold, design: .monospaced))
                .tracking(-0.4)
                .foregroundColor(Color.dynamicText(theme: themeManager.currentTheme))

            Text(label.uppercased())
                .font(.system(size: 9, weight: .bold))
                .tracking(0.8)
                .foregroundColor(Color.dynamicText(theme: themeManager.currentTheme).opacity(0.5))
        }
        .frame(maxWidth: .infinity, alignment: alignment == .leading ? .leading : .center)
    }

    private var avatarPlaceholder: some View {
        Circle()
            .fill(
                LinearGradient(
                    colors: [Color(hex: "#FF5A1F")!, Color(hex: "#A78BFA")!],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .frame(width: 64, height: 64)
            .overlay(
                Text(getUserInitials())
                    .font(.system(size: 22, weight: .bold))
                    .foregroundColor(.white)
            )
    }

    // MARK: - Espacio de trabajo

    /// Antes era una tarjeta «MEMBERSHIP» con corona que pintaba el NOMBRE DEL GIMNASIO bajo ese
    /// rótulo, con respaldo al literal «Premium», dentro de un `Button` cuyo cuerpo estaba vacío
    /// (`/* Navigate to billing */`) y con un chevron prometiendo una navegación inexistente.
    ///
    /// Un cliente de entrenador personal no tiene membresía: tiene un entrenador. Y en un
    /// gimnasio, lo que hay aquí es el espacio al que perteneces, no un plan contratado.
    private var workspaceCard: some View {
        HStack(spacing: 12) {
            Image(systemName: isPersonalTrainerWorkspace ? "figure.strengthtraining.traditional" : "building.2.fill")
                .font(.system(size: 20))
                .foregroundColor(Color.dynamicAccent(theme: themeManager.currentTheme))
                .frame(width: 44, height: 44)
                .background(Color.dynamicAccent(theme: themeManager.currentTheme).opacity(0.18))
                .clipShape(RoundedRectangle(cornerRadius: 12))

            VStack(alignment: .leading, spacing: 4) {
                Text(isPersonalTrainerWorkspace ? "YOUR TRAINER" : "YOUR GYM")
                    .font(.system(size: 9, weight: .bold))
                    .tracking(0.8)
                    .foregroundColor(Color.dynamicText(theme: themeManager.currentTheme).opacity(0.5))

                if let name = gymService.currentGym?.name, !name.isEmpty {
                    Text(name)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(Color.dynamicText(theme: themeManager.currentTheme))
                }
            }

            Spacer()
        }
        .padding(16)
        .background(Color.dynamicSurface(theme: themeManager.currentTheme))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.dynamicBorder(theme: themeManager.currentTheme).opacity(0.15), lineWidth: 1)
        )
        .padding(.horizontal, 20)
    }

    // MARK: - Settings List

    private var settingsList: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Section title
            Text("SETTINGS")
                .font(.system(size: 9, weight: .bold))
                .tracking(0.8)
                .foregroundColor(Color.dynamicText(theme: themeManager.currentTheme).opacity(0.5))
                .padding(.horizontal, 20)
                .padding(.bottom, 12)

            VStack(spacing: 2) {
                settingsRow(
                    icon: "bell.fill",
                    label: "Notifications",
                    value: nil,
                    // Era `action: {}`. Los permisos de notificación los gobierna el sistema, así
                    // que lo honesto es llevar ahí en vez de fingir un ajuste propio.
                    action: { openSystemSettings() }
                )

                settingsRow(
                    icon: themeManager.currentTheme == .dark ? "moon.fill" : "sun.max.fill",
                    label: "Dark mode",
                    value: themeManager.currentTheme == .dark ? "On" : "Off",
                    action: { themeManager.toggleTheme() }
                )

                settingsRow(
                    icon: "paintbrush.fill",
                    label: "Appearance",
                    value: "Lime",
                    action: { showingColorPicker = true }
                )

                settingsRow(
                    icon: "person.fill",
                    label: "Edit profile",
                    value: nil,
                    action: { showingEditProfile = true }
                )

                settingsRow(
                    icon: "building.2.fill",
                    label: "Switch space",
                    value: nil,
                    action: { showingGymSelector = true }
                )

                settingsRow(
                    icon: "questionmark.circle.fill",
                    label: "Help",
                    value: nil,
                    // Era `action: {}`. Una fila que no hace nada es peor que no tenerla, y
                    // además la App Store exige un canal de contacto que funcione.
                    action: { openSupport() }
                )
            }
            .padding(.horizontal, 20)
        }
    }

    private func settingsRow(icon: String, label: String, value: String?, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 12) {
                // Icon
                Image(systemName: icon)
                    .font(.system(size: 16))
                    .foregroundColor(Color.dynamicText(theme: themeManager.currentTheme))
                    .frame(width: 32, height: 32)
                    .background(Color.dynamicText(theme: themeManager.currentTheme).opacity(0.08))
                    .clipShape(RoundedRectangle(cornerRadius: 10))

                // Label
                Text(label)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(Color.dynamicText(theme: themeManager.currentTheme))

                Spacer()

                // Value + chevron
                HStack(spacing: 6) {
                    if let value = value {
                        Text(value)
                            .font(.system(size: 12))
                            .foregroundColor(Color.dynamicText(theme: themeManager.currentTheme).opacity(0.5))
                    }
                    Image(systemName: "chevron.right")
                        .font(.system(size: 12))
                        .foregroundColor(Color.dynamicText(theme: themeManager.currentTheme).opacity(0.35))
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .background(Color.dynamicSurface(theme: themeManager.currentTheme))
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(Color.white.opacity(0.08), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Logout Button

    private var logoutButton: some View {
        Button(action: {
            Task {
                await authService.logout()
            }
        }) {
            Text("Sign out")
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(Color(hex: "#FF5A5A")!)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(Color.dynamicSurface(theme: themeManager.currentTheme))
                .clipShape(RoundedRectangle(cornerRadius: 14))
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(Color.white.opacity(0.08), lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 20)
    }

    // MARK: - Support

    /// Abre la ficha de la app en Ajustes, que es donde se conceden o retiran los permisos.
    private func openSystemSettings() {
        HapticManager.shared.buttonTap()
        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
        UIApplication.shared.open(url)
    }

    private func openSupport() {
        HapticManager.shared.buttonTap()
        if let url = SupportConfig.supportURL, UIApplication.shared.canOpenURL(url) {
            UIApplication.shared.open(url)
        } else if let mail = SupportConfig.mailtoURL() {
            UIApplication.shared.open(mail)
        }
    }

    // MARK: - Delete Account

    private var deleteAccountButton: some View {
        Button {
            showingDeleteAccount = true
        } label: {
            Text("Delete account")
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(Color.dynamicTextTertiary(theme: themeManager.currentTheme))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 20)
        .sheet(isPresented: $showingDeleteAccount) {
            DeleteAccountView(ownsWorkspace: ownsWorkspace)
                .environmentObject(themeManager)
                .environmentObject(authService)
        }
    }

    /// Quien dirige el espacio necesita saber que al borrarse el espacio se archiva.
    private var ownsWorkspace: Bool {
        gymService.currentGym?.userRoleInGym.uppercased() == "OWNER"
    }

    // MARK: - Helpers

    /// Devuelve nil cuando no se sabe, y entonces la línea no se pinta. Antes el respaldo era
    /// el literal «2024»: la app afirmaba una fecha de alta que no había leído de ninguna parte.
    private var memberSinceText: String? {
        guard let createdAt = profileService.userProfile?.createdAt else { return nil }
        let formatter = DateFormatter.localized(template: "MMMyyyy")
        return formatter.string(from: createdAt).capitalized
    }

    private func getUserInitials() -> String {
        let fullName = profileService.userProfile?.fullName ?? authService.user?.name ?? "U"
        let parts = fullName.split(separator: " ").map(String.init)
        if parts.count >= 2 {
            return "\(parts[0].prefix(1))\(parts.last!.prefix(1))".uppercased()
        }
        return String(fullName.prefix(2)).uppercased()
    }

    private func setupServices() {
        userStatsService.authService = authService
        userStatsService.gymService = GymService.shared
        profileService.authService = authService
        imageService.configure(authService: authService)
        colorCustomizationManager.authService = authService
        colorCustomizationManager.profileService = profileService
        GymService.shared.authService = authService
    }

    private func loadData() {
        userStatsService.achievements = []
        Task {
            await profileService.fetchUserProfileIfStale()
            await GymService.shared.getMyGyms()
            try? await Task.sleep(nanoseconds: 100_000_000)

            guard GymService.shared.currentGymId != nil else { return }

            await userStatsService.fetchComprehensiveStats()

            if let profile = profileService.userProfile {
                colorCustomizationManager.loadColorFromProfile(profile)
            }
        }
    }

    private func uploadProfileImage(_ image: UIImage) async {
        do {
            _ = try await imageService.uploadProfileImage(image)
            await profileService.refreshProfile()
        } catch {
            print("Error uploading profile image: \(error)")
        }
    }
}

#Preview {
    ModernProfileView()
        .environmentObject(AuthServiceDirect())
        .environmentObject(ThemeManager())
        .environmentObject(ClassService())
        .environmentObject(EventService())
}
