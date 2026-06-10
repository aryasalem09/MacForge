import CoreGraphics
import XCTest
@testable import MacForge

final class NotchGeometryServiceTests: XCTestCase {
    func testCameraGapInferredFromAuxiliaryTopAreas() {
        let metrics = notchedMetricsWithAuxiliaryAreas()

        let geometry = NotchGeometryService().anchorGeometry(metrics: metrics)

        XCTAssertTrue(geometry.hasLikelyNotch)
        XCTAssertEqual(geometry.cameraGapFrame.rect.minX, 650, accuracy: 0.5)
        XCTAssertEqual(geometry.cameraGapFrame.rect.width, 212, accuracy: 0.5)
        XCTAssertEqual(geometry.collapsedFrame.rect.midX, geometry.cameraGapFrame.rect.midX, accuracy: 0.5)
        XCTAssertNil(geometry.fallbackReason)
    }

    func testSafeAreaOnlyNotchUsesCenteredFallbackGap() {
        let metrics = NotchScreenMetrics(
            screenID: "Built-in",
            screenFrame: CGRectCodable(CGRect(x: 0, y: 0, width: 1512, height: 982)),
            visibleFrame: CGRectCodable(CGRect(x: 0, y: 0, width: 1512, height: 944)),
            safeAreaInsets: EdgeInsetsCodable(top: 74, left: 0, bottom: 0, right: 0),
            auxiliaryTopLeftArea: nil,
            auxiliaryTopRightArea: nil,
            hasLikelyNotch: true
        )

        let geometry = NotchGeometryService().anchorGeometry(metrics: metrics)

        XCTAssertTrue(geometry.hasLikelyNotch)
        XCTAssertEqual(geometry.cameraGapFrame.rect.midX, 756, accuracy: 0.5)
        XCTAssertEqual(geometry.cameraGapFrame.rect.width, 210, accuracy: 0.5)
        XCTAssertEqual(geometry.fallbackReason, "Auxiliary notch areas were unavailable; using centered safe-area estimate.")
    }

    func testNonNotchedDisplayUsesTopCenterFallback() {
        let metrics = NotchScreenMetrics(
            screenID: "External",
            screenFrame: CGRectCodable(CGRect(x: 0, y: 0, width: 1440, height: 900)),
            visibleFrame: CGRectCodable(CGRect(x: 0, y: 0, width: 1440, height: 875)),
            safeAreaInsets: EdgeInsetsCodable(top: 0, left: 0, bottom: 0, right: 0),
            auxiliaryTopLeftArea: nil,
            auxiliaryTopRightArea: nil,
            hasLikelyNotch: false
        )

        let geometry = NotchGeometryService().anchorGeometry(metrics: metrics)

        XCTAssertFalse(geometry.hasLikelyNotch)
        XCTAssertEqual(geometry.collapsedFrame.rect.midX, 720, accuracy: 0.5)
        XCTAssertEqual(geometry.fallbackReason, "No notch geometry was detected; using top-center fallback.")
    }

    func testExpandedFrameClampsOnSmallDisplays() {
        var config = NotchShelfConfig.default
        config.expandedWidth = 680
        let metrics = NotchScreenMetrics(
            screenID: "Small",
            screenFrame: CGRectCodable(CGRect(x: 0, y: 0, width: 360, height: 600)),
            visibleFrame: CGRectCodable(CGRect(x: 0, y: 0, width: 360, height: 570)),
            safeAreaInsets: EdgeInsetsCodable(top: 0, left: 0, bottom: 0, right: 0),
            auxiliaryTopLeftArea: nil,
            auxiliaryTopRightArea: nil,
            hasLikelyNotch: false
        )

        let geometry = NotchGeometryService().anchorGeometry(metrics: metrics, config: config)

        XCTAssertLessThanOrEqual(geometry.expandedFrame.rect.width, 328)
        XCTAssertGreaterThanOrEqual(geometry.expandedFrame.rect.minX, 16)
        XCTAssertLessThanOrEqual(geometry.expandedFrame.rect.maxX, 344)
    }

