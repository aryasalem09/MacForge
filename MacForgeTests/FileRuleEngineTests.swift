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

    func testDryRunOnlyBlocksApply() throws {
        let directory = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }

        let source = directory.appendingPathComponent("photo.png")
        let destination = directory.appendingPathComponent("Moved/photo.png")
        try FileManager.default.createDirectory(at: destination.deletingLastPathComponent(), withIntermediateDirectories: true)
        try Data("image".utf8).write(to: source)

        let rule = FileRule(name: "Images", matchKind: .fileExtension("png"), action: .moveToFolder(UUID()), dryRunOnly: true)
        let preview = FileRulePreview(fileURL: source, actionDescription: "Move to Moved", destinationURL: destination, isDestructive: false)

        let results = FileOrganizerService().apply(previews: [preview], rule: rule, dryRun: false)

        XCTAssertTrue(results.first?.success == true)
        XCTAssertTrue(FileManager.default.fileExists(atPath: source.path))
        XCTAssertFalse(FileManager.default.fileExists(atPath: destination.path))
    }

    func testMoveCollisionBlocksApplyWithoutOverwrite() throws {
        let directory = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }

        let source = directory.appendingPathComponent("report.txt")
        let destination = directory.appendingPathComponent("Destination/report.txt")
        try FileManager.default.createDirectory(at: destination.deletingLastPathComponent(), withIntermediateDirectories: true)
        try Data("source".utf8).write(to: source)
        try Data("existing".utf8).write(to: destination)

        let rule = FileRule(name: "Reports", matchKind: .fileExtension("txt"), action: .moveToFolder(UUID()), dryRunOnly: false)
        let preview = FileRulePreview(fileURL: source, actionDescription: "Move to Destination", destinationURL: destination, isDestructive: false)

        let results = FileOrganizerService().apply(previews: [preview], rule: rule, dryRun: false)

        XCTAssertFalse(results.first?.success == true)
        XCTAssertTrue(FileManager.default.fileExists(atPath: source.path))
        XCTAssertEqual(try String(contentsOf: destination), "existing")
    }

    private func makeTemporaryDirectory() throws -> URL {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }
}

final class DuplicateFinderTests: XCTestCase {
    func testIdenticalFilesAreGrouped() async throws {
        let directory = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }

        let first = directory.appendingPathComponent("one.txt")
        let second = directory.appendingPathComponent("two.txt")
        try Data("same".utf8).write(to: first)
        try Data("same".utf8).write(to: second)

        let groups = await DuplicateFinder().findDuplicates(in: directory)

        XCTAssertEqual(groups.count, 1)
        XCTAssertEqual(Set(groups[0].files.map { $0.url.lastPathComponent }), Set(["one.txt", "two.txt"]))
    }

    func testDifferentFilesAreNotGrouped() async throws {
        let directory = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }

        try Data("short".utf8).write(to: directory.appendingPathComponent("one.txt"))
        try Data("longer".utf8).write(to: directory.appendingPathComponent("two.txt"))

        let groups = await DuplicateFinder().findDuplicates(in: directory)

        XCTAssertTrue(groups.isEmpty)
    }

    func testSameSizeDifferentContentIsNotGrouped() async throws {
        let directory = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }

        try Data("abc".utf8).write(to: directory.appendingPathComponent("one.txt"))
        try Data("xyz".utf8).write(to: directory.appendingPathComponent("two.txt"))

        let groups = await DuplicateFinder().findDuplicates(in: directory)

        XCTAssertTrue(groups.isEmpty)
    }

    private func makeTemporaryDirectory() throws -> URL {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }
}
