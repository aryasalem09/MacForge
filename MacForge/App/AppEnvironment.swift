import AppKit
import Combine
import Foundation
import UniformTypeIdentifiers

private struct MacForgeConfiguration: Codable {
    /// Bump when the meaning of persisted data changes. Version 1 predates the
    /// field (decodes as nil); version 2 introduced explicit versioning, the
    /// persistent notch tray, and the onboarding flag.
    static let currentSchemaVersion = 2

    var schemaVersion: Int?
    var notchConfig: NotchShelfConfig
    var liveIslandSettings: LiveIslandSettings?
    var dockSettings: DockSettings
    var pinnedFolders: [FolderShortcut]
    var wallpaperPresets: [WallpaperPreset]
    var appPresets: [AppPreset]
    var fileRules: [FileRule]
    var safetyConfirmationsEnabled: Bool
    var experimentalDockTweaksEnabled: Bool
    var showInDock: Bool
    var notchTrayItems: [NotchTrayItem]?
    var trayRetentionMinutes: Double?
    var hasCompletedOnboarding: Bool?
    var activeTimer: LiveIslandTimer?
}

private enum ConfigurationLoadOutcome {
    case fresh
    case loaded(MacForgeConfiguration)
    case migrated(MacForgeConfiguration, fromVersion: Int, backupName: String?)
    case failed(backupName: String?, errorDescription: String)
}

enum FileRuleOperationResult<T> {
    case success(T)
    case failure(CommandResult)
}

struct MacForgeBuildInfo: Hashable {
    /// Derived from the bundle so the About panel, diagnostics, and debug
    /// overlay can never disagree with the shipped MARKETING_VERSION.
    static let marketingVersion = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "dev"
    static let buildNumber = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "0"
    static var label: String { "v\(marketingVersion) (\(buildNumber))" }

    var bundlePath: String {
        Bundle.main.bundleURL.path
    }
}

extension JSONEncoder {
    static var macForge: JSONEncoder {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }
}

extension JSONDecoder {
    static var macForge: JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }
}

@MainActor
final class AppEnvironment: ObservableObject {
    @Published var notchConfig: NotchShelfConfig {
        didSet { updateShelfAndPersist() }
    }
    @Published var liveIslandSettings: LiveIslandSettings {
        didSet {
            if !Self.isRunningUnitTests, !notchConfig.forceAttachedNotchTestMode {
                liveIslandCoordinator.updateSettings(liveIslandSettings)
                if liveIslandSettings.agentActivityEnabled != oldValue.agentActivityEnabled {
                    if liveIslandSettings.agentActivityEnabled {
                        agentActivityCenter.start()
                    } else {
                        agentActivityCenter.stop()
                        agentActivityCenter.clearAll()
                    }
                }
                if liveIslandSettings.volumeHUDEnabled != oldValue.volumeHUDEnabled {
                    if liveIslandSettings.volumeHUDEnabled {
                        volumeHUDCenter.start()
                    } else {
                        volumeHUDCenter.stop()
                    }
                }
            }
            persist()
        }
    }
    @Published var dockSettings: DockSettings {
        didSet { persist() }
    }
    @Published var pinnedFolders: [FolderShortcut] {
        didSet {
            refreshPermissions()
            persist()
        }
    }
    @Published var wallpaperPresets: [WallpaperPreset] {
        didSet { persist() }
    }
    @Published var appPresets: [AppPreset] {
        didSet { persist() }
    }
    @Published var fileRules: [FileRule] {
        didSet { persist() }
    }
    @Published var permissionStates: [PermissionState] = []
    @Published var windows: [WindowInfo] = []
    @Published var commandResults: [CommandResult] = []
    @Published var notchTrayItems: [NotchTrayItem] {
        didSet { persist() }
    }
    @Published var trayRetentionMinutes: Double {
        didSet {
            pruneExpiredTrayItems()
            persist()
        }
    }
    @Published var hasCompletedOnboarding: Bool {
        didSet { persist() }
    }
    /// Mirror of the timer provider's active timer, persisted so a countdown
    /// survives relaunch.
    @Published var activeLiveTimer: LiveIslandTimer? {
        didSet { persist() }
    }
    @Published var wallpaperStates: [ScreenWallpaperState] = []
    @Published var safetyConfirmationsEnabled: Bool {
        didSet { persist() }
    }
    @Published var experimentalDockTweaksEnabled: Bool {
        didSet {
            refreshPermissions()
            persist()
        }
    }
    @Published var showInDock: Bool {
        didSet {
            NSApp.setActivationPolicy(showInDock ? .regular : .accessory)
            persist()
        }
    }
    @Published var lastPresetTransaction: PresetTransaction?
    @Published private(set) var notchHoverState: NotchHoverVisualState = .idle
    @Published private(set) var notchHoverDiagnostics: [String] = []

    let permissionCenter = PermissionCenter()
    let fileAccessPermissionService = FileAccessPermissionService()
    let folderAccessStore = FolderAccessStore()
    let windowService = AccessibilityWindowService()
    let dockSettingsService = DockSettingsService()
    let recoveryService = MacForgeRecoveryService()
    let wallpaperService = WallpaperService()
    let notchShelfWindowController = NotchShelfWindowController()
    let fileOrganizerService = FileOrganizerService()
    let bulkRenameEngine = BulkRenameEngine()
    let duplicateFinder = DuplicateFinder()
    let presetRunner = PresetRunner()
    let rollbackManager = RollbackManager()
    let notchIslandActivityCenter = NotchIslandActivityCenter()
    let liveIslandCoordinator = LiveIslandCoordinator()
    let agentActivityCenter = AgentActivityCenter()
    let volumeHUDCenter = VolumeHUDCenter()

    private let configurationURL: URL
    private var isLoading = true
    private var cancellables: Set<AnyCancellable> = []
    private var hoverStateMachine = NotchHoverStateMachine()
    private var hoverExpandTask: Task<Void, Never>?
    private var hoverCollapseTask: Task<Void, Never>?
    private var persistTask: Task<Void, Never>?

    var buildInfo: MacForgeBuildInfo { MacForgeBuildInfo() }
    var configurationPath: String { configurationURL.path }

    private static var isRunningUnitTests: Bool {
        let processInfo = ProcessInfo.processInfo
        let environment = processInfo.environment
        return environment["XCTestConfigurationFilePath"] != nil
            || environment["XCTestBundlePath"] != nil
            || processInfo.arguments.contains { $0.localizedCaseInsensitiveContains(".xctest") }
    }

