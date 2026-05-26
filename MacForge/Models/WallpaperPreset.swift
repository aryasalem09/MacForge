import Foundation

enum WallpaperTargetBehavior: String, CaseIterable, Codable, Identifiable, Hashable {
    case allScreens
    case mainScreen
    case eachScreenCustom

    var id: String { rawValue }

    var label: String {
        switch self {
        case .allScreens: "All Screens"
        case .mainScreen: "Main Screen"
        case .eachScreenCustom: "Each Screen Custom"
        }
    }
}

struct WallpaperPreset: Identifiable, Codable, Hashable {
    var id: UUID
    var name: String
    var imageBookmarkData: Data?
    var imagePath: String
    var targetBehavior: WallpaperTargetBehavior
    var createdAt: Date

    init(
        id: UUID = UUID(),
        name: String,
        imageBookmarkData: Data? = nil,
        imagePath: String,
        targetBehavior: WallpaperTargetBehavior = .allScreens,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.name = name
        self.imageBookmarkData = imageBookmarkData
        self.imagePath = imagePath
        self.targetBehavior = targetBehavior
        self.createdAt = createdAt
    }
}
