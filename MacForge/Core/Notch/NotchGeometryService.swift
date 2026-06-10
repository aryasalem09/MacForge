import AppKit
import CoreGraphics
import Foundation

struct CGRectCodable: Hashable, Codable {
    var x: Double
    var y: Double
    var width: Double
    var height: Double

    init(_ rect: CGRect) {
        x = Double(rect.origin.x)
        y = Double(rect.origin.y)
        width = Double(rect.size.width)
        height = Double(rect.size.height)
    }

    init(x: Double, y: Double, width: Double, height: Double) {
        self.x = x
        self.y = y
        self.width = width
        self.height = height
    }

    var rect: CGRect {
        CGRect(x: CGFloat(x), y: CGFloat(y), width: CGFloat(width), height: CGFloat(height))
    }
}

struct EdgeInsetsCodable: Hashable, Codable {
    var top: Double
    var left: Double
    var bottom: Double
    var right: Double

    init(top: Double, left: Double, bottom: Double, right: Double) {
        self.top = top
        self.left = left
        self.bottom = bottom
        self.right = right
    }

    init(_ insets: NSEdgeInsets) {
        top = Double(insets.top)
        left = Double(insets.left)
        bottom = Double(insets.bottom)
        right = Double(insets.right)
    }
}

struct NotchScreenMetrics: Hashable, Codable {
    var screenID: String
    var screenFrame: CGRectCodable
    var visibleFrame: CGRectCodable
    var safeAreaInsets: EdgeInsetsCodable
    var auxiliaryTopLeftArea: CGRectCodable?
    var auxiliaryTopRightArea: CGRectCodable?
    var hasLikelyNotch: Bool
}

struct NotchAnchorGeometry: Hashable, Codable {
    var screenID: String
    var hasLikelyNotch: Bool
    var cameraGapFrame: CGRectCodable
    var collapsedFrame: CGRectCodable
    var compactFrame: CGRectCodable
    var expandedFrame: CGRectCodable
    var fallbackReason: String?
}

struct NotchAttachmentGeometry: Hashable, Codable {
    var screenID: String
    var hasLikelyNotch: Bool
    var cameraGapFrame: CGRectCodable
    var attachedShellFrame: CGRectCodable
    var collapsedContentFrame: CGRectCodable
    var compactContentFrame: CGRectCodable
    var expandedContentFrame: CGRectCodable
    var menuBarBandFrame: CGRectCodable
    var safeInteractiveTopY: Double
    var fallbackReason: String?
}

struct NotchPanelLayout: Hashable, Codable {
    var screenID: String
    var presentationState: NotchIslandPresentationState
    var panelFrame: CGRectCodable
    var shellFrameInPanelCoordinates: CGRectCodable
    var contentFrameInPanelCoordinates: CGRectCodable
    var expandedFrameInPanelCoordinates: CGRectCodable
    var attachmentGeometry: NotchAttachmentGeometry
}

struct NotchGeometryService {
    private let margin: CGFloat = 16
    private let defaultCameraGapWidth: CGFloat = 210
    private let defaultCameraGapHeight: CGFloat = 34
    private let fallbackTopPadding: CGFloat = 8

    func metrics(for screen: NSScreen) -> NotchScreenMetrics {
        let leftArea = screen.auxiliaryTopLeftArea
        let rightArea = screen.auxiliaryTopRightArea
        let hasAuxiliaryGap: Bool
        if let leftArea, let rightArea {
            hasAuxiliaryGap = !leftArea.isEmpty && !rightArea.isEmpty && rightArea.minX > leftArea.maxX
        } else {
            hasAuxiliaryGap = false
        }
        let hasLikelyNotch = hasAuxiliaryGap || screen.safeAreaInsets.top > 0

        return NotchScreenMetrics(
            screenID: screen.localizedName,
            screenFrame: CGRectCodable(screen.frame),
            visibleFrame: CGRectCodable(screen.visibleFrame),
            safeAreaInsets: EdgeInsetsCodable(screen.safeAreaInsets),
            auxiliaryTopLeftArea: leftArea.flatMap { $0.isEmpty ? nil : CGRectCodable($0) },
            auxiliaryTopRightArea: rightArea.flatMap { $0.isEmpty ? nil : CGRectCodable($0) },
            hasLikelyNotch: hasLikelyNotch
        )
    }

    func anchorGeometry(for screen: NSScreen, config: NotchShelfConfig) -> NotchAnchorGeometry {
        anchorGeometry(metrics: metrics(for: screen), config: config)
    }

