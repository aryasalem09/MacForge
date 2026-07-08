import AppKit
import Foundation

@MainActor
protocol LiveIslandProvider {
    var id: String { get }
    var displayName: String { get }
    var latestDiagnostic: LiveIslandProviderDiagnostic? { get }

    func isEnabled(settings: LiveIslandSettings) -> Bool
    func snapshot(settings: LiveIslandSettings, now: Date) async -> LiveIslandSnapshot?
    func perform(action: LiveIslandActionKind) async -> CommandResult
    func seek(to seconds: TimeInterval) async -> CommandResult
}

extension LiveIslandProvider {
    var latestDiagnostic: LiveIslandProviderDiagnostic? { nil }

    func perform(action: LiveIslandActionKind) async -> CommandResult {
        .failure(displayName, "\(action.title) is not available for this source.")
    }

    func seek(to seconds: TimeInterval) async -> CommandResult {
        .failure(displayName, "Seeking is not available for this source.")
    }
}

struct LiveIslandProviderDiagnostic: Identifiable, Codable, Hashable {
    var id: String
    var providerName: String
    var isEnabled: Bool
    var status: String
    var appStatus: String
    var lastPollAt: Date?
    var lastSuccessAt: Date?
    var lastError: String?
    var rawResultSummary: String?
    var permissionNeeded: Bool
    var snapshotTitle: String?
    var snapshotSubtitle: String?
    var updatedAt: Date

    init(
        id: String,
        providerName: String,
        isEnabled: Bool = true,
        status: String,
        appStatus: String = "Unknown",
        lastPollAt: Date? = nil,
        lastSuccessAt: Date? = nil,
        lastError: String? = nil,
        rawResultSummary: String? = nil,
        permissionNeeded: Bool = false,
        snapshotTitle: String? = nil,
        snapshotSubtitle: String? = nil,
        updatedAt: Date
    ) {
        self.id = id
        self.providerName = providerName
        self.isEnabled = isEnabled
        self.status = status
        self.appStatus = appStatus
        self.lastPollAt = lastPollAt
        self.lastSuccessAt = lastSuccessAt
        self.lastError = lastError
        self.rawResultSummary = rawResultSummary
        self.permissionNeeded = permissionNeeded
        self.snapshotTitle = snapshotTitle
        self.snapshotSubtitle = snapshotSubtitle
        self.updatedAt = updatedAt
    }
}

struct AppleScriptExecutionError: Error, Equatable {
    var message: String
    var code: Int?

    var isPermissionError: Bool {
        code == -1743 || message.localizedCaseInsensitiveContains("not authorized")
    }
}

protocol AppleScriptRunning {
    func run(source: String) -> Result<String, AppleScriptExecutionError>
}

/// All Apple events go through one serial queue so a slow target app or a
/// pending Automation consent dialog can never stall the main thread — the
/// island's hover and spring animations keep running while a poll is stuck.
private let appleScriptQueue = DispatchQueue(label: "com.aryasalem.MacForge.applescript", qos: .userInitiated)

extension AppleScriptRunning {
    func runOffMain(source: String) async -> Result<String, AppleScriptExecutionError> {
        await withCheckedContinuation { continuation in
            appleScriptQueue.async {
                continuation.resume(returning: run(source: source))
            }
        }
    }
}

struct DefaultAppleScriptRunner: AppleScriptRunning {
    func run(source: String) -> Result<String, AppleScriptExecutionError> {
        guard let script = NSAppleScript(source: source) else {
            return .failure(AppleScriptExecutionError(message: "The automation script could not be compiled.", code: nil))
        }

        var errorInfo: NSDictionary?
        let descriptor = script.executeAndReturnError(&errorInfo)
        if let errorInfo {
            let message = errorInfo[NSAppleScript.errorMessage] as? String ?? "Automation failed."
            let code = errorInfo[NSAppleScript.errorNumber] as? Int
            return .failure(AppleScriptExecutionError(message: message, code: code))
        }

        return .success(descriptor.stringValue ?? descriptor.description)
    }
}

enum AutomationMediaParser {
    static let delimiter = "||MF||"

    static func parseMusicLikeOutput(
        _ output: String,
        providerID: String,
        providerName: String,
        kind: LiveIslandSnapshotKind,
        appName: String,
        bundleIdentifier: String,
        symbolName: String,
        durationDivisor: Double = 1,
        now: Date
    ) -> LiveIslandSnapshot? {
        let parts = output.components(separatedBy: delimiter)
        guard parts.count >= 6 else { return nil }

        let playbackState = playbackState(from: parts[0])
        guard playbackState != .stopped else { return nil }

        let title = clean(parts[1])
        guard !title.isEmpty else { return nil }

        let artist = clean(parts[2])
        let album = clean(parts[3])
        let elapsed = TimeInterval(clean(parts[4])) ?? 0
        let rawDuration = TimeInterval(clean(parts[5])) ?? 0
        let duration = durationDivisor == 0 ? rawDuration : rawDuration / durationDivisor
        let subtitle = [artist, album].filter { !$0.isEmpty }.joined(separator: " - ")
        // Optional 7th field: an artwork URL (Spotify exposes one directly).
        let artworkURL: URL? = parts.count >= 7 ? URL(string: clean(parts[6])) : nil

        return LiveIslandSnapshot(
            providerID: providerID,
            providerName: providerName,
            kind: kind,
            priority: .media,
            title: title.isEmpty ? "\(appName) media" : title,
            subtitle: subtitle,
            appName: appName,
            bundleIdentifier: bundleIdentifier,
            symbolName: symbolName,
            playbackState: playbackState,
            elapsedTime: elapsed,
            duration: duration > 0 ? duration : nil,
            artworkURL: artworkURL?.scheme?.hasPrefix("http") == true ? artworkURL : nil,
            startedAt: now,
            expiresAt: playbackState == .playing ? nil : now.addingTimeInterval(12),
            actions: [
                LiveIslandAction(.previous),
                LiveIslandAction(.playPause),
                LiveIslandAction(.next),
                LiveIslandAction(.openSource)
            ],
            supportsScrubbing: duration > 0
        )
    }

