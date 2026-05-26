import AppIntents
import Foundation

@available(macOS 14.0, *)
struct OpenPinnedFolderIntent: AppIntent {
    static var title: LocalizedStringResource = "Open Pinned Folder"
    static var description = IntentDescription("Ask MacForge to open a named pinned folder.")

    @Parameter(title: "Folder Name")
    var folderName: String

    init() {
        self.folderName = ""
    }

    init(folderName: String) {
        self.folderName = folderName
    }

    func perform() async throws -> some IntentResult {
        UserDefaults.standard.set(folderName, forKey: "MacForgeLastRequestedFolderName")
        return .result()
    }
}
