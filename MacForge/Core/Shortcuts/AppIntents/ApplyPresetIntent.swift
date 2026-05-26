import AppIntents
import Foundation

@available(macOS 14.0, *)
struct ApplyPresetIntent: AppIntent {
    static var title: LocalizedStringResource = "Apply MacForge Preset"
    static var description = IntentDescription("Ask MacForge to apply a named preset.")

    @Parameter(title: "Preset Name")
    var presetName: String

    init() {
        self.presetName = ""
    }

    init(presetName: String) {
        self.presetName = presetName
    }

    func perform() async throws -> some IntentResult {
        UserDefaults.standard.set(presetName, forKey: "MacForgeLastRequestedPresetName")
        return .result()
    }
}

@available(macOS 14.0, *)
struct MacForgeAppShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: ToggleNotchShelfIntent(),
            phrases: [
                "Toggle Notch Shelf in \(.applicationName)",
                "Show shelf with \(.applicationName)"
            ],
            shortTitle: "Toggle Shelf",
            systemImageName: "macbook.gen2"
        )
        AppShortcut(
            intent: TileFocusedWindowIntent(),
            phrases: [
                "Tile focused window with \(.applicationName)",
                "Center focused window with \(.applicationName)"
            ],
            shortTitle: "Tile Window",
            systemImageName: "rectangle.3.group"
        )
    }
}
