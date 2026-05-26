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
}
