import AppKit
import Combine
import Foundation
import UniformTypeIdentifiers

private struct MacForgeConfiguration: Codable {
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
}

enum FileRuleOperationResult<T> {
    case success(T)
    case failure(CommandResult)
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
            liveIslandCoordinator.updateSettings(liveIslandSettings)
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
    @Published var notchFileTrayItems: [URL] = []
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

    private let configurationURL: URL
    private var isLoading = true
    private var cancellables: Set<AnyCancellable> = []

    init() {
        let supportDirectory = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
            .appendingPathComponent("MacForge", isDirectory: true)
        try? FileManager.default.createDirectory(at: supportDirectory, withIntermediateDirectories: true)
        configurationURL = supportDirectory.appendingPathComponent("configuration.json")

        let loaded = Self.loadConfiguration(from: configurationURL)
        var loadedNotchConfig = loaded?.notchConfig ?? .default
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

        wallpaperService.onPresetCreated = { [weak self] preset in
            Task { @MainActor in
                self?.wallpaperPresets.append(preset)
            }
        }

        isLoading = false
        notchIslandActivityCenter.presentationState = notchConfig.enabled ? notchConfig.presentationState : .hidden
        liveIslandCoordinator.configureDefaultProviders(activityCenter: notchIslandActivityCenter)
        liveIslandCoordinator.updateSettings(liveIslandSettings)
        liveIslandCoordinator.start()
        refreshPermissions()
        refreshWallpaperStates()
        startNotchIslandObservation()
        startCommandBusObservation()
        updateShelfAndPersist()
        if repairedAttachedNotchLayout {
            append(.success("Notch Island", "Reset old Notch Island layout to attached defaults."))
        }
    }