    init() {
        let supportDirectory = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
            .appendingPathComponent("MacForge", isDirectory: true)
        try? FileManager.default.createDirectory(at: supportDirectory, withIntermediateDirectories: true)
        configurationURL = supportDirectory.appendingPathComponent("configuration.json")

        let loaded: MacForgeConfiguration?
        var startupMessages: [CommandResult] = []
        switch Self.loadConfiguration(from: configurationURL) {
        case .fresh:
            loaded = nil
        case .loaded(let configuration):
            loaded = configuration
        case .migrated(let configuration, let fromVersion, let backupName):
            loaded = configuration
            startupMessages.append(.success(
                "Preferences",
                "Settings were upgraded from schema v\(fromVersion) to v\(MacForgeConfiguration.currentSchemaVersion).",
                details: backupName.map { ["A backup of the previous file was kept as \($0)."] } ?? []
            ))
        case .failed(let backupName, let errorDescription):
            loaded = nil
            startupMessages.append(.failure(
                "Preferences",
                "Saved settings could not be read, so defaults were used.",
                details: [errorDescription] + (backupName.map { ["The unreadable file was kept as \($0)."] } ?? [])
            ))
        }
        var loadedNotchConfig = loaded?.notchConfig ?? .default
        let launchArguments = ProcessInfo.processInfo.arguments
        let forceVisualTest = launchArguments.contains("--macforge-force-notch-test")
        let forceExpandedVisualTest = launchArguments.contains("--macforge-force-notch-expanded")
        if forceVisualTest {
            loadedNotchConfig.hardResetVisualState(keepEnabled: true)
            loadedNotchConfig.enabled = true
            loadedNotchConfig.preferredStyle = .island
            loadedNotchConfig.forceAttachedNotchTestMode = true
            loadedNotchConfig.showPlacementDebugOverlay = true
            loadedNotchConfig.presentationState = forceExpandedVisualTest ? .expanded : .collapsed
        } else if loadedNotchConfig.forceAttachedNotchTestMode {
            // A previous QA launch persisted the forced test flags; clear them
            // so normal launches get Live Island providers back.
            loadedNotchConfig.forceAttachedNotchTestMode = false
            loadedNotchConfig.showPlacementDebugOverlay = false
            loadedNotchConfig.presentationState = .collapsed
        }
        let repairedAttachedNotchLayout = loadedNotchConfig.repairAttachedNotchLayoutIfNeeded()
        notchConfig = loadedNotchConfig
        liveIslandSettings = loaded?.liveIslandSettings ?? .default
        dockSettings = loaded?.dockSettings ?? .default
        pinnedFolders = loaded?.pinnedFolders ?? []
        wallpaperPresets = loaded?.wallpaperPresets ?? []
        appPresets = loaded?.appPresets.isEmpty == false ? loaded!.appPresets : AppPreset.examples
        fileRules = loaded?.fileRules ?? []
        safetyConfirmationsEnabled = loaded?.safetyConfirmationsEnabled ?? true
        experimentalDockTweaksEnabled = loaded?.experimentalDockTweaksEnabled ?? false
        showInDock = loaded?.showInDock ?? true
        let retentionMinutes = loaded?.trayRetentionMinutes ?? 0
        trayRetentionMinutes = retentionMinutes
        notchTrayItems = Self.prunedTrayItems(loaded?.notchTrayItems ?? [], retentionMinutes: retentionMinutes, now: Date())
        // Configurations saved before onboarding existed belong to users who
        // already set the app up — don't replay the welcome flow at them.
        hasCompletedOnboarding = loaded?.hasCompletedOnboarding ?? (loaded != nil)

        wallpaperService.onPresetCreated = { [weak self] preset in
            Task { @MainActor in
                self?.wallpaperPresets.append(preset)
            }
        }

        activeLiveTimer = loaded?.activeTimer

        isLoading = false
        notchIslandActivityCenter.presentationState = notchConfig.enabled ? notchConfig.presentationState : .hidden
        liveIslandCoordinator.configureDefaultProviders(activityCenter: notchIslandActivityCenter)
        liveIslandCoordinator.timerProvider.onTimerChanged = { [weak self] timer in
            self?.activeLiveTimer = timer
        }
        // Resume a countdown that was running when the app last quit.
        if let persistedTimer = loaded?.activeTimer, persistedTimer.endsAt > Date() {
            liveIslandCoordinator.timerProvider.restoreTimer(persistedTimer)
        } else if loaded?.activeTimer != nil {
            activeLiveTimer = nil
        }
        if !Self.isRunningUnitTests, !notchConfig.forceAttachedNotchTestMode {
            liveIslandCoordinator.updateSettings(liveIslandSettings)
            liveIslandCoordinator.start()
            if liveIslandSettings.agentActivityEnabled {
                agentActivityCenter.start()
            }
            volumeHUDCenter.onHUDEvent = { [weak self] snapshot in
                self?.liveIslandCoordinator.push(snapshot)
            }
            if liveIslandSettings.volumeHUDEnabled {
                volumeHUDCenter.start()
            }
        }
        refreshPermissions()
        refreshWallpaperStates()
        startNotchIslandObservation()
        startCommandBusObservation()
        updateShelfAndPersist()
        // didSet observers don't fire during init, so apply the persisted
        // Dock-visibility policy explicitly after launch finishes (AppDelegate
        // no longer hardcodes .regular over the user's saved choice).
        let dockPolicy: NSApplication.ActivationPolicy = showInDock ? .regular : .accessory
        if !Self.isRunningUnitTests {
            DispatchQueue.main.async {
                NSApp.setActivationPolicy(dockPolicy)
            }
        }
        NotificationCenter.default.publisher(for: NSApplication.willTerminateNotification)
            .sink { [weak self] _ in
                // Persistence is debounced; make sure a pending write lands
                // before the process exits.
                MainActor.assumeIsolated {
                    self?.flushPendingPersist()
                }
            }
            .store(in: &cancellables)
        startupMessages.forEach(append)
        if repairedAttachedNotchLayout {
            append(.success("Notch Island", "Notch Island layout upgraded to the attached Dynamic Island engine."))
        }
        if forceVisualTest {
            append(.success("Visual QA", "Running \(MacForgeBuildInfo.label) with forced attached notch test mode."))
        }
        // Accessibility is intentionally NOT requested at launch. Window
        // helpers prompt via requireAccessibility(for:) at the moment they
        // are used, and onboarding explains the model — permissions stay tied
        // to features.
        if launchArguments.contains("--macforge-demo-island"), !Self.isRunningUnitTests {
            // Suppress persistence so this QA-only override never leaks the
            // enabled/island state into a normal launch's saved configuration.
            isLoading = true
            notchConfig.enabled = true
            notchConfig.preferredStyle = .island
            isLoading = false
            notchIslandActivityCenter.clearActivity()
            commandResults.removeAll()
            liveIslandCoordinator.showTestSnapshot(kind: .music)
            agentActivityCenter.injectTestActivity()
            let demoExpanded = launchArguments.contains("--macforge-demo-expanded")
            notchIslandActivityCenter.presentationState = demoExpanded ? .expanded : .compact
            updateNotchShelf()
        }
    }

    func refreshPermissions() {
        permissionStates = permissionCenter.snapshot(
            folderAccessCount: pinnedFolders.count,
            experimentalDockTweaksEnabled: experimentalDockTweaksEnabled,
            calendarAgendaEnabled: liveIslandSettings.calendarAgendaEnabled
        )
    }

    func requestAccessibility() {
        permissionCenter.requestAccessibility()
        refreshPermissions()
    }

    func setLaunchAtLogin(_ enabled: Bool) {
        append(permissionCenter.setLaunchAtLogin(enabled))
        refreshPermissions()
    }

    func toggleNotchShelf() {
        notchConfig.enabled.toggle()
        if notchConfig.enabled {
            notchIslandActivityCenter.collapse()
        } else {
            notchIslandActivityCenter.hide()
        }
    }

    func updateNotchShelf() {
        notchShelfWindowController.update(config: notchConfig, environment: self)
    }

    func expandNotchIsland() {
        guard !notchConfig.calibrationModeEnabled else { return }
        notchIslandActivityCenter.expand()
        // Keep the hover state machine in sync with a programmatic expand so a
        // later hover doesn't find it stuck in a stale state.
        applyHoverActions(hoverStateMachine.holdExpanded(), event: "expand requested")
    }

    func collapseNotchIsland() {
        guard !notchConfig.calibrationModeEnabled else { return }
        notchIslandActivityCenter.collapse()
        // Any explicit collapse (chevron, swipe, Settings, activity expiry)
        // resets hover intent so hover-to-expand works again immediately.
        resetHoverState()
    }

    func resetNotchIslandLayout() {
        notchConfig.resetToAttachedNotchDefaults(keepEnabled: true)
        notchIslandActivityCenter.collapse()
        append(.success("Notch Island", "Reset island layout to attached notch defaults."))
    }

