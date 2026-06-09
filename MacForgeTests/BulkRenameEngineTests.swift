import XCTest
@testable import MacForge

final class BulkRenameEngineTests: XCTestCase {
    func testPreviewPreservesExtensionAndSequence() {
        let urls = [
            URL(fileURLWithPath: "/tmp/photo one.jpg"),
            URL(fileURLWithPath: "/tmp/photo two.jpg")
        ]
        let request = BulkRenameRequest(prefix: "Trip-", suffix: "", findText: "photo ", replaceText: "", sequenceEnabled: true, sequenceStart: 7, preserveExtension: true)

        let preview = BulkRenameEngine().preview(urls: urls, request: request)

        XCTAssertEqual(preview.map(\.newName), ["Trip-one-007.jpg", "Trip-two-008.jpg"])
    }

    func testDetectsGeneratedNameCollisions() {
        let urls = [
            URL(fileURLWithPath: "/tmp/a.txt"),
            URL(fileURLWithPath: "/tmp/b.txt")
        ]
        let request = BulkRenameRequest(prefix: "", suffix: "", findText: "", replaceText: "", sequenceEnabled: false, sequenceStart: 1, preserveExtension: false)

        let preview = BulkRenameEngine().preview(urls: urls, request: request)

        XCTAssertFalse(preview.contains { $0.hasCollision })

        let collisionRequest = BulkRenameRequest(prefix: "", suffix: "", findText: "a", replaceText: "x", sequenceEnabled: false, sequenceStart: 1, preserveExtension: false)
        let collisionPreview = BulkRenameEngine().preview(urls: [
            URL(fileURLWithPath: "/tmp/a"),
            URL(fileURLWithPath: "/tmp/x")
        ], request: collisionRequest)
        XCTAssertTrue(collisionPreview.contains { $0.hasCollision })
    }

    func testNoOpRenameCannotApply() {
        let urls = [URL(fileURLWithPath: "/tmp/report.txt")]
        let preview = BulkRenameEngine().preview(urls: urls, request: .empty)

        XCTAssertFalse(BulkRenameEngine().canApply(preview))

        let results = BulkRenameEngine().apply(previews: preview)
        XCTAssertFalse(results.first?.success == true)
        XCTAssertEqual(results.first?.message, "No files would change.")
    }

    func testCollisionBlocksApply() {
        let preview = [
            BulkRenamePreviewItem(
                originalURL: URL(fileURLWithPath: "/tmp/a.txt"),
                newName: "same.txt",
                newURL: URL(fileURLWithPath: "/tmp/same.txt"),
                hasCollision: true
            )
        ]

        XCTAssertFalse(BulkRenameEngine().canApply(preview))

        let results = BulkRenameEngine().apply(previews: preview)
        XCTAssertFalse(results.first?.success == true)
        XCTAssertEqual(results.first?.message, "Rename blocked because one or more destination names collide.")
    }

    func testExistingDestinationCollisionIsDetected() throws {
        let directory = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }

        let source = directory.appendingPathComponent("report.txt")
        let existing = directory.appendingPathComponent("final-report.txt")
        try Data("source".utf8).write(to: source)
        try Data("existing".utf8).write(to: existing)

        let request = BulkRenameRequest(prefix: "final-", suffix: "", findText: "", replaceText: "", sequenceEnabled: false, sequenceStart: 1, preserveExtension: true)
        let preview = BulkRenameEngine().preview(urls: [source], request: request)

        XCTAssertTrue(preview.first?.hasCollision == true)
        XCTAssertFalse(BulkRenameEngine().canApply(preview))
        XCTAssertEqual(try String(contentsOf: existing), "existing")
    }

    func testApplyRenamesRealFilesAfterSafePreview() throws {
        let directory = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }

        let first = directory.appendingPathComponent("report-a.txt")
        let second = directory.appendingPathComponent("report-b.txt")
        try Data("one".utf8).write(to: first)
        try Data("two".utf8).write(to: second)

        let request = BulkRenameRequest(prefix: "done-", suffix: "", findText: "", replaceText: "", sequenceEnabled: true, sequenceStart: 3, preserveExtension: true)
        let preview = BulkRenameEngine().preview(urls: [first, second], request: request)

        XCTAssertTrue(BulkRenameEngine().canApply(preview))
        let results = BulkRenameEngine().apply(previews: preview)

        XCTAssertEqual(results.filter(\.success).count, 2)
        XCTAssertFalse(FileManager.default.fileExists(atPath: first.path))
        XCTAssertFalse(FileManager.default.fileExists(atPath: second.path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: directory.appendingPathComponent("done-report-a-003.txt").path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: directory.appendingPathComponent("done-report-b-004.txt").path))
    }

    private func makeTemporaryDirectory() throws -> URL {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }
}
