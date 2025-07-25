import SwiftUI

struct HomeView: View {
    @EnvironmentObject var themeManager: ThemeManager
    @EnvironmentObject var eventService: EventService
    @State private var userName = "Alex"
    
    var body: some View {
        NavigationView {
            ZStack {
                Color.dynamicBackground(theme: themeManager.currentTheme).ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 30) {
                        // Welcome Section
                        HStack {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Hola, \(userName).")
                                    .font(.system(size: 28, weight: .bold))
                                    .foregroundColor(Color.dynamicText(theme: themeManager.currentTheme))
                                
                                Text("Ready for your next class?")
                                    .font(.system(size: 16, weight: .medium))
                                    .foregroundColor(Color.dynamicTextSecondary(theme: themeManager.currentTheme))
                            }
                            
                            Spacer()
                            
                            Image(systemName: "figure.boxing")
                                .font(.system(size: 40))
                                .foregroundColor(Color.dynamicAccent(theme: themeManager.currentTheme))
                        }
                        .padding(.horizontal, 20)
                        .padding(.top, 20)
                        
                        // Next Class Section
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Next Class")
                                .font(.system(size: 18, weight: .semibold))
                                .foregroundColor(Color.dynamicText(theme: themeManager.currentTheme))
                                .padding(.horizontal, 20)
                            
                            ClassCard(
                                title: "Boxing Fundamentals",
                                time: "6:00 PM",
                                instructor: "Carlos Rodriguez"
                            )
                            .padding(.horizontal, 20)
                        }
                        
                        // Quick Access Section
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Quick Access")
                                .font(.system(size: 18, weight: .semibold))
                                .foregroundColor(Color.dynamicText(theme: themeManager.currentTheme))
                                .padding(.horizontal, 20)
                            
                            QuickAccessGrid()
                                .padding(.horizontal, 20)
                        }
                        
                        // Upcoming Events Section
                        if let nextEvent = eventService.events.filter({ $0.startTime > Date() }).sorted(by: { $0.startTime < $1.startTime }).first {
                            VStack(alignment: .leading, spacing: 12) {
                                Text("Upcoming Event")
                                    .font(.system(size: 18, weight: .semibold))
                                    .foregroundColor(Color.dynamicText(theme: themeManager.currentTheme))
                                    .padding(.horizontal, 20)
                                
                                EventCard(event: nextEvent)
                                    .padding(.horizontal, 20)
                            }
                        }
                        
                        // Recent Activity Section
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Recent Activity")
                                .font(.system(size: 18, weight: .semibold))
                                .foregroundColor(Color.dynamicText(theme: themeManager.currentTheme))
                                .padding(.horizontal, 20)
                            
                            RecentActivityCard()
                                .padding(.horizontal, 20)
                        }
                        
                        Spacer(minLength: 100)
                    }
                }
            }
            .refreshable {
                await eventService.loadEvents()
            }
            .navigationTitle("Home")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    NavigationLink(destination: ThemeSettingsView()) {
                        Image(systemName: themeManager.currentTheme == .dark ? "moon.fill" : "sun.max.fill")
                            .font(.system(size: 18))
                            .foregroundColor(Color.dynamicAccent(theme: themeManager.currentTheme))
                    }
                }
            }
        }
        .onAppear {
            Task {
                await eventService.loadEvents()
            }
        }
    }
}

#Preview {
    HomeView()
        .environmentObject(ThemeManager())
        .environmentObject(EventService())
}