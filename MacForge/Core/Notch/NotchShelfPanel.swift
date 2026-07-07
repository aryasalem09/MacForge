import AppKit

final class NotchShelfPanel: NSPanel {
    enum Style {
        case island
        case classicShelf
    }

    init(contentRect: NSRect, style: Style, config: NotchShelfConfig) {
        super.init(
            contentRect: contentRect,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        isFloatingPanel = true
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle]
        backgroundColor = .clear
        isOpaque = false
        hidesOnDeactivate = false
        isMovableByWindowBackground = false
        animationBehavior = .none

        switch style {
        case .island:
            // The island blends with the physical notch: full opacity, no
            // AppKit shadow (SwiftUI draws its own), and it must always be
            // able to receive hover events.
            level = .statusBar
            hasShadow = false
            alphaValue = 1
            ignoresMouseEvents = false
            acceptsMouseMovedEvents = true
        case .classicShelf:
            level = .statusBar
            hasShadow = true
            alphaValue = config.opacity
            ignoresMouseEvents = config.ignoreMouseEventsWhenInactive
        }
    }

    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }
}
