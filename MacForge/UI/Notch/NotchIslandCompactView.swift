import AppKit
import SwiftUI

/// Compact live-activity presentation: content lives in the "ears" on either
/// side of the physical notch, exactly like the iPhone's Dynamic Island
/// compact layout. The center band stays empty because the camera housing
/// covers it.
struct NotchIslandCompactView: View {
    var layout: NotchIslandLayout

    @EnvironmentObject private var environment: AppEnvironment
    @EnvironmentObject private var activityCenter: NotchIslandActivityCenter
    @EnvironmentObject private var liveIslandCoordinator: LiveIslandCoordinator

    private var earWidth: CGFloat {
        CGFloat(NotchIslandLayout.compactEarWidth)
    }

    var body: some View {
        let snapshot = liveIslandCoordinator.currentSnapshot
        let activity = activityCenter.currentActivity

        HStack(spacing: 0) {
            leftEar(snapshot: snapshot, activity: activity)
                .frame(width: earWidth, alignment: .center)
            Spacer(minLength: 0)
            rightEar(snapshot: snapshot, activity: activity)
                .frame(width: earWidth, alignment: .center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .accessibilityLabel(accessibilityText(snapshot: snapshot, activity: activity))
    }

    @ViewBuilder
    private func leftEar(snapshot: LiveIslandSnapshot, activity: NotchIslandActivity?) -> some View {
        if snapshot.kind != .idle {
            LiveIslandIconView(snapshot: snapshot, size: iconSize)
        } else if let activity {
            Image(systemName: activity.symbolName)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(activity.isError ? .orange : .mint)
        }
    }

    @ViewBuilder
    private func rightEar(snapshot: LiveIslandSnapshot, activity: NotchIslandActivity?) -> some View {
        switch snapshot.kind {
        case .music, .video, .browserMedia, .genericMedia:
            NotchAudioBarsView(
                isAnimating: snapshot.playbackState.isPlaying,
                tint: snapshot.isError ? .orange : .mint
            )
        case .timer:
            Text(snapshot.subtitle.isEmpty ? snapshot.title : snapshot.subtitle)
                .font(.caption2.weight(.semibold).monospacedDigit())
                .foregroundStyle(.mint)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
                .padding(.horizontal, 2)
        case .download, .task:
            miniProgress(snapshot.progress, isError: snapshot.isError)
        case .error:
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.orange)
        case .idle:
            if let activity {
                miniProgress(activity.progress, isError: activity.isError)
            }
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

    private func accessibilityText(snapshot: LiveIslandSnapshot, activity: NotchIslandActivity?) -> String {
        if snapshot.kind != .idle {
            return "\(snapshot.title), \(snapshot.subtitle)"
        }
        if let activity {
            return "\(activity.title), \(activity.message)"
        }
        return "Compact Notch Island"
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
