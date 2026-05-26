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
}
