//
//  TrainingSyncChip.swift
//  Gym_API
//
//  El estado de la cola de sincronización, en una línea (UX §4 W8, §5 S11 y S16).
//
//  Tres estados, no dos. Esto es lo que pidió la revisión 2 de WP3:
//
//  1. **En cola** (`pendingCount > 0`): «Pending sync». Es normal, no es un error, y no bloquea
//     nada. Punto ámbar de 6 pt más el texto: el estado nunca se comunica solo por color.
//  2. **Apartadas** (`failedCount > 0`): «Couldn't save 1 session · Retry». El servidor las
//     rechazó y siguen en disco. Sin este estado el entreno se queda ahí para siempre y nadie se
//     entera, que es exactamente el fallo que la revisión de WP3 obligó a cerrar.
//  3. **Todo enviado**: no se pinta nada. Un chip verde permanente diciendo «synced» es ruido.
//
//  Las apartadas mandan sobre las encoladas: si hay algo que requiere una decisión de la
//  persona, es lo que tiene que leer.
//

import SwiftUI

struct TrainingSyncChip: View {

    /// Compacto para la barra de S11; con caja para las tarjetas de la home.
    var compact: Bool = false

    @EnvironmentObject var themeManager: ThemeManager
    @EnvironmentObject var syncCoordinator: TrainingSyncCoordinator

    @State private var isRetrying = false

    private var theme: ThemeManager.AppTheme { themeManager.currentTheme }

    // MARK: - Estado

    private enum SyncState {
        case failed(Int)
        case pending
        case clear
    }

    private var state: SyncState {
        if syncCoordinator.failedCount > 0 { return .failed(syncCoordinator.failedCount) }
        if syncCoordinator.pendingCount > 0 || syncCoordinator.isDraining { return .pending }
        return .clear
    }

    /// «Couldn't save 1 session» / «Couldn't save 3 sessions».
    static func failureText(count: Int) -> String {
        "Couldn't save \(count) session\(count == 1 ? "" : "s")"
    }

    var body: some View {
        switch state {
        case .clear:
            EmptyView()
        case .pending:
            pendingChip
        case .failed(let count):
            failedChip(count: count)
        }
    }

    // MARK: - En cola

    private var pendingChip: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(Color.dynamicWarningText(theme: theme))
                .frame(width: 6, height: 6)

            Text("Pending sync")
                .font(TrainingType.caption())
                .foregroundColor(Color.dynamicTextTertiary(theme: theme))
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .padding(.horizontal, compact ? 0 : 8)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Pending sync. Your session is saved on this phone and will upload when you are back online.")
    }

    // MARK: - Apartadas

    private func failedChip(count: Int) -> some View {
        HStack(spacing: 8) {
            Image(systemName: "exclamationmark.circle")
                .font(TrainingType.caption())
                .foregroundColor(Color.dynamicWarningText(theme: theme))

            Text(Self.failureText(count: count))
                .font(TrainingType.caption())
                .foregroundColor(Color.dynamicTextSecondary(theme: theme))
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)

            Text("·")
                .font(TrainingType.caption())
                .foregroundColor(Color.dynamicTextTertiary(theme: theme))
                .accessibilityHidden(true)

            Button {
                guard !isRetrying else { return }
                isRetrying = true
                HapticManager.shared.buttonTap()
                Task {
                    await syncCoordinator.retryFailed()
                    isRetrying = false
                }
            } label: {
                Text("Retry")
                    .font(TrainingType.caption())
                    .fontWeight(.semibold)
                    .foregroundColor(Color.dynamicText(theme: theme))
                    .underline()
                    .trainingTouchTarget(minWidth: 44, minHeight: 44)
            }
            .buttonStyle(.plain)
            .disabled(isRetrying)
            .accessibilityLabel("Retry sending")
            .accessibilityHint("Sends the sessions that the server turned down.")

            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .contain)
    }
}

// MARK: - Detalle de lo apartado

/// La lista de sesiones que el servidor rechazó, con el motivo que ya viene en inglés desde
/// `FailedSyncSummary.reason`. Se abre desde el chip largo de la tarjeta del último registro.
struct TrainingFailedSyncSheet: View {

    @EnvironmentObject var themeManager: ThemeManager
    @EnvironmentObject var syncCoordinator: TrainingSyncCoordinator
    @Environment(\.dismiss) private var dismiss

    @State private var isRetrying = false

    private var theme: ThemeManager.AppTheme { themeManager.currentTheme }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text("These sessions are still on your phone. Nothing was lost.")
                        .font(TrainingType.body())
                        .foregroundColor(Color.dynamicTextSecondary(theme: theme))
                        .fixedSize(horizontal: false, vertical: true)

                    ForEach(syncCoordinator.failedEntries) { entry in
                        VStack(alignment: .leading, spacing: 6) {
                            Text(entry.title)
                                .font(TrainingType.headline())
                                .foregroundColor(Color.dynamicText(theme: theme))

                            Text("\(entry.setCount) set\(entry.setCount == 1 ? "" : "s")")
                                .font(TrainingType.caption())
                                .foregroundColor(Color.dynamicTextTertiary(theme: theme))

                            Text(entry.reason)
                                .font(TrainingType.caption())
                                .foregroundColor(Color.dynamicTextSecondary(theme: theme))
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .trainingCard(theme: theme)
                        .accessibilityElement(children: .combine)
                    }

                    Button {
                        guard !isRetrying else { return }
                        isRetrying = true
                        HapticManager.shared.buttonTap()
                        Task {
                            await syncCoordinator.retryFailed()
                            isRetrying = false
                            if syncCoordinator.failedCount == 0 { dismiss() }
                        }
                    } label: {
                        HStack(spacing: 8) {
                            if isRetrying { ProgressView().tint(Color.dynamicText(theme: theme)) }
                            Text("Retry")
                                .font(TrainingType.headline())
                                .foregroundColor(Color.dynamicText(theme: theme))
                        }
                        .frame(maxWidth: .infinity, minHeight: 50)
                        .overlay(
                            Capsule().stroke(Color.dynamicAccentText(theme: theme), lineWidth: 1.5)
                        )
                    }
                    .buttonStyle(.plain)
                    .disabled(isRetrying)
                }
                .padding(16)
            }
            .background(Color.dynamicBackground(theme: theme).ignoresSafeArea())
            .navigationTitle("Not synced")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Close") { dismiss() }
                        .foregroundColor(Color.dynamicText(theme: theme))
                }
            }
        }
    }
}
