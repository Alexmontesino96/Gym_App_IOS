import SwiftUI

struct ExportOptionsView: View {
    @EnvironmentObject var themeManager: ThemeManager
    @EnvironmentObject var surveyService: SurveyService
    @Environment(\.dismiss) var dismiss
    
    let survey: Survey
    @State private var selectedFormat: ExportFormat = .excel
    @State private var isExporting = false
    @State private var exportError: String?
    @State private var exportSuccess = false
    @State private var downloadURL: URL?
    
    enum ExportFormat: String, CaseIterable {
        case excel = "excel"
        case csv = "csv"
        case json = "json"
        case pdf = "pdf"
        
        var displayName: String {
            switch self {
            case .excel: return "Excel (.xlsx)"
            case .csv: return "CSV (.csv)"
            case .json: return "JSON (.json)"
            case .pdf: return "PDF Report"
            }
        }
        
        var icon: String {
            switch self {
            case .excel: return "tablecells"
            case .csv: return "tablecells.badge.ellipsis"
            case .json: return "curlybraces"
            case .pdf: return "doc.richtext"
            }
        }
        
        var description: String {
            switch self {
            case .excel: 
                return "Full spreadsheet with multiple sheets for responses, statistics, and charts"
            case .csv: 
                return "Simple comma-separated values file for easy import into other tools"
            case .json: 
                return "Structured data format for developers and API integration"
            case .pdf: 
                return "Professional report with visualizations and summary statistics"
            }
        }
    }
    
