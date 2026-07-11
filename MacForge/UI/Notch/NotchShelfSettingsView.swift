import SwiftUI

struct NotchShelfSettingsView: View {
    @EnvironmentObject private var environment: AppEnvironment

    /// Routing enablement through the environment lets the calendar toggle
    /// trigger the permission request at the moment the feature turns on.
    private var calendarAgendaBinding: Binding<Bool> {
        Binding(
            get: { environment.liveIslandSettings.calendarAgendaEnabled },
            set: { environment.setCalendarAgendaEnabled($0) }
        )
    }

    var body: some View {
        Form {
            Section {
                Toggle("Enable Notch Shelf", isOn: $environment.notchConfig.enabled)
                Picker("Mode", selection: $environment.notchConfig.preferredStyle) {
                    ForEach(NotchShelfPreferredStyle.allCases) { style in
                        Text(style.label).tag(style)
                    }
                }
                Picker("Material", selection: $environment.notchConfig.materialStyle) {
                    ForEach(NotchIslandMaterialStyle.allCases) { style in
                        Text(style.label).tag(style)
                    }
                }
                if environment.notchConfig.preferredStyle == .classicShelf {
                    slider("Opacity", value: $environment.notchConfig.opacity, range: 0.45...1.0, step: 0.05, suffix: "%") {
                        Int(environment.notchConfig.opacity * 100)
                    }
                }
            } header: {
                Text("Shelf")
            } footer: {
                Text("The island measures the camera cutout from public screen geometry and attaches to it. It cannot draw inside pixels hidden by the physical camera cutout.")
            }

            if environment.notchConfig.preferredStyle == .island {
                islandSections
            } else {
                classicShelfSections
            }

            Section {
                HStack {
                    Button(environment.notchConfig.enabled ? "Hide Shelf" : "Show Shelf", systemImage: "macbook.gen2") {
                        environment.toggleNotchShelf()
                    }
                    Button("Refresh Position", systemImage: "arrow.triangle.2.circlepath") {
                        environment.updateNotchShelf()
                    }
                }
            } footer: {
                Text("Main-display placement is the current MVP. External displays use the same island states with a top-center fallback when no notch geometry is available.")
            }
        }
        .formStyle(.grouped)
        .padding(12)
    }

    private var islandSections: some View {
        Group {
            Section("Presentation") {
                HStack {
                    Button("Collapsed", systemImage: "capsule") {
                        environment.collapseNotchIsland()
                    }
                    Button("Expanded", systemImage: "arrow.down.right.and.arrow.up.left") {
                        environment.expandNotchIsland()
                    }
                    Button("Auto", systemImage: "timer") {
                        environment.collapseNotchIsland()
                    }
                }
                Toggle("Expand on hover", isOn: $environment.notchConfig.expandOnHover)
                Toggle("Expand on click", isOn: $environment.notchConfig.expandOnClick)
                Toggle("Show placement debug overlay", isOn: $environment.notchConfig.showPlacementDebugOverlay)
                HStack {
                    Slider(value: $environment.notchConfig.autoCollapseDelay, in: 1...10, step: 0.5) {
                        Text("Auto-collapse")
                    }
                    Text("\(environment.notchConfig.autoCollapseDelay, specifier: "%.1f") s")
                        .frame(width: 70, alignment: .trailing)
                }
            }

            liveIslandSourceSection

            agentActivitySection

            glanceSection

            Section {
                slider("Expanded width", value: $environment.notchConfig.expandedWidth, range: 480...680, step: 10, suffix: "px") {
                    Int(environment.notchConfig.expandedWidth)
                }
                slider("Expanded height", value: $environment.notchConfig.expandedHeight, range: 280...460, step: 10, suffix: "px") {
                    Int(environment.notchConfig.expandedHeight)
                }
                slider("Virtual notch offset", value: $environment.notchConfig.islandHorizontalOffset, range: -160...160, step: 1, suffix: "px") {
                    Int(environment.notchConfig.islandHorizontalOffset)
                }
                HStack {
                    Button("Reset Island Layout", systemImage: "arrow.counterclockwise") {
                        environment.resetNotchIslandLayout()
                    }
                    Button("Copy Notch Geometry Debug Info", systemImage: "doc.on.doc") {
                        environment.copyNotchGeometryDebugInfo()
                    }
                }
            } header: {
                Text("Island Size")
            } footer: {
                Text("Collapsed and compact sizes are measured from the physical notch automatically. The virtual notch offset only applies to displays without a camera cutout.")
            }

            widgetSection

            diagnosticsSection
        }
    }

