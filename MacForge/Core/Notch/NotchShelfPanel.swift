import AppKit

final class NotchShelfPanel: NSPanel {
    init(contentRect: NSRect, config: NotchShelfConfig) {
        super.init(
            contentRect: contentRect,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        isFloatingPanel = true
        level = .statusBar
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
        backgroundColor = .clear
        isOpaque = false
        hasShadow = true
        hidesOnDeactivate = false
        isMovableByWindowBackground = false
        ignoresMouseEvents = config.ignoreMouseEventsWhenInactive
    }

    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }
}
