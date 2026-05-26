import Foundation

enum PresetAction: Codable, Hashable, Identifiable {
    case toggleNotchShelf(Bool)
    case applyDockSettings(DockSettings)
    case applyWallpaperPreset(WallpaperPreset.ID)
    case applyWindowLayout(WindowLayoutPreset)
    case openFolder(FolderShortcut.ID)
    case runFileRule(FileRule.ID, dryRun: Bool)

    var id: String {
        switch self {
        case .toggleNotchShelf(let enabled): "toggleNotchShelf-\(enabled)"
        case .applyDockSettings(let settings): "applyDockSettings-\(settings.hashValue)"
        case .applyWallpaperPreset(let id): "applyWallpaperPreset-\(id.uuidString)"
        case .applyWindowLayout(let preset): "applyWindowLayout-\(preset.id.uuidString)"
        case .openFolder(let id): "openFolder-\(id.uuidString)"
        case .runFileRule(let id, let dryRun): "runFileRule-\(id.uuidString)-\(dryRun)"
        }
    }

    var label: String {
        switch self {
        case .toggleNotchShelf(let enabled): enabled ? "Show Notch Shelf" : "Hide Notch Shelf"
        case .applyDockSettings: "Apply Dock Settings"
        case .applyWallpaperPreset: "Apply Wallpaper"
        case .applyWindowLayout(let preset): "Tile Window: \(preset.name)"
        case .openFolder: "Open Folder"
        case .runFileRule(_, let dryRun): dryRun ? "Preview File Rule" : "Run File Rule"
        }
    }
}

struct AppPreset: Identifiable, Codable, Hashable {
    var id: UUID
    var name: String
    var iconName: String
    var actions: [PresetAction]
    var requiresConfirmation: Bool
    var lastRunDate: Date?

    init(
        id: UUID = UUID(),
        name: String,
        iconName: String,
        actions: [PresetAction],
        requiresConfirmation: Bool = true,
        lastRunDate: Date? = nil
    ) {
        self.id = id
        self.name = name
        self.iconName = iconName
        self.actions = actions
        self.requiresConfirmation = requiresConfirmation
        self.lastRunDate = lastRunDate
    }

    static let examples: [AppPreset] = [
        AppPreset(
            name: "Focus Mode",
            iconName: "scope",
            actions: [
                .toggleNotchShelf(true),
                .applyDockSettings(DockSettings(autoHide: true, tileSize: 42, magnification: false, magnificationSize: 64, position: .bottom, showRecentApps: false)),
                .applyWindowLayout(WindowLayoutPreset(name: "Centered", layoutType: .center))
            ]
        ),
        AppPreset(
            name: "Presentation",
            iconName: "rectangle.on.rectangle",
            actions: [
                .toggleNotchShelf(false),
                .applyDockSettings(DockSettings(autoHide: true, tileSize: 40, magnification: false, magnificationSize: 64, position: .bottom, showRecentApps: false))
            ]
        ),
        AppPreset(
            name: "Work Setup",
            iconName: "briefcase",
            actions: [
                .toggleNotchShelf(true),
                .applyWindowLayout(WindowLayoutPreset(name: "Maximize", layoutType: .maximize))
            ]
        )
    ]
}
