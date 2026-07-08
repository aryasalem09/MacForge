import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate {
    // The activation policy is applied by AppEnvironment from the persisted
    // showInDock setting; hardcoding .regular here overrode hide-from-Dock
    // users on every launch.
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }
}
