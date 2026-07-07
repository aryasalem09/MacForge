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

enum NotchHoverVisualState: String, Codable, CaseIterable, Identifiable, Hashable {
    case idle
    case hoverPending
    case expandedByHover
    case expandedByClick
    case collapsePending
    case draggingCalibration

    var id: String { rawValue }
}

enum NotchHoverAction: Equatable {
    case scheduleExpand
    case scheduleCollapse
    case cancelExpand
    case cancelCollapse
    case expand
    case collapse
}

struct NotchHoverStateMachine: Hashable {
    private(set) var state: NotchHoverVisualState = .idle
    private(set) var pointerInside = false

    mutating func pointerEntered(calibrationMode: Bool) -> [NotchHoverAction] {
        guard !calibrationMode else {
            state = .draggingCalibration
            pointerInside = true
            return [.cancelExpand, .cancelCollapse]
        }

        pointerInside = true
        switch state {
        case .idle, .collapsePending:
            state = .hoverPending
            return [.cancelCollapse, .scheduleExpand]
        case .hoverPending:
            return [.scheduleExpand]
        case .expandedByHover, .expandedByClick:
            return [.cancelCollapse]
        case .draggingCalibration:
            return [.cancelExpand, .cancelCollapse]
        }
    }

    mutating func pointerExited(calibrationMode: Bool) -> [NotchHoverAction] {
        pointerInside = false
        guard !calibrationMode else {
            return [.cancelExpand, .cancelCollapse]
        }

        switch state {
        case .hoverPending:
            state = .idle
            return [.cancelExpand]
        case .expandedByHover:
            state = .collapsePending
            return [.scheduleCollapse]
        case .collapsePending:
            return [.scheduleCollapse]
        case .idle, .expandedByClick, .draggingCalibration:
            return []
        }
    }

    mutating func hoverDelayElapsed(calibrationMode: Bool) -> [NotchHoverAction] {
        guard !calibrationMode,
              pointerInside,
              state == .hoverPending else {
            return []
        }

        state = .expandedByHover
        return [.expand]
    }

    mutating func collapseDelayElapsed(calibrationMode: Bool) -> [NotchHoverAction] {
        guard !calibrationMode,
              !pointerInside,
              state == .collapsePending else {
            return []
        }

        state = .idle
        return [.collapse]
    }

    mutating func clickToggle(isExpanded: Bool, calibrationMode: Bool) -> [NotchHoverAction] {
        guard !calibrationMode else { return [] }

        if isExpanded, state == .expandedByClick {
            state = .idle
            pointerInside = false
            return [.cancelExpand, .cancelCollapse, .collapse]
        }

        state = .expandedByClick
        pointerInside = true
        return [.cancelExpand, .cancelCollapse, .expand]
    }

    /// Force the machine into a held-open state to match a programmatic
    /// expand (swipe, chevron, Settings, App Intent). Behaves like a
    /// click-expand: it stays open on pointer exit until an explicit collapse.
    mutating func holdExpanded() -> [NotchHoverAction] {
        state = .expandedByClick
        pointerInside = true
        return [.cancelExpand, .cancelCollapse]
    }

    mutating func beginCalibrationDrag() -> [NotchHoverAction] {
        state = .draggingCalibration
        pointerInside = true
        return [.cancelExpand, .cancelCollapse]
    }

    mutating func endCalibrationDrag() -> [NotchHoverAction] {
        state = .idle
        pointerInside = false
        return [.cancelExpand, .cancelCollapse]
    }

    mutating func reset() -> [NotchHoverAction] {
        state = .idle
        pointerInside = false
        return [.cancelExpand, .cancelCollapse]
    }
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
