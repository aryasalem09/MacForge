import Foundation

struct ScreenWallpaperState: Identifiable, Codable, Hashable {
    var id: String
    var localizedName: String
    var imagePath: String?
}
