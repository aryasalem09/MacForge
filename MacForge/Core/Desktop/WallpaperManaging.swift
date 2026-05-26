import Foundation

@MainActor
protocol WallpaperManaging {
    func makePreset(name: String, imageURL: URL, targetBehavior: WallpaperTargetBehavior) -> CommandResult
    func apply(_ preset: WallpaperPreset) async -> CommandResult
    func restore(_ states: [ScreenWallpaperState]) async -> [CommandResult]
}
