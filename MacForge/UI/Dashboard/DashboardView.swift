import SwiftUI

struct DashboardView: View {
    @EnvironmentObject private var environment: AppEnvironment

    private var accessibilityStatus: PermissionState? {
        environment.permissionStates.first { $0.id == "accessibility" }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 220), spacing: 14)], spacing: 14) {
                    StatusCardView(
                        title: "Accessibility",
                        value: accessibilityStatus?.status.label ?? "Unknown",
                        subtitle: "Needed for Window Manager actions.",
                        systemImage: "lock.shield",
                        tint: accessibilityStatus?.status == .granted ? .green : .orange
                    )
                    StatusCardView(
                        title: "Visible Windows",
                        value: "\(environment.windows.count)",
                        subtitle: "Detected through public Accessibility APIs.",
                        systemImage: "rectangle.3.group",
                        tint: .blue
                    )
                    StatusCardView(
                        title: "Pinned Folders",
                        value: "\(environment.pinnedFolders.count)",
                        subtitle: "Folders explicitly granted by you.",
                        systemImage: "folder",
                        tint: .teal
                    )
                    StatusCardView(
                        title: "Notch Shelf",
                        value: environment.notchConfig.enabled ? "On" : "Off",
                        subtitle: "Top-center floating HUD.",
                        systemImage: "macbook.gen2",
                        tint: .purple
                    )
                    StatusCardView(
                        title: "Wallpaper",
                        value: environment.wallpaperPresets.first?.name ?? "None",
                        subtitle: "Active wallpaper presets stored locally.",
                        systemImage: "photo",
                        tint: .pink
                    )
                    StatusCardView(
                        title: "Safety Mode",
                        value: environment.safetyConfirmationsEnabled ? "On" : "Off",
                        subtitle: "Previews and confirmations stay enabled for risky actions.",
                        systemImage: "checkmark.shield",
                        tint: .green
                    )
                }

                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Text("Recent Results")
                            .font(.title3.weight(.semibold))
                        Spacer()
                        Button("Refresh Windows") {
                            Task { await environment.refreshWindows() }
                        }
                    }

                    if environment.commandResults.isEmpty {
                        ContentUnavailableView("No command results yet", systemImage: "list.bullet.clipboard", description: Text("MacForge will show every important action here."))
                    } else {
                        ForEach(environment.commandResults.prefix(8)) { result in
                            HStack(alignment: .top, spacing: 12) {
                                Image(systemName: result.success ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                                    .foregroundStyle(result.success ? .green : .orange)
                                VStack(alignment: .leading, spacing: 3) {
                                    Text(result.title)
                                        .font(.headline)
                                    Text(result.message)
                                        .foregroundStyle(.secondary)
                                    if !result.details.isEmpty {
                                        Text(result.details.joined(separator: "\n"))
                                            .font(.caption)
                                            .foregroundStyle(.tertiary)
                                            .lineLimit(3)
                                    }
                                }
                                Spacer()
                                Text(result.timestamp, style: .time)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            .padding(12)
                            .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 8))
                        }
                    }
                }
            }
            .padding(24)
        }
    }
}
