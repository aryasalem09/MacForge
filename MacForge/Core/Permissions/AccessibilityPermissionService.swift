import ApplicationServices
import AppKit
import Foundation

struct AccessibilityPermissionService {
    func isTrusted(prompt: Bool = false) -> Bool {
        if prompt {
            let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
            return AXIsProcessTrustedWithOptions(options)
        }
        return AXIsProcessTrusted()
    }

    func openAccessibilitySettings() {
        // Apple does not expose a stable public API for jumping directly to a specific privacy
        // pane. This System Settings URL is best-effort and falls back to opening System Settings.
        let directURL = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")
        if let directURL, NSWorkspace.shared.open(directURL) {
            return
        }

        if let settingsURL = URL(string: "x-apple.systempreferences:") {
            NSWorkspace.shared.open(settingsURL)
        }
    }
}
