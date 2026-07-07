import SwiftUI
import UniformTypeIdentifiers

/// Window actions, timers, quick folders, and presets — the "Tools" tab of the
/// expanded island.
struct NotchToolsView: View {
    @EnvironmentObject private var environment: AppEnvironment

    private var accessibilityGranted: Bool {
        environment.permissionStates.first { $0.id == "accessibility" }?.status == .granted
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
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

            if environment.liveIslandSettings.timersEnabled {
                controlSection(title: "Timers") {
                    HStack(spacing: 8) {
                        timerButton(minutes: 5)
                        timerButton(minutes: 10)
                        timerButton(minutes: 25)
                    }
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

    private func timerButton(minutes: Int) -> some View {
        Button {
            environment.startLiveIslandTimer(minutes: minutes)
        } label: {
            Label("\(minutes) min", systemImage: "timer")
                .lineLimit(1)
        }
        .buttonStyle(.bordered)
        .help("Start \(minutes)-minute timer")
        .accessibilityLabel("Start \(minutes)-minute timer")
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

/// A persistent drag-and-drop file shelf — the "Tray" tab of the expanded
/// island, matching the NotchNook/DynamicLake file tray.
struct NotchTrayView: View {
    @EnvironmentObject private var environment: AppEnvironment
    @State private var isDropTargeted = false

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Label("Drop files to keep them handy", systemImage: "tray.and.arrow.down")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.72))
                Spacer()
                Button {
                    environment.clearNotchFileTray()
                } label: {
                    Image(systemName: "trash")
                        .frame(width: 24, height: 22)
                }
                .buttonStyle(.plain)
                .foregroundStyle(.white.opacity(environment.notchFileTrayItems.isEmpty ? 0.34 : 0.82))
                .disabled(environment.notchFileTrayItems.isEmpty)
                .help("Clear tray")
                .accessibilityLabel("Clear tray")
            }
            .padding(12)
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(isDropTargeted ? Color.mint.opacity(0.18) : Color.white.opacity(0.06))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .strokeBorder(
                        isDropTargeted ? Color.mint.opacity(0.7) : Color.white.opacity(0.12),
                        style: StrokeStyle(lineWidth: 1.4, dash: [6, 4])
                    )
            )
            .onDrop(of: [UTType.fileURL.identifier], isTargeted: $isDropTargeted, perform: handleDrop)

            if environment.notchFileTrayItems.isEmpty {
                Label("No files yet", systemImage: "doc.on.doc")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.5))
            } else {
                ScrollView(.vertical, showsIndicators: false) {
                    VStack(spacing: 6) {
                        ForEach(environment.notchFileTrayItems, id: \.self) { url in
                            Button {
                                environment.revealNotchFileTrayItem(url)
                            } label: {
                                HStack(spacing: 8) {
                                    Image(systemName: "doc")
                                        .foregroundStyle(.mint)
                                    Text(url.lastPathComponent)
                                        .foregroundStyle(.white)
                                        .lineLimit(1)
                                    Spacer(minLength: 0)
                                    Image(systemName: "arrow.up.forward.app")
                                        .foregroundStyle(.white.opacity(0.4))
                                }
                                .font(.caption)
                                .padding(8)
                                .background(.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 8))
                            }
                            .buttonStyle(.plain)
                            .help(url.path)
                            .draggable(url)
                        }
                    }
                }
            }
        }
    }

    private func handleDrop(_ providers: [NSItemProvider]) -> Bool {
        for provider in providers where provider.hasItemConformingToTypeIdentifier(UTType.fileURL.identifier) {
            provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier, options: nil) { item, _ in
                let url: URL?
                if let itemURL = item as? URL {
                    url = itemURL
                } else if let data = item as? Data {
                    url = URL(dataRepresentation: data, relativeTo: nil)
                } else {
                    url = nil
                }

                if let url {
                    DispatchQueue.main.async {
                        environment.addNotchFileTrayItem(url)
                    }
                }
            }
        }

        return true
    }
}
