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

    func testBuildResetCommandsUsesOnlyWhitelistedExecutables() throws {
        let commands = try DockCommandBuilder().buildResetCommands()

        XCTAssertEqual(commands.last?.executablePath, DockCommandBuilder.killallPath)
        XCTAssertEqual(commands.last?.arguments, ["Dock"])
        for command in commands {
            XCTAssertNoThrow(try DockCommandBuilder().validate(command))
        }
    }

    func testBuildRestoreManagedKeysForcesAutohideOff() throws {
        let commands = try DockCommandBuilder().buildRestoreManagedKeysCommands()

        XCTAssertTrue(commands.contains {
            $0.executablePath == DockCommandBuilder.defaultsPath &&
            $0.arguments == ["write", DockCommandBuilder.dockDomain, "autohide", "-bool", "false"]
        })
        XCTAssertTrue(commands.contains {
            $0.arguments == ["delete", DockCommandBuilder.dockDomain, "autohide-delay"]
        })
        XCTAssertEqual(commands.last?.arguments, ["Dock"])
        for command in commands {
            XCTAssertNoThrow(try DockCommandBuilder().validate(command))
        }
    }

    func testRejectsMalformedDefaultsCommand() {
        let command = SafeCommand(
            executablePath: DockCommandBuilder.defaultsPath,
            arguments: ["write", "com.apple.finder", "AppleShowAllFiles", "-bool", "true"],
            summary: "Wrong domain"
        )

        XCTAssertThrowsError(try DockCommandBuilder().validate(command))
    }

    func testRejectsUnknownDockKey() {
        let command = SafeCommand(
            executablePath: DockCommandBuilder.defaultsPath,
            arguments: ["write", DockCommandBuilder.dockDomain, "persistent-apps", "-array", ""],
            summary: "Unsafe Dock mutation"
        )

        XCTAssertThrowsError(try DockCommandBuilder().validate(command))
    }

    func testDockServiceRequiresExperimentalSwitchForApplyAndReset() async {
        let applyResults = await DockSettingsService().apply(.default, experimentalTweaksEnabled: false)
        let resetResults = await DockSettingsService().resetToSystemDefaults(experimentalTweaksEnabled: false)

        XCTAssertEqual(applyResults.count, 1)
        XCTAssertEqual(resetResults.count, 1)
        XCTAssertFalse(applyResults[0].success)
        XCTAssertFalse(resetResults[0].success)
        XCTAssertEqual(applyResults[0].title, "Experimental Dock Tweaks")
        XCTAssertEqual(resetResults[0].title, "Experimental Dock Tweaks")
    }
}