    func repairNotchIslandLayout() {
        notchConfig.hardResetVisualState(keepEnabled: true)
        liveIslandCoordinator.clearTransientState()
        notchIslandActivityCenter.clearActivity()
        resetHoverState()
        notchIslandActivityCenter.collapse()
        append(.success("Notch Island", "Repaired stale toolbar-style layout and re-anchored the island to the notch."))
    }

    func hardResetNotchIslandVisualState() {
        notchConfig.hardResetVisualState(keepEnabled: true)
        liveIslandCoordinator.clearTransientState()
        notchIslandActivityCenter.clearActivity()
        resetHoverState()
        notchIslandActivityCenter.collapse()
        append(.success("Notch Island", "Hard reset Notch Island visual state without changing folders, presets, files, wallpapers, or Dock data."))
    }

    func snapNotchIslandToDetectedNotch() {
        notchConfig.islandHorizontalOffset = 0
        notchConfig.islandVerticalOffset = 0
        notchConfig.overlayMenuBarForAttachedNotch = true
        notchConfig.allowNotchIslandAboveMenuBar = true
        notchConfig.configVersion = NotchShelfConfig.currentConfigVersion
        notchIslandActivityCenter.collapse()
        append(.success("Notch Island", "Snapped placement to the detected notch geometry."))
    }

    func saveNotchCalibration() {
        notchConfig.calibrationModeEnabled = false
        resetHoverState()
        append(.success("Notch Calibration", "Saved x \(Int(notchConfig.islandHorizontalOffset)), y \(Int(notchConfig.islandVerticalOffset))."))
    }

    func resetNotchCalibration() {
        notchConfig.islandHorizontalOffset = 0
        notchConfig.islandVerticalOffset = 0
        notchConfig.calibrationModeEnabled = false
        resetHoverState()
        append(.success("Notch Calibration", "Reset manual calibration offsets."))
    }

    func beginNotchCalibrationDrag() {
        applyHoverActions(hoverStateMachine.beginCalibrationDrag(), event: "calibration drag began")
    }

    func updateNotchCalibrationDrag(startX: Double, startY: Double, translation: CGSize) {
        guard notchConfig.calibrationModeEnabled else { return }
        notchConfig.islandHorizontalOffset = (startX + Double(translation.width)).clamped(to: -160...160)
        notchConfig.islandVerticalOffset = (startY - Double(translation.height)).clamped(to: -120...120)
    }

    func endNotchCalibrationDrag() {
        applyHoverActions(hoverStateMachine.endCalibrationDrag(), event: "calibration drag ended")
        append(.success("Notch Calibration", "Calibration moved to x \(Int(notchConfig.islandHorizontalOffset)), y \(Int(notchConfig.islandVerticalOffset)). Click Save Calibration to keep this placement."))
    }

    func setForceAttachedNotchTestMode(_ enabled: Bool) {
        notchConfig.forceAttachedNotchTestMode = enabled
        if enabled {
            liveIslandCoordinator.stop()
            liveIslandCoordinator.clearTransientState()
        } else if !Self.isRunningUnitTests {
            liveIslandCoordinator.updateSettings(liveIslandSettings)
            liveIslandCoordinator.start()
        }
        notchIslandActivityCenter.clearActivity()
        resetHoverState()
        notchIslandActivityCenter.collapse()
        append(.success("Visual QA", enabled ? "Force Attached Notch Test Mode enabled." : "Force Attached Notch Test Mode disabled."))
    }

    func copyNotchGeometryDebugInfo() {
        // Report the same screen the island actually attaches to (the built-in
        // notched display), not merely NSScreen.main, so diagnostics match what
        // the user sees on multi-display setups.
        guard let screen = NotchShelfWindowController.islandScreen() else {
            append(.failure("Notch Geometry", "No screen was available for geometry diagnostics."))
            return
        }

        let service = NotchGeometryService()
        let metrics = service.metrics(for: screen)
        let layout = service.islandLayout(metrics: metrics, config: notchConfig)
        let panelFrame = notchShelfWindowController.currentPanelFrame
        let mouseLocation = NSEvent.mouseLocation
        let lines = [
            "buildLabel: \(MacForgeBuildInfo.label)",
            "bundlePath: \(buildInfo.bundlePath)",
            "configPath: \(configurationPath)",
            "screenID: \(metrics.screenID)",
            "islandScreen.frame: \(format(screen.frame))",
            "islandScreen.visibleFrame: \(format(screen.visibleFrame))",
            "islandScreen.safeAreaInsets: top \(screen.safeAreaInsets.top), left \(screen.safeAreaInsets.left), bottom \(screen.safeAreaInsets.bottom), right \(screen.safeAreaInsets.right)",
            "islandScreen.auxiliaryTopLeftArea: \(screen.auxiliaryTopLeftArea.map { format($0) } ?? "nil")",
            "islandScreen.auxiliaryTopRightArea: \(screen.auxiliaryTopRightArea.map { format($0) } ?? "nil")",
            "backingScaleFactor: \(screen.backingScaleFactor)",
            "hasPhysicalNotch: \(layout.hasPhysicalNotch)",
            "notchFrame: \(format(layout.notchFrame.rect))",
            "collapsedShapeSize: \(Int(layout.collapsedSize.width)) x \(Int(layout.collapsedSize.height))",
            "compactShapeSize: \(Int(layout.compactSize.width)) x \(Int(layout.compactSize.height))",
            "expandedShapeSize: \(Int(layout.expandedSize.width)) x \(Int(layout.expandedSize.height))",
            "collapsedPanelFrame: \(format(layout.panelFrame(for: .collapsed)))",
            "compactPanelFrame: \(format(layout.panelFrame(for: .compact)))",
            "expandedPanelFrame: \(format(layout.panelFrame(for: .expanded)))",
            "currentNSPanelFrame: \(panelFrame.map(format) ?? "none")",
            "currentNSWindowLevel: \(notchShelfWindowController.currentWindowLevelDescription)",
            "mouseLocation: \(formatPoint(mouseLocation))",
            "presentationState: \(notchIslandActivityCenter.presentationState.rawValue)",
            "hoverState: \(notchHoverState.rawValue)",
            "hoverDiagnostics: \(notchHoverDiagnostics.joined(separator: " | "))",
            "classicShelfEnabled: \(notchConfig.enabled && notchConfig.preferredStyle == .classicShelf)",
            "notchIslandModeEnabled: \(notchConfig.enabled && notchConfig.preferredStyle == .island)",
            "fallbackReason: \(layout.fallbackReason ?? "none")"
        ]
        let text = lines.joined(separator: "\n")

        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
        append(.success("Notch Geometry", "Copied Notch Island geometry debug info.", details: [
            "Notch: \(format(layout.notchFrame.rect))",
            "Panel: \(panelFrame.map(format) ?? "none")",
            "Level: \(notchShelfWindowController.currentWindowLevelDescription)"
        ]))
    }

    func disableNotchIslandFromSafety() {
        notchConfig.enabled = false
        notchConfig.preferredStyle = .island
        resetHoverState()
        notchIslandActivityCenter.hide()
        append(.success("Notch Island", "Disabled Notch Island."))
    }

    func clearLiveIslandState() {
        liveIslandCoordinator.clearTransientState()
        notchIslandActivityCenter.clearActivity()
        append(.success("Live Island", "Cleared transient activity and provider test state."))
    }

    // MARK: - Agent activity

    func showAgentActivityTest() {
        agentActivityCenter.injectTestActivity()
        if notchConfig.enabled, notchConfig.preferredStyle == .island, notchIslandActivityCenter.presentationState == .collapsed {
            notchIslandActivityCenter.presentationState = .compact
        }
        record(.success("Agent Activity", "Injected a demo Claude Code task to preview the split notch."))
    }

