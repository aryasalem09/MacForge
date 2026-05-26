import CoreGraphics
import Foundation

enum WindowLayoutType: String, CaseIterable, Codable, Identifiable, Hashable {
    case leftHalf
    case rightHalf
    case topHalf
    case bottomHalf
    case maximize
    case center
    case thirdsLeft
    case thirdsCenter
    case thirdsRight
    case twoThirdsLeft
    case twoThirdsRight
    case customGrid

    var id: String { rawValue }

    var label: String {
        switch self {
        case .leftHalf: "Left Half"
        case .rightHalf: "Right Half"
        case .topHalf: "Top Half"
        case .bottomHalf: "Bottom Half"
        case .maximize: "Maximize"
        case .center: "Center"
        case .thirdsLeft: "Left Third"
        case .thirdsCenter: "Center Third"
        case .thirdsRight: "Right Third"
        case .twoThirdsLeft: "Left Two Thirds"
        case .twoThirdsRight: "Right Two Thirds"
        case .customGrid: "Custom Grid"
        }
    }

    var symbolName: String {
        switch self {
        case .leftHalf: "rectangle.lefthalf.inset.filled"
        case .rightHalf: "rectangle.righthalf.inset.filled"
        case .topHalf: "rectangle.tophalf.inset.filled"
        case .bottomHalf: "rectangle.bottomhalf.inset.filled"
        case .maximize: "arrow.up.left.and.arrow.down.right"
        case .center: "rectangle.center.inset.filled"
        case .thirdsLeft, .thirdsCenter, .thirdsRight: "rectangle.split.3x1"
        case .twoThirdsLeft, .twoThirdsRight: "rectangle.split.2x1"
        case .customGrid: "square.grid.3x3"
        }
    }
}

struct GridCell: Codable, Hashable, Identifiable {
    var row: Int
    var column: Int

    var id: String { "\(row)-\(column)" }
}

struct CustomGridSelection: Codable, Hashable {
    var rows: Int
    var columns: Int
    var selectedCells: [GridCell]

    static let centeredTwoByTwo = CustomGridSelection(
        rows: 3,
        columns: 3,
        selectedCells: [
            GridCell(row: 1, column: 1)
        ]
    )
}

struct WindowLayoutPreset: Identifiable, Codable, Hashable {
    var id: UUID
    var name: String
    var layoutType: WindowLayoutType
    var customGrid: CustomGridSelection?

    init(id: UUID = UUID(), name: String, layoutType: WindowLayoutType, customGrid: CustomGridSelection? = nil) {
        self.id = id
        self.name = name
        self.layoutType = layoutType
        self.customGrid = customGrid
    }
}