    func refreshPermissions() {
        permissionStates = permissionCenter.snapshot(
            folderAccessCount: pinnedFolders.count,
            experimentalDockTweaksEnabled: experimentalDockTweaksEnabled
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
        notchIslandActivityCenter.expand()
    }

    func collapseNotchIsland() {
        notchIslandActivityCenter.collapse()
    }

    func resetNotchIslandLayout() {
        notchConfig.resetToAttachedNotchDefaults(keepEnabled: true)
        notchIslandActivityCenter.collapse()
        append(.success("Notch Island", "Reset island layout to attached notch defaults."))
    }

    func repairNotchIslandLayout() {
        notchConfig.resetToAttachedNotchDefaults(keepEnabled: true)
        liveIslandCoordinator.clearTransientState()
        notchIslandActivityCenter.clearActivity()
        notchIslandActivityCenter.collapse()
        append(.success("Notch Island", "Repaired stale toolbar-style layout and re-anchored the island to the notch."))
    }

    func snapNotchIslandToDetectedNotch() {
        notchConfig.islandHorizontalOffset = 0
        notchConfig.islandVerticalOffset = 0
        notchConfig.overlayMenuBarForAttachedNotch = true
        notchConfig.configVersion = NotchShelfConfig.currentConfigVersion
        notchIslandActivityCenter.collapse()
        append(.success("Notch Island", "Snapped placement to the detected notch geometry."))
    }

    func copyNotchGeometryDebugInfo() {
        guard let screen = NSScreen.main ?? NSScreen.screens.first else {
            append(.failure("Notch Geometry", "No screen was available for geometry diagnostics."))
            return
        }

        let service = NotchGeometryService()
        let metrics = service.metrics(for: screen)
        let geometry = service.attachmentGeometry(metrics: metrics, config: notchConfig)
        let collapsedPanelFrame = service.panelFrame(for: .collapsed, geometry: geometry, config: notchConfig)
        let compactPanelFrame = service.panelFrame(for: .compact, geometry: geometry, config: notchConfig)
        let expandedPanelFrame = service.panelFrame(for: .expanded, geometry: geometry, config: notchConfig)
        let panelFrame = notchShelfWindowController.currentPanelFrame
        let lines = [
            "screenID: \(metrics.screenID)",
            "NSScreen.main.frame: \(format(screen.frame))",
            "NSScreen.main.visibleFrame: \(format(screen.visibleFrame))",
            "NSScreen.main.safeAreaInsets: top \(screen.safeAreaInsets.top), left \(screen.safeAreaInsets.left), bottom \(screen.safeAreaInsets.bottom), right \(screen.safeAreaInsets.right)",
            "NSScreen.main.auxiliaryTopLeftArea: \(screen.auxiliaryTopLeftArea.map { format($0) } ?? "nil")",
            "NSScreen.main.auxiliaryTopRightArea: \(screen.auxiliaryTopRightArea.map { format($0) } ?? "nil")",
            "backingScaleFactor: \(screen.backingScaleFactor)",
            "cameraGapFrame: \(format(geometry.cameraGapFrame.rect))",
            "attachedShellFrame: \(format(geometry.attachedShellFrame.rect))",
            "collapsedContentFrame: \(format(geometry.collapsedContentFrame.rect))",
            "compactContentFrame: \(format(geometry.compactContentFrame.rect))",
            "expandedContentFrame: \(format(geometry.expandedContentFrame.rect))",
            "collapsedPanelFrame: \(format(collapsedPanelFrame))",
            "compactPanelFrame: \(format(compactPanelFrame))",
            "expandedPanelFrame: \(format(expandedPanelFrame))",
            "currentNSPanelFrame: \(panelFrame.map(format) ?? "none")",
            "currentNSWindowLevel: \(notchShelfWindowController.currentWindowLevelDescription)",
            "placementNudgeY: \(notchConfig.islandVerticalOffset)",
            "placementNudgeX: \(notchConfig.islandHorizontalOffset)",
            "attachedShellHeight: \(notchConfig.attachedShellHeight)",
            "overlayMenuBarForAttachedNotch: \(notchConfig.overlayMenuBarForAttachedNotch)",
            "classicShelfEnabled: \(notchConfig.enabled && notchConfig.preferredStyle == .classicShelf)",
            "notchIslandModeEnabled: \(notchConfig.enabled && notchConfig.preferredStyle == .island)",
            "fallbackReason: \(geometry.fallbackReason ?? "none")"
        ]
        let text = lines.joined(separator: "\n")

        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
        append(.success("Notch Geometry", "Copied Notch Island geometry debug info.", details: [
            "Shell: \(format(geometry.attachedShellFrame.rect))",
            "Panel: \(panelFrame.map(format) ?? "none")",
            "Level: \(notchShelfWindowController.currentWindowLevelDescription)"
        ]))
    }

    func disableNotchIslandFromSafety() {
        notchConfig.enabled = false
        notchConfig.preferredStyle = .island
        notchIslandActivityCenter.hide()
        append(.success("Notch Island", "Disabled Notch Island."))
    }

    func clearLiveIslandState() {
        liveIslandCoordinator.clearTransientState()
        notchIslandActivityCenter.clearActivity()
        append(.success("Live Island", "Cleared transient activity and provider test state."))
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
        notchFileTrayItems.removeAll { $0 == url }
        notchFileTrayItems.insert(url, at: 0)
        notchFileTrayItems = Array(notchFileTrayItems.prefix(12))
        notchIslandActivityCenter.showActivity(
            kind: .folder,
            title: "Tray",
            message: url.lastPathComponent,
            symbolName: "tray.and.arrow.down",
            duration: notchConfig.autoCollapseDelay
        )
    }

    func clearNotchFileTray() {
        notchFileTrayItems = []
        append(.success("Tray", "Cleared temporary tray."))
    }

    func revealNotchFileTrayItem(_ url: URL) {
        NSWorkspace.shared.activateFileViewerSelecting([url])
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
        let (windowInfos, results) = await windowService.listWindows()
        windows = windowInfos
        results.forEach(append)
    }

    func tileFocusedWindow(_ layout: WindowLayoutType) async {
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
            let configuration = try JSONDecoder.macForge.decode(MacForgeConfiguration.self, from: data)
            apply(configuration)
            return .success("Import Configuration", "Imported configuration.")
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
        append(.success("Reset Preferences", "MacForge preferences were reset. System settings were not changed."))
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

        NotificationCenter.default.publisher(for: NSApplication.didChangeScreenParametersNotification)
            .sink { [weak self] _ in
                Task { @MainActor in
                    self?.updateNotchShelf()
                }
            }
            .store(in: &cancellables)
    }

    private func persist() {
        guard !isLoading else { return }
        do {
            try currentConfigurationData().write(to: configurationURL)
        } catch {
            commandResults.insert(.failure("Preferences", "Could not save preferences.", details: [error.localizedDescription]), at: 0)
        }
    }

    private func syncNotchIslandPresentation(with snapshot: LiveIslandSnapshot? = nil) {
        guard notchConfig.enabled,
              notchConfig.preferredStyle == .island else {
            return
        }

        let snapshot = snapshot ?? liveIslandCoordinator.currentSnapshot
        let shouldUseCompact = snapshot.kind != .idle && snapshot.priority >= .backgroundMedia

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
        notchConfig.resetToAttachedNotchDefaults(keepEnabled: true)
        notchConfig.ignoreMouseEventsWhenInactive = false
    }

    private func format(_ rect: CGRect) -> String {
        "x \(Int(rect.origin.x)), y \(Int(rect.origin.y)), w \(Int(rect.width)), h \(Int(rect.height))"
    }

    private func currentConfigurationData() throws -> Data {
        try JSONEncoder.macForge.encode(MacForgeConfiguration(
            notchConfig: notchConfig,
            liveIslandSettings: liveIslandSettings,
            dockSettings: dockSettings,
            pinnedFolders: pinnedFolders,
            wallpaperPresets: wallpaperPresets,
            appPresets: appPresets,
            fileRules: fileRules,
            safetyConfirmationsEnabled: safetyConfirmationsEnabled,
            experimentalDockTweaksEnabled: experimentalDockTweaksEnabled,
            showInDock: showInDock
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
        persist()
    }

    private static func loadConfiguration(from url: URL) -> MacForgeConfiguration? {
        guard let data = try? Data(contentsOf: url) else { return nil }
        return try? JSONDecoder.macForge.decode(MacForgeConfiguration.self, from: data)
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
