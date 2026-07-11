import Foundation

struct LiveIslandSettings: Codable, Equatable, Hashable {
    var enableLiveIslandSources: Bool
    var appleMusicEnabled: Bool
    var spotifyEnabled: Bool
    var quickTimeEnabled: Bool
    var browserMediaHintsEnabled: Bool
    var downloadsWatcherEnabled: Bool
    var timersEnabled: Bool
    var calendarAgendaEnabled: Bool
    var volumeHUDEnabled: Bool
    var genericMediaEnabled: Bool
    var keepMediaVisibleWhilePlaying: Bool
    var showArtwork: Bool
    var privacyMode: Bool
    var providerDiagnosticsEnabled: Bool
    var agentActivityEnabled: Bool
    var showBatteryInIsland: Bool
    var clipboardHistoryEnabled: Bool
    var weatherEnabled: Bool
    var weatherLatitude: Double?
    var weatherLongitude: Double?
    var weatherLocationName: String?
    var excludeFromScreenCapture: Bool
    var downloadsFolderBookmark: Data?
    var downloadsFolderName: String?

    static let `default` = LiveIslandSettings(
        enableLiveIslandSources: true,
        appleMusicEnabled: true,
        spotifyEnabled: true,
        quickTimeEnabled: true,
        browserMediaHintsEnabled: false,
        downloadsWatcherEnabled: false,
        timersEnabled: true,
        calendarAgendaEnabled: false,
        volumeHUDEnabled: true,
        genericMediaEnabled: false,
        keepMediaVisibleWhilePlaying: true,
        showArtwork: true,
        privacyMode: false,
        providerDiagnosticsEnabled: false,
        agentActivityEnabled: true,
        showBatteryInIsland: true,
        clipboardHistoryEnabled: true,
        weatherEnabled: false,
        weatherLatitude: nil,
        weatherLongitude: nil,
        weatherLocationName: nil,
        excludeFromScreenCapture: false,
        downloadsFolderBookmark: nil,
        downloadsFolderName: nil
    )

    init(
        enableLiveIslandSources: Bool,
        appleMusicEnabled: Bool,
        spotifyEnabled: Bool,
        quickTimeEnabled: Bool,
        browserMediaHintsEnabled: Bool,
        downloadsWatcherEnabled: Bool,
        timersEnabled: Bool,
        calendarAgendaEnabled: Bool = false,
        volumeHUDEnabled: Bool = true,
        genericMediaEnabled: Bool = false,
        keepMediaVisibleWhilePlaying: Bool,
        showArtwork: Bool,
        privacyMode: Bool,
        providerDiagnosticsEnabled: Bool,
        agentActivityEnabled: Bool,
        showBatteryInIsland: Bool,
        clipboardHistoryEnabled: Bool = true,
        weatherEnabled: Bool = false,
        weatherLatitude: Double? = nil,
        weatherLongitude: Double? = nil,
        weatherLocationName: String? = nil,
        excludeFromScreenCapture: Bool = false,
        downloadsFolderBookmark: Data?,
        downloadsFolderName: String?
    ) {
        self.enableLiveIslandSources = enableLiveIslandSources
        self.appleMusicEnabled = appleMusicEnabled
        self.spotifyEnabled = spotifyEnabled
        self.quickTimeEnabled = quickTimeEnabled
        self.browserMediaHintsEnabled = browserMediaHintsEnabled
        self.downloadsWatcherEnabled = downloadsWatcherEnabled
        self.timersEnabled = timersEnabled
        self.calendarAgendaEnabled = calendarAgendaEnabled
        self.volumeHUDEnabled = volumeHUDEnabled
        self.genericMediaEnabled = genericMediaEnabled
        self.keepMediaVisibleWhilePlaying = keepMediaVisibleWhilePlaying
        self.showArtwork = showArtwork
        self.privacyMode = privacyMode
        self.providerDiagnosticsEnabled = providerDiagnosticsEnabled
        self.agentActivityEnabled = agentActivityEnabled
        self.showBatteryInIsland = showBatteryInIsland
        self.clipboardHistoryEnabled = clipboardHistoryEnabled
        self.weatherEnabled = weatherEnabled
        self.weatherLatitude = weatherLatitude
        self.weatherLongitude = weatherLongitude
        self.weatherLocationName = weatherLocationName
        self.excludeFromScreenCapture = excludeFromScreenCapture
        self.downloadsFolderBookmark = downloadsFolderBookmark
        self.downloadsFolderName = downloadsFolderName
    }

