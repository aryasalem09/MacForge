import AppKit
import Foundation

@MainActor
final class WallpaperService: WallpaperManaging {
    var onPresetCreated: ((WallpaperPreset) -> Void)?

    func makePreset(name: String, imageURL: URL, targetBehavior: WallpaperTargetBehavior = .allScreens) -> CommandResult {
        do {
            let bookmark = try imageURL.bookmarkData(options: [.withSecurityScope], includingResourceValuesForKeys: nil, relativeTo: nil)
            let preset = WallpaperPreset(name: name, imageBookmarkData: bookmark, imagePath: imageURL.path, targetBehavior: targetBehavior)
            onPresetCreated?(preset)
            return .success("Wallpaper Preset", "Saved \(name).", reversible: true)
        } catch {
            return .failure("Wallpaper Preset", "Could not save image access.", details: [error.localizedDescription])
        }
    }

    func apply(_ preset: WallpaperPreset) async -> CommandResult {
        do {
            let imageURL = try resolveURL(for: preset)
            let screens: [NSScreen]
            switch preset.targetBehavior {
            case .allScreens:
                screens = NSScreen.screens
            case .mainScreen, .eachScreenCustom:
                screens = [NSScreen.main ?? NSScreen.screens.first].compactMap { $0 }
            }

            guard !screens.isEmpty else {
                return .failure("Wallpaper", "No display was available.")
            }

            var details: [String] = []
            let didStartAccess = imageURL.startAccessingSecurityScopedResource()
            defer {
                if didStartAccess {
                    imageURL.stopAccessingSecurityScopedResource()
                }
            }

            for screen in screens {
                try NSWorkspace.shared.setDesktopImageURL(imageURL, for: screen, options: [:])
                details.append("Applied to \(screen.localizedName)")
            }

            return .success("Wallpaper", "Applied \(preset.name).", details: details, reversible: true)
        } catch {
            return .failure("Wallpaper", "Could not apply wallpaper.", details: [error.localizedDescription])
        }
    }

    func currentWallpaperStates() -> [ScreenWallpaperState] {
        NSScreen.screens.map { screen in
            ScreenWallpaperState(
                id: screen.localizedName,
                localizedName: screen.localizedName,
                imagePath: NSWorkspace.shared.desktopImageURL(for: screen)?.path
            )
        }
    }

    func restore(_ states: [ScreenWallpaperState]) async -> [CommandResult] {
        var results: [CommandResult] = []
        for state in states {
            guard let imagePath = state.imagePath else {
                results.append(.failure("Wallpaper Rollback", "No previous wallpaper path was captured for \(state.localizedName)."))
                continue
            }

            let imageURL = URL(fileURLWithPath: imagePath)
            guard FileManager.default.fileExists(atPath: imageURL.path) else {
                results.append(.failure("Wallpaper Rollback", "Previous wallpaper is no longer accessible for \(state.localizedName).", details: [imagePath]))
                continue
            }

            guard let screen = NSScreen.screens.first(where: { $0.localizedName == state.localizedName }) ?? NSScreen.main else {
                results.append(.failure("Wallpaper Rollback", "No display was available for \(state.localizedName)."))
                continue
            }

            do {
                try NSWorkspace.shared.setDesktopImageURL(imageURL, for: screen, options: [:])
                results.append(.success("Wallpaper Rollback", "Restored wallpaper for \(state.localizedName)."))
            } catch {
                results.append(.failure("Wallpaper Rollback", "Could not restore wallpaper for \(state.localizedName).", details: [error.localizedDescription]))
            }
        }
        return results
    }

    private func resolveURL(for preset: WallpaperPreset) throws -> URL {
        if let bookmark = preset.imageBookmarkData {
            var stale = false
            return try URL(resolvingBookmarkData: bookmark, options: [.withSecurityScope], relativeTo: nil, bookmarkDataIsStale: &stale)
        }
        return URL(fileURLWithPath: preset.imagePath)
    }
}
