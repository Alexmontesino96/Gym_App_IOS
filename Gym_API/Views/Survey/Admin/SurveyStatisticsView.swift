import SwiftUI
import Charts

struct SurveyStatisticsView: View {
    @EnvironmentObject var themeManager: ThemeManager
    @EnvironmentObject var surveyService: SurveyService
    @Environment(\.dismiss) var dismiss
    
    let survey: Survey
    @State private var statistics: SurveyStatistics?
    @State private var isLoading = true
    @State private var errorMessage: String?
    @State private var selectedTimeRange: TimeRange = .week
    @State private var showingExportOptions = false
    
    enum TimeRange: String, CaseIterable {
        case week = "Week"
        case month = "Month"
        case all = "All Time"
    }
    
    var body: some View {
        NavigationView {
            ZStack {
                Color.dynamicBackground(theme: themeManager.currentTheme)
                    .ignoresSafeArea()
                
                if isLoading {
                    ProgressView("Loading statistics...")
                        .progressViewStyle(CircularProgressViewStyle(tint: .accentColor))
                        .scaleEffect(1.2)
                } else if let error = errorMessage {
                    VStack(spacing: 20) {
                        Image(systemName: "exclamationmark.triangle")
                            .font(.system(size: 50))
                            .foregroundColor(.red)
                        
                        Text("Error loading statistics")
                            .font(.title2)
                            .fontWeight(.semibold)
                        
                        Text(error)
                            .font(.body)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                        
                        Button(action: loadStatistics) {
                            Label("Retry", systemImage: "arrow.clockwise")
                                .padding(.horizontal, 20)
                                .padding(.vertical, 10)
                                .background(Color.accentColor)
                                .foregroundColor(.white)
                                .cornerRadius(10)
                        }
                    }
                } else if let stats = statistics {
                    ScrollView {
                        VStack(spacing: 20) {
                            // Metrics Header
                            metricsHeader(stats)
                            
                            // Response Timeline
                            if let responsesByDate = stats.responsesByDate, !responsesByDate.isEmpty {
                                responseTimelineChart(responsesByDate)
                            }
                            
                            // Completion Rate Gauge
                            completionRateGauge(stats)
                            
                            // NPS Score (if applicable)
                            if let npsScore = stats.npsScore, isValidNumber(npsScore) {
                                npsScoreCard(npsScore)
                            }
                            
                            // Question Statistics
                            questionStatisticsSection(stats)
                            
                            // Export Button
                            exportButton()
                        }
                        .padding()
                    }
                }
            }
            .navigationTitle("\(survey.title) Statistics")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Close") { dismiss() }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Menu {
                        ForEach(TimeRange.allCases, id: \.self) { range in
                            Button(action: { selectedTimeRange = range }) {
                                Label(range.rawValue, systemImage: selectedTimeRange == range ? "checkmark" : "")
                            }
                        }
                    } label: {
                        Image(systemName: "calendar")
                    }
                }
            }
        }
        .onAppear {
            loadStatistics()
        }
        .sheet(isPresented: $showingExportOptions) {
            ExportOptionsView(survey: survey)
                .environmentObject(themeManager)
                .environmentObject(surveyService)
        }
    }
    
    // MARK: - Metrics Header
    private func metricsHeader(_ stats: SurveyStatistics) -> some View {
        HStack(spacing: 15) {
            metricCard(
                title: "Total Responses",
                value: "\(stats.totalResponses)",
                icon: "person.3.fill",
                color: .blue
            )
            
            metricCard(
                title: "Completed",
                value: "\(stats.completeResponses)",
                icon: "checkmark.circle.fill",
                color: .green
            )
            
            if let avgTime = stats.averageCompletionTime {
                metricCard(
                    title: "Avg Time",
                    value: formatTime(avgTime),
                    icon: "clock.fill",
                    color: .orange
                )
            }
        }
    }
    
    private func metricCard(title: String, value: String, icon: String, color: Color) -> some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(color)
            
            Text(value)
                .font(.title)
                .fontWeight(.bold)
                .foregroundColor(Color.dynamicText(theme: themeManager.currentTheme))
            
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.dynamicSurface(theme: themeManager.currentTheme))
                .shadow(color: .black.opacity(0.1), radius: 5, x: 0, y: 2)
        )
    }
    
    // MARK: - Response Timeline Chart
    private func responseTimelineChart(_ data: [String: Int]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Response Timeline")
                .font(.headline)
                .foregroundColor(Color.dynamicText(theme: themeManager.currentTheme))
            
            Chart {
                ForEach(Array(data.sorted(by: { $0.key < $1.key })), id: \.key) { date, count in
                    BarMark(
                        x: .value("Date", formatChartDate(date)),
                        y: .value("Responses", count)
                    )
                    .foregroundStyle(Color.accentColor.gradient)
                }
            }
            .frame(height: 200)
            .chartXAxis {
                AxisMarks(values: .automatic) { _ in
                    AxisValueLabel(orientation: .vertical)
                }
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.dynamicSurface(theme: themeManager.currentTheme))
                .shadow(color: .black.opacity(0.1), radius: 5, x: 0, y: 2)
        )
    }
    
    // MARK: - Helper Functions for Safe Values
    private func safeCompletionRate(_ rate: Double?) -> Double {
        guard let rate = rate else { return 0 }
        // Ensure rate is between 0 and 100
        return min(max(rate, 0), 100)
    }
    
    private func safeNPSScore(_ score: Double?) -> Double {
        guard let score = score else { return 0 }
        // NPS score should be between -100 and 100
        return min(max(score, -100), 100)
    }
    
    private func isValidNumber(_ value: Double) -> Bool {
        return !value.isNaN && !value.isInfinite
    }
    
    // MARK: - Completion Rate Gauge
    private func completionRateGauge(_ stats: SurveyStatistics) -> some View {
        VStack(spacing: 16) {
            Text("Completion Rate")
                .font(.headline)
                .foregroundColor(Color.dynamicText(theme: themeManager.currentTheme))
            
            ZStack {
                Circle()
                    .stroke(Color.gray.opacity(0.2), lineWidth: 20)
                
                Circle()
                    .trim(from: 0, to: safeCompletionRate(stats.completionRate) / 100)
                    .stroke(
                        LinearGradient(
                            colors: [Color.green, Color.accentColor],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        style: StrokeStyle(lineWidth: 20, lineCap: .round)
                    )
                    .rotationEffect(.degrees(-90))
                    .animation(.easeInOut(duration: 1), value: safeCompletionRate(stats.completionRate))
                
                VStack {
                    Text("\(Int(safeCompletionRate(stats.completionRate)))%")
                        .font(.system(size: 40, weight: .bold))
                        .foregroundColor(Color.dynamicText(theme: themeManager.currentTheme))
                    
                    Text("Complete")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .frame(width: 150, height: 150)
            
            HStack(spacing: 30) {
                VStack {
                    Text("\(stats.completeResponses)")
                        .font(.title2)
                        .fontWeight(.semibold)
                        .foregroundColor(.green)
                    Text("Completed")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                VStack {
                    Text("\(stats.incompleteResponses)")
                        .font(.title2)
                        .fontWeight(.semibold)
                        .foregroundColor(.orange)
                    Text("Incomplete")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding()
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.dynamicSurface(theme: themeManager.currentTheme))
                .shadow(color: .black.opacity(0.1), radius: 5, x: 0, y: 2)
        )
    }
    
    // MARK: - NPS Score Card
    private func npsScoreCard(_ score: Double) -> some View {
        let safeScore = safeNPSScore(score)
        
        return VStack(spacing: 12) {
            Text("Net Promoter Score")
                .font(.headline)
                .foregroundColor(Color.dynamicText(theme: themeManager.currentTheme))
            
            HStack(spacing: 20) {
                ZStack {
                    Circle()
                        .fill(npsColor(for: safeScore))
                        .frame(width: 80, height: 80)
                    
                    Text("\(Int(safeScore))")
                        .font(.system(size: 32, weight: .bold))
                        .foregroundColor(.white)
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(npsCategory(for: safeScore))
                        .font(.title3)
                        .fontWeight(.semibold)
                        .foregroundColor(Color.dynamicText(theme: themeManager.currentTheme))
                    
                    Text(npsDescription(for: safeScore))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
            }
            
            // NPS Scale Reference
            HStack(spacing: 0) {
                ForEach(0..<11) { index in
                    Rectangle()
                        .fill(npsScaleColor(for: index))
                        .frame(height: 20)
                        .overlay(
                            Text("\(index)")
                                .font(.caption2)
                                .foregroundColor(.white)
                        )
                }
            }
            .cornerRadius(4)
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.dynamicSurface(theme: themeManager.currentTheme))
                .shadow(color: .black.opacity(0.1), radius: 5, x: 0, y: 2)
        )
    }
    
    // MARK: - Question Statistics
    private func questionStatisticsSection(_ stats: SurveyStatistics) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Question Responses")
                .font(.headline)
                .foregroundColor(Color.dynamicText(theme: themeManager.currentTheme))
            
            ForEach(stats.questionStatistics) { questionStat in
                questionStatCard(questionStat)
            }
        }
    }
    
    private func questionStatCard(_ stat: QuestionStatistics) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(stat.questionText)
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundColor(Color.dynamicText(theme: themeManager.currentTheme))
            
            HStack {
                Label("\(stat.responseCount) responses", systemImage: "person.2")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Spacer()
                
                Text("\(stat.responseCount) answered")
                    .font(.caption)
                    .foregroundColor(.green)
            }
            
            // Type-specific visualization
            Group {
                let questionType = QuestionType(rawValue: stat.questionType) ?? .text
                
                switch questionType {
                case .scale, .nps:
                    if let avg = stat.statistics.average {
                        HStack {
                            Text("Average:")
                            Text(String(format: "%.1f", avg))
                                .fontWeight(.bold)
                                .foregroundColor(Color.accentColor)
                        }
                        .font(.caption)
                    }
                    
                case .radio, .checkbox, .select, .yesNo:
                    if let distribution = stat.statistics.distribution, !distribution.isEmpty {
                        VStack(alignment: .leading, spacing: 4) {
                            ForEach(Array(distribution.sorted(by: { $0.value > $1.value }).prefix(5)), id: \.key) { answer, count in
                                HStack {
                                    Text(answer)
                                        .font(.caption)
                                        .lineLimit(1)
                                    
                                    Spacer()
                                    
                                    Text("\(count)")
                                        .font(.caption)
                                        .fontWeight(.medium)
                                        .foregroundColor(Color.accentColor)
                                }
                                
                                GeometryReader { geometry in
                                    Rectangle()
                                        .fill(Color.accentColor.opacity(0.3))
                                        .frame(width: geometry.size.width * (Double(count) / Double(stat.responseCount)))
                                        .frame(height: 4)
                                        .cornerRadius(2)
                                }
                                .frame(height: 4)
                            }
                        }
                    }
                    
                default:
                    if let topTerms = stat.statistics.topTerms, !topTerms.isEmpty {
                        HStack {
                            Text("Top terms:")
                            Text(topTerms.first ?? "")
                                .fontWeight(.medium)
                                .foregroundColor(Color.accentColor)
                                .lineLimit(1)
                        }
                        .font(.caption)
                    }
                }
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.dynamicSurface(theme: themeManager.currentTheme).opacity(0.5))
        )
    }
    
    // MARK: - Export Button
    private func exportButton() -> some View {
        Button(action: { showingExportOptions = true }) {
            HStack {
                Image(systemName: "square.and.arrow.up")
                Text("Export Results")
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(Color.accentColor)
            .foregroundColor(.white)
            .cornerRadius(12)
        }
    }
    
    // MARK: - Helper Methods
    
    private func loadStatistics() {
        Task {
            isLoading = true
            errorMessage = nil
            
            statistics = await surveyService.getSurveyStatistics(surveyId: survey.id)
            
            if statistics == nil {
                errorMessage = "Failed to load statistics"
            }
            
            isLoading = false
        }
    }
    
    private func formatTime(_ seconds: Int) -> String {
        if seconds < 60 {
            return "\(seconds)s"
        } else if seconds < 3600 {
            return "\(seconds / 60)m"
        } else {
            return "\(seconds / 3600)h"
        }
    }
    
    private func formatChartDate(_ dateString: String) -> String {
        // Parse and format date for chart display
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        
        if let date = formatter.date(from: dateString) {
            formatter.dateFormat = "MMM d"
            return formatter.string(from: date)
        }
        
        return dateString
    }
    
    private func npsColor(for score: Double) -> Color {
        switch score {
        case -100..<0: return .red
        case 0..<50: return .orange
        case 50...100: return .green
        default: return .gray
        }
    }
    
    private func npsCategory(for score: Double) -> String {
        switch score {
        case -100..<0: return "Needs Improvement"
        case 0..<50: return "Good"
        case 50...100: return "Excellent"
        default: return "Unknown"
        }
    }
    
    private func npsDescription(for score: Double) -> String {
        switch score {
        case -100..<0: return "More detractors than promoters"
        case 0..<50: return "Positive sentiment overall"
        case 50...100: return "Strong customer loyalty"
        default: return ""
        }
    }
    
    private func npsScaleColor(for index: Int) -> Color {
        switch index {
        case 0...6: return .red
        case 7...8: return .orange
        case 9...10: return .green
        default: return .gray
        }
    }
}

// Preview
struct SurveyStatisticsView_Previews: PreviewProvider {
    static var previews: some View {
        SurveyStatisticsView(survey: Survey.sampleSurvey)
        .environmentObject(ThemeManager())
        .environmentObject(SurveyService())
    }
}