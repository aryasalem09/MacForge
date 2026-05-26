import CoreGraphics
import XCTest
@testable import MacForge

final class WindowLayoutEngineTests: XCTestCase {
    func testLeftAndRightHalvesUseVisibleFrame() throws {
        let visible = CGRect(x: 0, y: 25, width: 1440, height: 875)

        let left = try WindowLayoutEngine.targetFrame(for: .leftHalf, visibleFrame: visible)
        let right = try WindowLayoutEngine.targetFrame(for: .rightHalf, visibleFrame: visible)

        XCTAssertEqual(left, CGRect(x: 0, y: 25, width: 720, height: 875))
        XCTAssertEqual(right, CGRect(x: 720, y: 25, width: 720, height: 875))
    }

    func testCenterLayoutIsCenteredAndCapped() throws {
        let visible = CGRect(x: 0, y: 0, width: 2000, height: 1200)
        let frame = try WindowLayoutEngine.targetFrame(for: .center, visibleFrame: visible)

        XCTAssertEqual(frame.width, 1120)
        XCTAssertEqual(frame.height, 860)
        XCTAssertEqual(frame.midX, visible.midX, accuracy: 0.5)
        XCTAssertEqual(frame.midY, visible.midY, accuracy: 0.5)
    }

    func testCustomGridUsesTopBasedRows() throws {
        let visible = CGRect(x: 0, y: 0, width: 900, height: 600)
        let grid = CustomGridSelection(rows: 3, columns: 3, selectedCells: [
            GridCell(row: 0, column: 0),
            GridCell(row: 1, column: 1)
        ])

        let frame = try WindowLayoutEngine.targetFrame(for: .customGrid, visibleFrame: visible, customGrid: grid)

        XCTAssertEqual(frame, CGRect(x: 0, y: 200, width: 600, height: 400))
    }
}
