//
//  ExercisePickerSheet.swift
//  Gym_API
//
//  Catálogo de ejercicios, compartido por el cambio de ejercicio y el entreno libre (UX §5).
//
//  Una sola hoja para las dos cosas porque la tarea es la misma: encontrar un movimiento. Lo
//  único que cambia es el título y qué se hace con el resultado.
//

import SwiftUI
import TrainingCore

struct ExercisePickerSheet: View {

    enum Mode {
        /// Sustituir el ejercicio en curso.
        case swap(currentName: String)
        /// Añadir uno nuevo a la sesión.
        case add

        var title: String {
            switch self {
            case .swap: return "Swap exercise"
            case .add: return "Add exercise"
            }
        }

        var subtitle: String? {
            switch self {
            case .swap(let name): return "Replacing \(name)"
            case .add: return nil
            }
        }
    }

    let mode: Mode
    /// Con quién se está escribiendo el día. Solo lo pasa el editor del entrenador (S21) y es lo
    /// que enciende la sección «Recently used with Dana»; en las pantallas del cliente es nulo y
    /// la hoja se comporta exactamente como antes.
    var recentForClient: TrainingClientRef?
    let onSelect: (ExerciseCatalogItem) -> Void

    @EnvironmentObject var themeManager: ThemeManager
    @EnvironmentObject var trainingService: TrainingService
    @Environment(\.dismiss) private var dismiss

    @State private var query = ""
    @State private var searchTask: Task<Void, Never>?

    private var theme: ThemeManager.AppTheme { themeManager.currentTheme }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                if let subtitle = mode.subtitle {
                    Text(subtitle)
                        .font(TrainingType.caption())
                        .foregroundColor(Color.dynamicTextTertiary(theme: theme))
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 16)
                        .padding(.bottom, 8)
                }

                content
            }
            .background(Color.dynamicBackground(theme: theme).ignoresSafeArea())
            .navigationTitle(mode.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                        .foregroundColor(Color.dynamicText(theme: theme))
                }
            }
            .searchable(text: $query, prompt: "Search exercises")
            .onChange(of: query) { _, newValue in
                searchTask?.cancel()
                searchTask = Task {
                    // Medio segundo de espera: el catálogo son 120 filas y no hace falta una
                    // petición por letra.
                    try? await Task.sleep(nanoseconds: 400_000_000)
                    guard !Task.isCancelled else { return }
                    await trainingService.fetchExercises(query: newValue.isEmpty ? nil : newValue)
                }
            }
        }
        .task {
            if trainingService.exercises.isEmpty {
                await trainingService.fetchExercises()
            }
        }
    }

    @ViewBuilder
    private var content: some View {
        if !trainingService.exercises.isEmpty {
            List {
                if !recentItems.isEmpty {
                    Section {
                        ForEach(recentItems) { item in
                            row(item)
                        }
                    } header: {
                        Text("Recently used with \(recentForClient?.firstName ?? "")")
                            .font(TrainingType.label())
                            .tracking(0.8)
                            .foregroundColor(Color.dynamicTextTertiary(theme: theme))
                    }
                    .listRowBackground(Color.dynamicSurface(theme: theme))
                }

                ForEach(otherItems) { item in
                    row(item)
                }
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
        } else if trainingService.exercisesState == .loading {
            VStack(spacing: 12) {
                ForEach(0..<6, id: \.self) { _ in
                    HStack {
                        VStack(alignment: .leading, spacing: 6) {
                            TrainingSkeletonBar(width: 160, height: 14)
                            TrainingSkeletonBar(width: 110, height: 10)
                        }
                        Spacer()
                    }
                    .frame(minHeight: 48)
                }
            }
            .padding(16)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Loading exercises")
        } else if trainingService.exercisesState == .failed {
            TrainingRetryRow(
                message: "Couldn't load the exercises.",
                retryTitle: "Retry",
                onRetry: { Task { await trainingService.fetchExercises(query: query.isEmpty ? nil : query) } }
            )
            .trainingCard(theme: theme)
            .padding(16)
        } else {
            VStack(alignment: .leading, spacing: 8) {
                Text(query.isEmpty ? "No exercises available yet." : "Nothing matches “\(query)”.")
                    .font(TrainingType.body())
                    .foregroundColor(Color.dynamicTextSecondary(theme: theme))
                    .fixedSize(horizontal: false, vertical: true)
            }
            .trainingCard(theme: theme)
            .padding(16)
        }
    }

    // MARK: - Fila

    private func row(_ item: ExerciseCatalogItem) -> some View {
        Button(action: {
            HapticManager.shared.play(.selection)
            onSelect(item)
            dismiss()
        }) {
            VStack(alignment: .leading, spacing: 3) {
                Text(item.name)
                    .font(TrainingType.headline())
                    .foregroundColor(Color.dynamicText(theme: theme))

                if !item.primaryMuscles.isEmpty {
                    Text(item.primaryMuscles.prefix(3).joined(separator: " · "))
                        .font(TrainingType.caption())
                        .foregroundColor(Color.dynamicTextTertiary(theme: theme))
                        .lineLimit(1)
                }
            }
            .frame(maxWidth: .infinity, minHeight: 48, alignment: .leading)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .listRowBackground(Color.dynamicSurface(theme: theme))
        .accessibilityLabel(item.name)
        .accessibilityHint(item.primaryMuscles.isEmpty ? "" : "Works \(item.primaryMuscles.joined(separator: ", ")).")
    }

    // MARK: - Recientes con este cliente (S21)

    /// Las claves recordadas en el dispositivo, resueltas contra el catálogo cargado y en el
    /// mismo orden en que se usaron.
    ///
    /// Solo se enseña sin búsqueda activa: buscando «row» la respuesta esperada es lo que se
    /// parece a «row», no lo que se puso el martes pasado.
    private var recentItems: [ExerciseCatalogItem] {
        guard let client = recentForClient, query.isEmpty else { return [] }
        let keys = TrainingRecentExercises.keys(forClient: client.id)
        guard !keys.isEmpty else { return [] }
        let byKey = Dictionary(
            trainingService.exercises.map { ($0.exerciseKey, $0) },
            uniquingKeysWith: { first, _ in first }
        )
        return keys.compactMap { byKey[$0] }
    }

    /// El catálogo sin lo que ya está arriba: la misma fila dos veces confunde más que ahorra.
    private var otherItems: [ExerciseCatalogItem] {
        let recent = Set(recentItems.map(\.id))
        guard !recent.isEmpty else { return trainingService.exercises }
        return trainingService.exercises.filter { !recent.contains($0.id) }
    }
}
