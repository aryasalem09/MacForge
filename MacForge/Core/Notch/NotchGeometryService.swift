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

struct NotchGeometryService {
    private let margin: CGFloat = 16
    private let defaultCameraGapWidth: CGFloat = 210
    private let defaultCameraGapHeight: CGFloat = 34

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
        let screenFrame = metrics.screenFrame.rect
        let topInset = CGFloat(metrics.safeAreaInsets.top)
        let hasAuxiliaryGap = inferredAuxiliaryGap(metrics: metrics) != nil
        let hasLikelyNotch = metrics.hasLikelyNotch || hasAuxiliaryGap || topInset > 0
        let cameraGapFrame = cameraGap(metrics: metrics)
        let anchorCenterX = cameraGapFrame.midX
        let safeTopY = max(
            screenFrame.minY + margin,
            screenFrame.maxY - (hasLikelyNotch ? max(topInset, defaultCameraGapHeight) : 0) - 6
        )

        let collapsedWidth = clampedWidth(
            max(CGFloat(config.collapsedWidth), min(max(cameraGapFrame.width + 24, 180), 240)),
            screenFrame: screenFrame
        )
        let collapsedHeight = CGFloat(config.collapsedHeight)
        let compactWidth = clampedWidth(max(CGFloat(config.compactWidth), collapsedWidth + 72), screenFrame: screenFrame)
        let compactHeight = CGFloat(config.compactHeight)
        let expandedWidth = clampedWidth(CGFloat(config.expandedWidth), screenFrame: screenFrame)
        let expandedHeight = min(CGFloat(config.expandedHeight), max(180, safeTopY - screenFrame.minY - margin))

        let collapsedFrame = frame(
            centerX: anchorCenterX,
            topY: safeTopY,
            width: collapsedWidth,
            height: collapsedHeight,
            screenFrame: screenFrame
        )
        let compactFrame = frame(
            centerX: anchorCenterX,
            topY: safeTopY,
            width: compactWidth,
            height: compactHeight,
            screenFrame: screenFrame
        )
        let expandedFrame = frame(
            centerX: anchorCenterX,
            topY: safeTopY,
            width: expandedWidth,
            height: expandedHeight,
            screenFrame: screenFrame
        )

        return NotchAnchorGeometry(
            screenID: metrics.screenID,
            hasLikelyNotch: hasLikelyNotch,
            cameraGapFrame: CGRectCodable(cameraGapFrame),
            collapsedFrame: CGRectCodable(collapsedFrame),
            compactFrame: CGRectCodable(compactFrame),
            expandedFrame: CGRectCodable(expandedFrame),
            fallbackReason: fallbackReason(metrics: metrics, hasLikelyNotch: hasLikelyNotch)
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

    private func frame(centerX: CGFloat, topY: CGFloat, width: CGFloat, height: CGFloat, screenFrame: CGRect) -> CGRect {
        let x = min(max(centerX - width / 2, screenFrame.minX + margin), screenFrame.maxX - margin - width)
        let y = min(max(topY - height, screenFrame.minY + margin), screenFrame.maxY - margin - height)
        return CGRect(x: x, y: y, width: width, height: height).integral
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
