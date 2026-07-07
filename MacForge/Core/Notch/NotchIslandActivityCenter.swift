import Combine
import Foundation

@MainActor
final class NotchIslandActivityCenter: ObservableObject {
    @Published var presentationState: NotchIslandPresentationState
    @Published private(set) var currentActivity: NotchIslandActivity?
    @Published private(set) var recentActivities: [NotchIslandActivity]

    var nowProvider: () -> Date

    init(
        presentationState: NotchIslandPresentationState = .collapsed,
        currentActivity: NotchIslandActivity? = nil,
        recentActivities: [NotchIslandActivity] = [],
        nowProvider: @escaping () -> Date = Date.init
    ) {
        self.presentationState = presentationState
        self.currentActivity = currentActivity
        self.recentActivities = recentActivities
        self.nowProvider = nowProvider
    }

    func showActivity(
        kind: NotchIslandActivityKind,
        title: String,
        message: String,
        symbolName: String,
        duration: TimeInterval? = nil,
        progress: Double? = nil,
        isError: Bool = false,
        commandResultID: UUID? = nil
    ) {
        let now = nowProvider()
        let activity = NotchIslandActivity(
            kind: kind,
            title: title,
            message: message,
            symbolName: symbolName,
            startedAt: now,
            expiresAt: duration.map { now.addingTimeInterval($0) },
            progress: progress,
            isError: isError,
            commandResultID: commandResultID
        )

        currentActivity = activity
        recentActivities.insert(activity, at: 0)
        recentActivities = Array(recentActivities.prefix(12))
        // A new activity surfaces the compact presentation, but never shrinks
        // an island the user already has expanded.
        if presentationState != .expanded {
            presentationState = .compact
        }
    }

    func showCommandResult(_ result: CommandResult, autoCollapseDelay: TimeInterval) {
        showActivity(
            kind: activityKind(for: result),
            title: result.title,
            message: result.message,
            symbolName: symbolName(for: result),
            duration: autoCollapseDelay,
            isError: !result.success,
            commandResultID: result.id
        )
    }

    func expand() {
        presentationState = .expanded
    }

    func collapse() {
        presentationState = .collapsed
    }

    func hide() {
        presentationState = .hidden
    }

    func clearActivity() {
        currentActivity = nil
        if presentationState == .compact {
            presentationState = .collapsed
        }
    }

    func autoCollapseIfNeeded(now: Date? = nil) {
        guard let activity = currentActivity,
              let expiresAt = activity.expiresAt else {
            return
        }

        let date = now ?? nowProvider()
        guard date >= expiresAt else { return }
        currentActivity = nil
        if presentationState == .compact {
            presentationState = .collapsed
        }
    }

    private func activityKind(for result: CommandResult) -> NotchIslandActivityKind {
        guard result.success else { return .error }

        let title = result.title.lowercased()
        if title.contains("window") || title.contains("display") || title.contains("left") || title.contains("right") || title.contains("center") {
            return .windowAction
        }
        if title.contains("preset") {
            return .preset
        }
        if title.contains("file rule") {
            return .fileRule
        }
        if title.contains("rename") {
            return .bulkRename
        }
        if title.contains("duplicate") {
            return .duplicateScan
        }
        if title.contains("folder") {
            return .folder
        }
        if title.contains("wallpaper") {
            return .wallpaper
        }
        if title.contains("dock") {
            return .dock
        }
        if title.contains("permission") || title.contains("accessibility") {
            return .permission
        }
        if title.contains("shortcuts") {
            return .shortcut
        }
        return .idle
    }

    private func symbolName(for result: CommandResult) -> String {
        guard result.success else { return "exclamationmark.triangle.fill" }

        switch activityKind(for: result) {
        case .idle:
            return "checkmark.circle.fill"
        case .windowAction:
            return "rectangle.3.group"
        case .preset:
            return "sparkles.rectangle.stack"
        case .fileRule:
            return "line.3.horizontal.decrease.circle"
        case .bulkRename:
            return "textformat"
        case .duplicateScan:
            return "doc.on.doc"
        case .folder:
            return "folder"
        case .wallpaper:
            return "photo"
        case .dock:
            return "dock.rectangle"
        case .permission:
            return "lock.shield"
        case .shortcut:
            return "wand.and.stars"
        case .error:
            return "exclamationmark.triangle.fill"
        }
    }
}
