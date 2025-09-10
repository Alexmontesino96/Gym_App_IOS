import SwiftUI

// MARK: - Survey Admin Card
struct SurveyAdminCard: View {
    let survey: Survey
    @EnvironmentObject var themeManager: ThemeManager
    @EnvironmentObject var surveyService: SurveyService
    @State private var showingActionMenu = false
    @State private var showingStatistics = false
    @State private var showingResponses = false
    @State private var showingEditor = false
    @State private var showingExport = false
    
    // Callbacks for parent view
    var onEdit: (() -> Void)?
    var onStatistics: (() -> Void)?
    var onResponses: (() -> Void)?
    var onExport: (() -> Void)?
    var onDelete: (() -> Void)?
    
    var statusColor: Color {
        switch survey.status {
        case .draft:
            return .gray
        case .published:
            return .green
        case .closed:
            return .orange
        case .archived:
            return .red
        }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header with status badge
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(survey.title)
                        .font(.headline)
                        .foregroundColor(Color.dynamicText(theme: themeManager.currentTheme))
                        .lineLimit(1)
                    
                    if let description = survey.description {
                        Text(description)
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .lineLimit(2)
                    }
                }
                
                Spacer()
                
                // Status Badge
                Text(survey.status.displayName)
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(.white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(statusColor)
                    .cornerRadius(4)
            }
            .padding()
            
            Divider()
                .background(Color.gray.opacity(0.2))
            