    func anchorGeometry(metrics: NotchScreenMetrics, config: NotchShelfConfig = .default) -> NotchAnchorGeometry {
        let geometry = attachmentGeometry(metrics: metrics, config: config)
        return NotchAnchorGeometry(
            screenID: geometry.screenID,
            hasLikelyNotch: geometry.hasLikelyNotch,
            cameraGapFrame: geometry.cameraGapFrame,
            collapsedFrame: geometry.collapsedContentFrame,
            compactFrame: geometry.compactContentFrame,
            expandedFrame: geometry.expandedContentFrame,
            fallbackReason: geometry.fallbackReason
        )
    }

    func attachmentGeometry(for screen: NSScreen, config: NotchShelfConfig) -> NotchAttachmentGeometry {
        attachmentGeometry(metrics: metrics(for: screen), config: config)
    }

    func attachmentGeometry(metrics: NotchScreenMetrics, config: NotchShelfConfig = .default) -> NotchAttachmentGeometry {
        let screenFrame = metrics.screenFrame.rect
        let topInset = CGFloat(metrics.safeAreaInsets.top)
        let hasAuxiliaryGap = inferredAuxiliaryGap(metrics: metrics) != nil
        let hasLikelyNotch = metrics.hasLikelyNotch || hasAuxiliaryGap || topInset > 0
        let cameraGapFrame = cameraGap(metrics: metrics)
        let horizontalOffset = CGFloat(config.islandHorizontalOffset.clamped(to: -160...160))
        let anchorCenterX = cameraGapFrame.midX + horizontalOffset

        let configuredCollapsedWidth = min(max(CGFloat(config.collapsedWidth), 160), 280)
        let collapsedWidth = clampedWidth(max(configuredCollapsedWidth, min(cameraGapFrame.width, 220)), screenFrame: screenFrame)
        let collapsedHeight = min(max(CGFloat(config.collapsedHeight), 28), 60)
        let compactWidth = clampedWidth(min(max(CGFloat(config.compactWidth), collapsedWidth + 72), 420), screenFrame: screenFrame)
        let compactHeight = min(max(CGFloat(config.compactHeight), 40), 70)
        let expandedWidth = clampedWidth(CGFloat(config.expandedWidth), screenFrame: screenFrame)

        if !hasLikelyNotch || !config.overlayMenuBarForAttachedNotch {
            let topY = min(
                max(screenFrame.minY + margin, screenFrame.maxY - fallbackTopPadding + CGFloat(config.islandVerticalOffset.clamped(to: -40...40))),
                screenFrame.maxY - fallbackTopPadding
            )
            let collapsedFrame = frame(centerX: anchorCenterX, topY: topY, width: collapsedWidth, height: collapsedHeight, screenFrame: screenFrame)
            let compactFrame = frame(centerX: anchorCenterX, topY: topY, width: compactWidth, height: compactHeight, screenFrame: screenFrame)
            let expandedHeight = min(CGFloat(config.expandedHeight), max(180, topY - screenFrame.minY - margin))
            let expandedFrame = frame(centerX: anchorCenterX, topY: topY, width: expandedWidth, height: expandedHeight, screenFrame: screenFrame)

            return NotchAttachmentGeometry(
                screenID: metrics.screenID,
                hasLikelyNotch: hasLikelyNotch,
                cameraGapFrame: CGRectCodable(cameraGapFrame),
                attachedShellFrame: CGRectCodable(collapsedFrame),
                collapsedContentFrame: CGRectCodable(collapsedFrame),
                compactContentFrame: CGRectCodable(compactFrame),
                expandedContentFrame: CGRectCodable(expandedFrame),
                menuBarBandFrame: CGRectCodable(CGRect(x: screenFrame.minX, y: topY, width: screenFrame.width, height: 0)),
                safeInteractiveTopY: Double(topY),
                fallbackReason: config.overlayMenuBarForAttachedNotch ? fallbackReason(metrics: metrics, hasLikelyNotch: hasLikelyNotch) : "Attached menu-bar overlay is disabled; using conservative below-menu placement."
            )
        }

        let verticalOffset = CGFloat(config.islandVerticalOffset.clamped(to: -120...120))
        let topAnchorY = screenFrame.maxY + verticalOffset
        let shellHeight = CGFloat(config.attachedShellHeight).clamped(to: 20...110)
        let shellWidth = clampedWidth(max(collapsedWidth, min(cameraGapFrame.width + 22, 280)), screenFrame: screenFrame)
        let shellFrame = topFlushedFrame(
            centerX: anchorCenterX,
            topY: topAnchorY,
            width: shellWidth,
            height: shellHeight,
            screenFrame: screenFrame
        )

        let menuBandHeight = max(cameraGapFrame.height, 1)
        let menuBarBandFrame = CGRect(
            x: screenFrame.minX,
            y: topAnchorY - menuBandHeight,
            width: screenFrame.width,
            height: menuBandHeight
        )
        let safeInteractiveTopY = cameraGapFrame.minY + verticalOffset

        let collapsedContentFrame = topFlushedFrame(
            centerX: anchorCenterX,
            topY: safeInteractiveTopY,
            width: collapsedWidth,
            height: collapsedHeight,
            screenFrame: screenFrame
        )
        let compactContentFrame = topFlushedFrame(
            centerX: anchorCenterX,
            topY: safeInteractiveTopY,
            width: compactWidth,
            height: compactHeight,
            screenFrame: screenFrame
        )
        let expandedHeight = min(CGFloat(config.expandedHeight), max(180, safeInteractiveTopY - screenFrame.minY - margin))
        let expandedContentFrame = topFlushedFrame(
            centerX: anchorCenterX,
            topY: safeInteractiveTopY,
            width: expandedWidth,
            height: expandedHeight,
            screenFrame: screenFrame
        )

        return NotchAttachmentGeometry(
            screenID: metrics.screenID,
            hasLikelyNotch: hasLikelyNotch,
            cameraGapFrame: CGRectCodable(cameraGapFrame),
            attachedShellFrame: CGRectCodable(shellFrame),
            collapsedContentFrame: CGRectCodable(collapsedContentFrame),
            compactContentFrame: CGRectCodable(compactContentFrame),
            expandedContentFrame: CGRectCodable(expandedContentFrame),
            menuBarBandFrame: CGRectCodable(menuBarBandFrame),
            safeInteractiveTopY: Double(safeInteractiveTopY),
            fallbackReason: fallbackReason(metrics: metrics, hasLikelyNotch: hasLikelyNotch)
        )
    }

