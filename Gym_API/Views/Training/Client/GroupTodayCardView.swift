//
//  GroupTodayCardView.swift
//  Gym_API
//
//  «Your group today» (UX §4). Solo en programas compartidos con visibilidad de grupo.
//
//  Privacidad, que aquí es el diseño: esta tarjeta enseña quién entrenó y nada más. Ni pesos, ni
//  volumen, ni medidas, ni fotos de cuerpos. Y quien NO ha entrenado hoy no sale marcado en
//  negativo: simplemente no está en la fila (UX §4). El backend tampoco manda esos datos
//  (`GroupToday` no tiene dónde guardarlos), así que la regla se cumple en las dos capas.
//

import SwiftUI
import TrainingCore

struct GroupTodayCardView: View {

    let group: GroupToday
    let state: LoadState
    /// Nombre del programa compartido, para la esquina derecha.
    let programName: String
    /// Abre la hoja de kudos de ese miembro.
    let onSelectMember: (GroupTodayMember) -> Void

    @EnvironmentObject var themeManager: ThemeManager
    @Environment(\.trainingReduceMotion) private var reduceMotion

    private var theme: ThemeManager.AppTheme { themeManager.currentTheme }

    private let maximumAvatars = 5

    private var visibleMembers: [GroupTodayMember] {
        Array(group.trainedToday.prefix(maximumAvatars))
    }

    private var overflow: Int {
        max(0, group.trainedToday.count - maximumAvatars)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            TrainingEyebrow(text: "Your group today", trailing: programName)

            if group.trainedToday.isEmpty {
                Text("Nobody's logged yet today. Be first.")
                    .font(TrainingType.body())
                    .foregroundColor(Color.dynamicTextSecondary(theme: theme))
                    .fixedSize(horizontal: false, vertical: true)
            } else {
                avatars
                Text(group.headline)
                    .font(TrainingType.subhead())
                    .foregroundColor(Color.dynamicTextSecondary(theme: theme))
                    .accessibilityHidden(true)
            }

            if group.isNew {
                Text("Consistency starts next week.")
                    .font(TrainingType.caption())
                    .foregroundColor(Color.dynamicTextTertiary(theme: theme))
            } else if !group.week.isEmpty {
                weekStrip
            }

            if state == .failed {
                Text("Couldn't refresh. Showing your last saved data.")
                    .font(TrainingType.caption())
                    .foregroundColor(Color.dynamicTextTertiary(theme: theme))
            }
        }
        .trainingCard(theme: theme)
        .accessibilityElement(children: .contain)
        .accessibilityLabel(containerLabel)
    }

    // MARK: - Avatares

    private var avatars: some View {
        HStack(spacing: -8) {
            ForEach(Array(visibleMembers.enumerated()), id: \.element.userId) { index, member in
                MemberAvatarButton(
                    member: member,
                    index: index,
                    animate: !reduceMotion,
                    onTap: { onSelectMember(member) }
                )
                .zIndex(Double(maximumAvatars - index))
            }

            if overflow > 0 {
                Text("+\(overflow)")
                    .font(TrainingType.caption())
                    .fontWeight(.semibold)
                    .monospacedDigit()
                    .foregroundColor(Color.dynamicTextSecondary(theme: theme))
                    .padding(.leading, 14)
                    .accessibilityLabel("\(overflow) more trained today")
            }

            Spacer(minLength: 0)
        }
    }

    // MARK: - Semana

    private var weekStrip: some View {
        HStack(alignment: .bottom, spacing: 12) {
            HStack(spacing: 6) {
                ForEach(Array(group.week.enumerated()), id: \.element.id) { index, day in
                    VStack(spacing: 4) {
                        bar(for: day)
                        Text(weekdayInitial(index))
                            .font(TrainingType.label())
                            .foregroundColor(Color.dynamicTextTertiary(theme: theme))
                    }
                }
            }

            Spacer(minLength: 0)

            VStack(alignment: .trailing, spacing: 2) {
                Text("This week")
                    .font(TrainingType.caption())
                    .foregroundColor(Color.dynamicTextTertiary(theme: theme))
                if let consistency = group.consistencyPct {
                    Text("\(Int(consistency.rounded()))% consistency")
                        .font(TrainingType.caption())
                        .monospacedDigit()
                        .foregroundColor(Color.dynamicTextSecondary(theme: theme))
                }
            }
            .fixedSize(horizontal: true, vertical: false)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(weekLabel)
    }

    private func bar(for day: GroupTodayWeekDay) -> some View {
        let ratio = group.totalMembers > 0
            ? min(1, Double(day.trainedCount) / Double(group.totalMembers))
            : 0
        return ZStack(alignment: .bottom) {
            RoundedRectangle(cornerRadius: 2)
                .fill(Color.dynamicSurface2(theme: theme))
                .frame(width: 10, height: 20)
            RoundedRectangle(cornerRadius: 2)
                .fill(Color.dynamicAccent(theme: theme).opacity(0.75))
                .frame(width: 10, height: max(2, 20 * ratio))
        }
    }

    private func weekdayInitial(_ index: Int) -> String {
        let initials = ["M", "T", "W", "T", "F", "S", "S"]
        return initials.indices.contains(index) ? initials[index] : ""
    }

    // MARK: - Accesibilidad

    private var containerLabel: String {
        var parts = ["Your group today.", "\(programName)."]
        parts.append("\(group.trainedCount) of \(group.totalMembers) members trained today.")
        if let consistency = group.consistencyPct, !group.isNew {
            parts.append("Group consistency this week, \(Int(consistency.rounded())) percent.")
        }
        return parts.joined(separator: " ")
    }

    private var weekLabel: String {
        let days = group.week.enumerated().map { index, day in
            "\(weekdayName(index)) \(day.trainedCount)"
        }.joined(separator: ", ")
        return "Trained each day this week: \(days)."
    }

    private func weekdayName(_ index: Int) -> String {
        let names = ["Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday", "Sunday"]
        return names.indices.contains(index) ? names[index] : ""
    }
}

