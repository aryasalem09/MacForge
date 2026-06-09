import XCTest
@testable import MacForge

@MainActor
final class NotchIslandStateTests: XCTestCase {
    func testActivityMovesIslandToCompactState() {
        let now = Date()
        let center = NotchIslandActivityCenter(nowProvider: { now })

        center.showActivity(
            kind: .windowAction,
            title: "Window Action",
            message: "Centered",
            symbolName: "rectangle.center.inset.filled",
            duration: 4
        )

        XCTAssertEqual(center.presentationState, .compact)
        XCTAssertEqual(center.currentActivity?.kind, .windowAction)
        XCTAssertEqual(center.recentActivities.count, 1)
    }

    func testActivityAutoExpirationCollapsesCompactIsland() {
        var now = Date()
        let center = NotchIslandActivityCenter(nowProvider: { now })
        center.showActivity(
            kind: .preset,
            title: "Running Preset",
            message: "Focus",
            symbolName: "scope",
            duration: 2
        )

        now = now.addingTimeInterval(3)
        center.autoCollapseIfNeeded()

        XCTAssertNil(center.currentActivity)
        XCTAssertEqual(center.presentationState, .collapsed)
    }

    func testCommandResultMapsFailureToErrorActivity() {
        let center = NotchIslandActivityCenter()
        let result = CommandResult.failure("Window Action", "Accessibility permission is required.")

        center.showCommandResult(result, autoCollapseDelay: 3)

        XCTAssertEqual(center.currentActivity?.kind, .error)
        XCTAssertTrue(center.currentActivity?.isError == true)
        XCTAssertEqual(center.presentationState, .compact)
    }

    func testManualExpandCollapseAndHideTransitions() {
        let center = NotchIslandActivityCenter()

        center.expand()
        XCTAssertEqual(center.presentationState, .expanded)

        center.collapse()
        XCTAssertEqual(center.presentationState, .collapsed)

        center.hide()
        XCTAssertEqual(center.presentationState, .hidden)
    }

    func testDefaultIslandConfigIsSmallAndIslandFirst() {
        let config = NotchShelfConfig.default

        XCTAssertEqual(config.preferredStyle, .island)
        XCTAssertLessThanOrEqual(config.collapsedHeight, 38)
        XCTAssertLessThanOrEqual(config.collapsedWidth, 240)
        XCTAssertGreaterThan(config.expandedWidth, config.collapsedWidth)
    }
}
