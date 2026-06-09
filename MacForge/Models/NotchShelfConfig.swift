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

enum NotchShelfPreferredStyle: String, CaseIterable, Codable, Identifiable, Hashable {
    case island
    case classicShelf

    var id: String { rawValue }

    var label: String {
        switch self {
        case .island: "Notch Island"
        case .classicShelf: "Classic Shelf"
        }
    }
}

enum NotchIslandMaterialStyle: String, CaseIterable, Codable, Identifiable, Hashable {
    case dark
    case glass

    var id: String { rawValue }

    var label: String {
        switch self {
        case .dark: "Dark"
        case .glass: "Glass"
        }
    }
}

struct NotchShelfConfig: Codable, Equatable, Hashable {
    var enabled: Bool
    var preferredStyle: NotchShelfPreferredStyle
    var positionMode: NotchShelfPositionMode
    var presentationState: NotchIslandPresentationState
    var width: Double
    var height: Double
    var autoCollapseDelay: Double
    var collapsedWidth: Double
    var collapsedHeight: Double
    var compactWidth: Double
    var compactHeight: Double
    var expandedWidth: Double
    var expandedHeight: Double
    var cornerRadius: Double
    var opacity: Double
    var materialStyle: NotchIslandMaterialStyle
    var showClock: Bool
    var showFolders: Bool
    var showWindowActions: Bool
    var showPresets: Bool
    var showCurrentApp: Bool
    var showClipboardPreviewPlaceholder: Bool
    var showRecentResults: Bool
    var showActivityProgress: Bool
    var ignoreMouseEventsWhenInactive: Bool
    var expandOnHover: Bool
    var expandOnClick: Bool
    var mainDisplayOnly: Bool
    var customX: Double
    var customY: Double

    static let `default` = NotchShelfConfig(
        enabled: false,
        preferredStyle: .island,
        positionMode: .automaticNotchAware,
        presentationState: .collapsed,
        width: 620,
        height: 76,
        autoCollapseDelay: 4.0,
        collapsedWidth: 210,
        collapsedHeight: 36,
        compactWidth: 330,
        compactHeight: 46,
        expandedWidth: 580,
        expandedHeight: 360,
        cornerRadius: 22,
        opacity: 0.92,
        materialStyle: .dark,
        showClock: true,
        showFolders: true,
        showWindowActions: true,
        showPresets: true,
        showCurrentApp: true,
        showClipboardPreviewPlaceholder: false,
        showRecentResults: true,
        showActivityProgress: true,
        ignoreMouseEventsWhenInactive: false,
        expandOnHover: true,
        expandOnClick: true,
        mainDisplayOnly: true,
        customX: 0,
        customY: 0
    )

