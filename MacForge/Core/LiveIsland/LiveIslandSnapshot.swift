import Foundation

enum LiveIslandSnapshotKind: String, Codable, CaseIterable, Hashable {
    case idle
    case music
    case video
    case browserMedia
    case genericMedia
    case download
    case timer
    case task
    case error
}

enum LiveIslandPlaybackState: String, Codable, CaseIterable, Hashable {
    case playing
    case paused
    case stopped
    case unknown

    var isPlaying: Bool { self == .playing }
}

enum LiveIslandActionKind: String, Codable, CaseIterable, Identifiable, Hashable {
    case playPause
    case next
    case previous
    case openSource
    case cancelTimer

    var id: String { rawValue }

    var symbolName: String {
        switch self {
        case .playPause: "playpause.fill"
        case .next: "forward.fill"
        case .previous: "backward.fill"
        case .openSource: "arrow.up.right.square"
        case .cancelTimer: "xmark.circle"
        }
    }

    var title: String {
        switch self {
        case .playPause: "Play or Pause"
        case .next: "Next"
        case .previous: "Previous"
        case .openSource: "Open Source"
        case .cancelTimer: "Cancel Timer"
        }
    }
}

struct LiveIslandAction: Identifiable, Codable, Hashable {
    var kind: LiveIslandActionKind
    var title: String
    var symbolName: String
    var isEnabled: Bool

    var id: String { kind.rawValue }

    init(
        _ kind: LiveIslandActionKind,
        title: String? = nil,
        symbolName: String? = nil,
        isEnabled: Bool = true
    ) {
        self.kind = kind
        self.title = title ?? kind.title
        self.symbolName = symbolName ?? kind.symbolName
        self.isEnabled = isEnabled
    }
}

struct LiveIslandSnapshot: Identifiable, Codable, Hashable {
    var id: UUID
    var providerID: String
    var providerName: String
    var kind: LiveIslandSnapshotKind
    var priority: LiveIslandPriority
    var title: String
    var subtitle: String
    var appName: String?
    var bundleIdentifier: String?
    var symbolName: String
    var playbackState: LiveIslandPlaybackState
    var elapsedTime: TimeInterval?
    var duration: TimeInterval?
    var progress: Double?
    var artworkURL: URL?
    var sourceURL: URL?
    var startedAt: Date
    var expiresAt: Date?
    var isError: Bool
    var actions: [LiveIslandAction]

    init(
        id: UUID = UUID(),
        providerID: String,
        providerName: String,
        kind: LiveIslandSnapshotKind,
        priority: LiveIslandPriority,
        title: String,
        subtitle: String = "",
        appName: String? = nil,
        bundleIdentifier: String? = nil,
        symbolName: String,
        playbackState: LiveIslandPlaybackState = .unknown,
        elapsedTime: TimeInterval? = nil,
        duration: TimeInterval? = nil,
        progress: Double? = nil,
        artworkURL: URL? = nil,
        sourceURL: URL? = nil,
        startedAt: Date = Date(),
        expiresAt: Date? = nil,
        isError: Bool = false,
        actions: [LiveIslandAction] = []
    ) {
        self.id = id
        self.providerID = providerID
        self.providerName = providerName
        self.kind = kind
        self.priority = priority
        self.title = title
        self.subtitle = subtitle
        self.appName = appName
        self.bundleIdentifier = bundleIdentifier
        self.symbolName = symbolName
        self.playbackState = playbackState
        self.elapsedTime = elapsedTime
        self.duration = duration
        self.progress = progress ?? Self.progress(elapsedTime: elapsedTime, duration: duration)
        self.artworkURL = artworkURL
        self.sourceURL = sourceURL
        self.startedAt = startedAt
        self.expiresAt = expiresAt
        self.isError = isError
        self.actions = actions
    }

    static func idle(at date: Date = Date()) -> LiveIslandSnapshot {
        LiveIslandSnapshot(
            id: UUID(uuidString: "00000000-0000-0000-0000-000000000001") ?? UUID(),
            providerID: "idle",
            providerName: "MacForge",
            kind: .idle,
            priority: .idle,
            title: "MacForge",
            subtitle: "Ready",
            symbolName: "sparkle",
            startedAt: date
        )
    }

    func isActive(at date: Date, settings: LiveIslandSettings) -> Bool {
        if playbackState.isPlaying, settings.keepMediaVisibleWhilePlaying {
            return true
        }
        guard let expiresAt else { return true }
        return date < expiresAt
    }

    func redacted(using settings: LiveIslandSettings) -> LiveIslandSnapshot {
        guard settings.privacyMode else {
            var copy = self
            if !settings.showArtwork {
                copy.artworkURL = nil
            }
            return copy
        }

        var copy = self
        copy.artworkURL = nil

        switch kind {
        case .music:
            copy.title = playbackState == .paused ? "Music paused" : "Music playing"
            copy.subtitle = appName ?? providerName
        case .video:
            copy.title = playbackState == .paused ? "Video paused" : "Video active"
            copy.subtitle = appName ?? providerName
        case .browserMedia:
            copy.title = "Possible browser media"
            copy.subtitle = appName ?? providerName
        case .genericMedia:
            copy.title = "Media app active"
            copy.subtitle = appName ?? providerName
        default:
            break
        }

        return copy
    }

    private static func progress(elapsedTime: TimeInterval?, duration: TimeInterval?) -> Double? {
        guard let elapsedTime,
              let duration,
              duration > 0 else {
            return nil
        }

        return min(max(elapsedTime / duration, 0), 1)
    }
}
