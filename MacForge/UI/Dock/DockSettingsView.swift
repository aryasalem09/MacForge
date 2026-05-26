import SwiftUI

struct DockSettingsView: View {
    @EnvironmentObject private var environment: AppEnvironment

    var body: some View {
        Form {
            Section("Experimental Dock Tweaks") {
                Toggle("Enable Experimental Dock Tweaks", isOn: $environment.experimentalDockTweaksEnabled)
                Text("macOS does not provide a comprehensive public Dock customization framework. MacForge uses a strict whitelist of local defaults commands and shows this feature as experimental.")
                    .foregroundStyle(.secondary)
            }

            Section("Dock Behavior") {
                Toggle("Automatically hide and show the Dock", isOn: $environment.dockSettings.autoHide)
                HStack {
                    Slider(value: $environment.dockSettings.tileSize, in: 16...128, step: 1) {
                        Text("Dock size")
                    }
                    Text("\(Int(environment.dockSettings.tileSize))")
                        .frame(width: 44, alignment: .trailing)
                }
                Toggle("Magnification", isOn: $environment.dockSettings.magnification)
                HStack {
                    Slider(value: $environment.dockSettings.magnificationSize, in: 16...256, step: 1) {
                        Text("Magnification size")
                    }
                    Text("\(Int(environment.dockSettings.magnificationSize))")
                        .frame(width: 44, alignment: .trailing)
                }
                Picker("Position", selection: $environment.dockSettings.position) {
                    ForEach(DockPosition.allCases) { position in
                        Text(position.label).tag(position)
                    }
                }
                Toggle("Show recent applications in Dock", isOn: $environment.dockSettings.showRecentApps)
            }

            Section("Preview") {
                let commands = (try? DockCommandBuilder().buildApplyCommands(for: environment.dockSettings)) ?? []
                ForEach(commands) { command in
                    VStack(alignment: .leading, spacing: 3) {
                        Text(command.summary)
                        Text("\(command.executablePath) \(command.arguments.joined(separator: " "))")
                            .font(.caption.monospaced())
                            .foregroundStyle(.secondary)
                    }
                }
            }

            Section {
                HStack {
                    Button("Apply Dock Settings", systemImage: "checkmark.circle") {
                        Task { await environment.applyDockSettings() }
                    }
                    .disabled(!environment.experimentalDockTweaksEnabled)

                    Button("Reset Dock Keys", systemImage: "arrow.counterclockwise") {
                        Task { await environment.resetDockSettings() }
                    }
                    .disabled(!environment.experimentalDockTweaksEnabled)
                }
            }
        }
        .formStyle(.grouped)
        .padding(12)
    }
}
