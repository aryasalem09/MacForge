import SwiftUI

struct NotchShelfSettingsView: View {
    @EnvironmentObject private var environment: AppEnvironment

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
                slider("Opacity", value: $environment.notchConfig.opacity, range: 0.45...1.0, step: 0.05, suffix: "%") {
                    Int(environment.notchConfig.opacity * 100)
                }
            } header: {
                Text("Shelf")
            } footer: {
                Text("MacForge uses public screen safe-area and auxiliary top-area geometry. It cannot draw inside pixels hidden by the physical camera cutout.")
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
                Toggle("Main display only", isOn: $environment.notchConfig.mainDisplayOnly)
                Toggle("Overlay menu bar area for attached notch", isOn: $environment.notchConfig.overlayMenuBarForAttachedNotch)
                Toggle("Show placement debug overlay", isOn: $environment.notchConfig.showPlacementDebugOverlay)
                HStack {
                    Slider(value: $environment.notchConfig.autoCollapseDelay, in: 1...10, step: 0.5) {
                        Text("Auto-collapse")
                    }
                    Text("\(environment.notchConfig.autoCollapseDelay, specifier: "%.1f") s")
                        .frame(width: 70, alignment: .trailing)
                }
                Toggle("Click-through mode", isOn: $environment.notchConfig.ignoreMouseEventsWhenInactive)
                if environment.notchConfig.ignoreMouseEventsWhenInactive {
                    Label("Buttons may not be clickable while click-through mode is enabled.", systemImage: "exclamationmark.triangle")
                        .font(.caption)
                        .foregroundStyle(.orange)
                }
            }

            liveIslandSourceSection

            Section("Placement") {
                slider("Vertical attach offset", value: $environment.notchConfig.islandVerticalOffset, range: -40...40, step: 1, suffix: "px") {
                    Int(environment.notchConfig.islandVerticalOffset)
                }
                slider("Horizontal offset", value: $environment.notchConfig.islandHorizontalOffset, range: -80...80, step: 1, suffix: "px") {
                    Int(environment.notchConfig.islandHorizontalOffset)
                }
                slider("Shell height", value: $environment.notchConfig.attachedShellHeight, range: 20...80, step: 1, suffix: "px") {
                    Int(environment.notchConfig.attachedShellHeight)
                }
                HStack {
                    Button("Snap to Detected Notch", systemImage: "scope") {
                        environment.snapNotchIslandToDetectedNotch()
                    }
                    Button("Reset to Attached Defaults", systemImage: "arrow.counterclockwise") {
                        environment.resetNotchIslandLayout()
                    }
                }
                HStack {
                    Button("Repair Notch Island Layout", systemImage: "wrench.and.screwdriver") {
                        environment.repairNotchIslandLayout()
                    }
                    Button("Copy Notch Geometry Debug Info", systemImage: "doc.on.doc") {
                        environment.copyNotchGeometryDebugInfo()
                    }
                }
            }

            Section("Island Size") {
                slider("Collapsed width", value: $environment.notchConfig.collapsedWidth, range: 140...280, step: 2, suffix: "px") {
                    Int(environment.notchConfig.collapsedWidth)
                }
                slider("Collapsed height", value: $environment.notchConfig.collapsedHeight, range: 30...44, step: 1, suffix: "px") {
                    Int(environment.notchConfig.collapsedHeight)
                }
                slider("Compact width", value: $environment.notchConfig.compactWidth, range: 260...420, step: 4, suffix: "px") {
                    Int(environment.notchConfig.compactWidth)
                }
                slider("Expanded width", value: $environment.notchConfig.expandedWidth, range: 480...680, step: 10, suffix: "px") {
                    Int(environment.notchConfig.expandedWidth)
                }
                slider("Expanded height", value: $environment.notchConfig.expandedHeight, range: 280...460, step: 10, suffix: "px") {
                    Int(environment.notchConfig.expandedHeight)
                }
                Button("Reset Island Layout", systemImage: "arrow.counterclockwise") {
                    environment.resetNotchIslandLayout()
                }
            }

            widgetSection
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
                Toggle("Keep media visible while playing", isOn: $environment.liveIslandSettings.keepMediaVisibleWhilePlaying)
                Toggle("Show artwork", isOn: $environment.liveIslandSettings.showArtwork)
                Toggle("Privacy Mode", isOn: $environment.liveIslandSettings.privacyMode)
                Toggle("Provider diagnostics", isOn: $environment.liveIslandSettings.providerDiagnosticsEnabled)
            } header: {
                Text("Live Island Sources")
            } footer: {
                Text("Music, Spotify, and QuickTime use public Automation with macOS consent. Browser hints use active tab title and URL only when enabled.")
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
            Toggle("Clipboard placeholder", isOn: $environment.notchConfig.showClipboardPreviewPlaceholder)
        }
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
