import SwiftUI

struct NotchIslandCollapsedView: View {
    @EnvironmentObject private var environment: AppEnvironment
    @EnvironmentObject private var liveIslandCoordinator: LiveIslandCoordinator

    var body: some View {
        HStack(spacing: 8) {
            if liveIslandCoordinator.currentSnapshot.kind != .idle {
                Image(systemName: liveIslandCoordinator.currentSnapshot.symbolName)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(liveIslandCoordinator.currentSnapshot.isError ? .orange : .white.opacity(0.92))

                if let progress = liveIslandCoordinator.currentSnapshot.progress {
                    ProgressView(value: progress)
                        .progressViewStyle(.linear)
                        .controlSize(.mini)
                        .tint(liveIslandCoordinator.currentSnapshot.isError ? .orange : .mint)
                        .frame(width: 42)
                }
            }
        }
        .padding(.horizontal, 13)
        .padding(.top, environment.notchConfig.attachedContentTopPadding)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background {
            NotchIslandShellBackground(
                cornerRadius: CGFloat(environment.notchConfig.cornerRadius),
                materialStyle: environment.notchConfig.materialStyle
            )
        }
        .accessibilityLabel("Collapsed Notch Island")
    }
}
