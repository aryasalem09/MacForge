import SwiftUI

struct NotchIslandCollapsedView: View {
    @EnvironmentObject private var environment: AppEnvironment
    @EnvironmentObject private var activityCenter: NotchIslandActivityCenter

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: activityCenter.currentActivity?.symbolName ?? "sparkle")
                .font(.caption.weight(.semibold))
                .foregroundStyle(activityCenter.currentActivity?.isError == true ? .orange : .white.opacity(0.92))

            if environment.notchConfig.showClock {
                TimelineView(.periodic(from: .now, by: 60)) { context in
                    Text(context.date, style: .time)
                        .font(.caption2.monospacedDigit().weight(.semibold))
                        .foregroundStyle(.white.opacity(0.82))
                }
                .frame(width: 46)
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
