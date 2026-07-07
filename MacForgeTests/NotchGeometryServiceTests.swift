import CoreGraphics
import XCTest
@testable import MacForge

final class NotchGeometryServiceTests: XCTestCase {
    private let service = NotchGeometryService()

    // MARK: - Physical notch measurement

    func testPhysicalNotchMeasuredExactlyFromAuxiliaryAreas() {
        let notch = service.physicalNotchRect(metrics: notchedMetricsWithAuxiliaryAreas())

        XCTAssertNotNil(notch)
        XCTAssertEqual(notch?.minX ?? 0, 650, accuracy: 0.5)
        XCTAssertEqual(notch?.width ?? 0, 212, accuracy: 0.5)
        XCTAssertEqual(notch?.height ?? 0, 38, accuracy: 0.5)
        XCTAssertEqual(notch?.maxY ?? 0, 982, accuracy: 0.5)
    }

    func testSafeAreaOnlyNotchFallsBackToCenteredEstimate() {
        let metrics = safeAreaOnlyMetrics()

        let notch = service.physicalNotchRect(metrics: metrics)
        let layout = service.islandLayout(metrics: metrics)

        XCTAssertNotNil(notch)
        XCTAssertEqual(notch?.midX ?? 0, 756, accuracy: 0.5)
        XCTAssertEqual(notch?.height ?? 0, 34, accuracy: 0.5)
        XCTAssertEqual(notch?.maxY ?? 0, 982, accuracy: 0.5)
        XCTAssertTrue(layout.hasPhysicalNotch)
        XCTAssertEqual(layout.fallbackReason, "Auxiliary notch areas were unavailable; using centered safe-area estimate.")
    }

    func testDisplayWithoutNotchUsesVirtualNotchAtTopCenter() {
        let layout = service.islandLayout(metrics: externalDisplayMetrics())
        let notch = layout.notchFrame.rect

        XCTAssertFalse(layout.hasPhysicalNotch)
        XCTAssertEqual(notch.midX, 720, accuracy: 0.5)
        XCTAssertEqual(notch.maxY, 900, accuracy: 0.5)
        XCTAssertNotNil(layout.fallbackReason)
    }

    func testVirtualNotchHonorsHorizontalOffsetButPhysicalNotchDoesNot() {
        var config = NotchShelfConfig.default
        config.islandHorizontalOffset = 60

        let virtualLayout = service.islandLayout(metrics: externalDisplayMetrics(), config: config)
        let physicalLayout = service.islandLayout(metrics: notchedMetricsWithAuxiliaryAreas(), config: config)

        XCTAssertEqual(virtualLayout.notchFrame.rect.midX, 780, accuracy: 0.5)
        XCTAssertEqual(physicalLayout.notchFrame.rect.midX, 756, accuracy: 0.5)
    }

    // MARK: - Shape sizes

    func testCollapsedShapeMatchesNotchPlusCornerFlares() {
        let layout = service.islandLayout(metrics: notchedMetricsWithAuxiliaryAreas())
        let flare = NotchIslandLayout.topCornerFlare

        XCTAssertEqual(layout.collapsedSize.width, 212 + flare * 2, accuracy: 0.5)
        XCTAssertEqual(layout.collapsedSize.height, 38, accuracy: 0.5)
    }

    func testCompactShapeAddsAnEarOnEachSide() {
        let layout = service.islandLayout(metrics: notchedMetricsWithAuxiliaryAreas())

        XCTAssertEqual(
            layout.compactSize.width,
            layout.collapsedSize.width + NotchIslandLayout.compactEarWidth * 2,
            accuracy: 0.5
        )
        XCTAssertGreaterThan(layout.compactSize.height, layout.collapsedSize.height)
    }

    func testExpandedShapeUsesConfiguredSizeOnLargeDisplays() {
        let layout = service.islandLayout(metrics: notchedMetricsWithAuxiliaryAreas())

        XCTAssertEqual(layout.expandedSize.width, NotchShelfConfig.default.expandedWidth, accuracy: 0.5)
        XCTAssertEqual(layout.expandedSize.height, NotchShelfConfig.default.expandedHeight, accuracy: 0.5)
    }

    func testExpandedShapeClampsOnSmallDisplays() {
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

        let layout = service.islandLayout(metrics: metrics, config: config)

        XCTAssertLessThanOrEqual(layout.expandedSize.width, 360 - 32)
        XCTAssertLessThanOrEqual(layout.expandedSize.height, 600 * 0.6 + 0.5)
    }

    // MARK: - Panel frames

    func testCollapsedPanelHugsTheNotchExactly() {
        let layout = service.islandLayout(metrics: notchedMetricsWithAuxiliaryAreas())
        let panel = layout.panelFrame(for: .collapsed)
        let notch = layout.notchFrame.rect

        XCTAssertEqual(panel.midX, notch.midX, accuracy: 0.5)
        XCTAssertEqual(panel.maxY, notch.maxY, accuracy: 0.5)
        XCTAssertEqual(panel.width, layout.collapsedSize.width, accuracy: 0.5)
        XCTAssertEqual(panel.height, layout.collapsedSize.height, accuracy: 0.5)
    }

