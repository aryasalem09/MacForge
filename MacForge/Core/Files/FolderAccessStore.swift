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

    func resolve(_ shortcut: FolderShortcut, startAccessing: Bool = true) -> URL? {
        guard let bookmarkData = shortcut.bookmarkData else {
            return URL(fileURLWithPath: shortcut.path)
        }

        let record = BookmarkRecord(id: shortcut.id, name: shortcut.name, bookmarkData: bookmarkData, originalPath: shortcut.path, createdAt: shortcut.createdAt)
        do {
            return try bookmarkStore.resolve(record, startAccessing: startAccessing).url
        } catch {
            return URL(fileURLWithPath: shortcut.path)
        }
    }

    func open(_ shortcut: FolderShortcut) -> CommandResult {
        guard let url = resolve(shortcut) else {
            return .failure("Open Folder", "Could not resolve access for \(shortcut.name).")
        }
        return NSWorkspace.shared.open(url)
            ? .success("Open Folder", "Opened \(shortcut.name).")
            : .failure("Open Folder", "Finder could not open \(shortcut.name).")
    }

    func reveal(_ shortcut: FolderShortcut) -> CommandResult {
        guard let url = resolve(shortcut) else {
            return .failure("Reveal Folder", "Could not resolve access for \(shortcut.name).")
        }
        NSWorkspace.shared.activateFileViewerSelecting([url])
        return .success("Reveal Folder", "Revealed \(shortcut.name) in Finder.")
    }

    func metadata(for shortcut: FolderShortcut) async -> FolderMetadata {
        guard let url = await MainActor.run(body: { resolve(shortcut) }) else {
            return FolderMetadata(itemCount: nil, lastModified: nil, sizeBytes: nil)
        }

        let fileManager = FileManager.default
        let resourceValues = try? url.resourceValues(forKeys: [.contentModificationDateKey])
        let itemCount = (try? fileManager.contentsOfDirectory(atPath: url.path).count)
        return FolderMetadata(itemCount: itemCount, lastModified: resourceValues?.contentModificationDate, sizeBytes: nil)
    }
}

struct FolderMetadata: Codable, Hashable {
    var itemCount: Int?
    var lastModified: Date?
    var sizeBytes: Int64?
}
