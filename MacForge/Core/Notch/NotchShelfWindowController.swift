import AppKit
import SwiftUI

@MainActor
final class NotchShelfWindowController {
    private var panel: NotchShelfPanel?
    private let notchDetectionService = NotchDetectionService()

    var isVisible: Bool {
        panel?.isVisible == true
    }

    func show(config: NotchShelfConfig, environment: AppEnvironment) {
        let targetFrame = frame(for: config)
        if panel == nil {
            panel = NotchShelfPanel(contentRect: targetFrame, config: config)
        }

        panel?.setFrame(targetFrame, display: true)
        panel?.alphaValue = config.opacity
        panel?.ignoresMouseEvents = config.ignoreMouseEventsWhenInactive
        panel?.contentView = NSHostingView(rootView: NotchShelfView().environmentObject(environment))
        panel?.orderFrontRegardless()
    }

    func hide() {
        panel?.orderOut(nil)
    }

    func update(config: NotchShelfConfig, environment: AppEnvironment) {
        guard config.enabled else {
            hide()
            return
        }
        show(config: config, environment: environment)
    }

    private func frame(for config: NotchShelfConfig) -> CGRect {
        guard let screen = NSScreen.main ?? NSScreen.screens.first else {
            return CGRect(x: 300, y: 700, width: config.width, height: config.height)
        }

        if config.positionMode == .custom {
            return CGRect(x: config.customX, y: config.customY, width: config.width, height: config.height)
        }

        let shelfWidth = min(CGFloat(config.width), screen.visibleFrame.width - 32)
        let shelfHeight = CGFloat(config.height)
        let x = screen.frame.midX - shelfWidth / 2

        let notchInfo = notchDetectionService.detect(on: screen)
        let topInset = config.positionMode == .automaticNotchAware ? (notchInfo?.topSafeAreaInset ?? 0) : 0
        let y = screen.frame.maxY - max(topInset, 0) - shelfHeight - 8

        return CGRect(x: x, y: y, width: shelfWidth, height: shelfHeight)
    }
}
