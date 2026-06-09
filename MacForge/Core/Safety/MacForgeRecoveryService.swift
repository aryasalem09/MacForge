import Foundation

struct MacForgeRecoveryService {
    private let dockCommandBuilder: DockCommandBuilder
    private let processRunner: ProcessRunner

    init(
        dockCommandBuilder: DockCommandBuilder = DockCommandBuilder(),
        processRunner: ProcessRunner = ProcessRunner()
    ) {
        self.dockCommandBuilder = dockCommandBuilder
        self.processRunner = processRunner
    }

    func restoreDockManagedKeys() async -> [CommandResult] {
        do {
            let commands = try dockCommandBuilder.buildRestoreManagedKeysCommands()
            var results: [CommandResult] = []
            for command in commands {
                results.append(await processRunner.run(command))
            }
            return results
        } catch {
            return [.failure("Dock Recovery", "Could not build safe Dock recovery commands.", details: [error.localizedDescription])]
        }
    }

    func restoreDockManagedKeyPreview() -> [SafeCommand] {
        (try? dockCommandBuilder.buildRestoreManagedKeysCommands()) ?? []
    }
}
