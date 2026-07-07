import Combine
import Foundation

/// State of a single agent/CLI task surfaced in the notch.
enum AgentActivityState: String, Codable, Hashable {
    case running
    case success
    case failure
    case info

    var isFinished: Bool { self == .success || self == .failure }
}

/// Raw line format a CLI appends to the MacForge agent event log. Every field
/// is optional so a one-liner shell `echo` can produce a valid event.
///
/// Example line (newline-delimited JSON):
/// {"id":"build","source":"Claude Code","title":"Building MacForge","message":"tests 3/8","progress":0.4,"state":"running"}
struct AgentActivityEvent: Codable, Hashable {
    var id: String?
    var source: String?
    /// progress | notification | done | clear
    var kind: String?
    var title: String?
    var message: String?
    var progress: Double?
    /// running | success | failure | info
    var state: String?
    /// Optional unix epoch seconds; informational only.
    var ts: Double?
}

/// A resolved, displayable agent task.
struct AgentActivity: Identifiable, Hashable {
    var id: String
    var source: String
    var title: String
    var message: String
    var progress: Double?
    var state: AgentActivityState
    var updatedAt: Date

    var symbolName: String {
        switch state {
        case .running: "gearshape.2"
        case .success: "checkmark.circle.fill"
        case .failure: "exclamationmark.triangle.fill"
        case .info: "bell.fill"
        }
    }
}

/// Watches a newline-delimited JSON event log and exposes live agent/CLI
/// activity (Claude Code, Codex, terminal jobs, CI, …) so the notch can show
/// it alongside media. Pure ingestion is separated from file watching so it
/// can be unit-tested.
@MainActor
final class AgentActivityCenter: ObservableObject {
    @Published private(set) var activities: [AgentActivity] = []
    @Published private(set) var lastNotification: AgentActivity?

    /// How long a running task may go without an update before it is treated
    /// as crashed and dropped.
    private let staleRunningInterval: TimeInterval = 60
    /// How long a finished task lingers before it disappears.
    private let finishedLinger: TimeInterval = 8
    private let maxActivities = 8

    let eventsURL: URL
    private var nowProvider: () -> Date

    private var readOffset: UInt64 = 0
    private var lineBuffer = Data()
    private var pollTimer: Timer?
    private var dispatchSource: DispatchSourceFileSystemObject?

    init(eventsURL: URL = AgentActivityCenter.defaultEventsURL(), nowProvider: @escaping () -> Date = Date.init) {
        self.eventsURL = eventsURL
        self.nowProvider = nowProvider
    }

