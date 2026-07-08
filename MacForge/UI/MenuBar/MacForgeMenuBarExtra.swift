import SwiftUI

/// Island-first menu bar: the notch controls up top, desktop helpers tucked
/// into a submenu.
struct MacForgeMenuBarExtra: View {
    @EnvironmentObject private var environment: AppEnvironment
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        Button("Open MacForge", systemImage: "macwindow") {
            openWindow(id: "main")
            NSApp.activate(ignoringOtherApps: true)
        }

        Button(environment.notchConfig.enabled ? "Turn Off Notch Island" : "Turn On Notch Island", systemImage: "macbook.gen2") {
            environment.toggleNotchShelf()
        }

        if environment.notchConfig.enabled {
            Button("Expand Island", systemImage: "arrow.down.right.and.arrow.up.left") {
                environment.expandNotchIsland()
            }
        }

        if environment.liveIslandSettings.timersEnabled {
            Menu("Start Timer") {
                ForEach([5, 10, 25, 45], id: \.self) { minutes in
                    Button("\(minutes) minutes", systemImage: "timer") {
                        environment.startLiveIslandTimer(minutes: minutes)
                    }
                }
            }
        }

        Divider()

        Menu("Helpers") {
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
        }

        Divider()

        SettingsLink {
            Label("Settings", systemImage: "gearshape")
        }

        Button("Quit MacForge", systemImage: "power") {
            NSApp.terminate(nil)
        }
    }
}
