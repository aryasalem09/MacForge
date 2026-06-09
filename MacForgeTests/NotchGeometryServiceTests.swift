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

    func testDefaultIslandWidthsStayBelowToolbarThreshold() {
        let geometry = NotchGeometryService().anchorGeometry(metrics: notchedMetricsWithAuxiliaryAreas())

        XCTAssertLessThanOrEqual(geometry.collapsedFrame.rect.width, 220)
        XCTAssertLessThanOrEqual(geometry.compactFrame.rect.width, 340)
        XCTAssertGreaterThanOrEqual(geometry.expandedFrame.rect.width, 520)
    }

    func testVerticalOffsetIsAppliedAndClampedBelowCameraGap() {
        var config = NotchShelfConfig.default
        config.islandVerticalOffset = -18

        let lowered = NotchGeometryService().anchorGeometry(metrics: notchedMetricsWithAuxiliaryAreas(), config: config)

        XCTAssertEqual(lowered.collapsedFrame.rect.maxY, lowered.cameraGapFrame.rect.minY - 18, accuracy: 0.5)

        config.islandVerticalOffset = 24
        let clamped = NotchGeometryService().anchorGeometry(metrics: notchedMetricsWithAuxiliaryAreas(), config: config)

        XCTAssertEqual(clamped.collapsedFrame.rect.maxY, clamped.cameraGapFrame.rect.minY, accuracy: 0.5)
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