    mutating func setDownloadsFolder(_ url: URL) throws {
        downloadsFolderBookmark = try url.bookmarkData(
            options: [.withSecurityScope],
            includingResourceValuesForKeys: nil,
            relativeTo: nil
        )
        downloadsFolderName = url.lastPathComponent
    }

    mutating func clearDownloadsFolder() {
        downloadsFolderBookmark = nil
        downloadsFolderName = nil
    }

    func resolveDownloadsFolder() -> URL? {
        guard let downloadsFolderBookmark else { return nil }
        var isStale = false
        return try? URL(
            resolvingBookmarkData: downloadsFolderBookmark,
            options: [.withSecurityScope],
            relativeTo: nil,
            bookmarkDataIsStale: &isStale
        )
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let defaults = Self.default

        enableLiveIslandSources = try container.decodeIfPresent(Bool.self, forKey: .enableLiveIslandSources) ?? defaults.enableLiveIslandSources
        appleMusicEnabled = try container.decodeIfPresent(Bool.self, forKey: .appleMusicEnabled) ?? defaults.appleMusicEnabled
        spotifyEnabled = try container.decodeIfPresent(Bool.self, forKey: .spotifyEnabled) ?? defaults.spotifyEnabled
        quickTimeEnabled = try container.decodeIfPresent(Bool.self, forKey: .quickTimeEnabled) ?? defaults.quickTimeEnabled
        browserMediaHintsEnabled = try container.decodeIfPresent(Bool.self, forKey: .browserMediaHintsEnabled) ?? defaults.browserMediaHintsEnabled
        downloadsWatcherEnabled = try container.decodeIfPresent(Bool.self, forKey: .downloadsWatcherEnabled) ?? defaults.downloadsWatcherEnabled
        timersEnabled = try container.decodeIfPresent(Bool.self, forKey: .timersEnabled) ?? defaults.timersEnabled
        calendarAgendaEnabled = try container.decodeIfPresent(Bool.self, forKey: .calendarAgendaEnabled) ?? defaults.calendarAgendaEnabled
        volumeHUDEnabled = try container.decodeIfPresent(Bool.self, forKey: .volumeHUDEnabled) ?? defaults.volumeHUDEnabled
        genericMediaEnabled = try container.decodeIfPresent(Bool.self, forKey: .genericMediaEnabled) ?? defaults.genericMediaEnabled
        keepMediaVisibleWhilePlaying = try container.decodeIfPresent(Bool.self, forKey: .keepMediaVisibleWhilePlaying) ?? defaults.keepMediaVisibleWhilePlaying
        showArtwork = try container.decodeIfPresent(Bool.self, forKey: .showArtwork) ?? defaults.showArtwork
        privacyMode = try container.decodeIfPresent(Bool.self, forKey: .privacyMode) ?? defaults.privacyMode
        providerDiagnosticsEnabled = try container.decodeIfPresent(Bool.self, forKey: .providerDiagnosticsEnabled) ?? defaults.providerDiagnosticsEnabled
        agentActivityEnabled = try container.decodeIfPresent(Bool.self, forKey: .agentActivityEnabled) ?? defaults.agentActivityEnabled
        showBatteryInIsland = try container.decodeIfPresent(Bool.self, forKey: .showBatteryInIsland) ?? defaults.showBatteryInIsland
        clipboardHistoryEnabled = try container.decodeIfPresent(Bool.self, forKey: .clipboardHistoryEnabled) ?? defaults.clipboardHistoryEnabled
        weatherEnabled = try container.decodeIfPresent(Bool.self, forKey: .weatherEnabled) ?? defaults.weatherEnabled
        weatherLatitude = try container.decodeIfPresent(Double.self, forKey: .weatherLatitude) ?? defaults.weatherLatitude
        weatherLongitude = try container.decodeIfPresent(Double.self, forKey: .weatherLongitude) ?? defaults.weatherLongitude
        weatherLocationName = try container.decodeIfPresent(String.self, forKey: .weatherLocationName) ?? defaults.weatherLocationName
        excludeFromScreenCapture = try container.decodeIfPresent(Bool.self, forKey: .excludeFromScreenCapture) ?? defaults.excludeFromScreenCapture
        downloadsFolderBookmark = try container.decodeIfPresent(Data.self, forKey: .downloadsFolderBookmark) ?? defaults.downloadsFolderBookmark
        downloadsFolderName = try container.decodeIfPresent(String.self, forKey: .downloadsFolderName) ?? defaults.downloadsFolderName
    }
}
