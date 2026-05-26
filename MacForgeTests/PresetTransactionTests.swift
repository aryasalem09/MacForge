import XCTest
@testable import MacForge

final class PresetTransactionTests: XCTestCase {
    func testRecordsResultsInOrderAndRollbackMetadata() {
        var transaction = PresetTransaction(
            presetName: "Focus",
            oldStateSnapshot: ["Notch Shelf": "disabled"],
            rollbackSnapshot: RollbackSnapshot(notchShelfEnabled: false, dockSettings: .default),
            actions: [.toggleNotchShelf(true)]
        )

        transaction.record(.success("First", "Done", reversible: true))
        transaction.record(.failure("Second", "Nope"))
        transaction.finish()

        XCTAssertEqual(transaction.results.map(\.title), ["First", "Second"])
        XCTAssertTrue(transaction.rollbackAvailable)
        XCTAssertNotNil(transaction.finishedAt)
    }

    func testMetadataOnlyTransactionDoesNotAdvertiseRollback() {
        var transaction = PresetTransaction(
            presetName: "Legacy",
            oldStateSnapshot: ["Notch Shelf": "disabled"],
            actions: [.toggleNotchShelf(true)]
        )

        transaction.record(.success("First", "Done", reversible: true))

        XCTAssertFalse(transaction.rollbackAvailable)
    }

    func testRollbackSnapshotCreatesAvailability() {
        let snapshot = RollbackSnapshot(
            notchShelfEnabled: true,
            dockSettings: DockSettings(autoHide: true, tileSize: 44, magnification: false, magnificationSize: 64, position: .left, showRecentApps: false),
            wallpaperStates: [ScreenWallpaperState(id: "Main", localizedName: "Main", imagePath: "/tmp/wallpaper.jpg")]
        )
        let transaction = PresetTransaction(
            presetName: "Focus",
            rollbackSnapshot: snapshot,
            actions: [.toggleNotchShelf(false)]
        )

        XCTAssertTrue(transaction.rollbackAvailable)
        XCTAssertEqual(transaction.rollbackSnapshot?.notchShelfEnabled, true)
        XCTAssertEqual(transaction.rollbackSnapshot?.wallpaperStates.count, 1)
    }

    func testRollbackReportsUnavailableFileRuleRollback() async {
        let ruleID = UUID()
        let transaction = PresetTransaction(
            presetName: "Files",
            rollbackSnapshot: RollbackSnapshot(notchShelfEnabled: false),
            actions: [.runFileRule(ruleID, dryRun: false)]
        )
        let context = PresetRollbackContext(
            restoreNotchShelf: { enabled in
                .success("Shelf", enabled ? "Shown" : "Hidden")
            },
            restoreDockSettings: { _ in [] },
            restoreWallpapers: { _ in [] }
        )

        let results = await RollbackManager().rollback(transaction, context: context)

        XCTAssertTrue(results.contains { $0.title == "File Rule Rollback" && !$0.success })
    }
}
