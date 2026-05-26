import Foundation

struct BulkRenameRequest: Codable, Hashable {
    var prefix: String
    var suffix: String
    var findText: String
    var replaceText: String
    var sequenceEnabled: Bool
    var sequenceStart: Int
    var preserveExtension: Bool

    static let empty = BulkRenameRequest(
        prefix: "",
        suffix: "",
        findText: "",
        replaceText: "",
        sequenceEnabled: false,
        sequenceStart: 1,
        preserveExtension: true
    )
}

struct BulkRenamePreviewItem: Identifiable, Hashable {
    var id = UUID()
    var originalURL: URL
    var newName: String
    var newURL: URL
    var hasCollision: Bool

    var changed: Bool {
        originalURL.lastPathComponent != newName
    }
}

struct BulkRenameEngine {
    func preview(urls: [URL], request: BulkRenameRequest) -> [BulkRenamePreviewItem] {
        var proposedNames: [String: Int] = [:]

        let preliminary = urls.enumerated().map { index, url in
            let originalName = url.lastPathComponent
            let ext = url.pathExtension
            let stem = request.preserveExtension && !ext.isEmpty ? url.deletingPathExtension().lastPathComponent : originalName
            var newStem = stem

            if !request.findText.isEmpty {
                newStem = newStem.replacingOccurrences(of: request.findText, with: request.replaceText)
            }

            newStem = request.prefix + newStem + request.suffix

            if request.sequenceEnabled {
                let sequence = String(format: "%03d", request.sequenceStart + index)
                newStem += "-\(sequence)"
            }

            let newName: String
            if request.preserveExtension && !ext.isEmpty {
                newName = "\(newStem).\(ext)"
            } else {
                newName = newStem
            }

            proposedNames[newName, default: 0] += 1
            return (url, newName)
        }

        return preliminary.map { url, newName in
            let destination = url.deletingLastPathComponent().appendingPathComponent(newName)
            let collision = proposedNames[newName, default: 0] > 1 || (FileManager.default.fileExists(atPath: destination.path) && destination != url)
            return BulkRenamePreviewItem(originalURL: url, newName: newName, newURL: destination, hasCollision: collision)
        }
    }
}
