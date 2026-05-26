import SwiftUI

struct WindowListView: View {
    var windows: [WindowInfo]

    var body: some View {
        if windows.isEmpty {
            ContentUnavailableView("No windows detected", systemImage: "rectangle.3.group", description: Text("Grant Accessibility permission, then refresh the list."))
        } else {
            Table(windows) {
                TableColumn("App") { window in
                    HStack {
                        if window.isFocused {
                            Image(systemName: "target")
                                .foregroundStyle(.green)
                        }
                        Text(window.appName)
                    }
                }
                TableColumn("Title") { window in
                    Text(window.title.isEmpty ? "Untitled" : window.title)
                        .lineLimit(1)
                }
                TableColumn("Frame") { window in
                    Text("\(Int(window.frame.width)) x \(Int(window.frame.height))")
                        .monospacedDigit()
                }
                TableColumn("Display") { window in
                    Text(window.screenIdentifier ?? "Unknown")
                }
            }
            .frame(minHeight: 260)
        }
    }
}
