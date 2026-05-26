import Foundation

protocol WindowManaging {
    func listWindows() async -> ([WindowInfo], [CommandResult])
    func tileFocusedWindow(_ layout: WindowLayoutType, customGrid: CustomGridSelection?) async -> CommandResult
}