    func clearAgentActivity() {
        agentActivityCenter.clearAll()
        append(.success("Agent Activity", "Cleared agent and CLI activity."))
    }

    func revealAgentEventLog() {
        let url = agentActivityCenter.eventsURL
        if !FileManager.default.fileExists(atPath: url.path) {
            FileManager.default.createFile(atPath: url.path, contents: nil)
        }
        NSWorkspace.shared.activateFileViewerSelecting([url])
        record(.success("Agent Activity", "Revealed the agent event log at \(url.path)."))
    }

    func copyAgentEventLogPath() {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(agentActivityCenter.eventsURL.path, forType: .string)
        append(.success("Agent Activity", "Copied the agent event log path to the clipboard."))
    }

    func restoreDockManagedSettings() async {
        let wasEnabled = experimentalDockTweaksEnabled
        if !experimentalDockTweaksEnabled {
            experimentalDockTweaksEnabled = true
        }

        let results = await recoveryService.restoreDockManagedKeys()
        dockSettings = .default

        if !wasEnabled {
            experimentalDockTweaksEnabled = false
        }

        results.forEach(append)
    }

    func panicResetMacForgeRuntime() async {
        notchConfig.enabled = false
        notchConfig.preferredStyle = .island
        resetNotchConfigToSafeDefaults()
        liveIslandCoordinator.clearTransientState()
        agentActivityCenter.clearAll()
        resetHoverState()
        notchIslandActivityCenter.hide()
        liveIslandSettings = .default
        dockSettings = .default

        let results = await recoveryService.restoreDockManagedKeys()
        experimentalDockTweaksEnabled = false

        append(.success("Panic Reset", "Disabled Notch Island, cleared Live Island state, reset layout, and disabled Experimental Dock Tweaks."))
        results.forEach(append)
    }

    func addNotchFileTrayItem(_ url: URL) {
        guard url.isFileURL else { return }
        notchTrayItems.removeAll { $0.path == url.path }
        notchTrayItems.insert(NotchTrayItem(url: url), at: 0)
        notchTrayItems = Array(notchTrayItems.prefix(24))
        notchIslandActivityCenter.showActivity(
            kind: .folder,
            title: "Tray",
            message: url.lastPathComponent,
            symbolName: "tray.and.arrow.down",
            duration: notchConfig.autoCollapseDelay
        )
    }

    func clearNotchFileTray() {
        notchTrayItems = []
        append(.success("Tray", "Cleared temporary tray."))
    }

    func removeNotchTrayItem(_ item: NotchTrayItem) {
        notchTrayItems.removeAll { $0.id == item.id }
    }

    func openNotchTrayItem(_ item: NotchTrayItem) {
        guard let url = item.resolveURL() else {
            removeNotchTrayItem(item)
            append(.failure("Tray", "\(item.name) is no longer available and was removed from the tray."))
            return
        }
        NSWorkspace.shared.open(url)
    }

    func revealNotchTrayItem(_ item: NotchTrayItem) {
        guard let url = item.resolveURL() else {
            removeNotchTrayItem(item)
            append(.failure("Tray", "\(item.name) is no longer available and was removed from the tray."))
            return
        }
        NSWorkspace.shared.activateFileViewerSelecting([url])
    }

    /// Hands tray files to AirDrop. Passing every resolvable item at once
    /// mirrors the system share flow users expect from a shelf.
    func airDropNotchTrayItems(_ items: [NotchTrayItem]) {
        let urls = items.compactMap { $0.resolveURL() }
        guard !urls.isEmpty else {
            append(.failure("AirDrop", "None of the selected tray files are available."))
            return
        }
        guard let service = NSSharingService(named: .sendViaAirDrop), service.canPerform(withItems: urls) else {
            append(.failure("AirDrop", "AirDrop is not available right now."))
            return
        }
        service.perform(withItems: urls)
    }

    /// Applies the configurable retention window. A zero window keeps files
    /// until the user removes them.
    func pruneExpiredTrayItems(now: Date = Date()) {
        let pruned = Self.prunedTrayItems(notchTrayItems, retentionMinutes: trayRetentionMinutes, now: now)
        if pruned.count != notchTrayItems.count {
            notchTrayItems = pruned
        }
    }

    static func prunedTrayItems(_ items: [NotchTrayItem], retentionMinutes: Double, now: Date) -> [NotchTrayItem] {
        guard retentionMinutes > 0 else { return items }
        let cutoff = now.addingTimeInterval(-retentionMinutes * 60)
        return items.filter { $0.addedAt >= cutoff }
    }

    func addPinnedFolder() {
        guard let url = fileAccessPermissionService.chooseFolder() else { return }
        switch folderAccessStore.makeShortcut(for: url) {
        case .success(let shortcut):
            pinnedFolders.append(shortcut)
            append(.success("Pinned Folder", "Added \(shortcut.name)."))
        case .failure(let error):
            append(.failure("Pinned Folder", "Could not save folder access.", details: [error.localizedDescription]))
        }
    }

    func forgetFolder(_ shortcut: FolderShortcut) {
        pinnedFolders.removeAll { $0.id == shortcut.id }
        append(.success("Forget Folder", "Removed \(shortcut.name) from MacForge."))
    }

    func openFolder(_ shortcut: FolderShortcut) {
        notchIslandActivityCenter.showActivity(
            kind: .folder,
            title: "Open Folder",
            message: shortcut.name,
            symbolName: "folder",
            duration: notchConfig.autoCollapseDelay
        )
        append(folderAccessStore.open(shortcut))
    }

    func revealFolder(_ shortcut: FolderShortcut) {
        append(folderAccessStore.reveal(shortcut))
    }

    func addWallpaperPreset() {
        guard let url = fileAccessPermissionService.chooseImage() else { return }
        let name = url.deletingPathExtension().lastPathComponent
        append(wallpaperService.makePreset(name: name, imageURL: url, targetBehavior: .allScreens))
    }

    func applyWallpaperPreset(_ preset: WallpaperPreset) async {
        notchIslandActivityCenter.showActivity(
            kind: .wallpaper,
            title: "Wallpaper Apply",
            message: preset.name,
            symbolName: "photo",
            duration: nil
        )
        append(await wallpaperService.apply(preset))
        refreshWallpaperStates()
    }

    func refreshWallpaperStates() {
        wallpaperStates = wallpaperService.currentWallpaperStates()
    }

    func refreshWindows() async {
        // Don't spam the notch/log with the accessibility error on the
        // automatic launch refresh — the Permissions and Windows screens
        // already show a grant affordance, and launch prompts for approval.
        guard permissionCenter.accessibilityGranted else {
            windows = []
            return
        }
        let (windowInfos, results) = await windowService.listWindows()
        windows = windowInfos
        results.forEach(append)
    }

    func tileFocusedWindow(_ layout: WindowLayoutType) async {
        guard requireAccessibility(for: "arrange windows") else { return }
        notchIslandActivityCenter.showActivity(
            kind: .windowAction,
            title: "Window Action",
            message: layout.label,
            symbolName: layout.symbolName,
            duration: notchConfig.autoCollapseDelay
        )
        append(await windowService.tileFocusedWindow(layout, customGrid: nil))
        await refreshWindows()
    }

    func moveFocusedWindowToNextDisplay() async {
        guard requireAccessibility(for: "move windows between displays") else { return }
        notchIslandActivityCenter.showActivity(
            kind: .windowAction,
            title: "Window Action",
            message: "Moving to next display",
            symbolName: "rectangle.on.rectangle",
            duration: notchConfig.autoCollapseDelay
        )
        append(await windowService.moveFocusedWindowToNextDisplay())
        await refreshWindows()
    }