    nonisolated static func defaultEventsURL() -> URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
            .appendingPathComponent("MacForge", isDirectory: true)
        return base.appendingPathComponent("agent-events.jsonl")
    }

    // MARK: - Derived state

    var primary: AgentActivity? {
        activities.first { $0.state == .running } ?? activities.first
    }

    var runningCount: Int {
        activities.filter { $0.state == .running }.count
    }

    var hasActivity: Bool { !activities.isEmpty }

    var aggregateProgress: Double? {
        let running = activities.filter { $0.state == .running }.compactMap(\.progress)
        guard !running.isEmpty else { return nil }
        return running.reduce(0, +) / Double(running.count)
    }

    // MARK: - Watching

    func start() {
        stop()
        ensureLogExists()
        // Start reading only new events written after launch.
        readOffset = currentFileSize()
        lineBuffer.removeAll()
        startPollTimer()
        startDispatchSource()
    }

    func stop() {
        pollTimer?.invalidate()
        pollTimer = nil
        dispatchSource?.cancel()
        dispatchSource = nil
    }

    private func startPollTimer() {
        pollTimer?.invalidate()
        let timer = Timer(timeInterval: 0.4, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.readNewEvents()
                self?.expireStale(now: self?.nowProvider() ?? Date())
            }
        }
        RunLoop.main.add(timer, forMode: .common)
        pollTimer = timer
    }

    private func startDispatchSource() {
        dispatchSource?.cancel()
        let fd = open(eventsURL.path, O_EVTONLY)
        guard fd >= 0 else { return }
        let source = DispatchSource.makeFileSystemObjectSource(
            fileDescriptor: fd,
            eventMask: [.write, .extend, .delete, .rename],
            queue: .main
        )
        source.setEventHandler { [weak self] in
            guard let self else { return }
            let flags = source.data
            if flags.contains(.delete) || flags.contains(.rename) {
                // Log rotated or removed; reopen from the top.
                self.dispatchSource?.cancel()
                self.readOffset = 0
                self.lineBuffer.removeAll()
                self.ensureLogExists()
                self.startDispatchSource()
            }
            self.readNewEvents()
        }
        // Each source closes only the descriptor it opened. Reading a shared
        // ivar here would close the *next* source's fd after a reopen.
        source.setCancelHandler {
            close(fd)
        }
        dispatchSource = source
        source.resume()
    }

    private func ensureLogExists() {
        let directory = eventsURL.deletingLastPathComponent()
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        if !FileManager.default.fileExists(atPath: eventsURL.path) {
            FileManager.default.createFile(atPath: eventsURL.path, contents: nil)
        }
    }

    private func currentFileSize() -> UInt64 {
        (try? FileManager.default.attributesOfItem(atPath: eventsURL.path)[.size] as? UInt64) ?? 0
    }

    private func readNewEvents() {
        guard let handle = try? FileHandle(forReadingFrom: eventsURL) else { return }
        defer { try? handle.close() }

        let size = currentFileSize()
        if size < readOffset {
            // File was truncated/rotated — start over.
            readOffset = 0
        }
        do {
            try handle.seek(toOffset: readOffset)
        } catch {
            return
        }
        let data = handle.readDataToEndOfFile()
        guard !data.isEmpty else { return }
        readOffset += UInt64(data.count)

        // Buffer raw bytes and only decode whole newline-terminated lines, so a
        // JSON line split across two writes (or a multibyte character split at a
        // read boundary) is completed on the next read instead of being dropped.
        lineBuffer.append(data)
        let newline = UInt8(ascii: "\n")
        let now = nowProvider()
        while let index = lineBuffer.firstIndex(of: newline) {
            let lineData = lineBuffer.subdata(in: lineBuffer.startIndex..<index)
            lineBuffer.removeSubrange(lineBuffer.startIndex...index)
            processLine(lineData, now: now)
        }
        // Drop a pathological unterminated line so the buffer can't grow forever.
        if lineBuffer.count > 64 * 1024 {
            lineBuffer.removeAll()
        }
    }

    private func processLine(_ data: Data, now: Date) {
        guard let text = String(data: data, encoding: .utf8) else { return }
        let trimmed = text.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty, let lineData = trimmed.data(using: .utf8) else { return }
        guard let event = try? JSONDecoder().decode(AgentActivityEvent.self, from: lineData) else { return }
        ingest(event, now: now)
    }

    /// Synchronously drain the log — used by tests to exercise the reader
    /// without waiting on the poll timer.
    func pumpForTesting() {
        readNewEvents()
    }

    // MARK: - Pure ingestion (unit-tested)

    @discardableResult
    func ingest(_ event: AgentActivityEvent, now: Date) -> AgentActivity? {
        let kind = event.kind?.lowercased()
        if kind == "clear" {
            if let id = event.id {
                activities.removeAll { $0.id == id }
            } else {
                activities.removeAll()
            }
            return nil
        }

        let resolvedState: AgentActivityState
        if let raw = event.state?.lowercased(), let parsed = AgentActivityState(rawValue: raw) {
            resolvedState = parsed
        } else {
            switch kind {
            case "done": resolvedState = .success
            case "notification": resolvedState = .info
            default: resolvedState = .running
            }
        }

        // A notification with no id is a distinct one-off toast.
        let id = event.id ?? (kind == "notification" ? UUID().uuidString : (event.source ?? "agent"))
        let source = event.source ?? "Agent"
        let title = event.title ?? source
        let message = event.message ?? ""

        let activity = AgentActivity(
            id: id,
            source: source,
            title: title,
            message: message,
            progress: event.progress.map { min(max($0, 0), 1) },
            state: resolvedState,
            updatedAt: now
        )

        activities.removeAll { $0.id == id }
        activities.insert(activity, at: 0)
        activities = Array(activities.prefix(maxActivities))

        if resolvedState != .running {
            lastNotification = activity
        }
        return activity
    }

    func expireStale(now: Date) {
        let filtered = activities.filter { activity in
            let age = now.timeIntervalSince(activity.updatedAt)
            if activity.state == .running {
                return age < staleRunningInterval
            }
            return age < finishedLinger
        }
        // Only publish when something actually expired; the poll runs every
        // 0.4s and @Published notifies on every assignment.
        if filtered != activities {
            activities = filtered
        }
    }

    // MARK: - Actions

    func clearAll() {
        activities.removeAll()
        lastNotification = nil
    }

    /// Injects a short-lived demo task so the user can preview the split view
    /// without wiring a real CLI first.
    func injectTestActivity() {
        let now = nowProvider()
        ingest(
            AgentActivityEvent(
                id: "macforge-demo",
                source: "Claude Code",
                kind: "progress",
                title: "Running tests",
                message: "3 of 8 suites",
                progress: 0.42,
                state: "running",
                ts: nil
            ),
            now: now
        )
    }
}