    static func parseQuickTimeOutput(_ output: String, now: Date) -> LiveIslandSnapshot? {
        let parts = output.components(separatedBy: delimiter)
        guard parts.count >= 4 else { return nil }

        let playbackState = playbackState(from: parts[0])
        guard playbackState != .stopped else { return nil }

        let title = clean(parts[1])
        let elapsed = TimeInterval(clean(parts[2])) ?? 0
        let duration = TimeInterval(clean(parts[3])) ?? 0

        return LiveIslandSnapshot(
            providerID: QuickTimeProvider.providerID,
            providerName: "QuickTime",
            kind: .video,
            priority: .media,
            title: title.isEmpty ? "Video active" : title,
            subtitle: playbackState == .playing ? "Playing in QuickTime" : "Paused in QuickTime",
            appName: "QuickTime Player",
            bundleIdentifier: "com.apple.QuickTimePlayerX",
            symbolName: "play.rectangle",
            playbackState: playbackState,
            elapsedTime: elapsed,
            duration: duration > 0 ? duration : nil,
            startedAt: now,
            expiresAt: playbackState == .playing ? nil : now.addingTimeInterval(12),
            actions: [
                LiveIslandAction(.playPause),
                LiveIslandAction(.openSource)
            ],
            supportsScrubbing: duration > 0
        )
    }

    static func playbackState(from rawValue: String) -> LiveIslandPlaybackState {
        let value = clean(rawValue).lowercased()
        if value.contains("playing") || value == "true" {
            return .playing
        }
        if value.contains("paused") || value == "false" {
            return .paused
        }
        if value.contains("stopped") {
            return .stopped
        }
        return .unknown
    }

