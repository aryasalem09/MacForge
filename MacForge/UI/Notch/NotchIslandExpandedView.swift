import AppKit
import IOKit.ps
import SwiftUI

enum IslandTab: String, CaseIterable, Identifiable {
    case now
    case agents
    case tray
    case tools

    var id: String { rawValue }

    var label: String {
        switch self {
        case .now: "Now"
        case .agents: "Agents"
        case .tray: "Tray"
        case .tools: "Tools"
        }
    }

    var symbol: String {
        switch self {
        case .now: "play.circle"
        case .agents: "terminal"
        case .tray: "tray.full"
        case .tools: "square.grid.2x2"
        }
    }
}

/// Expanded island content: a header with battery + close, a tab bar, and the
/// selected tab. The root view draws the rounded island shape; this view lays
/// out content starting below the physical notch band.
struct NotchIslandExpandedView: View {
    var topContentInset: CGFloat

    @EnvironmentObject private var environment: AppEnvironment
    @EnvironmentObject private var activityCenter: NotchIslandActivityCenter
    @EnvironmentObject private var liveIslandCoordinator: LiveIslandCoordinator
    @EnvironmentObject private var agentCenter: AgentActivityCenter
    @State private var tab: IslandTab = .now

    var body: some View {
        VStack(spacing: 0) {
            Color.clear.frame(height: topContentInset)

            VStack(spacing: 10) {
                header
                tabBar
                ScrollView(.vertical, showsIndicators: false) {
                    tabContent
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.bottom, 4)
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 14)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .onAppear { selectDefaultTab() }
        .accessibilityLabel("Expanded Notch Island")
    }

    private var header: some View {
        HStack(spacing: 10) {
            if environment.liveIslandSettings.showBatteryInIsland {
                IslandBatteryView()
            }
            Spacer()
            if agentCenter.runningCount > 0 {
                Label("\(agentCenter.runningCount)", systemImage: "bolt.horizontal.circle")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.cyan)
                    .help("\(agentCenter.runningCount) agent task(s) running")
            }
            Button {
                environment.collapseNotchIsland()
            } label: {
                Image(systemName: "chevron.up")
                    .font(.system(size: 12, weight: .semibold))
                    .frame(width: 26, height: 22)
            }
            .buttonStyle(.plain)
            .foregroundStyle(.white.opacity(0.78))
            .help("Collapse")
            .accessibilityLabel("Collapse Notch Island")
        }
    }

    private var tabBar: some View {
        HStack(spacing: 4) {
            ForEach(IslandTab.allCases) { item in
                Button {
                    withAnimation(.easeOut(duration: 0.16)) { tab = item }
                } label: {
                    HStack(spacing: 5) {
                        Image(systemName: item.symbol)
                            .font(.system(size: 11, weight: .semibold))
                        Text(item.label)
                            .font(.caption.weight(.medium))
                        if item == .agents, agentCenter.hasActivity {
                            Circle().fill(.cyan).frame(width: 5, height: 5)
                        }
                    }
                    .padding(.vertical, 6)
                    .frame(maxWidth: .infinity)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(tab == item ? Color.white.opacity(0.14) : Color.clear)
                    )
                    .foregroundStyle(tab == item ? .white : .white.opacity(0.6))
                }
                .buttonStyle(.plain)
                .accessibilityLabel(item.label)
            }
        }
        .padding(3)
        .background(.white.opacity(0.05), in: RoundedRectangle(cornerRadius: 11))
    }

    @ViewBuilder
    private var tabContent: some View {
        switch tab {
        case .now:
            nowTab
        case .agents:
            AgentsPanelView()
        case .tray:
            NotchTrayView()
        case .tools:
            NotchToolsView()
        }
    }

    @ViewBuilder
    private var nowTab: some View {
        let snapshot = liveIslandCoordinator.currentSnapshot
        VStack(alignment: .leading, spacing: 12) {
            if snapshot.kind == .idle {
                idleCard
            } else {
                NowPlayingHero(snapshot: snapshot)
            }

            if agentCenter.hasActivity {
                Button {
                    withAnimation(.easeOut(duration: 0.16)) { tab = .agents }
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "terminal")
                            .foregroundStyle(.cyan)
                        Text(agentSummary)
                            .font(.caption.weight(.medium))
                            .foregroundStyle(.white)
                            .lineLimit(1)
                        Spacer(minLength: 0)
                        Image(systemName: "chevron.right")
                            .font(.caption2)
                            .foregroundStyle(.white.opacity(0.4))
                    }
                    .padding(10)
                    .background(.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 10))
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var idleCard: some View {
        HStack(spacing: 12) {
            Image(systemName: "sparkle")
                .font(.title2)
                .foregroundStyle(.mint)
                .frame(width: 42, height: 42)
                .background(.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 12))
            VStack(alignment: .leading, spacing: 3) {
                Text("Nothing playing")
                    .font(.callout.weight(.semibold))
                    .foregroundStyle(.white)
                Text("Play music or run a task to see it here.")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.6))
            }
            Spacer(minLength: 0)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.white.opacity(0.05), in: RoundedRectangle(cornerRadius: 14))
    }

    private var agentSummary: String {
        if let primary = agentCenter.primary {
            let extra = agentCenter.activities.count - 1
            return extra > 0 ? "\(primary.source): \(primary.title) +\(extra) more" : "\(primary.source): \(primary.title)"
        }
        return "Agent activity"
    }

    private func selectDefaultTab() {
        if liveIslandCoordinator.currentSnapshot.kind == .idle, agentCenter.hasActivity {
            tab = .agents
        } else {
            tab = .now
        }
    }
}

