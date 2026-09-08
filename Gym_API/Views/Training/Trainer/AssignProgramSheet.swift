//
//  AssignProgramSheet.swift
//  Gym_API
//
//  Asignar un programa a un cliente (plan §4.2, §4.3 y §6.2).
//
//  Tres decisiones y un caso especial:
//
//  - **Cuándo empieza.** El contrato exige que `start_date` sea lunes, así que no hay selector de
//    fecha: solo «This week» (el lunes pasado, con los días ya vividos como descanso) y
//    «Next Monday», que es el valor por defecto. Un `DatePicker` aquí solo serviría para que el
//    servidor devolviera 422.
//  - **Cómo.** Copia propia (por defecto, 1:1) o compartido (grupos). La copia se puede ajustar
//    para esta persona sin tocar la plantilla.
//  - **El 409.** «Ya tiene un programa activo» no es un error: es una pregunta. Se responde con
//    una alerta que dice qué va a pasar y reenvía la misma petición con `replace: true`.
//

import SwiftUI
import TrainingCore

struct AssignProgramSheet: View {

    let client: TrainingClientRef
    var onAssigned: () -> Void = {}

    @EnvironmentObject var themeManager: ThemeManager
    @EnvironmentObject var trainingService: TrainingService
    @Environment(\.dismiss) private var dismiss

    @State private var selectedProgramId: Int?
    @State private var startsThisWeek = false
    @State private var mode: TrainingAssignmentMode = .copy
    @State private var isAssigning = false
    @State private var errorMessage: String?
    @State private var showsReplaceAlert = false

    private var theme: ThemeManager.AppTheme { themeManager.currentTheme }

    private var options: AssignmentStartOptions {
        WeekMath.startOptions(today: WeekMath.today(in: .current))
    }

    private var startDate: CalendarDate {
        startsThisWeek ? options.thisWeek : options.nextMonday
    }

    /// Solo se ofrecen programas publicados: asignar un borrador deja al cliente con días vacíos.
    private var programs: [TrainingProgram] {
        trainingService.programs.filter { $0.status == .active }
    }

