import Foundation

struct WindowPresetRunner {
    let windowManager: WindowManaging

    func run(_ preset: WindowLayoutPreset) async -> CommandResult {
        await windowManager.tileFocusedWindow(preset.layoutType, customGrid: preset.customGrid)
    }
}
