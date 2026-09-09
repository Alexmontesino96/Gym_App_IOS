//
//  TrainingShareAvailability.swift
//  Gym_API
//
//  Quién puede ofrecer «To story» y «To feed» (plan §8.7).
//
//  La regla es una sola y vive aquí para que no haya tres versiones de ella: en un espacio de
//  ENTRENADOR PERSONAL no se comparte nunca, con independencia de que los módulos `posts` y
//  `stories` estén encendidos. Un espacio de entrenador personal es la consulta de una persona,
//  no una comunidad: el compositor de historias abriría un muro que ahí no existe, y el cliente
//  publicaría su entreno delante de desconocidos. El interruptor de módulo sigue mandando en los
//  gimnasios tradicionales.
//
//  Falla cerrada, como el resto del módulo: mientras no haya llegado el contexto del espacio no
//  se sabe en cuál estamos, y no se enseña el botón. Es preferible una pantalla sin botón un
//  segundo a un botón que abre el sitio equivocado.
//

import Foundation

@MainActor
enum TrainingShareAvailability {

    /// Código de espacio de entrenador personal tal y como lo devuelve el backend.
    static let personalTrainerType = "personal_trainer"

    /// ¿Se puede ofrecer el botón de compartir del módulo `code` (`stories` o `posts`)?
    ///
    /// Lee el contexto de los servicios compartidos para que la llamen igual una pantalla con
    /// `@EnvironmentObject` y una que no lo tiene (`RecordsView`). Las vistas que la usan ya
    /// observan `GymService` o `WorkspaceContextService`, así que se repintan cuando el contexto
    /// termina de cargar.
    static func isAvailable(module code: String) -> Bool {
        isAvailable(
            moduleEnabled: GymService.shared.isModuleEnabled(code),
            workspaceIsPersonalTrainer: WorkspaceContextService.shared.context?.workspace.isPersonalTrainer,
            gymType: WorkspaceContextService.shared.context?.workspace.type ?? GymService.shared.currentGym?.type
        )
    }

    /// La decisión, sin servicios de por medio: así se puede razonar (y probar) sobre ella.
    ///
    /// - Parameters:
    ///   - moduleEnabled: `GymService.isModuleEnabled(code)`; `nil` mientras no se sepa.
    ///   - workspaceIsPersonalTrainer: `workspaceContext.workspace.is_personal_trainer`; `nil`
    ///     mientras el contexto no haya llegado.
    ///   - gymType: `type` del espacio (`gym`, `personal_trainer`…).
    static func isAvailable(
        moduleEnabled: Bool?,
        workspaceIsPersonalTrainer: Bool?,
        gymType: String?
    ) -> Bool {
        // 1. Sin ninguna de las dos señales del espacio no se sabe dónde estamos: falla cerrada.
        guard workspaceIsPersonalTrainer != nil || gymType != nil else { return false }
        // 2. Espacio de entrenador personal: no se comparte, aunque el módulo esté encendido.
        if workspaceIsPersonalTrainer == true { return false }
        if gymType == personalTrainerType { return false }
        // 3. Gimnasio tradicional: manda el módulo, y `nil` (todavía sin respuesta) también cierra.
        return moduleEnabled == true
    }
}
