import XCTest
@testable import MacForge

final class FileRuleEngineTests: XCTestCase {
    func testExtensionMatchIgnoresCaseAndLeadingDot() {
        let rule = FileRule(name: "Images", matchKind: .fileExtension(".PNG"), action: .moveToTrash)
        let candidate = FileCandidate(url: URL(fileURLWithPath: "/tmp/photo.png"), sizeBytes: 100, modificationDate: Date())

        XCTAssertTrue(FileRuleEngine().matches(rule, candidate: candidate))
    }

    func testOlderThanDaysMatch() {
        let now = Date(timeIntervalSince1970: 1_000_000)
        let oldDate = now.addingTimeInterval(-8 * 24 * 60 * 60)
        let rule = FileRule(name: "Old", matchKind: .olderThanDays(7), action: .moveToTrash)
        let candidate = FileCandidate(url: URL(fileURLWithPath: "/tmp/old.txt"), sizeBytes: 100, modificationDate: oldDate)

        XCTAssertTrue(FileRuleEngine().matches(rule, candidate: candidate, now: now))
    }

    func testPreviewBuildsDestination() {
        let destinationID = UUID()
        let rule = FileRule(name: "Docs", matchKind: .fileExtension("pdf"), action: .moveToFolder(destinationID))
        let candidate = FileCandidate(url: URL(fileURLWithPath: "/tmp/a.pdf"), sizeBytes: 100, modificationDate: Date())

        let previews = FileRuleEngine().preview(rule: rule, candidates: [candidate]) { id in
            id == destinationID ? URL(fileURLWithPath: "/tmp/dest") : nil
        }

        XCTAssertEqual(previews.first?.destinationURL?.path, "/tmp/dest/a.pdf")
    }
}
