import Foundation

enum FileRuleMatchKind: Codable, Hashable {
    case fileExtension(String)
    case filenameContains(String)
    case olderThanDays(Int)
    case largerThanMB(Int)

    var label: String {
        switch self {
        case .fileExtension(let value): "Extension is .\(value)"
        case .filenameContains(let value): "Name contains \(value)"
        case .olderThanDays(let days): "Older than \(days) days"
        case .largerThanMB(let size): "Larger than \(size) MB"
        }
    }
}

enum FileRuleAction: Codable, Hashable {
    case moveToFolder(UUID)
    case copyToFolder(UUID)
    case tag(String)
    case moveToTrash

    var label: String {
        switch self {
        case .moveToFolder: "Move to folder"
        case .copyToFolder: "Copy to folder"
        case .tag(let tag): "Tag \(tag)"
        case .moveToTrash: "Move to Trash"
        }
    }
}

struct FileRule: Identifiable, Codable, Hashable {
    var id: UUID
    var name: String
    var sourceFolderID: UUID?
    var matchKind: FileRuleMatchKind
    var action: FileRuleAction
    var dryRunOnly: Bool
    var isEnabled: Bool

    init(
        id: UUID = UUID(),
        name: String,
        sourceFolderID: UUID? = nil,
        matchKind: FileRuleMatchKind,
        action: FileRuleAction,
        dryRunOnly: Bool = true,
        isEnabled: Bool = true
    ) {
        self.id = id
        self.name = name
        self.sourceFolderID = sourceFolderID
        self.matchKind = matchKind
        self.action = action
        self.dryRunOnly = dryRunOnly
        self.isEnabled = isEnabled
    }
}
