//
//  TestSupport.swift
//  2026 New Relic
//

import Foundation
import XCTest
@testable import SymbolTool

enum Fixture {
    static func text(_ name: String, _ ext: String = "txt", file: StaticString = #filePath, line: UInt = #line) throws -> String {
        let url = try XCTUnwrap(Bundle.module.url(forResource: name, withExtension: ext, subdirectory: "Fixtures"),
                                "missing fixture \(name).\(ext)", file: file, line: line)
        return try String(contentsOf: url, encoding: .utf8)
    }
}

/// Records every command and answers from a handler. Thread-safe: the tool runs binaries concurrently.
final class FakeCommandRunner: CommandRunning {
    private let lock = NSLock()
    private var recorded: [(command: String, arguments: [String])] = []
    let handler: (String, [String]) throws -> CommandResult

    var invocations: [(command: String, arguments: [String])] {
        lock.lock(); defer { lock.unlock() }
        return recorded
    }

    init(handler: @escaping (String, [String]) throws -> CommandResult = { _, _ in CommandResult(exitStatus: 0, output: "", errorOutput: "") }) {
        self.handler = handler
    }

    func run(_ command: String, _ arguments: [String]) throws -> CommandResult {
        lock.lock()
        recorded.append((command, arguments))
        lock.unlock()
        return try handler(command, arguments)
    }

    /// Answers `symbols` calls with the TestApp fixtures, and `curl` calls with `curlStatus`.
    static func symbolsFixtures(curlStatus: String = "201") throws -> FakeCommandRunner {
        let uuids = try Fixture.text("TestApp-uuid")
        let arm64 = try Fixture.text("TestApp-arm64")
        let x86 = try Fixture.text("TestApp-x86_64")
        return FakeCommandRunner { command, arguments in
            guard command == "symbols" else { return CommandResult(exitStatus: 0, output: curlStatus, errorOutput: "") }
            switch arguments.first {
            case "-uuid": return CommandResult(exitStatus: 0, output: uuids, errorOutput: "")
            case "-arch": return CommandResult(exitStatus: 0, output: arguments[1] == "arm64" ? arm64 : x86, errorOutput: "")
            default: return CommandResult(exitStatus: 64, output: "", errorOutput: "unexpected")
            }
        }
    }
}

final class FakeUploader: SymbolUploading {
    struct TelemetryFailure: Error {}

    var mapStatus = 201
    var mapCurlExitStatus: Int32 = 0
    var dsymStatus = 201
    var telemetryStatus = 200
    var telemetryThrows = false
    private(set) var uploads: [(kind: UploadKind, archiveName: String, size: UInt64, zipEntries: [String])] = []
    private(set) var telemetrySizes: [UInt64] = []

    func upload(_ archive: URL, kind: UploadKind, size: UInt64) throws -> UploadResponse {
        // The archive is deleted after the pipeline finishes, so list its contents now.
        uploads.append((kind, archive.lastPathComponent, size, Self.zipEntries(archive)))
        return kind == .map ? UploadResponse(statusCode: mapStatus, curlExitStatus: mapCurlExitStatus)
                            : UploadResponse(statusCode: dsymStatus, curlExitStatus: 0)
    }

    func sendOversizedMapTelemetry(size: UInt64) throws -> UploadResponse {
        telemetrySizes.append(size)
        if telemetryThrows { throw TelemetryFailure() }
        return UploadResponse(statusCode: telemetryStatus, curlExitStatus: 0)
    }

    private static func zipEntries(_ archive: URL) -> [String] {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/zipinfo")
        process.arguments = ["-1", archive.path]
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = FileHandle.nullDevice
        guard (try? process.run()) != nil else { return [] }
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()
        return String(decoding: data, as: UTF8.self).split(separator: "\n").map(String.init).sorted()
    }
}

final class LogCapture {
    private let lock = NSLock()
    private var recorded: [String] = []
    var lines: [String] { lock.lock(); defer { lock.unlock() }; return recorded }
    var write: (String) -> Void { { line in self.lock.lock(); self.recorded.append(line); self.lock.unlock() } }
    var text: String { lines.joined(separator: "\n") }
}

/// A `$DWARF_DSYM_FOLDER_PATH`-style folder with one `.dSYM` bundle per name.
func makeDsymFolder(_ names: [String]) throws -> URL {
    let folder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    for name in names {
        let dwarf = folder.appendingPathComponent("\(name).dSYM/Contents/Resources/DWARF")
        try FileManager.default.createDirectory(at: dwarf, withIntermediateDirectories: true)
        try Data("dwarf".utf8).write(to: dwarf.appendingPathComponent(name))
    }
    return folder
}