    private static func clean(_ value: String) -> String {
        value.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

final class AppleMusicProvider: LiveIslandProvider {
    nonisolated static let providerID = "apple-music"

    let id = AppleMusicProvider.providerID
    let displayName = "Apple Music"
    private(set) var latestDiagnostic: LiveIslandProviderDiagnostic?

    private let runner: AppleScriptRunning
    private var reportedPermissionError = false

    init(runner: AppleScriptRunning = DefaultAppleScriptRunner()) {
        self.runner = runner
    }

    func isEnabled(settings: LiveIslandSettings) -> Bool {
        settings.enableLiveIslandSources && settings.appleMusicEnabled
    }

    func snapshot(settings: LiveIslandSettings, now: Date) async -> LiveIslandSnapshot? {
        guard Self.isRunning else {
            latestDiagnostic = diagnostic(
                status: "Unavailable",
                appStatus: "Music is not running",
                lastPollAt: now,
                updatedAt: now
            )
            return nil
        }

        switch await runner.runOffMain(source: Self.snapshotScript) {
        case .success(let output):
            let snapshot = AutomationMediaParser.parseMusicLikeOutput(
                output,
                providerID: id,
                providerName: displayName,
                kind: .music,
                appName: "Music",
                bundleIdentifier: "com.apple.Music",
                symbolName: "music.note",
                now: now
            )
            latestDiagnostic = diagnostic(
                status: snapshot == nil ? "Unavailable" : "Active",
                appStatus: "Music is running",
                lastPollAt: now,
                lastSuccessAt: snapshot == nil ? nil : now,
                lastError: snapshot == nil ? "Music did not report a playable current track." : nil,
                rawResultSummary: Self.rawSummary(output, privacyMode: settings.privacyMode),
                permissionNeeded: false,
                snapshot: snapshot,
                updatedAt: now
            )
            reportedPermissionError = false
            return snapshot
        case .failure(let error):
            let permissionNeeded = error.isPermissionError
            latestDiagnostic = diagnostic(
                status: permissionNeeded ? "Needs Automation Permission" : "AppleScript Error",
                appStatus: "Music is running",
                lastPollAt: now,
                lastError: error.message,
                permissionNeeded: permissionNeeded,
                updatedAt: now
            )
            // Show the consent card once per launch instead of letting a
            // priority-100 error occupy the island until the user acts; the
            // sticky diagnostic and Permissions page keep the state visible.
            guard permissionNeeded, !reportedPermissionError else { return nil }
            reportedPermissionError = true
            return automationPermissionSnapshot(now: now, appName: "Music", bundleIdentifier: "com.apple.Music")
        }
    }

    func seek(to seconds: TimeInterval) async -> CommandResult {
        let script = "tell application \"Music\" to set player position to \(Int(seconds.rounded()))"
        return automationResult(await runner.runOffMain(source: script), title: "Apple Music", successMessage: "Jumped to \(Int(seconds.rounded()))s.")
    }

    func perform(action: LiveIslandActionKind) async -> CommandResult {
        let script: String
        switch action {
        case .playPause:
            script = #"tell application "Music" to playpause"#
        case .next:
            script = #"tell application "Music" to next track"#
        case .previous:
            script = #"tell application "Music" to previous track"#
        case .openSource:
            NSWorkspace.shared.runningApplications.first { $0.bundleIdentifier == "com.apple.Music" }?.activate(options: [])
            return .success("Apple Music", "Opened Music.")
        case .cancelTimer:
            return .failure("Apple Music", "Cancel timer is not available for Music.")
        }

        return automationResult(await runner.runOffMain(source: script), title: "Apple Music", successMessage: "\(action.title) sent to Music.")
    }

    private func automationPermissionSnapshot(now: Date, appName: String, bundleIdentifier: String) -> LiveIslandSnapshot {
        LiveIslandSnapshot(
            providerID: id,
            providerName: displayName,
            kind: .error,
            priority: .error,
            title: "Music permission needed",
            subtitle: "Allow MacForge to control Music in System Settings.",
            appName: appName,
            bundleIdentifier: bundleIdentifier,
            symbolName: "lock.shield",
            startedAt: now,
            expiresAt: now.addingTimeInterval(8),
            isError: true,
            actions: [LiveIslandAction(.openSource)]
        )
    }

    private static var isRunning: Bool {
        NSWorkspace.shared.runningApplications.contains { $0.bundleIdentifier == "com.apple.Music" }
    }

    private func diagnostic(
        status: String,
        appStatus: String,
        lastPollAt: Date?,
        lastSuccessAt: Date? = nil,
        lastError: String? = nil,
        rawResultSummary: String? = nil,
        permissionNeeded: Bool = false,
        snapshot: LiveIslandSnapshot? = nil,
        updatedAt: Date
    ) -> LiveIslandProviderDiagnostic {
        LiveIslandProviderDiagnostic(
            id: id,
            providerName: displayName,
            isEnabled: true,
            status: status,
            appStatus: appStatus,
            lastPollAt: lastPollAt,
            lastSuccessAt: lastSuccessAt,
            lastError: lastError,
            rawResultSummary: rawResultSummary,
            permissionNeeded: permissionNeeded,
            snapshotTitle: snapshot?.title,
            snapshotSubtitle: snapshot?.subtitle,
            updatedAt: updatedAt
        )
    }

    private static func rawSummary(_ output: String, privacyMode: Bool) -> String {
        guard !privacyMode else {
            return "Music returned media metadata."
        }

        let normalized = output.replacingOccurrences(of: AutomationMediaParser.delimiter, with: " | ")
        if normalized.count <= 180 {
            return normalized
        }
        return String(normalized.prefix(177)) + "..."
    }

    private static let snapshotScript = """
    set delimiter to "\(AutomationMediaParser.delimiter)"
    tell application "Music"
        set playerState to (player state as string)
        if playerState is "stopped" then
            return "stopped" & delimiter & "" & delimiter & "" & delimiter & "" & delimiter & "0" & delimiter & "0"
        end if
        set trackName to ""
        set artistName to ""
        set albumName to ""
        set trackDuration to 0
        try
            set currentTrack to current track
            set trackName to name of currentTrack
            try
                set artistName to artist of currentTrack
            end try
            try
                set albumName to album of currentTrack
            end try
            try
                set trackDuration to duration of currentTrack
            end try
        on error
            return "stopped" & delimiter & "" & delimiter & "" & delimiter & "" & delimiter & "0" & delimiter & "0"
        end try
        set trackPosition to player position
        return playerState & delimiter & trackName & delimiter & artistName & delimiter & albumName & delimiter & (trackPosition as text) & delimiter & (trackDuration as text)
    end tell
    """
}

final class SpotifyProvider: LiveIslandProvider {
    nonisolated static let providerID = "spotify"

    let id = SpotifyProvider.providerID
    let displayName = "Spotify"

    private let runner: AppleScriptRunning
    private var reportedPermissionError = false

    init(runner: AppleScriptRunning = DefaultAppleScriptRunner()) {
        self.runner = runner
    }

    func isEnabled(settings: LiveIslandSettings) -> Bool {
        settings.enableLiveIslandSources && settings.spotifyEnabled
    }

    func snapshot(settings: LiveIslandSettings, now: Date) async -> LiveIslandSnapshot? {
        guard Self.isRunning else { return nil }

        switch await runner.runOffMain(source: Self.snapshotScript) {
        case .success(let output):
            reportedPermissionError = false
            return AutomationMediaParser.parseMusicLikeOutput(
                output,
                providerID: id,
                providerName: displayName,
                kind: .music,
                appName: "Spotify",
                bundleIdentifier: "com.spotify.client",
                symbolName: "music.note.list",
                durationDivisor: 1000,
                now: now
            )
        case .failure(let error):
            guard error.isPermissionError, !reportedPermissionError else { return nil }
            reportedPermissionError = true
            return LiveIslandSnapshot(
                providerID: id,
                providerName: displayName,
                kind: .error,
                priority: .error,
                title: "Spotify permission needed",
                subtitle: "Allow MacForge to control Spotify in System Settings.",
                appName: "Spotify",
                bundleIdentifier: "com.spotify.client",
                symbolName: "lock.shield",
                startedAt: now,
                expiresAt: now.addingTimeInterval(8),
                isError: true,
                actions: [LiveIslandAction(.openSource)]
            )
        }
    }

    func perform(action: LiveIslandActionKind) async -> CommandResult {
        let script: String
        switch action {
        case .playPause:
            script = #"tell application "Spotify" to playpause"#
        case .next:
            script = #"tell application "Spotify" to next track"#
        case .previous:
            script = #"tell application "Spotify" to previous track"#
        case .openSource:
            NSWorkspace.shared.runningApplications.first { $0.bundleIdentifier == "com.spotify.client" }?.activate(options: [])
            return .success("Spotify", "Opened Spotify.")
        case .cancelTimer:
            return .failure("Spotify", "Cancel timer is not available for Spotify.")
        }

        return automationResult(await runner.runOffMain(source: script), title: "Spotify", successMessage: "\(action.title) sent to Spotify.")
    }

    func seek(to seconds: TimeInterval) async -> CommandResult {
        let script = "tell application \"Spotify\" to set player position to \(Int(seconds.rounded()))"
        return automationResult(await runner.runOffMain(source: script), title: "Spotify", successMessage: "Jumped to \(Int(seconds.rounded()))s.")
    }

    private static var isRunning: Bool {
        NSWorkspace.shared.runningApplications.contains { $0.bundleIdentifier == "com.spotify.client" }
    }

    private static let snapshotScript = """
    set delimiter to "\(AutomationMediaParser.delimiter)"
    tell application "Spotify"
        set playerState to (player state as string)
        if playerState is "stopped" then
            return "stopped" & delimiter & "" & delimiter & "" & delimiter & "" & delimiter & "0" & delimiter & "0"
        end if
        set currentTrackInfo to current track
        set trackName to name of currentTrackInfo
        set artistName to artist of currentTrackInfo
        set albumName to album of currentTrackInfo
        set trackPosition to player position
        set trackDuration to duration of currentTrackInfo
        set artworkAddress to ""
        try
            set artworkAddress to artwork url of currentTrackInfo
        end try
        return playerState & delimiter & trackName & delimiter & artistName & delimiter & albumName & delimiter & (trackPosition as text) & delimiter & (trackDuration as text) & delimiter & artworkAddress
    end tell
    """
}

final class QuickTimeProvider: LiveIslandProvider {
    nonisolated static let providerID = "quicktime"

    let id = QuickTimeProvider.providerID
    let displayName = "QuickTime"

    private let runner: AppleScriptRunning
    private var reportedPermissionError = false

    init(runner: AppleScriptRunning = DefaultAppleScriptRunner()) {
        self.runner = runner
    }

    func isEnabled(settings: LiveIslandSettings) -> Bool {
        settings.enableLiveIslandSources && settings.quickTimeEnabled
    }

    func snapshot(settings: LiveIslandSettings, now: Date) async -> LiveIslandSnapshot? {
        guard Self.isRunning else { return nil }

        switch await runner.runOffMain(source: Self.snapshotScript) {
        case .success(let output):
            reportedPermissionError = false
            return AutomationMediaParser.parseQuickTimeOutput(output, now: now)
        case .failure(let error):
            guard error.isPermissionError, !reportedPermissionError else { return nil }
            reportedPermissionError = true
            return LiveIslandSnapshot(
                providerID: id,
                providerName: displayName,
                kind: .error,
                priority: .error,
                title: "QuickTime permission needed",
                subtitle: "Allow MacForge to read QuickTime playback state.",
                appName: "QuickTime Player",
                bundleIdentifier: "com.apple.QuickTimePlayerX",
                symbolName: "lock.shield",
                startedAt: now,
                expiresAt: now.addingTimeInterval(8),
                isError: true
            )
        }
    }

    func perform(action: LiveIslandActionKind) async -> CommandResult {
        let script: String
        switch action {
        case .playPause:
            script = """
            tell application "QuickTime Player"
                if (count of documents) is greater than 0 then
                    if playing of document 1 then
                        pause document 1
                    else
                        play document 1
                    end if
                end if
            end tell
            """
        case .openSource:
            NSWorkspace.shared.runningApplications.first { $0.bundleIdentifier == "com.apple.QuickTimePlayerX" }?.activate(options: [])
            return .success("QuickTime", "Opened QuickTime Player.")
        default:
            return .failure("QuickTime", "\(action.title) is not available for QuickTime.")
        }

        return automationResult(await runner.runOffMain(source: script), title: "QuickTime", successMessage: "\(action.title) sent to QuickTime.")
    }

    func seek(to seconds: TimeInterval) async -> CommandResult {
        let script = """
        tell application "QuickTime Player"
            if (count of documents) is greater than 0 then
                set current time of document 1 to \(Int(seconds.rounded()))
            end if
        end tell
        """
        return automationResult(await runner.runOffMain(source: script), title: "QuickTime", successMessage: "Jumped to \(Int(seconds.rounded()))s.")
    }

    private static var isRunning: Bool {
        NSWorkspace.shared.runningApplications.contains { $0.bundleIdentifier == "com.apple.QuickTimePlayerX" }
    }

    private static let snapshotScript = """
    set delimiter to "\(AutomationMediaParser.delimiter)"
    tell application "QuickTime Player"
        if (count of documents) is 0 then
            return "stopped" & delimiter & "" & delimiter & "0" & delimiter & "0"
        end if
        set frontDocument to document 1
        set playbackState to "paused"
        if playing of frontDocument then set playbackState to "playing"
        set docName to name of frontDocument
        set docPosition to current time of frontDocument
        set docDuration to duration of frontDocument
        return playbackState & delimiter & docName & delimiter & (docPosition as text) & delimiter & (docDuration as text)
    end tell
    """
}

struct BrowserBridgeMediaMessage: Codable, Equatable {
    var title: String?
    var artist: String?
    var album: String?
    var playbackState: LiveIslandPlaybackState
    var duration: TimeInterval?
    var position: TimeInterval?
    var artworkURL: URL?
    var sourceURL: URL?
    var browserName: String?
    var tabTitle: String?

    func snapshot(now: Date) -> LiveIslandSnapshot {
        let visibleTitle = title ?? tabTitle ?? "Browser media"
        let subtitle = [artist, album].compactMap { value in
            guard let value, !value.isEmpty else { return nil }
            return value
        }.joined(separator: " - ")

        return LiveIslandSnapshot(
            providerID: BrowserMediaProvider.providerID,
            providerName: "Browser Bridge",
            kind: .browserMedia,
            priority: .media,
            title: visibleTitle,
            subtitle: subtitle.isEmpty ? (browserName ?? "Browser") : subtitle,
            appName: browserName,
            symbolName: "safari",
            playbackState: playbackState,
            elapsedTime: position,
            duration: duration,
            artworkURL: artworkURL,
            sourceURL: sourceURL,
            startedAt: now,
            expiresAt: playbackState == .playing ? nil : now.addingTimeInterval(12),
            actions: [LiveIslandAction(.openSource)]
        )
    }
}

protocol BrowserBridgeReceiving {
    func receiveBrowserBridgeMessage(_ data: Data, now: Date) -> Result<LiveIslandSnapshot, Error>
}

struct BrowserBridgeMessageParser: BrowserBridgeReceiving {
    func receiveBrowserBridgeMessage(_ data: Data, now: Date) -> Result<LiveIslandSnapshot, Error> {
        do {
            let decoder = JSONDecoder()
            let message = try decoder.decode(BrowserBridgeMediaMessage.self, from: data)
            return .success(message.snapshot(now: now))
        } catch {
            return .failure(error)
        }
    }
}

final class BrowserMediaProvider: LiveIslandProvider {
    nonisolated static let providerID = "browser-media"

    let id = BrowserMediaProvider.providerID
    let displayName = "Browser Media"

    private let runner: AppleScriptRunning

    init(runner: AppleScriptRunning = DefaultAppleScriptRunner()) {
        self.runner = runner
    }

    func isEnabled(settings: LiveIslandSettings) -> Bool {
        settings.enableLiveIslandSources && settings.browserMediaHintsEnabled
    }

    func snapshot(settings: LiveIslandSettings, now: Date) async -> LiveIslandSnapshot? {
        for target in BrowserAutomationTarget.allCases where target.isRunning {
            switch await runner.runOffMain(source: target.snapshotScript) {
            case .success(let output):
                if let hint = BrowserTabHint.parse(output, target: target),
                   hint.looksLikeMedia {
                    return hint.snapshot(now: now)
                }
            case .failure(let error):
                guard error.isPermissionError else { continue }
                return LiveIslandSnapshot(
                    providerID: id,
                    providerName: displayName,
                    kind: .error,
                    priority: .error,
                    title: "\(target.displayName) permission needed",
                    subtitle: "Browser hints use only active tab title and URL after Automation consent.",
                    appName: target.displayName,
                    bundleIdentifier: target.bundleIdentifier,
                    symbolName: "lock.shield",
                    startedAt: now,
                    expiresAt: now.addingTimeInterval(8),
                    isError: true
                )
            }
        }

        return nil
    }

    func perform(action: LiveIslandActionKind) async -> CommandResult {
        guard action == .openSource else {
            return .failure("Browser Media", "\(action.title) is not available for browser hints.")
        }

        for target in BrowserAutomationTarget.allCases where target.isRunning {
            NSWorkspace.shared.runningApplications.first { $0.bundleIdentifier == target.bundleIdentifier }?.activate(options: [])
            return .success("Browser Media", "Opened \(target.displayName).")
        }

        return .failure("Browser Media", "No supported browser is running.")
    }
}

enum BrowserAutomationTarget: CaseIterable {
    case safari
    case chrome
    case brave
    case edge

    var displayName: String {
        switch self {
        case .safari: "Safari"
        case .chrome: "Chrome"
        case .brave: "Brave"
        case .edge: "Microsoft Edge"
        }
    }

    var bundleIdentifier: String {
        switch self {
        case .safari: "com.apple.Safari"
        case .chrome: "com.google.Chrome"
        case .brave: "com.brave.Browser"
        case .edge: "com.microsoft.edgemac"
        }
    }

    var isRunning: Bool {
        NSWorkspace.shared.runningApplications.contains { $0.bundleIdentifier == bundleIdentifier }
    }

    var snapshotScript: String {
        let delimiter = AutomationMediaParser.delimiter
        switch self {
        case .safari:
            return """
            set delimiter to "\(delimiter)"
            tell application "Safari"
                if not (exists front document) then return ""
                return (name of front document) & delimiter & (URL of front document)
            end tell
            """
        case .chrome, .brave, .edge:
            return """
            set delimiter to "\(delimiter)"
            tell application "\(displayName)"
                if not (exists front window) then return ""
                set activeTab to active tab of front window
                return (title of activeTab) & delimiter & (URL of activeTab)
            end tell
            """
        }
    }
}

struct BrowserTabHint: Equatable {
    var title: String
    var url: URL?
    var target: BrowserAutomationTarget

    static func parse(_ output: String, target: BrowserAutomationTarget) -> BrowserTabHint? {
        let parts = output.components(separatedBy: AutomationMediaParser.delimiter)
        guard parts.count >= 2 else { return nil }
        let title = parts[0].trimmingCharacters(in: .whitespacesAndNewlines)
        let url = URL(string: parts[1].trimmingCharacters(in: .whitespacesAndNewlines))
        guard !title.isEmpty || url != nil else { return nil }
        return BrowserTabHint(title: title, url: url, target: target)
    }

    var looksLikeMedia: Bool {
        let value = "\(title) \(url?.absoluteString ?? "")".lowercased()
        let mediaHints = [
            "youtube.com",
            "music.youtube.com",
            "netflix.com",
            "hulu.com",
            "twitch.tv",
            "vimeo.com",
            "disneyplus.com",
            "max.com",
            "spotify.com",
            "soundcloud.com",
            "pandora.com",
            "music.apple.com",
            "tv.apple.com",
            "primevideo.com",
            "peacocktv.com"
        ]
        return mediaHints.contains { value.contains($0) }
    }

    func snapshot(now: Date) -> LiveIslandSnapshot {
        LiveIslandSnapshot(
            providerID: BrowserMediaProvider.providerID,
            providerName: "Browser Media",
            kind: .browserMedia,
            priority: .backgroundMedia,
            title: "Possible browser media",
            subtitle: title.isEmpty ? target.displayName : "\(target.displayName): \(title)",
            appName: target.displayName,
            bundleIdentifier: target.bundleIdentifier,
            symbolName: "play.rectangle.on.rectangle",
            playbackState: .unknown,
            sourceURL: url,
            startedAt: now,
            expiresAt: now.addingTimeInterval(8),
            actions: [LiveIslandAction(.openSource)]
        )
    }
}

final class GenericMediaAppProvider: LiveIslandProvider {
    let id = "generic-media-app"
    let displayName = "Generic Media App"

    private let targets: [(name: String, bundleID: String, symbolName: String)] = [
        ("TV", "com.apple.TV", "tv"),
        ("Podcasts", "com.apple.podcasts", "dot.radiowaves.left.and.right"),
        ("VLC", "org.videolan.vlc", "play.rectangle"),
        ("IINA", "com.colliderli.iina", "play.rectangle")
    ]

    func isEnabled(settings: LiveIslandSettings) -> Bool {
        settings.enableLiveIslandSources && settings.genericMediaEnabled
    }

    func snapshot(settings: LiveIslandSettings, now: Date) async -> LiveIslandSnapshot? {
        guard let target = targets.first(where: { target in
            NSWorkspace.shared.runningApplications.contains { $0.bundleIdentifier == target.bundleID }
        }) else {
            return nil
        }

        return LiveIslandSnapshot(
            providerID: id,
            providerName: displayName,
            kind: .genericMedia,
            priority: .backgroundMedia,
            title: "Media app active",
            subtitle: target.name,
            appName: target.name,
            bundleIdentifier: target.bundleID,
            symbolName: target.symbolName,
            playbackState: .unknown,
            startedAt: now,
            expiresAt: now.addingTimeInterval(8),
            actions: [LiveIslandAction(.openSource)]
        )
    }

    func perform(action: LiveIslandActionKind) async -> CommandResult {
        guard action == .openSource else {
            return .failure("Media App", "\(action.title) is not available for generic media apps.")
        }

        for target in targets {
            if let app = NSWorkspace.shared.runningApplications.first(where: { $0.bundleIdentifier == target.bundleID }) {
                app.activate(options: [])
                return .success("Media App", "Opened \(target.name).")
            }
        }

        return .failure("Media App", "No known media app is running.")
    }
}

struct ActiveDownload: Equatable {
    var url: URL
    var sizeBytes: Int64?
    var modifiedAt: Date?

    var displayName: String {
        let name = url.lastPathComponent
        if name.hasSuffix(".download") || name.hasSuffix(".crdownload") || name.hasSuffix(".part") {
            return String(name.dropLast(url.pathExtension.count + 1))
        }
        return name
    }
}

final class DownloadsProvider: LiveIslandProvider {
    let id = "downloads"
    let displayName = "Downloads"

    private var lastFolderURL: URL?
    private var trackedSizes: [String: (bytes: Int64, at: Date)] = [:]
    private var lastActiveNames: [String] = []
    private var completion: (name: String, at: Date)?

    func isEnabled(settings: LiveIslandSettings) -> Bool {
        settings.enableLiveIslandSources && settings.downloadsWatcherEnabled && settings.downloadsFolderBookmark != nil
    }

    func snapshot(settings: LiveIslandSettings, now: Date) async -> LiveIslandSnapshot? {
        guard let folderURL = settings.resolveDownloadsFolder() else { return nil }
        lastFolderURL = folderURL
        let started = folderURL.startAccessingSecurityScopedResource()
        defer {
            if started {
                folderURL.stopAccessingSecurityScopedResource()
            }
        }

        let downloads = Self.activeDownloads(in: folderURL)

        guard let newest = downloads.first else {
            // A tracked temp file vanishing means the download finished —
            // surface that instead of silently blinking out.
            if let finishedName = lastActiveNames.first {
                completion = (name: finishedName, at: now)
                lastActiveNames = []
                trackedSizes = [:]
            }
            if let completion, now < completion.at.addingTimeInterval(6) {
                return LiveIslandSnapshot(
                    providerID: id,
                    providerName: displayName,
                    kind: .download,
                    priority: .download,
                    title: "Download finished",
                    subtitle: completion.name,
                    symbolName: "checkmark.circle",
                    progress: 1,
                    startedAt: completion.at,
                    expiresAt: completion.at.addingTimeInterval(6),
                    actions: [LiveIslandAction(.openSource, title: "Open Downloads")]
                )
            }
            completion = nil
            return nil
        }

        completion = nil
        lastActiveNames = downloads.map(\.displayName)

        var subtitleParts: [String] = [newest.displayName.isEmpty ? "Temporary download file" : newest.displayName]
        if let bytes = newest.sizeBytes {
            var detail = ByteCountFormatter.string(fromByteCount: bytes, countStyle: .file)
            if let previous = trackedSizes[newest.url.path], now > previous.at, bytes > previous.bytes {
                let rate = Double(bytes - previous.bytes) / now.timeIntervalSince(previous.at)
                detail += " at \(ByteCountFormatter.string(fromByteCount: Int64(rate), countStyle: .file))/s"
            }
            subtitleParts.append(detail)
            trackedSizes[newest.url.path] = (bytes: bytes, at: now)
        }

        return LiveIslandSnapshot(
            providerID: id,
            providerName: displayName,
            kind: .download,
            priority: .download,
            title: downloads.count > 1 ? "\(downloads.count) downloads active" : "Downloading",
            subtitle: subtitleParts.joined(separator: " - "),
            symbolName: "arrow.down.circle",
            progress: nil,
            startedAt: now,
            expiresAt: now.addingTimeInterval(4),
            actions: [LiveIslandAction(.openSource, title: "Open Downloads")]
        )
    }

    func perform(action: LiveIslandActionKind) async -> CommandResult {
        guard action == .openSource else {
            return .failure("Downloads", "\(action.title) is not available for downloads.")
        }
        guard let lastFolderURL else {
            return .failure("Downloads", "No Downloads folder has been selected.")
        }
        NSWorkspace.shared.open(lastFolderURL)
        return .success("Downloads", "Opened \(lastFolderURL.lastPathComponent).")
    }

    static func activeDownload(in folderURL: URL, fileManager: FileManager = .default) -> ActiveDownload? {
        activeDownloads(in: folderURL, fileManager: fileManager).first
    }

    static func activeDownloads(in folderURL: URL, fileManager: FileManager = .default) -> [ActiveDownload] {
        guard let contents = try? fileManager.contentsOfDirectory(
            at: folderURL,
            includingPropertiesForKeys: [.contentModificationDateKey, .fileSizeKey],
            options: [.skipsHiddenFiles]
        ) else {
            return []
        }

        let candidates = contents.compactMap { url -> ActiveDownload? in
            let pathExtension = url.pathExtension.lowercased()
            guard ["download", "crdownload", "part"].contains(pathExtension) else { return nil }
            let values = try? url.resourceValues(forKeys: [.contentModificationDateKey, .fileSizeKey])
            return ActiveDownload(
                url: url,
                sizeBytes: values?.fileSize.map(Int64.init),
                modifiedAt: values?.contentModificationDate
            )
        }

        return candidates.sorted { lhs, rhs in
            (lhs.modifiedAt ?? .distantPast) > (rhs.modifiedAt ?? .distantPast)
        }
    }
}

struct LiveIslandTimer: Identifiable, Codable, Hashable {
    var id: UUID
    var duration: TimeInterval
    var startedAt: Date
    var endsAt: Date

    init(id: UUID = UUID(), duration: TimeInterval, startedAt: Date) {
        self.id = id
        self.duration = duration
        self.startedAt = startedAt
        self.endsAt = startedAt.addingTimeInterval(duration)
    }

    func remaining(at date: Date) -> TimeInterval {
        max(0, endsAt.timeIntervalSince(date))
    }
}

final class TimerProvider: LiveIslandProvider {
    let id = "timer"
    let displayName = "Timers"

    /// Fired whenever the timer starts, is restored, completes, or is
    /// cancelled — AppEnvironment persists it so a relaunch resumes countdown.
    var onTimerChanged: ((LiveIslandTimer?) -> Void)?
    /// Plays the completion chime; overridable so tests stay silent.
    var completionSound: () -> Void = {
        (NSSound(named: "Glass") ?? NSSound(named: "Ping"))?.play()
    }

    private(set) var activeTimer: LiveIslandTimer?

    func isEnabled(settings: LiveIslandSettings) -> Bool {
        settings.enableLiveIslandSources && settings.timersEnabled
    }

    func startTimer(duration: TimeInterval, now: Date = Date()) {
        activeTimer = LiveIslandTimer(duration: duration, startedAt: now)
        onTimerChanged?(activeTimer)
    }

    /// Re-arms a timer persisted by a previous launch, keeping its original
    /// start and end dates.
    func restoreTimer(_ timer: LiveIslandTimer, now: Date = Date()) {
        guard timer.endsAt > now else { return }
        activeTimer = timer
        onTimerChanged?(activeTimer)
    }

    func cancelTimer() {
        guard activeTimer != nil else { return }
        activeTimer = nil
        onTimerChanged?(nil)
    }

    func snapshot(settings: LiveIslandSettings, now: Date) async -> LiveIslandSnapshot? {
        guard let timer = activeTimer else { return nil }
        let remaining = timer.remaining(at: now)
        guard remaining > 0 else {
            activeTimer = nil
            onTimerChanged?(nil)
            completionSound()
            return LiveIslandSnapshot(
                providerID: id,
                providerName: displayName,
                kind: .timer,
                priority: .timer,
                title: "Timer complete",
                subtitle: "Time is up",
                symbolName: "timer",
                progress: 1,
                startedAt: now,
                expiresAt: now.addingTimeInterval(5),
                actions: [LiveIslandAction(.cancelTimer)]
            )
        }

        let minutes = Int(remaining) / 60
        let seconds = Int(remaining) % 60
        let completed = min(max((timer.duration - remaining) / timer.duration, 0), 1)

        return LiveIslandSnapshot(
            providerID: id,
            providerName: displayName,
            kind: .timer,
            priority: .timer,
            title: "Timer \(Int((timer.duration / 60).rounded())) min",
            subtitle: String(format: "%d:%02d remaining", minutes, seconds),
            symbolName: "timer",
            progress: completed,
            startedAt: timer.startedAt,
            expiresAt: timer.endsAt,
            actions: [LiveIslandAction(.cancelTimer)]
        )
    }

    func perform(action: LiveIslandActionKind) async -> CommandResult {
        guard action == .cancelTimer else {
            return .failure("Timer", "\(action.title) is not available for timers.")
        }
        cancelTimer()
        return .success("Timer", "Timer cancelled.")
    }
}

final class MacForgeTaskProvider: LiveIslandProvider {
    let id = "macforge-task"
    let displayName = "MacForge Tasks"

    private weak var activityCenter: NotchIslandActivityCenter?

    init(activityCenter: NotchIslandActivityCenter) {
        self.activityCenter = activityCenter
    }

    func isEnabled(settings: LiveIslandSettings) -> Bool {
        true
    }

    func snapshot(settings: LiveIslandSettings, now: Date) async -> LiveIslandSnapshot? {
        guard let activity = activityCenter?.currentActivity else { return nil }
        if let expiresAt = activity.expiresAt, now >= expiresAt {
            return nil
        }
        if activity.kind == .idle, activity.title == "Idle" {
            return nil
        }

        return LiveIslandSnapshot(
            providerID: id,
            providerName: displayName,
            kind: activity.isError ? .error : .task,
            priority: activity.isError ? .error : .task,
            title: activity.title,
            subtitle: activity.message,
            symbolName: activity.symbolName,
            progress: activity.progress,
            startedAt: activity.startedAt,
            expiresAt: activity.expiresAt,
            isError: activity.isError
        )
    }
}

private func automationResult(
    _ result: Result<String, AppleScriptExecutionError>,
    title: String,
    successMessage: String
) -> CommandResult {
    switch result {
    case .success:
        return .success(title, successMessage)
    case .failure(let error):
        if error.isPermissionError {
            return .failure(title, "Automation permission is required.", details: [error.message])
        }
        return .failure(title, "Automation failed.", details: [error.message])
    }
}
