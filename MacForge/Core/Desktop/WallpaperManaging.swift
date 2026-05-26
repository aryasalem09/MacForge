import Foundation

protocol WallpaperManaging {
    func makePreset(name: String, imageURL: URL, targetBehavior: WallpaperTargetBehavior) -> CommandResult
    func apply(_ preset: WallpaperPreset) async -> CommandResult
}
