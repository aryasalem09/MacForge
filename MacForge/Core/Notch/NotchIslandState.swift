import Foundation

enum NotchIslandPresentationState: String, Codable, CaseIterable, Identifiable, Hashable {
    case hidden
    case collapsed
    case compact
    case expanded

    var id: String { rawValue }

    var label: String {
        switch self {
        case .hidden: "Hidden"
        case .collapsed: "Collapsed"
        case .compact: "Compact"
        case .expanded: "Expanded"
        }
    }
}

enum NotchIslandActivityKind: String, Codable, CaseIterable, Identifiable, Hashable {
    case idle
    case windowAction
    case preset
    case fileRule
    case bulkRename
    case duplicateScan
    case folder
    case wallpaper
    case dock
    case permission
    case shortcut
    case error

    var id: String { rawValue }
}

struct NotchIslandActivity: Identifiable, Codable, Hashable {
    var id: UUID
    var kind: NotchIslandActivityKind
    var title: String
    var message: String
    var symbolName: String
    var startedAt: Date
    var expiresAt: Date?
    var progress: Double?
    var isError: Bool
    var commandResultID: UUID?

    init(
        id: UUID = UUID(),
        kind: NotchIslandActivityKind,
        title: String,
        message: String,
        symbolName: String,
        startedAt: Date = Date(),
        expiresAt: Date? = nil,
        progress: Double? = nil,
        isError: Bool = false,
        commandResultID: UUID? = nil
    ) {
        self.id = id
        self.kind = kind
        self.title = title
        self.message = message
        self.symbolName = symbolName
        self.startedAt = startedAt
        self.expiresAt = expiresAt
        self.progress = progress
        self.isError = isError
        self.commandResultID = commandResultID
    }

    static func idle(at date: Date = Date()) -> NotchIslandActivity {
        NotchIslandActivity(
            kind: .idle,
            title: "Idle",
            message: "MacForge ready",
            symbolName: "sparkle",
            startedAt: date
        )
    }
}
