//
//  NeedsAttentionSection.swift
//  Gym_API
//
//  «NEEDS ATTENTION»: el triage de la mañana del entrenador (visión §8.3,
//  `GET /training/clients/summary`).
//
//  Va ENCIMA de «TO REVIEW» porque responden a preguntas distintas y una es más urgente: el
//  buzón enseña lo que tus clientes SÍ hicieron y tú no has mirado; esto enseña a quien no está
//  haciendo nada. Lo segundo es lo que hace perder clientes.
//
//  Dos decisiones que conviene no deshacer:
//
//  1. **Solo aparece quien tiene razones.** El que va bien no sale aquí ni sale marcado en
//     verde en ninguna parte: la ausencia es la buena noticia. Un panel que lista a los doce
//     clientes con un semáforo cada uno vuelve a ser el panel de administración que esto no es.
//  2. **Las razones se pintan tal cual las manda el servidor**, traducidas por
//     `TrainingAttentionReason`. Una razón que esta versión de la app no conoce se enseña con su
//     clave cruda antes que desaparecer.
//
//  Es vista propia, y no un trozo de `TrainerDashboardView`, por lo mismo que `TrainerInboxSection`:
//  para que la galería pueda capturarla sin una maqueta paralela que envejezca.
//

import SwiftUI
import TrainingCore

struct NeedsAttentionSection: View {

    /// Lleva a la pestaña de clientes, que es donde está la lista entera con su filtro.
    let onSeeAll: () -> Void
    /// Abre la ficha de un cliente concreto.
    let onOpenClient: (TrainingClientSummary) -> Void

    @EnvironmentObject var themeManager: ThemeManager
    @EnvironmentObject var trainingService: TrainingService

    private var theme: ThemeManager.AppTheme { themeManager.currentTheme }

    /// Hasta cinco. Quien tenga la sexta razón más grave está en la lista de clientes, y para
    /// eso está «See all»: el panel es un aviso, no un inventario.
    private static let maxRows = 5

    private var summary: TrainingClientsSummary? { trainingService.clientsSummary }
    private var flagged: [TrainingClientSummary] { summary?.needingAttention ?? [] }
    private var rows: [TrainingClientSummary] { Array(flagged.prefix(Self.maxRows)) }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            header
            content
        }
    }

    // MARK: - Cabecera

    private var header: some View {
        HStack(alignment: .firstTextBaseline) {
            Text("NEEDS ATTENTION")
                .font(TrainingType.label())
                .tracking(0.9)
                .foregroundColor(Color.dynamicTextTertiary(theme: theme))
                .padding(.leading, 2)
                .accessibilityAddTraits(.isHeader)

            Spacer()

            if !flagged.isEmpty {
                Button(action: onSeeAll) {
                    Text("See all")
                        .font(TrainingType.caption())
                        .foregroundColor(Color.dynamicAccent(theme: theme))
                }
                .buttonStyle(.plain)
                .trainingTouchTarget(minWidth: 60, minHeight: 32)
                .accessibilityLabel("See all clients")
                .accessibilityHint("Opens the clients tab.")
            }
        }
    }

    // MARK: - Contenido

    @ViewBuilder
    private var content: some View {
        switch trainingService.clientsSummaryState {
        case .loading, .idle where summary == nil:
            VStack(spacing: 10) {
                ForEach(0..<2, id: \.self) { _ in
                    HStack(spacing: 12) {
                        TrainingSkeletonBar(width: 40, height: 40, cornerRadius: 20)
                        VStack(alignment: .leading, spacing: 6) {
                            TrainingSkeletonBar(width: 130, height: 14)
                            TrainingSkeletonBar(width: 180, height: 11)
                        }
                        Spacer(minLength: 0)
                    }
                    .frame(minHeight: 48)
                }
            }
            .trainingCard(theme: theme, padding: 14)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Loading which clients need attention")

        case .failed where summary == nil:
            TrainingRetryRow(
                message: "Couldn't load which clients need attention.",
                retryTitle: "Retry",
                onRetry: { Task { await trainingService.fetchClientsSummary() } }
            )
            .trainingCard(theme: theme, padding: 14)

        default:
            if rows.isEmpty {
                // Vacío honesto y positivo: no hay a quién mirar, no es que no se sepa.
                HStack(alignment: .top, spacing: 10) {
                    Image(systemName: "checkmark.circle")
                        .font(TrainingType.icon(15))
                        .foregroundColor(Color.dynamicTextTertiary(theme: theme))
                    Text(allGoodText)
                        .font(TrainingType.body())
                        .foregroundColor(Color.dynamicTextSecondary(theme: theme))
                        .fixedSize(horizontal: false, vertical: true)
                    Spacer(minLength: 0)
                }
                .trainingDashedCard(theme: theme, padding: 14)
                .accessibilityElement(children: .combine)
            } else {
                VStack(spacing: 0) {
                    ForEach(Array(rows.enumerated()), id: \.element.id) { index, client in
                        row(client)
                        if index < rows.count - 1 {
                            Divider().background(Color.dynamicBorder(theme: theme).opacity(0.15))
                        }
                    }
                }
                .trainingCard(theme: theme, padding: 14)
            }
        }
    }

    /// Con clientes en el espacio, la enhorabuena; sin ninguno, se dice lo que hay.
    private var allGoodText: String {
        let total = summary?.clients.count ?? 0
        return total == 0
            ? "No clients yet. When someone joins your workspace, they show up here."
            : "Everyone's on track. Clients who fall behind land here."
    }

    // MARK: - Fila

    private func row(_ client: TrainingClientSummary) -> some View {
        Button { onOpenClient(client) } label: {
            HStack(spacing: 12) {
                avatar(client)

                VStack(alignment: .leading, spacing: 3) {
                    Text(client.fullName)
                        .font(TrainingType.subhead())
                        .fontWeight(.semibold)
                        .foregroundColor(Color.dynamicText(theme: theme))
                        .lineLimit(1)

                    // Todas las razones en una línea: «Missed 1 · Check-in pending».
                    Text(client.attentionText)
                        .font(TrainingType.caption())
                        .foregroundColor(Color.dynamicWarningText(theme: theme))
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 0)

                Image(systemName: "chevron.right")
                    .font(TrainingType.icon(11, weight: .semibold))
                    .foregroundColor(Color.dynamicTextTertiary(theme: theme))
            }
            .padding(.vertical, 8)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(client.fullName). \(client.attentionText)")
        .accessibilityHint("Opens \(client.firstName)'s programs and logs.")
        .accessibilityAddTraits(.isButton)
    }

    private func avatar(_ client: TrainingClientSummary) -> some View {
        Group {
            if let picture = client.pictureURL, !picture.isEmpty {
                OptimizedAsyncImage(
                    url: picture,
                    displaySize: CGSize(width: 40, height: 40),
                    placeholder: { AnyView(initialsCircle(client)) },
                    errorView: { AnyView(initialsCircle(client)) }
                )
                .frame(width: 40, height: 40)
                .clipShape(Circle())
            } else {
                initialsCircle(client)
            }
        }
        .accessibilityHidden(true)
    }

    private func initialsCircle(_ client: TrainingClientSummary) -> some View {
        ZStack {
            Circle().fill(Color.dynamicSurface2(theme: theme))
            Text(client.initials)
                .font(TrainingType.caption())
                .fontWeight(.bold)
                .foregroundColor(Color.dynamicTextSecondary(theme: theme))
        }
        .frame(width: 40, height: 40)
    }
}
