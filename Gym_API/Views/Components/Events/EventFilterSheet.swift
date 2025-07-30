import SwiftUI

struct EventFilterSheet: View {
    @EnvironmentObject var themeManager: ThemeManager
    @Binding var selectedFilter: EventFilter
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            VStack(spacing: 16) {
                // Filter Options - Más compacto
                VStack(spacing: 12) {
                    ForEach(EventFilter.allCases, id: \.self) { filter in
                        CompactFilterOption(
                            filter: filter,
                            isSelected: selectedFilter == filter,
                            themeManager: themeManager
                        ) {
                            selectedFilter = filter
                        }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 10)
                
                // Apply Button - Más compacto
                Button(action: {
                    dismiss()
                }) {
                    Text("Apply Filter")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 44)
                        .background(Color.dynamicAccent(theme: themeManager.currentTheme))
                        .cornerRadius(12)
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 20)
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

struct CompactFilterOption: View {
    let filter: EventFilter
    let isSelected: Bool
    let themeManager: ThemeManager
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                // Filter Icon - Más pequeño
                Image(systemName: filter.iconName)
                    .font(.system(size: 20))
                    .foregroundColor(isSelected ? .white : Color.dynamicAccent(theme: themeManager.currentTheme))
                    .frame(width: 36, height: 36)
                    .background(
                        Circle()
                            .fill(isSelected ? Color.dynamicAccent(theme: themeManager.currentTheme) : Color.dynamicAccent(theme: themeManager.currentTheme).opacity(0.2))
                    )
                
                // Filter Info - Solo título
                VStack(alignment: .leading, spacing: 2) {
                    HStack {
                        Text(filter.displayName)
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(Color.dynamicText(theme: themeManager.currentTheme))
                        
                        Spacer()
                        
                        if isSelected {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(Color.dynamicAccent(theme: themeManager.currentTheme))
                                .font(.system(size: 18))
                        }
                    }
                }
                
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
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