            // Stats Row
            HStack(spacing: 24) {
                // Questions
                HStack(spacing: 4) {
                    Image(systemName: "questionmark.circle")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text("\(survey.questionsCount ?? 0)")
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(.secondary)
                }
                
                // Responses
                HStack(spacing: 4) {
                    Image(systemName: "person.2")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text("\(survey.responsesCount ?? 0)")
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(.secondary)
                }
                
                // Completion Rate
                if let rate = survey.completionRate {
                    HStack(spacing: 4) {
                        Image(systemName: "chart.pie")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text("\(Int(rate))%")
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundColor(.secondary)
                    }
                }
                
                Spacer()
                
                // Days Remaining or Date Info
                if survey.status == .published {
                    if let daysRemaining = survey.daysRemaining {
                        HStack(spacing: 4) {
                            Image(systemName: daysRemaining <= 3 ? "exclamationmark.triangle" : "calendar")
                                .font(.caption)
                                .foregroundColor(daysRemaining <= 3 ? .orange : .secondary)
                            Text(daysRemaining == 0 ? "Ends today" : "\(daysRemaining)d left")
                                .font(.caption)
                                .fontWeight(.medium)
                                .foregroundColor(daysRemaining <= 3 ? .orange : .secondary)
                        }
                    }
                } else if let endDate = survey.endDate {
                    Text(endDate, style: .date)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .padding()
            
            // Action Buttons Row
            HStack(spacing: 12) {
                // Statistics Button
                Button(action: {
                    showingStatistics = true
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: "chart.bar.fill")
                            .font(.caption)
                        Text("Stats")
                            .font(.caption)
                            .fontWeight(.medium)
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(Color.accentColor.opacity(0.1))
                    .foregroundColor(.accentColor)
                    .cornerRadius(6)
                }
                
                // Responses Button
                Button(action: {
                    showingResponses = true
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: "person.2.fill")
                            .font(.caption)
                        Text("Responses")
                            .font(.caption)
                            .fontWeight(.medium)
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(Color.blue.opacity(0.1))
                    .foregroundColor(.blue)
                    .cornerRadius(6)
                }
                
                // Export Button (if allowed)
                if RolePermissions.canExportSurveyData(GymService.shared.currentGym?.userRoleInGym) {
                    Button(action: {
                        showingExport = true
                    }) {
                        HStack(spacing: 4) {
                            Image(systemName: "square.and.arrow.up")
                                .font(.caption)
                            Text("Export")
                                .font(.caption)
                                .fontWeight(.medium)
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(Color.green.opacity(0.1))
                        .foregroundColor(.green)
                        .cornerRadius(6)
                    }
                }
                
                Spacer()
                
                // Action Menu
                Menu {
                    // Edit (if not archived)
                    if survey.status != .archived {
                        Button(action: { onEdit?() }) {
                            Label("Edit", systemImage: "pencil")
                        }
                    }
                    
                    // Status Actions
                    if survey.status == .draft {
                        Button(action: { 
                            Task {
                                await surveyService.publishSurvey(surveyId: survey.id)
                            }
                        }) {
                            if surveyService.isPublishingSurvey(survey.id) {
                                Label("Publishing...", systemImage: "arrow.triangle.2.circlepath")
                            } else {
                                Label("Publish", systemImage: "paperplane")
                            }
                        }
                        .disabled(surveyService.isPublishingSurvey(survey.id))
                    } else if survey.status == .published {
                        Button(action: {
                            Task {
                                await surveyService.closeSurvey(surveyId: survey.id)
                            }
                        }) {
                            Label("Close", systemImage: "xmark.circle")
                        }
                    }
                    
                    // Duplicate
                    Button(action: {
                        // TODO: Implement duplicate
                    }) {
                        Label("Duplicate", systemImage: "doc.on.doc")
                    }
                    
                    Divider()
                    
                    // Delete (if allowed and no responses)
                    if RolePermissions.canDeleteSurveys(GymService.shared.currentGym?.userRoleInGym) &&
                       (survey.responsesCount ?? 0) == 0 {
                        Button(role: .destructive, action: { onDelete?() }) {
                            Label("Delete", systemImage: "trash")
                        }
                    }
                } label: {
                    Image(systemName: "ellipsis")
                        .font(.system(size: 16))
                        .foregroundColor(.secondary)
                        .frame(width: 32, height: 32)
                        .background(Color.gray.opacity(0.1))
                        .cornerRadius(6)
                }
            }
            .padding(.horizontal)
            .padding(.bottom, 12)
        }
        .background(Color.dynamicSurface(theme: themeManager.currentTheme))
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.05), radius: 5, x: 0, y: 2)
        .sheet(isPresented: $showingStatistics) {
            SurveyStatisticsView(survey: survey)
                .environmentObject(themeManager)
                .environmentObject(surveyService)
        }
        .sheet(isPresented: $showingResponses) {
            SurveyResponsesListView(survey: survey)
                .environmentObject(themeManager)
                .environmentObject(surveyService)
        }
        .sheet(isPresented: $showingExport) {
            ExportOptionsView(survey: survey)
                .environmentObject(themeManager)
                .environmentObject(surveyService)
        }
    }
}

// MARK: - Survey Quick Stats Widget
struct SurveyQuickStats: View {
    let totalSurveys: Int
    let activeSurveys: Int
    let totalResponses: Int
    let averageCompletionRate: Double
    @EnvironmentObject var themeManager: ThemeManager
    
    var body: some View {
        HStack(spacing: 20) {
            // Total Surveys
            StatItem(
                icon: "doc.text",
                value: "\(totalSurveys)",
                label: "Surveys",
                color: .blue,
                theme: themeManager.currentTheme
            )
            
            Divider()
                .frame(height: 40)
            
            // Active Surveys
            StatItem(
                icon: "checkmark.circle",
                value: "\(activeSurveys)",
                label: "Active",
                color: .green,
                theme: themeManager.currentTheme
            )
            
            Divider()
                .frame(height: 40)
            
            // Total Responses
            StatItem(
                icon: "person.2",
                value: "\(totalResponses)",
                label: "Responses",
                color: .purple,
                theme: themeManager.currentTheme
            )
            
            Divider()
                .frame(height: 40)
            
            // Average Completion
            StatItem(
                icon: "chart.pie",
                value: "\(Int(averageCompletionRate))%",
                label: "Completion",
                color: .orange,
                theme: themeManager.currentTheme
            )
        }
        .padding()
        .background(Color.dynamicSurface(theme: themeManager.currentTheme))
        .cornerRadius(12)
    }
    
