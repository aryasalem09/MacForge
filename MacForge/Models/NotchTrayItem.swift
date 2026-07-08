import Foundation

/// A file staged in the notch shelf tray. The bookmark keeps the file
/// reachable across relaunches even if the user moves it; `addedAt` drives the
/// configurable retention window.
struct NotchTrayItem: Identifiable, Codable, Hashable {
    var id: UUID
    var name: String
    var path: String
    var bookmarkData: Data?
    var addedAt: Date

    init(id: UUID = UUID(), url: URL, addedAt: Date = Date()) {
        self.id = id
        self.name = url.lastPathComponent
        self.path = url.path
        self.bookmarkData = try? url.bookmarkData(
            options: [.minimalBookmark],
            includingResourceValuesForKeys: nil,
            relativeTo: nil
        )
        self.addedAt = addedAt
    }

    /// Resolves the bookmark (tracking files the user has moved) and falls
    /// back to the recorded path. Returns nil when the file is gone.
    func resolveURL() -> URL? {
        if let bookmarkData {
            var isStale = false
            if let url = try? URL(
                resolvingBookmarkData: bookmarkData,
                options: [],
                relativeTo: nil,
                bookmarkDataIsStale: &isStale
            ) {
                return url
            }
        }
        guard FileManager.default.fileExists(atPath: path) else { return nil }
        return URL(fileURLWithPath: path)
    }
}
