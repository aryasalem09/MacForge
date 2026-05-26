import Foundation

struct RollbackManager {
    func rollback(_ transaction: PresetTransaction, context: PresetRollbackContext) async -> [CommandResult] {
        guard let snapshot = transaction.rollbackSnapshot, snapshot.hasRestorableState else {
            return [.failure("Rollback", "No restorable snapshot was recorded for \(transaction.presetName).")]
        }

        var results: [CommandResult] = []

        if let enabled = snapshot.notchShelfEnabled {
            results.append(await context.restoreNotchShelf(enabled))
        }

        if let dockSettings = snapshot.dockSettings {
            results.append(contentsOf: await context.restoreDockSettings(dockSettings))
        }

        if !snapshot.wallpaperStates.isEmpty {
            results.append(contentsOf: await context.restoreWallpapers(snapshot.wallpaperStates))
        }

        if transaction.actions.contains(where: \.isFileOperation) {
            results.append(.failure("File Rule Rollback", "File-rule changes are not automatically reversible in v0.2.", details: [
                "Review command results and Finder Trash manually if a file rule moved files."
            ]))
        }

        return results.isEmpty
            ? [.failure("Rollback", "No restorable values were available for \(transaction.presetName).")]
            : results
    }
}

private extension PresetAction {
    var isFileOperation: Bool {
        if case .runFileRule = self {
            return true
        }
        return false
    }
}
