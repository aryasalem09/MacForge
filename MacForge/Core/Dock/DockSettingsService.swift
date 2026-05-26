import Foundation

struct DockSettingsService: DockManaging {
    private let builder = DockCommandBuilder()
    private let runner = ProcessRunner()

    func apply(_ settings: DockSettings, experimentalTweaksEnabled: Bool) async -> [CommandResult] {
        guard experimentalTweaksEnabled else {
            return [.failure("Experimental Dock Tweaks", "Enable Experimental Dock Tweaks in Safety Settings before changing Dock preferences.")]
        }

        do {
            let commands = try builder.buildApplyCommands(for: settings)
            var results: [CommandResult] = []
            for command in commands {
                results.append(await runner.run(command))
            }
            return results
        } catch {
            return [.failure("Dock Settings", "Could not build safe Dock commands.", details: [error.localizedDescription])]
        }
    }

    func resetToSystemDefaults(experimentalTweaksEnabled: Bool) async -> [CommandResult] {
        guard experimentalTweaksEnabled else {
            return [.failure("Experimental Dock Tweaks", "Enable Experimental Dock Tweaks before resetting Dock preferences.")]
        }

        do {
            let commands = try builder.buildResetCommands()
            var results: [CommandResult] = []
            for command in commands {
                results.append(await runner.run(command))
            }
            return results
        } catch {
            return [.failure("Dock Reset", "Could not build reset commands.", details: [error.localizedDescription])]
        }
    }
}
