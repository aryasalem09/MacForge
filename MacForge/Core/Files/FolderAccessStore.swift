import AppKit
import Foundation

@MainActor
final class FolderAccessStore {
    private let bookmarkStore = SecurityScopedBookmarkStore()

    func makeShortcut(for url: URL, name: String? = nil) -> Result<FolderShortcut, Error> {
        do {
            let record = try bookmarkStore.makeRecord(for: url, name: name)
            return .success(FolderShortcut(name: record.name, bookmarkData: record.bookmarkData, path: record.originalPath))
        } catch {
            return .failure(error)
        }
    }

    func resolve(_ shortcut: FolderShortcut) -> URL? {
        guard let bookmarkData = shortcut.bookmarkData else {
            return URL(fileURLWithPath: shortcut.path)
        }

        let record = BookmarkRecord(id: shortcut.id, name: shortcut.name, bookmarkData: bookmarkData, originalPath: shortcut.path, createdAt: shortcut.createdAt)
        do {
            return try bookmarkStore.resolve(record, startAccessing: false).url
        } catch {
            return URL(fileURLWithPath: shortcut.path)
        }
    }

    func withResolvedURL<T>(
        _ shortcut: FolderShortcut,
        startAccessing: Bool = true,
        perform work: (URL) throws -> T
    ) rethrows -> T {
        let resolved = resolvedBookmark(for: shortcut, startAccessing: startAccessing)
        defer { resolved?.stopAccessing() }
        return try work(resolved?.url ?? URL(fileURLWithPath: shortcut.path))
    }

    func withResolvedURL<T>(
        _ shortcut: FolderShortcut,
        startAccessing: Bool = true,
        perform work: (URL) async throws -> T
    ) async rethrows -> T {
        let resolved = resolvedBookmark(for: shortcut, startAccessing: startAccessing)
        defer { resolved?.stopAccessing() }
        return try await work(resolved?.url ?? URL(fileURLWithPath: shortcut.path))
    }

    func open(_ shortcut: FolderShortcut) -> CommandResult {
        withResolvedURL(shortcut) { url in
            NSWorkspace.shared.open(url)
                ? .success("Open Folder", "Opened \(shortcut.name).")
                : .failure("Open Folder", "Finder could not open \(shortcut.name).")
        }
    }

    func reveal(_ shortcut: FolderShortcut) -> CommandResult {
        withResolvedURL(shortcut) { url in
            NSWorkspace.shared.activateFileViewerSelecting([url])
            return .success("Reveal Folder", "Revealed \(shortcut.name) in Finder.")
        }
    }

    func metadata(for shortcut: FolderShortcut) async -> FolderMetadata {
        withResolvedURL(shortcut) { url in
            let fileManager = FileManager.default
            let resourceValues = try? url.resourceValues(forKeys: [.contentModificationDateKey])
            let itemCount = (try? fileManager.contentsOfDirectory(atPath: url.path).count)
            return FolderMetadata(itemCount: itemCount, lastModified: resourceValues?.contentModificationDate, sizeBytes: nil)
        }
    }

    private func resolvedBookmark(for shortcut: FolderShortcut, startAccessing: Bool) -> ResolvedBookmark? {
        guard let bookmarkData = shortcut.bookmarkData else {
            return nil
        }

        let record = BookmarkRecord(id: shortcut.id, name: shortcut.name, bookmarkData: bookmarkData, originalPath: shortcut.path, createdAt: shortcut.createdAt)
        return try? bookmarkStore.resolve(record, startAccessing: startAccessing)
    }
}

struct FolderMetadata: Codable, Hashable {
    var itemCount: Int?
    var lastModified: Date?
    var sizeBytes: Int64?
}
