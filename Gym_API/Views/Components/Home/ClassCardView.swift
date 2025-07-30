import SwiftUI

struct ClassCardView: View {
    @EnvironmentObject var themeManager: ThemeManager
    let gymClass: GymClass
    @EnvironmentObject var classService: ClassService
    @State private var trainerImage: String = ""
    
    var body: some View {
        HStack(spacing: 0) {
            // Indicador de estado (línea colorida)
            Rectangle()
                .fill(classAccentColor)
                .frame(width: 6)
            
            // Contenido principal
            VStack(alignment: .leading, spacing: 12) {
                // Header
                VStack(alignment: .leading, spacing: 8) {
                    Text(gymClass.name)
                        .font(.system(size: 22, weight: .bold))
                        .foregroundColor(Color.dynamicText(theme: themeManager.currentTheme))
                        .lineLimit(1)
                    
                    HStack(spacing: 12) {
                        HStack(spacing: 4) {
                            Image(systemName: "clock")
                                .font(.system(size: 14))
                                .foregroundColor(Color.dynamicAccent(theme: themeManager.currentTheme))
                            Text(formattedTimeWithDuration)
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(Color.dynamicText(theme: themeManager.currentTheme))
                        }
                    }
                }
                
                // Badges
                HStack(spacing: 6) {
                    Text(difficultyText.uppercased())
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundColor(Color(red: 0.25, green: 0.65, blue: 0.25))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 3)
                        .background(
                            RoundedRectangle(cornerRadius: 6)
                                .fill(Color.dynamicSurface(theme: themeManager.currentTheme))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 6)
                                        .stroke(Color(red: 0.25, green: 0.65, blue: 0.25), lineWidth: 1)
                                )
                        )
                    
                    Text(spotsText.uppercased())
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundColor(spotsTextColor)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 3)
                        .background(
                            RoundedRectangle(cornerRadius: 6)
                                .fill(Color.dynamicSurface(theme: themeManager.currentTheme))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 6)
                                        .stroke(spotsTextColor, lineWidth: 1)
                                )
                        )
                }
                
                // Instructor and action button
                HStack(spacing: 0) {
                    HStack(spacing: 10) {
                        AsyncImage(url: URL(string: instructorImageURL)) { phase in
                            switch phase {
                            case .success(let image):
                                image
                                    .resizable()
                                    .aspectRatio(contentMode: .fill)
                                    .frame(width: 50, height: 50)
                                    .clipped()
                            case .failure(_), .empty:
                                Image("trainer_placeholder")
                                    .resizable()
                                    .aspectRatio(contentMode: .fill)
                                    .frame(width: 50, height: 50)
                                    .clipped()
                            @unknown default:
                                ZStack {
                                    Circle()
                                        .fill(Color.dynamicSurface(theme: themeManager.currentTheme))
                                    Image(systemName: "person.fill")
                                        .font(.system(size: 24))
                                        .foregroundColor(Color.dynamicTextSecondary(theme: themeManager.currentTheme))
                                }
                                .frame(width: 50, height: 50)
                            }
                        }
                        .clipShape(Circle())
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text(instructorDisplayName)
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundColor(Color.dynamicText(theme: themeManager.currentTheme))
                                .lineLimit(1)
                        }
                    }
                    
                    Spacer()
                    
                    // Action button
                    actionButton
                }
            }
            .padding(.leading, 24)
            .padding(.trailing, 20)
            .padding(.top, 18)
            .padding(.bottom, 16)
        }
        .frame(maxWidth: .infinity)
        .background(Color.dynamicSurface(theme: themeManager.currentTheme))
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .overlay(
            // Green status dot in top-right corner
            Circle()
                .fill(Color.green)
                .frame(width: 8, height: 8)
                .offset(x: -12, y: 12),
            alignment: .topTrailing
        )
    }
    
    @ViewBuilder
    private var actionButton: some View {
        Group {
            if gymClass.status == .completed {
                HStack(spacing: 6) {
                    Image(systemName: "lock.fill")
                        .font(.system(size: 14, weight: .bold))
                    Text("Complete")
                        .font(.system(size: 16, weight: .bold))
                }
                .foregroundColor(Color.dynamicTextSecondary(theme: themeManager.currentTheme))
                .padding(.horizontal, 20)
                .padding(.vertical, 12)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.dynamicSurface(theme: themeManager.currentTheme))
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(Color.dynamicTextSecondary(theme: themeManager.currentTheme), lineWidth: 1)
                        )
                )
            } else if gymClass.status == .cancelled {
                Text("Cancelled")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.red)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color.red.opacity(0.1))
                    )
            } else if classService.isUserRegistered(classId: gymClass.id) {
                VStack(spacing: 8) {
                    // Estado "Registered"
                    HStack(spacing: 6) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 14, weight: .bold))
                        Text("Registered")
                            .font(.system(size: 16, weight: .bold))
                    }
                    .foregroundColor(.green)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 8)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color.green.opacity(0.1))
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(Color.green, lineWidth: 1)
                            )
                    )
                    
                    // Botón Cancel más pequeño
                    Button(action: {
                        Task {
                            await classService.cancelClassRegistration(classId: gymClass.id, reason: "User cancelled from app")
                        }
                    }) {
                        if classService.cancellingClassIds.contains(gymClass.id) {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .red))
                                .scaleEffect(0.6)
                        } else {
                            Text("Cancel")
                                .font(.system(size: 12, weight: .medium))
                        }
                    }
                    .foregroundColor(.red)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(
                        RoundedRectangle(cornerRadius: 6)
                            .stroke(Color.red.opacity(0.5), lineWidth: 1)
                    )
                }
            } else {
                Button(action: {
                    Task {
                        await classService.joinClass(classId: gymClass.id)
                    }
                }) {
                    if classService.joiningClassIds.contains(gymClass.id) {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            .scaleEffect(0.8)
                    } else {
                        Text("Join")
                            .font(.system(size: 16, weight: .bold))
                    }
                }
                .foregroundColor(.white)
                .padding(.horizontal, 20)
                .padding(.vertical, 12)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.dynamicAccent(theme: themeManager.currentTheme))
                )
            }
        }
    }
    
    // MARK: - Computed Properties
    private var classAccentColor: Color {
        return Color.dynamicAccent(theme: themeManager.currentTheme)
    }
    
    private var formattedTimeWithDuration: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"
        
        // Obtener las zonas horarias
        let userTimezone = TimeZone.current
        let gymTimezoneString = gymClass.gymTimezone ?? "America/New_York"
        let gymTimezone = TimeZone(identifier: gymTimezoneString) ?? TimeZone.current
        
        print("🎭 ClassCardView: User timezone: \(userTimezone.identifier)")
        print("🎭 ClassCardView: Gym timezone: \(gymTimezoneString)")
        
        // Si las zonas horarias son iguales, no hacer conversión
        if userTimezone.identifier == gymTimezone.identifier {
            formatter.timeZone = TimeZone.current
            print("🎭 ClassCardView: Same timezone, no conversion needed")
        } else {
            // Si son diferentes, usar la zona horaria del gimnasio
            formatter.timeZone = gymTimezone
            print("🎭 ClassCardView: Different timezone, using gym timezone for display")
        }
        
        let startTimeString = formatter.string(from: gymClass.startTime)
        print("🎭 ClassCardView: Formatted time: \(startTimeString)")
        
        // Calculate duration
        let duration = gymClass.endTime.timeIntervalSince(gymClass.startTime)
        let hours = Int(duration / 3600)
        
        return "\(startTimeString) • \(hours)h"
    }
    
    private var instructorDisplayName: String {
        // Map generic instructor names to Jose Paul Rodriguez as shown in original
        return "Jose Paul Rodriguez"
    }
    
    private var instructorImageURL: String {
        // Return empty string to use fallback icon
        return ""
    }
    
    private var difficultyText: String {
        switch gymClass.difficulty {
        case .beginner: return "Beginner"
        case .intermediate: return "Intermediate"
        case .advanced: return "Advanced"
        }
    }
    
    private var spotsText: String {
        let availableSpots = gymClass.maxParticipants - gymClass.currentParticipants
        if availableSpots <= 0 {
            return "Full"
        } else {
            return "\(availableSpots) spots"
        }
    }
    
    private var spotsTextColor: Color {
        let availableSpots = gymClass.maxParticipants - gymClass.currentParticipants
        if availableSpots <= 0 {
            return Color(red: 0.4, green: 0.4, blue: 0.4)
        } else if availableSpots <= 3 {
            return Color(red: 0.78, green: 0.16, blue: 0.16)
        } else {
            return Color(red: 0.90, green: 0.38, blue: 0.0)
        }
    }
    
    private var spotsBadgeBackground: Color {
        let availableSpots = gymClass.maxParticipants - gymClass.currentParticipants
        if availableSpots <= 0 {
            return Color(red: 0.92, green: 0.92, blue: 0.92)
        } else if availableSpots <= 3 {
            return Color(red: 1.0, green: 0.95, blue: 0.95)
        } else {
            return Color(red: 1.0, green: 0.95, blue: 0.88)
        }
    }
}


#Preview {
    let sampleClass = GymClass(
        id: 1,
        name: "Boxing Fundamentals",
        description: "Learn the basics of boxing",
        instructor: "Coach Mike",
        startTime: Date(),
        endTime: Date().addingTimeInterval(3600),
        maxParticipants: 15,
        currentParticipants: 8,
        difficulty: .beginner,
        status: .available
    )
    
    ClassCardView(gymClass: sampleClass)
        .environmentObject(ThemeManager())
        .environmentObject(ClassService())
        .padding()
}