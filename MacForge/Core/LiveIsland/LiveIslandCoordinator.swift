import AppKit
import Combine
import Foundation

@MainActor
final class LiveIslandCoordinator: ObservableObject {
    @Published private(set) var currentSnapshot: LiveIslandSnapshot
    @Published private(set) var diagnostics: [LiveIslandProviderDiagnostic]

    private(set) var settings: LiveIslandSettings
    private(set) var providers: [LiveIslandProvider]
    let timerProvider: TimerProvider
    var nowProvider: () -> Date

    private var refreshCancellable: AnyCancellable?
    private var lastSwitchAt: Date
    private var testSnapshot: LiveIslandSnapshot?
    private var pushedSnapshots: [String: LiveIslandSnapshot] = [:]
    private var refreshInFlight = false
    private var isSuspendedForSleep = false
    private var tickCount = 0
    private var sleepObservers: [NSObjectProtocol] = []

    init(
        settings: LiveIslandSettings = .default,
        providers: [LiveIslandProvider] = [],
        timerProvider: TimerProvider? = nil,
        nowProvider: @escaping () -> Date = Date.init
    ) {
        self.settings = settings
        self.providers = providers
        self.timerProvider = timerProvider ?? TimerProvider()
        self.nowProvider = nowProvider
        let now = nowProvider()
        currentSnapshot = .idle(at: now)
        diagnostics = []
        lastSwitchAt = now
    }

    func configureDefaultProviders(activityCenter: NotchIslandActivityCenter) {
        providers = [
            MacForgeTaskProvider(activityCenter: activityCenter),
            timerProvider,
            DownloadsProvider(),
            AppleMusicProvider(),
            SpotifyProvider(),
            QuickTimeProvider(),
            BrowserMediaProvider(),
            GenericMediaAppProvider(),
            CalendarAgendaProvider()
        ]
    }

    func updateSettings(_ settings: LiveIslandSettings) {
        self.settings = settings
        Task { await refresh() }
    }

    func start() {
        refreshCancellable?.cancel()
        registerSleepObserversIfNeeded()
        refreshCancellable = Timer.publish(every: 1, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                Task { @MainActor in
                    await self?.tick()
                }
            }
        Task { await refresh() }
    }

    func stop() {
        refreshCancellable?.cancel()
        refreshCancellable = nil
    }

    /// One timer tick. Polls at 1 Hz while anything is live, but backs off to
    /// every third tick when the island is idle and pauses entirely while the
    /// screens are asleep, so an idle Mac isn't firing Apple events all day.
    private func tick() async {
        guard !isSuspendedForSleep else { return }
        tickCount &+= 1
        if currentSnapshot.kind == .idle, testSnapshot == nil, pushedSnapshots.isEmpty, tickCount % 3 != 0 {
            return
        }
        await refresh()
    }

    /// Immediately surfaces an externally generated snapshot (volume HUD,
    /// bridge messages) without waiting for the next poll. Pushed snapshots
    /// compete in the normal priority arbitration and drop out when they
    /// expire.
    func push(_ snapshot: LiveIslandSnapshot) {
        pushedSnapshots[snapshot.providerID] = snapshot
        Task { await refresh() }
    }

