import SwiftUI

struct PermissionRowView: View {
    var state: PermissionState
    var action: (() -> Void)?

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: symbolName)
                .foregroundStyle(color)
                .font(.title3)
                .frame(width: 28)
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(state.name)
                        .font(.headline)
                    if state.isRequired {
                        Text("Required")
                            .font(.caption.weight(.semibold))
                            .padding(.horizontal, 7)
                            .padding(.vertical, 3)
                            .background(.orange.opacity(0.16), in: Capsule())
                    }
                }
                Text(state.detail)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer()
            Text(state.status.label)
                .font(.callout.weight(.medium))
                .foregroundStyle(color)
            if let action {
                Button("Open") {
                    action()
                }
            }
        }
        .padding(14)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8))
    }

    private var symbolName: String {
        switch state.status {
        case .granted: "checkmark.circle.fill"
        case .missing: "exclamationmark.triangle.fill"
        case .limited: "info.circle.fill"
        case .disabled: "minus.circle.fill"
        case .unknown: "questionmark.circle.fill"
        }
    }

    private var color: Color {
        switch state.status {
        case .granted: .green
        case .missing: .orange
        case .limited: .blue
        case .disabled: .secondary
        case .unknown: .secondary
        }
    }
}
