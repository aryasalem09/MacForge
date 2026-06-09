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

    func testPresetRunnerExecutesActionsInOrderAndCapturesSnapshot() async {
        let first = UUID()
        let second = UUID()
        let preset = AppPreset(
            name: "Ordered",
            iconName: "sparkles",
            actions: [.openFolder(first), .runFileRule(second, dryRun: true)]
        )
        var executed: [String] = []

        let transaction = await PresetRunner().run(
            preset,
            context: PresetExecutionContext(
                runAction: { action in
                    executed.append(action.label)
                    return .success(action.label, "ok")
                },
                snapshotState: { ["Before": "yes"] },
                rollbackSnapshot: { RollbackSnapshot(notchShelfEnabled: true) }
            )
        )

        XCTAssertEqual(executed, ["Open Folder", "Preview File Rule"])
        XCTAssertEqual(transaction.oldStateSnapshot["Before"], "yes")
        XCTAssertEqual(transaction.results.map(\.title), ["Open Folder", "Preview File Rule"])
        XCTAssertTrue(transaction.rollbackAvailable)
        XCTAssertNotNil(transaction.finishedAt)
    }

    func testRollbackRestoresAllAvailableSnapshotParts() async {
        let snapshot = RollbackSnapshot(
            notchShelfEnabled: false,
            dockSettings: .default,
            wallpaperStates: [ScreenWallpaperState(id: "main", localizedName: "Main", imagePath: "/tmp/wallpaper.png")]
        )
        let transaction = PresetTransaction(
            presetName: "Everything",
            rollbackSnapshot: snapshot,
            actions: [.toggleNotchShelf(true)]
        )

        let results = await RollbackManager().rollback(
            transaction,
            context: PresetRollbackContext(
                restoreNotchShelf: { enabled in .success("Shelf", enabled ? "shown" : "hidden") },
                restoreDockSettings: { settings in [.success("Dock", settings.position.rawValue)] },
                restoreWallpapers: { states in [.success("Wallpaper", "\(states.count)")] }
            )
        )

        XCTAssertEqual(results.map(\.title), ["Shelf", "Dock", "Wallpaper"])
        XCTAssertTrue(results.allSatisfy(\.success))
    }
}

final class CommandBusTests: XCTestCase {
    override func setUp() {
        super.setUp()
        _ = MacForgeCommandBus.shared.drain()
    }

    override func tearDown() {
        _ = MacForgeCommandBus.shared.drain()
        super.tearDown()
    }

    func testCommandBusPersistsRequestsInOrderAndDrains() {
        MacForgeCommandBus.shared.enqueue(.toggleNotchShelf)
        MacForgeCommandBus.shared.enqueue(.tileFocusedWindow("leftHalf"))

        let requests = MacForgeCommandBus.shared.drain()

        XCTAssertEqual(requests.count, 2)
        XCTAssertEqual(requests.map(\.kind), [.toggleNotchShelf, .tileFocusedWindow("leftHalf")])
        XCTAssertTrue(MacForgeCommandBus.shared.drain().isEmpty)
    }
}
