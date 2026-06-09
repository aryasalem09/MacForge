import SwiftUI

struct NotchIslandCompactView: View {
    @EnvironmentObject private var activityCenter: NotchIslandActivityCenter

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: activityCenter.currentActivity?.symbolName ?? "checkmark.circle.fill")
                .font(.callout.weight(.semibold))
                .foregroundStyle(activityCenter.currentActivity?.isError == true ? .orange : .mint)
                .frame(width: 20)

            VStack(alignment: .leading, spacing: 1) {
                Text(activityCenter.currentActivity?.title ?? "MacForge")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                Text(activityCenter.currentActivity?.message ?? "Ready")
                    .font(.caption2)
                    .foregroundStyle(.white.opacity(0.72))
                    .lineLimit(1)
            }

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 14)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background {
            Capsule()
                .fill(.black.opacity(0.94))
                .overlay(
                    Capsule()
                        .strokeBorder(.white.opacity(0.10), lineWidth: 1)
                )
        }
        .accessibilityLabel(activityCenter.currentActivity?.title ?? "Compact Notch Island")
    }
}
