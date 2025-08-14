import SwiftUI

// MARK: - Profile Achievement Card Component
struct ProfileAchievementCard: View {
    let achievement: Achievement
    let theme: ThemeManager.AppTheme
    
    var body: some View {
        VStack(spacing: 12) {
            // Badge Icon
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [
                                Color.dynamicAccent(theme: theme).opacity(0.3),
                                Color.dynamicAccent(theme: theme).opacity(0.1)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 60, height: 60)
                
                Image(systemName: achievement.badgeIcon)
                    .font(.system(size: 28, weight: .bold))
                    .foregroundColor(Color.dynamicAccent(theme: theme))
            }
            
            // Achievement Info
            VStack(spacing: 4) {
                Text(achievement.name)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(Color.dynamicText(theme: theme))
                    .lineLimit(1)
                
                Text(achievement.description)
                    .font(.system(size: 11))
                    .foregroundColor(Color.dynamicText(theme: theme).opacity(0.7))
                    .lineLimit(2)
                    .multilineTextAlignment(.center)
            }
        }
        .frame(width: 120, height: 150)
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.dynamicSurface(theme: theme))
                .shadow(color: .black.opacity(0.1), radius: 5, x: 0, y: 2)
        )
    }
}

// MARK: - Profile Stat Card Component
struct ProfileStatCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color
    let theme: ThemeManager.AppTheme
    
    var body: some View {
        HStack(spacing: 12) {
            // Icon
            Image(systemName: icon)
                .font(.system(size: 24, weight: .semibold))
                .foregroundColor(color)
                .frame(width: 40, height: 40)
                .background(
                    Circle()
                        .fill(color.opacity(0.15))
                )
            
            // Text
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(Color.dynamicText(theme: theme).opacity(0.7))
                
                Text(value)
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(Color.dynamicText(theme: theme))
            }
            
            Spacer()
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.dynamicSurface(theme: theme))
        )
    }
}

// MARK: - Weekly Activity View
struct WeeklyActivityView: View {
    let weeklyData: [DayActivity]
    let theme: ThemeManager.AppTheme
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Weekly Activity")
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(Color.dynamicText(theme: theme).opacity(0.8))
            
            HStack(spacing: 6) {
                ForEach(weeklyData, id: \.dayOfWeek) { day in
                    VStack(spacing: 4) {
                        // Activity Indicator
                        RoundedRectangle(cornerRadius: 8)
                            .fill(
                                day.isActive
                                    ? Color.dynamicAccent(theme: theme)
                                    : Color.dynamicText(theme: theme).opacity(0.1)
                            )
                            .frame(width: 35, height: 35)
                            .overlay(
                                Text("\(day.workoutCount)")
                                    .font(.system(size: 14, weight: .bold))
                                    .foregroundColor(day.isActive ? .white : Color.dynamicText(theme: theme).opacity(0.3))
                            )
                        
                        Text(day.dayOfWeek)
                            .font(.system(size: 10))
                            .foregroundColor(Color.dynamicText(theme: theme).opacity(0.6))
                            .lineLimit(1)
                    }
                    .frame(maxWidth: .infinity)
                }
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color.dynamicSurface(theme: theme))
            )
        }
    }
}

// MARK: - Category Breakdown View
struct CategoryBreakdownView: View {
    let categoryData: [CategoryData]
    let theme: ThemeManager.AppTheme
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Workout Distribution")
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(Color.dynamicText(theme: theme).opacity(0.8))
            
