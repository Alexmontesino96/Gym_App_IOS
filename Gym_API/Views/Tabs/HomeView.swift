import SwiftUI

struct HomeView: View {
    @EnvironmentObject var themeManager: ThemeManager
    @EnvironmentObject var eventService: EventService
    @EnvironmentObject var authService: AuthServiceDirect
    @StateObject private var gymService = GymService.shared
    @State private var currentDate = Date()
    @State private var showingMyGym = false
    
    private var greeting: String {
        let hour = Calendar.current.component(.hour, from: currentDate)
        switch hour {
        case 6..<12: return "Good Morning"
        case 12..<17: return "Good Afternoon"
        case 17..<22: return "Good Evening"
        default: return "Good Night"
        }
    }
    
    private var userName: String {
        authService.user?.name.components(separatedBy: " ").first ?? "Athlete"
    }
    
    var body: some View {
        NavigationView {
            ZStack {
                Color.dynamicBackground(theme: themeManager.currentTheme).ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 24) {
                        // Hero Section
                        HeroSection(greeting: greeting, userName: userName, themeManager: themeManager)
                        
                        // Quick Access Section (4 icons in one line)
                        QuickAccessSection(themeManager: themeManager)
                        
                        // My Gym Section
                        MyGymCardSection(
                            gymService: gymService,
                            showingMyGym: $showingMyGym,
                            themeManager: themeManager
                        )
                        
                        // Stats Overview
                        StatsOverviewSection(themeManager: themeManager)
                        
                        // Upcoming Events
                        if !eventService.events.isEmpty {
                            UpcomingEventsSection(events: eventService.events, themeManager: themeManager)
                        }
                        
                        // Motivational Quote
                        MotivationalSection(themeManager: themeManager)
                        
                        Spacer(minLength: 100)
                    }
                }
            }
            .refreshable {
                await eventService.fetchEvents()
            }
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        themeManager.toggleTheme()
                    }) {
                        Image(systemName: themeManager.currentTheme == .dark ? "sun.max.fill" : "moon.fill")
                            .font(.system(size: 18))
                            .foregroundColor(Color.dynamicAccent(theme: themeManager.currentTheme))
                    }
                }
            }
        }
        .onAppear {
            currentDate = Date()
            setupServices()
            Task {
                await eventService.fetchEvents()
                await gymService.getMyGyms()
            }
        }
        .sheet(isPresented: $showingMyGym) {
            MyGymView()
                .environmentObject(themeManager)
                .environmentObject(authService)
        }
    }
    
    private func setupServices() {
        gymService.authService = authService
    }
}

// MARK: - Hero Section
struct HeroSection: View {
    let greeting: String
    let userName: String
    let themeManager: ThemeManager
    
    var body: some View {
        VStack(spacing: 16) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(greeting)
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(Color.dynamicTextSecondary(theme: themeManager.currentTheme))
                    
                    Text(userName)
                        .font(.system(size: 32, weight: .bold))
                        .foregroundColor(Color.dynamicText(theme: themeManager.currentTheme))
                }
                
                Spacer()
                
                // Fitness icon
                ZStack {
                    Circle()
                        .fill(Color.dynamicAccent(theme: themeManager.currentTheme).opacity(0.15))
                        .frame(width: 50, height: 50)
                    
                    Image(systemName: "figure.boxing")
                        .font(.system(size: 24, weight: .semibold))
                        .foregroundColor(Color.dynamicAccent(theme: themeManager.currentTheme))
                }
            }
            
            HStack {
                Text("Ready to crush your goals today?")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(Color.dynamicTextSecondary(theme: themeManager.currentTheme))
                Spacer()
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 10)
    }
}

// MARK: - Quick Access Section
struct QuickAccessSection: View {
    let themeManager: ThemeManager
    
    private let quickAccessItems = [
        QuickAccessItem(icon: "dumbbell.fill", title: "Classes", color: .blue),
        QuickAccessItem(icon: "calendar.circle.fill", title: "Events", color: .green),
        QuickAccessItem(icon: "message.circle.fill", title: "Chat", color: .purple),
        QuickAccessItem(icon: "person.circle.fill", title: "Profile", color: .orange)
    ]
    
