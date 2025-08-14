import SwiftUI

// MARK: - Coach Row View
struct CoachRowView: View {
    // MARK: - Properties
    let coach: UserProfile
    let themeManager: ThemeManager
    let onTap: () -> Void
    
    // MARK: - State Variables
    @State private var isPressed = false
    
    // MARK: - Computed Properties
    private var roleDisplayText: String {
        if let gymRole = coach.gymRole, !gymRole.isEmpty {
            return gymRole.capitalized
        } else {
            return coach.role.capitalized
        }
    }
    
    private var isOnline: Bool {
        // TODO: Implement actual online status logic
        // For now, randomly show some coaches as online for UI demonstration
        return coach.id % 3 == 0
    }
    
    private var avatarGradientColors: [Color] {
        // Generate consistent colors based on coach ID
        let colors = [
            Color.dynamicAccent(theme: themeManager.currentTheme),
            Color.blue,
            Color.green,
            Color.orange,
            Color.purple,
            Color.pink,
            Color.cyan,
            Color.indigo,
            Color.mint,
            Color.teal
        ]
        
        let primaryIndex = abs(coach.id.hashValue) % colors.count
        let secondaryIndex = abs((coach.id + 1).hashValue) % colors.count
        
        return [colors[primaryIndex], colors[secondaryIndex]]
    }
    
    private var initials: String {
        let names = coach.fullName.split(separator: " ")
        if names.count >= 2 {
            return String(names[0].prefix(1)) + String(names[1].prefix(1))
        } else if let firstLetter = coach.fullName.first {
            return String(firstLetter).uppercased()
        } else {
            return "?"
        }
    }
    
    // MARK: - Body
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 16) {
                // Avatar Section
                ZStack {
                    // Profile image or gradient avatar
                    if let pictureURL = coach.picture,
                       !pictureURL.isEmpty {
                        AsyncImage(url: URL(string: pictureURL)) { image in
                            image
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                        } placeholder: {
                            gradientAvatar
                        }
                        .frame(width: 60, height: 60)
                        .clipShape(Circle())
                    } else {
                        gradientAvatar
                    }
                    
                    // Online status indicator
                    if isOnline {
                        Circle()
                            .fill(Color.green)
                            .frame(width: 18, height: 18)
                            .overlay(
                                Circle()
                                    .stroke(
                                        Color.dynamicBackground(theme: themeManager.currentTheme),
                                        lineWidth: 3
                                    )
                            )
                            .offset(x: 22, y: 22)
                            .shadow(radius: 2)
                    }
                    
                    // Coach badge
                    Image(systemName: "person.badge.shield.checkmark.fill")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.white)
                        .background(
                            Circle()
                                .fill(Color.dynamicAccent(theme: themeManager.currentTheme))
                                .frame(width: 24, height: 24)
                        )
                        .offset(x: -22, y: -22)
                }
                .shadow(
                    color: Color.black.opacity(themeManager.currentTheme == .dark ? 0.3 : 0.1),
                    radius: 6,
                    x: 0,
                    y: 3
                )
                
                // Content Section
                VStack(alignment: .leading, spacing: 6) {
                    // Name
                    HStack(alignment: .center) {
                        Text(coach.fullName)
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundColor(Color.dynamicText(theme: themeManager.currentTheme))
                            .lineLimit(1)
                        
                        Spacer()
                        
                        // Verified coach icon
                        Image(systemName: "checkmark.seal.fill")
                            .font(.system(size: 16))
                            .foregroundColor(Color.dynamicAccent(theme: themeManager.currentTheme))
                    }
                    
                    // Role and status
                    HStack(spacing: 8) {
                        // Role badge
                        HStack(spacing: 4) {
                            Image(systemName: roleIcon)
                                .font(.system(size: 10, weight: .medium))
                                .foregroundColor(Color.dynamicAccent(theme: themeManager.currentTheme))
                            
                            Text(roleDisplayText)
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundColor(Color.dynamicAccent(theme: themeManager.currentTheme))
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color.dynamicAccent(theme: themeManager.currentTheme).opacity(0.1))
                        )
                        
                        // Online status text
                        if isOnline {
                            HStack(spacing: 4) {
                                Circle()
                                    .fill(Color.green)
                                    .frame(width: 6, height: 6)
                                
                                Text("Online")
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundColor(Color.green)
                            }
                        } else {
                            Text("Last seen recently")
                                .font(.system(size: 12))
                                .foregroundColor(Color.dynamicTextSecondary(theme: themeManager.currentTheme))
                        }
                        
                        Spacer()
                    }
                    
                    // Bio preview (if available)
                    if let bio = coach.bio, !bio.isEmpty {
                        Text(bio)
                            .font(.system(size: 14))
                            .foregroundColor(Color.dynamicTextSecondary(theme: themeManager.currentTheme))
                            .lineLimit(2)
                            .multilineTextAlignment(.leading)
                    }
                    
                    // Specialization areas (if available in goals)
                    if let specializations = coach.goals, !specializations.isEmpty {
                        HStack(spacing: 6) {
                            Image(systemName: "star.fill")
                                .font(.system(size: 10))
                                .foregroundColor(.orange)
                            
                            Text(specializations)
                                .font(.system(size: 12))
                                .foregroundColor(Color.dynamicTextSecondary(theme: themeManager.currentTheme))
                                .lineLimit(1)
                        }
                    }
                }
                
                // Arrow indicator
                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(Color.dynamicTextSecondary(theme: themeManager.currentTheme))
                    .opacity(0.5)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
        }
        .buttonStyle(PlainButtonStyle())
        .background(
            RoundedRectangle(cornerRadius: 0)
                .fill(Color.dynamicSurface(theme: themeManager.currentTheme))
                .opacity(isPressed ? 0.7 : 0.001)
        )
        .contentShape(Rectangle())
        .scaleEffect(isPressed ? 0.98 : 1.0)
        .animation(.easeInOut(duration: 0.1), value: isPressed)
        .onTapGesture {
            withAnimation(.easeInOut(duration: 0.1)) {
                isPressed = true
            }
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                withAnimation(.easeInOut(duration: 0.1)) {
                    isPressed = false
                }
                onTap()
            }
        }
    }
    
    // MARK: - Gradient Avatar
    private var gradientAvatar: some View {
        ZStack {
            LinearGradient(
                gradient: Gradient(colors: avatarGradientColors),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .frame(width: 60, height: 60)
            .clipShape(Circle())
            
            Text(initials)
                .font(.system(size: 22, weight: .bold))
                .foregroundColor(.white)
        }
    }
    
    // MARK: - Role Icon
    private var roleIcon: String {
        let role = roleDisplayText.lowercased()
        
        switch role {
        case let r where r.contains("trainer"):
            return "dumbbell.fill"
        case let r where r.contains("coach"):
            return "person.badge.shield.checkmark"
        case let r where r.contains("instructor"):
            return "graduationcap.fill"
        case let r where r.contains("manager"):
            return "person.crop.circle.badge.checkmark"
        case let r where r.contains("admin"):
            return "crown.fill"
        default:
            return "person.badge.shield.checkmark"
        }
    }
}

