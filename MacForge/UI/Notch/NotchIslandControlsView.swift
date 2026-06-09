import SwiftUI

struct NotchIslandControlsView: View {
    @EnvironmentObject private var environment: AppEnvironment

    private var accessibilityGranted: Bool {
        environment.permissionStates.first { $0.id == "accessibility" }?.status == .granted
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            controlSection(title: "Windows") {
                HStack(spacing: 8) {
                    islandButton(.leftHalf)
                    islandButton(.rightHalf)
                    islandButton(.maximize)
                    islandButton(.center)
                    Button {
                        Task { await environment.moveFocusedWindowToNextDisplay() }
                    } label: {
                        Image(systemName: "rectangle.on.rectangle")
                            .frame(width: 26, height: 24)
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(.white.opacity(accessibilityGranted ? 0.88 : 0.34))
                    .disabled(!accessibilityGranted)
                    .help("Next Display")
                    .accessibilityLabel("Move focused window to next display")
                }
                if !accessibilityGranted {
                    Label("Accessibility missing", systemImage: "lock.shield")
                        .font(.caption2)
                        .foregroundStyle(.orange)
                }
            }

            if environment.notchConfig.showFolders {
                controlSection(title: "Folders") {
                    if environment.pinnedFolders.isEmpty {
                        Label("Add folders in File Hub", systemImage: "folder.badge.plus")
                            .font(.caption)
                            .foregroundStyle(.white.opacity(0.65))
                    } else {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) {
                                ForEach(environment.pinnedFolders.prefix(4)) { folder in
                                    Button {
                                        environment.openFolder(folder)
                                    } label: {
                                        Label(folder.name, systemImage: "folder")
                                            .lineLimit(1)
                                    }
                                    .buttonStyle(.bordered)
                                }
                            }
                        }
                    }
                }
            }

            if environment.notchConfig.showPresets {
                controlSection(title: "Presets") {
                    if environment.appPresets.isEmpty {
                        Label("Create presets in Presets", systemImage: "sparkles.rectangle.stack")
                            .font(.caption)
                            .foregroundStyle(.white.opacity(0.65))
                    } else {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) {
                                ForEach(environment.appPresets.prefix(4)) { preset in
                                    Button {
                                        Task { await environment.runPreset(preset) }
                                    } label: {
                                        Label(preset.name, systemImage: preset.iconName)
                                            .lineLimit(1)
                                    }
                                    .buttonStyle(.borderedProminent)
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    private func islandButton(_ layout: WindowLayoutType) -> some View {
        Button {
            Task { await environment.tileFocusedWindow(layout) }
        } label: {
            Image(systemName: layout.symbolName)
                .frame(width: 26, height: 24)
        }
        .buttonStyle(.plain)
        .foregroundStyle(.white.opacity(accessibilityGranted ? 0.88 : 0.34))
        .disabled(!accessibilityGranted)
        .help(layout.label)
        .accessibilityLabel(layout.label)
    }

    private func controlSection<Content: View>(
        title: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.white.opacity(0.58))
            content()
        }
    }
}