    var body: some View {
        VStack(spacing: 16) {
            HStack {
                Text("Quick Access")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(Color.dynamicText(theme: themeManager.currentTheme))
                Spacer()
            }
            .padding(.horizontal, 20)
            
            // Quick access card with 4 icons
            ZStack {
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color.dynamicSurface(theme: themeManager.currentTheme))
                    .shadow(
                        color: Color.black.opacity(themeManager.currentTheme == .dark ? 0.25 : 0.1),
                        radius: 6,
                        x: 0,
                        y: 3
                    )
                
                HStack(spacing: 0) {
                    ForEach(quickAccessItems, id: \.title) { item in
                        QuickAccessButtonNew(item: item, themeManager: themeManager)
                        
                        // Divider between items (except last)
                        if item.title != quickAccessItems.last?.title {
                            Rectangle()
                                .fill(Color.dynamicTextSecondary(theme: themeManager.currentTheme).opacity(0.2))
                                .frame(width: 1, height: 40)
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 20)
            }
            .padding(.horizontal, 20)
        }
    }
}

struct QuickAccessButtonNew: View {
    let item: QuickAccessItem
    let themeManager: ThemeManager
    
    var body: some View {
        VStack(spacing: 10) {
            ZStack {
                Circle()
                    .fill(item.color.opacity(0.15))
                    .frame(width: 40, height: 40)
                
                Image(systemName: item.icon)
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundColor(item.color)
            }
            
            Text(item.title)
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(Color.dynamicTextSecondary(theme: themeManager.currentTheme))
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Stats Overview Section
struct StatsOverviewSection: View {
    let themeManager: ThemeManager
    
    var body: some View {
        VStack(spacing: 16) {
            HStack {
                Text("This Week")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(Color.dynamicText(theme: themeManager.currentTheme))
                Spacer()
            }
            .padding(.horizontal, 20)
            
            HStack(spacing: 12) {
                StatCard(
                    icon: "flame.fill",
                    title: "Classes",
                    value: "5",
                    color: .red,
                    themeManager: themeManager
                )
                
                StatCard(
                    icon: "calendar.badge.checkmark",
                    title: "Events",
                    value: "2",
                    color: .green,
                    themeManager: themeManager
                )
                
                StatCard(
                    icon: "clock.fill",
                    title: "Hours",
                    value: "8.5",
                    color: .blue,
                    themeManager: themeManager
                )
            }
            .padding(.horizontal, 20)
        }
    }
}

struct StatCard: View {
    let icon: String
    let title: String
    let value: String
    let color: Color
    let themeManager: ThemeManager
    
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.dynamicSurface(theme: themeManager.currentTheme))
                .shadow(
                    color: Color.black.opacity(themeManager.currentTheme == .dark ? 0.25 : 0.1),
                    radius: 6,
                    x: 0,
                    y: 3
                )
            
            VStack(spacing: 12) {
                HStack {
                    ZStack {
                        Circle()
                            .fill(color.opacity(0.15))
                            .frame(width: 32, height: 32)
                        
                        Image(systemName: icon)
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(color)
                    }
                    Spacer()
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(value)
                            .font(.system(size: 24, weight: .bold))
                            .foregroundColor(Color.dynamicText(theme: themeManager.currentTheme))
                        Spacer()
                    }
                    
                    HStack {
                        Text(title)
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(Color.dynamicTextSecondary(theme: themeManager.currentTheme))
                        Spacer()
                    }
                }
            }
            .padding(16)
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Upcoming Events Section
struct UpcomingEventsSection: View {
    let events: [Event]
    let themeManager: ThemeManager
    
    private var upcomingEvents: [Event] {
        events.filter { $0.startTime > Date() }
              .sorted { $0.startTime < $1.startTime }
              .prefix(3)
              .map { $0 }
    }
    
    var body: some View {
        if !upcomingEvents.isEmpty {
            VStack(spacing: 16) {
                HStack {
                    Text("Upcoming Events")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundColor(Color.dynamicText(theme: themeManager.currentTheme))
                    Spacer()
                    
                    NavigationLink(destination: EventsView()) {
                        Text("See All")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(Color.dynamicAccent(theme: themeManager.currentTheme))
                    }
                }
                .padding(.horizontal, 20)
                
                // Events container with app style
                ZStack {
                    RoundedRectangle(cornerRadius: 16)
                        .fill(Color.dynamicSurface(theme: themeManager.currentTheme))
                        .shadow(
                            color: Color.black.opacity(themeManager.currentTheme == .dark ? 0.25 : 0.1),
                            radius: 6,
                            x: 0,
                            y: 3
                        )
                    
                    VStack(spacing: 12) {
                        ForEach(Array(upcomingEvents.enumerated()), id: \.element.id) { index, event in
                            CompactEventRow(event: event, themeManager: themeManager)
                            
                            // Divider between events (except last)
                            if index < upcomingEvents.count - 1 {
                                Rectangle()
                                    .fill(Color.dynamicTextSecondary(theme: themeManager.currentTheme).opacity(0.2))
                                    .frame(height: 1)
                                    .padding(.horizontal, 16)
                            }
                        }
                    }
                    .padding(16)
                }
                .padding(.horizontal, 20)
            }
        }
    }
}

// MARK: - Compact Event Row
struct CompactEventRow: View {
    let event: Event
    let themeManager: ThemeManager
    
    private var timeFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"
        formatter.timeZone = TimeZone.current // Usar zona horaria local
        return formatter
    }
    
    private var dateFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d"
        formatter.timeZone = TimeZone.current // Usar zona horaria local
        return formatter
    }
    
