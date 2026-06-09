import Foundation

struct LiveIslandSettings: Codable, Equatable, Hashable {
    var enableLiveIslandSources: Bool
    var appleMusicEnabled: Bool
    var spotifyEnabled: Bool
    var quickTimeEnabled: Bool
    var browserMediaHintsEnabled: Bool
    var downloadsWatcherEnabled: Bool
    var timersEnabled: Bool
    var keepMediaVisibleWhilePlaying: Bool
    var showArtwork: Bool
    var privacyMode: Bool
    var providerDiagnosticsEnabled: Bool
    var downloadsFolderBookmark: Data?
    var downloadsFolderName: String?

    static let `default` = LiveIslandSettings(
        enableLiveIslandSources: true,
        appleMusicEnabled: true,
        spotifyEnabled: true,
        quickTimeEnabled: true,
        browserMediaHintsEnabled: false,
        downloadsWatcherEnabled: true,
        timersEnabled: true,
        keepMediaVisibleWhilePlaying: true,
        showArtwork: true,
        privacyMode: false,
        providerDiagnosticsEnabled: false,
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
        keepMediaVisibleWhilePlaying: Bool,
        showArtwork: Bool,
        privacyMode: Bool,
        providerDiagnosticsEnabled: Bool,
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
        self.keepMediaVisibleWhilePlaying = keepMediaVisibleWhilePlaying
        self.showArtwork = showArtwork
        self.privacyMode = privacyMode
        self.providerDiagnosticsEnabled = providerDiagnosticsEnabled
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
}