    struct StatItem: View {
        let icon: String
        let value: String
        let label: String
        let color: Color
        let theme: ThemeManager.AppTheme
        
        var body: some View {
            VStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 20))
                    .foregroundColor(color)
                
                Text(value)
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(Color.dynamicText(theme: theme))
                
                Text(label)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .frame(maxWidth: .infinity)
        }
    }
}

// MARK: - Survey Action Menu
struct SurveyActionMenu: View {
    let survey: Survey
    @EnvironmentObject var surveyService: SurveyService
    @EnvironmentObject var themeManager: ThemeManager
    @Binding var isPresented: Bool
    
    var onEdit: (() -> Void)?
    var onStatistics: (() -> Void)?
    var onExport: (() -> Void)?
    var onDuplicate: (() -> Void)?
    var onDelete: (() -> Void)?
    
    var body: some View {
        VStack(spacing: 0) {
            // Handle
            Capsule()
                .fill(Color.gray.opacity(0.3))
                .frame(width: 40, height: 4)
                .padding(.vertical, 8)
            
            // Title
            Text(survey.title)
                .font(.headline)
                .foregroundColor(Color.dynamicText(theme: themeManager.currentTheme))
                .padding()
            
            Divider()
            
            // Actions
            ScrollView {
                VStack(spacing: 0) {
                    // View Statistics
                    ActionRow(
                        icon: "chart.bar",
                        title: "View Statistics",
                        color: .blue
                    ) {
                        onStatistics?()
                        isPresented = false
                    }
                    
                    // Export Data
                    if RolePermissions.canExportSurveyData(GymService.shared.currentGym?.userRoleInGym) {
                        ActionRow(
                            icon: "arrow.down.doc",
                            title: "Export Data",
                            color: .green
                        ) {
                            onExport?()
                            isPresented = false
                        }
                    }
                    
                    // Edit
                    if survey.status != .archived {
                        ActionRow(
                            icon: "pencil",
                            title: "Edit Survey",
                            color: .orange
                        ) {
                            onEdit?()
                            isPresented = false
                        }
                    }
                    
                    // Duplicate
                    ActionRow(
                        icon: "doc.on.doc",
                        title: "Duplicate",
                        color: .purple
                    ) {
                        onDuplicate?()
                        isPresented = false
                    }
                    
                    // Status Actions removed from here - already in main menu
                    // This prevents duplicate publish buttons
                    if survey.status == .published {
                        ActionRow(
                            icon: "xmark.circle",
                            title: "Close Survey",
                            color: .orange
                        ) {
                            Task {
                                await surveyService.closeSurvey(surveyId: survey.id)
                                isPresented = false
                            }
                        }
                    }
                    
                    // Delete
                    if RolePermissions.canDeleteSurveys(GymService.shared.currentGym?.userRoleInGym) &&
                       (survey.responsesCount ?? 0) == 0 {
                        Divider()
                            .padding(.vertical, 8)
                        
                        ActionRow(
                            icon: "trash",
                            title: "Delete",
                            color: .red
                        ) {
                            onDelete?()
                            isPresented = false
                        }
                    }
                }
            }
        }
        .frame(maxHeight: 400)
        .background(Color.dynamicBackground(theme: themeManager.currentTheme))
    }
    
    struct ActionRow: View {
        let icon: String
        let title: String
        let color: Color
        let action: () -> Void
        
        var body: some View {
            Button(action: action) {
                HStack {
                    Image(systemName: icon)
                        .font(.system(size: 18))
                        .foregroundColor(color)
                        .frame(width: 24)
                    
                    Text(title)
                        .font(.body)
                        .foregroundColor(.primary)
                    
                    Spacer()
                    
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding()
                .contentShape(Rectangle())
            }
            .buttonStyle(PlainButtonStyle())
        }
    }
}