import AppKit
import SwiftUI

/// Compact live-activity presentation: content lives in the "ears" on either
/// side of the physical notch, exactly like the iPhone's Dynamic Island
/// compact layout. When both media and an agent/CLI task are active the ears
/// split — media on the left, agent progress on the right.
struct NotchIslandCompactView: View {
    var layout: NotchIslandLayout

    @EnvironmentObject private var environment: AppEnvironment
    @EnvironmentObject private var activityCenter: NotchIslandActivityCenter
    @EnvironmentObject private var liveIslandCoordinator: LiveIslandCoordinator
    @EnvironmentObject private var agentCenter: AgentActivityCenter

    private var earWidth: CGFloat {
        CGFloat(NotchIslandLayout.compactEarWidth)
    }

    var body: some View {
        let snapshot = liveIslandCoordinator.currentSnapshot
        let activity = activityCenter.currentActivity
        let agent = agentCenter.primary
        let mediaActive = snapshot.kind != .idle

        HStack(spacing: 0) {
            leftEar(snapshot: snapshot, activity: activity, agent: agent, mediaActive: mediaActive)
                .frame(width: earWidth, alignment: .center)
            Spacer(minLength: 0)
            rightEar(snapshot: snapshot, activity: activity, agent: agent, mediaActive: mediaActive)
                .frame(width: earWidth, alignment: .center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .accessibilityLabel(accessibilityText(snapshot: snapshot, activity: activity, agent: agent))
    }

    @ViewBuilder
    private func leftEar(snapshot: LiveIslandSnapshot, activity: NotchIslandActivity?, agent: AgentActivity?, mediaActive: Bool) -> some View {
        if mediaActive {
            LiveIslandIconView(snapshot: snapshot, size: iconSize)
        } else if let agent {
            AgentEarBadge(activity: agent, size: iconSize)
        } else if let activity {
            Image(systemName: activity.symbolName)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(activity.isError ? .orange : .mint)
        }
    }

    @ViewBuilder
    private func rightEar(snapshot: LiveIslandSnapshot, activity: NotchIslandActivity?, agent: AgentActivity?, mediaActive: Bool) -> some View {
        if mediaActive, let agent {
            // Split: media on the left ear, agent progress on the right.
            AgentEarBadge(activity: agent, size: iconSize)
        } else if mediaActive {
            mediaRightEar(snapshot: snapshot)
        } else if let agent {
            AgentEarProgress(activity: agent)
        } else if let activity {
            miniProgress(activity.progress, isError: activity.isError)
        }
    }

    @ViewBuilder
    private func mediaRightEar(snapshot: LiveIslandSnapshot) -> some View {
        switch snapshot.kind {
        case .music, .video, .browserMedia, .genericMedia:
            NotchAudioBarsView(
                isAnimating: snapshot.playbackState.isPlaying,
                tint: snapshot.isError ? .orange : .mint
            )
        case .timer, .calendar:
            Text(snapshot.subtitle.isEmpty ? snapshot.title : snapshot.subtitle)
                .font(.caption2.weight(.semibold).monospacedDigit())
                .foregroundStyle(.mint)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
                .padding(.horizontal, 2)
        case .hud:
            HUDLevelBarView(level: snapshot.progress ?? 0, symbolName: snapshot.symbolName)
        case .download, .task:
            miniProgress(snapshot.progress, isError: snapshot.isError)
        case .error:
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.orange)
        case .idle:
            EmptyView()
        }
    }

    @ViewBuilder
    private func miniProgress(_ progress: Double?, isError: Bool) -> some View {
        if let progress {
            ProgressView(value: progress.clamped(to: 0...1))
                .progressViewStyle(.circular)
                .controlSize(.small)
                .tint(isError ? .orange : .mint)
        } else {
            ProgressView()
                .progressViewStyle(.circular)
                .controlSize(.small)
                .tint(isError ? .orange : .mint)
        }
    }

    private var iconSize: CGFloat {
        max(CGFloat(layout.compactSize.height) - 14, 18)
    }

    private func accessibilityText(snapshot: LiveIslandSnapshot, activity: NotchIslandActivity?, agent: AgentActivity?) -> String {
        var parts: [String] = []
        if snapshot.kind != .idle {
            parts.append("\(snapshot.title), \(snapshot.subtitle)")
        }
        if let agent {
            parts.append("\(agent.source): \(agent.title)")
        }
        if parts.isEmpty, let activity {
            parts.append("\(activity.title), \(activity.message)")
        }
        return parts.isEmpty ? "Compact Notch Island" : parts.joined(separator: ", ")
    }
}

/// The agent's badge in a compact ear: an app-style tinted icon.
struct AgentEarBadge: View {
    var activity: AgentActivity
    var size: CGFloat

