import Foundation

enum DockPosition: String, CaseIterable, Codable, Identifiable, Hashable {
    case left
    case bottom
    case right

    var id: String { rawValue }

    var label: String {
        switch self {
        case .left: "Left"
        case .bottom: "Bottom"
        case .right: "Right"
        }
    }
}

struct DockSettings: Codable, Equatable, Hashable {
    var autoHide: Bool
    var tileSize: Double
    var magnification: Bool
    var magnificationSize: Double
    var position: DockPosition
    var showRecentApps: Bool

    static let `default` = DockSettings(
        autoHide: false,
        tileSize: 48,
        magnification: false,
        magnificationSize: 64,
        position: .bottom,
        showRecentApps: true
    )
}
