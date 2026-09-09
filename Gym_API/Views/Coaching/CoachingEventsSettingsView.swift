import SwiftUI

struct CoachingEventsSettingsRow: View {
    let isEnabled: Bool
    @EnvironmentObject var themeManager: ThemeManager

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: "person.3.sequence.fill")
                .font(TrainingType.icon(21))
                .foregroundStyle(Color.dynamicAccentText(theme: themeManager.currentTheme))
                .frame(width: 48, height: 48)
                .background(Color.dynamicAccent(theme: themeManager.currentTheme).opacity(0.12),
                            in: RoundedRectangle(cornerRadius: 15))
            VStack(alignment: .leading, spacing: 4) {
                Text("Events").font(TrainingType.headline())
                    .foregroundStyle(Color.dynamicText(theme: themeManager.currentTheme))
                Text("Bring your clients together")
                    .font(TrainingType.caption())
                    .foregroundStyle(Color.dynamicTextSecondary(theme: themeManager.currentTheme))
            }
            Spacer(minLength: 4)
            Text(isEnabled ? "On" : "Off")
                .font(TrainingType.caption())
                .foregroundStyle(Color.dynamicTextSecondary(theme: themeManager.currentTheme))
            Image(systemName: "chevron.right")
                .font(TrainingType.icon(12))
                .foregroundStyle(Color.dynamicTextTertiary(theme: themeManager.currentTheme))
        }
        .trainingCard(theme: themeManager.currentTheme)
        .accessibilityElement(children: .combine)
    }
}

struct CoachingEventsSettingsView: View {
    @EnvironmentObject var themeManager: ThemeManager
    @ObservedObject private var workspace = WorkspaceContextService.shared

    private var theme: ThemeManager.AppTheme { themeManager.currentTheme }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                VStack(alignment: .leading, spacing: 16) {
                    CoachingGatheringArtwork()
                        .frame(height: 154)
                        .accessibilityHidden(true)
                    Text("Bring your clients\ntogether.")
                        .font(TrainingType.display())
                        .tracking(-1)
                        .foregroundStyle(Color.dynamicText(theme: theme))
                        .fixedSize(horizontal: false, vertical: true)
                    Text("Make space for shared workouts, hands-on workshops and time with your community.")
                        .font(TrainingType.body())
                        .foregroundStyle(Color.dynamicTextSecondary(theme: theme))
                        .fixedSize(horizontal: false, vertical: true)
                }

                preferenceCard

                VStack(alignment: .leading, spacing: 19) {
                    feature("person.2", title: "One invitation. Your whole community.",
                            text: "Clients discover your events in their app and reserve a place.")
                    feature("ticket", title: "Free meetups or paid workshops",
                            text: workspace.ptEvents?.canSellTickets == true
                                ? "Your payments are connected. Set a ticket price when you create an event."
                                : "Start with free events. Paid tickets become available once your workspace payments are connected.")
                    feature("bubble.left.and.bubble.right", title: "Keep the conversation together",
                            text: "Use each event's chat to share details with the people attending.")
                }
                .padding(.horizontal, 2)