    /// Ensures Accessibility is granted before a window action. When missing,
    /// opens the macOS approval prompt (system dialog + Settings) and shows a
    /// friendly notch card instead of a hard error, then returns false.
    @discardableResult
    func requireAccessibility(for action: String) -> Bool {
        if permissionCenter.accessibilityGranted { return true }
        permissionCenter.requestAccessibility()
        refreshPermissions()
        notchIslandActivityCenter.showActivity(
            kind: .permission,
            title: "Accessibility needed",
            message: "Approve MacForge in System Settings to \(action).",
            symbolName: "lock.shield",
            duration: notchConfig.autoCollapseDelay
        )
        record(.success("Accessibility", "Opened the approval prompt so you can allow MacForge to \(action)."))
        return false
    }

    func promptForAccessibilityIfNeeded() {
        guard !permissionCenter.accessibilityGranted else { return }
        let key = "MacForgeDidOpenAccessibilityApproval"
        if UserDefaults.standard.bool(forKey: key) {
            // Seen the approval flow already this install — just re-show the
            // lightweight system dialog so we don't yank focus to Settings.
            permissionCenter.promptAccessibilityDialog()
        } else {
            // First launch without access: take the user straight to the
            // approval screen so they can toggle MacForge on.
            UserDefaults.standard.set(true, forKey: key)
            permissionCenter.requestAccessibility()
        }
    }

    func applyDockSettings() async {
        notchIslandActivityCenter.showActivity(
            kind: .dock,
            title: "Dock Apply",
            message: "Applying Dock settings",
            symbolName: "dock.rectangle",
            duration: nil
        )
        let results = await dockSettingsService.apply(dockSettings, experimentalTweaksEnabled: experimentalDockTweaksEnabled)
        results.forEach(append)
    }

    func resetDockSettings() async {
        notchIslandActivityCenter.showActivity(
            kind: .dock,
            title: "Dock Reset",
            message: "Restoring Dock defaults",
            symbolName: "dock.rectangle",
            duration: nil
        )
        let results = await dockSettingsService.resetToSystemDefaults(experimentalTweaksEnabled: experimentalDockTweaksEnabled)
        results.forEach(append)
    }

    func createFolderTemplate(named template: FolderTemplate, in shortcut: FolderShortcut) {
        notchIslandActivityCenter.showActivity(
            kind: .folder,
            title: "Folder Template",
            message: template.label,
            symbolName: "folder.badge.plus",
            duration: nil
        )
        let result = folderAccessStore.withResolvedURL(shortcut) { root in
            let folderName = "\(template.label) \(Date().formatted(.dateTime.year().month(.twoDigits).day(.twoDigits)))"
            let rootURL = root.appendingPathComponent(folderName, isDirectory: true)

            do {
                for path in template.paths {
                    try FileManager.default.createDirectory(at: rootURL.appendingPathComponent(path, isDirectory: true), withIntermediateDirectories: true)
                }
                return CommandResult.success("Folder Template", "Created \(folderName).")
            } catch {
                return CommandResult.failure("Folder Template", "Could not create template folders.", details: [error.localizedDescription])
            }
        }
        append(result)
    }

    func previewFileRule(_ rule: FileRule) -> FileRuleOperationResult<[FileRulePreview]> {
        withFileRuleAccess(rule) { sourceURL, destinationResolver in
            fileOrganizerService.preview(rule: rule, sourceURL: sourceURL, destinationResolver: destinationResolver)
        }
    }

    func applyFileRule(_ rule: FileRule, dryRun: Bool = false) -> [CommandResult] {
        notchIslandActivityCenter.showActivity(
            kind: .fileRule,
            title: dryRun || rule.dryRunOnly ? "File Rule Preview" : "File Rule Apply",
            message: rule.name,
            symbolName: "line.3.horizontal.decrease.circle",
            duration: nil
        )
        switch withFileRuleAccess(rule, perform: { sourceURL, destinationResolver in
            let previews = fileOrganizerService.preview(rule: rule, sourceURL: sourceURL, destinationResolver: destinationResolver)
            return fileOrganizerService.apply(previews: previews, rule: rule, dryRun: dryRun)
        }) {
        case .success(let results):
            return results
        case .failure(let result):
            return [result]
        }
    }

    func runPreset(_ preset: AppPreset) async {
        notchIslandActivityCenter.showActivity(
            kind: .preset,
            title: "Running Preset",
            message: preset.name,
            symbolName: preset.iconName,
            duration: nil
        )
        let context = PresetExecutionContext(
            runAction: { [weak self] action in
                guard let self else { return .failure("Preset", "MacForge environment was unavailable.") }
                return await self.runPresetAction(action)
            },
            snapshotState: { [weak self] in
                guard let self else { return [:] }
                return [
                    "Notch Shelf": self.notchConfig.enabled ? "enabled" : "disabled",
                    "Dock Auto-hide": self.dockSettings.autoHide ? "enabled" : "disabled",
                    "Wallpaper Presets": "\(self.wallpaperPresets.count)"
                ]
            },
            rollbackSnapshot: { [weak self] in
                self?.captureRollbackSnapshot() ?? RollbackSnapshot()
            }
        )

        let transaction = await presetRunner.run(preset, context: context)
        lastPresetTransaction = transaction
        if let index = appPresets.firstIndex(where: { $0.id == preset.id }) {
            appPresets[index].lastRunDate = Date()
        }
        append(.success("Preset", "Finished \(preset.name).", details: transaction.results.map { "\($0.title): \($0.message)" }, reversible: transaction.rollbackAvailable))
    }

    func rollbackLastPreset() async {
        guard let transaction = lastPresetTransaction else {
            append(.failure("Rollback", "No preset has been run in this session."))
            return
        }

        let context = PresetRollbackContext(
            restoreNotchShelf: { [weak self] enabled in
                guard let self else { return .failure("Notch Shelf Rollback", "MacForge environment was unavailable.") }
                self.notchConfig.enabled = enabled
                return .success("Notch Shelf Rollback", enabled ? "Shelf restored to shown." : "Shelf restored to hidden.")
            },
            restoreDockSettings: { [weak self] settings in
                guard let self else { return [.failure("Dock Rollback", "MacForge environment was unavailable.")] }
                guard self.experimentalDockTweaksEnabled else {
                    return [.failure("Dock Rollback", "Experimental Dock Tweaks must be enabled before Dock settings can be restored.")]
                }
                self.dockSettings = settings
                return await self.dockSettingsService.apply(settings, experimentalTweaksEnabled: self.experimentalDockTweaksEnabled)
            },
            restoreWallpapers: { [weak self] states in
                guard let self else { return [.failure("Wallpaper Rollback", "MacForge environment was unavailable.")] }
                let results = await self.wallpaperService.restore(states)
                self.refreshWallpaperStates()
                return results
            }
        )

        let results = await rollbackManager.rollback(transaction, context: context)
        results.forEach(append)
    }

    private func startCommandBusObservation() {
        NotificationCenter.default.publisher(for: MacForgeCommandBus.didEnqueueNotification)
            .sink { [weak self] _ in
                Task { @MainActor in
                    self?.processPendingCommandRequests()
                }
            }
            .store(in: &cancellables)

        Timer.publish(every: 1.0, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                self?.processPendingCommandRequests()
                self?.notchIslandActivityCenter.autoCollapseIfNeeded()
                self?.syncNotchIslandPresentation()
                self?.pruneExpiredTrayItems()
            }
            .store(in: &cancellables)

        processPendingCommandRequests()
    }

