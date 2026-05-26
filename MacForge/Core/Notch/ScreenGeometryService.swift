import AppKit
import Foundation

struct ScreenGeometryService {
    func mainScreen() -> NSScreen? {
        NSScreen.main ?? NSScreen.screens.first
    }

    func screenSummary() -> [String] {
        NSScreen.screens.map { screen in
            "\(screen.localizedName): frame \(screen.frame.debugDescription), visible \(screen.visibleFrame.debugDescription), safe top \(Int(screen.safeAreaInsets.top))"
        }
    }
}
