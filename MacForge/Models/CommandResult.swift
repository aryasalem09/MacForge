import Foundation

struct CommandResult: Identifiable, Codable, Hashable {
    var id: UUID
    var title: String
    var success: Bool
    var message: String
    var details: [String]
    var timestamp: Date
    var reversible: Bool
    var rollbackActionID: String?

    init(
        id: UUID = UUID(),
        title: String,
        success: Bool,
        message: String,
        details: [String] = [],
        timestamp: Date = Date(),
        reversible: Bool = false,
        rollbackActionID: String? = nil
    ) {
        self.id = id
        self.title = title
        self.success = success
        self.message = message
        self.details = details
        self.timestamp = timestamp
        self.reversible = reversible
        self.rollbackActionID = rollbackActionID
    }

    static func success(_ title: String, _ message: String, details: [String] = [], reversible: Bool = false) -> CommandResult {
        CommandResult(title: title, success: true, message: message, details: details, reversible: reversible)
    }

    static func failure(_ title: String, _ message: String, details: [String] = []) -> CommandResult {
        CommandResult(title: title, success: false, message: message, details: details)
    }
}
