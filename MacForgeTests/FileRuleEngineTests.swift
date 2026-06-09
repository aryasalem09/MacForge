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

    func testDisabledRuleNeverMatches() {
        let rule = FileRule(name: "Disabled", matchKind: .filenameContains("report"), action: .moveToTrash, isEnabled: false)
        let candidate = FileCandidate(url: URL(fileURLWithPath: "/tmp/report.txt"), sizeBytes: 100, modificationDate: Date())

        XCTAssertFalse(FileRuleEngine().matches(rule, candidate: candidate))
    }

    func testFilenameAndLargeFileMatches() {
        let namedRule = FileRule(name: "Invoices", matchKind: .filenameContains("invoice"), action: .moveToTrash)
        let largeRule = FileRule(name: "Large", matchKind: .largerThanMB(2), action: .moveToTrash)
        let candidate = FileCandidate(url: URL(fileURLWithPath: "/tmp/Invoice-June.pdf"), sizeBytes: 3 * 1_024 * 1_024, modificationDate: Date())

        XCTAssertTrue(FileRuleEngine().matches(namedRule, candidate: candidate))
        XCTAssertTrue(FileRuleEngine().matches(largeRule, candidate: candidate))
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

    func testTrashPreviewIsMarkedDestructive() {
        let rule = FileRule(name: "Trash", matchKind: .fileExtension("tmp"), action: .moveToTrash)
        let candidate = FileCandidate(url: URL(fileURLWithPath: "/tmp/cache.tmp"), sizeBytes: 100, modificationDate: Date())

        let previews = FileRuleEngine().preview(rule: rule, candidates: [candidate]) { _ in nil }

        XCTAssertEqual(previews.first?.actionDescription, "Move to Trash")
        XCTAssertEqual(previews.first?.isDestructive, true)
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

    func testDuplicateDestinationsBlockApplyWithoutMovingEitherFile() throws {
        let directory = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }

        let first = directory.appendingPathComponent("first/report.txt")
        let second = directory.appendingPathComponent("second/report.txt")
        let destination = directory.appendingPathComponent("Destination/report.txt")
        try FileManager.default.createDirectory(at: first.deletingLastPathComponent(), withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: second.deletingLastPathComponent(), withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: destination.deletingLastPathComponent(), withIntermediateDirectories: true)
        try Data("first".utf8).write(to: first)
        try Data("second".utf8).write(to: second)

        let rule = FileRule(name: "Reports", matchKind: .fileExtension("txt"), action: .moveToFolder(UUID()), dryRunOnly: false)
        let previews = [
            FileRulePreview(fileURL: first, actionDescription: "Move to Destination", destinationURL: destination, isDestructive: false),
            FileRulePreview(fileURL: second, actionDescription: "Move to Destination", destinationURL: destination, isDestructive: false)
        ]

        let results = FileOrganizerService().apply(previews: previews, rule: rule, dryRun: false)

        XCTAssertFalse(results.first?.success == true)
        XCTAssertTrue(results.first?.details.contains { $0.contains("Multiple files would write report.txt") } == true)
        XCTAssertTrue(FileManager.default.fileExists(atPath: first.path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: second.path))
        XCTAssertFalse(FileManager.default.fileExists(atPath: destination.path))
    }

    func testCopyApplyCopiesWithoutRemovingSource() throws {
        let directory = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }

        let source = directory.appendingPathComponent("note.txt")
        let destination = directory.appendingPathComponent("Destination/note.txt")
        try FileManager.default.createDirectory(at: destination.deletingLastPathComponent(), withIntermediateDirectories: true)
        try Data("hello".utf8).write(to: source)

        let rule = FileRule(name: "Copy", matchKind: .fileExtension("txt"), action: .copyToFolder(UUID()), dryRunOnly: false)
        let preview = FileRulePreview(fileURL: source, actionDescription: "Copy to Destination", destinationURL: destination, isDestructive: false)

        let results = FileOrganizerService().apply(previews: [preview], rule: rule, dryRun: false)

        XCTAssertTrue(results.first?.success == true)
        XCTAssertEqual(try String(contentsOf: source), "hello")
        XCTAssertEqual(try String(contentsOf: destination), "hello")
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

    func testHiddenFilesAreSkipped() async throws {
        let directory = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }

        try Data("same".utf8).write(to: directory.appendingPathComponent(".hidden-a"))
        try Data("same".utf8).write(to: directory.appendingPathComponent(".hidden-b"))

        let groups = await DuplicateFinder().findDuplicates(in: directory)

        XCTAssertTrue(groups.isEmpty)
    }

    private func makeTemporaryDirectory() throws -> URL {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }
}