    private func processPendingCommandRequests() {
        let requests = MacForgeCommandBus.shared.drain()
        guard !requests.isEmpty else { return }
        requests.forEach(handleCommandRequest)
    }

    private func handleCommandRequest(_ request: MacForgeCommandRequest) {
        switch request.kind {
        case .toggleNotchShelf:
            toggleNotchShelf()
            append(.success("Shortcuts", "Toggled Notch Shelf."))
        case .tileFocusedWindow(let rawLayout):
            guard let layout = WindowLayoutType(rawValue: rawLayout), layout != .customGrid else {
                append(.failure("Shortcuts", "Unsupported window layout requested.", details: [rawLayout]))
                return
            }
            Task { await tileFocusedWindow(layout) }
        case .openPinnedFolder(let folderName):
            guard let shortcut = pinnedFolders.first(where: { $0.name.localizedCaseInsensitiveCompare(folderName) == .orderedSame }) else {
                append(.failure("Shortcuts", "Pinned folder was not found.", details: [folderName]))
                return
            }
            openFolder(shortcut)
        case .applyPreset(let presetName):
            guard let preset = appPresets.first(where: { $0.name.localizedCaseInsensitiveCompare(presetName) == .orderedSame }) else {
                append(.failure("Shortcuts", "Preset was not found.", details: [presetName]))
                return
            }
            Task { await runPreset(preset) }
        }
    }

    func exportConfiguration() -> CommandResult {
        let panel = NSSavePanel()
        panel.nameFieldStringValue = "MacForge Configuration.json"
        panel.allowedContentTypes = [.json]
        guard panel.runModal() == .OK, let url = panel.url else {
            return .failure("Export Configuration", "Export cancelled.")
        }

        do {
            try currentConfigurationData().write(to: url)
            return .success("Export Configuration", "Saved configuration to \(url.lastPathComponent).")
        } catch {
            return .failure("Export Configuration", "Could not export configuration.", details: [error.localizedDescription])
        }
    }

    func importConfiguration() -> CommandResult {
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        panel.allowedContentTypes = [.json]
        guard panel.runModal() == .OK, let url = panel.url else {
            return .failure("Import Configuration", "Import cancelled.")
        }

        do {
            let data = try Data(contentsOf: url)
            var configuration = try JSONDecoder.macForge.decode(MacForgeConfiguration.self, from: data)
            let version = configuration.schemaVersion ?? 1
            guard version <= MacForgeConfiguration.currentSchemaVersion else {
                return .failure(
                    "Import Configuration",
                    "This file was exported by a newer MacForge (schema v\(version)); this build supports up to v\(MacForgeConfiguration.currentSchemaVersion)."
                )
            }
            if version < MacForgeConfiguration.currentSchemaVersion {
                Self.migrate(&configuration, from: version)
            }
            apply(configuration)
            return .success("Import Configuration", "Imported configuration (schema v\(version)).")
        } catch {
            return .failure("Import Configuration", "Could not import configuration.", details: [error.localizedDescription])
        }
    }

    func resetPreferences() {
        notchConfig = .default
        liveIslandSettings = .default
        dockSettings = .default
        pinnedFolders = []
        wallpaperPresets = []
        appPresets = AppPreset.examples
        fileRules = []
        safetyConfirmationsEnabled = true
        experimentalDockTweaksEnabled = false
        showInDock = true
        notchTrayItems = []
        trayRetentionMinutes = 0
        append(.success("Reset Preferences", "MacForge preferences were reset. System settings were not changed."))
    }

    /// Turns the calendar agenda widget on, requesting Calendars access only
    /// at this moment — the permission stays tied to the feature.
    func setCalendarAgendaEnabled(_ enabled: Bool) {
        guard enabled else {
            liveIslandSettings.calendarAgendaEnabled = false
            refreshPermissions()
            return
        }

        Task { @MainActor in
            let granted = CalendarAgendaProvider.hasFullAccess ? true : await CalendarAgendaProvider.requestAccess()
            if granted {
                liveIslandSettings.calendarAgendaEnabled = true
                append(.success("Calendar", "Calendar agenda is now shown in the island before events start."))
            } else {
                liveIslandSettings.calendarAgendaEnabled = false
                append(.failure(
                    "Calendar",
                    "Calendar access was not granted.",
                    details: ["Allow MacForge under System Settings > Privacy & Security > Calendars, then turn the widget on again."]
                ))
            }
            refreshPermissions()
        }
    }

    func previewVolumeHUD() {
        volumeHUDCenter.publishCurrentLevel()
    }

    func chooseLiveIslandDownloadsFolder() {
        guard let url = fileAccessPermissionService.chooseFolder() else { return }
        do {
            try liveIslandSettings.setDownloadsFolder(url)
            append(.success("Downloads Watcher", "Watching \(url.lastPathComponent)."))
        } catch {
            append(.failure("Downloads Watcher", "Could not save folder access.", details: [error.localizedDescription]))
        }
    }

    func clearLiveIslandDownloadsFolder() {
        liveIslandSettings.clearDownloadsFolder()
        append(.success("Downloads Watcher", "Downloads folder access was cleared."))
    }

    func startLiveIslandTimer(minutes: Int) {
        liveIslandCoordinator.startTimer(minutes: minutes)
        append(.success("Timer", "Started \(minutes)-minute timer."))
    }

    func showLiveIslandTestSnapshot(kind: LiveIslandSnapshotKind) {
        liveIslandCoordinator.showTestSnapshot(kind: kind)
        if notchConfig.enabled, notchConfig.preferredStyle == .island, notchIslandActivityCenter.presentationState != .expanded {
            notchIslandActivityCenter.presentationState = .compact
        }
    }

    func runLiveIslandSelfTest() {
        liveIslandCoordinator.showTestSnapshot(kind: .music)
        if notchConfig.enabled, notchConfig.preferredStyle == .island, notchIslandActivityCenter.presentationState != .expanded {
            notchIslandActivityCenter.presentationState = .compact
        }
        record(.success("Live Island Self-Test", "Injected a temporary media snapshot to verify the coordinator-to-island UI path."))
    }

    func testAppleMusicProvider() async {
        guard let provider = liveIslandCoordinator.providers.first(where: { $0.id == AppleMusicProvider.providerID }) else {
            record(.failure("Apple Music Provider", "The Apple Music provider is not configured."))
            return
        }

        let snapshot = await provider.snapshot(settings: liveIslandSettings, now: Date())
        await liveIslandCoordinator.refresh()

        if let snapshot {
            if notchConfig.enabled, notchConfig.preferredStyle == .island, notchIslandActivityCenter.presentationState != .expanded {
                notchIslandActivityCenter.presentationState = .compact
            }
            record(.success("Apple Music Provider", "Read \(snapshot.title).", details: [snapshot.subtitle].filter { !$0.isEmpty }))
            return
        }

        if let diagnostic = provider.latestDiagnostic {
            let details = [
                "Status: \(diagnostic.status)",
                "App: \(diagnostic.appStatus)",
                diagnostic.lastError.map { "Error: \($0)" },
                diagnostic.rawResultSummary.map { "Raw: \($0)" }
            ].compactMap { $0 }
            record(.failure("Apple Music Provider", diagnostic.permissionNeeded ? "Automation permission is needed." : "No playable Music track was available.", details: details))
        } else {
            record(.failure("Apple Music Provider", "No diagnostic was returned."))
        }
    }

    func openMusicApp() {
        guard let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: "com.apple.Music") else {
            append(.failure("Apple Music", "Music.app was not found."))
            return
        }

