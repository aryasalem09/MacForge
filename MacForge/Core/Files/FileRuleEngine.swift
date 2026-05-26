import Foundation

struct FileCandidate: Hashable {
    var url: URL
    var sizeBytes: Int64?
    var modificationDate: Date?
}

struct FileRulePreview: Identifiable, Hashable {
    var id = UUID()
    var fileURL: URL
    var actionDescription: String
    var destinationURL: URL?
    var isDestructive: Bool
}

struct FileRuleEngine {
    func matches(_ rule: FileRule, candidate: FileCandidate, now: Date = Date()) -> Bool {
        guard rule.isEnabled else { return false }

        switch rule.matchKind {
        case .fileExtension(let fileExtension):
            return candidate.url.pathExtension.localizedCaseInsensitiveCompare(fileExtension.trimmingCharacters(in: CharacterSet(charactersIn: "."))) == .orderedSame
        case .filenameContains(let text):
            return candidate.url.deletingPathExtension().lastPathComponent.localizedCaseInsensitiveContains(text)
        case .olderThanDays(let days):
            guard let modificationDate = candidate.modificationDate else { return false }
            let age = Calendar.current.dateComponents([.day], from: modificationDate, to: now).day ?? 0
            return age >= days
        case .largerThanMB(let megabytes):
            guard let sizeBytes = candidate.sizeBytes else { return false }
            return sizeBytes >= Int64(megabytes) * 1_024 * 1_024
        }
    }

    func preview(rule: FileRule, candidates: [FileCandidate], destinationResolver: (UUID) -> URL?) -> [FileRulePreview] {
        candidates.compactMap { candidate in
            guard matches(rule, candidate: candidate) else { return nil }
            switch rule.action {
            case .moveToFolder(let id):
                let destination = destinationResolver(id)?.appendingPathComponent(candidate.url.lastPathComponent)
                return FileRulePreview(fileURL: candidate.url, actionDescription: "Move to \(destination?.deletingLastPathComponent().path ?? "destination")", destinationURL: destination, isDestructive: false)
            case .copyToFolder(let id):
                let destination = destinationResolver(id)?.appendingPathComponent(candidate.url.lastPathComponent)
                return FileRulePreview(fileURL: candidate.url, actionDescription: "Copy to \(destination?.deletingLastPathComponent().path ?? "destination")", destinationURL: destination, isDestructive: false)
            case .tag(let tag):
                return FileRulePreview(fileURL: candidate.url, actionDescription: "Apply Finder tag \(tag)", destinationURL: nil, isDestructive: false)
            case .moveToTrash:
                return FileRulePreview(fileURL: candidate.url, actionDescription: "Move to Trash", destinationURL: nil, isDestructive: true)
            }
        }
    }
}