            VStack(spacing: 12) {
                ForEach(categoryData, id: \.category) { data in
                    HStack(spacing: 12) {
                        Image(systemName: data.category.iconName)
                            .font(.system(size: 16))
                            .foregroundColor(data.category.color)
                            .frame(width: 30)
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text(data.category.displayName)
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(Color.dynamicText(theme: theme))
                            
                            GeometryReader { geometry in
                                ZStack(alignment: .leading) {
                                    RoundedRectangle(cornerRadius: 2)
                                        .fill(Color.dynamicText(theme: theme).opacity(0.1))
                                        .frame(height: 4)
                                    
                                    RoundedRectangle(cornerRadius: 2)
                                        .fill(data.category.color)
                                        .frame(width: geometry.size.width * (data.percentage / 100), height: 4)
                                }
                            }
                            .frame(height: 4)
                        }
                        
                        Text("\(Int(data.percentage))%")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(Color.dynamicText(theme: theme))
                            .frame(width: 40, alignment: .trailing)
                    }
                }
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color.dynamicSurface(theme: theme))
            )
        }
    }
}

// MARK: - Time Investment Card
struct TimeInvestmentCard: View {
    let timeInvestment: TimeInvestment
    let theme: ThemeManager.AppTheme
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Time Investment")
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(Color.dynamicText(theme: theme).opacity(0.8))
            
            HStack(spacing: 20) {
                VStack(alignment: .leading, spacing: 8) {
                    Label("\(timeInvestment.averageSessionDuration) min avg", systemImage: "timer")
                        .font(.system(size: 14))
                        .foregroundColor(Color.dynamicText(theme: theme))
                        .lineLimit(1)
                    
                    Label("\(timeInvestment.peakHour):00 peak time", systemImage: "clock.fill")
                        .font(.system(size: 14))
                        .foregroundColor(Color.dynamicText(theme: theme))
                        .lineLimit(1)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                
                Spacer()
                
                // Consistency Meter
                ZStack {
                    Circle()
                        .stroke(Color.dynamicText(theme: theme).opacity(0.1), lineWidth: 8)
                        .frame(width: 60, height: 60)
                    
                    Circle()
                        .trim(from: 0, to: timeInvestment.consistency)
                        .stroke(
                            LinearGradient(
                                colors: [Color.green, Color.dynamicAccent(theme: theme)],
                                startPoint: .leading,
                                endPoint: .trailing
                            ),
                            style: StrokeStyle(lineWidth: 8, lineCap: .round)
                        )
                        .frame(width: 60, height: 60)
                        .rotationEffect(Angle(degrees: -90))
                    
                    Text("\(Int(timeInvestment.consistency * 100))%")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(Color.dynamicText(theme: theme))
                }
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color.dynamicSurface(theme: theme))
            )
        }
    }
}

// MARK: - Leaderboard Card
struct LeaderboardCard: View {
    let entry: LeaderboardEntry
    let theme: ThemeManager.AppTheme
    
    var body: some View {
        HStack(spacing: 16) {
            // Rank
            Text(entry.rankDisplay)
                .font(.system(size: 32))
            
            // User Info
            VStack(alignment: .leading, spacing: 4) {
                Text("Your Position")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(Color.dynamicText(theme: theme).opacity(0.7))
                
                Text("\(entry.score) \(entry.category.displayName)")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(Color.dynamicText(theme: theme))
            }
            
            Spacer()
            
            // Period Badge
            Text(entry.period.displayName)
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(Color.dynamicAccent(theme: theme))
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(
                    Capsule()
                        .fill(Color.dynamicAccent(theme: theme).opacity(0.15))
                )
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.dynamicSurface(theme: theme))
        )
    }
}

// MARK: - Workout Buddy Card
struct WorkoutBuddyCard: View {
    let buddy: WorkoutBuddy
    let theme: ThemeManager.AppTheme
    
    var body: some View {
        VStack(spacing: 8) {
            // Avatar
            Circle()
                .fill(Color.dynamicAccent(theme: theme).opacity(0.2))
                .frame(width: 50, height: 50)
                .overlay(
                    Text(buddy.initials)
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(Color.dynamicAccent(theme: theme))
                )
            
            Text(buddy.name.split(separator: " ").first ?? "")
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(Color.dynamicText(theme: theme))
            
            Text("\(buddy.sharedWorkouts)")
                .font(.system(size: 16, weight: .bold))
                .foregroundColor(Color.dynamicAccent(theme: theme))
            
            Text("workouts")
                .font(.system(size: 10))
                .foregroundColor(Color.dynamicText(theme: theme).opacity(0.6))
        }
        .frame(width: 80)
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.dynamicSurface(theme: theme))
        )
    }
}