    func testAllPanelFramesStayFlushWithScreenTopAndCentered() {
        let metrics = notchedMetricsWithAuxiliaryAreas()
        let layout = service.islandLayout(metrics: metrics)
        let screenTop = metrics.screenFrame.rect.maxY
        let notchMidX = layout.notchFrame.rect.midX

        for state in NotchIslandPresentationState.allCases {
            let panel = layout.panelFrame(for: state)
            XCTAssertEqual(panel.maxY, screenTop, accuracy: 0.5, "state \(state.rawValue)")
            XCTAssertEqual(panel.midX, notchMidX, accuracy: 0.5, "state \(state.rawValue)")
        }
    }

    func testLargerStatesReserveShadowMargins() {
        let layout = service.islandLayout(metrics: notchedMetricsWithAuxiliaryAreas())

        let compact = layout.panelFrame(for: .compact)
        let expanded = layout.panelFrame(for: .expanded)

        XCTAssertEqual(compact.width, layout.compactSize.size.width + 40, accuracy: 0.5)
        XCTAssertEqual(compact.height, layout.compactSize.size.height + 24, accuracy: 0.5)
        XCTAssertEqual(expanded.width, layout.expandedSize.size.width + 56, accuracy: 0.5)
        XCTAssertEqual(expanded.height, layout.expandedSize.size.height + 40, accuracy: 0.5)
    }

    func testPanelFramesGrowMonotonicallyAcrossStates() {
        let layout = service.islandLayout(metrics: notchedMetricsWithAuxiliaryAreas())

        let collapsed = layout.panelFrame(for: .collapsed)
        let compact = layout.panelFrame(for: .compact)
        let expanded = layout.panelFrame(for: .expanded)

        XCTAssertLessThan(collapsed.width, compact.width)
        XCTAssertLessThan(compact.width, expanded.width)
        XCTAssertLessThan(collapsed.height, compact.height)
        XCTAssertLessThan(compact.height, expanded.height)
        XCTAssertTrue(expanded.contains(collapsed))
    }

    // MARK: - Config repair

    func testOldToolbarConfigRepairsToAttachedDefaults() {
        var config = NotchShelfConfig.default
        config.configVersion = 263
        config.collapsedWidth = 620
        config.compactWidth = 620
        config.islandVerticalOffset = 140
        config.forceAttachedNotchTestMode = true

        XCTAssertTrue(config.repairAttachedNotchLayoutIfNeeded())
        XCTAssertEqual(config.configVersion, NotchShelfConfig.currentConfigVersion)
        XCTAssertEqual(config.preferredStyle, .island)
        XCTAssertEqual(config.islandVerticalOffset, 0)
        XCTAssertFalse(config.forceAttachedNotchTestMode)
    }

    // MARK: - Fixtures

    private func notchedMetricsWithAuxiliaryAreas() -> NotchScreenMetrics {
        NotchScreenMetrics(
            screenID: "Built-in",
            screenFrame: CGRectCodable(CGRect(x: 0, y: 0, width: 1512, height: 982)),
            visibleFrame: CGRectCodable(CGRect(x: 0, y: 0, width: 1512, height: 944)),
            safeAreaInsets: EdgeInsetsCodable(top: 38, left: 0, bottom: 0, right: 0),
            auxiliaryTopLeftArea: CGRectCodable(CGRect(x: 0, y: 944, width: 650, height: 38)),
            auxiliaryTopRightArea: CGRectCodable(CGRect(x: 862, y: 944, width: 650, height: 38)),
            hasLikelyNotch: true
        )
    }

    private func safeAreaOnlyMetrics() -> NotchScreenMetrics {
        NotchScreenMetrics(
            screenID: "Built-in",
            screenFrame: CGRectCodable(CGRect(x: 0, y: 0, width: 1512, height: 982)),
            visibleFrame: CGRectCodable(CGRect(x: 0, y: 0, width: 1512, height: 944)),
            safeAreaInsets: EdgeInsetsCodable(top: 34, left: 0, bottom: 0, right: 0),
            auxiliaryTopLeftArea: nil,
            auxiliaryTopRightArea: nil,
            hasLikelyNotch: true
        )
    }

    private func externalDisplayMetrics() -> NotchScreenMetrics {
        NotchScreenMetrics(
            screenID: "External",
            screenFrame: CGRectCodable(CGRect(x: 0, y: 0, width: 1440, height: 900)),
            visibleFrame: CGRectCodable(CGRect(x: 0, y: 0, width: 1440, height: 875)),
            safeAreaInsets: EdgeInsetsCodable(top: 0, left: 0, bottom: 0, right: 0),
            auxiliaryTopLeftArea: nil,
            auxiliaryTopRightArea: nil,
            hasLikelyNotch: false
        )
    }
}