// MARK: - Now Playing hero

struct NowPlayingHero: View {
    var snapshot: LiveIslandSnapshot

    @EnvironmentObject private var environment: AppEnvironment
    @EnvironmentObject private var liveIslandCoordinator: LiveIslandCoordinator

    var body: some View {
        VStack(spacing: 12) {
            HStack(alignment: .center, spacing: 14) {
                ArtworkView(snapshot: snapshot, size: 72)

                VStack(alignment: .leading, spacing: 4) {
                    Text(snapshot.title)
                        .font(.headline)
                        .foregroundStyle(.white)
                        .lineLimit(1)
                    Text(snapshot.subtitle.isEmpty ? (snapshot.appName ?? snapshot.providerName) : snapshot.subtitle)
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.6))
                        .lineLimit(1)
                }

                Spacer(minLength: 0)

                NotchAudioBarsView(isAnimating: snapshot.playbackState.isPlaying, tint: .white.opacity(0.8))
                    .frame(width: 26)
            }

            scrubber

            if !snapshot.actions.isEmpty {
                controls
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity)
        .background(.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 18))
    }

    @ViewBuilder
    private var scrubber: some View {
        let progress = snapshot.progress ?? 0
        VStack(spacing: 4) {
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(.white.opacity(0.16))
                    Capsule().fill(.white)
                        .frame(width: max(0, geo.size.width * progress.clamped(to: 0...1)))
                }
            }
            .frame(height: 4)

            if let elapsed = snapshot.elapsedTime, let duration = snapshot.duration, duration > 0 {
                HStack {
                    Text(timeString(elapsed))
                    Spacer()
                    Text("-" + timeString(max(0, duration - elapsed)))
                }
                .font(.caption2.monospacedDigit())
                .foregroundStyle(.white.opacity(0.55))
            }
        }
    }

    private var controls: some View {
        HStack(spacing: 26) {
            Spacer(minLength: 0)
            controlButton(.previous, size: 18)
            playPauseButton
            controlButton(.next, size: 18)
            if snapshot.actions.contains(where: { $0.kind == .openSource }) {
                controlButton(.openSource, size: 15)
            }
            Spacer(minLength: 0)
        }
        .padding(.top, 2)
    }

    private var playPauseButton: some View {
        let isPlaying = snapshot.playbackState == .playing
        let enabled = snapshot.actions.contains { $0.kind == .playPause && $0.isEnabled }
        return Button {
            perform(.playPause)
        } label: {
            Image(systemName: isPlaying ? "pause.fill" : "play.fill")
                .font(.system(size: 26, weight: .medium))
                .frame(width: 40, height: 40)
        }
        .buttonStyle(.plain)
        .foregroundStyle(.white.opacity(enabled ? 1 : 0.3))
        .disabled(!enabled)
        .accessibilityLabel(isPlaying ? "Pause" : "Play")
    }

    private func controlButton(_ kind: LiveIslandActionKind, size: CGFloat) -> some View {
        let action = snapshot.actions.first { $0.kind == kind }
        let enabled = action?.isEnabled ?? false
        return Button {
            perform(kind)
        } label: {
            Image(systemName: symbol(for: kind))
                .font(.system(size: size, weight: .semibold))
                .frame(width: 30, height: 30)
        }
        .buttonStyle(.plain)
        .foregroundStyle(.white.opacity(enabled ? 0.85 : 0.25))
        .disabled(!enabled)
        .help(action?.title ?? "")
        .accessibilityLabel(action?.title ?? symbol(for: kind))
    }

    private func symbol(for kind: LiveIslandActionKind) -> String {
        switch kind {
        case .previous: "backward.fill"
        case .next: "forward.fill"
        case .openSource: "arrow.up.forward.app"
        case .playPause: "playpause.fill"
        case .cancelTimer: "xmark.circle"
        }
    }

    private func perform(_ kind: LiveIslandActionKind) {
        Task {
            let result = await liveIslandCoordinator.performCurrentAction(kind)
            if !result.success {
                environment.append(result)
            }
        }
    }

    private func timeString(_ interval: TimeInterval) -> String {
        let total = Int(interval.rounded())
        return String(format: "%d:%02d", total / 60, total % 60)
    }
}

