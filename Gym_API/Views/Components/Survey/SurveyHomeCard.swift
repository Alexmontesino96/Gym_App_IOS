import SwiftUI

struct SurveyHomeCard: View {
    @EnvironmentObject var surveyService: SurveyService
    @EnvironmentObject var themeManager: ThemeManager
    @State private var showingSurveyList = false
    @State private var selectedSurvey: Survey?
    
    var availableSurveyCount: Int {
        surveyService.availableSurveys.filter { $0.isAvailable }.count
    }
    
    var nextSurvey: Survey? {
        surveyService.availableSurveys
            .filter { $0.isAvailable }
            .sorted { 
                // Priorizar por fecha de finalización más próxima
                let date1 = $0.endDate ?? Date.distantFuture
                let date2 = $1.endDate ?? Date.distantFuture
                return date1 < date2
            }
            .first
    }
    
    var body: some View {
        if availableSurveyCount > 0, let survey = nextSurvey {
            VStack(alignment: .leading, spacing: 12) {
                // Header
                HStack {
                    HStack(spacing: 8) {
                        Image(systemName: "doc.text.magnifyingglass")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.white)
                            .frame(width: 32, height: 32)
                            .background(
                                LinearGradient(
                                    gradient: Gradient(colors: [Color.blue, Color.purple]),
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .cornerRadius(8)
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Surveys")
                                .font(.headline)
                                .foregroundColor(Color.dynamicText(theme: themeManager.currentTheme))
                            
                            if availableSurveyCount > 1 {
                                Text("\(availableSurveyCount) available")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                    
                    Spacer()
                    
                    Button(action: {
                        showingSurveyList = true
                    }) {
                        Text("View All")
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundColor(.accentColor)
                    }
                }
                
                Divider()
                    .background(Color.gray.opacity(0.3))
                
                // Survey Preview
                VStack(alignment: .leading, spacing: 8) {
                    Text(survey.title)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(Color.dynamicText(theme: themeManager.currentTheme))
                        .lineLimit(2)
                    
                    HStack(spacing: 16) {
                        // Questions count
                        HStack(spacing: 4) {
                            Image(systemName: "questionmark.circle")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Text("\(survey.questionsCount ?? 0) questions")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        // Time estimate
                        HStack(spacing: 4) {
                            Image(systemName: "clock")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Text(survey.formattedEstimatedTime)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    // Urgency indicator
                    if let daysRemaining = survey.daysRemaining, daysRemaining <= 3 {
                        HStack(spacing: 4) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .font(.caption)
                                .foregroundColor(.orange)
                            Text(daysRemaining == 0 ? "Last day to respond!" : "Only \(daysRemaining) days left")
                                .font(.caption)
                                .fontWeight(.medium)
                                .foregroundColor(.orange)
                        }
                        .padding(.top, 4)
                    }
                }
                
                // Action Button
                Button(action: {
                    print("🎯 Take Survey button tapped")
                    print("   Survey: \(survey.title) (ID: \(survey.id))")
                    print("   Status: \(survey.status.rawValue)")
                    selectedSurvey = survey
                    print("   selectedSurvey set to: \(survey.title)")
                }) {
                    HStack {
                        Text("Take Survey")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                        Image(systemName: "arrow.right")
                            .font(.caption)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(
                        LinearGradient(
                            gradient: Gradient(colors: [Color.blue.opacity(0.8), Color.purple.opacity(0.8)]),
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .foregroundColor(.white)
                    .cornerRadius(8)
                }
            }
            .padding()
            .background(Color.dynamicSurface(theme: themeManager.currentTheme))
            .cornerRadius(12)
            .shadow(color: Color.black.opacity(0.05), radius: 5, x: 0, y: 2)
            .sheet(isPresented: $showingSurveyList) {
                SurveyListView()
                    .environmentObject(surveyService)
                    .environmentObject(themeManager)
            }
            .sheet(item: $selectedSurvey) { survey in
                let _ = print("📄 Sheet is presenting SurveyResponseView")
                let _ = print("   Selected Survey: \(survey.title) (ID: \(survey.id))")
                SurveyResponseView(survey: survey)
                    .environmentObject(surveyService)
                    .environmentObject(themeManager)
            }
            .onAppear {
                if surveyService.availableSurveys.isEmpty {
                    Task {
                        await surveyService.getAvailableSurveys()
                    }
                }
            }
        }
    }
}

// MARK: - Mini Survey Indicator
struct SurveyIndicator: View {
    let count: Int
    @EnvironmentObject var themeManager: ThemeManager
    @State private var showingSurveyList = false
    
    var body: some View {
        if count > 0 {
            Button(action: {
                showingSurveyList = true
            }) {
                HStack(spacing: 6) {
                    Image(systemName: "doc.text.magnifyingglass")
                        .font(.system(size: 14, weight: .medium))
                    
                    Text("\(count) survey\(count == 1 ? "" : "s")")
                        .font(.system(size: 12, weight: .medium))
                    
                    Image(systemName: "chevron.right")
                        .font(.system(size: 10, weight: .semibold))
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(
                    Capsule()
                        .fill(LinearGradient(
                            gradient: Gradient(colors: [Color.blue.opacity(0.9), Color.purple.opacity(0.9)]),
                            startPoint: .leading,
                            endPoint: .trailing
                        ))
                )
                .foregroundColor(.white)
                .shadow(color: Color.black.opacity(0.1), radius: 3, x: 0, y: 2)
            }
            .buttonStyle(PlainButtonStyle())
            .sheet(isPresented: $showingSurveyList) {
                SurveyListView()
            }
        }
    }
}