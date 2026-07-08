import AppKit
import SwiftUI
import UniformTypeIdentifiers

/// Window actions, timers, quick folders, and presets — the "Tools" tab of the
/// expanded island.
struct NotchToolsView: View {
    @EnvironmentObject private var environment: AppEnvironment
    @State private var customTimerMinutes = 15

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
                        Divider().frame(height: 16)
                        Stepper(value: $customTimerMinutes, in: 1...180, step: customTimerMinutes >= 30 ? 15 : 5) {
                            Text("\(customTimerMinutes) min")
                                .font(.caption.monospacedDigit())
                                .foregroundStyle(.white.opacity(0.85))
                                .frame(minWidth: 46, alignment: .trailing)
                        }
                        .controlSize(.small)
                        Button {
                            environment.startLiveIslandTimer(minutes: customTimerMinutes)
                        } label: {
                            Image(systemName: "play.circle.fill")
                        }
                        .buttonStyle(.plain)
                        .foregroundStyle(.mint)
                        .help("Start \(customTimerMinutes)-minute timer")
                        .accessibilityLabel("Start custom timer")
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
/// island, matching the NotchNook/DynamicLake file tray. Files survive
/// relaunches via bookmarks and honor the configurable retention window.
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
                    environment.airDropNotchTrayItems(environment.notchTrayItems)
                } label: {
                    Image(systemName: "square.and.arrow.up")
                        .frame(width: 24, height: 22)
                }
                .buttonStyle(.plain)
                .foregroundStyle(.white.opacity(environment.notchTrayItems.isEmpty ? 0.34 : 0.82))
                .disabled(environment.notchTrayItems.isEmpty)
                .help("AirDrop all tray files")
                .accessibilityLabel("AirDrop all tray files")
                Button {
                    environment.clearNotchFileTray()
                } label: {
                    Image(systemName: "trash")
                        .frame(width: 24, height: 22)
                }
                .buttonStyle(.plain)
                .foregroundStyle(.white.opacity(environment.notchTrayItems.isEmpty ? 0.34 : 0.82))
                .disabled(environment.notchTrayItems.isEmpty)
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

            if environment.notchTrayItems.isEmpty {
                Label("No files yet", systemImage: "doc.on.doc")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.5))
            } else {
                ScrollView(.vertical, showsIndicators: false) {
                    VStack(spacing: 6) {
                        ForEach(environment.notchTrayItems) { item in
                            NotchTrayRowView(item: item)
                        }
                    }
                }
            }
        }
        .animation(.spring(response: 0.3, dampingFraction: 0.85), value: environment.notchTrayItems)
    }

    fileprivate func handleDrop(_ providers: [NSItemProvider]) -> Bool {
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

/// A single tray file: click opens it, drag pulls it back out, and the
/// trailing controls cover AirDrop, reveal, and remove.
private struct NotchTrayRowView: View {
    var item: NotchTrayItem

    @EnvironmentObject private var environment: AppEnvironment
    @State private var isHovering = false

    var body: some View {
        HStack(spacing: 8) {
            Image(nsImage: NSWorkspace.shared.icon(forFile: item.path))
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 20, height: 20)
            VStack(alignment: .leading, spacing: 1) {
                Text(item.name)
                    .foregroundStyle(.white)
                    .lineLimit(1)
                Text(item.addedAt, format: .relative(presentation: .named))
                    .font(.caption2)
                    .foregroundStyle(.white.opacity(0.45))
            }
            Spacer(minLength: 0)
            if isHovering {
                trayRowButton("square.and.arrow.up", help: "AirDrop") {
                    environment.airDropNotchTrayItems([item])
                }
                trayRowButton("magnifyingglass", help: "Reveal in Finder") {
                    environment.revealNotchTrayItem(item)
                }
                trayRowButton("xmark", help: "Remove from tray") {
                    environment.removeNotchTrayItem(item)
                }
            }
        }
        .font(.caption)
        .padding(8)
        .background(.white.opacity(isHovering ? 0.1 : 0.06), in: RoundedRectangle(cornerRadius: 8))
        .contentShape(RoundedRectangle(cornerRadius: 8))
        .onTapGesture {
            environment.openNotchTrayItem(item)
        }
        .onHover { hovering in
            withAnimation(.easeOut(duration: 0.12)) {
                isHovering = hovering
            }
        }
        .help(item.path)
        .draggable(item.resolveURL() ?? URL(fileURLWithPath: item.path))
        .contextMenu {
            Button("Open") { environment.openNotchTrayItem(item) }
            Button("Reveal in Finder") { environment.revealNotchTrayItem(item) }
            Button("Send with AirDrop") { environment.airDropNotchTrayItems([item]) }
            Divider()
            Button("Remove from Tray", role: .destructive) { environment.removeNotchTrayItem(item) }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(item.name), added \(item.addedAt.formatted(.relative(presentation: .named)))")
    }

    private func trayRowButton(_ symbolName: String, help: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbolName)
                .font(.system(size: 10, weight: .semibold))
                .frame(width: 20, height: 20)
                .background(.white.opacity(0.1), in: Circle())
        }
        .buttonStyle(.plain)
        .foregroundStyle(.white.opacity(0.85))
        .help(help)
        .accessibilityLabel(help)
    }
}