    func testExpandedFrameStaysBelowSafeTopArea() {
        let metrics = notchedMetricsWithAuxiliaryAreas()

        let geometry = NotchGeometryService().anchorGeometry(metrics: metrics)

        XCTAssertLessThanOrEqual(geometry.expandedFrame.rect.maxY, geometry.cameraGapFrame.rect.minY + 0.5)
    }

    func testAttachedShellTopFlushesToScreenTop() {
        let metrics = notchedMetricsWithAuxiliaryAreas()

        let geometry = NotchGeometryService().attachmentGeometry(metrics: metrics)

        XCTAssertEqual(geometry.attachedShellFrame.rect.maxY, metrics.screenFrame.rect.maxY, accuracy: 0.5)
        XCTAssertEqual(geometry.attachedShellFrame.rect.midX, geometry.cameraGapFrame.rect.midX, accuracy: 0.5)
    }

    func testPanelFrameIncludesAttachedShellWithoutMenuBarGap() {
        let metrics = notchedMetricsWithAuxiliaryAreas()
        let service = NotchGeometryService()

        let collapsedFrame = service.panelFrame(for: .collapsed, metrics: metrics)
        let compactFrame = service.panelFrame(for: .compact, metrics: metrics)

        XCTAssertEqual(collapsedFrame.maxY, metrics.screenFrame.rect.maxY, accuracy: 0.5)
        XCTAssertEqual(compactFrame.maxY, metrics.screenFrame.rect.maxY, accuracy: 0.5)
        XCTAssertLessThan(collapsedFrame.minY, metrics.screenFrame.rect.maxY)
        XCTAssertLessThan(compactFrame.minY, metrics.screenFrame.rect.maxY)
    }

    func testDefaultIslandWidthsStayBelowToolbarThreshold() {
        let geometry = NotchGeometryService().anchorGeometry(metrics: notchedMetricsWithAuxiliaryAreas())

        XCTAssertLessThanOrEqual(geometry.collapsedFrame.rect.width, 280)
        XCTAssertLessThanOrEqual(geometry.compactFrame.rect.width, 420)
        XCTAssertGreaterThanOrEqual(geometry.expandedFrame.rect.width, 520)
    }

    func testAttachedOffsetsAndShellHeightAreApplied() {
        var config = NotchShelfConfig.default
        config.islandVerticalOffset = 12
        config.islandHorizontalOffset = 32
        config.attachedShellHeight = 60

        let geometry = NotchGeometryService().attachmentGeometry(metrics: notchedMetricsWithAuxiliaryAreas(), config: config)

        XCTAssertEqual(geometry.attachedShellFrame.rect.maxY, 994, accuracy: 0.5)
        XCTAssertEqual(geometry.attachedShellFrame.rect.height, 60, accuracy: 0.5)
        XCTAssertEqual(geometry.attachedShellFrame.rect.midX, geometry.cameraGapFrame.rect.midX + 32, accuracy: 0.5)
    }

    func testPanelTopAnchorStaysFixedAcrossStates() {
        let service = NotchGeometryService()
        let metrics = notchedMetricsWithAuxiliaryAreas()

        let collapsed = service.panelLayout(for: .collapsed, metrics: metrics)
        let compact = service.panelLayout(for: .compact, metrics: metrics)
        let expanded = service.panelLayout(for: .expanded, metrics: metrics)

        XCTAssertEqual(collapsed.panelFrame.rect.maxY, metrics.screenFrame.rect.maxY, accuracy: 0.5)
        XCTAssertEqual(compact.panelFrame.rect.maxY, collapsed.panelFrame.rect.maxY, accuracy: 0.5)
        XCTAssertEqual(expanded.panelFrame.rect.maxY, collapsed.panelFrame.rect.maxY, accuracy: 0.5)
        XCTAssertGreaterThan(expanded.panelFrame.rect.height, compact.panelFrame.rect.height)
    }

    func testManualCalibrationOffsetAffectsActualPanelFrame() {
        var config = NotchShelfConfig.default
        config.islandHorizontalOffset = 48
        config.islandVerticalOffset = -20
        let metrics = notchedMetricsWithAuxiliaryAreas()

        let layout = NotchGeometryService().panelLayout(for: .collapsed, metrics: metrics, config: config)

        XCTAssertEqual(layout.panelFrame.rect.maxY, metrics.screenFrame.rect.maxY - 20, accuracy: 0.5)
        XCTAssertEqual(layout.panelFrame.rect.midX, metrics.screenFrame.rect.midX + 48, accuracy: 0.5)
    }