    private var canAssign: Bool { selectedProgramId != nil && !isAssigning }

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 16) {
                    programSection
                    if selectedProgramId != nil {
                        startSection
                        modeSection
                    }
                    if let errorMessage {
                        Text(errorMessage)
                            .font(TrainingType.caption())
                            .foregroundColor(Color.dynamicTextSecondary(theme: theme))
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 12)
                .padding(.bottom, 40)
            }
            .background(Color.dynamicBackground(theme: theme).ignoresSafeArea())
            .navigationTitle("Assign program")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                        .foregroundColor(Color.dynamicText(theme: theme))
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Assign") { Task { await assign(replace: false) } }
                        .fontWeight(.semibold)
                        .foregroundColor(
                            canAssign
                                ? Color.dynamicAccentText(theme: theme)
                                : Color.dynamicTextTertiary(theme: theme)
                        )
                        .disabled(!canAssign)
                }
            }
            .task { await trainingService.fetchPrograms(status: .active) }
            .alert("Replace the current program?", isPresented: $showsReplaceAlert) {
                Button("Replace", role: .destructive) { Task { await assign(replace: true) } }
                Button("Keep the current one", role: .cancel) {}
            } message: {
                Text("\(client.firstName) already follows a program. Replacing ends it today; the logs stay.")
            }
        }
    }

    // MARK: - Programa

    @ViewBuilder
    private var programSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            TrainingEyebrow(text: "Program")

            switch trainingService.programsState {
            case _ where !programs.isEmpty:
                ForEach(Array(programs.enumerated()), id: \.element.id) { index, program in
                    programRow(program)
                    if index < programs.count - 1 {
                        Divider().background(Color.dynamicBorder(theme: theme).opacity(0.15))
                    }
                }
            case .idle, .loading:
                VStack(spacing: 10) {
                    ForEach(0..<3, id: \.self) { _ in
                        HStack {
                            VStack(alignment: .leading, spacing: 6) {
                                TrainingSkeletonBar(width: 170, height: 14)
                                TrainingSkeletonBar(width: 110, height: 10)
                            }
                            Spacer()
                        }
                        .frame(minHeight: 48)
                    }
                }
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("Loading programs")

            case .failed:
                TrainingRetryRow(
                    message: "Couldn't load your programs.",
                    retryTitle: "Retry",
                    onRetry: { Task { await trainingService.fetchPrograms(status: .active) } }
                )

            case .loaded:
                if programs.isEmpty {
                    Text("No published programs yet. Build one on the web panel and publish it.")
                        .font(TrainingType.body())
                        .foregroundColor(Color.dynamicTextSecondary(theme: theme))
                        .fixedSize(horizontal: false, vertical: true)
                } else {
                    ForEach(Array(programs.enumerated()), id: \.element.id) { index, program in
                        programRow(program)
                        if index < programs.count - 1 {
                            Divider().background(Color.dynamicBorder(theme: theme).opacity(0.15))
                        }
                    }
                }
            }
        }
        .trainingCard(theme: theme)
    }

    private func programRow(_ program: TrainingProgram) -> some View {
        let isSelected = selectedProgramId == program.id

        return Button {
            HapticManager.shared.play(.selection)
            selectedProgramId = program.id
            // Un programa de grupo se comparte por defecto; uno privado se copia. Se puede
            // cambiar debajo, pero el valor de salida es el que casi siempre es correcto.
            mode = program.visibility == .group ? .shared : .copy
            errorMessage = nil
        } label: {
            HStack(spacing: 12) {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(TrainingType.icon(18, weight: .regular))
                    .foregroundColor(
                        isSelected
                            ? Color.dynamicAccentText(theme: theme)
                            : Color.dynamicTextTertiary(theme: theme)
                    )

                VStack(alignment: .leading, spacing: 2) {
                    Text(program.name)
                        .font(TrainingType.headline())
                        .foregroundColor(Color.dynamicText(theme: theme))
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)

                    Text(programSubtitle(program))
                        .font(TrainingType.caption())
                        .foregroundColor(Color.dynamicTextTertiary(theme: theme))
                        .lineLimit(1)
                }

                Spacer(minLength: 0)
            }
            .frame(maxWidth: .infinity, minHeight: 52, alignment: .leading)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(program.name). \(programSubtitle(program))")
        .accessibilityAddTraits(isSelected ? [.isSelected] : [])
    }

    private func programSubtitle(_ program: TrainingProgram) -> String {
        var parts = ["\(program.durationWeeks) week\(program.durationWeeks == 1 ? "" : "s")"]
        parts.append(program.visibility == .group ? "Group" : "Private")
        if let count = program.assignedCount, count > 0 {
            parts.append("\(count) assigned")
        }
        return parts.joined(separator: " · ")
    }

    // MARK: - Inicio

    private var startSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            TrainingEyebrow(text: "Starts")

            choiceRow(
                title: "Next Monday",
                subtitle: TrainingFormat.longDate(options.nextMonday.startOfDay(in: .current)),
                isSelected: !startsThisWeek
            ) { startsThisWeek = false }

            Divider().background(Color.dynamicBorder(theme: theme).opacity(0.15))

            choiceRow(
                title: "This week",
                subtitle: "\(TrainingFormat.longDate(options.thisWeek.startOfDay(in: .current))) · days already gone show as rest",
                isSelected: startsThisWeek
            ) { startsThisWeek = true }
        }
        .trainingCard(theme: theme)
    }

    // MARK: - Modo

    private var modeSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            TrainingEyebrow(text: "Mode")

            choiceRow(
                title: "Personal copy",
                subtitle: "You can adjust loads for \(client.firstName) without touching the template.",
                isSelected: mode == .copy
            ) { mode = .copy }

            Divider().background(Color.dynamicBorder(theme: theme).opacity(0.15))

            choiceRow(
                title: "Shared",
                subtitle: "Everyone on this program reads the same plan.",
                isSelected: mode == .shared
            ) { mode = .shared }
        }
        .trainingCard(theme: theme)
    }

    private func choiceRow(
        title: String,
        subtitle: String,
        isSelected: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button {
            HapticManager.shared.play(.selection)
            action()
            errorMessage = nil
        } label: {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: isSelected ? "largecircle.fill.circle" : "circle")
                    .font(TrainingType.icon(17, weight: .regular))
                    .foregroundColor(
                        isSelected
                            ? Color.dynamicAccentText(theme: theme)
                            : Color.dynamicTextTertiary(theme: theme)
                    )
                    .padding(.top, 2)

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(TrainingType.headline())
                        .foregroundColor(Color.dynamicText(theme: theme))

                    Text(subtitle)
                        .font(TrainingType.caption())
                        .foregroundColor(Color.dynamicTextTertiary(theme: theme))
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 0)
            }
            .frame(maxWidth: .infinity, minHeight: 52, alignment: .leading)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(title). \(subtitle)")
        .accessibilityAddTraits(isSelected ? [.isSelected] : [])
    }

    // MARK: - Asignar

    private func assign(replace: Bool) async {
        guard let programId = selectedProgramId, !isAssigning else { return }
        // Antes del primer await: dos toques serían dos asignaciones y la segunda daría 409.
        isAssigning = true
        errorMessage = nil
        defer { isAssigning = false }

        let request = AssignProgramRequest(
            userIds: [client.id],
            startDate: startDate,
            mode: mode,
            replace: replace
        )

        switch await trainingService.assignProgram(programId: programId, request) {
        case .assigned:
            HapticManager.shared.play(.success)
            onAssigned()
            dismiss()
        case .alreadyAssigned:
            showsReplaceAlert = true
        case .cancelled:
            errorMessage = trainingService.saveErrorMessage ?? "Couldn't assign the program."
            trainingService.saveErrorMessage = nil
        }
    }
}