    var body: some View {
        NavigationView {
            ZStack {
                Color.dynamicBackground(theme: themeManager.currentTheme)
                    .ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 20) {
                        // Header
                        headerSection
                        
                        // Format Selection
                        formatSelectionSection
                        
                        // Export Options
                        exportOptionsSection
                        
                        // Export Button
                        exportButton
                        
                        // Status Messages
                        if let error = exportError {
                            errorMessage(error)
                        }
                        
                        if exportSuccess {
                            successMessage
                        }
                    }
                    .padding()
                }
            }
            .navigationTitle("Export Survey Data")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
        .sheet(isPresented: .constant(downloadURL != nil)) {
            if let url = downloadURL {
                ShareSheet(items: [url])
            }
        }
    }
    
    // MARK: - Header Section
    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "square.and.arrow.up.circle.fill")
                    .font(.largeTitle)
                    .foregroundColor(Color.accentColor)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("Export Survey Results")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(Color.dynamicText(theme: themeManager.currentTheme))
                    
                    Text(survey.title)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
            }
            
            Text("Choose a format to export all survey responses and analytics data")
                .font(.body)
                .foregroundColor(.secondary)
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.dynamicSurface(theme: themeManager.currentTheme))
        )
    }
    
    // MARK: - Format Selection
    private var formatSelectionSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Select Format")
                .font(.headline)
                .foregroundColor(Color.dynamicText(theme: themeManager.currentTheme))
            
            ForEach(ExportFormat.allCases, id: \.self) { format in
                formatOption(format)
            }
        }
    }
    
    private func formatOption(_ format: ExportFormat) -> some View {
        Button(action: { selectedFormat = format }) {
            HStack(spacing: 16) {
                // Icon
                ZStack {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(selectedFormat == format ? Color.accentColor : Color.gray.opacity(0.2))
                        .frame(width: 50, height: 50)
                    
                    Image(systemName: format.icon)
                        .font(.title2)
                        .foregroundColor(selectedFormat == format ? .white : Color.accentColor)
                }
                
                // Info
                VStack(alignment: .leading, spacing: 4) {
                    Text(format.displayName)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(Color.dynamicText(theme: themeManager.currentTheme))
                    
                    Text(format.description)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.leading)
                }
                
                Spacer()
                
                // Selection indicator
                if selectedFormat == format {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(Color.accentColor)
                        .font(.title2)
                }
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.dynamicSurface(theme: themeManager.currentTheme))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(selectedFormat == format ? Color.accentColor : Color.clear, lineWidth: 2)
                    )
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    // MARK: - Export Options
    private var exportOptionsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Export Details")
                .font(.headline)
                .foregroundColor(Color.dynamicText(theme: themeManager.currentTheme))
            
            VStack(spacing: 16) {
                // Data included
                HStack {
                    Label("Includes", systemImage: "checkmark.seal")
                        .font(.subheadline)
                        .foregroundColor(Color.dynamicText(theme: themeManager.currentTheme))
                    
                    Spacer()
                }
                
                VStack(alignment: .leading, spacing: 8) {
                    exportDetailRow(icon: "person.2", text: "All responses (complete and incomplete)")
                    exportDetailRow(icon: "chart.bar", text: "Statistical analysis and summaries")
                    exportDetailRow(icon: "calendar", text: "Response timestamps and metadata")
                    
                    if selectedFormat == .excel || selectedFormat == .pdf {
                        exportDetailRow(icon: "chart.line.uptrend", text: "Visual charts and graphs")
                    }
                    
                    if selectedFormat == .pdf {
                        exportDetailRow(icon: "doc.text", text: "Executive summary and insights")
                    }
                }
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.dynamicSurface(theme: themeManager.currentTheme).opacity(0.5))
            )
        }
    }
    
    private func exportDetailRow(icon: String, text: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundColor(Color.accentColor)
                .frame(width: 20)
            
            Text(text)
                .font(.caption)
                .foregroundColor(.secondary)
            
            Spacer()
        }
    }
    
    // MARK: - Export Button
    private var exportButton: some View {
        Button(action: performExport) {
            HStack {
                if isExporting {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        .scaleEffect(0.8)
                } else {
                    Image(systemName: "square.and.arrow.up")
                }
                
                Text(isExporting ? "Exporting..." : "Export Data")
                    .fontWeight(.semibold)
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(isExporting ? Color.gray : Color.accentColor)
            )
            .foregroundColor(.white)
        }
        .disabled(isExporting)
    }
    
    // MARK: - Status Messages
    private func errorMessage(_ error: String) -> some View {
        HStack {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundColor(.red)
            
            Text(error)
                .font(.caption)
                .foregroundColor(.red)
            
            Spacer()
            
            Button(action: { exportError = nil }) {
                Image(systemName: "xmark.circle.fill")
                    .foregroundColor(.red.opacity(0.7))
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.red.opacity(0.1))
        )
    }
    
    private var successMessage: some View {
        VStack(spacing: 16) {
            HStack {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.green)
                    .font(.title)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("Export Successful!")
                        .font(.headline)
                        .foregroundColor(.green)
                    
                    Text("Your data has been exported successfully")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
            }
            
            if downloadURL != nil {
                Button(action: shareExport) {
                    Label("Share Export", systemImage: "square.and.arrow.up")
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(Color.green.opacity(0.2))
                        )
                        .foregroundColor(.green)
                }
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.green.opacity(0.1))
        )
    }
    
    // MARK: - Actions
    
    private func performExport() {
        Task {
            isExporting = true
            exportError = nil
            exportSuccess = false
            
            // Call export endpoint
            downloadURL = await surveyService.exportSurveyResults(
                surveyId: survey.id,
                format: selectedFormat.rawValue
            )
            
            if downloadURL != nil {
                exportSuccess = true
                
                // Auto-dismiss after success
                DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                    if exportSuccess {
                        dismiss()
                    }
                }
            } else {
                exportError = "Failed to export data. Please try again."
            }
            
            isExporting = false
        }
    }
    
    private func shareExport() {
        guard let url = downloadURL else { return }
        
        // Present share sheet
        let activityVC = UIActivityViewController(
            activityItems: [url],
            applicationActivities: nil
        )
        
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let window = windowScene.windows.first {
            window.rootViewController?.present(activityVC, animated: true)
        }
    }
}

// MARK: - Share Sheet
struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]
    
    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }
    
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

// Preview
struct ExportOptionsView_Previews: PreviewProvider {
    static var previews: some View {
        ExportOptionsView(survey: Survey.sampleSurvey)
        .environmentObject(ThemeManager())
        .environmentObject(SurveyService())
    }
}