/// Album artwork with graceful fallback to the source app's icon.
struct ArtworkView: View {
    var snapshot: LiveIslandSnapshot
    var size: CGFloat

    var body: some View {
        Group {
            if let url = snapshot.artworkURL {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let image):
                        image.resizable().aspectRatio(contentMode: .fill)
                    default:
                        fallback
                    }
                }
            } else {
                fallback
            }
        }
        .frame(width: size, height: size)
        .clipShape(RoundedRectangle(cornerRadius: size * 0.2))
        .overlay(
            RoundedRectangle(cornerRadius: size * 0.2)
                .strokeBorder(.white.opacity(0.1), lineWidth: 1)
        )
    }

    private var fallback: some View {
        LiveIslandIconView(snapshot: snapshot, size: size)
    }
}

// MARK: - Agents

/// The "Agents" tab: live Claude Code / Codex / CLI task progress and
/// notifications piped into the notch. When empty, shows how to connect.
struct AgentsPanelView: View {
    @EnvironmentObject private var environment: AppEnvironment
    @EnvironmentObject private var agentCenter: AgentActivityCenter

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            if agentCenter.activities.isEmpty {
                emptyState
            } else {
                ForEach(agentCenter.activities) { activity in
                    AgentRow(activity: activity)
                }
            }

            footer
        }
    }

    private var emptyState: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 10) {
                Image(systemName: "terminal")
                    .font(.title3)
                    .foregroundStyle(.cyan)
                    .frame(width: 40, height: 40)
                    .background(.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 12))
                VStack(alignment: .leading, spacing: 3) {
                    Text("Pipe your CLIs into the notch")
                        .font(.callout.weight(.semibold))
                        .foregroundStyle(.white)
                    Text("Claude Code, Codex, builds, and any terminal job can show progress and notifications here.")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.6))
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            Text("Append JSON lines to the event log:")
                .font(.caption2)
                .foregroundStyle(.white.opacity(0.5))
            Text(#"echo '{"source":"Claude Code","title":"Building","progress":0.4,"state":"running"}' >> "$MACFORGE_AGENT_EVENTS""#)
                .font(.system(size: 10, design: .monospaced))
                .foregroundStyle(.cyan.opacity(0.9))
                .padding(8)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(.black.opacity(0.4), in: RoundedRectangle(cornerRadius: 8))
                .textSelection(.enabled)
        }
        .padding(12)
        .background(.white.opacity(0.05), in: RoundedRectangle(cornerRadius: 14))
    }

    private var footer: some View {
        HStack(spacing: 8) {
            Button {
                environment.showAgentActivityTest()
            } label: {
                Label("Demo", systemImage: "play.fill").font(.caption)
            }
            .buttonStyle(.bordered)

            Button {
                environment.revealAgentEventLog()
            } label: {
                Label("Log", systemImage: "folder").font(.caption)
            }
            .buttonStyle(.bordered)

            Button {
                environment.copyAgentEventLogPath()
            } label: {
                Label("Copy path", systemImage: "doc.on.doc").font(.caption)
            }
            .buttonStyle(.bordered)

            if agentCenter.hasActivity {
                Spacer(minLength: 0)
                Button {
                    environment.clearAgentActivity()
                } label: {
                    Image(systemName: "trash").font(.caption)
                }
                .buttonStyle(.bordered)
                .help("Clear agent activity")
            }
        }
    }
}

