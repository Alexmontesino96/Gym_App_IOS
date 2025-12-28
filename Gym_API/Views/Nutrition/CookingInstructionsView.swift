import SwiftUI

// MARK: - CookingInstructionsView

/// Vista de instrucciones de cocina paso a paso
/// Muestra los pasos de preparacion con checkboxes y tips
struct CookingInstructionsView: View {
    // MARK: - Properties

    let instructions: String?
    let tips: String?
    let preparationTime: Int?
    let isInteractive: Bool

    @EnvironmentObject var themeManager: ThemeManager
    @State private var completedSteps: Set<Int> = []
    @State private var expandedView = true

    // MARK: - Computed Properties

    private var steps: [CookingStep] {
        guard let instructions = instructions, !instructions.isEmpty else { return [] }

        return instructions
            .components(separatedBy: "\n")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
            .enumerated()
            .map { CookingStep(id: $0.offset, text: cleanStepText($0.element)) }
    }

    // MARK: - Initialization

    init(
        instructions: String?,
        tips: String? = nil,
        preparationTime: Int? = nil,
        isInteractive: Bool = true
    ) {
        self.instructions = instructions
        self.tips = tips
        self.preparationTime = preparationTime
        self.isInteractive = isInteractive
    }

    // MARK: - Body

    var body: some View {
        VStack(spacing: 0) {
            if !steps.isEmpty {
                // Header
                headerSection

                // Steps
                if expandedView {
                    stepsSection
                        .transition(.opacity.combined(with: .move(edge: .top)))
                }

                // Tips section
                if let tips = tips, !tips.isEmpty, expandedView {
                    tipsSection(tips: tips)
                        .transition(.opacity)
                }
            } else {
                emptyState
            }
        }
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.dynamicSurface(theme: themeManager.currentTheme))
        )
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: expandedView)
    }

    // MARK: - Header Section

    private var headerSection: some View {
        Button(action: {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                expandedView.toggle()
            }
        }) {
            HStack {
                // Icon
                ZStack {
                    Circle()
                        .fill(Color.dynamicAccent(theme: themeManager.currentTheme).opacity(0.1))
                        .frame(width: 36, height: 36)

                    Image(systemName: "frying.pan")
                        .font(.system(size: 16))
                        .foregroundColor(Color.dynamicAccent(theme: themeManager.currentTheme))
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text("Preparacion")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(Color.dynamicText(theme: themeManager.currentTheme))

                    HStack(spacing: 12) {
                        Text("\(steps.count) pasos")
                            .font(.system(size: 13))
                            .foregroundColor(Color.dynamicTextSecondary(theme: themeManager.currentTheme))

                        if let time = preparationTime {
                            HStack(spacing: 4) {
                                Image(systemName: "clock")
                                    .font(.system(size: 11))
                                Text(formatTime(time))
                                    .font(.system(size: 12))
                            }
                            .foregroundColor(Color.dynamicTextSecondary(theme: themeManager.currentTheme))
                        }
                    }
                }

                Spacer()

                // Progress indicator
                if isInteractive {
                    progressIndicator
                }

                // Expand/collapse
                Image(systemName: expandedView ? "chevron.up" : "chevron.down")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(Color.dynamicTextSecondary(theme: themeManager.currentTheme))
            }
            .padding(16)
        }
        .buttonStyle(PlainButtonStyle())
    }

    // MARK: - Progress Indicator

    private var progressIndicator: some View {
        let completed = completedSteps.count
        let total = steps.count

        return HStack(spacing: 4) {
            Text("\(completed)/\(total)")
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(
                    completed == total && total > 0
                        ? .green
                        : Color.dynamicTextSecondary(theme: themeManager.currentTheme)
                )

            if completed == total && total > 0 {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 12))
                    .foregroundColor(.green)
            }
        }
    }

    // MARK: - Steps Section

    private var stepsSection: some View {
        VStack(spacing: 0) {
            Divider()
                .background(Color.dynamicBorder(theme: themeManager.currentTheme).opacity(0.5))

            ForEach(steps) { step in
                stepRow(step)

                if step.id != steps.last?.id {
                    Divider()
                        .background(Color.dynamicBorder(theme: themeManager.currentTheme).opacity(0.3))
                        .padding(.leading, 60)
                }
            }
        }
    }

    // MARK: - Step Row

    private func stepRow(_ step: CookingStep) -> some View {
        HStack(alignment: .top, spacing: 14) {
            // Step number/checkbox
            if isInteractive {
                Button(action: {
                    toggleStep(step.id)
                }) {
                    stepIndicator(step: step)
                }
                .buttonStyle(PlainButtonStyle())
            } else {
                stepNumber(step.id + 1)
            }

            // Step text
            Text(step.text)
                .font(.system(size: 14))
                .foregroundColor(
                    completedSteps.contains(step.id)
                        ? Color.dynamicTextSecondary(theme: themeManager.currentTheme)
                        : Color.dynamicText(theme: themeManager.currentTheme)
                )
                .strikethrough(completedSteps.contains(step.id))
                .fixedSize(horizontal: false, vertical: true)

            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .contentShape(Rectangle())
        .onTapGesture {
            if isInteractive {
                toggleStep(step.id)
            }
        }
    }

    // MARK: - Step Indicator

    private func stepIndicator(step: CookingStep) -> some View {
        ZStack {
            if completedSteps.contains(step.id) {
                Circle()
                    .fill(Color.green)
                    .frame(width: 32, height: 32)

                Image(systemName: "checkmark")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(.white)
            } else {
                Circle()
                    .stroke(Color.dynamicBorder(theme: themeManager.currentTheme), lineWidth: 2)
                    .frame(width: 32, height: 32)

                Text("\(step.id + 1)")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(Color.dynamicText(theme: themeManager.currentTheme))
            }
        }
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: completedSteps.contains(step.id))
    }

    // MARK: - Step Number (non-interactive)

    private func stepNumber(_ number: Int) -> some View {
        ZStack {
            Circle()
                .fill(Color.dynamicAccent(theme: themeManager.currentTheme).opacity(0.1))
                .frame(width: 32, height: 32)

            Text("\(number)")
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(Color.dynamicAccent(theme: themeManager.currentTheme))
        }
    }

    // MARK: - Tips Section

    private func tipsSection(tips: String) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Divider()
                .background(Color.dynamicBorder(theme: themeManager.currentTheme).opacity(0.5))

            HStack(alignment: .top, spacing: 12) {
                Image(systemName: "lightbulb.fill")
                    .font(.system(size: 16))
                    .foregroundColor(.yellow)

                VStack(alignment: .leading, spacing: 6) {
                    Text("Tip del Nutricionista")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(Color.dynamicText(theme: themeManager.currentTheme))

                    Text(tips)
                        .font(.system(size: 13))
                        .foregroundColor(Color.dynamicTextSecondary(theme: themeManager.currentTheme))
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.yellow.opacity(0.1))
        }
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "doc.text")
                .font(.system(size: 28))
                .foregroundColor(Color.dynamicTextSecondary(theme: themeManager.currentTheme))

            Text("Sin instrucciones disponibles")
                .font(.system(size: 14))
                .foregroundColor(Color.dynamicTextSecondary(theme: themeManager.currentTheme))
        }
        .padding(24)
        .frame(maxWidth: .infinity)
    }

    // MARK: - Actions

    private func toggleStep(_ id: Int) {
        let impact = UIImpactFeedbackGenerator(style: .light)
        impact.impactOccurred()

        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
            if completedSteps.contains(id) {
                completedSteps.remove(id)
            } else {
                completedSteps.insert(id)
            }
        }

        // Check if all steps completed
        if completedSteps.count == steps.count && steps.count > 0 {
            let notification = UINotificationFeedbackGenerator()
            notification.notificationOccurred(.success)
        }
    }

    // MARK: - Helpers

    private func cleanStepText(_ text: String) -> String {
        // Remove leading numbers, dashes, dots
        var cleaned = text

        // Remove patterns like "1.", "1)", "1-", "- ", etc.
        let patterns = ["^\\d+\\.\\s*", "^\\d+\\)\\s*", "^\\d+-\\s*", "^-\\s*", "^\\*\\s*"]
        for pattern in patterns {
            if let range = cleaned.range(of: pattern, options: .regularExpression) {
                cleaned.removeSubrange(range)
            }
        }

        return cleaned.trimmingCharacters(in: .whitespaces)
    }

    private func formatTime(_ minutes: Int) -> String {
        if minutes < 60 {
            return "\(minutes) min"
        } else {
            let hours = minutes / 60
            let mins = minutes % 60
            if mins == 0 {
                return "\(hours)h"
            }
            return "\(hours)h \(mins)m"
        }
    }
}

