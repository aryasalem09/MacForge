import AppKit
import SwiftUI

struct NotchIslandExpandedView: View {
    @EnvironmentObject private var environment: AppEnvironment
    @EnvironmentObject private var activityCenter: NotchIslandActivityCenter

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                if environment.notchConfig.showCurrentApp {
                    Label(NSWorkspace.shared.frontmostApplication?.localizedName ?? "No App", systemImage: "app.dashed")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.white.opacity(0.72))
                        .lineLimit(1)
                }
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

            NotchIslandActivityView(
                activity: activityCenter.currentActivity,
                showProgress: environment.notchConfig.showActivityProgress
            )

            NotchIslandControlsView()

            if environment.notchConfig.showRecentResults {
                recentResults
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background {
            RoundedRectangle(cornerRadius: environment.notchConfig.cornerRadius)
                .fill(backgroundFill)
                .overlay(
                    RoundedRectangle(cornerRadius: environment.notchConfig.cornerRadius)
                        .strokeBorder(.white.opacity(0.10), lineWidth: 1)
                )
        }
        .accessibilityLabel("Expanded Notch Island")
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

    private var backgroundFill: AnyShapeStyle {
        switch environment.notchConfig.materialStyle {
        case .dark:
            AnyShapeStyle(Color.black.opacity(0.94))
        case .glass:
            AnyShapeStyle(.ultraThinMaterial)
        }
    }
}
