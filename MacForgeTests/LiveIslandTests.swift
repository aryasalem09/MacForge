import XCTest
@testable import MacForge

@MainActor
final class LiveIslandTests: XCTestCase {
    func testMediaBeatsIdle() {
        let now = Date()
        let media = musicSnapshot(now: now)

        let selected = LiveIslandCoordinator.selectSnapshot(
            from: [LiveIslandSnapshot.idle(at: now), media],
            current: .idle(at: now),
            settings: .default,
            now: now,
            lastSwitchAt: now.addingTimeInterval(-10)
        )

        XCTAssertEqual(selected.kind, .music)
    }

    func testActiveTaskTemporarilyBeatsMedia() {
        let now = Date()
        let task = LiveIslandSnapshot(
            providerID: "task",
            providerName: "Task",
            kind: .task,
            priority: .task,
            title: "Bulk Rename",
            subtitle: "Renaming files",
            symbolName: "textformat",
            startedAt: now,
            expiresAt: now.addingTimeInterval(4)
        )

        let selected = LiveIslandCoordinator.selectSnapshot(
            from: [musicSnapshot(now: now), task],
            current: musicSnapshot(now: now),
            settings: .default,
            now: now,
            lastSwitchAt: now.addingTimeInterval(-10)
        )

        XCTAssertEqual(selected.kind, .task)
        XCTAssertEqual(selected.title, "Bulk Rename")
    }

    func testErrorBeatsMediaTemporarily() {
        let now = Date()
        let error = LiveIslandSnapshot(
            providerID: "error",
            providerName: "Error",
            kind: .error,
            priority: .error,
            title: "Permission Needed",
            subtitle: "Automation denied",
            symbolName: "lock.shield",
            startedAt: now,
            expiresAt: now.addingTimeInterval(4),
            isError: true
        )

        let selected = LiveIslandCoordinator.selectSnapshot(
            from: [musicSnapshot(now: now), error],
            current: musicSnapshot(now: now),
            settings: .default,
            now: now,
            lastSwitchAt: now.addingTimeInterval(-10)
        )

        XCTAssertEqual(selected.kind, .error)
        XCTAssertTrue(selected.isError)
    }

    func testMediaReturnsAfterTaskExpires() {
        let now = Date()
        let expiredTask = LiveIslandSnapshot(
            providerID: "task",
            providerName: "Task",
            kind: .task,
            priority: .task,
            title: "Preset",
            subtitle: "Done",
            symbolName: "sparkles",
            startedAt: now.addingTimeInterval(-10),
            expiresAt: now.addingTimeInterval(-1)
        )

        let selected = LiveIslandCoordinator.selectSnapshot(
            from: [musicSnapshot(now: now)],
            current: expiredTask,
            settings: .default,
            now: now,
            lastSwitchAt: now.addingTimeInterval(-10)
        )

        XCTAssertEqual(selected.kind, .music)
    }

    func testPrivacyModeRedactsMediaMetadata() {
        var settings = LiveIslandSettings.default
        settings.privacyMode = true
        let redacted = musicSnapshot(now: Date()).redacted(using: settings)

        XCTAssertEqual(redacted.title, "Music playing")
        XCTAssertEqual(redacted.subtitle, "Music")
        XCTAssertNil(redacted.artworkURL)
    }

    func testDisabledProviderIgnored() async {
        let now = Date()
        let provider = FakeProvider(
            id: "disabled",
            displayName: "Disabled",
            enabled: false,
            snapshot: musicSnapshot(now: now)
        )
        let coordinator = LiveIslandCoordinator(
            providers: [provider],
            nowProvider: { now }
        )

        await coordinator.refresh()

        XCTAssertEqual(coordinator.currentSnapshot.kind, .idle)
    }

