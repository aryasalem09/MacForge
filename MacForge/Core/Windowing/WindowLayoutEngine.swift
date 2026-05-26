import CoreGraphics
import Foundation

struct WindowLayoutEngine {
    static func targetFrame(
        for layout: WindowLayoutType,
        visibleFrame: CGRect,
        customGrid: CustomGridSelection? = nil
    ) throws -> CGRect {
        let x = visibleFrame.minX
        let y = visibleFrame.minY
        let width = visibleFrame.width
        let height = visibleFrame.height

        let frame: CGRect
        switch layout {
        case .leftHalf:
            frame = CGRect(x: x, y: y, width: width / 2, height: height)
        case .rightHalf:
            frame = CGRect(x: x + width / 2, y: y, width: width / 2, height: height)
        case .topHalf:
            frame = CGRect(x: x, y: y + height / 2, width: width, height: height / 2)
        case .bottomHalf:
            frame = CGRect(x: x, y: y, width: width, height: height / 2)
        case .maximize:
            frame = visibleFrame
        case .center:
            let targetWidth = min(width * 0.72, 1120)
            let targetHeight = min(height * 0.78, 860)
            frame = CGRect(
                x: x + (width - targetWidth) / 2,
                y: y + (height - targetHeight) / 2,
                width: targetWidth,
                height: targetHeight
            )
        case .thirdsLeft:
            frame = CGRect(x: x, y: y, width: width / 3, height: height)
        case .thirdsCenter:
            frame = CGRect(x: x + width / 3, y: y, width: width / 3, height: height)
        case .thirdsRight:
            frame = CGRect(x: x + (2 * width / 3), y: y, width: width / 3, height: height)
        case .twoThirdsLeft:
            frame = CGRect(x: x, y: y, width: 2 * width / 3, height: height)
        case .twoThirdsRight:
            frame = CGRect(x: x + width / 3, y: y, width: 2 * width / 3, height: height)
        case .customGrid:
            guard let customGrid else { throw WindowGeometryError.emptySelection }
            frame = try customGridFrame(visibleFrame: visibleFrame, selection: customGrid)
        }

        return frame.integral
    }

    private static func customGridFrame(visibleFrame: CGRect, selection: CustomGridSelection) throws -> CGRect {
        guard selection.rows > 0, selection.columns > 0 else {
            throw WindowGeometryError.invalidGrid
        }

        guard !selection.selectedCells.isEmpty else {
            throw WindowGeometryError.emptySelection
        }

        let validCells = selection.selectedCells.filter {
            $0.row >= 0 && $0.row < selection.rows && $0.column >= 0 && $0.column < selection.columns
        }

        guard !validCells.isEmpty else {
            throw WindowGeometryError.emptySelection
        }

        let minRow = validCells.map(\.row).min() ?? 0
        let maxRow = validCells.map(\.row).max() ?? minRow
        let minColumn = validCells.map(\.column).min() ?? 0
        let maxColumn = validCells.map(\.column).max() ?? minColumn

        let cellWidth = visibleFrame.width / CGFloat(selection.columns)
        let cellHeight = visibleFrame.height / CGFloat(selection.rows)

        // Grid rows are modeled top-to-bottom for a user-facing editor, while macOS screen
        // coordinates are bottom-left based.
        let topBasedY = visibleFrame.maxY - CGFloat(maxRow + 1) * cellHeight

        return CGRect(
            x: visibleFrame.minX + CGFloat(minColumn) * cellWidth,
            y: topBasedY,
            width: CGFloat(maxColumn - minColumn + 1) * cellWidth,
            height: CGFloat(maxRow - minRow + 1) * cellHeight
        )
    }
}
