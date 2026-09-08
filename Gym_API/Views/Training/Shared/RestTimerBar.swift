//
//  RestTimerBar.swift
//  Gym_API
//
//  Cronómetro de descanso (UX §8).
//
//  Lo que hace distinto a este cronómetro: no cuenta hacia atrás sobre una variable, sino sobre
//  una **fecha de fin absoluta**. Si el móvil pasa cinco minutos bloqueado, al volver la barra
//  dice la verdad («Rest done · 3:12 ago») sin tener que arreglar nada.
//
//  Y no roba el foco de VoiceOver: su valor se refresca en pasos de 15 s, no cada segundo, para
//  no convertir la pantalla en una máquina de interrumpir (UX §8, checklist §10.19).
//

import SwiftUI
import TrainingCore

struct RestTimerBar: View {

    let label: String
    let progress: Double
    let isFinished: Bool
    let isFinalCountdown: Bool
    /// Valor hablado; cambia solo cada 15 s.
    let accessibilityValue: String?
    let onSkip: () -> Void
    let onAddThirty: () -> Void
    let onOpenSettings: () -> Void

    @EnvironmentObject var themeManager: ThemeManager
    @Environment(\.trainingReduceMotion) private var reduceMotion

    private var theme: ThemeManager.AppTheme { themeManager.currentTheme }

    var body: some View {
        VStack(spacing: 0) {
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Rectangle()
                        .fill(Color.dynamicBorder(theme: theme).opacity(0.15))
                    Rectangle()
                        .fill(Color.dynamicAccent(theme: theme))
                        .frame(width: geo.size.width * max(0, min(1, progress)))
                }
            }
            .frame(height: 2)
            .accessibilityHidden(true)

            HStack(spacing: 12) {
                Button(action: onOpenSettings) {
                    HStack(spacing: 6) {
                        Image(systemName: "timer")
                            .font(TrainingType.icon(13, weight: .semibold))
                            .foregroundColor(Color.dynamicTextSecondary(theme: theme))
                        Text(label)
                            .font(TrainingType.monoL())
                            .monospacedDigit()
                            .foregroundColor(
                                isFinalCountdown
                                    ? Color.dynamicAccentText(theme: theme)
                                    : Color.dynamicText(theme: theme)
                            )
                            .lineLimit(1)
                            .minimumScaleFactor(0.6)
                    }
                    .frame(minHeight: 44)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Rest timer")
                .accessibilityValue(accessibilityValue ?? label)
                .accessibilityHint("Opens the rest timer options.")

                Spacer(minLength: 0)

                Button(action: onSkip) {
                    Text("Skip")
                        .font(TrainingType.caption())
                        .fontWeight(.semibold)
                        .foregroundColor(Color.dynamicTextSecondary(theme: theme))
                        .padding(.horizontal, 12)
                        .frame(minHeight: 44)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Skip rest")

                Button(action: onAddThirty) {
                    Text("+30s")
                        .font(TrainingType.caption())
                        .fontWeight(.semibold)
                        .foregroundColor(Color.dynamicText(theme: theme))
                        .padding(.horizontal, 12)
                        .frame(minHeight: 44)
                        .overlay(
                            Capsule().stroke(Color.dynamicBorder(theme: theme).opacity(0.4), lineWidth: 1)
                        )
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Add thirty seconds")
            }
            .padding(.horizontal, 16)
            .frame(height: 54)
        }
        .background(Color.dynamicSurface2(theme: theme))
        .animation(reduceMotion ? nil : .easeOut(duration: 0.2), value: isFinished)
    }
}

// MARK: - Hoja del cronómetro

/// Pulsación larga sobre el tiempo (UX §8): stepper de ±15 s, preajustes y el aviso del permiso
/// de notificaciones, que es el único sitio donde se menciona — nunca un modal al empezar.
struct RestTimerSheet: View {

    let currentSeconds: Int
    let permissionHint: String?
    let onApply: (Int, Bool) -> Void

    @EnvironmentObject var themeManager: ThemeManager
    @Environment(\.dismiss) private var dismiss

    @State private var seconds: Int
    @State private var applyToExercise = false

    private var theme: ThemeManager.AppTheme { themeManager.currentTheme }

    private let presets = [60, 90, 120, 180]

