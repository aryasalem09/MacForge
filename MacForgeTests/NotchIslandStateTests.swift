import XCTest
@testable import MacForge

@MainActor
final class NotchIslandStateTests: XCTestCase {
    func testActivityMovesIslandToCompactState() {
        let now = Date()
        let center = NotchIslandActivityCenter(nowProvider: { now })

        center.showActivity(
            kind: .windowAction,
            title: "Window Action",
            message: "Centered",
            symbolName: "rectangle.center.inset.filled",
            duration: 4
        )

        XCTAssertEqual(center.presentationState, .compact)
        XCTAssertEqual(center.currentActivity?.kind, .windowAction)
        XCTAssertEqual(center.recentActivities.count, 1)
    }

    func testActivityAutoExpirationCollapsesCompactIsland() {
        var now = Date()
        let center = NotchIslandActivityCenter(nowProvider: { now })
        center.showActivity(
            kind: .preset,
            title: "Running Preset",
            message: "Focus",
            symbolName: "scope",
            duration: 2
        )

        now = now.addingTimeInterval(3)
        center.autoCollapseIfNeeded()

        XCTAssertNil(center.currentActivity)
        XCTAssertEqual(center.presentationState, .collapsed)
    }

    func testActivityDoesNotShrinkAnExpandedIsland() {
        let center = NotchIslandActivityCenter(presentationState: .expanded)

        center.showActivity(
            kind: .preset,
            title: "Running Preset",
            message: "Focus",
            symbolName: "scope",
            duration: 4
        )

        XCTAssertEqual(center.presentationState, .expanded)
        XCTAssertEqual(center.currentActivity?.kind, .preset)
    }

    func testCommandResultMapsFailureToErrorActivity() {
        let center = NotchIslandActivityCenter()
        let result = CommandResult.failure("Window Action", "Accessibility permission is required.")

        center.showCommandResult(result, autoCollapseDelay: 3)

        XCTAssertEqual(center.currentActivity?.kind, .error)
        XCTAssertTrue(center.currentActivity?.isError == true)
        XCTAssertEqual(center.presentationState, .compact)
    }

    func testManualExpandCollapseAndHideTransitions() {
        let center = NotchIslandActivityCenter()

        center.expand()
        XCTAssertEqual(center.presentationState, .expanded)

        center.collapse()
        XCTAssertEqual(center.presentationState, .collapsed)

        center.hide()
        XCTAssertEqual(center.presentationState, .hidden)
    }

    func testDefaultIslandConfigIsSmallAndIslandFirst() {
        let config = NotchShelfConfig.default

        XCTAssertEqual(config.preferredStyle, .island)
        XCTAssertLessThanOrEqual(config.collapsedHeight, 38)
        XCTAssertLessThanOrEqual(config.collapsedWidth, 240)
        XCTAssertGreaterThan(config.expandedWidth, config.collapsedWidth)
        XCTAssertEqual(config.configVersion, NotchShelfConfig.currentConfigVersion)
    }

    func testHoverEnterThenDelayExpandsOnce() {
        var machine = NotchHoverStateMachine()

        XCTAssertEqual(machine.pointerEntered(calibrationMode: false), [.cancelCollapse, .scheduleExpand])
        XCTAssertEqual(machine.hoverDelayElapsed(calibrationMode: false), [.expand])
        XCTAssertEqual(machine.hoverDelayElapsed(calibrationMode: false), [])
        XCTAssertEqual(machine.state, .expandedByHover)
    }

    func testHoverExitBriefReenterDoesNotCollapse() {
        var machine = NotchHoverStateMachine()
        _ = machine.pointerEntered(calibrationMode: false)
        _ = machine.hoverDelayElapsed(calibrationMode: false)

        XCTAssertEqual(machine.pointerExited(calibrationMode: false), [.scheduleCollapse])
        XCTAssertEqual(machine.pointerEntered(calibrationMode: false), [.cancelCollapse, .scheduleExpand])
        XCTAssertEqual(machine.collapseDelayElapsed(calibrationMode: false), [])
        XCTAssertEqual(machine.state, .hoverPending)
    }

    func testHoverExitForDelayCollapsesOnce() {
        var machine = NotchHoverStateMachine()
        _ = machine.pointerEntered(calibrationMode: false)
        _ = machine.hoverDelayElapsed(calibrationMode: false)
        _ = machine.pointerExited(calibrationMode: false)

        XCTAssertEqual(machine.collapseDelayElapsed(calibrationMode: false), [.collapse])
        XCTAssertEqual(machine.collapseDelayElapsed(calibrationMode: false), [])
        XCTAssertEqual(machine.state, .idle)
    }

