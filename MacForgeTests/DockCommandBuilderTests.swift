import XCTest
@testable import MacForge

final class DockCommandBuilderTests: XCTestCase {
    func testBuildApplyCommandsUsesWhitelistedExecutables() throws {
        let commands = try DockCommandBuilder().buildApplyCommands(for: .default)

        XCTAssertTrue(commands.contains { $0.executablePath == DockCommandBuilder.defaultsPath })
        XCTAssertTrue(commands.contains { $0.executablePath == DockCommandBuilder.killallPath && $0.arguments == ["Dock"] })
        for command in commands {
            XCTAssertNoThrow(try DockCommandBuilder().validate(command))
        }
    }

    func testRejectsUnsafeCommand() {
        let command = SafeCommand(executablePath: "/bin/sh", arguments: ["-c", "defaults write com.apple.dock autohide true"], summary: "Unsafe")
        XCTAssertThrowsError(try DockCommandBuilder().validate(command))
    }

    func testRejectsInvalidDockSize() {
        let settings = DockSettings(autoHide: true, tileSize: 400, magnification: false, magnificationSize: 64, position: .bottom, showRecentApps: true)
        XCTAssertThrowsError(try DockCommandBuilder().buildApplyCommands(for: settings))
    }
}
