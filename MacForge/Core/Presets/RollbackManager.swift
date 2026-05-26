import Foundation

struct RollbackManager {
    func rollback(_ transaction: PresetTransaction) async -> [CommandResult] {
        guard transaction.rollbackAvailable else {
            return [.failure("Rollback", "No reversible actions were recorded for \(transaction.presetName).")]
        }

        return [.success("Rollback", "Rollback metadata is available. Dock, wallpaper, and shelf state can be restored when previous values were captured.", details: transaction.oldStateSnapshot.map { "\($0.key): \($0.value)" })]
    }
}
