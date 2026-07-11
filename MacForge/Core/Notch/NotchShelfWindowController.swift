import AppKit
import SwiftUI

/// Published bridge between the window controller and the island's SwiftUI
/// content. The controller resizes the panel first, then flips `displayState`
/// so the shape morph always animates inside a window big enough to hold it.
@MainActor
final class NotchIslandLayoutModel: ObservableObject {
    @Published var layout: NotchIslandLayout?
    @Published var displayState: NotchIslandPresentationState = .collapsed
    /// Which expanded tab to show; shared so gestures (like dropping a file on
    /// the collapsed island) can steer the expanded view before it opens.
    @Published var activeExpandedTab: IslandTab = .now
    /// The island shape's actual rendered height (content-hugging when
    /// expanded). Deliberately not @Published: hover hit-testing reads it every
    /// tick and it changes every frame during the morph.
    var displayedShapeHeight: CGFloat = 0
}

@MainActor
final class NotchShelfWindowController {
    /// How long the SwiftUI spring needs before the panel can safely shrink
    /// down to the target frame without clipping the morph animation.
    private static let shrinkDelay: TimeInterval = 0.32

    private var panel: NotchShelfPanel?
    private var activeStyle: NotchShelfPreferredStyle?
    private let layoutModel = NotchIslandLayoutModel()
    private let notchDetectionService = NotchDetectionService()
    private let notchGeometryService = NotchGeometryService()
    private var pendingShrink: DispatchWorkItem?
    private var pendingIslandUpdate: DispatchWorkItem?
    private var globalMouseMonitor: Any?
    private var localMouseMonitor: Any?
    private var hoverPollTimer: Timer?
    private var pointerInsideIsland = false
    private weak var hoverEnvironment: AppEnvironment?

    var isVisible: Bool {
        panel?.isVisible == true
    }

    var currentPanelFrame: CGRect? {
        panel?.frame
    }

    var currentIslandLayout: NotchIslandLayout? {
        layoutModel.layout
    }

    var currentWindowLevelDescription: String {
        guard let panel else { return "none" }
        if panel.level == .statusBar {
            return "statusBar (\(panel.level.rawValue))"
        }
        return "\(panel.level.rawValue)"
    }

    /// The screen the island attaches to: the built-in notched display when
    /// present, otherwise the main screen with a virtual notch.
    static func islandScreen() -> NSScreen? {
        NSScreen.screens.first { $0.safeAreaInsets.top > 0 }
            ?? NSScreen.main
            ?? NSScreen.screens.first
    }

    func update(config: NotchShelfConfig, environment: AppEnvironment) {
        guard config.enabled else {
            hide()
            return
        }

        if activeStyle != config.preferredStyle {
            teardown()
        }
        activeStyle = config.preferredStyle

        if config.preferredStyle == .island {
            updateIsland(config: config, environment: environment)
        } else {
            showClassicShelf(config: config, environment: environment)
        }
    }

    func hide() {
        pendingIslandUpdate?.cancel()
        pendingIslandUpdate = nil
        pendingShrink?.cancel()
        pendingShrink = nil
        stopHoverMonitoring()
        // Collapse the SwiftUI content too, not just the window: an ordered-out
        // panel keeps its view hierarchy alive, so an expanded Mirror tab would
        // otherwise keep the camera session running invisibly.
        if layoutModel.displayState != .collapsed {
            layoutModel.displayState = .collapsed
        }
        panel?.orderOut(nil)
    }

    private func teardown() {
        hide()
        panel = nil
    }

    // MARK: - Hover tracking