    func testClickExpansionPersistsAcrossHoverExit() {
        var machine = NotchHoverStateMachine()

        XCTAssertEqual(machine.clickToggle(isExpanded: false, calibrationMode: false), [.cancelExpand, .cancelCollapse, .expand])
        XCTAssertEqual(machine.pointerExited(calibrationMode: false), [])
        XCTAssertEqual(machine.state, .expandedByClick)
    }

    func testResetAfterProgrammaticCollapseReenablesHoverToExpand() {
        // Reproduces the regression where a chevron/swipe/Settings collapse
        // left the machine stuck in .expandedByClick, killing hover-to-expand.
        var machine = NotchHoverStateMachine()
        _ = machine.clickToggle(isExpanded: false, calibrationMode: false) // -> .expandedByClick
        _ = machine.pointerExited(calibrationMode: false)                  // pointer leaves via chevron

        // collapseNotchIsland() resets the machine.
        XCTAssertEqual(machine.reset(), [.cancelExpand, .cancelCollapse])
        XCTAssertEqual(machine.state, .idle)

        // A later hover now schedules an expand instead of no-oping.
        XCTAssertEqual(machine.pointerEntered(calibrationMode: false), [.cancelCollapse, .scheduleExpand])
        XCTAssertEqual(machine.hoverDelayElapsed(calibrationMode: false), [.expand])
        XCTAssertEqual(machine.state, .expandedByHover)
    }

    func testHoldExpandedStaysOpenUntilExplicitCollapse() {
        // expandNotchIsland() (swipe/Settings/App Intent) holds the island open
        // like a click-expand: pointer exit must not auto-collapse it.
        var machine = NotchHoverStateMachine()

        XCTAssertEqual(machine.holdExpanded(), [.cancelExpand, .cancelCollapse])
        XCTAssertEqual(machine.state, .expandedByClick)
        XCTAssertEqual(machine.pointerExited(calibrationMode: false), [])
        XCTAssertEqual(machine.state, .expandedByClick)

        // A subsequent click collapses it.
        XCTAssertEqual(
            machine.clickToggle(isExpanded: true, calibrationMode: false),
            [.cancelExpand, .cancelCollapse, .collapse]
        )
        XCTAssertEqual(machine.state, .idle)
    }

    func testCalibrationModeDisablesHoverTransitions() {
        var machine = NotchHoverStateMachine()

        XCTAssertEqual(machine.pointerEntered(calibrationMode: true), [.cancelExpand, .cancelCollapse])
        XCTAssertEqual(machine.hoverDelayElapsed(calibrationMode: true), [])
        XCTAssertEqual(machine.state, .draggingCalibration)
        XCTAssertEqual(machine.endCalibrationDrag(), [.cancelExpand, .cancelCollapse])
        XCTAssertEqual(machine.state, .idle)
    }

    func testCalibrationPersistsEncodeDecode() throws {
        var config = NotchShelfConfig.default
        config.islandHorizontalOffset = 44
        config.islandVerticalOffset = -18
        config.calibrationModeEnabled = true

        let data = try JSONEncoder().encode(config)
        let decoded = try JSONDecoder().decode(NotchShelfConfig.self, from: data)

        XCTAssertEqual(decoded.islandHorizontalOffset, 44)
        XCTAssertEqual(decoded.islandVerticalOffset, -18)
        XCTAssertTrue(decoded.calibrationModeEnabled)
    }

    func testHardResetClearsBadVisualValues() {
        var config = NotchShelfConfig.default
        config.islandHorizontalOffset = 120
        config.islandVerticalOffset = -100
        config.forceAttachedNotchTestMode = true
        config.calibrationModeEnabled = true

        config.hardResetVisualState()

        XCTAssertEqual(config.islandHorizontalOffset, 0)
        XCTAssertEqual(config.islandVerticalOffset, 0)
        XCTAssertFalse(config.forceAttachedNotchTestMode)
        XCTAssertFalse(config.calibrationModeEnabled)
    }
}

@MainActor
final class AgentActivityCenterTests: XCTestCase {
    private func makeCenter(now: Date) -> AgentActivityCenter {
        AgentActivityCenter(
            eventsURL: URL(fileURLWithPath: "/tmp/macforge-agent-tests-\(UUID().uuidString).jsonl"),
            nowProvider: { now }
        )
    }

    func testProgressEventCreatesRunningActivity() {
        let now = Date()
        let center = makeCenter(now: now)

        center.ingest(AgentActivityEvent(id: "build", source: "Claude Code", kind: nil, title: "Building", message: "3/8", progress: 0.4, state: nil, ts: nil), now: now)

        XCTAssertEqual(center.activities.count, 1)
        XCTAssertEqual(center.primary?.state, .running)
        XCTAssertEqual(center.primary?.progress, 0.4)
        XCTAssertEqual(center.runningCount, 1)
    }

