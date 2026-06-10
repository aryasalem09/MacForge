import AppKit
import SwiftUI

struct NotchIslandCompactView: View {
    @EnvironmentObject private var environment: AppEnvironment
    @EnvironmentObject private var liveIslandCoordinator: LiveIslandCoordinator

    var body: some View {
        let snapshot = liveIslandCoordinator.currentSnapshot

        HStack(spacing: 10) {
            if snapshot.kind == .idle {
                Spacer(minLength: 0)
            } else {
                LiveIslandIconView(snapshot: snapshot, size: 28)

                VStack(alignment: .leading, spacing: 2) {
                    Text(snapshot.title)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.white)
                        .lineLimit(1)
                    Text(snapshot.subtitle)
                        .font(.caption2)
                        .foregroundStyle(.white.opacity(0.72))
                        .lineLimit(1)

                    if let progress = snapshot.progress {
                        ProgressView(value: progress)
                            .progressViewStyle(.linear)
                            .controlSize(.mini)
                            .tint(snapshot.isError ? .orange : .mint)
                    } else if snapshot.kind == .download {
                        ProgressView()
                            .progressViewStyle(.linear)
                            .controlSize(.mini)
                            .tint(.mint)
                    }
                }

                Spacer(minLength: 0)

                if !snapshot.actions.isEmpty {
                    HStack(spacing: 6) {
                        ForEach(snapshot.actions.prefix(3)) { action in
                            Button {
                                perform(action)
                            } label: {
                                Image(systemName: playbackSymbol(for: action, snapshot: snapshot))
                                    .frame(width: 22, height: 22)
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
        }
        .padding(.horizontal, 14)
        .padding(.top, environment.notchConfig.attachedContentTopPadding)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background {
            NotchIslandShellBackground(
                cornerRadius: CGFloat(environment.notchConfig.cornerRadius),
                materialStyle: environment.notchConfig.materialStyle
            )
        }
        .accessibilityLabel(snapshot.kind == .idle ? "Compact Notch Island" : snapshot.title)
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
}

struct LiveIslandIconView: View {
    var snapshot: LiveIslandSnapshot
    var size: CGFloat

    var body: some View {
        ZStack {
            if let bundleIdentifier = snapshot.bundleIdentifier,
               let app = NSWorkspace.shared.runningApplications.first(where: { $0.bundleIdentifier == bundleIdentifier }),
               let icon = app.icon {
                Image(nsImage: icon)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: size, height: size)
                    .clipShape(RoundedRectangle(cornerRadius: 6))
            } else {
                Image(systemName: snapshot.symbolName)
                    .font(.system(size: max(size * 0.52, 12), weight: .semibold))
                    .foregroundStyle(snapshot.isError ? .orange : .mint)
                    .frame(width: size, height: size)
                    .background(.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 6))
            }
        }
    }
}