    private func registerSleepObserversIfNeeded() {
        guard sleepObservers.isEmpty else { return }
        let center = NSWorkspace.shared.notificationCenter
        let sleepNames: [Notification.Name] = [NSWorkspace.screensDidSleepNotification, NSWorkspace.willSleepNotification]
        let wakeNames: [Notification.Name] = [NSWorkspace.screensDidWakeNotification, NSWorkspace.didWakeNotification]
        for name in sleepNames {
            sleepObservers.append(center.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in
                Task { @MainActor in
                    self?.isSuspendedForSleep = true
                }
            })
        }
        for name in wakeNames {
            sleepObservers.append(center.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in
                Task { @MainActor in
                    self?.isSuspendedForSleep = false
                    await self?.refresh()
                }
            })
        }
    }

    func startTimer(minutes: Int) {
        timerProvider.startTimer(duration: TimeInterval(minutes * 60), now: nowProvider())
        Task { await refresh() }
    }

    func showTestSnapshot(kind: LiveIslandSnapshotKind) {
        let now = nowProvider()
        switch kind {
        case .music:
            testSnapshot = LiveIslandSnapshot(
                providerID: "test",
                providerName: "Test Provider",
                kind: .music,
                priority: .media,
                title: "Test Track",
                subtitle: "MacForge Test Artist",
                appName: "MacForge",
                symbolName: "music.note",
                playbackState: .playing,
                elapsedTime: 45,
                duration: 180,
                startedAt: now,
                expiresAt: now.addingTimeInterval(8),
                actions: [LiveIslandAction(.previous), LiveIslandAction(.playPause), LiveIslandAction(.next)]
            )
        case .download:
            testSnapshot = LiveIslandSnapshot(
                providerID: "test",
                providerName: "Test Provider",
                kind: .download,
                priority: .download,
                title: "Download active",
                subtitle: "MacForge-Test.dmg",
                symbolName: "arrow.down.circle",
                progress: nil,
                startedAt: now,
                expiresAt: now.addingTimeInterval(8)
            )
        case .error:
            testSnapshot = LiveIslandSnapshot(
                providerID: "test",
                providerName: "Test Provider",
                kind: .error,
                priority: .error,
                title: "Test error",
                subtitle: "This is a temporary provider diagnostic.",
                symbolName: "exclamationmark.triangle.fill",
                startedAt: now,
                expiresAt: now.addingTimeInterval(6),
                isError: true
            )
        default:
            testSnapshot = LiveIslandSnapshot(
                providerID: "test",
                providerName: "Test Provider",
                kind: .task,
                priority: .task,
                title: "Test activity",
                subtitle: "MacForge provider test",
                symbolName: "sparkles",
                progress: 0.55,
                startedAt: now,
                expiresAt: now.addingTimeInterval(6)
            )
        }
        Task { await refresh() }
    }

    func performCurrentAction(_ action: LiveIslandActionKind) async -> CommandResult {
        let providerID = currentSnapshot.providerID
        guard providerID != "test" else {
            testSnapshot = nil
            await refresh()
            return .success("Live Island", "Cleared test provider.")
        }
        guard let provider = providers.first(where: { $0.id == providerID }) else {
            return .failure("Live Island", "The active provider is no longer available.")
        }

        let result = await provider.perform(action: action)
        await refresh()
        return result
    }

    /// Jumps the active source to an absolute position (expanded-view
    /// scrubber drag).
    func seekCurrent(to seconds: TimeInterval) async -> CommandResult {
        guard let provider = providers.first(where: { $0.id == currentSnapshot.providerID }) else {
            return .failure("Live Island", "The active provider is no longer available.")
        }
        let result = await provider.seek(to: seconds)
        await refresh()
        return result
    }

    func refresh() async {
        guard !refreshInFlight else { return }
        refreshInFlight = true
        defer { refreshInFlight = false }

        let now = nowProvider()
        var candidates: [LiveIslandSnapshot] = []
        var nextDiagnostics: [LiveIslandProviderDiagnostic] = []

        pushedSnapshots = pushedSnapshots.filter { $0.value.isActive(at: now, settings: settings) }
        candidates.append(contentsOf: pushedSnapshots.values)

        if let testSnapshot, testSnapshot.isActive(at: now, settings: settings) {
            candidates.append(testSnapshot)
            nextDiagnostics.append(LiveIslandProviderDiagnostic(
                id: testSnapshot.providerID,
                providerName: testSnapshot.providerName,
                isEnabled: true,
                status: "Testing",
                appStatus: "Self-test",
                lastPollAt: now,
                lastSuccessAt: now,
                rawResultSummary: "Injected test snapshot",
                snapshotTitle: testSnapshot.title,
                snapshotSubtitle: testSnapshot.subtitle,
                updatedAt: now
            ))
        } else {
            testSnapshot = nil
        }

        for provider in providers {
            guard provider.isEnabled(settings: settings) else {
                nextDiagnostics.append(LiveIslandProviderDiagnostic(
                    id: provider.id,
                    providerName: provider.displayName,
                    isEnabled: false,
                    status: "Disabled",
                    appStatus: "Provider disabled",
                    updatedAt: now
                ))
                continue
            }

            let snapshot = await provider.snapshot(settings: settings, now: now)
            if let snapshot, snapshot.isActive(at: now, settings: settings) {
                candidates.append(snapshot)
                nextDiagnostics.append(provider.latestDiagnostic ?? LiveIslandProviderDiagnostic(
                    id: provider.id,
                    providerName: provider.displayName,
                    isEnabled: true,
                    status: "Active",
                    appStatus: "Available",
                    lastPollAt: now,
                    lastSuccessAt: now,
                    snapshotTitle: snapshot.title,
                    snapshotSubtitle: snapshot.subtitle,
                    updatedAt: now
                ))
            } else {
                nextDiagnostics.append(provider.latestDiagnostic ?? LiveIslandProviderDiagnostic(
                    id: provider.id,
                    providerName: provider.displayName,
                    isEnabled: true,
                    status: "Available",
                    appStatus: "No active snapshot",
                    lastPollAt: now,
                    updatedAt: now
                ))
            }
        }

        let selected = Self.selectSnapshot(
            from: candidates,
            current: currentSnapshot,
            settings: settings,
            now: now,
            lastSwitchAt: lastSwitchAt
        ).redacted(using: settings)

        if selected.providerID != currentSnapshot.providerID || selected.kind != currentSnapshot.kind {
            lastSwitchAt = now
        }

        // Snapshots get a fresh UUID and startedAt every poll, so plain
        // equality would republish identical content at 1 Hz forever. Only
        // publish when something the island renders actually changed.
        if selected.hasVisibleChange(from: currentSnapshot) {
            currentSnapshot = selected
        }
        if settings.providerDiagnosticsEnabled {
            diagnostics = nextDiagnostics
        } else if !diagnostics.isEmpty {
            diagnostics = []
        }
    }

    func clearTransientState() {
        testSnapshot = nil
        pushedSnapshots = [:]
        timerProvider.cancelTimer()
        let now = nowProvider()
        currentSnapshot = .idle(at: now)
        diagnostics = []
        lastSwitchAt = now
    }

    static func selectSnapshot(
        from candidates: [LiveIslandSnapshot],
        current: LiveIslandSnapshot,
        settings: LiveIslandSettings,
        now: Date,
        lastSwitchAt: Date
    ) -> LiveIslandSnapshot {
        let activeCandidates = candidates.filter { $0.isActive(at: now, settings: settings) }
        guard let best = activeCandidates.sorted(by: snapshotSort).first else {
            return .idle(at: now)
        }

        guard current.providerID != "idle",
              current.isActive(at: now, settings: settings),
              activeCandidates.contains(where: { $0.providerID == current.providerID }),
              best.priority == current.priority,
              best.providerID != current.providerID,
              now.timeIntervalSince(lastSwitchAt) < 2 else {
            return best
        }

        // Hold the current provider through the anti-flap window, but hand
        // back its FRESH candidate so elapsed time and progress keep moving.
        return activeCandidates.first(where: { $0.providerID == current.providerID }) ?? current
    }

    private static func snapshotSort(_ lhs: LiveIslandSnapshot, _ rhs: LiveIslandSnapshot) -> Bool {
        if lhs.priority != rhs.priority {
            return lhs.priority > rhs.priority
        }
        return lhs.startedAt > rhs.startedAt
    }
}
