import Foundation

enum NotchShelfPositionMode: String, CaseIterable, Codable, Identifiable, Hashable {
    case automaticNotchAware
    case topCenter
    case custom

    var id: String { rawValue }

    var label: String {
        switch self {
        case .automaticNotchAware: "Automatic"
        case .topCenter: "Top Center"
        case .custom: "Custom"
        }
    }
}

struct NotchShelfConfig: Codable, Equatable, Hashable {
    var enabled: Bool
    var positionMode: NotchShelfPositionMode
    var width: Double
    var height: Double
    var cornerRadius: Double
    var opacity: Double
    var showClock: Bool
    var showFolders: Bool
    var showWindowActions: Bool
    var showPresets: Bool
    var showCurrentApp: Bool
    var showClipboardPreviewPlaceholder: Bool
    var ignoreMouseEventsWhenInactive: Bool
    var customX: Double
    var customY: Double

    static let `default` = NotchShelfConfig(
        enabled: false,
        positionMode: .automaticNotchAware,
        width: 620,
        height: 76,
        cornerRadius: 22,
        opacity: 0.92,
        showClock: true,
        showFolders: true,
        showWindowActions: true,
        showPresets: true,
        showCurrentApp: true,
        showClipboardPreviewPlaceholder: false,
        ignoreMouseEventsWhenInactive: false,
        customX: 0,
        customY: 0
    )
}
