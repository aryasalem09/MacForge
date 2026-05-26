import SwiftUI

struct PresetsView: View {
    @EnvironmentObject private var environment: AppEnvironment

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                PresetEditorView()

                Text("Presets")
                    .font(.title3.weight(.semibold))

                LazyVGrid(columns: [GridItem(.adaptive(minimum: 280), spacing: 14)], spacing: 14) {
                    ForEach(environment.appPresets) { preset in
                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                Image(systemName: preset.iconName)
                                    .font(.title)
                                    .foregroundStyle(.purple)
                                VStack(alignment: .leading) {
                                    Text(preset.name)
                                        .font(.headline)
                                    if let lastRunDate = preset.lastRunDate {
                                        Text("Last run \(lastRunDate.formatted(date: .abbreviated, time: .shortened))")
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                }
                                Spacer()
                            }
                            PresetRunPreviewView(preset: preset)
                            HStack {
                                Button("Run", systemImage: "play.fill") {
                                    Task { await environment.runPreset(preset) }
                                }
                                Button("Remove", role: .destructive) {
                                    environment.appPresets.removeAll { $0.id == preset.id }
                                }
                            }
                        }
                        .padding(14)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8))
                    }
                }

                if let transaction = environment.lastPresetTransaction {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Last Run")
                            .font(.headline)
                        Text(transaction.presetName)
                        ForEach(transaction.results) { result in
                            Label(result.message, systemImage: result.success ? "checkmark.circle" : "exclamationmark.triangle")
                                .foregroundStyle(result.success ? Color.primary : Color.orange)
                        }
                    }
                    .padding(14)
                    .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 8))
                }
            }
            .padding(24)
        }
    }
}
