import SwiftUI
import UniformTypeIdentifiers

struct NotchIslandControlsView: View {
    @EnvironmentObject private var environment: AppEnvironment
    @State private var isDropTargeted = false

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

            if environment.liveIslandSettings.timersEnabled {
                controlSection(title: "Timers") {
                    HStack(spacing: 8) {
                        timerButton(minutes: 5)
                        timerButton(minutes: 10)
                        timerButton(minutes: 25)
                    }
                }
            }

            controlSection(title: "Tray") {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Label("Drop files here", systemImage: "tray.and.arrow.down")
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
                    .padding(8)
                    .background(isDropTargeted ? .white.opacity(0.16) : .white.opacity(0.07), in: RoundedRectangle(cornerRadius: 8))
                    .onDrop(of: [UTType.fileURL.identifier], isTargeted: $isDropTargeted, perform: handleDrop)

                    if !environment.notchFileTrayItems.isEmpty {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) {
                                ForEach(environment.notchFileTrayItems, id: \.self) { url in
                                    Button {
                                        environment.revealNotchFileTrayItem(url)
                                    } label: {
                                        Label(url.lastPathComponent, systemImage: "doc")
                                            .lineLimit(1)
                                    }
                                    .buttonStyle(.bordered)
                                    .help(url.path)
                                }
                            }
                        }
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
