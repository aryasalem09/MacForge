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
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background {
            Capsule()
                .fill(.black.opacity(0.96))
                .overlay(
                    Capsule()
                        .strokeBorder(.white.opacity(0.08), lineWidth: 1)
                )
        }
        .accessibilityLabel("Collapsed Notch Island")
    }
}