    func panelFrame(for state: NotchIslandPresentationState, metrics: NotchScreenMetrics, config: NotchShelfConfig = .default) -> CGRect {
        panelLayout(for: state, metrics: metrics, config: config).panelFrame.rect
    }

    func panelFrame(for state: NotchIslandPresentationState, screen: NSScreen, config: NotchShelfConfig) -> CGRect {
        panelLayout(for: state, screen: screen, config: config).panelFrame.rect
    }

    func panelFrame(for state: NotchIslandPresentationState, geometry: NotchAttachmentGeometry, config: NotchShelfConfig = .default) -> CGRect {
        panelLayout(for: state, geometry: geometry, config: config).panelFrame.rect
    }

    func panelLayout(for state: NotchIslandPresentationState, screen: NSScreen, config: NotchShelfConfig) -> NotchPanelLayout {
        let geometry = attachmentGeometry(for: screen, config: config)
        return panelLayout(for: state, geometry: geometry, config: config)
    }

    func panelLayout(for state: NotchIslandPresentationState, metrics: NotchScreenMetrics, config: NotchShelfConfig = .default) -> NotchPanelLayout {
        let geometry = attachmentGeometry(metrics: metrics, config: config)
        return panelLayout(for: state, geometry: geometry, config: config)
    }

    func panelLayout(for state: NotchIslandPresentationState, geometry: NotchAttachmentGeometry, config: NotchShelfConfig = .default) -> NotchPanelLayout {
        let contentFrame: CGRect
        switch state {
        case .hidden, .collapsed:
            contentFrame = config.forceAttachedNotchTestMode ? geometry.attachedShellFrame.rect : geometry.collapsedContentFrame.rect
        case .compact:
            contentFrame = geometry.compactContentFrame.rect
        case .expanded:
            contentFrame = geometry.expandedContentFrame.rect
        }

        let panelFrame: CGRect
        if geometry.hasLikelyNotch, config.overlayMenuBarForAttachedNotch {
            panelFrame = geometry.attachedShellFrame.rect.union(contentFrame).integral
        } else {
            panelFrame = contentFrame
        }

        return NotchPanelLayout(
            screenID: geometry.screenID,
            presentationState: state,
            panelFrame: CGRectCodable(panelFrame),
            shellFrameInPanelCoordinates: CGRectCodable(panelLocalRect(geometry.attachedShellFrame.rect, in: panelFrame)),
            contentFrameInPanelCoordinates: CGRectCodable(panelLocalRect(contentFrame, in: panelFrame)),
            expandedFrameInPanelCoordinates: CGRectCodable(panelLocalRect(geometry.expandedContentFrame.rect, in: panelFrame)),
            attachmentGeometry: geometry
        )
    }

