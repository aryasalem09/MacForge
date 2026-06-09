import XCTest
@testable import MacForge

final class SecurityScopedBookmarkStoreTests: XCTestCase {
    func testBookmarkRecordJSONRoundTrip() throws {
        let records = [
            BookmarkRecord(name: "Folder", bookmarkData: Data([1, 2, 3]), originalPath: "/tmp/Folder")
        ]
        let store = SecurityScopedBookmarkStore()

        let data = try store.encode(records)
        let decoded = try store.decode(data)

        XCTAssertEqual(decoded.first?.id, records.first?.id)
        XCTAssertEqual(decoded.first?.name, "Folder")
        XCTAssertEqual(decoded.first?.bookmarkData, Data([1, 2, 3]))
        XCTAssertEqual(decoded.first?.originalPath, "/tmp/Folder")
        XCTAssertEqual(decoded.first?.createdAt.timeIntervalSince(records[0].createdAt) ?? 99, 0, accuracy: 1)
    }

    @MainActor
    func testFolderShortcutWithoutBookmarkUsesScopedHelperPath() {
        let path = "/tmp/MacForgeFolder"
        let shortcut = FolderShortcut(name: "Folder", path: path)
        let store = FolderAccessStore()

        let resolvedPath = store.withResolvedURL(shortcut) { url in
            url.path
        }

        XCTAssertEqual(resolvedPath, path)
    }

    @MainActor
    func testPathBackedShortcutMetadataUsesSelectedFolder() async throws {
        let directory = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        try Data("one".utf8).write(to: directory.appendingPathComponent("one.txt"))
        try Data("two".utf8).write(to: directory.appendingPathComponent("two.txt"))

        let shortcut = FolderShortcut(name: "Folder", path: directory.path)
        let metadata = await FolderAccessStore().metadata(for: shortcut)

        XCTAssertEqual(metadata.itemCount, 2)
        XCTAssertNotNil(metadata.lastModified)
    }

    @MainActor
    func testPermissionSnapshotReflectsFileAccessAndDockToggleState() {
        let missingAccess = PermissionCenter().snapshot(folderAccessCount: 0, experimentalDockTweaksEnabled: false)
        let grantedAccess = PermissionCenter().snapshot(folderAccessCount: 2, experimentalDockTweaksEnabled: true)

        XCTAssertEqual(missingAccess.first { $0.id == "file-access" }?.status, .limited)
        XCTAssertEqual(missingAccess.first { $0.id == "dock-tweaks" }?.status, .disabled)
        XCTAssertEqual(grantedAccess.first { $0.id == "file-access" }?.status, .granted)
        XCTAssertEqual(grantedAccess.first { $0.id == "dock-tweaks" }?.status, .granted)
    }

    private func makeTemporaryDirectory() throws -> URL {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }
}
