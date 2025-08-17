import SwiftUI

// MARK: - Next Class Card
struct NextClassCard: View {
    let themeManager: ThemeManager
    let classService: ClassService
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    
    private var nextClass: GymClass? {
        let now = Date()
        let userRegisteredClasses = classService.classes.filter { gymClass in
            let isRegistered = classService.userRegistrationStatus[gymClass.id] ?? false
            return isRegistered && gymClass.startTime > now
        }
        
        return userRegisteredClasses.sorted { $0.startTime < $1.startTime }.first
    }
    
    private var timeUntilClass: String {
        guard let nextClass = nextClass else { return "" }
        
        let now = Date()
        let timeInterval = nextClass.startTime.timeIntervalSince(now)
        let hours = Int(timeInterval / 3600)
        let minutes = Int((timeInterval.truncatingRemainder(dividingBy: 3600)) / 60)
        
        if hours > 0 {
            return "En \(hours)h \(minutes)m"
        } else {
            return "En \(minutes)m"
        }
    }
    
    private var formattedTime: String {
        guard let nextClass = nextClass else { return "" }
        
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"
        formatter.timeZone = TimeZone.current
        return formatter.string(from: nextClass.startTime)
    }
    
    var body: some View {
        // Agregamos una verificación adicional para evitar crashes
        if !classService.classes.isEmpty,
           let gymClass = nextClass {
            VStack(spacing: 16) {
                // Header
                HStack {
                    Text("Próxima Clase")
                        .font(.cappedDynamicSystem(size: 20, weight: .bold, maxSize: 26))
                        .foregroundColor(Color.dynamicText(theme: themeManager.currentTheme))
                    
                    Spacer()
                    
                    // Time until class badge
                    HStack(spacing: 4) {
                        Image(systemName: "clock.fill")
                            .font(.system(size: 11))
                            .foregroundColor(Color.dynamicAccent(theme: themeManager.currentTheme))
                        
                        Text(timeUntilClass)
                            .font(.cappedDynamicSystem(size: 11, weight: .semibold, maxSize: 15))
                            .foregroundColor(Color.dynamicAccent(theme: themeManager.currentTheme))
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(
                        Capsule()
                            .fill(Color.dynamicAccent(theme: themeManager.currentTheme).opacity(0.1))
                    )
                }
                .padding(.horizontal, 4)
                
                // Class card
                ZStack {
                    // Background with gradient
                    RoundedRectangle(cornerRadius: 20)
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color.dynamicSurface(theme: themeManager.currentTheme),
                                    Color.dynamicSurface(theme: themeManager.currentTheme).opacity(0.8)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 20)
                                .stroke(Color.dynamicAccent(theme: themeManager.currentTheme).opacity(0.3), lineWidth: 1)
                        )
                    
                    // Content
                    VStack(spacing: 16) {
                        // Class info
                        HStack(spacing: 16) {
                            // Class type icon
                            ZStack {
                                Circle()
                                    .fill(Color.dynamicAccent(theme: themeManager.currentTheme).opacity(0.15))
                                    .frame(width: 60, height: 60)
                                
                                Image(systemName: classIconForName(gymClass.name))
                                    .font(.system(size: 28, weight: .semibold))
                                    .foregroundColor(Color.dynamicAccent(theme: themeManager.currentTheme))
                            }
                            
                            VStack(alignment: .leading, spacing: 8) {
                                Text(gymClass.name)
                                    .font(.cappedDynamicSystem(size: 22, weight: .bold, maxSize: 28))
                                    .foregroundColor(Color.dynamicText(theme: themeManager.currentTheme))
                                    .lineLimit(1)
                                
                                HStack(spacing: 8) {
                                    Text(formattedTime)
                                        .font(.cappedDynamicSystem(size: 15, weight: .medium, maxSize: 19))
                                        .foregroundColor(Color.dynamicTextSecondary(theme: themeManager.currentTheme))
                                    
                                    Text("•")
                                        .font(.system(size: 15, weight: .bold))
                                        .foregroundColor(Color.dynamicTextSecondary(theme: themeManager.currentTheme))
                                    
                                    Text("Instructor: \(gymClass.instructor)")
                                        .font(.cappedDynamicSystem(size: 15, weight: .medium, maxSize: 19))
                                        .foregroundColor(Color.dynamicTextSecondary(theme: themeManager.currentTheme))
                                        .lineLimit(1)
                                }
                            }
                            
                            Spacer()
                        }
                        
                        // Action buttons
                        HStack(spacing: 12) {
                            // Chat button
                            Button(action: {
                                // TODO: Navigate to chat with instructor
                            }) {
                                HStack(spacing: 8) {
                                    Image(systemName: "message.fill")
                                        .font(.system(size: 14, weight: .semibold))
                                    Text("Chat")
                                        .font(.cappedDynamicSystem(size: 14, weight: .semibold, maxSize: 18))
                                }
                                .foregroundColor(.white)
                                .padding(.horizontal, 20)
                                .padding(.vertical, 10)
                                .background(
                                    Capsule()
                                        .fill(Color.dynamicAccent(theme: themeManager.currentTheme))
                                )
                            }
                            
                            Spacer()
                            
                            // Details button
                            Button(action: {
                                // TODO: Show class details
                            }) {
                                HStack(spacing: 8) {
                                    Image(systemName: "info.circle.fill")
                                        .font(.system(size: 14, weight: .semibold))
                                    Text("Detalles")
                                        .font(.cappedDynamicSystem(size: 14, weight: .semibold, maxSize: 18))
                                }
                                .foregroundColor(Color.dynamicText(theme: themeManager.currentTheme))
                                .padding(.horizontal, 20)
                                .padding(.vertical, 10)
                                .background(
                                    Capsule()
                                        .fill(Color.dynamicSurface(theme: themeManager.currentTheme))
                                        .overlay(
                                            Capsule()
                                                .stroke(Color.dynamicBorder(theme: themeManager.currentTheme), lineWidth: 1)
                                        )
                                )
                            }
                        }
                    }
                    .padding(24)
                }
                .padding(.horizontal, 4)
            }
            .accessibilityElement(children: .combine)
            .accessibilityLabel("Next class: \(gymClass.name) at \(formattedTime) with \(gymClass.instructor)")
        } else {
            // Return empty view if no class or classes not loaded
            EmptyView()
        }
    }
    
    // Helper function to get appropriate icon for class type
    private func classIconForName(_ className: String) -> String {
        let lowercaseName = className.lowercased()
        
        if lowercaseName.contains("box") || lowercaseName.contains("kick") {
            return "figure.boxing"
        } else if lowercaseName.contains("yoga") {
            return "figure.mind.and.body"
        } else if lowercaseName.contains("run") || lowercaseName.contains("cardio") {
            return "figure.run"
        } else if lowercaseName.contains("strength") || lowercaseName.contains("weight") {
            return "dumbbell.fill"
        } else if lowercaseName.contains("dance") {
            return "figure.dance"
        } else if lowercaseName.contains("cycle") || lowercaseName.contains("spin") {
            return "figure.indoor.cycle"
        } else if lowercaseName.contains("swim") {
            return "figure.pool.swim"
        } else if lowercaseName.contains("climb") {
            return "figure.climbing"
        } else {
            return "figure.strengthtraining.traditional"
        }
    }
}

#Preview {
    NextClassCard(
        themeManager: ThemeManager(),
        classService: ClassService()
    )
    .padding()
    .background(Color.dynamicBackground(theme: .dark))
}