// MARK: - Personal Goal Card
struct PersonalGoalCard: View {
    let goal: PersonalGoal
    let theme: ThemeManager.AppTheme
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: goal.category.iconName)
                    .font(.system(size: 20))
                    .foregroundColor(goal.category.color)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(goal.title)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(Color.dynamicText(theme: theme))
                    
                    if let days = goal.daysRemaining, days > 0 {
                        Text("\(days) days remaining")
                            .font(.system(size: 12))
                            .foregroundColor(Color.dynamicText(theme: theme).opacity(0.6))
                    }
                }
                
                Spacer()
                
                Text("\(goal.progressPercentage)%")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(goal.category.color)
            }
            
            // Progress Bar
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.dynamicText(theme: theme).opacity(0.1))
                        .frame(height: 8)
                    
                    RoundedRectangle(cornerRadius: 4)
                        .fill(goal.category.color)
                        .frame(width: geometry.size.width * goal.progress, height: 8)
                }
            }
            .frame(height: 8)
            
            Text("\(String(format: "%.1f", goal.currentValue)) / \(String(format: "%.0f", goal.targetValue)) \(goal.unit)")
                .font(.system(size: 12))
                .foregroundColor(Color.dynamicText(theme: theme).opacity(0.7))
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.dynamicSurface(theme: theme))
        )
    }
}

// MARK: - Workout History Card
struct WorkoutHistoryCard: View {
    let workout: WorkoutHistory
    let theme: ThemeManager.AppTheme
    
    var body: some View {
        HStack(spacing: 16) {
            // Type Icon
            ZStack {
                Circle()
                    .fill(workout.type.color.opacity(0.15))
                    .frame(width: 50, height: 50)
                
                Image(systemName: workout.type.iconName)
                    .font(.system(size: 20))
                    .foregroundColor(workout.type.color)
            }
            
            // Workout Info
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(workout.className ?? workout.type.displayName)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(Color.dynamicText(theme: theme))
                    
                    Spacer()
                    
                    Text(workout.formattedDate)
                        .font(.system(size: 12))
                        .foregroundColor(Color.dynamicText(theme: theme).opacity(0.6))
                }
                
                HStack(spacing: 16) {
                    Label(workout.formattedDuration, systemImage: "clock")
                        .font(.system(size: 12))
                        .foregroundColor(Color.dynamicText(theme: theme).opacity(0.7))
                    
                    if let calories = workout.caloriesBurned {
                        Label("\(calories) cal", systemImage: "flame")
                            .font(.system(size: 12))
                            .foregroundColor(Color.dynamicText(theme: theme).opacity(0.7))
                    }
                    
                    if let trainer = workout.trainerName {
                        Label(trainer, systemImage: "person")
                            .font(.system(size: 12))
                            .foregroundColor(Color.dynamicText(theme: theme).opacity(0.7))
                    }
                }
                
                if let notes = workout.notes {
                    Text(notes)
                        .font(.system(size: 12))
                        .foregroundColor(Color.dynamicAccent(theme: theme))
                        .lineLimit(1)
                }
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.dynamicSurface(theme: theme))
        )
    }
}


// MARK: - Visual Effect Blur
struct VisualEffectBlur: UIViewRepresentable {
    var blurStyle: UIBlurEffect.Style
    
    func makeUIView(context: Context) -> UIVisualEffectView {
        return UIVisualEffectView(effect: UIBlurEffect(style: blurStyle))
    }
    
    func updateUIView(_ uiView: UIVisualEffectView, context: Context) {
        uiView.effect = UIBlurEffect(style: blurStyle)
    }
}