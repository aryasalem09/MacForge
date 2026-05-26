import Foundation

struct BookmarkRecord: Identifiable, Codable, Hashable {
    var id: UUID
    var name: String
    var bookmarkData: Data
    var originalPath: String
    var createdAt: Date

    init(id: UUID = UUID(), name: String, bookmarkData: Data, originalPath: String, createdAt: Date = Date()) {
        self.id = id
        self.name = name
        self.bookmarkData = bookmarkData
        self.originalPath = originalPath
        self.createdAt = createdAt
    }
}

struct ResolvedBookmark {
    var url: URL
    var isStale: Bool
    private let didStartAccessing: Bool

    init(url: URL, isStale: Bool, didStartAccessing: Bool) {
        self.url = url
        self.isStale = isStale
        self.didStartAccessing = didStartAccessing
    }

    func stopAccessing() {
        if didStartAccessing {
            url.stopAccessingSecurityScopedResource()
        }
    }
}

struct SecurityScopedBookmarkStore {
    func makeRecord(for url: URL, name: String? = nil) throws -> BookmarkRecord {
        let bookmark = try url.bookmarkData(options: [.withSecurityScope], includingResourceValuesForKeys: nil, relativeTo: nil)
        return BookmarkRecord(name: name ?? url.lastPathComponent, bookmarkData: bookmark, originalPath: url.path)
    }

    func resolve(_ record: BookmarkRecord, startAccessing: Bool = true) throws -> ResolvedBookmark {
        var stale = false
        let url = try URL(resolvingBookmarkData: record.bookmarkData, options: [.withSecurityScope], relativeTo: nil, bookmarkDataIsStale: &stale)
        let didStart = startAccessing ? url.startAccessingSecurityScopedResource() : false
        return ResolvedBookmark(url: url, isStale: stale, didStartAccessing: didStart)
    }

    func encode(_ records: [BookmarkRecord]) throws -> Data {
        try JSONEncoder.macForge.encode(records)
    }

    func decode(_ data: Data) throws -> [BookmarkRecord] {
        try JSONDecoder.macForge.decode([BookmarkRecord].self, from: data)
    }
}