    var body: some View {
        Image(systemName: activity.symbolName)
            .font(.system(size: max(size * 0.5, 12), weight: .semibold))
            .foregroundStyle(tint)
            .frame(width: size, height: size)
            .background(tint.opacity(0.16), in: RoundedRectangle(cornerRadius: size * 0.28))
            .symbolEffect(.pulse, isActive: activity.state == .running)
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

/// The agent's progress readout in a compact ear.
struct AgentEarProgress: View {
    var activity: AgentActivity

    var body: some View {
        if let progress = activity.progress {
            ZStack {
                Circle()
                    .stroke(.white.opacity(0.16), lineWidth: 3)
                Circle()
                    .trim(from: 0, to: progress.clamped(to: 0...1))
                    .stroke(tint, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                    .rotationEffect(.degrees(-90))
            }
            .frame(width: 18, height: 18)
        } else if activity.state == .running {
            ProgressView()
                .progressViewStyle(.circular)
                .controlSize(.small)
                .tint(.cyan)
        } else {
            Image(systemName: activity.symbolName)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(tint)
        }
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

/// Icons resolved from running apps, cached by bundle identifier so the
/// compact ear doesn't rescan the full process list on every render.
enum AppIconCache {
    private static let cache = NSCache<NSString, NSImage>()

    static func icon(forBundleIdentifier bundleIdentifier: String) -> NSImage? {
        if let cached = cache.object(forKey: bundleIdentifier as NSString) {
            return cached
        }
        guard let app = NSWorkspace.shared.runningApplications.first(where: { $0.bundleIdentifier == bundleIdentifier }),
              let icon = app.icon else {
            return nil
        }
        cache.setObject(icon, forKey: bundleIdentifier as NSString)
        return icon
    }
}

/// The compact HUD readout: a tiny level bar next to the state symbol,
/// mirroring the system volume indicator inside the island's right ear.
struct HUDLevelBarView: View {
    var level: Double
    var symbolName: String

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: symbolName)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.white)
            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(.white.opacity(0.22))
                    Capsule()
                        .fill(.white)
                        .frame(width: max(proxy.size.width * level.clamped(to: 0...1), level > 0 ? 3 : 0))
                }
            }
            .frame(width: 34, height: 4)
        }
        .padding(.horizontal, 2)
    }
}

struct LiveIslandIconView: View {
    var snapshot: LiveIslandSnapshot
    var size: CGFloat

    var body: some View {
        ZStack {
            if let bundleIdentifier = snapshot.bundleIdentifier,
               let icon = AppIconCache.icon(forBundleIdentifier: bundleIdentifier) {
                Image(nsImage: icon)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: size, height: size)
                    .clipShape(RoundedRectangle(cornerRadius: size * 0.24))
            } else {
                Image(systemName: snapshot.symbolName)
                    .font(.system(size: max(size * 0.52, 12), weight: .semibold))
                    .foregroundStyle(snapshot.isError ? .orange : .mint)
                    .frame(width: size, height: size)
                    .background(.white.opacity(0.08), in: RoundedRectangle(cornerRadius: size * 0.24))
            }
        }
    }
}