    init(currentSeconds: Int, permissionHint: String?, onApply: @escaping (Int, Bool) -> Void) {
        self.currentSeconds = currentSeconds
        self.permissionHint = permissionHint
        self.onApply = onApply
        _seconds = State(initialValue: max(15, currentSeconds))
    }

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 20) {
                    stepper

                    HStack(spacing: 8) {
                        ForEach(presets, id: \.self) { preset in
                            Button(action: {
                                HapticManager.shared.play(.selection)
                                seconds = preset
                            }) {
                                Text(TrainingPrescription.clock(preset))
                                    .font(TrainingType.caption())
                                    .fontWeight(.semibold)
                                    .monospacedDigit()
                                    .foregroundColor(
                                        seconds == preset
                                            ? Color.dynamicText(theme: theme)
                                            : Color.dynamicTextSecondary(theme: theme)
                                    )
                                    .frame(maxWidth: .infinity, minHeight: 44)
                                    .background(
                                        Capsule().fill(seconds == preset ? Color.dynamicSurface2(theme: theme) : Color.clear)
                                    )
                                    .overlay(
                                        Capsule().stroke(
                                            Color.dynamicBorder(theme: theme).opacity(seconds == preset ? 0.5 : 0.2),
                                            lineWidth: 1
                                        )
                                    )
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel(TrainingPrescription.spokenRest(preset))
                            .accessibilityAddTraits(seconds == preset ? [.isButton, .isSelected] : .isButton)
                        }
                    }

                    Toggle(isOn: $applyToExercise) {
                        Text("Use this for all sets of this exercise")
                            .font(TrainingType.body())
                            .foregroundColor(Color.dynamicText(theme: theme))
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .tint(Color.dynamicAccent(theme: theme))

                    if let permissionHint {
                        Button(action: openSettings) {
                            HStack(spacing: 6) {
                                Image(systemName: "bell.slash")
                                    .font(TrainingType.caption())
                                Text(permissionHint)
                                    .font(TrainingType.caption())
                                    .multilineTextAlignment(.leading)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                            .foregroundColor(Color.dynamicTextSecondary(theme: theme))
                            .frame(minHeight: 44)
                        }
                        .buttonStyle(.plain)
                        .accessibilityHint("Opens the system settings.")
                    }

                    Button(action: {
                        HapticManager.shared.play(.light)
                        onApply(seconds, applyToExercise)
                        dismiss()
                    }) {
                        Text("Apply")
                            .font(TrainingType.headline())
                            .foregroundColor(ThemeManager.accentInkForCurrentAccent(theme: theme))
                            .frame(maxWidth: .infinity, minHeight: 50)
                            .background(Capsule().fill(Color.dynamicAccent(theme: theme)))
                    }
                    .buttonStyle(.plain)

                    Spacer(minLength: 0)
                }
                .padding(16)
            }
            .background(Color.dynamicBackground(theme: theme).ignoresSafeArea())
            .navigationTitle("Rest timer")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Close") { dismiss() }
                        .foregroundColor(Color.dynamicText(theme: theme))
                }
            }
        }
        // El alto de apertura, con `.large` detrás: el `Toggle` de «Use this for all sets»
        // ocupa tres líneas en talla de accesibilidad y empujaba «Apply» fuera de los 380 pt,
        // sin scroll con el que llegar a él.
        .presentationDetents([.height(permissionHint == nil ? 380 : 440), .large])
    }

    private var stepper: some View {
        HStack(spacing: 0) {
            Button(action: {
                HapticManager.shared.play(.selection)
                seconds = max(15, seconds - 15)
            }) {
                Image(systemName: "minus")
                    .font(TrainingType.icon(16, weight: .bold))
                    .foregroundColor(Color.dynamicText(theme: theme))
                    .frame(width: 56, height: 56)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Fifteen seconds less")

            Text(TrainingPrescription.clock(seconds))
                .font(TrainingType.monoXL())
                .monospacedDigit()
                .foregroundColor(Color.dynamicText(theme: theme))
                .frame(maxWidth: .infinity)
                .lineLimit(1)
                .minimumScaleFactor(0.5)

            Button(action: {
                HapticManager.shared.play(.selection)
                seconds = min(600, seconds + 15)
            }) {
                Image(systemName: "plus")
                    .font(TrainingType.icon(16, weight: .bold))
                    .foregroundColor(Color.dynamicText(theme: theme))
                    .frame(width: 56, height: 56)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Fifteen seconds more")
        }
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.dynamicBorder(theme: theme).opacity(0.3), lineWidth: 1)
        )
        .accessibilityElement(children: .contain)
        .accessibilityValue(TrainingPrescription.spokenRest(seconds))
    }

    private func openSettings() {
        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
        UIApplication.shared.open(url)
    }
}
