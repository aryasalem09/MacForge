import AppIntents
import Foundation

@available(macOS 14.0, *)
enum IntentWindowLayout: String, AppEnum {
    case leftHalf
    case rightHalf
    case maximize
    case center

    static var typeDisplayRepresentation = TypeDisplayRepresentation(name: "Window Layout")
    static var caseDisplayRepresentations: [IntentWindowLayout: DisplayRepresentation] = [
        .leftHalf: "Left Half",
        .rightHalf: "Right Half",
        .maximize: "Maximize",
        .center: "Center"
    ]
}

@available(macOS 14.0, *)
struct TileFocusedWindowIntent: AppIntent {
    static var title: LocalizedStringResource = "Tile Focused Window"
    static var description = IntentDescription("Tile the currently focused window with MacForge.")

    @Parameter(title: "Layout")
    var layout: IntentWindowLayout

    init() {
        self.layout = .center
    }

    init(layout: IntentWindowLayout) {
        self.layout = layout
    }

    func perform() async throws -> some IntentResult {
        UserDefaults.standard.set(layout.rawValue, forKey: "MacForgeLastRequestedWindowLayout")
        return .result()
    }
}
