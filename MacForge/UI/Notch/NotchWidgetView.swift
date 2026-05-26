import SwiftUI

struct NotchWidgetView<Content: View>: View {
    var systemImage: String
    @ViewBuilder var content: Content

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: systemImage)
                .foregroundStyle(.secondary)
            content
        }
        .font(.callout.weight(.medium))
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(.black.opacity(0.12), in: RoundedRectangle(cornerRadius: 8))
    }
}
