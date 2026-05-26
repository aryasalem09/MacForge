import ApplicationServices
import AppKit
import Foundation

@MainActor
final class AccessibilityWindowService: WindowManaging {
    private let permissionService = AccessibilityPermissionService()

    func listWindows() async -> ([WindowInfo], [CommandResult]) {
        guard permissionService.isTrusted() else {
            return ([], [.failure("Window Manager", "Accessibility permission is required before MacForge can inspect windows.")])
        }

        var windows: [WindowInfo] = []
        var results: [CommandResult] = []
        let focusedWindow = focusedWindowElement()

        for app in NSWorkspace.shared.runningApplications where app.activationPolicy == .regular {
            let appElement = AXUIElementCreateApplication(app.processIdentifier)
            var value: CFTypeRef?
            let copyResult = AXUIElementCopyAttributeValue(appElement, kAXWindowsAttribute as CFString, &value)
            guard copyResult == .success, let axWindows = value as? [AXUIElement] else {
                if copyResult != .attributeUnsupported {
                    results.append(.failure("Window Scan", "Could not read windows for \(app.localizedName ?? "Unknown App").", details: ["AX error: \(copyResult.rawValue)"]))
                }
                continue
            }

            for axWindow in axWindows {
                guard let frame = frame(of: axWindow) else { continue }
                let title = stringAttribute(kAXTitleAttribute, from: axWindow) ?? "Untitled"
                let focused = focusedWindow.map { CFEqual($0, axWindow) } ?? false
                windows.append(
                    WindowInfo(
                        appName: app.localizedName ?? "Unknown App",
                        bundleIdentifier: app.bundleIdentifier,
                        pid: app.processIdentifier,
                        title: title,
                        frame: frame,
                        screenIdentifier: screenIdentifier(for: frame),
                        isFocused: focused,
                        canMove: isSettable(kAXPositionAttribute, on: axWindow),
                        canResize: isSettable(kAXSizeAttribute, on: axWindow)
                    )
                )
            }
        }

        return (windows.sorted { $0.appName.localizedCaseInsensitiveCompare($1.appName) == .orderedAscending }, results)
    }

    func tileFocusedWindow(_ layout: WindowLayoutType, customGrid: CustomGridSelection? = nil) async -> CommandResult {
        guard permissionService.isTrusted() else {
            return .failure("Window Action", "Accessibility permission is required to move or resize windows.")
        }

        guard let window = focusedWindowElement() else {
            return .failure("Window Action", "No focused window was available.")
        }

        let currentFrame = frame(of: window) ?? NSScreen.main?.visibleFrame ?? .zero
        let screen = screen(containing: currentFrame) ?? NSScreen.main
        guard let screen else {
            return .failure("Window Action", "No display was available.")
        }

        do {
            let targetFrame = try WindowLayoutEngine.targetFrame(for: layout, visibleFrame: screen.visibleFrame, customGrid: customGrid)
            return setFrame(targetFrame, for: window, title: layout.label)
        } catch {
            return .failure("Window Action", "Could not calculate a target frame.", details: [error.localizedDescription])
        }
    }

    func moveFocusedWindowToNextDisplay() async -> CommandResult {
        guard permissionService.isTrusted() else {
            return .failure("Next Display", "Accessibility permission is required to move windows.")
        }
        guard NSScreen.screens.count > 1 else {
            return .failure("Next Display", "Only one display is connected.")
        }
        guard let window = focusedWindowElement(), let currentFrame = frame(of: window) else {
            return .failure("Next Display", "No focused window was available.")
        }

        let screens = NSScreen.screens
        let currentIndex = screens.firstIndex { $0.frame.intersects(currentFrame) } ?? 0
        let nextScreen = screens[(currentIndex + 1) % screens.count]
        let target = CGRect(
            x: nextScreen.visibleFrame.midX - currentFrame.width / 2,
            y: nextScreen.visibleFrame.midY - currentFrame.height / 2,
            width: min(currentFrame.width, nextScreen.visibleFrame.width),
            height: min(currentFrame.height, nextScreen.visibleFrame.height)
        )
        return setFrame(target.integral, for: window, title: "Next Display")
    }

    private func focusedWindowElement() -> AXUIElement? {
        let system = AXUIElementCreateSystemWide()
        var focusedAppValue: CFTypeRef?
        guard AXUIElementCopyAttributeValue(system, kAXFocusedApplicationAttribute as CFString, &focusedAppValue) == .success,
              let focusedApp = focusedAppValue else {
            return nil
        }

        var focusedWindowValue: CFTypeRef?
        guard AXUIElementCopyAttributeValue(focusedApp as! AXUIElement, kAXFocusedWindowAttribute as CFString, &focusedWindowValue) == .success,
              let focusedWindowValue else {
            return nil
        }

        return (focusedWindowValue as! AXUIElement)
    }

    private func frame(of window: AXUIElement) -> CGRect? {
        guard let origin = pointAttribute(kAXPositionAttribute, from: window),
              let size = sizeAttribute(kAXSizeAttribute, from: window) else {
            return nil
        }
        return CGRect(origin: origin, size: size)
    }

    private func setFrame(_ frame: CGRect, for window: AXUIElement, title: String) -> CommandResult {
        var origin = frame.origin
        var size = frame.size

        guard let axOrigin = AXValueCreate(.cgPoint, &origin),
              let axSize = AXValueCreate(.cgSize, &size) else {
            return .failure(title, "Could not create Accessibility geometry values.")
        }

        let moveResult = AXUIElementSetAttributeValue(window, kAXPositionAttribute as CFString, axOrigin)
        let sizeResult = AXUIElementSetAttributeValue(window, kAXSizeAttribute as CFString, axSize)

        if moveResult == .success && sizeResult == .success {
            return .success(title, "Window moved to \(Int(frame.width)) x \(Int(frame.height)).")
        }

        return .failure(title, "The focused app refused the requested window change.", details: [
            "Move AX result: \(moveResult.rawValue)",
            "Resize AX result: \(sizeResult.rawValue)"
        ])
    }

    private func stringAttribute(_ attribute: String, from element: AXUIElement) -> String? {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, attribute as CFString, &value) == .success else { return nil }
        return value as? String
    }

    private func pointAttribute(_ attribute: String, from element: AXUIElement) -> CGPoint? {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, attribute as CFString, &value) == .success,
              let axValue = value else { return nil }
        var point = CGPoint.zero
        guard AXValueGetValue(axValue as! AXValue, .cgPoint, &point) else { return nil }
        return point
    }

    private func sizeAttribute(_ attribute: String, from element: AXUIElement) -> CGSize? {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, attribute as CFString, &value) == .success,
              let axValue = value else { return nil }
        var size = CGSize.zero
        guard AXValueGetValue(axValue as! AXValue, .cgSize, &size) else { return nil }
        return size
    }

    private func isSettable(_ attribute: String, on element: AXUIElement) -> Bool {
        var settable = DarwinBoolean(false)
        return AXUIElementIsAttributeSettable(element, attribute as CFString, &settable) == .success && settable.boolValue
    }

    private func screen(containing frame: CGRect) -> NSScreen? {
        NSScreen.screens.max { lhs, rhs in
            lhs.visibleFrame.intersection(frame).area < rhs.visibleFrame.intersection(frame).area
        }
    }

    private func screenIdentifier(for frame: CGRect) -> String? {
        guard let screen = screen(containing: frame) else { return nil }
        return screen.localizedName
    }
}

private extension CGRect {
    var area: CGFloat {
        guard !isNull else { return 0 }
        return width * height
    }
}