    func testForceTestModeUsesAttachedOnlyCollapsedLayout() {
        var config = NotchShelfConfig.default
        config.forceAttachedNotchTestMode = true
        let layout = NotchGeometryService().panelLayout(for: .collapsed, metrics: notchedMetricsWithAuxiliaryAreas(), config: config)

        XCTAssertEqual(layout.panelFrame.rect, layout.attachmentGeometry.attachedShellFrame.rect)
    }

    func testExpandedPanelGrowsDownwardWithTopAnchored() {
        let service = NotchGeometryService()
        let metrics = notchedMetricsWithAuxiliaryAreas()

        let compactFrame = service.panelFrame(for: .compact, metrics: metrics)
        let expandedFrame = service.panelFrame(for: .expanded, metrics: metrics)

        XCTAssertEqual(expandedFrame.maxY, metrics.screenFrame.rect.maxY, accuracy: 0.5)
        XCTAssertGreaterThan(expandedFrame.height, compactFrame.height)
        XCTAssertLessThan(expandedFrame.minY, compactFrame.minY)
    }

    func testOldToolbarConfigRepairsToAttachedDefaults() {
        var config = NotchShelfConfig.default
        config.configVersion = 2
        config.collapsedWidth = 620
        config.compactWidth = 620
        config.collapsedHeight = 76
        config.compactHeight = 76
        config.islandVerticalOffset = 140
        config.forceAttachedNotchTestMode = true

        XCTAssertTrue(config.repairAttachedNotchLayoutIfNeeded())
        XCTAssertEqual(config.configVersion, NotchShelfConfig.currentConfigVersion)
        XCTAssertEqual(config.preferredStyle, .island)
        XCTAssertLessThanOrEqual(config.collapsedWidth, 280)
        XCTAssertLessThanOrEqual(config.compactWidth, 420)
        XCTAssertEqual(config.islandVerticalOffset, 0)
        XCTAssertTrue(config.overlayMenuBarForAttachedNotch)
        XCTAssertFalse(config.forceAttachedNotchTestMode)
    }

    func testExternalDisplayUsesNonAttachedFallback() {
        let metrics = NotchScreenMetrics(
            screenID: "External",
            screenFrame: CGRectCodable(CGRect(x: 0, y: 0, width: 1440, height: 900)),
            visibleFrame: CGRectCodable(CGRect(x: 0, y: 0, width: 1440, height: 875)),
            safeAreaInsets: EdgeInsetsCodable(top: 0, left: 0, bottom: 0, right: 0),
            auxiliaryTopLeftArea: nil,
            auxiliaryTopRightArea: nil,
            hasLikelyNotch: false
        )

        let service = NotchGeometryService()
        let geometry = service.attachmentGeometry(metrics: metrics)
        let collapsedPanelFrame = service.panelFrame(for: .collapsed, metrics: metrics)

        XCTAssertFalse(geometry.hasLikelyNotch)
        XCTAssertEqual(collapsedPanelFrame, geometry.collapsedContentFrame.rect)
        XCTAssertLessThan(collapsedPanelFrame.maxY, metrics.screenFrame.rect.maxY)
    }

    private func notchedMetricsWithAuxiliaryAreas() -> NotchScreenMetrics {
        NotchScreenMetrics(
            screenID: "Built-in",
            screenFrame: CGRectCodable(CGRect(x: 0, y: 0, width: 1512, height: 982)),
            visibleFrame: CGRectCodable(CGRect(x: 0, y: 0, width: 1512, height: 944)),
            safeAreaInsets: EdgeInsetsCodable(top: 74, left: 0, bottom: 0, right: 0),
            auxiliaryTopLeftArea: CGRectCodable(CGRect(x: 0, y: 944, width: 650, height: 38)),
            auxiliaryTopRightArea: CGRectCodable(CGRect(x: 862, y: 944, width: 650, height: 38)),
            hasLikelyNotch: true
        )
    }
}
