//
//  TrainerTrainingDestination.swift
//  Gym_API
//
//  Traduce una `TrainerTrainingRoute` en la pantalla que le toca.
//
//  Existe porque hay **dos** pilas de navegación que llegan a las mismas pantallas: la lista de
//  clientes (ficha → S20 → S22) y el panel (buzón → S22, y el deep link del push). Con el
//  `switch` escrito dos veces, la segunda se queda atrás en cuanto una pantalla gana un
//  parámetro; escrito una, las dos entradas van siempre al mismo sitio.
//

import SwiftUI
import TrainingCore

struct TrainerTrainingDestination: View {

    let route: TrainerTrainingRoute
    @Binding var path: NavigationPath
    /// Lleva a la pestaña de mensajes. La posee `TrainerMainTabView`.
    var onMessage: () -> Void = {}

    @EnvironmentObject var themeManager: ThemeManager
    @EnvironmentObject var trainingService: TrainingService
    @EnvironmentObject var coachingService: CoachingService

    var body: some View {
        switch route {
        case .clientDetail(let client):
            ClientDetailView(
                client: client,
                onMessage: onMessage,
                onOpenPrograms: { path.append(TrainerTrainingRoute.clientPrograms(client)) },
                onOpenLog: { path.append(TrainerTrainingRoute.logReview(logId: $0, client: client)) }
            )

        case .clientPrograms(let client):
            ClientProgramsView(
                client: client,
                onOpenLog: { path.append(TrainerTrainingRoute.logReview(logId: $0, client: client)) }
            )

        case .logReview(let logId, let client):
            LogReviewView(
                logId: logId,
                client: client,
                onOpenExerciseHistory: { key, name in
                    // Sin cliente conocido (deep link de push) no hay historial de nadie que
                    // abrir: el nombre del ejercicio deja de llevar a ningún sitio, que es mejor
                    // que llevar al historial equivocado.
                    guard let client else { return }
                    path.append(TrainerTrainingRoute.clientExerciseHistory(client: client, key: key, name: name))
                }
            )

        case .clientExerciseHistory(let client, let key, let name):
            ExerciseHistoryView(exerciseKey: key, exerciseName: name, clientId: client.id)
        }
    }
}
