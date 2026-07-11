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

/// In-memory pasteboard stand-in for clipboard tests.
final class FakePasteboard: PasteboardReading {
    private(set) var changeCount = 0
    private(set) var typeIdentifiers: [String] = []
    private var string: String?
    private var fileURLs: [URL] = []
    private(set) var lastWritten: String?
    private(set) var lastWrittenFilePaths: [String]?
    /// Fired during readString to simulate a cross-process write racing the
    /// capture between the type check and the content read.
    var onReadString: (() -> Void)?

    func put(_ value: String, types: [String] = ["public.utf8-plain-text"]) {
        string = value
        fileURLs = []
        typeIdentifiers = types
        changeCount += 1
    }

    func putFiles(_ urls: [URL]) {
        fileURLs = urls
        string = nil
        typeIdentifiers = ["public.file-url"]
        changeCount += 1
    }

    func readString() -> String? {
        onReadString?()
        return string
    }

    func readFileURLs() -> [URL] { fileURLs }

    @discardableResult
    func write(_ value: String) -> Int {
        string = value
        fileURLs = []
        lastWritten = value
        typeIdentifiers = ["public.utf8-plain-text"]
        changeCount += 1
        return changeCount
    }

    @discardableResult
    func writeFileURLs(_ paths: [String]) -> Int {
        fileURLs = paths.map { URL(fileURLWithPath: $0) }
        string = nil
        lastWrittenFilePaths = paths
        typeIdentifiers = ["public.file-url"]
        changeCount += 1
        return changeCount
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

    func testClipboardCaptureDedupesSkipsConcealedAndCaps() {
        let fake = FakePasteboard()
        let center = ClipboardHistoryCenter(pasteboard: fake, nowProvider: { Date() })

        // Normal copy is captured.
        fake.put("hello world")
        center.captureIfChanged()
        XCTAssertEqual(center.items.map(\.text), ["hello world"])

        // Identical re-copy refreshes position instead of duplicating.
        fake.put("hello world")
        center.captureIfChanged()
        XCTAssertEqual(center.items.count, 1)

        // Concealed (password manager) content is never captured.
        fake.put("hunter2", types: ["public.utf8-plain-text", "org.nspasteboard.ConcealedType"])
        center.captureIfChanged()
        XCTAssertFalse(center.items.contains { $0.text == "hunter2" })

        // Transient content is never captured.
        fake.put("temp", types: ["public.utf8-plain-text", "org.nspasteboard.TransientType"])
        center.captureIfChanged()
        XCTAssertFalse(center.items.contains { $0.text == "temp" })

        // History caps at 24.
        for index in 0..<30 {
            fake.put("item \(index)")
            center.captureIfChanged()
        }
        XCTAssertEqual(center.items.count, 24)
        XCTAssertEqual(center.items.first?.text, "item 29")
    }

    func testClipboardRecopyDoesNotEchoBackIntoHistory() {
        let fake = FakePasteboard()
        let center = ClipboardHistoryCenter(pasteboard: fake, nowProvider: { Date() })

        fake.put("first")
        center.captureIfChanged()
        fake.put("second")
        center.captureIfChanged()
        XCTAssertEqual(center.items.map(\.text), ["second", "first"])

        // Re-copying "first" from history writes to the pasteboard but must
        // not be re-captured as a new event on the next poll.
        let first = center.items.last!
        center.copyToPasteboard(first)
        center.captureIfChanged()
        XCTAssertEqual(center.items.map(\.text), ["first", "second"])
        XCTAssertEqual(fake.lastWritten, "first")
    }

    func testClipboardPauseSkipsCaptureAndResumesCleanly() {
        let fake = FakePasteboard()
        let center = ClipboardHistoryCenter(pasteboard: fake, nowProvider: { Date() })

        center.setPaused(true)
        fake.put("while paused")
        center.captureIfChanged()
        XCTAssertTrue(center.items.isEmpty)

        center.setPaused(false)
        // The change that happened while paused is not retroactively captured…
        center.captureIfChanged()
        XCTAssertTrue(center.items.isEmpty)
        // …but new changes are.
        fake.put("after resume")
        center.captureIfChanged()
        XCTAssertEqual(center.items.map(\.text), ["after resume"])
    }

    func testClipboardFileCopyBackRestoresRealFileURLs() throws {
        let fake = FakePasteboard()
        let center = ClipboardHistoryCenter(pasteboard: fake, nowProvider: { Date() })

        // Use a real temp file so the existence check passes.
        let file = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("macforge-clip-\(UUID().uuidString).txt")
        try "x".data(using: .utf8)!.write(to: file)
        defer { try? FileManager.default.removeItem(at: file) }

        fake.putFiles([file])
        center.captureIfChanged()
        guard let item = center.items.first else { return XCTFail("file copy not captured") }
        if case .fileURLs = item.kind {} else { XCTFail("expected fileURLs kind") }

        center.copyToPasteboard(item)
        XCTAssertEqual(fake.lastWrittenFilePaths, [file.path], "real file URLs restored, not a name string")
        XCTAssertNil(fake.lastWritten, "no plain-text fallback when the file still exists")
    }

    func testClipboardRacingConcealedWriteIsDiscarded() {
        let fake = FakePasteboard()
        let center = ClipboardHistoryCenter(pasteboard: fake, nowProvider: { Date() })

        fake.put("benign")
        // Simulate a password manager writing a concealed secret between the
        // type check and the content read.
        fake.onReadString = { [weak fake] in
            fake?.onReadString = nil
            fake?.put("s3cret!", types: ["public.utf8-plain-text", "org.nspasteboard.ConcealedType"])
        }
        center.captureIfChanged()
        XCTAssertTrue(center.items.isEmpty, "capture that raced a pasteboard change must be discarded")

        // The next tick evaluates the new content against its own (concealed)
        // types and skips it.
        center.captureIfChanged()
        XCTAssertTrue(center.items.isEmpty)
    }

    func testClipboardDedupeAndRecopyRefreshTimestamps() {
        var now = Date(timeIntervalSinceReferenceDate: 1000)
        let fake = FakePasteboard()
        let center = ClipboardHistoryCenter(pasteboard: fake, nowProvider: { now })

        fake.put("hello")
        center.captureIfChanged()
        let firstStamp = center.items[0].capturedAt

        // Re-copying identical content later refreshes the timestamp.
        now = Date(timeIntervalSinceReferenceDate: 5000)
        fake.put("other")
        center.captureIfChanged()
        fake.put("hello")
        center.captureIfChanged()
        XCTAssertEqual(center.items.first?.text, "hello")
        XCTAssertGreaterThan(center.items.first!.capturedAt, firstStamp)

        // copyToPasteboard also stamps the item as just-used.
        now = Date(timeIntervalSinceReferenceDate: 9000)
        let other = center.items.last!
        center.copyToPasteboard(other)
        XCTAssertEqual(center.items.first?.text, "other")
        XCTAssertEqual(center.items.first?.capturedAt, now)
    }

    func testWeatherDecodesOpenMeteoPayloadAndMapsSymbols() {
        let center = WeatherGlanceCenter()
        center.configure(latitude: 37.77, longitude: -122.42, locationName: "San Francisco", enabled: false)

        let fixture = #"{"current":{"temperature_2m":68.4,"weather_code":61,"is_day":1}}"#
        center.apply(responseData: fixture.data(using: .utf8)!)

        XCTAssertEqual(center.current?.temperatureText, "68°")
        XCTAssertEqual(center.current?.symbolName, "cloud.rain.fill")
        XCTAssertEqual(center.current?.conditionDescription, "Rain")

        // Clear night maps to the moon variant.
        XCTAssertEqual(WeatherGlanceCenter.condition(forWMOCode: 0, isDay: false).symbolName, "moon.stars.fill")
        XCTAssertEqual(WeatherGlanceCenter.condition(forWMOCode: 95, isDay: true).symbolName, "cloud.bolt.rain.fill")
        // Unknown codes fall back to a plain cloud rather than crashing.
        XCTAssertEqual(WeatherGlanceCenter.condition(forWMOCode: 42, isDay: true).symbolName, "cloud.fill")
    }

    func testWeatherUnitFollowsLocale() {
        XCTAssertTrue(WeatherGlanceCenter.localePrefersFahrenheit(Locale(identifier: "en_US")))
        XCTAssertFalse(WeatherGlanceCenter.localePrefersFahrenheit(Locale(identifier: "de_DE")))
        XCTAssertFalse(WeatherGlanceCenter.localePrefersFahrenheit(Locale(identifier: "en_GB")))
    }

    func testAudioOutputCycleWrapsAndHandlesUnknownCurrent() {
        let devices = [
            AudioOutputDevice(id: 41, name: "MacBook Pro Speakers"),
            AudioOutputDevice(id: 55, name: "AirPods Pro"),
            AudioOutputDevice(id: 60, name: "Studio Display"),
        ]

        XCTAssertEqual(AudioOutputSwitcher.nextDevice(after: 41, in: devices)?.id, 55)
        XCTAssertEqual(AudioOutputSwitcher.nextDevice(after: 60, in: devices)?.id, 41, "wraps around")
        XCTAssertEqual(AudioOutputSwitcher.nextDevice(after: nil, in: devices)?.id, 41, "unknown current starts at first")
        XCTAssertEqual(AudioOutputSwitcher.nextDevice(after: 99, in: devices)?.id, 41, "missing current starts at first")
        XCTAssertNil(AudioOutputSwitcher.nextDevice(after: 41, in: []))
    }

    func testKeepAwakeAssertionLifecycle() {
        let controller = KeepAwakeController()
        XCTAssertFalse(controller.isActive)
        controller.setActive(true)
        XCTAssertTrue(controller.isActive)
        // Idempotent double-activation.
        controller.setActive(true)
        XCTAssertTrue(controller.isActive)
        controller.setActive(false)
        XCTAssertFalse(controller.isActive)
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
