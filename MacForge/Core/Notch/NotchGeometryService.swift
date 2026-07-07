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

struct CGSizeCodable: Hashable, Codable {
    var width: Double
    var height: Double

    init(_ size: CGSize) {
        width = Double(size.width)
        height = Double(size.height)
    }

    init(width: Double, height: Double) {
        self.width = width
        self.height = height
    }

    var size: CGSize {
        CGSize(width: CGFloat(width), height: CGFloat(height))
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

/// Everything the island window and its SwiftUI content need to attach to the
/// physical camera housing. The panel is anchored flush to the top of the
/// screen and centered on the notch; the SwiftUI shape morphs inside it.
struct NotchIslandLayout: Hashable, Codable {
    /// Corner flare drawn on each side of the shape's top edge so a widened
    /// island blends into the screen edge the way the physical notch does.
    static let topCornerFlare: Double = 6
    static let compactEarWidth: Double = 74

    var screenID: String
    var hasPhysicalNotch: Bool
    /// Camera-housing cutout in global (bottom-left origin) screen coordinates.
    /// On displays without a notch this is a virtual notch used as the anchor.
    var notchFrame: CGRectCodable
    var collapsedSize: CGSizeCodable
    var compactSize: CGSizeCodable
    var expandedSize: CGSizeCodable
    var fallbackReason: String?

    func shapeSize(for state: NotchIslandPresentationState) -> CGSize {
        switch state {
        case .hidden, .collapsed: collapsedSize.size
        case .compact: compactSize.size
        case .expanded: expandedSize.size
        }
    }

    /// Window frame for a presentation state, in global screen coordinates.
    /// Collapsed hugs the notch exactly; larger states reserve margins so the
    /// SwiftUI shadow renders inside the window instead of being clipped.
    func panelFrame(for state: NotchIslandPresentationState) -> CGRect {
        let size = shapeSize(for: state)
        let sideMargin: CGFloat
        let bottomMargin: CGFloat
        switch state {
        case .hidden, .collapsed:
            sideMargin = 0
            bottomMargin = 0
        case .compact:
            sideMargin = 20
            bottomMargin = 24
        case .expanded:
            sideMargin = 28
            bottomMargin = 40
        }

        let notch = notchFrame.rect
        let width = size.width + sideMargin * 2
        let height = size.height + bottomMargin
        return CGRect(
            x: notch.midX - width / 2,
            y: notch.maxY - height,
            width: width,
            height: height
        )
    }
}

struct NotchGeometryService {
    private let virtualNotchSize = CGSize(width: 200, height: 34)
    private let minimumExpandedContentWidth: CGFloat = 320
    private let screenEdgeMargin: CGFloat = 16

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

    /// The exact camera-housing cutout, measured from the gap between the two
    /// auxiliary menu-bar areas. Returns nil when the screen has no notch.
    func physicalNotchRect(metrics: NotchScreenMetrics) -> CGRect? {
        let screenFrame = metrics.screenFrame.rect

        if let left = metrics.auxiliaryTopLeftArea?.rect,
           let right = metrics.auxiliaryTopRightArea?.rect,
           right.minX > left.maxX {
            let top = screenFrame.maxY
            let bottom = min(left.minY, right.minY)
            return CGRect(
                x: left.maxX,
                y: bottom,
                width: right.minX - left.maxX,
                height: top - bottom
            )
        }

        let topInset = CGFloat(metrics.safeAreaInsets.top)
        guard topInset > 0 else { return nil }
        return CGRect(
            x: screenFrame.midX - virtualNotchSize.width / 2,
            y: screenFrame.maxY - topInset,
            width: virtualNotchSize.width,
            height: topInset
        )
    }

    func islandLayout(metrics: NotchScreenMetrics, config: NotchShelfConfig = .default) -> NotchIslandLayout {
        let screenFrame = metrics.screenFrame.rect
        let flare = CGFloat(NotchIslandLayout.topCornerFlare)
        let physicalNotch = physicalNotchRect(metrics: metrics)

        var fallbackReason: String?
        let notch: CGRect
        if let physicalNotch {
            notch = physicalNotch
            if metrics.auxiliaryTopLeftArea == nil || metrics.auxiliaryTopRightArea == nil {
                fallbackReason = "Auxiliary notch areas were unavailable; using centered safe-area estimate."
            }
        } else {
            let offset = CGFloat(config.islandHorizontalOffset.clamped(to: -160...160))
            // max(0, …) guards against an inverted ClosedRange on a screen
            // narrower than the virtual notch plus margins.
            let maxOffset = max(0, (screenFrame.width - virtualNotchSize.width) / 2 - screenEdgeMargin)
            let centerX = screenFrame.midX + offset.clamped(to: -maxOffset...maxOffset)
            notch = CGRect(
                x: centerX - virtualNotchSize.width / 2,
                y: screenFrame.maxY - virtualNotchSize.height,
                width: virtualNotchSize.width,
                height: virtualNotchSize.height
            )
            fallbackReason = "No notch was detected; using a virtual notch at the top center."
        }

        let collapsedSize = CGSize(
            width: notch.width + flare * 2,
            height: notch.height
        )
        let maxShapeWidth = screenFrame.width - screenEdgeMargin * 2
        let compactSize = CGSize(
            width: min(collapsedSize.width + CGFloat(NotchIslandLayout.compactEarWidth) * 2, maxShapeWidth),
            height: notch.height + 8
        )
        let expandedWidth = CGFloat(config.expandedWidth)
            .clamped(to: min(collapsedSize.width + minimumExpandedContentWidth, maxShapeWidth)...maxShapeWidth)
        let maxExpandedHeight = max(screenFrame.height * 0.6, notch.height + 160)
        let expandedHeight = CGFloat(config.expandedHeight)
            .clamped(to: (notch.height + 160)...maxExpandedHeight)
        let expandedSize = CGSize(width: expandedWidth, height: expandedHeight)

        return NotchIslandLayout(
            screenID: metrics.screenID,
            hasPhysicalNotch: physicalNotch != nil,
            notchFrame: CGRectCodable(notch),
            collapsedSize: CGSizeCodable(collapsedSize),
            compactSize: CGSizeCodable(compactSize),
            expandedSize: CGSizeCodable(expandedSize),
            fallbackReason: fallbackReason
        )
    }

    func islandLayout(for screen: NSScreen, config: NotchShelfConfig) -> NotchIslandLayout {
        islandLayout(metrics: metrics(for: screen), config: config)
    }
}

extension Comparable {
    func clamped(to range: ClosedRange<Self>) -> Self {
        min(max(self, range.lowerBound), range.upperBound)
    }
}
