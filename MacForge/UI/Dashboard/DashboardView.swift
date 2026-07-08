import SwiftUI

/// The island-first overview: a hero card for the notch island itself, a
/// glance at the live widget sources, and the recent-results feed. Desktop
/// helpers live in their own sidebar section, not here.
struct DashboardView: View {
    @EnvironmentObject private var environment: AppEnvironment
    @EnvironmentObject private var liveIslandCoordinator: LiveIslandCoordinator
    @EnvironmentObject private var agentCenter: AgentActivityCenter

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                islandHeroCard

                LazyVGrid(columns: [GridItem(.adaptive(minimum: 220), spacing: 14)], spacing: 14) {
                    StatusCardView(
                        title: "Live Widgets",
                        value: "\(enabledWidgetCount) on",
                        subtitle: widgetSummary,
                        systemImage: "waveform",
                        tint: .mint
                    )
                    StatusCardView(
                        title: "File Tray",
                        value: "\(environment.notchTrayItems.count)",
                        subtitle: environment.trayRetentionMinutes > 0
                            ? "Files kept \(retentionLabel), then removed."
                            : "Files stay until you remove them.",
                        systemImage: "tray.full",
                        tint: .teal
                    )
                    StatusCardView(
                        title: "Agents & CLI",
                        value: agentCenter.runningCount > 0 ? "\(agentCenter.runningCount) running" : "Idle",
                        subtitle: "Terminal jobs can report progress into the notch.",
                        systemImage: "terminal",
                        tint: .cyan
                    )
                    StatusCardView(
                        title: "Safety Mode",
                        value: environment.safetyConfirmationsEnabled ? "On" : "Off",
                        subtitle: "Previews and confirmations stay enabled for risky actions.",
                        systemImage: "checkmark.shield",
                        tint: .green
                    )
                }

                recentResults
            }
            .padding(24)
        }
    }

    // MARK: - Hero

    private var islandHeroCard: some View {
        let snapshot = liveIslandCoordinator.currentSnapshot
        return HStack(alignment: .center, spacing: 16) {
            Image(systemName: "macbook.gen2")
                .font(.system(size: 30, weight: .medium))
                .foregroundStyle(environment.notchConfig.enabled ? .mint : .secondary)
                .frame(width: 58, height: 58)
                .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 14))

            VStack(alignment: .leading, spacing: 4) {
                Text("Notch Island")
                    .font(.title3.weight(.semibold))
                if environment.notchConfig.enabled {
                    Text(snapshot.kind == .idle
                         ? "Ready — hover over the notch to expand."
                         : "\(snapshot.title)\(snapshot.subtitle.isEmpty ? "" : " · \(snapshot.subtitle)")")
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                } else {
                    Text("Turned off. The notch stays untouched.")
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            if environment.notchConfig.enabled {
                Button("Expand") {
                    environment.expandNotchIsland()
                }
            }
            Toggle("", isOn: $environment.notchConfig.enabled)
                .toggleStyle(.switch)
                .labelsHidden()
                .accessibilityLabel("Enable Notch Island")
        }
        .padding(18)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 14))
    }

    // MARK: - Widget summary

    private var enabledWidgetCount: Int {
        let settings = environment.liveIslandSettings
        return [
            settings.appleMusicEnabled,
            settings.spotifyEnabled,
            settings.quickTimeEnabled,
            settings.browserMediaHintsEnabled,
            settings.downloadsWatcherEnabled,
            settings.timersEnabled,
            settings.calendarAgendaEnabled,
            settings.volumeHUDEnabled,
            settings.genericMediaEnabled
        ].filter { $0 }.count
    }

    private var widgetSummary: String {
        let settings = environment.liveIslandSettings
        var names: [String] = []
        if settings.appleMusicEnabled || settings.spotifyEnabled { names.append("Media") }
        if settings.timersEnabled { names.append("Timers") }
        if settings.calendarAgendaEnabled { names.append("Calendar") }
        if settings.volumeHUDEnabled { names.append("Volume HUD") }
        if settings.downloadsWatcherEnabled { names.append("Downloads") }
        return names.isEmpty ? "Enable sources in Island & Widgets." : names.joined(separator: ", ")
    }

    private var retentionLabel: String {
        let minutes = Int(environment.trayRetentionMinutes)
        if minutes >= 1440 { return "\(minutes / 1440) day\(minutes >= 2880 ? "s" : "")" }
        if minutes >= 60 { return "\(minutes / 60) hour\(minutes >= 120 ? "s" : "")" }
        return "\(minutes) min"
    }

    // MARK: - Recent results

    private var recentResults: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Recent Results")
                    .font(.title3.weight(.semibold))
                Spacer()
            }

            if environment.commandResults.isEmpty {
                ContentUnavailableView("No activity yet", systemImage: "list.bullet.clipboard", description: Text("MacForge will show every important action here."))
            } else {
                ForEach(environment.commandResults.prefix(8)) { result in
                    HStack(alignment: .top, spacing: 12) {
                        Image(systemName: result.success ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                            .foregroundStyle(result.success ? .green : .orange)
                        VStack(alignment: .leading, spacing: 3) {
                            Text(result.title)
                                .font(.headline)
                            Text(result.message)
                                .foregroundStyle(.secondary)
                            if !result.details.isEmpty {
                                Text(result.details.joined(separator: "\n"))
                                    .font(.caption)
                                    .foregroundStyle(.tertiary)
                                    .lineLimit(3)
                            }
                        }
                        Spacer()
                        Text(result.timestamp, style: .time)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .padding(12)
                    .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 8))
                }
            }
        }
    }
}