    init(
        enabled: Bool,
        preferredStyle: NotchShelfPreferredStyle,
        positionMode: NotchShelfPositionMode,
        presentationState: NotchIslandPresentationState,
        width: Double,
        height: Double,
        autoCollapseDelay: Double,
        collapsedWidth: Double,
        collapsedHeight: Double,
        compactWidth: Double,
        compactHeight: Double,
        expandedWidth: Double,
        expandedHeight: Double,
        cornerRadius: Double,
        opacity: Double,
        materialStyle: NotchIslandMaterialStyle,
        showClock: Bool,
        showFolders: Bool,
        showWindowActions: Bool,
        showPresets: Bool,
        showCurrentApp: Bool,
        showClipboardPreviewPlaceholder: Bool,
        showRecentResults: Bool,
        showActivityProgress: Bool,
        ignoreMouseEventsWhenInactive: Bool,
        expandOnHover: Bool,
        expandOnClick: Bool,
        mainDisplayOnly: Bool,
        customX: Double,
        customY: Double
    ) {
        self.enabled = enabled
        self.preferredStyle = preferredStyle
        self.positionMode = positionMode
        self.presentationState = presentationState
        self.width = width
        self.height = height
        self.autoCollapseDelay = autoCollapseDelay
        self.collapsedWidth = collapsedWidth
        self.collapsedHeight = collapsedHeight
        self.compactWidth = compactWidth
        self.compactHeight = compactHeight
        self.expandedWidth = expandedWidth
        self.expandedHeight = expandedHeight
        self.cornerRadius = cornerRadius
        self.opacity = opacity
        self.materialStyle = materialStyle
        self.showClock = showClock
        self.showFolders = showFolders
        self.showWindowActions = showWindowActions
        self.showPresets = showPresets
        self.showCurrentApp = showCurrentApp
        self.showClipboardPreviewPlaceholder = showClipboardPreviewPlaceholder
        self.showRecentResults = showRecentResults
        self.showActivityProgress = showActivityProgress
        self.ignoreMouseEventsWhenInactive = ignoreMouseEventsWhenInactive
        self.expandOnHover = expandOnHover
        self.expandOnClick = expandOnClick
        self.mainDisplayOnly = mainDisplayOnly
        self.customX = customX
        self.customY = customY
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let defaults = Self.default

        enabled = try container.decodeIfPresent(Bool.self, forKey: .enabled) ?? defaults.enabled
        preferredStyle = try container.decodeIfPresent(NotchShelfPreferredStyle.self, forKey: .preferredStyle) ?? defaults.preferredStyle
        positionMode = try container.decodeIfPresent(NotchShelfPositionMode.self, forKey: .positionMode) ?? defaults.positionMode
        presentationState = try container.decodeIfPresent(NotchIslandPresentationState.self, forKey: .presentationState) ?? defaults.presentationState
        width = try container.decodeIfPresent(Double.self, forKey: .width) ?? defaults.width
        height = try container.decodeIfPresent(Double.self, forKey: .height) ?? defaults.height
        autoCollapseDelay = try container.decodeIfPresent(Double.self, forKey: .autoCollapseDelay) ?? defaults.autoCollapseDelay
        collapsedWidth = try container.decodeIfPresent(Double.self, forKey: .collapsedWidth) ?? defaults.collapsedWidth
        collapsedHeight = try container.decodeIfPresent(Double.self, forKey: .collapsedHeight) ?? defaults.collapsedHeight
        compactWidth = try container.decodeIfPresent(Double.self, forKey: .compactWidth) ?? defaults.compactWidth
        compactHeight = try container.decodeIfPresent(Double.self, forKey: .compactHeight) ?? defaults.compactHeight
        expandedWidth = try container.decodeIfPresent(Double.self, forKey: .expandedWidth) ?? defaults.expandedWidth
        expandedHeight = try container.decodeIfPresent(Double.self, forKey: .expandedHeight) ?? defaults.expandedHeight
        cornerRadius = try container.decodeIfPresent(Double.self, forKey: .cornerRadius) ?? defaults.cornerRadius
        opacity = try container.decodeIfPresent(Double.self, forKey: .opacity) ?? defaults.opacity
        materialStyle = try container.decodeIfPresent(NotchIslandMaterialStyle.self, forKey: .materialStyle) ?? defaults.materialStyle
        showClock = try container.decodeIfPresent(Bool.self, forKey: .showClock) ?? defaults.showClock
        showFolders = try container.decodeIfPresent(Bool.self, forKey: .showFolders) ?? defaults.showFolders
        showWindowActions = try container.decodeIfPresent(Bool.self, forKey: .showWindowActions) ?? defaults.showWindowActions
        showPresets = try container.decodeIfPresent(Bool.self, forKey: .showPresets) ?? defaults.showPresets
        showCurrentApp = try container.decodeIfPresent(Bool.self, forKey: .showCurrentApp) ?? defaults.showCurrentApp
        showClipboardPreviewPlaceholder = try container.decodeIfPresent(Bool.self, forKey: .showClipboardPreviewPlaceholder) ?? defaults.showClipboardPreviewPlaceholder
        showRecentResults = try container.decodeIfPresent(Bool.self, forKey: .showRecentResults) ?? defaults.showRecentResults
        showActivityProgress = try container.decodeIfPresent(Bool.self, forKey: .showActivityProgress) ?? defaults.showActivityProgress
        ignoreMouseEventsWhenInactive = try container.decodeIfPresent(Bool.self, forKey: .ignoreMouseEventsWhenInactive) ?? defaults.ignoreMouseEventsWhenInactive
        expandOnHover = try container.decodeIfPresent(Bool.self, forKey: .expandOnHover) ?? defaults.expandOnHover
        expandOnClick = try container.decodeIfPresent(Bool.self, forKey: .expandOnClick) ?? defaults.expandOnClick
        mainDisplayOnly = try container.decodeIfPresent(Bool.self, forKey: .mainDisplayOnly) ?? defaults.mainDisplayOnly
        customX = try container.decodeIfPresent(Double.self, forKey: .customX) ?? defaults.customX
        customY = try container.decodeIfPresent(Double.self, forKey: .customY) ?? defaults.customY
    }
}
