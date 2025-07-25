import SwiftUI

struct ClassesView: View {
    @EnvironmentObject var authService: AuthServiceDirect
    @EnvironmentObject var classService: ClassService
    @EnvironmentObject var themeManager: ThemeManager
    @State private var selectedDate = Date()
    
    var body: some View {
        NavigationView {
            ZStack {
                Color.dynamicBackground(theme: themeManager.currentTheme).ignoresSafeArea()
                
                if classService.isLoading {
                    ProgressView("Loading classes...")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(Color.dynamicText(theme: themeManager.currentTheme))
                } else if classService.classes.isEmpty {
                    VStack(spacing: 16) {
                        Image(systemName: "calendar.badge.exclamationmark")
                            .font(.system(size: 48))
                            .foregroundColor(Color.dynamicTextSecondary(theme: themeManager.currentTheme))
                        
                        Text("No classes available")
                            .font(.system(size: 18, weight: .medium))
                            .foregroundColor(Color.dynamicTextSecondary(theme: themeManager.currentTheme))
                        
                        Text("Check back later for new classes")
                            .font(.system(size: 14))
                            .foregroundColor(Color.dynamicTextSecondary(theme: themeManager.currentTheme).opacity(0.7))
                    }
                } else {
                    ScrollView {
                        LazyVStack(spacing: 16) {
                            ForEach(classService.classes) { gymClass in
                                ClassCardView(gymClass: gymClass)
                                    .padding(.horizontal, 20)
                            }
                        }
                        .padding(.vertical, 20)
                    }
                }
            }
            .navigationTitle("Classes")
            .navigationBarTitleDisplayMode(.large)
        }
        .onAppear {
            Task {
                await classService.loadClasses()
            }
        }
    }
}

#Preview {
    ClassesView()
        .environmentObject(AuthServiceDirect())
        .environmentObject(ClassService())
        .environmentObject(ThemeManager())
}