    var body: some View {
        HStack(spacing: 16) {
            // Left accent line
            Rectangle()
                .fill(Color.dynamicAccent(theme: themeManager.currentTheme))
                .frame(width: 4, height: 40)
                .cornerRadius(2)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(event.title)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(Color.dynamicText(theme: themeManager.currentTheme))
                    .lineLimit(1)
                
                HStack(spacing: 8) {
                    Text(dateFormatter.string(from: event.startTime))
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(Color.dynamicTextSecondary(theme: themeManager.currentTheme))
                    
                    Text("•")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(Color.dynamicTextSecondary(theme: themeManager.currentTheme))
                    
                    Text(timeFormatter.string(from: event.startTime))
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(Color.dynamicTextSecondary(theme: themeManager.currentTheme))
                }
            }
            
            Spacer()
            
            // Status indicator
            ZStack {
                Circle()
                    .fill(Color.green.opacity(0.15))
                    .frame(width: 24, height: 24)
                
                Circle()
                    .fill(Color.green)
                    .frame(width: 8, height: 8)
            }
        }
    }
}

// MARK: - Motivational Section
struct MotivationalSection: View {
    let themeManager: ThemeManager
    
    private let quotes = [
        "Push yourself because no one else is going to do it for you.",
        "Your only limit is your mind.",
        "Great things never come from comfort zones.",
        "Success starts with self-discipline.",
        "Be stronger than your strongest excuse."
    ]
    
    var body: some View {
        VStack(spacing: 16) {
            HStack {
                Text("Daily Motivation")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(Color.dynamicText(theme: themeManager.currentTheme))
                Spacer()
            }
            .padding(.horizontal, 20)
            
            ZStack {
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color.dynamicAccent(theme: themeManager.currentTheme))
                    .shadow(
                        color: Color.dynamicAccent(theme: themeManager.currentTheme).opacity(0.3),
                        radius: 8,
                        x: 0,
                        y: 4
                    )
                
                HStack(spacing: 16) {
                    // Quote icon
                    ZStack {
                        Circle()
                            .fill(Color.white.opacity(0.2))
                            .frame(width: 50, height: 50)
                        
                        Image(systemName: "quote.bubble.fill")
                            .font(.system(size: 24, weight: .semibold))
                            .foregroundColor(.white)
                    }
                    
                    VStack(alignment: .leading, spacing: 8) {
                        Text(quotes.randomElement() ?? quotes[0])
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.white)
                            .multilineTextAlignment(.leading)
                            .lineSpacing(2)
                        
                        Text("- Stay Motivated")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundColor(.white.opacity(0.8))
                            .textCase(.uppercase)
                            .tracking(0.5)
                    }
                    
                    Spacer()
                }
                .padding(20)
            }
            .padding(.horizontal, 20)
        }
    }
}

