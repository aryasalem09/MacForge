import SwiftUI

struct WindowManagerView: View {
    @EnvironmentObject private var environment: AppEnvironment

    private var accessibilityGranted: Bool {
        environment.permissionStates.first { $0.id == "accessibility" }?.status == .granted
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            if !accessibilityGranted {
                ContentUnavailableView {
                    Label("Accessibility Required", systemImage: "lock.shield")
                } description: {
                    Text("macOS requires explicit Accessibility permission before MacForge can inspect, move, or resize windows.")
                } actions: {
                    Button("Open Accessibility Settings") {
                        environment.requestAccessibility()
                    }
                }
                .frame(maxWidth: .infinity, minHeight: 220)
            }

            HStack {
                Text("Focused Window Actions")
                    .font(.title3.weight(.semibold))
                Spacer()
                Button("Refresh", systemImage: "arrow.clockwise") {
                    Task { await environment.refreshWindows() }
                }
            }

            HStack {
                ForEach([WindowLayoutType.leftHalf, .rightHalf, .maximize, .center, .thirdsLeft, .thirdsRight], id: \.self) { layout in
                    Button {
                        Task { await environment.tileFocusedWindow(layout) }
                    } label: {
                        Label(layout.label, systemImage: layout.symbolName)
                    }
                    .disabled(!accessibilityGranted)
                }
                Button("Next Display", systemImage: "rectangle.on.rectangle") {
                    Task { await environment.moveFocusedWindowToNextDisplay() }
                }
                .disabled(!accessibilityGranted)
            }

            WindowLayoutEditorView { layout in
                Task { await environment.tileFocusedWindow(layout) }
            }
            .disabled(!accessibilityGranted)

            WindowListView(windows: environment.windows)
        }
        .padding(24)
    }
}
