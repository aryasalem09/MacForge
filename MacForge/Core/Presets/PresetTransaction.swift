import Foundation

struct RollbackSnapshot: Codable, Hashable {
    var notchShelfEnabled: Bool?
    var dockSettings: DockSettings?
    var wallpaperStates: [ScreenWallpaperState]
    var capturedAt: Date

    init(
        notchShelfEnabled: Bool? = nil,
        dockSettings: DockSettings? = nil,
        wallpaperStates: [ScreenWallpaperState] = [],
        capturedAt: Date = Date()
    ) {
        self.notchShelfEnabled = notchShelfEnabled
        self.dockSettings = dockSettings
        self.wallpaperStates = wallpaperStates
        self.capturedAt = capturedAt
    }

    var hasRestorableState: Bool {
        notchShelfEnabled != nil || dockSettings != nil || !wallpaperStates.isEmpty
    }
}

struct PresetRollbackContext {
    var restoreNotchShelf: (Bool) async -> CommandResult
    var restoreDockSettings: (DockSettings) async -> [CommandResult]
    var restoreWallpapers: ([ScreenWallpaperState]) async -> [CommandResult]
}

struct PresetTransaction: Identifiable, Codable, Hashable {
    var id: UUID
    var presetName: String
    var oldStateSnapshot: [String: String]
    var rollbackSnapshot: RollbackSnapshot?
    var actions: [PresetAction]
    var results: [CommandResult]
    var startedAt: Date
    var finishedAt: Date?

    init(
        id: UUID = UUID(),
        presetName: String,
        oldStateSnapshot: [String: String] = [:],
        rollbackSnapshot: RollbackSnapshot? = nil,
        actions: [PresetAction],
        results: [CommandResult] = [],
        startedAt: Date = Date(),
        finishedAt: Date? = nil
    ) {
        self.id = id
        self.presetName = presetName
        self.oldStateSnapshot = oldStateSnapshot
        self.rollbackSnapshot = rollbackSnapshot
        self.actions = actions
        self.results = results
        self.startedAt = startedAt
        self.finishedAt = finishedAt
    }

    var rollbackAvailable: Bool {
        rollbackSnapshot?.hasRestorableState == true
    }

    mutating func record(_ result: CommandResult) {
        results.append(result)
    }

    mutating func finish() {
        finishedAt = Date()
    }
}
