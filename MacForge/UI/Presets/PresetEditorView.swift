import SwiftUI

struct PresetEditorView: View {
    @EnvironmentObject private var environment: AppEnvironment
    @State private var name = "New Preset"
    @State private var iconName = "sparkles"
    @State private var includeShelf = true
    @State private var showShelf = true
    @State private var includeWindowLayout = true
    @State private var layout: WindowLayoutType = .center
    @State private var includeFolder = false
    @State private var selectedFolderID: UUID?
    @State private var includeWallpaper = false
    @State private var selectedWallpaperID: UUID?
    @State private var includeDockSettings = false
    @State private var includeFileRule = false
    @State private var selectedFileRuleID: UUID?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Quick Preset Builder")
                .font(.headline)
            TextField("Name", text: $name)
            TextField("SF Symbol", text: $iconName)

            Toggle("Toggle Notch Shelf", isOn: $includeShelf)
            if includeShelf {
                Toggle("Show Notch Shelf", isOn: $showShelf)
            }

            Toggle("Apply window layout", isOn: $includeWindowLayout)
            if includeWindowLayout {
                Picker("Window Layout", selection: $layout) {
                    ForEach(WindowLayoutType.allCases.filter { $0 != .customGrid }) { layout in
                        Text(layout.label).tag(layout)
                    }
                }
            }

            Toggle("Open pinned folder", isOn: $includeFolder)
                .disabled(environment.pinnedFolders.isEmpty)
            if includeFolder {
                Picker("Pinned Folder", selection: Binding(get: {
                    selectedFolderID ?? environment.pinnedFolders.first?.id
                }, set: { selectedFolderID = $0 })) {
                    ForEach(environment.pinnedFolders) { folder in
                        Text(folder.name).tag(Optional(folder.id))
                    }
                }
            }

            Toggle("Apply wallpaper preset", isOn: $includeWallpaper)
                .disabled(environment.wallpaperPresets.isEmpty)
            if includeWallpaper {
                Picker("Wallpaper Preset", selection: Binding(get: {
                    selectedWallpaperID ?? environment.wallpaperPresets.first?.id
                }, set: { selectedWallpaperID = $0 })) {
                    ForEach(environment.wallpaperPresets) { preset in
                        Text(preset.name).tag(Optional(preset.id))
                    }
                }
            }

            Toggle("Apply current Dock settings (requires Experimental Dock Tweaks)", isOn: $includeDockSettings)

            Toggle("Preview file rule only", isOn: $includeFileRule)
                .disabled(environment.fileRules.isEmpty)
            if includeFileRule {
                Picker("File Rule", selection: Binding(get: {
                    selectedFileRuleID ?? environment.fileRules.first?.id
                }, set: { selectedFileRuleID = $0 })) {
                    ForEach(environment.fileRules) { rule in
                        Text(rule.name).tag(Optional(rule.id))
                    }
                }
            }

            if selectedActions.isEmpty {
                Text("Select at least one action.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Preview")
                        .font(.caption.weight(.semibold))
                    ForEach(selectedActions.map(\.label), id: \.self) { label in
                        Label(label, systemImage: "checkmark.circle")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            Button("Create Preset", systemImage: "plus.circle") {
                createPreset()
            }
            .disabled(selectedActions.isEmpty)
        }
        .padding(14)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8))
    }

    private var selectedActions: [PresetAction] {
        var actions: [PresetAction] = []
        if includeShelf {
            actions.append(.toggleNotchShelf(showShelf))
        }
        if includeWindowLayout {
            actions.append(.applyWindowLayout(WindowLayoutPreset(name: layout.label, layoutType: layout)))
        }
        if includeFolder, let folderID = selectedFolderID ?? environment.pinnedFolders.first?.id {
            actions.append(.openFolder(folderID))
        }
        if includeWallpaper, let wallpaperID = selectedWallpaperID ?? environment.wallpaperPresets.first?.id {
            actions.append(.applyWallpaperPreset(wallpaperID))
        }
        if includeDockSettings {
            actions.append(.applyDockSettings(environment.dockSettings))
        }
        if includeFileRule, let ruleID = selectedFileRuleID ?? environment.fileRules.first?.id {
            actions.append(.runFileRule(ruleID, dryRun: true))
        }
        return actions
    }

    private func createPreset() {
        let preset = AppPreset(
            name: name.isEmpty ? "New Preset" : name,
            iconName: iconName.isEmpty ? "sparkles" : iconName,
            actions: selectedActions,
            requiresConfirmation: environment.safetyConfirmationsEnabled
        )
        environment.appPresets.append(preset)
        environment.append(.success("Preset", "Created \(preset.name)."))
    }
}