    func testSameIdUpdatesInPlaceInsteadOfDuplicating() {
        let now = Date()
        let center = makeCenter(now: now)
        center.ingest(AgentActivityEvent(id: "build", source: "Claude Code", kind: nil, title: "Building", message: "3/8", progress: 0.4, state: "running", ts: nil), now: now)
        center.ingest(AgentActivityEvent(id: "build", source: "Claude Code", kind: nil, title: "Building", message: "7/8", progress: 0.9, state: "running", ts: nil), now: now)

        XCTAssertEqual(center.activities.count, 1)
        XCTAssertEqual(center.primary?.progress, 0.9)
        XCTAssertEqual(center.primary?.message, "7/8")
    }

    func testDoneEventBecomesSuccessAndSetsNotification() {
        let now = Date()
        let center = makeCenter(now: now)
        center.ingest(AgentActivityEvent(id: "build", source: "Claude Code", kind: "done", title: "Build succeeded", message: nil, progress: nil, state: nil, ts: nil), now: now)

        XCTAssertEqual(center.primary?.state, .success)
        XCTAssertEqual(center.lastNotification?.title, "Build succeeded")
        XCTAssertEqual(center.runningCount, 0)
    }

    func testNotificationsWithoutIdDoNotOverwriteEachOther() {
        let now = Date()
        let center = makeCenter(now: now)
        center.ingest(AgentActivityEvent(id: nil, source: "Codex", kind: "notification", title: "One", message: nil, progress: nil, state: nil, ts: nil), now: now)
        center.ingest(AgentActivityEvent(id: nil, source: "Codex", kind: "notification", title: "Two", message: nil, progress: nil, state: nil, ts: nil), now: now)

        XCTAssertEqual(center.activities.count, 2)
    }

    func testClearWithIdRemovesOnlyThatTask() {
        let now = Date()
        let center = makeCenter(now: now)
        center.ingest(AgentActivityEvent(id: "a", source: "X", kind: nil, title: "A", message: nil, progress: nil, state: "running", ts: nil), now: now)
        center.ingest(AgentActivityEvent(id: "b", source: "X", kind: nil, title: "B", message: nil, progress: nil, state: "running", ts: nil), now: now)
        center.ingest(AgentActivityEvent(id: "a", source: "X", kind: "clear", title: nil, message: nil, progress: nil, state: nil, ts: nil), now: now)

        XCTAssertEqual(center.activities.map(\.id), ["b"])
    }

    func testExpireStaleDropsAbandonedRunningTasksButKeepsFreshOnes() {
        let start = Date()
        let center = makeCenter(now: start)
        center.ingest(AgentActivityEvent(id: "stuck", source: "X", kind: nil, title: "Stuck", message: nil, progress: nil, state: "running", ts: nil), now: start)

        center.expireStale(now: start.addingTimeInterval(120))
        XCTAssertTrue(center.activities.isEmpty)
    }

    func testExpireStaleLingersThenDropsFinishedTasks() {
        let start = Date()
        let center = makeCenter(now: start)
        center.ingest(AgentActivityEvent(id: "done", source: "X", kind: "done", title: "Done", message: nil, progress: nil, state: nil, ts: nil), now: start)

        center.expireStale(now: start.addingTimeInterval(3))
        XCTAssertEqual(center.activities.count, 1)

        center.expireStale(now: start.addingTimeInterval(30))
        XCTAssertTrue(center.activities.isEmpty)
    }

    func testProgressIsClampedToUnitRange() {
        let now = Date()
        let center = makeCenter(now: now)
        center.ingest(AgentActivityEvent(id: "x", source: "X", kind: nil, title: "X", message: nil, progress: 1.8, state: "running", ts: nil), now: now)
        XCTAssertEqual(center.primary?.progress, 1)
    }

