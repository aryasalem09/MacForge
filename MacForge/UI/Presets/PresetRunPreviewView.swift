import SwiftUI

struct PresetRunPreviewView: View {
    var preset: AppPreset

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(preset.actions) { action in
                HStack {
                    Image(systemName: "checkmark.circle")
                        .foregroundStyle(.secondary)
                    Text(action.label)
                }
            }
        }
        .padding(12)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 8))
    }
}
