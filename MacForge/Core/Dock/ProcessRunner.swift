import Foundation

struct ProcessRunner {
    func run(_ command: SafeCommand) async -> CommandResult {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: command.executablePath)
        process.arguments = command.arguments

        let outputPipe = Pipe()
        let errorPipe = Pipe()
        process.standardOutput = outputPipe
        process.standardError = errorPipe

        do {
            try process.run()
            process.waitUntilExit()

            let output = String(data: outputPipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
            let errorOutput = String(data: errorPipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
            let details = [output, errorOutput].filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }

            if process.terminationStatus == 0 {
                return .success(command.summary, "Command completed.", details: details, reversible: true)
            }
            return .failure(command.summary, "Command exited with status \(process.terminationStatus).", details: details)
        } catch {
            return .failure(command.summary, "Could not run command.", details: [error.localizedDescription])
        }
    }
}
