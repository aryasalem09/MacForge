import Foundation

struct FolderShortcut: Identifiable, Codable, Hashable {
    var id: UUID
    var name: String
    var bookmarkData: Data?
    var path: String
    var createdAt: Date
    var lastResolvedAt: Date?

    init(id: UUID = UUID(), name: String, bookmarkData: Data? = nil, path: String, createdAt: Date = Date(), lastResolvedAt: Date? = nil) {
        self.id = id
        self.name = name
        self.bookmarkData = bookmarkData
        self.path = path
        self.createdAt = createdAt
        self.lastResolvedAt = lastResolvedAt
    }

    var displayPath: String {
        (path as NSString).abbreviatingWithTildeInPath
    }
}
