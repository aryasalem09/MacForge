import Foundation

struct PresetTransaction: Identifiable, Codable, Hashable {
    var id: UUID
    var presetName: String
    var oldStateSnapshot: [String: String]
    var actions: [PresetAction]
    var results: [CommandResult]
    var startedAt: Date
    var finishedAt: Date?

    init(
        id: UUID = UUID(),
        presetName: String,
        oldStateSnapshot: [String: String] = [:],
        actions: [PresetAction],
        results: [CommandResult] = [],
        startedAt: Date = Date(),
        finishedAt: Date? = nil
    ) {
        self.id = id
        self.presetName = presetName
        self.oldStateSnapshot = oldStateSnapshot
        self.actions = actions
        self.results = results
        self.startedAt = startedAt
        self.finishedAt = finishedAt
    }

    var rollbackAvailable: Bool {
        results.contains { $0.reversible }
    }

    mutating func record(_ result: CommandResult) {
        results.append(result)
    }

    mutating func finish() {
        finishedAt = Date()
    }
}
