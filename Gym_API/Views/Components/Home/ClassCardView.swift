import SwiftUI

struct ClassCardView: View {
    @EnvironmentObject var themeManager: ThemeManager
    let gymClass: GymClass
    @EnvironmentObject var classService: ClassService
    @State private var trainerImage: String = ""
    
    var body: some View {
        VStack(spacing: 0) {
            // Fondo de la tarjeta
            RoundedRectangle(cornerRadius: 20)
                .fill(Color.dynamicSurface(theme: themeManager.currentTheme))
            
            HStack(spacing: 0) {
                // Indicador de estado (línea colorida)
                Rectangle()
                    .fill(classAccentColor)
                    .frame(width: 5)
                
                // Contenido principal
                VStack(alignment: .leading, spacing: 12) {
                    // Header
                    VStack(alignment: .leading, spacing: 8) {
                        Text(gymClass.name.uppercased())
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(Color.dynamicText(theme: themeManager.currentTheme))
                            .lineLimit(2)
                        
                        Text(formattedTimeWithDuration)
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(Color.dynamicTextSecondary(theme: themeManager.currentTheme))
                    }
                    
                    // Badges
                    HStack(spacing: 6) {
                        Text(difficultyText.uppercased())
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundColor(Color(red: 0.13, green: 0.55, blue: 0.13))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 3)
                            .background(
                                RoundedRectangle(cornerRadius: 6)
                                    .fill(Color.dynamicSurface(theme: themeManager.currentTheme))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 6)
                                            .stroke(Color(red: 0.13, green: 0.55, blue: 0.13), lineWidth: 1)
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
                            AsyncImage(url: URL(string: instructorImageURL)) { image in
                                image
                                    .resizable()
                                    .aspectRatio(contentMode: .fill)
                            } placeholder: {
                                Image(systemName: "person.circle.fill")
                                    .resizable()
                                    .aspectRatio(contentMode: .fill)
                                    .foregroundColor(Color.dynamicTextSecondary(theme: themeManager.currentTheme))
                            }
                            .frame(width: 50, height: 50)
                            .clipShape(Circle())
                            
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Instructor")
                                    .font(.system(size: 10, weight: .medium))
                                    .foregroundColor(Color.dynamicTextSecondary(theme: themeManager.currentTheme))
                                
                                Text(instructorDisplayName)
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundColor(Color.dynamicText(theme: themeManager.currentTheme))
                            }
                        }
                        
                        Spacer()
                        
                        // Action button
                        actionButton
                    }
                }
                .padding(.leading, 24)
                .padding(.trailing, 20)
                .padding(.top, 12)
                .padding(.bottom, 16)
            }
        }
        .frame(maxWidth: .infinity)
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
                Button(action: {
                    Task {
                        await classService.cancelClassRegistration(classId: gymClass.id, reason: "User cancelled from app")
                    }
                }) {
                    if classService.cancellingClassIds.contains(gymClass.id) {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .red))
                            .scaleEffect(0.8)
                    } else {
                        Text("Cancel")
                            .font(.system(size: 16, weight: .bold))
                    }
                }
                .foregroundColor(.red)
                .padding(.horizontal, 20)
                .padding(.vertical, 12)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.red, lineWidth: 1)
                )
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
        let startTimeString = formatter.string(from: gymClass.startTime)
        
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
        // Use a placeholder profile image URL
        return "https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d?w=100&h=100&fit=face&crop=face"
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