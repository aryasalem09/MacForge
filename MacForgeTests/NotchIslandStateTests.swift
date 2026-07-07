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

    func testActivityDoesNotShrinkAnExpandedIsland() {
        let center = NotchIslandActivityCenter(presentationState: .expanded)

        center.showActivity(
            kind: .preset,
            title: "Running Preset",
            message: "Focus",
            symbolName: "scope",
            duration: 4
        )

        XCTAssertEqual(center.presentationState, .expanded)
        XCTAssertEqual(center.currentActivity?.kind, .preset)
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
        XCTAssertEqual(config.configVersion, NotchShelfConfig.currentConfigVersion)
    }

    func testHoverEnterThenDelayExpandsOnce() {
        var machine = NotchHoverStateMachine()

        XCTAssertEqual(machine.pointerEntered(calibrationMode: false), [.cancelCollapse, .scheduleExpand])
        XCTAssertEqual(machine.hoverDelayElapsed(calibrationMode: false), [.expand])
        XCTAssertEqual(machine.hoverDelayElapsed(calibrationMode: false), [])
        XCTAssertEqual(machine.state, .expandedByHover)
    }

    func testHoverExitBriefReenterDoesNotCollapse() {
        var machine = NotchHoverStateMachine()
        _ = machine.pointerEntered(calibrationMode: false)
        _ = machine.hoverDelayElapsed(calibrationMode: false)

        XCTAssertEqual(machine.pointerExited(calibrationMode: false), [.scheduleCollapse])
        XCTAssertEqual(machine.pointerEntered(calibrationMode: false), [.cancelCollapse, .scheduleExpand])
        XCTAssertEqual(machine.collapseDelayElapsed(calibrationMode: false), [])
        XCTAssertEqual(machine.state, .hoverPending)
    }

    func testHoverExitForDelayCollapsesOnce() {
        var machine = NotchHoverStateMachine()
        _ = machine.pointerEntered(calibrationMode: false)
        _ = machine.hoverDelayElapsed(calibrationMode: false)
        _ = machine.pointerExited(calibrationMode: false)

        XCTAssertEqual(machine.collapseDelayElapsed(calibrationMode: false), [.collapse])
        XCTAssertEqual(machine.collapseDelayElapsed(calibrationMode: false), [])
        XCTAssertEqual(machine.state, .idle)
    }

    func testClickExpansionPersistsAcrossHoverExit() {
        var machine = NotchHoverStateMachine()

        XCTAssertEqual(machine.clickToggle(isExpanded: false, calibrationMode: false), [.cancelExpand, .cancelCollapse, .expand])
        XCTAssertEqual(machine.pointerExited(calibrationMode: false), [])
        XCTAssertEqual(machine.state, .expandedByClick)
    }

    func testResetAfterProgrammaticCollapseReenablesHoverToExpand() {
        // Reproduces the regression where a chevron/swipe/Settings collapse
        // left the machine stuck in .expandedByClick, killing hover-to-expand.
        var machine = NotchHoverStateMachine()
        _ = machine.clickToggle(isExpanded: false, calibrationMode: false) // -> .expandedByClick
        _ = machine.pointerExited(calibrationMode: false)                  // pointer leaves via chevron

        // collapseNotchIsland() resets the machine.
        XCTAssertEqual(machine.reset(), [.cancelExpand, .cancelCollapse])
        XCTAssertEqual(machine.state, .idle)

        // A later hover now schedules an expand instead of no-oping.
        XCTAssertEqual(machine.pointerEntered(calibrationMode: false), [.cancelCollapse, .scheduleExpand])
        XCTAssertEqual(machine.hoverDelayElapsed(calibrationMode: false), [.expand])
        XCTAssertEqual(machine.state, .expandedByHover)
    }

    func testHoldExpandedStaysOpenUntilExplicitCollapse() {
        // expandNotchIsland() (swipe/Settings/App Intent) holds the island open
        // like a click-expand: pointer exit must not auto-collapse it.
        var machine = NotchHoverStateMachine()

        XCTAssertEqual(machine.holdExpanded(), [.cancelExpand, .cancelCollapse])
        XCTAssertEqual(machine.state, .expandedByClick)
        XCTAssertEqual(machine.pointerExited(calibrationMode: false), [])
        XCTAssertEqual(machine.state, .expandedByClick)

        // A subsequent click collapses it.
        XCTAssertEqual(
            machine.clickToggle(isExpanded: true, calibrationMode: false),
            [.cancelExpand, .cancelCollapse, .collapse]
        )
        XCTAssertEqual(machine.state, .idle)
    }

    func testCalibrationModeDisablesHoverTransitions() {
        var machine = NotchHoverStateMachine()

        XCTAssertEqual(machine.pointerEntered(calibrationMode: true), [.cancelExpand, .cancelCollapse])
        XCTAssertEqual(machine.hoverDelayElapsed(calibrationMode: true), [])
        XCTAssertEqual(machine.state, .draggingCalibration)
        XCTAssertEqual(machine.endCalibrationDrag(), [.cancelExpand, .cancelCollapse])
        XCTAssertEqual(machine.state, .idle)
    }

    func testCalibrationPersistsEncodeDecode() throws {
        var config = NotchShelfConfig.default
        config.islandHorizontalOffset = 44
        config.islandVerticalOffset = -18
        config.calibrationModeEnabled = true

        let data = try JSONEncoder().encode(config)
        let decoded = try JSONDecoder().decode(NotchShelfConfig.self, from: data)

        XCTAssertEqual(decoded.islandHorizontalOffset, 44)
        XCTAssertEqual(decoded.islandVerticalOffset, -18)
        XCTAssertTrue(decoded.calibrationModeEnabled)
    }

    func testHardResetClearsBadVisualValues() {
        var config = NotchShelfConfig.default
        config.islandHorizontalOffset = 120
        config.islandVerticalOffset = -100
        config.forceAttachedNotchTestMode = true
        config.calibrationModeEnabled = true

        config.hardResetVisualState()

        XCTAssertEqual(config.islandHorizontalOffset, 0)
        XCTAssertEqual(config.islandVerticalOffset, 0)
        XCTAssertFalse(config.forceAttachedNotchTestMode)
        XCTAssertFalse(config.calibrationModeEnabled)
    }
}
