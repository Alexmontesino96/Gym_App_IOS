import SwiftUI

struct EventFilterSheet: View {
    @EnvironmentObject var themeManager: ThemeManager
    @Binding var selectedFilter: EventFilter
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            VStack(spacing: 24) {
                // Header
                VStack(spacing: 8) {
                    Image(systemName: "line.3.horizontal.decrease.circle.fill")
                        .font(.system(size: 50))
                        .foregroundColor(Color.dynamicAccent(theme: themeManager.currentTheme))
                    
                    Text("Filter Events")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                        .foregroundColor(Color.dynamicText(theme: themeManager.currentTheme))
                    
                    Text("Choose which events to show")
                        .font(.subheadline)
                        .foregroundColor(Color.dynamicTextSecondary(theme: themeManager.currentTheme))
                }
                .padding(.top, 20)
                
                // Filter Options
                VStack(spacing: 16) {
                    ForEach(EventFilter.allCases, id: \.self) { filter in
                        FilterOption(
                            filter: filter,
                            isSelected: selectedFilter == filter,
                            themeManager: themeManager
                        ) {
                            selectedFilter = filter
                        }
                    }
                }
                .padding(.horizontal, 20)
                
                Spacer()
                
                // Apply Button
                Button(action: {
                    dismiss()
                }) {
                    Text("Apply Filter")
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                        .background(Color.dynamicAccent(theme: themeManager.currentTheme))
                        .cornerRadius(12)
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 30)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color.dynamicBackground(theme: themeManager.currentTheme))
            .navigationTitle("Filtros")
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarBackButtonHidden(true)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Close") {
                        dismiss()
                    }
                    .foregroundColor(Color.dynamicAccent(theme: themeManager.currentTheme))
                }
            }
        }
    }
}

struct FilterOption: View {
    let filter: EventFilter
    let isSelected: Bool
    let themeManager: ThemeManager
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 16) {
                // Filter Icon
                Image(systemName: filter.iconName)
                    .font(.system(size: 24))
                    .foregroundColor(isSelected ? .white : Color.dynamicAccent(theme: themeManager.currentTheme))
                    .frame(width: 48, height: 48)
                    .background(
                        Circle()
                            .fill(isSelected ? Color.dynamicAccent(theme: themeManager.currentTheme) : Color.dynamicAccent(theme: themeManager.currentTheme).opacity(0.2))
                    )
                
                // Filter Info
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(filter.displayName)
                            .font(.headline)
                            .foregroundColor(Color.dynamicText(theme: themeManager.currentTheme))
                        
                        Spacer()
                        
                        if isSelected {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(Color.dynamicAccent(theme: themeManager.currentTheme))
                                .font(.title2)
                        }
                    }
                    
                    Text(filter.description)
                        .font(.subheadline)
                        .foregroundColor(Color.dynamicTextSecondary(theme: themeManager.currentTheme))
                }
                
                Spacer()
            }
            .padding(16)
            .background(Color.dynamicSurface(theme: themeManager.currentTheme))
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(
                        isSelected ? Color.dynamicAccent(theme: themeManager.currentTheme) : Color.dynamicBorder(theme: themeManager.currentTheme),
                        lineWidth: isSelected ? 2 : 1
                    )
            )
            .scaleEffect(isSelected ? 1.02 : 1.0)
            .animation(.easeInOut(duration: 0.2), value: isSelected)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

enum EventFilter: String, CaseIterable {
    case available = "available"
    case past = "past"
    case joined = "joined"
    
    var displayName: String {
        switch self {
        case .available: return "Available"
        case .past: return "Past Events"
        case .joined: return "Joined"
        }
    }
    
    var description: String {
        switch self {
        case .available: return "Show upcoming events you can join"
        case .past: return "Show events that have already happened"
        case .joined: return "Show events you have joined"
        }
    }
    
    var iconName: String {
        switch self {
        case .available: return "calendar.badge.plus"
        case .past: return "calendar.badge.clock"
        case .joined: return "calendar.badge.checkmark"
        }
    }
}

#Preview {
    EventFilterSheet(selectedFilter: .constant(.available))
        .environmentObject(ThemeManager())
}