import AppKit
import SwiftUI

struct NotchIslandExpandedView: View {
    @EnvironmentObject private var environment: AppEnvironment
    @EnvironmentObject private var activityCenter: NotchIslandActivityCenter
    @EnvironmentObject private var liveIslandCoordinator: LiveIslandCoordinator

    var body: some View {
        let snapshot = liveIslandCoordinator.currentSnapshot

        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Spacer()
                Button {
                    activityCenter.collapse()
                } label: {
                    Image(systemName: "chevron.up")
                        .frame(width: 24, height: 22)
                }
                .buttonStyle(.plain)
                .foregroundStyle(.white.opacity(0.78))
                .help("Collapse")
                .accessibilityLabel("Collapse Notch Island")
            }

            liveSnapshotCard(snapshot)

            if environment.notchConfig.showCurrentApp {
                Label(NSWorkspace.shared.frontmostApplication?.localizedName ?? "No App", systemImage: "app.dashed")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.72))
                    .lineLimit(1)
            }

            NotchIslandControlsView()

            if environment.notchConfig.showRecentResults {
                recentResults
            }
        }
        .padding(14)
        .padding(.top, environment.notchConfig.attachedContentTopPadding)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background {
            NotchIslandShellBackground(
                cornerRadius: CGFloat(environment.notchConfig.cornerRadius),
                materialStyle: environment.notchConfig.materialStyle
            )
        }
        .accessibilityLabel("Expanded Notch Island")
    }

    private func liveSnapshotCard(_ snapshot: LiveIslandSnapshot) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(sectionTitle(for: snapshot))
                .font(.caption.weight(.semibold))
                .foregroundStyle(.white.opacity(0.58))

            HStack(alignment: .center, spacing: 12) {
                LiveIslandIconView(snapshot: snapshot, size: 42)

                VStack(alignment: .leading, spacing: 4) {
                    Text(snapshot.kind == .idle ? "MacForge" : snapshot.title)
                        .font(.callout.weight(.semibold))
                        .foregroundStyle(.white)
                        .lineLimit(1)
                    Text(snapshot.kind == .idle ? "Notch Island is ready." : snapshot.subtitle)
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.70))
                        .lineLimit(2)

                    if environment.notchConfig.showActivityProgress, let progress = snapshot.progress {
                        ProgressView(value: progress)
                            .progressViewStyle(.linear)
                            .controlSize(.small)
                            .tint(snapshot.isError ? .orange : .mint)
                    } else if snapshot.kind == .download {
                        ProgressView()
                            .progressViewStyle(.linear)
                            .controlSize(.small)
                            .tint(.mint)
                    }
                }

                Spacer(minLength: 0)
            }

            if !snapshot.actions.isEmpty {
                HStack(spacing: 8) {
                    ForEach(snapshot.actions) { action in
                        Button {
                            perform(action)
                        } label: {
                            Image(systemName: playbackSymbol(for: action, snapshot: snapshot))
                                .frame(width: 28, height: 26)
                        }
                        .buttonStyle(.plain)
                        .foregroundStyle(.white.opacity(action.isEnabled ? 0.88 : 0.34))
                        .disabled(!action.isEnabled)
                        .help(action.title)
                        .accessibilityLabel(action.title)
                    }
                }
            }
        }
        .padding(12)
        .background(.white.opacity(0.07), in: RoundedRectangle(cornerRadius: 8))
        .accessibilityLabel(snapshot.kind == .idle ? "Current activity" : snapshot.title)
    }

    private func perform(_ action: LiveIslandAction) {
        Task {
            let result = await liveIslandCoordinator.performCurrentAction(action.kind)
            if !result.success {
                environment.append(result)
            }
        }
    }

    private func playbackSymbol(for action: LiveIslandAction, snapshot: LiveIslandSnapshot) -> String {
        if action.kind == .playPause, snapshot.playbackState == .playing {
            return "pause.fill"
        }
        if action.kind == .playPause {
            return "play.fill"
        }
        return action.symbolName
    }

    private func sectionTitle(for snapshot: LiveIslandSnapshot) -> String {
        switch snapshot.kind {
        case .music, .video, .browserMedia, .genericMedia:
            return "Now Playing"
        case .download:
            return "Download"
        case .timer:
            return "Timer"
        case .task, .error:
            return "Live Activity"
        case .idle:
            return "Live Island"
        }
    }

    private var recentResults: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Recent")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.white.opacity(0.58))

            if environment.commandResults.isEmpty {
                Label("No recent results", systemImage: "list.bullet.clipboard")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.65))
            } else {
                ForEach(environment.commandResults.prefix(3)) { result in
                    HStack(spacing: 8) {
                        Image(systemName: result.success ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                            .foregroundStyle(result.success ? .mint : .orange)
                        VStack(alignment: .leading, spacing: 1) {
                            Text(result.title)
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.white)
                                .lineLimit(1)
                            Text(result.message)
                                .font(.caption2)
                                .foregroundStyle(.white.opacity(0.62))
                                .lineLimit(1)
                        }
                        Spacer(minLength: 0)
                    }
                }
            }
        }
    }

}
