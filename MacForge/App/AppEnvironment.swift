import AppKit
import Combine
import Foundation
import UniformTypeIdentifiers

private struct MacForgeConfiguration: Codable {
    var notchConfig: NotchShelfConfig
    var dockSettings: DockSettings
    var pinnedFolders: [FolderShortcut]
    var wallpaperPresets: [WallpaperPreset]
    var appPresets: [AppPreset]
    var fileRules: [FileRule]
    var safetyConfirmationsEnabled: Bool
    var experimentalDockTweaksEnabled: Bool
    var showInDock: Bool
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
    let wallpaperService = WallpaperService()
    let notchShelfWindowController = NotchShelfWindowController()
    let fileOrganizerService = FileOrganizerService()
    let bulkRenameEngine = BulkRenameEngine()
    let duplicateFinder = DuplicateFinder()
    let presetRunner = PresetRunner()
    let rollbackManager = RollbackManager()

    private let configurationURL: URL
    private var isLoading = true

    init() {
        let supportDirectory = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
            .appendingPathComponent("MacForge", isDirectory: true)
        try? FileManager.default.createDirectory(at: supportDirectory, withIntermediateDirectories: true)
        configurationURL = supportDirectory.appendingPathComponent("configuration.json")

        let loaded = Self.loadConfiguration(from: configurationURL)
        notchConfig = loaded?.notchConfig ?? .default
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
        refreshPermissions()
        refreshWallpaperStates()
        updateShelfAndPersist()
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
    }

    func updateNotchShelf() {
        notchShelfWindowController.update(config: notchConfig, environment: self)
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
        append(await windowService.tileFocusedWindow(layout, customGrid: nil))
        await refreshWindows()
    }

    func moveFocusedWindowToNextDisplay() async {
        append(await windowService.moveFocusedWindowToNextDisplay())
        await refreshWindows()
    }

    func applyDockSettings() async {
        let results = await dockSettingsService.apply(dockSettings, experimentalTweaksEnabled: experimentalDockTweaksEnabled)
        results.forEach(append)
    }

    func resetDockSettings() async {
        let results = await dockSettingsService.resetToSystemDefaults(experimentalTweaksEnabled: experimentalDockTweaksEnabled)
        results.forEach(append)
    }

    func createFolderTemplate(named template: FolderTemplate, in shortcut: FolderShortcut) {
        guard let root = folderAccessStore.resolve(shortcut) else {
            append(.failure("Folder Template", "Could not resolve \(shortcut.name)."))
            return
        }

        let folderName = "\(template.label) \(Date().formatted(.dateTime.year().month(.twoDigits).day(.twoDigits)))"
        let rootURL = root.appendingPathComponent(folderName, isDirectory: true)

        do {
            for path in template.paths {
                try FileManager.default.createDirectory(at: rootURL.appendingPathComponent(path, isDirectory: true), withIntermediateDirectories: true)
            }
            append(.success("Folder Template", "Created \(folderName)."))
        } catch {
            append(.failure("Folder Template", "Could not create template folders.", details: [error.localizedDescription]))
        }
    }

    func runPreset(_ preset: AppPreset) async {
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
            }
        )

        let transaction = await presetRunner.run(preset, context: context)
        lastPresetTransaction = transaction
        if let index = appPresets.firstIndex(where: { $0.id == preset.id }) {
            appPresets[index].lastRunDate = Date()
        }
        append(.success("Preset", "Finished \(preset.name).", details: transaction.results.map { "\($0.title): \($0.message)" }, reversible: transaction.rollbackAvailable))
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
        dockSettings = .default
        pinnedFolders = []
        wallpaperPresets = []
        appPresets = AppPreset.examples
        fileRules = []
        safetyConfirmationsEnabled = true
        experimentalDockTweaksEnabled = false
        append(.success("Reset Preferences", "MacForge preferences were reset. System settings were not changed."))
    }

    func append(_ result: CommandResult) {
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
            guard let rule = fileRules.first(where: { $0.id == id }),
                  let sourceID = rule.sourceFolderID,
                  let sourceShortcut = pinnedFolders.first(where: { $0.id == sourceID }),
                  let sourceURL = folderAccessStore.resolve(sourceShortcut) else {
                return .failure("File Rule", "The file rule is missing a source folder.")
            }
            let previews = fileOrganizerService.preview(rule: rule, sourceURL: sourceURL) { [weak self] folderID in
                self?.pinnedFolders.first(where: { $0.id == folderID }).flatMap { self?.folderAccessStore.resolve($0) }
            }
            let results = fileOrganizerService.apply(previews: previews, rule: rule, dryRun: dryRun || rule.dryRunOnly)
            return results.first ?? .success("File Rule", "No files matched.")
        }
    }

    private func updateShelfAndPersist() {
        guard !isLoading else { return }
        updateNotchShelf()
        persist()
    }

    private func persist() {
        guard !isLoading else { return }
        do {
            try currentConfigurationData().write(to: configurationURL)
        } catch {
            commandResults.insert(.failure("Preferences", "Could not save preferences.", details: [error.localizedDescription]), at: 0)
        }
    }

    private func currentConfigurationData() throws -> Data {
        try JSONEncoder.macForge.encode(MacForgeConfiguration(
            notchConfig: notchConfig,
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
