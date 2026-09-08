//
//  TrainerInboxSection.swift
//  Gym_API
//
//  «To review»: lo que los clientes del espacio han terminado y el entrenador no ha mirado
//  todavía (`GET /training/inbox`, plan §6.2).
//
//  Es una vista propia y no un trozo de `TrainerDashboardView` porque la galería de revisión
//  tiene que poder capturarla sola, y una maqueta paralela dejaría de parecerse a lo que ve el
//  entrenador a la primera corrección.
//

import SwiftUI
import TrainingCore

struct TrainerInboxSection: View {

    let onOpenLog: (TrainingWorkoutLogSummary) -> Void

    @EnvironmentObject var themeManager: ThemeManager
    @EnvironmentObject var trainingService: TrainingService

    private var theme: ThemeManager.AppTheme { themeManager.currentTheme }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                Text("TO REVIEW")
                    .font(TrainingType.label())
                    .tracking(0.9)
                    .foregroundColor(Color.dynamicTextTertiary(theme: theme))
                    .padding(.leading, 2)
                    .accessibilityAddTraits(.isHeader)

                Spacer()

                if !trainingService.inbox.isEmpty {
                    Text("\(trainingService.inbox.count)")
                        .font(TrainingType.monoS())
                        .monospacedDigit()
                        .foregroundColor(Color.dynamicTextTertiary(theme: theme))
                        .accessibilityLabel("\(trainingService.inbox.count) sessions to review")
                }
            }

            content
        }
    }

    @ViewBuilder
    private var content: some View {
        switch trainingService.inboxState {
        case .loading, .idle where trainingService.inbox.isEmpty:
            VStack(spacing: 10) {
                ForEach(0..<2, id: \.self) { _ in
                    HStack(spacing: 12) {
                        VStack(alignment: .leading, spacing: 6) {
                            TrainingSkeletonBar(width: 160, height: 14)
                            TrainingSkeletonBar(width: 190, height: 11)
                        }
                        Spacer()
                    }
                    .frame(minHeight: 56)
                }
            }
            .trainingCard(theme: theme, padding: 14)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Loading the sessions to review")

        case .failed where trainingService.inbox.isEmpty:
            TrainingRetryRow(
                message: "Couldn't load the sessions to review.",
                retryTitle: "Retry",
                onRetry: { Task { await trainingService.fetchInbox() } }
            )
            .trainingCard(theme: theme, padding: 14)

        default:
            if trainingService.inbox.isEmpty {
                // Vacío honesto: no hay nada, no es que no se haya podido.
                HStack(alignment: .top, spacing: 10) {
                    Image(systemName: "checkmark.circle")
                        .font(TrainingType.icon(15))
                        .foregroundColor(Color.dynamicTextTertiary(theme: theme))
                    Text("Nothing to review. Sessions your clients finish land here.")
                        .font(TrainingType.body())
                        .foregroundColor(Color.dynamicTextSecondary(theme: theme))
                        .fixedSize(horizontal: false, vertical: true)
                    Spacer(minLength: 0)
                }
                .trainingDashedCard(theme: theme, padding: 14)
                .accessibilityElement(children: .combine)
            } else {
                VStack(spacing: 0) {
                    ForEach(Array(trainingService.inbox.enumerated()), id: \.element.id) { index, log in
                        TrainerLogRow(log: log, unit: WeightUnitPreference.current) {
                            onOpenLog(log)
                        }
                        if index < trainingService.inbox.count - 1 {
                            Divider().background(Color.dynamicBorder(theme: theme).opacity(0.15))
                        }
                    }
                }
                .trainingCard(theme: theme, padding: 14)
            }
        }
    }
}
