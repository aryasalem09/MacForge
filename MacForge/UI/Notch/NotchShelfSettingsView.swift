import SwiftUI

struct NotchShelfSettingsView: View {
    @EnvironmentObject private var environment: AppEnvironment

    var body: some View {
        Form {
            Section("Shelf") {
                Toggle("Enable Notch Shelf", isOn: $environment.notchConfig.enabled)
                Picker("Position", selection: $environment.notchConfig.positionMode) {
                    ForEach(NotchShelfPositionMode.allCases) { mode in
                        Text(mode.label).tag(mode)
                    }
                }
                HStack {
                    Slider(value: $environment.notchConfig.width, in: 360...900, step: 10) {
                        Text("Width")
                    }
                    Text("\(Int(environment.notchConfig.width)) px")
                        .frame(width: 70, alignment: .trailing)
                }
                HStack {
                    Slider(value: $environment.notchConfig.height, in: 52...120, step: 2) {
                        Text("Height")
                    }
                    Text("\(Int(environment.notchConfig.height)) px")
                        .frame(width: 70, alignment: .trailing)
                }
                HStack {
                    Slider(value: $environment.notchConfig.opacity, in: 0.45...1.0, step: 0.05) {
                        Text("Opacity")
                    }
                    Text("\(Int(environment.notchConfig.opacity * 100))%")
                        .frame(width: 70, alignment: .trailing)
                }
                Toggle("Ignore mouse events when inactive", isOn: $environment.notchConfig.ignoreMouseEventsWhenInactive)
            }

            Section("Widgets") {
                Toggle("Clock", isOn: $environment.notchConfig.showClock)
                Toggle("Current app", isOn: $environment.notchConfig.showCurrentApp)
                Toggle("Quick folders", isOn: $environment.notchConfig.showFolders)
                Toggle("Window actions", isOn: $environment.notchConfig.showWindowActions)
                Toggle("Preset button", isOn: $environment.notchConfig.showPresets)
                Toggle("Clipboard placeholder", isOn: $environment.notchConfig.showClipboardPreviewPlaceholder)
            }

            Section {
                HStack {
                    Button(environment.notchConfig.enabled ? "Hide Shelf" : "Show Shelf", systemImage: "macbook.gen2") {
                        environment.toggleNotchShelf()
                    }
                    Button("Refresh Position", systemImage: "arrow.triangle.2.circlepath") {
                        environment.updateNotchShelf()
                    }
                }
            } footer: {
                Text("On this MacBook Pro running macOS 26.5, shelf placement uses NSScreen safe area insets when available and falls back to top-center placement on displays without a notch.")
            }
        }
        .formStyle(.grouped)
        .padding(12)
    }
}
