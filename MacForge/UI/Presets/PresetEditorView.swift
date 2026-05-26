import SwiftUI

struct PresetEditorView: View {
    @EnvironmentObject private var environment: AppEnvironment
    @State private var name = "New Preset"
    @State private var iconName = "sparkles"
    @State private var showShelf = true
    @State private var layout: WindowLayoutType = .center

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Quick Preset Builder")
                .font(.headline)
            TextField("Name", text: $name)
            TextField("SF Symbol", text: $iconName)
            Toggle("Show Notch Shelf", isOn: $showShelf)
            Picker("Window Layout", selection: $layout) {
                ForEach(WindowLayoutType.allCases.filter { $0 != .customGrid }) { layout in
                    Text(layout.label).tag(layout)
                }
            }
            Button("Create Preset", systemImage: "plus.circle") {
                let preset = AppPreset(
                    name: name.isEmpty ? "New Preset" : name,
                    iconName: iconName.isEmpty ? "sparkles" : iconName,
                    actions: [
                        .toggleNotchShelf(showShelf),
                        .applyWindowLayout(WindowLayoutPreset(name: layout.label, layoutType: layout))
                    ],
                    requiresConfirmation: environment.safetyConfirmationsEnabled
                )
                environment.appPresets.append(preset)
                environment.append(.success("Preset", "Created \(preset.name)."))
            }
        }
        .padding(14)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8))
    }
}
