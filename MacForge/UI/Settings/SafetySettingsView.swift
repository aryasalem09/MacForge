import SwiftUI

struct SafetySettingsView: View {
    @EnvironmentObject private var environment: AppEnvironment

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Toggle("Safety confirmations", isOn: $environment.safetyConfirmationsEnabled)
            Toggle("Experimental Dock Tweaks", isOn: $environment.experimentalDockTweaksEnabled)
            Text("File rules default to dry-run, destructive deletes are not implemented, Dock commands go through a fixed whitelist, and MacForge never asks for root access.")
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            Divider()

            VStack(alignment: .leading, spacing: 8) {
                Text("Reset MacForge")
                    .font(.headline)
                Text("These actions only restore MacForge-managed runtime state and Dock keys. They do not delete pinned folder contents, user files, wallpapers, or presets.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Button("Restore Dock Managed Settings", systemImage: "dock.rectangle") {
                            Task { await environment.restoreDockManagedSettings() }
                        }
                        Button("Disable Notch Island", systemImage: "capsule") {
                            environment.disableNotchIslandFromSafety()
                        }
                    }
                    HStack {
                        Button("Reset Notch Layout", systemImage: "arrow.counterclockwise") {
                            environment.resetNotchIslandLayout()
                        }
                        Button("Clear Live State", systemImage: "xmark.circle") {
                            environment.clearLiveIslandState()
                        }
                    }
                }

                Button("Panic Reset Everything MacForge Changed", systemImage: "exclamationmark.arrow.triangle.2.circlepath", role: .destructive) {
                    Task { await environment.panicResetMacForgeRuntime() }
                }
                .help("Disables Notch Island, clears transient Live Island state, restores MacForge-managed Dock keys, resets layout, and turns off Experimental Dock Tweaks.")
            }
        }
        .padding(14)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8))
    }
}
