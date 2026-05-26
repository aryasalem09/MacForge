import Foundation

struct PresetStore {
    var presets: [AppPreset]

    static let seeded = PresetStore(presets: AppPreset.examples)
}