    /// Hover is tracked with mouse-location monitors instead of SwiftUI
    /// `.onHover`: a non-activating panel does not reliably get tracking-area
    /// events while another app is frontmost, and monitors keep working
    /// system-wide without any special permissions.
    private func startHoverMonitoring(environment: AppEnvironment) {
        hoverEnvironment = environment
        if globalMouseMonitor == nil {
            globalMouseMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.mouseMoved, .leftMouseDragged]) { [weak self] _ in
                Task { @MainActor in
                    self?.evaluateHover()
                }
            }
        }
        if localMouseMonitor == nil {
            localMouseMonitor = NSEvent.addLocalMonitorForEvents(matching: [.mouseMoved, .leftMouseDragged]) { [weak self] event in
                Task { @MainActor in
                    self?.evaluateHover()
                }
                return event
            }
        }
        if hoverPollTimer == nil {
            // Low-frequency polling backstop: monitors can miss events in
            // some routing situations (full-screen spaces, warped cursors),
            // and the notch band is small enough that hover must never die.
            let timer = Timer(timeInterval: 0.12, repeats: true) { [weak self] _ in
                Task { @MainActor in
                    self?.evaluateHover()
                }
            }
            RunLoop.main.add(timer, forMode: .common)
            hoverPollTimer = timer
        }
    }

    private func stopHoverMonitoring() {
        if let globalMouseMonitor {
            NSEvent.removeMonitor(globalMouseMonitor)
            self.globalMouseMonitor = nil
        }
        if let localMouseMonitor {
            NSEvent.removeMonitor(localMouseMonitor)
            self.localMouseMonitor = nil
        }
        hoverPollTimer?.invalidate()
        hoverPollTimer = nil
        if pointerInsideIsland {
            pointerInsideIsland = false
            hoverEnvironment?.handleNotchHoverChanged(false)
        }
    }

    private func evaluateHover() {
        guard let environment = hoverEnvironment,
              activeStyle == .island,
              panel?.isVisible == true,
              let layout = layoutModel.layout else {
            return
        }

        let inside = hoverRect(layout: layout).contains(NSEvent.mouseLocation)
        guard inside != pointerInsideIsland else { return }
        pointerInsideIsland = inside
        environment.handleNotchHoverChanged(inside)
    }

    /// The island shape's current footprint in global screen coordinates,
    /// with a small grace inset while open so edge jitter doesn't flap the
    /// hover state machine. Uses the actual rendered height so the hover zone
    /// matches a content-hugging expanded shape instead of the configured max.
    private func hoverRect(layout: NotchIslandLayout) -> CGRect {
        let state = layoutModel.displayState
        let size = layout.shapeSize(for: state)
        let displayed = layoutModel.displayedShapeHeight
        let height = state == .expanded && displayed > 1 ? min(displayed, size.height) : size.height
        let notch = layout.notchFrame.rect
        let rect = CGRect(
            x: notch.midX - size.width / 2,
            y: notch.maxY - height,
            width: size.width,
            height: height
        )
        if state == .compact || state == .expanded {
            return rect.insetBy(dx: -10, dy: -10)
        }
        return rect
    }

    // MARK: - Notch Island

    private func updateIsland(config: NotchShelfConfig, environment: AppEnvironment) {
        guard let screen = Self.islandScreen() else {
            hide()
            return
        }

        let state = environment.notchIslandActivityCenter.presentationState
        guard state != .hidden else {
            hide()
            return
        }

        let layout = notchGeometryService.islandLayout(for: screen, config: config)
        startHoverMonitoring(environment: environment)

        // Defer every window mutation (panel creation, setFrame, @Published
        // writes) one runloop turn: setFrame lays out the NSHostingView
        // synchronously, and doing that inside a caller's in-flight SwiftUI
        // update (e.g. AppEnvironment.init's cascade of @Published writes)
        // aborts in AttributeGraph. Only the newest update survives.
        pendingIslandUpdate?.cancel()
        let work = DispatchWorkItem { [weak self, weak environment] in
            guard let self, let environment else { return }
            self.pendingIslandUpdate = nil
            let panel = self.ensureIslandPanel(
                config: config,
                environment: environment,
                initialFrame: layout.panelFrame(for: state)
            )
            // Screen-capture privacy: keep the island out of screenshots and
            // screen shares when the user asks for it.
            panel.sharingType = environment.liveIslandSettings.excludeFromScreenCapture ? .none : .readOnly
            if self.layoutModel.layout != layout {
                self.layoutModel.layout = layout
            }
            self.transition(panel: panel, to: state, layout: layout)
            panel.orderFrontRegardless()
        }
        pendingIslandUpdate = work
        DispatchQueue.main.async(execute: work)
    }

    private func ensureIslandPanel(
        config: NotchShelfConfig,
        environment: AppEnvironment,
        initialFrame: CGRect
    ) -> NotchShelfPanel {
        if let panel {
            return panel
        }

        let panel = NotchShelfPanel(contentRect: initialFrame, style: .island, config: config)
        let root = NotchIslandRootView(model: layoutModel)
            .environmentObject(environment)
            .environmentObject(environment.notchIslandActivityCenter)
            .environmentObject(environment.liveIslandCoordinator)
            .environmentObject(environment.agentActivityCenter)
            .environmentObject(environment.clipboardHistoryCenter)
            .environmentObject(environment.weatherGlanceCenter)
            .environmentObject(environment.keepAwakeController)
        let hostingView = NSHostingView(rootView: AnyView(root))
        hostingView.frame = CGRect(origin: .zero, size: initialFrame.size)
        hostingView.autoresizingMask = [.width, .height]
        panel.contentView = hostingView
        self.panel = panel
        return panel
    }

    /// Moves the panel between state frames without ever animating the window
    /// itself: grow instantly to the union so the SwiftUI morph has room, let
    /// the spring play out, then snap down to the exact target frame.
    private func transition(
        panel: NotchShelfPanel,
        to state: NotchIslandPresentationState,
        layout: NotchIslandLayout
    ) {
        let target = layout.panelFrame(for: state)
        pendingShrink?.cancel()
        pendingShrink = nil

        let union = panel.frame.union(target)
        if panel.frame != union {
            // display: false — let SwiftUI paint on its own schedule instead
            // of forcing a synchronous redraw that can flash a stale frame.
            panel.setFrame(union, display: false)
        }

        if layoutModel.displayState != state {
            layoutModel.displayState = state
        }

        if union != target {
            let shrink = DispatchWorkItem { [weak self] in
                guard let self, let panel = self.panel else { return }
                panel.setFrame(target, display: false)
                self.pendingShrink = nil
            }
            pendingShrink = shrink
            DispatchQueue.main.asyncAfter(deadline: .now() + Self.shrinkDelay, execute: shrink)
        }
    }

    // MARK: - Classic shelf

    private func showClassicShelf(config: NotchShelfConfig, environment: AppEnvironment) {
        let targetFrame = classicShelfFrame(for: config)
        if panel == nil {
            panel = NotchShelfPanel(contentRect: targetFrame, style: .classicShelf, config: config)
        }

        guard let panel else { return }
        panel.alphaValue = config.opacity
        panel.ignoresMouseEvents = config.ignoreMouseEventsWhenInactive
        panel.sharingType = environment.liveIslandSettings.excludeFromScreenCapture ? .none : .readOnly
        panel.contentView = NSHostingView(
            rootView: NotchShelfView().environmentObject(environment)
        )
        panel.setFrame(targetFrame, display: true)
        panel.orderFrontRegardless()
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