    private func cameraGap(metrics: NotchScreenMetrics) -> CGRect {
        let screenFrame = metrics.screenFrame.rect
        let topInset = CGFloat(metrics.safeAreaInsets.top)

        if let gap = inferredAuxiliaryGap(metrics: metrics) {
            return gap
        }

        let gapWidth = defaultCameraGapWidth
        let gapHeight = max(topInset, defaultCameraGapHeight)
        let gapY = screenFrame.maxY - gapHeight
        let centeredGap = CGRect(
            x: screenFrame.midX - gapWidth / 2,
            y: gapY,
            width: gapWidth,
            height: gapHeight
        )

        return clamp(centeredGap, to: screenFrame)
    }

    private func inferredAuxiliaryGap(metrics: NotchScreenMetrics) -> CGRect? {
        guard let left = metrics.auxiliaryTopLeftArea?.rect,
              let right = metrics.auxiliaryTopRightArea?.rect,
              right.minX > left.maxX else {
            return nil
        }

        let screenFrame = metrics.screenFrame.rect
        let gapMinX = left.maxX
        let gapMaxX = right.minX
        let gapWidth = max(gapMaxX - gapMinX, defaultCameraGapWidth)
        let gapMidX = (gapMinX + gapMaxX) / 2
        let topBandMinY = min(left.minY, right.minY)
        let topBandHeight = max(max(left.height, right.height), defaultCameraGapHeight)
        let gap = CGRect(
            x: gapMidX - gapWidth / 2,
            y: topBandMinY,
            width: gapWidth,
            height: topBandHeight
        )

        return clamp(gap, to: screenFrame)
    }

    private func clampedWidth(_ width: CGFloat, screenFrame: CGRect) -> CGFloat {
        min(width, max(120, screenFrame.width - margin * 2))
    }

    private func topFlushedFrame(centerX: CGFloat, topY: CGFloat, width: CGFloat, height: CGFloat, screenFrame: CGRect) -> CGRect {
        let x = min(max(centerX - width / 2, screenFrame.minX + margin), screenFrame.maxX - margin - width)
        let y = topY - height
        return CGRect(x: x, y: y, width: width, height: height).integral
    }

    private func frame(centerX: CGFloat, topY: CGFloat, width: CGFloat, height: CGFloat, screenFrame: CGRect) -> CGRect {
        let x = min(max(centerX - width / 2, screenFrame.minX + margin), screenFrame.maxX - margin - width)
        let y = min(max(topY - height, screenFrame.minY + margin), screenFrame.maxY - margin - height)
        return CGRect(x: x, y: y, width: width, height: height).integral
    }

    private func frameAllowingTopFlush(centerX: CGFloat, topY: CGFloat, width: CGFloat, height: CGFloat, screenFrame: CGRect) -> CGRect {
        let x = min(max(centerX - width / 2, screenFrame.minX + margin), screenFrame.maxX - margin - width)
        let y = min(max(topY - height, screenFrame.minY + margin), screenFrame.maxY - height)
        return CGRect(x: x, y: y, width: width, height: height).integral
    }

    private func panelLocalRect(_ rect: CGRect, in panelFrame: CGRect) -> CGRect {
        CGRect(
            x: rect.minX - panelFrame.minX,
            y: rect.minY - panelFrame.minY,
            width: rect.width,
            height: rect.height
        ).integral
    }

    private func clamp(_ rect: CGRect, to screenFrame: CGRect) -> CGRect {
        let width = min(rect.width, screenFrame.width - margin * 2)
        let height = min(rect.height, screenFrame.height - margin * 2)
        let x = min(max(rect.midX - width / 2, screenFrame.minX + margin), screenFrame.maxX - margin - width)
        let y = min(max(rect.midY - height / 2, screenFrame.minY + margin), screenFrame.maxY - margin - height)
        return CGRect(x: x, y: y, width: width, height: height).integral
    }

    private func fallbackReason(metrics: NotchScreenMetrics, hasLikelyNotch: Bool) -> String? {
        if metrics.auxiliaryTopLeftArea == nil || metrics.auxiliaryTopRightArea == nil {
            if hasLikelyNotch {
                return "Auxiliary notch areas were unavailable; using centered safe-area estimate."
            }
            return "No notch geometry was detected; using top-center fallback."
        }

        return nil
    }
}

private extension Comparable {
    func clamped(to range: ClosedRange<Self>) -> Self {
        min(max(self, range.lowerBound), range.upperBound)
    }
}
