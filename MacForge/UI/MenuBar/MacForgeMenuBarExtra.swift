import SwiftUI

struct MacForgeMenuBarExtra: View {
    @EnvironmentObject private var environment: AppEnvironment
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        Button("Open MacForge", systemImage: "macwindow") {
            openWindow(id: "main")
            NSApp.activate(ignoringOtherApps: true)
        }

        Button(environment.notchConfig.enabled ? "Hide Notch Shelf" : "Show Notch Shelf", systemImage: "macbook.gen2") {
            environment.toggleNotchShelf()
        }

        Menu("Apply Preset") {
            if environment.appPresets.isEmpty {
                Text("No presets")
            } else {
                ForEach(environment.appPresets) { preset in
                    Button(preset.name, systemImage: preset.iconName) {
                        Task { await environment.runPreset(preset) }
                    }
                }
            }
        }

        QuickActionsMenu()

        Menu("Open Pinned Folder") {
            if environment.pinnedFolders.isEmpty {
                Text("No pinned folders")
            } else {
                ForEach(environment.pinnedFolders) { folder in
                    Button(folder.name, systemImage: "folder") {
                        environment.openFolder(folder)
                    }
                }
            }
        }

        Divider()

        Button("Permissions", systemImage: "lock.shield") {
            openWindow(id: "main")
            NSApp.activate(ignoringOtherApps: true)
        }

        Button("Settings", systemImage: "gearshape") {
            NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
            NSApp.activate(ignoringOtherApps: true)
        }

        Divider()

        Button("Quit", systemImage: "power") {
            NSApp.terminate(nil)
        }
    }
}