// MARK: - Un miembro

private struct MemberAvatarButton: View {

    let member: GroupTodayMember
    let index: Int
    let animate: Bool
    let onTap: () -> Void

    @EnvironmentObject var themeManager: ThemeManager

    @State private var scale: CGFloat = 0.8
    @State private var opacity: Double = 0

    private var theme: ThemeManager.AppTheme { themeManager.currentTheme }

    private var initials: String {
        let parts = member.name.components(separatedBy: " ").prefix(2).compactMap { $0.first }
        let text = parts.map { String($0).uppercased() }.joined()
        return text.isEmpty ? "?" : text
    }

    var body: some View {
        Button(action: {
            HapticManager.shared.play(.selection)
            onTap()
        }) {
            ZStack {
                if let url = member.pictureURL, let parsed = URL(string: url) {
                    AsyncImage(url: parsed) { image in
                        image.resizable().scaledToFill()
                    } placeholder: {
                        initialsCircle
                    }
                } else {
                    initialsCircle
                }
            }
            .frame(width: 32, height: 32)
            .clipShape(Circle())
            .overlay(
                Circle().stroke(
                    member.kudosGiven
                        ? Color.dynamicAccent(theme: theme)
                        : Color.dynamicSurface(theme: theme),
                    lineWidth: 2
                )
            )
            .scaleEffect(scale)
            .opacity(opacity)
            .trainingTouchTarget()
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(member.name). Trained today\(member.dayName.map { ", \($0)" } ?? "").")
        .accessibilityValue(member.kudosGiven ? "Kudos sent" : "")
        .accessibilityHint(member.kudosGiven ? "" : "Double-tap to send kudos.")
        .onAppear(perform: appear)
    }

    private var initialsCircle: some View {
        ZStack {
            Circle().fill(Color.dynamicSurface2(theme: theme))
            Text(initials)
                .font(TrainingType.label())
                .foregroundColor(Color.dynamicTextSecondary(theme: theme))
        }
    }

    private func appear() {
        guard opacity == 0 else { return }
        guard animate else {
            scale = 1
            opacity = 1
            return
        }
        withAnimation(.spring(response: 0.4, dampingFraction: 0.85).delay(Double(index) * 0.04)) {
            scale = 1
            opacity = 1
        }
    }
}
