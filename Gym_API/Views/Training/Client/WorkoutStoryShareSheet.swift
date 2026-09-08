//
//  WorkoutStoryShareSheet.swift
//  Gym_API
//
//  «To story» de S18 (UX §5 y plan §7.2).
//
//  Por qué esta hoja y no el creador de historias existente: `StoryCreatorView` no admite
//  parámetros, fija el tipo a `.image` y manda `workoutData: nil` en sus dos únicas llamadas.
//  Precargarle la plantilla de entrenamiento significaría rehacer una pantalla de otro módulo.
//  Esto usa la misma plantilla de render (`WorkoutStoryView`) y el mismo servicio
//  (`StoryService.createStory`, que ya acepta `workoutData`), y deja el creador intacto.
//
//  «Show weights» está encendido por defecto pero se apaga en un toque: al apagarlo, el peso no
//  viaja al servidor, no solo se oculta en la vista previa.
//

import SwiftUI
import TrainingCore

struct WorkoutStoryShareSheet: View {

    /// Titular de la marca, si lo hay.
    let exerciseName: String?
    let topRecord: TrainingSetLog?
    let session: WorkoutSession?
    let log: TrainingWorkoutLog?
    let unit: WeightUnit

    @EnvironmentObject var themeManager: ThemeManager
    @Environment(\.dismiss) private var dismiss

    /// `StoryService` no tiene singleton: lo inyecta `ServiceContainer` en la raíz y las hojas
    /// heredan el entorno de quien las presenta.
    @EnvironmentObject var storyService: StoryService

    @State private var showsWeights = true
    @State private var isSharing = false
    @State private var errorMessage: String?

    private var theme: ThemeManager.AppTheme { themeManager.currentTheme }

    // MARK: - Datos de la historia

    /// El ejercicio que se cuenta: el de la marca si la hay, si no el de más volumen.
    private var highlight: (name: String, weightKg: Double?, reps: Int?, sets: Int)? {
        if let record = topRecord {
            let count = log?.sets.filter { $0.exerciseKey == record.exerciseKey }.count ?? 1
            return (record.exerciseName, record.weightKg, record.reps, count)
        }
        if let log, let best = log.sets.max(by: { $0.volumeKg < $1.volumeKg }) {
            let count = log.sets.filter { $0.exerciseKey == best.exerciseKey }.count
            return (best.exerciseName, best.weightKg, best.reps, count)
        }
        if let session, let best = session.exercises.max(by: { $0.volumeKg < $1.volumeKg }) {
            let top = best.sets.filter(\.isDone).max { ($0.weightKg ?? 0) < ($1.weightKg ?? 0) }
            return (best.exerciseName, top?.weightKg, top?.reps, best.completedSetCount)
        }
        return nil
    }

    private var durationMinutes: Int? {
        if let seconds = log?.durationSeconds { return max(1, seconds / 60) }
        if let session { return max(1, session.durationSeconds(at: Date()) / 60) }
        return nil
    }

    private var workoutData: WorkoutData {
        let highlight = self.highlight
        return WorkoutData(
            exercise: highlight?.name ?? (log?.title ?? session?.title ?? "Workout"),
            weight: showsWeights ? highlight?.weightKg.map { unit.fromKilograms($0).rounded() } : nil,
            weightUnit: showsWeights ? unit.symbol : nil,
            reps: highlight?.reps,
            sets: highlight?.sets,
            durationMinutes: durationMinutes,
            caloriesBurned: nil,
            notes: nil
        )
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    preview

                    Toggle(isOn: $showsWeights) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Show weights")
                                .font(TrainingType.body())
                                .foregroundColor(Color.dynamicText(theme: theme))
                            Text("Off means the numbers never leave your phone.")
                                .font(TrainingType.caption())
                                .foregroundColor(Color.dynamicTextTertiary(theme: theme))
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                    .tint(Color.dynamicAccent(theme: theme))

                    if let errorMessage {
                        Text(errorMessage)
                            .font(TrainingType.caption())
                            .foregroundColor(Color.dynamicTextSecondary(theme: theme))
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    Button(action: share) {
                        HStack(spacing: 8) {
                            if isSharing { ProgressView().tint(Color.dynamicText(theme: theme)) }
                            Text("Share to story")
                                .font(TrainingType.headline())
                                .foregroundColor(Color.dynamicText(theme: theme))
                        }
                        .frame(maxWidth: .infinity, minHeight: 50)
                        .overlay(
                            Capsule().stroke(Color.dynamicAccentText(theme: theme), lineWidth: 1.5)
                        )
                    }
                    .buttonStyle(.plain)
                    .disabled(isSharing)
                }
                .padding(16)
            }
            .background(Color.dynamicBackground(theme: theme).ignoresSafeArea())
            .navigationTitle("Share to story")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                        .foregroundColor(Color.dynamicText(theme: theme))
                }
            }
        }
    }

    // MARK: - Vista previa

    private var preview: some View {
        VStack(alignment: .leading, spacing: 8) {
            TrainingEyebrow(text: "Preview")

            WorkoutStoryView(workoutData: workoutData)
                .frame(height: 320)
                .clipShape(RoundedRectangle(cornerRadius: 18))
                .overlay(
                    RoundedRectangle(cornerRadius: 18)
                        .stroke(Color.dynamicCardBorder(theme: theme), lineWidth: 1)
                )
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(previewLabel)
        }
    }

    private var previewLabel: String {
        var parts = ["Story preview."]
        if let highlight {
            parts.append(Celebration.spokenSet(
                exerciseName: highlight.name,
                weightKg: showsWeights ? highlight.weightKg : nil,
                reps: highlight.reps ?? 1,
                unit: unit.trainingUnit
            ))
        }
        if !showsWeights { parts.append("Weights hidden.") }
        return parts.joined(separator: " ")
    }

    // MARK: - Publicar

    private func share() {
        guard !isSharing else { return }
        isSharing = true
        errorMessage = nil

        Task {
            let story = await storyService.createStory(
                type: .workout,
                caption: nil,
                mediaData: nil,
                workoutData: workoutData,
                privacy: .public,
                duration: 24
            )
            isSharing = false
            if story != nil {
                HapticManager.shared.play(.success)
                dismiss()
            } else {
                errorMessage = "Couldn't share. Tap to retry."
            }
        }
    }
}
