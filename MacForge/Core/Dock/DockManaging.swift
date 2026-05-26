import Foundation

protocol DockManaging {
    func apply(_ settings: DockSettings, experimentalTweaksEnabled: Bool) async -> [CommandResult]
    func resetToSystemDefaults(experimentalTweaksEnabled: Bool) async -> [CommandResult]
}