// MARK: - My Gym Card Section
struct MyGymCardSection: View {
    @ObservedObject var gymService: GymService
    @Binding var showingMyGym: Bool
    let themeManager: ThemeManager
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("My Gym")
                .font(.system(size: 20, weight: .semibold))
                .foregroundColor(Color.dynamicText(theme: themeManager.currentTheme))
                .padding(.horizontal, 20)
            
            if gymService.isLoadingGyms {
                // Loading state with pulse animation
                HStack {
                    Spacer()
                    PulseLoadingView(message: "Loading gym...", themeManager: themeManager)
                    Spacer()
                }
                .frame(height: 100)
                .background(Color.dynamicSurface(theme: themeManager.currentTheme))
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .padding(.horizontal, 20)
            } else if let gym = gymService.currentGym {
                // Gym card
                Button(action: { showingMyGym = true }) {
                    HStack(spacing: 16) {
                        // Gym icon
                        ZStack {
                            Circle()
                                .fill(Color.dynamicAccent(theme: themeManager.currentTheme).opacity(0.1))
                                .frame(width: 60, height: 60)
                            
                            Image(systemName: "building.2.fill")
                                .font(.system(size: 28, weight: .semibold))
                                .foregroundColor(Color.dynamicAccent(theme: themeManager.currentTheme))
                        }
                        
                        VStack(alignment: .leading, spacing: 6) {
                            Text(gym.name)
                                .font(.system(size: 18, weight: .semibold))
                                .foregroundColor(Color.dynamicText(theme: themeManager.currentTheme))
                                .lineLimit(1)
                            
                            HStack(spacing: 6) {
                                Image(systemName: gym.roleIcon)
                                    .font(.system(size: 12))
                                Text(gym.roleDisplayName)
                                    .font(.system(size: 14))
                            }
                            .foregroundColor(Color.dynamicTextSecondary(theme: themeManager.currentTheme))
                            
                            HStack(spacing: 4) {
                                Circle()
                                    .fill(gym.isActive ? Color.green : Color.red)
                                    .frame(width: 6, height: 6)
                                Text(gym.statusText)
                                    .font(.system(size: 12))
                                    .foregroundColor(gym.isActive ? Color.green : Color.red)
                            }
                        }
                        
                        Spacer()
                        
                        Image(systemName: "chevron.right")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(Color.dynamicTextSecondary(theme: themeManager.currentTheme))
                    }
                    .padding(16)
                    .background(Color.dynamicSurface(theme: themeManager.currentTheme))
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                    .shadow(
                        color: Color.black.opacity(themeManager.currentTheme == .dark ? 0.3 : 0.08),
                        radius: 8,
                        x: 0,
                        y: 2
                    )
                }
                .buttonStyle(PlainButtonStyle())
                .padding(.horizontal, 20)
            } else {
                // No gym state
                HStack(spacing: 16) {
                    Image(systemName: "building.2")
                        .font(.system(size: 28))
                        .foregroundColor(Color.dynamicTextSecondary(theme: themeManager.currentTheme))
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text("No gym associated")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(Color.dynamicText(theme: themeManager.currentTheme))
                        
                        Text("Contact your gym to get added")
                            .font(.system(size: 14))
                            .foregroundColor(Color.dynamicTextSecondary(theme: themeManager.currentTheme))
                    }
                    
                    Spacer()
                }
                .padding(16)
                .background(Color.dynamicSurface(theme: themeManager.currentTheme))
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .padding(.horizontal, 20)
            }
        }
    }
}

#Preview {
    HomeView()
        .environmentObject(ThemeManager())
        .environmentObject(EventService())
        .environmentObject(AuthServiceDirect())
}