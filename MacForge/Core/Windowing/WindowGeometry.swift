import CoreGraphics
import Foundation

struct WindowGeometry: Codable, Hashable {
    var frame: CGRect
    var visibleFrame: CGRect
}

enum WindowGeometryError: Error, LocalizedError {
    case invalidGrid
    case emptySelection

    var errorDescription: String? {
        switch self {
        case .invalidGrid: "The custom grid must have at least one row and one column."
        case .emptySelection: "Choose at least one grid cell."
        }
    }
}
