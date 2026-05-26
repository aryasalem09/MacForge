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
        }
        .padding(14)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8))
    }
}
