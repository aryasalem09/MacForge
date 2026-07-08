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
                LabeledContent("Version", value: MacForgeBuildInfo.marketingVersion)
                LabeledContent("Build", value: MacForgeBuildInfo.buildNumber)
                LabeledContent("Bundle", value: environment.buildInfo.bundlePath)
                LabeledContent("Config", value: environment.configurationPath)
                LabeledContent("Notch Mode", value: environment.notchConfig.preferredStyle.label)
                LabeledContent("Placement", value: "x \(Int(environment.notchConfig.islandHorizontalOffset)), y \(Int(environment.notchConfig.islandVerticalOffset))")
                LabeledContent("Requires", value: "macOS 14 or later")
            }
        }
        .formStyle(.grouped)
        .padding(12)
    }
}
