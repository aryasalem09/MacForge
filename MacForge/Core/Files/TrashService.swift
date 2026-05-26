import Foundation

struct TrashService {
    func moveToTrash(_ url: URL) -> CommandResult {
        do {
            var resultingURL: NSURL?
            try FileManager.default.trashItem(at: url, resultingItemURL: &resultingURL)
            return .success("Move to Trash", "Moved \(url.lastPathComponent) to Trash.", details: [resultingURL?.path ?? ""])
        } catch {
            return .failure("Move to Trash", "Could not move \(url.lastPathComponent) to Trash.", details: [error.localizedDescription])
        }
    }
}