    func testDownloadTempFilesDetected() throws {
        let folder = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: folder) }

        let download = folder.appendingPathComponent("Movie.mp4.crdownload")
        try Data("partial".utf8).write(to: download)

        let active = DownloadsProvider.activeDownload(in: folder)

        XCTAssertEqual(active?.url.lastPathComponent, "Movie.mp4.crdownload")
        XCTAssertEqual(active?.displayName, "Movie.mp4")
    }

    func testAppleMusicParserWithMockScriptOutput() {
        let now = Date()
        let output = [
            "playing",
            "Song",
            "Artist",
            "Album",
            "30",
            "120"
        ].joined(separator: AutomationMediaParser.delimiter)

        let snapshot = AutomationMediaParser.parseMusicLikeOutput(
            output,
            providerID: AppleMusicProvider.providerID,
            providerName: "Apple Music",
            kind: .music,
            appName: "Music",
            bundleIdentifier: "com.apple.Music",
            symbolName: "music.note",
            now: now
        )

        XCTAssertEqual(snapshot?.title, "Song")
        XCTAssertEqual(snapshot?.subtitle, "Artist - Album")
        XCTAssertEqual(snapshot?.playbackState, .playing)
        XCTAssertEqual(snapshot?.progress, 0.25)
    }

    func testAppleMusicParserWithPausedTrackAndMissingAlbumArtist() {
        let now = Date()
        let output = [
            "paused",
            "Quiet Track",
            "",
            "",
            "12",
            "60"
        ].joined(separator: AutomationMediaParser.delimiter)

        let snapshot = AutomationMediaParser.parseMusicLikeOutput(
            output,
            providerID: AppleMusicProvider.providerID,
            providerName: "Apple Music",
            kind: .music,
            appName: "Music",
            bundleIdentifier: "com.apple.Music",
            symbolName: "music.note",
            now: now
        )

        XCTAssertEqual(snapshot?.title, "Quiet Track")
        XCTAssertEqual(snapshot?.subtitle, "")
        XCTAssertEqual(snapshot?.playbackState, .paused)
        XCTAssertNotNil(snapshot?.expiresAt)
    }

    func testAppleMusicParserIgnoresMissingCurrentTrack() {
        let now = Date()
        let output = [
            "playing",
            "",
            "",
            "",
            "0",
            "0"
        ].joined(separator: AutomationMediaParser.delimiter)

        let snapshot = AutomationMediaParser.parseMusicLikeOutput(
            output,
            providerID: AppleMusicProvider.providerID,
            providerName: "Apple Music",
            kind: .music,
            appName: "Music",
            bundleIdentifier: "com.apple.Music",
            symbolName: "music.note",
            now: now
        )

        XCTAssertNil(snapshot)
    }

    func testAppleScriptPermissionErrorDetected() {
        let error = AppleScriptExecutionError(message: "Not authorized to send Apple events to Music.", code: -1743)

        XCTAssertTrue(error.isPermissionError)
    }

    func testSpotifyParserWithMockScriptOutput() {
        let now = Date()
        let output = [
            "paused",
            "Track",
            "Artist",
            "Record",
            "12.5",
            "250000"
        ].joined(separator: AutomationMediaParser.delimiter)

        let snapshot = AutomationMediaParser.parseMusicLikeOutput(
            output,
            providerID: SpotifyProvider.providerID,
            providerName: "Spotify",
            kind: .music,
            appName: "Spotify",
            bundleIdentifier: "com.spotify.client",
            symbolName: "music.note.list",
            durationDivisor: 1000,
            now: now
        )

        XCTAssertEqual(snapshot?.title, "Track")
        XCTAssertEqual(snapshot?.duration, 250)
        XCTAssertEqual(snapshot?.playbackState, .paused)
        XCTAssertEqual(snapshot?.progress, 0.05)
    }

    func testBrowserBridgeMessageParser() throws {
        let now = Date()
        let data = Data("""
        {
          "title": "Video Title",
          "artist": "Channel",
          "album": null,
          "playbackState": "playing",
          "duration": 300,
          "position": 45,
          "artworkURL": "https://example.com/art.png",
          "sourceURL": "https://example.com/watch",
          "browserName": "Chrome",
          "tabTitle": "Video Title - Site"
        }
        """.utf8)

        let result = BrowserBridgeMessageParser().receiveBrowserBridgeMessage(data, now: now)
        guard case .success(let snapshot) = result else {
            return XCTFail("Expected bridge message to parse")
        }

        XCTAssertEqual(snapshot.kind, .browserMedia)
        XCTAssertEqual(snapshot.title, "Video Title")
        XCTAssertEqual(snapshot.playbackState, .playing)
        XCTAssertEqual(snapshot.progress, 0.15)
    }

    func testSettingsEncodeDecode() throws {
        var settings = LiveIslandSettings.default
        settings.privacyMode = true
        settings.browserMediaHintsEnabled = true
        settings.downloadsFolderBookmark = Data([1, 2, 3])
        settings.downloadsFolderName = "Downloads"

        let data = try JSONEncoder.macForge.encode(settings)
        let decoded = try JSONDecoder.macForge.decode(LiveIslandSettings.self, from: data)

        XCTAssertEqual(decoded, settings)
    }

    func testLiveIslandSettingsDefaultsEnableMusicButNotDownloads() {
        let settings = LiveIslandSettings.default

        XCTAssertTrue(settings.enableLiveIslandSources)
        XCTAssertTrue(settings.appleMusicEnabled)
        XCTAssertTrue(settings.keepMediaVisibleWhilePlaying)
        XCTAssertFalse(settings.downloadsWatcherEnabled)
    }

    func testLiveIslandSettingsDecodeUsesMediaEnabledDefaultsForMissingFields() throws {
        let data = Data(#"{"privacyMode":true}"#.utf8)

        let decoded = try JSONDecoder.macForge.decode(LiveIslandSettings.self, from: data)

        XCTAssertTrue(decoded.enableLiveIslandSources)
        XCTAssertTrue(decoded.appleMusicEnabled)
        XCTAssertTrue(decoded.keepMediaVisibleWhilePlaying)
        XCTAssertTrue(decoded.privacyMode)
    }

    func testFakeSelfTestSnapshotBecomesPrimary() async {
        let now = Date()
        let coordinator = LiveIslandCoordinator(nowProvider: { now })

        coordinator.showTestSnapshot(kind: .music)
        await coordinator.refresh()

        XCTAssertEqual(coordinator.currentSnapshot.providerID, "test")
        XCTAssertEqual(coordinator.currentSnapshot.kind, .music)
    }

    func testClassicShelfStillAvailable() throws {
        var config = NotchShelfConfig.default
        config.preferredStyle = .classicShelf

        let data = try JSONEncoder.macForge.encode(config)
        let decoded = try JSONDecoder.macForge.decode(NotchShelfConfig.self, from: data)

        XCTAssertEqual(decoded.preferredStyle, .classicShelf)
    }

    private func musicSnapshot(now: Date) -> LiveIslandSnapshot {
        LiveIslandSnapshot(
            providerID: "music",
            providerName: "Music",
            kind: .music,
            priority: .media,
            title: "Song",
            subtitle: "Artist",
            appName: "Music",
            symbolName: "music.note",
            playbackState: .playing,
            elapsedTime: 10,
            duration: 100,
            artworkURL: URL(string: "https://example.com/art.png"),
            startedAt: now
        )
    }
}

private struct FakeProvider: LiveIslandProvider {
    var id: String
    var displayName: String
    var enabled: Bool
    var snapshot: LiveIslandSnapshot?

    func isEnabled(settings: LiveIslandSettings) -> Bool {
        enabled
    }

    func snapshot(settings: LiveIslandSettings, now: Date) async -> LiveIslandSnapshot? {
        snapshot
    }
}
