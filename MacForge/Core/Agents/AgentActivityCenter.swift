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

// MARK: - One-click Claude Code / Codex integration

/// Installs the hook scripts + config entries that make Claude Code and Codex
/// report turn completions and notifications into the notch. Everything is
/// local: scripts live in Application Support, and user configs are backed up
/// before any edit.
enum AgentIntegrationInstaller {
    static var binDirectory: URL {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
            .appendingPathComponent("MacForge/bin", isDirectory: true)
    }

    static var claudeHookScriptURL: URL { binDirectory.appendingPathComponent("macforge-claude-hook.sh") }
    static var codexNotifyScriptURL: URL { binDirectory.appendingPathComponent("macforge-codex-notify.sh") }

    static var defaultClaudeSettingsURL: URL {
        FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".claude/settings.json")
    }

    static var defaultCodexConfigURL: URL {
        FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".codex/config.toml")
    }

    /// Whether the user's Claude Code settings already route into MacForge —
    /// drives the "Connected" state on the setup buttons.
    static func isClaudeCodeConnected(settingsURL: URL = defaultClaudeSettingsURL) -> Bool {
        guard let text = try? String(contentsOf: settingsURL, encoding: .utf8) else { return false }
        return text.localizedCaseInsensitiveContains("macforge")
    }

    static func isCodexConnected(configURL: URL = defaultCodexConfigURL) -> Bool {
        guard let text = try? String(contentsOf: configURL, encoding: .utf8) else { return false }
        return text.localizedCaseInsensitiveContains("macforge")
    }

    // MARK: Claude Code

    /// Merges Stop + Notification hooks into ~/.claude/settings.json (backing
    /// the file up first). Idempotent: skips events that already call MacForge.
    static func installClaudeCodeHooks(
        settingsURL: URL = defaultClaudeSettingsURL,
        binDirectory: URL = AgentIntegrationInstaller.binDirectory
    ) -> CommandResult {
        let scriptURL = binDirectory.appendingPathComponent("macforge-claude-hook.sh")
        do {
            try installHelperScripts(at: binDirectory)
        } catch {
            return .failure("Claude Code Setup", "Could not install the MacForge hook script.", details: [error.localizedDescription])
        }

        let fileManager = FileManager.default
        var root: [String: Any] = [:]
        if let data = try? Data(contentsOf: settingsURL) {
            guard let parsed = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any] else {
                return .failure("Claude Code Setup", "~/.claude/settings.json exists but is not valid JSON; not touching it.")
            }
            root = parsed
        }

        var hooks = root["hooks"] as? [String: Any] ?? [:]
        var changedEvents: [String] = []
        for event in ["Stop", "Notification"] {
            var entries = hooks[event] as? [[String: Any]] ?? []
            let alreadyInstalled = entries.contains { entry in
                ((entry["hooks"] as? [[String: Any]]) ?? []).contains { hook in
                    (hook["command"] as? String)?.contains("macforge") == true
                }
            }
            guard !alreadyInstalled else { continue }
            entries.append([
                "hooks": [
                    [
                        "type": "command",
                        "command": scriptURL.path,
                    ] as [String: Any]
                ]
            ])
            hooks[event] = entries
            changedEvents.append(event)
        }

        guard !changedEvents.isEmpty else {
            return .success("Claude Code Setup", "MacForge hooks are already installed in ~/.claude/settings.json.")
        }
        root["hooks"] = hooks

        do {
            var backupPath: String?
            if fileManager.fileExists(atPath: settingsURL.path) {
                let backup = settingsURL.appendingPathExtension("macforge-backup")
                try? fileManager.removeItem(at: backup)
                try fileManager.copyItem(at: settingsURL, to: backup)
                backupPath = backup.path
            } else {
                try fileManager.createDirectory(at: settingsURL.deletingLastPathComponent(), withIntermediateDirectories: true)
            }
            let data = try JSONSerialization.data(withJSONObject: root, options: [.prettyPrinted, .sortedKeys])
            try data.write(to: settingsURL, options: .atomic)
            var details = ["Hooks added: \(changedEvents.joined(separator: ", "))"]
            if let backupPath {
                details.append("Backup: \(backupPath)")
            }
            return .success("Claude Code Setup", "Claude Code will now report into the notch (restart Claude Code sessions to pick it up).", details: details)
        } catch {
            return .failure("Claude Code Setup", "Could not update ~/.claude/settings.json.", details: [error.localizedDescription])
        }
    }

    // MARK: Codex

    /// Points Codex's `notify` hook at MacForge via ~/.codex/config.toml.
    /// Never rewrites an existing custom notify program.
    static func installCodexNotify(
        configURL: URL = defaultCodexConfigURL,
        binDirectory: URL = AgentIntegrationInstaller.binDirectory
    ) -> CommandResult {
        let scriptURL = binDirectory.appendingPathComponent("macforge-codex-notify.sh")
        do {
            try installHelperScripts(at: binDirectory)
        } catch {
            return .failure("Codex Setup", "Could not install the MacForge notify script.", details: [error.localizedDescription])
        }

        let fileManager = FileManager.default
        var existing = ""
        if let data = try? Data(contentsOf: configURL), let text = String(data: data, encoding: .utf8) {
            existing = text
        }

        if existing.contains("macforge") {
            return .success("Codex Setup", "MacForge notify is already configured in ~/.codex/config.toml.")
        }
        if existing.range(of: #"(?m)^\s*notify\s*="#, options: .regularExpression) != nil {
            return .failure(
                "Codex Setup",
                "~/.codex/config.toml already sets a custom `notify` program; add MacForge manually.",
                details: ["Point it at: \(scriptURL.path)"]
            )
        }

        do {
            var backupPath: String?
            if fileManager.fileExists(atPath: configURL.path) {
                let backup = configURL.appendingPathExtension("macforge-backup")
                try? fileManager.removeItem(at: backup)
                try fileManager.copyItem(at: configURL, to: backup)
                backupPath = backup.path
            } else {
                try fileManager.createDirectory(at: configURL.deletingLastPathComponent(), withIntermediateDirectories: true)
            }
            var updated = existing
            if !updated.isEmpty, !updated.hasSuffix("\n") {
                updated += "\n"
            }
            updated += "\n# Added by MacForge — turn notifications in the notch\nnotify = [\"\(scriptURL.path)\"]\n"
            try updated.data(using: .utf8)?.write(to: configURL, options: .atomic)
            var details = ["notify → \(scriptURL.path)"]
            if let backupPath {
                details.append("Backup: \(backupPath)")
            }
            return .success("Codex Setup", "Codex will now report turn completions into the notch.", details: details)
        } catch {
            return .failure("Codex Setup", "Could not update ~/.codex/config.toml.", details: [error.localizedDescription])
        }
    }

    // MARK: Helper scripts

    static func installHelperScripts(at directory: URL = AgentIntegrationInstaller.binDirectory) throws {
        let fileManager = FileManager.default
        try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
        try writeExecutable(claudeHookScript, to: directory.appendingPathComponent("macforge-claude-hook.sh"))
        try writeExecutable(codexNotifyScript, to: directory.appendingPathComponent("macforge-codex-notify.sh"))
    }

    private static func writeExecutable(_ content: String, to url: URL) throws {
        try content.data(using: .utf8)?.write(to: url, options: .atomic)
        try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: url.path)
    }

    /// Claude Code hook: receives the hook JSON on stdin, appends a MacForge
    /// event line. Field extraction is a permissive sed pull — worst case the
    /// notch shows a generic title, never a broken line.
    private static let claudeHookScript = #"""
    #!/bin/zsh
    # MacForge ⟷ Claude Code hook (installed by MacForge; safe to delete).
    LOG="${MACFORGE_AGENT_EVENTS:-$HOME/Library/Application Support/MacForge/agent-events.jsonl}"
    payload=$(cat 2>/dev/null || true)

    pull() {
        printf '%s' "$payload" | /usr/bin/sed -n "s/.*\"$1\"[[:space:]]*:[[:space:]]*\"\([^\"]*\)\".*/\1/p" | /usr/bin/head -1
    }

    event=$(pull hook_event_name)
    session=$(pull session_id)
    message=$(pull message)

    case "$event" in
        Stop)
            kind="done"; state="success"; title="Turn complete"; body="" ;;
        Notification)
            kind="notification"; state="info"; title="${message:-Attention needed}"; body="" ;;
        *)
            kind="notification"; state="info"; title="${event:-Claude Code}"; body="${message}" ;;
    esac

    esc() { printf '%s' "$1" | /usr/bin/sed 's/\\/\\\\/g; s/"/\\"/g' | /usr/bin/tr -d '\n\r'; }

    /bin/mkdir -p "$(dirname "$LOG")"
    printf '{"id":"claude-%s","source":"Claude Code","kind":"%s","title":"%s","message":"%s","state":"%s"}\n' \
        "$(esc "${session:-code}")" "$kind" "$(esc "$title")" "$(esc "$body")" "$state" >> "$LOG"
    """#

    /// Codex notify hook: Codex passes a JSON payload as the last argument.
    private static let codexNotifyScript = #"""
    #!/bin/zsh
    # MacForge ⟷ Codex notify hook (installed by MacForge; safe to delete).
    LOG="${MACFORGE_AGENT_EVENTS:-$HOME/Library/Application Support/MacForge/agent-events.jsonl}"
    payload="${@: -1}"

    pull() {
        printf '%s' "$payload" | /usr/bin/sed -n "s/.*\"$1\"[[:space:]]*:[[:space:]]*\"\([^\"]*\)\".*/\1/p" | /usr/bin/head -1
    }

    type=$(pull type)
    message=$(pull last-assistant-message)

    case "$type" in
        agent-turn-complete)
            kind="done"; state="success"; title="Turn complete" ;;
        *)
            kind="notification"; state="info"; title="${type:-Codex}" ;;
    esac

    esc() { printf '%s' "$1" | /usr/bin/sed 's/\\/\\\\/g; s/"/\\"/g' | /usr/bin/tr -d '\n\r'; }

    /bin/mkdir -p "$(dirname "$LOG")"
    printf '{"id":"codex","source":"Codex","kind":"%s","title":"%s","message":"%s","state":"%s"}\n' \
        "$kind" "$(esc "$title")" "$(esc "${message}")" "$state" >> "$LOG"
    """#
}
