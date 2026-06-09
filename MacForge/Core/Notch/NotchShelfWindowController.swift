import AppKit
import QuartzCore
import SwiftUI

@MainActor
final class NotchShelfWindowController {
    private var panel: NotchShelfPanel?
    private let notchDetectionService = NotchDetectionService()
    private let notchGeometryService = NotchGeometryService()

    var isVisible: Bool {
        panel?.isVisible == true
    }

    func show(config: NotchShelfConfig, environment: AppEnvironment) {
        let targetFrame = frame(for: config, environment: environment)
        let hadPanel = panel != nil
        if panel == nil {
            panel = NotchShelfPanel(contentRect: targetFrame, config: config)
        }

        panel?.alphaValue = config.opacity
        panel?.ignoresMouseEvents = config.ignoreMouseEventsWhenInactive
        panel?.contentView = NSHostingView(rootView: rootView(config: config, environment: environment))
        if hadPanel {
            NSAnimationContext.runAnimationGroup { context in
                context.duration = 0.22
                context.timingFunction = CAMediaTimingFunction(name: .easeOut)
                panel?.animator().setFrame(targetFrame, display: true)
            }
        } else {
            panel?.setFrame(targetFrame, display: true)
        }
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

    private func rootView(config: NotchShelfConfig, environment: AppEnvironment) -> AnyView {
        if config.preferredStyle == .island {
            return AnyView(
                NotchIslandView()
                    .environmentObject(environment)
                    .environmentObject(environment.notchIslandActivityCenter)
            )
        }

        return AnyView(NotchShelfView().environmentObject(environment))
    }

    private func frame(for config: NotchShelfConfig, environment: AppEnvironment) -> CGRect {
        if config.preferredStyle == .island {
            return islandFrame(for: config, environment: environment)
        }

        return classicShelfFrame(for: config)
    }

    private func islandFrame(for config: NotchShelfConfig, environment: AppEnvironment) -> CGRect {
        guard let screen = NSScreen.main ?? NSScreen.screens.first else {
            return CGRect(x: 300, y: 700, width: config.collapsedWidth, height: config.collapsedHeight)
        }

        let geometry = notchGeometryService.anchorGeometry(for: screen, config: config)
        switch environment.notchIslandActivityCenter.presentationState {
        case .hidden:
            return geometry.collapsedFrame.rect
        case .collapsed:
            return geometry.collapsedFrame.rect
        case .compact:
            return geometry.compactFrame.rect
        case .expanded:
            return geometry.expandedFrame.rect
        }
    }

    private func classicShelfFrame(for config: NotchShelfConfig) -> CGRect {
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