    @State private var weatherQuery = ""
    @State private var weatherResults: [WeatherLocationResult] = []
    @State private var weatherSearching = false

    private var glanceSection: some View {
        Section {
            Toggle("Clipboard history (Clip tab)", isOn: $environment.liveIslandSettings.clipboardHistoryEnabled)
            Toggle("Hide island from screenshots & screen shares", isOn: $environment.liveIslandSettings.excludeFromScreenCapture)

            if let name = environment.liveIslandSettings.weatherLocationName,
               environment.liveIslandSettings.weatherEnabled {
                HStack {
                    Label(name, systemImage: "location.fill")
                    Spacer()
                    Button("Remove", role: .destructive) {
                        environment.clearWeatherLocation()
                    }
                }
            } else {
                HStack {
                    TextField("Weather city (e.g. San Francisco)", text: $weatherQuery)
                        .textFieldStyle(.roundedBorder)
                        .onSubmit { searchWeatherLocations() }
                    Button("Search") {
                        searchWeatherLocations()
                    }
                    .disabled(weatherQuery.trimmingCharacters(in: .whitespaces).isEmpty || weatherSearching)
                }
                if weatherSearching {
                    ProgressView().controlSize(.small)
                }
                ForEach(weatherResults) { result in
                    Button {
                        environment.setWeatherLocation(result)
                        weatherResults = []
                        weatherQuery = ""
                    } label: {
                        Label(result.displayName, systemImage: "mappin.and.ellipse")
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(.tint)
                }
            }
        } header: {
            Text("Glance & Privacy")
        } footer: {
            Text("Clipboard history stays in memory only and skips anything password managers mark as concealed. Weather uses Open-Meteo with just the city you pick — no location permission, no account. The camera Mirror tab asks for camera access the first time you open it.")
        }
    }

    private func searchWeatherLocations() {
        let query = weatherQuery
        weatherSearching = true
        Task { @MainActor in
            weatherResults = await WeatherGlanceCenter.searchLocations(matching: query)
            weatherSearching = false
        }
    }

    private var agentActivitySection: some View {
        Section {
            Toggle("Show agent & CLI activity", isOn: $environment.liveIslandSettings.agentActivityEnabled)
            HStack {
                if environment.claudeCodeConnected {
                    Label("Claude Code connected", systemImage: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                } else {
                    Button("Set up Claude Code", systemImage: "asterisk") {
                        environment.installClaudeCodeIntegration()
                    }
                }
                if environment.codexConnected {
                    Label("Codex connected", systemImage: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                } else {
                    Button("Set up Codex", systemImage: "chevron.left.forwardslash.chevron.right") {
                        environment.installCodexIntegration()
                    }
                }
            }
            .disabled(!environment.liveIslandSettings.agentActivityEnabled)
            if let notice = environment.agentSetupNotice {
                Label(notice, systemImage: "info.circle")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            HStack {
                Button("Run Demo Task", systemImage: "play.fill") {
                    environment.showAgentActivityTest()
                }
                Button("Reveal Log", systemImage: "folder") {
                    environment.revealAgentEventLog()
                }
                Button("Copy Path", systemImage: "doc.on.doc") {
                    environment.copyAgentEventLogPath()
                }
            }
            .disabled(!environment.liveIslandSettings.agentActivityEnabled)
        } header: {
            Text("Agents & CLI")
        } footer: {
            Text("Set up Claude Code or Codex with one click — MacForge installs a small local hook script and updates the tool's config (a backup is written first). Any other CLI can append newline-delimited JSON to the event log at the copied path (also exported as $MACFORGE_AGENT_EVENTS by Scripts/macforge-notify.sh).")
        }
    }

    private var liveIslandSourceSection: some View {
        Group {
            Section {
                Toggle("Enable Live Island Sources", isOn: $environment.liveIslandSettings.enableLiveIslandSources)
                Toggle("Apple Music", isOn: $environment.liveIslandSettings.appleMusicEnabled)
                Toggle("Spotify", isOn: $environment.liveIslandSettings.spotifyEnabled)
                Toggle("QuickTime/video", isOn: $environment.liveIslandSettings.quickTimeEnabled)
                Toggle("Browser media hints", isOn: $environment.liveIslandSettings.browserMediaHintsEnabled)
                Toggle("Downloads watcher", isOn: $environment.liveIslandSettings.downloadsWatcherEnabled)
                Toggle("Timers", isOn: $environment.liveIslandSettings.timersEnabled)
                Toggle("Calendar agenda", isOn: calendarAgendaBinding)
                Toggle("Volume HUD in island", isOn: $environment.liveIslandSettings.volumeHUDEnabled)
                Toggle("Other media apps (TV, VLC, IINA)", isOn: $environment.liveIslandSettings.genericMediaEnabled)
                Toggle("Keep media visible while playing", isOn: $environment.liveIslandSettings.keepMediaVisibleWhilePlaying)
                Toggle("Show artwork", isOn: $environment.liveIslandSettings.showArtwork)
                Toggle("Show battery in island", isOn: $environment.liveIslandSettings.showBatteryInIsland)
                Toggle("Privacy Mode", isOn: $environment.liveIslandSettings.privacyMode)
                Toggle("Provider diagnostics", isOn: $environment.liveIslandSettings.providerDiagnosticsEnabled)
            } header: {
                Text("Live Island Sources")
            } footer: {
                Text("Music, Spotify, and QuickTime use public Automation with macOS consent. Browser hints use active tab title and URL only when enabled. Calendar asks for access only when you turn it on. The volume HUD is fully local — no permissions.")
            }

            Section {
                Picker("Keep files", selection: $environment.trayRetentionMinutes) {
                    Text("Until removed").tag(0.0)
                    Text("For 1 hour").tag(60.0)
                    Text("For 8 hours").tag(480.0)
                    Text("For 1 day").tag(1440.0)
                    Text("For 1 week").tag(10080.0)
                }
                LabeledContent("Files in tray", value: "\(environment.notchTrayItems.count)")
                HStack {
                    Button("AirDrop All", systemImage: "square.and.arrow.up") {
                        environment.airDropNotchTrayItems(environment.notchTrayItems)
                    }
                    .disabled(environment.notchTrayItems.isEmpty)
                    Button("Clear Tray", systemImage: "trash") {
                        environment.clearNotchFileTray()
                    }
                    .disabled(environment.notchTrayItems.isEmpty)
                }
            } header: {
                Text("File Tray")
            } footer: {
                Text("Files dropped on the island stay in the Tray tab across relaunches. The retention window removes older files automatically; \u{201C}Until removed\u{201D} keeps everything.")
            }

            Section("Downloads") {
                HStack {
                    Text(environment.liveIslandSettings.downloadsFolderName ?? "No folder selected")
                        .foregroundStyle(environment.liveIslandSettings.downloadsFolderName == nil ? .secondary : .primary)
                    Spacer()
                    Button("Choose", systemImage: "folder") {
                        environment.chooseLiveIslandDownloadsFolder()
                    }
                    Button("Clear", systemImage: "xmark.circle") {
                        environment.clearLiveIslandDownloadsFolder()
                    }
                    .disabled(environment.liveIslandSettings.downloadsFolderBookmark == nil)
                }
            }

            Section {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Button("Force Now Playing Test Card", systemImage: "waveform.path.ecg") {
                            environment.runLiveIslandSelfTest()
                        }
                        Button("Test Music Provider", systemImage: "music.note") {
                            Task { await environment.testAppleMusicProvider() }
                        }
                        Button("Open Music", systemImage: "arrow.up.right.square") {
                            environment.openMusicApp()
                        }
                    }

                    HStack {
                        Button("Open Automation Settings", systemImage: "lock.shield") {
                            environment.openAutomationSettings()
                        }
                        Button("Download", systemImage: "arrow.down.circle") {
                            environment.showLiveIslandTestSnapshot(kind: .download)
                        }
                        Button("Task", systemImage: "sparkles") {
                            environment.showLiveIslandTestSnapshot(kind: .task)
                        }
                        Button("Error", systemImage: "exclamationmark.triangle") {
                            environment.showLiveIslandTestSnapshot(kind: .error)
                        }
                    }
                }
            } header: {
                Text("Test Providers")
            } footer: {
                Text("To reset the Automation prompt manually: quit MacForge, run `tccutil reset AppleEvents com.aryasalem.MacForge`, relaunch MacForge, then allow Music when prompted.")
            }

            if environment.liveIslandSettings.providerDiagnosticsEnabled {
                Section("Provider Diagnostics") {
                    ForEach(environment.liveIslandCoordinator.diagnostics) { diagnostic in
                        providerDiagnosticRow(diagnostic)
                    }
                }
            }
        }
    }

    private var classicShelfSections: some View {
        Group {
            Section("Classic Shelf Position") {
                Picker("Position", selection: $environment.notchConfig.positionMode) {
                    ForEach(NotchShelfPositionMode.allCases) { mode in
                        Text(mode.label).tag(mode)
                    }
                }
                slider("Width", value: $environment.notchConfig.width, range: 360...900, step: 10, suffix: "px") {
                    Int(environment.notchConfig.width)
                }
                slider("Height", value: $environment.notchConfig.height, range: 52...120, step: 2, suffix: "px") {
                    Int(environment.notchConfig.height)
                }
                Toggle("Click-through mode", isOn: $environment.notchConfig.ignoreMouseEventsWhenInactive)
                if environment.notchConfig.ignoreMouseEventsWhenInactive {
                    Label("Shelf buttons may not be clickable while click-through mode is enabled.", systemImage: "exclamationmark.triangle")
                        .font(.caption)
                        .foregroundStyle(.orange)
                }
            }

            widgetSection
        }
    }

    private var widgetSection: some View {
        Section("Widgets") {
            Toggle("Clock", isOn: $environment.notchConfig.showClock)
            Toggle("Current app", isOn: $environment.notchConfig.showCurrentApp)
            Toggle("Quick folders", isOn: $environment.notchConfig.showFolders)
            Toggle("Window actions", isOn: $environment.notchConfig.showWindowActions)
            Toggle("Preset button", isOn: $environment.notchConfig.showPresets)
            Toggle("Recent results", isOn: $environment.notchConfig.showRecentResults)
            Toggle("Activity progress", isOn: $environment.notchConfig.showActivityProgress)
        }
    }

    private var diagnosticsSection: some View {
        Section("Diagnostics") {
            LabeledContent("Build", value: MacForgeBuildInfo.label)
            LabeledContent("Bundle", value: environment.buildInfo.bundlePath)
            LabeledContent("Config", value: environment.configurationPath)
            LabeledContent("Panel", value: environment.notchShelfWindowController.currentPanelFrame.map { format($0) } ?? "none")
            LabeledContent("Level", value: environment.notchShelfWindowController.currentWindowLevelDescription)
            LabeledContent("Hover", value: environment.notchHoverState.rawValue)
            LabeledContent("Virtual notch offset", value: "x \(Int(environment.notchConfig.islandHorizontalOffset))")
            if !environment.notchHoverDiagnostics.isEmpty {
                Text(environment.notchHoverDiagnostics.joined(separator: "\n"))
                    .font(.caption2.monospaced())
                    .foregroundStyle(.secondary)
                    .textSelection(.enabled)
            }
        }
    }

    private func format(_ rect: CGRect) -> String {
        "x \(Int(rect.origin.x)), y \(Int(rect.origin.y)), w \(Int(rect.width)), h \(Int(rect.height))"
    }

    private func slider<Value: BinaryInteger>(
        _ title: String,
        value: Binding<Double>,
        range: ClosedRange<Double>,
        step: Double,
        suffix: String,
        displayValue: () -> Value
    ) -> some View {
        HStack {
            Slider(value: value, in: range, step: step) {
                Text(title)
            }
            Text(verbatim: "\(displayValue()) \(suffix)")
                .frame(width: 74, alignment: .trailing)
        }
    }

    private func providerDiagnosticRow(_ diagnostic: LiveIslandProviderDiagnostic) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Label(diagnostic.providerName, systemImage: diagnostic.permissionNeeded ? "lock.shield" : "dot.radiowaves.left.and.right")
                Spacer()
                Text(diagnostic.status)
                    .foregroundStyle(diagnostic.permissionNeeded ? .orange : .secondary)
            }

            Text(diagnostic.appStatus)
                .font(.caption)
                .foregroundStyle(.secondary)

            if let lastPollAt = diagnostic.lastPollAt {
                Text("Last poll: \(lastPollAt.formatted(date: .omitted, time: .standard))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            if let lastSuccessAt = diagnostic.lastSuccessAt {
                Text("Last success: \(lastSuccessAt.formatted(date: .omitted, time: .standard))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            if let title = diagnostic.snapshotTitle {
                Text([title, diagnostic.snapshotSubtitle].compactMap { $0 }.filter { !$0.isEmpty }.joined(separator: " - "))
                    .font(.caption)
                    .foregroundStyle(.primary)
                    .lineLimit(1)
            }

            if let rawResultSummary = diagnostic.rawResultSummary {
                Text(rawResultSummary)
                    .font(.caption2.monospaced())
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }

            if let lastError = diagnostic.lastError {
                Text(lastError)
                    .font(.caption)
                    .foregroundStyle(.orange)
                    .lineLimit(2)
            }
        }
        .padding(.vertical, 4)
    }
}
