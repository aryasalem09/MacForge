import Foundation

struct SafeCommand: Identifiable, Codable, Hashable {
    var id: UUID
    var executablePath: String
    var arguments: [String]
    var summary: String

    init(id: UUID = UUID(), executablePath: String, arguments: [String], summary: String) {
        self.id = id
        self.executablePath = executablePath
        self.arguments = arguments
        self.summary = summary
    }
}

enum DockCommandBuilderError: Error, LocalizedError {
    case invalidDockSize
    case unsafeCommand

    var errorDescription: String? {
        switch self {
        case .invalidDockSize: "Dock size values must be between 16 and 128."
        case .unsafeCommand: "The command is outside MacForge's Dock command whitelist."
        }
    }
}

struct DockCommandBuilder {
    static let defaultsPath = "/usr/bin/defaults"
    static let killallPath = "/usr/bin/killall"
    static let dockDomain = "com.apple.dock"
    static let managedDockKeys: Set<String> = [
        "autohide",
        "autohide-delay",
        "autohide-time-modifier",
        "tilesize",
        "magnification",
        "largesize",
        "orientation",
        "show-recents"
    ]

    func buildApplyCommands(for settings: DockSettings, restartDock: Bool = true) throws -> [SafeCommand] {
        guard (16...128).contains(settings.tileSize), (16...256).contains(settings.magnificationSize) else {
            throw DockCommandBuilderError.invalidDockSize
        }

        var commands: [SafeCommand] = [
            defaultsWrite("autohide", type: "-bool", value: settings.autoHide ? "true" : "false", summary: "Set Dock auto-hide \(settings.autoHide ? "on" : "off")"),
            defaultsWrite("tilesize", type: "-float", value: String(Int(settings.tileSize)), summary: "Set Dock size to \(Int(settings.tileSize))"),
            defaultsWrite("magnification", type: "-bool", value: settings.magnification ? "true" : "false", summary: "Set Dock magnification \(settings.magnification ? "on" : "off")"),
            defaultsWrite("largesize", type: "-float", value: String(Int(settings.magnificationSize)), summary: "Set Dock magnification size to \(Int(settings.magnificationSize))"),
            defaultsWrite("orientation", type: "-string", value: settings.position.rawValue, summary: "Move Dock to \(settings.position.label.lowercased())"),
            defaultsWrite("show-recents", type: "-bool", value: settings.showRecentApps ? "true" : "false", summary: "Set recent apps in Dock \(settings.showRecentApps ? "on" : "off")")
        ]

        if restartDock {
            commands.append(restartDockCommand())
        }

        try commands.forEach(validate)
        return commands
    }

    func buildResetCommands() throws -> [SafeCommand] {
        let keys = ["autohide", "tilesize", "magnification", "largesize", "orientation", "show-recents"]
        var commands = keys.map {
            SafeCommand(executablePath: Self.defaultsPath, arguments: ["delete", Self.dockDomain, $0], summary: "Reset Dock \($0)")
        }
        commands.append(restartDockCommand())
        try commands.forEach(validate)
        return commands
    }

    func buildRestoreManagedKeysCommands() throws -> [SafeCommand] {
        let keysToDelete = [
            "autohide-delay",
            "autohide-time-modifier",
            "tilesize",
            "magnification",
            "largesize",
            "orientation",
            "show-recents"
        ]
        var commands = [
            defaultsWrite("autohide", type: "-bool", value: "false", summary: "Restore Dock auto-hide off")
        ]
        commands.append(contentsOf: keysToDelete.map {
            SafeCommand(executablePath: Self.defaultsPath, arguments: ["delete", Self.dockDomain, $0], summary: "Remove MacForge-managed Dock \($0)")
        })
        commands.append(restartDockCommand())
        try commands.forEach(validate)
        return commands
    }

    func validate(_ command: SafeCommand) throws {
        switch command.executablePath {
        case Self.defaultsPath:
            guard command.arguments.count >= 3,
                  ["write", "delete"].contains(command.arguments[0]),
                  command.arguments[1] == Self.dockDomain,
                  Self.managedDockKeys.contains(command.arguments[2]) else {
                throw DockCommandBuilderError.unsafeCommand
            }
            if command.arguments[0] == "write" {
                guard command.arguments.count == 5,
                      ["-bool", "-float", "-string"].contains(command.arguments[3]) else {
                    throw DockCommandBuilderError.unsafeCommand
                }
            } else if command.arguments[0] == "delete" {
                guard command.arguments.count == 3 else {
                    throw DockCommandBuilderError.unsafeCommand
                }
            }
        case Self.killallPath:
            guard command.arguments == ["Dock"] else {
                throw DockCommandBuilderError.unsafeCommand
            }
        default:
            throw DockCommandBuilderError.unsafeCommand
        }
    }

    private func defaultsWrite(_ key: String, type: String, value: String, summary: String) -> SafeCommand {
        SafeCommand(
            executablePath: Self.defaultsPath,
            arguments: ["write", Self.dockDomain, key, type, value],
            summary: summary
        )
    }

    private func restartDockCommand() -> SafeCommand {
        SafeCommand(executablePath: Self.killallPath, arguments: ["Dock"], summary: "Restart Dock to apply changes")
    }
}
