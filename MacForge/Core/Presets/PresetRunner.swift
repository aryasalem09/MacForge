import Foundation

struct PresetExecutionContext {
    var runAction: (PresetAction) async -> CommandResult
    var snapshotState: () -> [String: String]
    var rollbackSnapshot: () -> RollbackSnapshot
}

struct PresetRunner {
    func preview(_ preset: AppPreset) -> [String] {
        preset.actions.map(\.label)
    }

    func run(_ preset: AppPreset, context: PresetExecutionContext) async -> PresetTransaction {
        var transaction = PresetTransaction(
            presetName: preset.name,
            oldStateSnapshot: context.snapshotState(),
            rollbackSnapshot: context.rollbackSnapshot(),
            actions: preset.actions
        )

        for action in preset.actions {
            let result = await context.runAction(action)
            transaction.record(result)
        }

        transaction.finish()
        return transaction
    }
}
