import SwiftUI

struct NotchIslandView: View {
    @EnvironmentObject private var environment: AppEnvironment
    @EnvironmentObject private var activityCenter: NotchIslandActivityCenter
    @EnvironmentObject private var liveIslandCoordinator: LiveIslandCoordinator

    var body: some View {
        Group {
            switch activityCenter.presentationState {
            case .hidden, .collapsed:
                NotchIslandCollapsedView()
            case .compact:
                NotchIslandCompactView()
            case .expanded:
                NotchIslandExpandedView()
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .overlay(alignment: .bottom) {
            if environment.notchConfig.showPlacementDebugOverlay {
                Text(debugOverlayText)
                    .font(.caption2.monospaced())
                    .foregroundStyle(.white.opacity(0.74))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(.black.opacity(0.72), in: Capsule())
                    .padding(.bottom, 4)
            }
        }
        .contentShape(Rectangle())
        .onTapGesture {
            guard environment.notchConfig.expandOnClick else { return }
            if activityCenter.presentationState == .expanded {
                activityCenter.collapse()
            } else {
                activityCenter.expand()
            }
        }
        .onHover { isHovering in
            guard environment.notchConfig.expandOnHover else { return }
            if isHovering {
                activityCenter.expand()
            } else if activityCenter.currentActivity == nil {
                activityCenter.collapse()
            }
        }
        .gesture(
            DragGesture(minimumDistance: 14)
                .onEnded { value in
                    handleSwipe(value.translation)
                }
        )
        .onExitCommand {
            activityCenter.collapse()
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Notch Island")
    }

    private func handleSwipe(_ translation: CGSize) {
        if abs(translation.height) > abs(translation.width) {
            if translation.height > 10 {
                activityCenter.expand()
            } else if translation.height < -10 {
                activityCenter.collapse()
            }
            return
        }

        if translation.width < -24 {
            performSupportedMediaAction(.next)
        } else if translation.width > 24 {
            performSupportedMediaAction(.previous)
        }
    }

    private func performSupportedMediaAction(_ kind: LiveIslandActionKind) {
        guard liveIslandCoordinator.currentSnapshot.actions.contains(where: { $0.kind == kind && $0.isEnabled }) else {
            return
        }
        Task {
            let result = await liveIslandCoordinator.performCurrentAction(kind)
            if !result.success {
                environment.append(result)
            }
        }
    }

    private var debugOverlayText: String {
        let config = environment.notchConfig
        let snapshot = liveIslandCoordinator.currentSnapshot
        return "state \(activityCenter.presentationState.rawValue) | \(snapshot.kind.rawValue) | c \(Int(config.collapsedWidth))x\(Int(config.collapsedHeight)) | m \(Int(config.compactWidth))x\(Int(config.compactHeight)) | y \(Int(config.islandVerticalOffset))"
    }
}