// MARK: - CookingStep Model

struct CookingStep: Identifiable {
    let id: Int
    let text: String
}

// MARK: - CompactInstructionsPreview

/// Vista previa compacta de las instrucciones (para cards)
struct CompactInstructionsPreview: View {
    let instructions: String?
    let preparationTime: Int?

    @EnvironmentObject var themeManager: ThemeManager

    private var stepCount: Int {
        guard let instructions = instructions, !instructions.isEmpty else { return 0 }
        return instructions
            .components(separatedBy: "\n")
            .filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
            .count
    }

    var body: some View {
        HStack(spacing: 16) {
            if stepCount > 0 {
                HStack(spacing: 6) {
                    Image(systemName: "list.number")
                        .font(.system(size: 13))
                    Text("\(stepCount) pasos")
                        .font(.system(size: 13))
                }
                .foregroundColor(Color.dynamicTextSecondary(theme: themeManager.currentTheme))
            }

            if let time = preparationTime {
                HStack(spacing: 6) {
                    Image(systemName: "clock")
                        .font(.system(size: 13))
                    Text(formatTime(time))
                        .font(.system(size: 13))
                }
                .foregroundColor(Color.dynamicTextSecondary(theme: themeManager.currentTheme))
            }
        }
    }

    private func formatTime(_ minutes: Int) -> String {
        if minutes < 60 {
            return "\(minutes) min"
        }
        return "\(minutes / 60)h \(minutes % 60)m"
    }
}

// MARK: - Preview

#Preview {
    ScrollView {
        VStack(spacing: 30) {
            Text("Cooking Instructions")
                .font(.headline)
                .foregroundColor(.white)

            CookingInstructionsView(
                instructions: """
                1. Precalentar el horno a 180 grados
                2. Mezclar los ingredientes secos en un bowl
                3. Agregar los huevos y la leche
                4. Batir hasta obtener una mezcla homogenea
                5. Verter en el molde y hornear por 25 minutos
                """,
                tips: "Puedes agregar frutos secos para mas proteina",
                preparationTime: 35,
                isInteractive: true
            )

            CookingInstructionsView(
                instructions: nil,
                isInteractive: false
            )
        }
        .padding()
    }
    .background(Color.black)
    .environmentObject(ThemeManager())
}
