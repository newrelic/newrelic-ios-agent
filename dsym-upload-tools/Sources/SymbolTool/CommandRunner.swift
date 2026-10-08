//
//  CommandRunner.swift
//  2026 New Relic
//

import Foundation

struct CommandResult {
    let exitStatus: Int32
    let output: String
    let errorOutput: String

    var succeeded: Bool { exitStatus == 0 }
}

/// Runs external tools (`symbols`, `curl`). Abstracted so tests can supply canned output.
protocol CommandRunning {
    func run(_ command: String, _ arguments: [String]) throws -> CommandResult
}

/// Launches commands directly with an argument array (no shell), so paths and tokens
/// containing quotes, spaces or `$` are passed through untouched.
struct ProcessCommandRunner: CommandRunning {
    func run(_ command: String, _ arguments: [String]) throws -> CommandResult {
        let process = Process()
        // `env` resolves the command on PATH the same way the previous `zsh -c` invocation did.
        process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        process.arguments = [command] + arguments
        process.standardInput = FileHandle.nullDevice

        let outputPipe = Pipe()
        let errorPipe = Pipe()
        process.standardOutput = outputPipe
        process.standardError = errorPipe

        try process.run()

        // Drain stderr on another thread so a chatty child can't fill the pipe and block on write.
        let errorData = DataBox()
        let group = DispatchGroup()
        group.enter()
        DispatchQueue.global().async {
            errorData.value = errorPipe.fileHandleForReading.readDataToEndOfFile()
            group.leave()
        }
        let outputData = outputPipe.fileHandleForReading.readDataToEndOfFile()
        group.wait()
        process.waitUntilExit()

        return CommandResult(exitStatus: process.terminationStatus,
                             output: String(decoding: outputData, as: UTF8.self),
                             errorOutput: String(decoding: errorData.value, as: UTF8.self))
    }
}

/// Written once on the reader thread; `group.wait()` orders that write before the read.
private final class DataBox: @unchecked Sendable {
    var value = Data()
}