                Text("Turning Events off keeps your history. Finish or cancel upcoming events first so clients can still access their bookings.")
                    .font(TrainingType.caption())
                    .foregroundStyle(Color.dynamicTextTertiary(theme: theme))
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(20)
            .padding(.bottom, 24)
        }
        .background(Color.dynamicBackground(theme: theme))
        .navigationTitle("Events")
        .navigationBarTitleDisplayMode(.inline)
        .task { await workspace.fetchContext(forceRefresh: true) }
    }

    @ViewBuilder
    private var preferenceCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            if let state = workspace.ptEvents {
                Toggle(isOn: Binding(
                    get: { workspace.showsPTEvents },
                    set: { enabled in Task { await workspace.setPTEventsEnabled(enabled) } }
                )) {
                    VStack(alignment: .leading, spacing: 5) {
                        Text("Show Events").font(TrainingType.headline())
                        Text("Add an Events tab for you and your clients.")
                            .font(TrainingType.caption())
                            .foregroundStyle(Color.dynamicTextSecondary(theme: theme))
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .tint(Color.dynamicAccent(theme: theme))
                .disabled(!state.available || !state.canManage || workspace.isSavingEvents)
                .accessibilityIdentifier("pt.events.toggle")
                if workspace.isSavingEvents {
                    HStack(spacing: 8) {
                        ProgressView()
                        Text("Saving for your workspace…").font(TrainingType.caption())
                    }
                } else if !state.available {
                    Text("Events aren't enabled for this workspace yet.")
                        .font(TrainingType.caption())
                    if let url = SupportConfig.supportURL {
                        Link("Contact support", destination: url)
                            .font(TrainingType.caption())
                            .foregroundStyle(Color.dynamicAccentText(theme: theme))
                    }
                } else if !state.canManage {
                    Text("Only an active workspace owner or admin can change this setting.")
                        .font(TrainingType.caption())
                }
            } else if workspace.isLoading {
                HStack(spacing: 12) {
                    ProgressView()
                    Text("Loading your event settings…").font(TrainingType.subhead())
                }
            } else {
                Text("Event settings aren't available right now.").font(TrainingType.subhead())
                Button("Try again") { Task { await workspace.fetchContext(forceRefresh: true) } }
                    .font(TrainingType.caption())
                    .foregroundStyle(Color.dynamicAccentText(theme: theme))
            }
            if let error = workspace.eventsSettingsError {
                Label(error, systemImage: "exclamationmark.circle")
                    .font(TrainingType.caption())
                    .foregroundStyle(Color.dynamicWarningText(theme: theme))
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityIdentifier("pt.events.error")
            }
        }
        .foregroundStyle(Color.dynamicText(theme: theme))
        .trainingCard(theme: theme, padding: 20)
    }

    private func feature(_ icon: String, title: String, text: String) -> some View {
        HStack(alignment: .top, spacing: 13) {
            Image(systemName: icon)
                .font(TrainingType.icon(18, weight: .medium))
                .foregroundStyle(Color.dynamicAccentText(theme: theme))
                .frame(width: 25, height: 25)
            VStack(alignment: .leading, spacing: 5) {
                Text(title).font(TrainingType.subhead().weight(.semibold))
                    .foregroundStyle(Color.dynamicText(theme: theme))
                Text(text).font(TrainingType.caption())
                    .foregroundStyle(Color.dynamicTextSecondary(theme: theme))
            }
            .fixedSize(horizontal: false, vertical: true)
        }
    }
}

/// A small gathering, drawn using the coach's brand colors in both appearances.
struct CoachingGatheringArtwork: View {
    @EnvironmentObject var themeManager: ThemeManager
    private var theme: ThemeManager.AppTheme { themeManager.currentTheme }

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                RoundedRectangle(cornerRadius: 26)
                    .fill(Color.dynamicAccent(theme: theme).opacity(0.07))
                Circle().stroke(Color.dynamicAccent(theme: theme).opacity(0.10), lineWidth: 1)
                    .frame(width: 190, height: 190).offset(x: 100, y: 30)
                Circle().stroke(Color.dynamicAccent(theme: theme).opacity(0.10), lineWidth: 1)
                    .frame(width: 240, height: 240).offset(x: 100, y: 30)
                HStack(spacing: 22) {
                    VStack(alignment: .leading, spacing: 15) {
                        Text("BETTER TOGETHER")
                            .font(TrainingType.label()).tracking(1.1)
                            .foregroundStyle(Color.dynamicAccentText(theme: theme))
                        HStack(spacing: -9) {
                            ForEach(0..<3) { index in
                                Image(systemName: index == 1 ? "figure.strengthtraining.traditional" : "person.fill")
                                    .font(TrainingType.icon(19, weight: .medium))
                                    .foregroundStyle(Color.dynamicText(theme: theme))
                                    .frame(width: 43, height: 43)
                                    .background(Color.dynamicSurface(theme: theme), in: Circle())
                                    .overlay(Circle().stroke(Color.dynamicBackground(theme: theme), lineWidth: 3))
                            }
                        }
                    }
                    Spacer(minLength: 0)
                    Image(systemName: "calendar.badge.plus")
                        .font(.system(size: 49, weight: .light))
                        .foregroundStyle(Color.dynamicAccentText(theme: theme))
                        .rotationEffect(.degrees(-8))
                        .padding(.trailing, 8)
                }
                .padding(24)
            }
            .frame(width: geometry.size.width, height: geometry.size.height)
            .clipShape(RoundedRectangle(cornerRadius: 26))
        }
    }
}
