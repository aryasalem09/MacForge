import SwiftUI

struct QuickActionsMenu: View {
    @EnvironmentObject private var environment: AppEnvironment

    var body: some View {
        Menu("Window Actions") {
            Button("Left Half", systemImage: WindowLayoutType.leftHalf.symbolName) {
                Task { await environment.tileFocusedWindow(.leftHalf) }
            }
            Button("Right Half", systemImage: WindowLayoutType.rightHalf.symbolName) {
                Task { await environment.tileFocusedWindow(.rightHalf) }
            }
            Button("Maximize", systemImage: WindowLayoutType.maximize.symbolName) {
                Task { await environment.tileFocusedWindow(.maximize) }
            }
            Button("Center", systemImage: WindowLayoutType.center.symbolName) {
                Task { await environment.tileFocusedWindow(.center) }
            }
            Button("Next Display", systemImage: "rectangle.on.rectangle") {
                Task { await environment.moveFocusedWindowToNextDisplay() }
            }
        }
    }
}
