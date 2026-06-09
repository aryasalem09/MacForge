import SwiftUI

struct NotchIslandActivityView: View {
    var activity: NotchIslandActivity?
    var showProgress: Bool

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: activity?.symbolName ?? "sparkle")
                .font(.title3.weight(.semibold))
                .foregroundStyle(activity?.isError == true ? .orange : .mint)
                .frame(width: 28)

            VStack(alignment: .leading, spacing: 4) {
                Text(activity?.title ?? "MacForge")
                    .font(.callout.weight(.semibold))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                Text(activity?.message ?? "Notch Island is ready.")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.70))
                    .lineLimit(2)

                if showProgress, let progress = activity?.progress {
                    ProgressView(value: progress)
                        .progressViewStyle(.linear)
                        .controlSize(.small)
                        .tint(activity?.isError == true ? .orange : .mint)
                }
            }

            Spacer(minLength: 0)
        }
        .padding(12)
        .background(.white.opacity(0.07), in: RoundedRectangle(cornerRadius: 8))
        .accessibilityLabel(activity?.title ?? "Current activity")
    }
}