struct AgentRow: View {
    var activity: AgentActivity

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: activity.symbolName)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(tint)
                .frame(width: 30, height: 30)
                .background(tint.opacity(0.15), in: RoundedRectangle(cornerRadius: 8))
                .symbolEffect(.pulse, isActive: activity.state == .running)

            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(activity.title)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.white)
                        .lineLimit(1)
                    Spacer(minLength: 0)
                    Text(activity.source)
                        .font(.system(size: 9, weight: .medium))
                        .foregroundStyle(.white.opacity(0.5))
                        .lineLimit(1)
                }
                if !activity.message.isEmpty {
                    Text(activity.message)
                        .font(.caption2)
                        .foregroundStyle(.white.opacity(0.6))
                        .lineLimit(2)
                }
                if let progress = activity.progress, activity.state == .running {
                    ProgressView(value: progress.clamped(to: 0...1))
                        .progressViewStyle(.linear)
                        .controlSize(.mini)
                        .tint(tint)
                }
            }
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.white.opacity(0.05), in: RoundedRectangle(cornerRadius: 10))
    }

    private var tint: Color {
        switch activity.state {
        case .running: .cyan
        case .success: .mint
        case .failure: .orange
        case .info: .yellow
        }
    }
}

// MARK: - Battery

struct IslandBatteryView: View {
    @State private var level: Double = 1
    @State private var charging = false
    @State private var available = false

    private let timer = Timer.publish(every: 20, on: .main, in: .common).autoconnect()

    var body: some View {
        Group {
            if available {
                HStack(spacing: 4) {
                    Image(systemName: batterySymbol)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(batteryTint)
                    Text("\(Int((level * 100).rounded()))%")
                        .font(.caption2.weight(.semibold).monospacedDigit())
                        .foregroundStyle(.white.opacity(0.8))
                }
                .accessibilityLabel("Battery \(Int((level * 100).rounded())) percent\(charging ? ", charging" : "")")
            }
        }
        .onAppear(perform: refresh)
        .onReceive(timer) { _ in refresh() }
    }

    private var batterySymbol: String {
        if charging { return "battery.100.bolt" }
        switch level {
        case ..<0.15: return "battery.0"
        case ..<0.45: return "battery.25"
        case ..<0.7: return "battery.50"
        case ..<0.9: return "battery.75"
        default: return "battery.100"
        }
    }

    private var batteryTint: Color {
        if charging { return .green }
        return level < 0.2 ? .orange : .white.opacity(0.8)
    }

    private func refresh() {
        guard let info = Self.readBattery() else {
            available = false
            return
        }
        level = info.level
        charging = info.charging
        available = true
    }

    static func readBattery() -> (level: Double, charging: Bool)? {
        guard let blob = IOPSCopyPowerSourcesInfo()?.takeRetainedValue(),
              let sources = IOPSCopyPowerSourcesList(blob)?.takeRetainedValue() as? [CFTypeRef] else {
            return nil
        }
        for source in sources {
            guard let desc = IOPSGetPowerSourceDescription(blob, source)?.takeUnretainedValue() as? [String: Any],
                  let current = desc[kIOPSCurrentCapacityKey as String] as? Int,
                  let max = desc[kIOPSMaxCapacityKey as String] as? Int,
                  max > 0 else {
                continue
            }
            let state = desc[kIOPSPowerSourceStateKey as String] as? String
            let isCharging = (desc[kIOPSIsChargingKey as String] as? Bool) ?? false
            let onAC = state == (kIOPSACPowerValue as String)
            return (Double(current) / Double(max), isCharging || onAC)
        }
        return nil
    }
}
