import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var environment: AppEnvironment

    var body: some View {
        Form {
            Section("General") {
                Toggle("Show app in Dock", isOn: $environment.showInDock)
                Toggle("Launch at login", isOn: Binding(
                    get: { environment.permissionCenter.launchAtLoginEnabled },
                    set: { environment.setLaunchAtLogin($0) }
                ))
            }

            Section("Safety") {
                SafetySettingsView()
            }

            Section("Configuration") {
                HStack {
                    Button("Export JSON", systemImage: "square.and.arrow.up") {
                        environment.append(environment.exportConfiguration())
                    }
                    Button("Import JSON", systemImage: "square.and.arrow.down") {
                        environment.append(environment.importConfiguration())
                    }
                    Button("Reset Preferences", role: .destructive) {
                        environment.resetPreferences()
                    }
                }
            }

            Section("About MacForge") {
                LabeledContent("Version", value: "0.1.0")
                LabeledContent("Target", value: "macOS 14+, tailored on macOS 26.5")
                LabeledContent("Machine", value: "Apple Silicon MacBook Pro with notch-aware safe area support")
            }
        }
        .formStyle(.grouped)
        .padding(12)
    }
}
