import AppIntents
import Foundation

@available(macOS 14.0, *)
struct ToggleNotchShelfIntent: AppIntent {
    static var title: LocalizedStringResource = "Toggle Notch Shelf"
    static var description = IntentDescription("Toggle MacForge's floating Notch Shelf.")

    func perform() async throws -> some IntentResult {
        let current = UserDefaults.standard.bool(forKey: "MacForgeShortcutNotchShelfRequested")
        UserDefaults.standard.set(!current, forKey: "MacForgeShortcutNotchShelfRequested")
        return .result()
    }
}