    func testInstallerMergesClaudeHooksAndIsIdempotent() throws {
        let dir = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("macforge-inst-\(UUID().uuidString)")
        let settings = dir.appendingPathComponent("settings.json")
        let bin = dir.appendingPathComponent("bin")
        defer { try? FileManager.default.removeItem(at: dir) }

        // Existing settings with an unrelated hook must be preserved.
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let existing = #"{"model":"opus","hooks":{"Stop":[{"hooks":[{"type":"command","command":"/usr/bin/true"}]}]}}"#
        try existing.data(using: .utf8)!.write(to: settings)

        let first = AgentIntegrationInstaller.installClaudeCodeHooks(settingsURL: settings, binDirectory: bin)
        XCTAssertTrue(first.success, first.message)

        let data = try Data(contentsOf: settings)
        let root = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        XCTAssertEqual(root["model"] as? String, "opus", "unrelated keys preserved")
        let hooks = try XCTUnwrap(root["hooks"] as? [String: Any])
        let stop = try XCTUnwrap(hooks["Stop"] as? [[String: Any]])
        XCTAssertEqual(stop.count, 2, "existing Stop hook preserved, MacForge appended")
        XCTAssertNotNil(hooks["Notification"], "Notification hook added")
        XCTAssertTrue(FileManager.default.fileExists(atPath: settings.appendingPathExtension("macforge-backup").path))
        XCTAssertTrue(FileManager.default.isExecutableFile(atPath: bin.appendingPathComponent("macforge-claude-hook.sh").path))
        XCTAssertTrue(AgentIntegrationInstaller.isClaudeCodeConnected(settingsURL: settings))

        // Second run must not duplicate anything.
        let second = AgentIntegrationInstaller.installClaudeCodeHooks(settingsURL: settings, binDirectory: bin)
        XCTAssertTrue(second.success)
        let rereadData = try Data(contentsOf: settings)
        let reread = try XCTUnwrap(JSONSerialization.jsonObject(with: rereadData) as? [String: Any])
        let rereadHooks = try XCTUnwrap(reread["hooks"] as? [String: Any])
        XCTAssertEqual((rereadHooks["Stop"] as? [[String: Any]])?.count, 2, "idempotent")
    }

    func testInstallerRefusesInvalidClaudeSettingsJSON() throws {
        let dir = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("macforge-inst-\(UUID().uuidString)")
        let settings = dir.appendingPathComponent("settings.json")
        defer { try? FileManager.default.removeItem(at: dir) }
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        try "not json {".data(using: .utf8)!.write(to: settings)

        let result = AgentIntegrationInstaller.installClaudeCodeHooks(
            settingsURL: settings,
            binDirectory: dir.appendingPathComponent("bin")
        )
        XCTAssertFalse(result.success)
        XCTAssertEqual(try String(contentsOf: settings, encoding: .utf8), "not json {", "invalid file untouched")
    }

    func testInstallerAddsCodexNotifyButNeverClobbersCustomOne() throws {
        let dir = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("macforge-inst-\(UUID().uuidString)")
        let config = dir.appendingPathComponent("config.toml")
        let bin = dir.appendingPathComponent("bin")
        defer { try? FileManager.default.removeItem(at: dir) }
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        try "model = \"o3\"\n".data(using: .utf8)!.write(to: config)

        let first = AgentIntegrationInstaller.installCodexNotify(configURL: config, binDirectory: bin)
        XCTAssertTrue(first.success, first.message)
        let text = try String(contentsOf: config, encoding: .utf8)
        XCTAssertTrue(text.contains("model = \"o3\""), "existing config preserved")
        XCTAssertTrue(text.contains("notify = [\""), "notify added")
        XCTAssertTrue(AgentIntegrationInstaller.isCodexConnected(configURL: config))

        // A pre-existing custom notify must never be replaced.
        let custom = dir.appendingPathComponent("custom.toml")
        try "notify = [\"/my/own/notifier\"]\n".data(using: .utf8)!.write(to: custom)
        let refused = AgentIntegrationInstaller.installCodexNotify(configURL: custom, binDirectory: bin)
        XCTAssertFalse(refused.success)
        XCTAssertTrue(try String(contentsOf: custom, encoding: .utf8).contains("/my/own/notifier"))
    }

    func testPartialLineSplitAcrossWritesIsNotDropped() throws {
        let url = URL(fileURLWithPath: "/tmp/macforge-agent-partial-\(UUID().uuidString).jsonl")
        FileManager.default.createFile(atPath: url.path, contents: nil)
        defer { try? FileManager.default.removeItem(at: url) }

        let center = AgentActivityCenter(eventsURL: url)
        center.start()
        defer { center.stop() }

        let handle = try FileHandle(forWritingTo: url)
        defer { try? handle.close() }

        // Write a JSON line in two halves, reading in between so the first read
        // sees only the fragment before the newline.
        let full = #"{"id":"split","source":"CLI","title":"Half","state":"running"}"# + "\n"
        let bytes = Array(full.utf8)
        let mid = bytes.count / 2
        handle.write(Data(bytes[0..<mid]))
        center.pumpForTesting()
        XCTAssertTrue(center.activities.isEmpty, "partial line should not decode yet")

        handle.write(Data(bytes[mid...]))
        center.pumpForTesting()
        XCTAssertEqual(center.activities.first?.id, "split", "completed line should ingest")
    }
}