        NSWorkspace.shared.open(url)
        append(.success("Apple Music", "Opened Music."))
    }

    func openAutomationSettings() {
        guard let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Automation") else {
            append(.failure("Automation Settings", "Could not build the System Settings URL."))
            return
        }

        NSWorkspace.shared.open(url)
        append(.success("Automation Settings", "Opened Privacy & Security Automation settings."))
    }

    func handleNotchHoverChanged(_ isHovering: Bool) {
        guard notchConfig.enabled,
              notchConfig.preferredStyle == .island,
              notchConfig.expandOnHover else {
            return
        }

        let actions = isHovering
            ? hoverStateMachine.pointerEntered(calibrationMode: notchConfig.calibrationModeEnabled)
            : hoverStateMachine.pointerExited(calibrationMode: notchConfig.calibrationModeEnabled)
        applyHoverActions(actions, event: isHovering ? "hover entered" : "hover exited")
    }

    func toggleNotchIslandExpansionByClick() {
        guard notchConfig.expandOnClick else { return }
        let actions = hoverStateMachine.clickToggle(
            isExpanded: notchIslandActivityCenter.presentationState == .expanded,
            calibrationMode: notchConfig.calibrationModeEnabled
        )
        applyHoverActions(actions, event: "click toggle")
    }

    private func handleHoverExpandDelayElapsed() {
        let actions = hoverStateMachine.hoverDelayElapsed(calibrationMode: notchConfig.calibrationModeEnabled)
        applyHoverActions(actions, event: "hover expand delay elapsed")
    }

    private func handleHoverCollapseDelayElapsed() {
        let actions = hoverStateMachine.collapseDelayElapsed(calibrationMode: notchConfig.calibrationModeEnabled)
        applyHoverActions(actions, event: "hover collapse delay elapsed")
    }

    private func applyHoverActions(_ actions: [NotchHoverAction], event: String) {
        notchHoverState = hoverStateMachine.state
        recordHoverDiagnostic(event)

        for action in actions {
            switch action {
            case .scheduleExpand:
                hoverExpandTask?.cancel()
                hoverExpandTask = Task { [weak self] in
                    try? await Task.sleep(nanoseconds: 120_000_000)
                    guard !Task.isCancelled else { return }
                    await MainActor.run {
                        self?.handleHoverExpandDelayElapsed()
                    }
                }
            case .scheduleCollapse:
                hoverCollapseTask?.cancel()
                hoverCollapseTask = Task { [weak self] in
                    try? await Task.sleep(nanoseconds: 400_000_000)
                    guard !Task.isCancelled else { return }
                    await MainActor.run {
                        self?.handleHoverCollapseDelayElapsed()
                    }
                }
            case .cancelExpand:
                hoverExpandTask?.cancel()
                hoverExpandTask = nil
            case .cancelCollapse:
                hoverCollapseTask?.cancel()
                hoverCollapseTask = nil
            case .expand:
                guard notchIslandActivityCenter.presentationState != .expanded else { continue }
                notchIslandActivityCenter.expand()
            case .collapse:
                if liveIslandCoordinator.currentSnapshot.kind != .idle {
                    notchIslandActivityCenter.presentationState = .compact
                } else {
                    notchIslandActivityCenter.collapse()
                }
            }
        }

        notchHoverState = hoverStateMachine.state
    }

    private func resetHoverState() {
        applyHoverActions(hoverStateMachine.reset(), event: "hover reset")
    }

    private func recordHoverDiagnostic(_ event: String) {
        let line = "\(Date().formatted(date: .omitted, time: .standard)) \(event) -> \(hoverStateMachine.state.rawValue)"
        notchHoverDiagnostics.insert(line, at: 0)
        notchHoverDiagnostics = Array(notchHoverDiagnostics.prefix(8))
    }

    func append(_ result: CommandResult) {
        record(result)
        if notchConfig.enabled, notchConfig.preferredStyle == .island {
            notchIslandActivityCenter.showCommandResult(result, autoCollapseDelay: notchConfig.autoCollapseDelay)
        }
    }

    private func record(_ result: CommandResult) {
        commandResults.insert(result, at: 0)
        commandResults = Array(commandResults.prefix(60))
    }

    private func runPresetAction(_ action: PresetAction) async -> CommandResult {
        switch action {
        case .toggleNotchShelf(let enabled):
            notchConfig.enabled = enabled
            return .success("Notch Shelf", enabled ? "Shelf shown." : "Shelf hidden.", reversible: true)
        case .applyDockSettings(let settings):
            dockSettings = settings
            let results = await dockSettingsService.apply(settings, experimentalTweaksEnabled: experimentalDockTweaksEnabled)
            return results.last ?? .success("Dock Settings", "No Dock commands were needed.")
        case .applyWallpaperPreset(let id):
            guard let preset = wallpaperPresets.first(where: { $0.id == id }) else {
                return .failure("Wallpaper", "Wallpaper preset was not found.")
            }
            return await wallpaperService.apply(preset)
        case .applyWindowLayout(let preset):
            return await windowService.tileFocusedWindow(preset.layoutType, customGrid: preset.customGrid)
        case .openFolder(let id):
            guard let shortcut = pinnedFolders.first(where: { $0.id == id }) else {
                return .failure("Open Folder", "Pinned folder was not found.")
            }
            return folderAccessStore.open(shortcut)
        case .runFileRule(let id, let dryRun):
            guard let rule = fileRules.first(where: { $0.id == id }) else {
                return .failure("File Rule", "The file rule is missing a source folder.")
            }
            let results = applyFileRule(rule, dryRun: dryRun || rule.dryRunOnly)
            return results.first ?? .success("File Rule", "No files matched.")
        }
    }

    private func captureRollbackSnapshot() -> RollbackSnapshot {
        RollbackSnapshot(
            notchShelfEnabled: notchConfig.enabled,
            dockSettings: dockSettings,
            wallpaperStates: wallpaperService.currentWallpaperStates()
        )
    }

    private func withFileRuleAccess<T>(
        _ rule: FileRule,
        perform work: (URL, (UUID) -> URL?) -> T
    ) -> FileRuleOperationResult<T> {
        guard let sourceID = rule.sourceFolderID,
              let sourceShortcut = pinnedFolders.first(where: { $0.id == sourceID }) else {
            return .failure(CommandResult.failure("File Rule", "The file rule is missing a source folder."))
        }

        let fallbackResolver: (UUID) -> URL? = { [weak self] folderID in
            guard let self,
                  let shortcut = self.pinnedFolders.first(where: { $0.id == folderID }) else {
                return nil
            }
            return self.folderAccessStore.resolve(shortcut)
        }

        if let destinationID = rule.action.destinationFolderID {
            guard let destinationShortcut = pinnedFolders.first(where: { $0.id == destinationID }) else {
                return .failure(CommandResult.failure("File Rule", "The destination folder is missing."))
            }

            let value = folderAccessStore.withResolvedURL(sourceShortcut) { sourceURL in
                folderAccessStore.withResolvedURL(destinationShortcut) { destinationURL in
                    let resolver: (UUID) -> URL? = { folderID in
                        folderID == destinationID ? destinationURL : fallbackResolver(folderID)
                    }
                    return work(sourceURL, resolver)
                }
            }
            return .success(value)
        }

        let value = folderAccessStore.withResolvedURL(sourceShortcut) { sourceURL in
            work(sourceURL, fallbackResolver)
        }
        return .success(value)
    }

    private func updateShelfAndPersist() {
        guard !isLoading else { return }
        if !notchConfig.enabled {
            notchIslandActivityCenter.hide()
        } else if notchIslandActivityCenter.presentationState == .hidden {
            notchIslandActivityCenter.collapse()
        }
        updateNotchShelf()
        persist()
    }

    private func startNotchIslandObservation() {
        notchIslandActivityCenter.$presentationState
            .removeDuplicates()
            .sink { [weak self] _ in
                Task { @MainActor in
                    self?.updateNotchShelf()
                }
            }
            .store(in: &cancellables)

        liveIslandCoordinator.$currentSnapshot
            .removeDuplicates()
            .sink { [weak self] snapshot in
                Task { @MainActor in
                    self?.syncNotchIslandPresentation(with: snapshot)
                }
            }
            .store(in: &cancellables)

        // Agent/CLI activity surfaces the island (split with media) the same
        // way live media does.
        agentActivityCenter.$activities
            .map { $0.count }
            .removeDuplicates()
            .sink { [weak self] _ in
                Task { @MainActor in
                    self?.syncNotchIslandPresentation()
                }
            }
            .store(in: &cancellables)

        NotificationCenter.default.publisher(for: NSApplication.didChangeScreenParametersNotification)
            .sink { [weak self] _ in
                Task { @MainActor in
                    self?.updateNotchShelf()
                }
            }
            .store(in: &cancellables)
    }

    /// Coalesces bursts of changes (calibration drags, config imports) into a
    /// single disk write instead of re-encoding the whole file on every
    /// property change on the main thread.
    private func persist() {
        guard !isLoading else { return }
        persistTask?.cancel()
        persistTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 400_000_000)
            guard !Task.isCancelled else { return }
            self?.persistNow()
        }
    }

    private func flushPendingPersist() {
        guard persistTask != nil else { return }
        persistNow()
    }

    func persistNow() {
        guard !isLoading else { return }
        persistTask?.cancel()
        persistTask = nil
        do {
            try currentConfigurationData().write(to: configurationURL, options: [.atomic])
        } catch {
            commandResults.insert(.failure("Preferences", "Could not save preferences.", details: [error.localizedDescription]), at: 0)
        }
    }

    private func syncNotchIslandPresentation(with snapshot: LiveIslandSnapshot? = nil) {
        guard notchConfig.enabled,
              notchConfig.preferredStyle == .island else {
            return
        }
        guard !notchConfig.forceAttachedNotchTestMode else {
            updateNotchShelf()
            return
        }

        let snapshot = snapshot ?? liveIslandCoordinator.currentSnapshot
        let mediaActive = snapshot.kind != .idle && snapshot.priority >= .backgroundMedia
        let agentActive = agentActivityCenter.hasActivity
        let shouldUseCompact = mediaActive || agentActive

        switch notchIslandActivityCenter.presentationState {
        case .hidden:
            return
        case .expanded:
            updateNotchShelf()
        case .collapsed where shouldUseCompact:
            notchIslandActivityCenter.presentationState = .compact
        case .compact where !shouldUseCompact && notchIslandActivityCenter.currentActivity == nil:
            notchIslandActivityCenter.collapse()
        default:
            updateNotchShelf()
        }
    }

    private func resetNotchConfigToSafeDefaults() {
        notchConfig.hardResetVisualState(keepEnabled: true)
        notchConfig.ignoreMouseEventsWhenInactive = false
    }

    private func format(_ rect: CGRect) -> String {
        "x \(Int(rect.origin.x)), y \(Int(rect.origin.y)), w \(Int(rect.width)), h \(Int(rect.height))"
    }

    private func formatPoint(_ point: CGPoint) -> String {
        "x \(Int(point.x)), y \(Int(point.y))"
    }

    private func currentConfigurationData() throws -> Data {
        try JSONEncoder.macForge.encode(MacForgeConfiguration(
            schemaVersion: MacForgeConfiguration.currentSchemaVersion,
            notchConfig: notchConfig,
            liveIslandSettings: liveIslandSettings,
            dockSettings: dockSettings,
            pinnedFolders: pinnedFolders,
            wallpaperPresets: wallpaperPresets,
            appPresets: appPresets,
            fileRules: fileRules,
            safetyConfirmationsEnabled: safetyConfirmationsEnabled,
            experimentalDockTweaksEnabled: experimentalDockTweaksEnabled,
            showInDock: showInDock,
            notchTrayItems: notchTrayItems,
            trayRetentionMinutes: trayRetentionMinutes,
            hasCompletedOnboarding: hasCompletedOnboarding,
            activeTimer: activeLiveTimer
        ))
    }

    private func apply(_ configuration: MacForgeConfiguration) {
        notchConfig = configuration.notchConfig
        liveIslandSettings = configuration.liveIslandSettings ?? .default
        dockSettings = configuration.dockSettings
        pinnedFolders = configuration.pinnedFolders
        wallpaperPresets = configuration.wallpaperPresets
        appPresets = configuration.appPresets
        fileRules = configuration.fileRules
        safetyConfirmationsEnabled = configuration.safetyConfirmationsEnabled
        experimentalDockTweaksEnabled = configuration.experimentalDockTweaksEnabled
        showInDock = configuration.showInDock
        trayRetentionMinutes = configuration.trayRetentionMinutes ?? 0
        notchTrayItems = Self.prunedTrayItems(configuration.notchTrayItems ?? [], retentionMinutes: trayRetentionMinutes, now: Date())
        hasCompletedOnboarding = configuration.hasCompletedOnboarding ?? true
        persistNow()
    }

    private static func loadConfiguration(from url: URL) -> ConfigurationLoadOutcome {
        guard FileManager.default.fileExists(atPath: url.path) else { return .fresh }
        guard let data = try? Data(contentsOf: url) else {
            return .failed(backupName: nil, errorDescription: "The configuration file could not be read.")
        }

        do {
            var configuration = try JSONDecoder.macForge.decode(MacForgeConfiguration.self, from: data)
            let version = configuration.schemaVersion ?? 1
            guard version < MacForgeConfiguration.currentSchemaVersion else {
                return .loaded(configuration)
            }
            let backupName = backUpConfigurationFile(at: url, suffix: "v\(version)")
            migrate(&configuration, from: version)
            return .migrated(configuration, fromVersion: version, backupName: backupName)
        } catch {
            let backupName = backUpConfigurationFile(at: url, suffix: "unreadable")
            return .failed(backupName: backupName, errorDescription: error.localizedDescription)
        }
    }

    /// Copies the configuration file aside before a migration or a failed
    /// decode rewrites it, so there is always a manual restore path.
    private static func backUpConfigurationFile(at url: URL, suffix: String) -> String? {
        let backupURL = url.deletingLastPathComponent()
            .appendingPathComponent("configuration.\(suffix).backup.json")
        do {
            if FileManager.default.fileExists(atPath: backupURL.path) {
                try FileManager.default.removeItem(at: backupURL)
            }
            try FileManager.default.copyItem(at: url, to: backupURL)
            return backupURL.lastPathComponent
        } catch {
            return nil
        }
    }

    private static func migrate(_ configuration: inout MacForgeConfiguration, from version: Int) {
        // v1 -> v2 introduced explicit schema versioning, the persistent notch
        // tray, and the onboarding flag. Per-section models already self-heal
        // missing keys via lenient decoding, so no structural transforms are
        // needed. Future migrations chain here in ascending version order.
        configuration.schemaVersion = MacForgeConfiguration.currentSchemaVersion
    }
}

enum FolderTemplate: String, CaseIterable, Identifiable {
    case project
    case client
    case media
    case coding

    var id: String { rawValue }

    var label: String {
        switch self {
        case .project: "Project"
        case .client: "Client"
        case .media: "Media"
        case .coding: "Coding Project"
        }
    }

    var paths: [String] {
        switch self {
        case .project:
            ["Docs", "Assets", "Exports", "Archive"]
        case .client:
            ["Admin", "Briefs", "Deliverables", "Invoices", "Source"]
        case .media:
            ["Audio", "Images", "Video", "Exports"]
        case .coding:
            ["Sources", "Tests", "Docs", "Design"]
        }
    }
}