// MARK: - Preview
#Preview {
    VStack(spacing: 0) {
        CoachRowView(
            coach: UserProfile(
                id: 1,
                email: "coach1@gym.com",
                isActive: true,
                isSuperuser: false,
                firstName: "John",
                lastName: "Smith",
                role: "trainer",
                phoneNumber: "+1234567890",
                birthDate: nil,
                height: 180.0,
                weight: 75.0,
                bio: "Certified personal trainer with 10+ years of experience specializing in strength training and weight loss.",
                goals: "Strength Training, Weight Loss, Muscle Building",
                healthConditions: nil,
                gymRole: "Head Coach",
                qrCode: "",
                createdAt: Date(),
                updatedAt: Date(),
                auth0Id: "coach1",
                picture: nil,
                color: nil
            ),
            themeManager: ThemeManager(),
            onTap: {}
        )
        
        CoachRowView(
            coach: UserProfile(
                id: 2,
                email: "coach2@gym.com",
                isActive: true,
                isSuperuser: false,
                firstName: "Maria",
                lastName: "Rodriguez",
                role: "coach",
                phoneNumber: "+1234567891",
                birthDate: nil,
                height: 165.0,
                weight: 55.0,
                bio: "Yoga and wellness coach focused on holistic health.",
                goals: "Yoga, Meditation, Flexibility",
                healthConditions: nil,
                gymRole: "Wellness Coach",
                qrCode: "",
                createdAt: Date(),
                updatedAt: Date(),
                auth0Id: "coach2",
                picture: nil,
                color: nil
            ),
            themeManager: ThemeManager(),
            onTap: {}
        )
    }
    .background(Color.dynamicBackground(theme: .dark))
}