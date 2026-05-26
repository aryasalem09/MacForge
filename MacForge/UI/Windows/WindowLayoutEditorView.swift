import SwiftUI

struct WindowLayoutEditorView: View {
    @State private var selectedLayout: WindowLayoutType = .leftHalf

    var onRun: (WindowLayoutType) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Layout Preset Editor")
                .font(.headline)
            Picker("Layout", selection: $selectedLayout) {
                ForEach(WindowLayoutType.allCases.filter { $0 != .customGrid }) { layout in
                    Label(layout.label, systemImage: layout.symbolName).tag(layout)
                }
            }
            .pickerStyle(.menu)

            Button("Apply to Focused Window", systemImage: selectedLayout.symbolName) {
                onRun(selectedLayout)
            }
        }
        .padding(14)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8))
    }
}
