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
            GenericMediaAppProvider()
        ]
    }

    func updateSettings(_ settings: LiveIslandSettings) {
        self.settings = settings
        Task { await refresh() }
    }

    func start() {
        refreshCancellable?.cancel()
        refreshCancellable = Timer.publish(every: 1, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                Task { @MainActor in
                    await self?.refresh()
                }
            }
        Task { await refresh() }
    }

    func stop() {
        refreshCancellable?.cancel()
        refreshCancellable = nil
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

    func refresh() async {
        let now = nowProvider()
        var candidates: [LiveIslandSnapshot] = []
        var nextDiagnostics: [LiveIslandProviderDiagnostic] = []

        if let testSnapshot, testSnapshot.isActive(at: now, settings: settings) {
            candidates.append(testSnapshot)
            nextDiagnostics.append(LiveIslandProviderDiagnostic(
                id: testSnapshot.providerID,
                providerName: testSnapshot.providerName,
                status: "Testing",
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
                    status: "Disabled",
                    updatedAt: now
                ))
                continue
            }

            let snapshot = await provider.snapshot(settings: settings, now: now)
            if let snapshot, snapshot.isActive(at: now, settings: settings) {
                candidates.append(snapshot)
                nextDiagnostics.append(LiveIslandProviderDiagnostic(
                    id: provider.id,
                    providerName: provider.displayName,
                    status: "Active",
                    updatedAt: now
                ))
            } else {
                nextDiagnostics.append(LiveIslandProviderDiagnostic(
                    id: provider.id,
                    providerName: provider.displayName,
                    status: "Available",
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

        currentSnapshot = selected
        diagnostics = nextDiagnostics
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

        return current
    }

    private static func snapshotSort(_ lhs: LiveIslandSnapshot, _ rhs: LiveIslandSnapshot) -> Bool {
        if lhs.priority != rhs.priority {
            return lhs.priority > rhs.priority
        }
        return lhs.startedAt > rhs.startedAt
    }
}
