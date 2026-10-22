//
//  SymbolUploadPipelineTests.swift
//  2026 New Relic
//

import XCTest
@testable import SymbolTool

final class SymbolUploadPipelineTests: XCTestCase {
    private var dwarfPath: String!
    private var scratch: URL!

    override func setUpWithError() throws {
        scratch = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: scratch, withIntermediateDirectories: true)
        dwarfPath = scratch.appendingPathComponent("TestApp").path
        try Data("not really dwarf".utf8).write(to: URL(fileURLWithPath: dwarfPath))
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: scratch)
    }

    private func makePipeline(runner: FakeCommandRunner, uploader: FakeUploader, threshold: UInt64 = 209_715_200,
                              log: LogCapture = LogCapture()) -> SymbolUploadPipeline {
        let logger = Logger(write: log.write)
        return SymbolUploadPipeline(converter: MapFileConverter(runner: runner, logger: logger),
                                    uploader: uploader, logger: logger, mapSizeThreshold: threshold)
    }

    func testUploadsOneArchiveContainingAMapPerArchitecture() throws {
        let uploader = FakeUploader()
        makePipeline(runner: try .symbolsFixtures(), uploader: uploader).process(dwarfPath: dwarfPath)

        XCTAssertEqual(uploader.uploads.count, 1)
        let upload = try XCTUnwrap(uploader.uploads.first)
        XCTAssertEqual(upload.kind, .map)
        XCTAssertEqual(upload.archiveName, "mapArchive.zip")
        // Same layout as the original tool: <scratch-dir>/<uuid>.map
        let maps = upload.zipEntries.filter { $0.hasSuffix(".map") }
        XCTAssertEqual(maps.map { $0.split(separator: "/").last.map(String.init) ?? "" },
                       ["a6a0824813a13bceaed80b6f92dfab3b.map", "bdbb53df45803bb69123234b492d9f65.map"])
        XCTAssertTrue(maps.allSatisfy { $0.split(separator: "/").count == 2 })
    }

    func testFailedMapUploadFallsBackToDsymUpload() throws {
        // Regression: the original tool logged a non-201 map response but never uploaded the dSYM.
        let uploader = FakeUploader()
        uploader.mapStatus = 500
        let log = LogCapture()
        makePipeline(runner: try .symbolsFixtures(), uploader: uploader, log: log).process(dwarfPath: dwarfPath)

        XCTAssertEqual(uploader.uploads.map(\.kind), [.map, .dsym])
        XCTAssertEqual(uploader.uploads.last?.archiveName, "dsymArchive.zip")
        XCTAssertTrue(uploader.uploads.last?.zipEntries.contains { $0.hasSuffix("/TestApp") } ?? false)
        XCTAssertTrue(log.text.contains("*** Failed w/ error: 500 when upload"))
        XCTAssertTrue(log.text.contains("Falling back to upload zipped dSYM..."))
    }

    func testConversionFailureFallsBackToDsymUpload() throws {
        let runner = FakeCommandRunner { _, _ in CommandResult(exitStatus: 1, output: "", errorOutput: "symbols: bad file") }
        let uploader = FakeUploader()
        let log = LogCapture()
        makePipeline(runner: runner, uploader: uploader, log: log).process(dwarfPath: dwarfPath)

        XCTAssertEqual(uploader.uploads.map(\.kind), [.dsym])
        XCTAssertTrue(log.text.contains("Error in conversion: `symbols -uuid"))
        XCTAssertTrue(log.text.contains("symbols: bad file"))
    }

    func testBinaryWithNoUUIDsFallsBackToDsymUpload() throws {
        // The original tool zipped and uploaded an empty map archive in this case.
        let uploader = FakeUploader()
        makePipeline(runner: FakeCommandRunner(), uploader: uploader).process(dwarfPath: dwarfPath)
        XCTAssertEqual(uploader.uploads.map(\.kind), [.dsym])
    }

    func testOversizedMapSendsTelemetryWithoutDsymFallback() throws {
        let uploader = FakeUploader()
        uploader.telemetryStatus = 500
        makePipeline(runner: try .symbolsFixtures(), uploader: uploader, threshold: 10).process(dwarfPath: dwarfPath)

        XCTAssertEqual(uploader.telemetrySizes.count, 1)
        XCTAssertTrue(uploader.uploads.isEmpty)
    }

    func testScratchDirectoriesAreRemoved() throws {
        let caches = try XCTUnwrap(FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first)
        let before = Set(try FileManager.default.contentsOfDirectory(atPath: caches.path))
        let uploader = FakeUploader()
        uploader.mapStatus = 500
        makePipeline(runner: try .symbolsFixtures(), uploader: uploader).process(dwarfPath: dwarfPath)
        let after = Set(try FileManager.default.contentsOfDirectory(atPath: caches.path))
        XCTAssertEqual(after.subtracting(before), [])
    }

    func testUnreachableServerSkipsDsymFallback() throws {
        let uploader = FakeUploader()
        uploader.mapStatus = 0
        uploader.mapCurlExitStatus = 7 // couldn't connect
        let log = LogCapture()
        let outcome = makePipeline(runner: try .symbolsFixtures(), uploader: uploader, log: log).process(dwarfPath: dwarfPath)

        XCTAssertEqual(outcome, .rejected)
        XCTAssertEqual(uploader.uploads.map(\.kind), [.map])
        XCTAssertTrue(log.text.contains("Could not reach the New Relic symbol upload server"))
    }

    func testTransferFailureStillFallsBackToDsym() throws {
        // curl also reports 000 when a connection is reset mid-upload; that isn't "unreachable".
        let uploader = FakeUploader()
        uploader.mapStatus = 0
        uploader.mapCurlExitStatus = 56
        let outcome = makePipeline(runner: try .symbolsFixtures(), uploader: uploader).process(dwarfPath: dwarfPath)

        XCTAssertEqual(outcome, .dsymUploaded)
        XCTAssertEqual(uploader.uploads.map(\.kind), [.map, .dsym])
    }

    func testEmptyArchitectureIsSkippedWhenOthersHaveSymbols() throws {
        let fixtures = try FakeCommandRunner.symbolsFixtures()
        let runner = FakeCommandRunner { command, arguments in
            if arguments.first == "-arch", arguments[1] == "x86_64" {
                return CommandResult(exitStatus: 0, output: "        0x0 (0x100000000) __PAGEZERO SEGMENT\n", errorOutput: "")
            }
            return try fixtures.handler(command, arguments)
        }
        let uploader = FakeUploader()
        let log = LogCapture()
        let outcome = makePipeline(runner: runner, uploader: uploader, log: log).process(dwarfPath: dwarfPath)

        XCTAssertEqual(outcome, .mapUploaded)
        XCTAssertEqual(uploader.uploads.first?.zipEntries.filter { $0.hasSuffix(".map") }.count, 1)
        XCTAssertTrue(log.text.contains("produced no symbols for \(dwarfPath!); skipping that architecture."))
    }

    func testTelemetryErrorNeverFallsBackToDsym() throws {
        let uploader = FakeUploader()
        uploader.telemetryThrows = true
        let log = LogCapture()
        let outcome = makePipeline(runner: try .symbolsFixtures(), uploader: uploader, threshold: 10, log: log).process(dwarfPath: dwarfPath)

        XCTAssertEqual(outcome, .oversizedMapReported)
        XCTAssertTrue(uploader.uploads.isEmpty)
        XCTAssertTrue(log.text.contains("*** Failed sending telemetry"))
    }

    func testSymbolsWarningExitStatusIsToleratedWhenOutputIsUsable() throws {
        let fixtures = try FakeCommandRunner.symbolsFixtures()
        let runner = FakeCommandRunner { command, arguments in
            let result = try fixtures.handler(command, arguments)
            return CommandResult(exitStatus: 1, output: result.output, errorOutput: "warning: something minor")
        }
        let uploader = FakeUploader()
        let log = LogCapture()
        let outcome = makePipeline(runner: runner, uploader: uploader, log: log).process(dwarfPath: dwarfPath)

        XCTAssertEqual(outcome, .mapUploaded)
        XCTAssertTrue(log.text.contains("exited with status 1; using its output. warning: something minor"))
    }

    func testMapWithoutSymbolsFallsBackToDsym() throws {
        let uuids = try Fixture.text("TestApp-uuid")
        let runner = FakeCommandRunner { _, arguments in
            CommandResult(exitStatus: 0, output: arguments.first == "-uuid" ? uuids : "        0x0 (0x100000000) __PAGEZERO SEGMENT\n", errorOutput: "")
        }
        let uploader = FakeUploader()
        let outcome = makePipeline(runner: runner, uploader: uploader).process(dwarfPath: dwarfPath)

        XCTAssertEqual(outcome, .dsymUploaded)
        XCTAssertEqual(uploader.uploads.map(\.kind), [.dsym])
    }
}

final class RunSymbolToolTests: XCTestCase {

    private func run(_ arguments: [String], _ environment: [String: String], runner: FakeCommandRunner = FakeCommandRunner()) -> (Int32, String) {
        let log = LogCapture()
        let status = RunSymbolTool(arguments: arguments, environment: environment, runner: runner, write: log.write).run()
        return (status, log.text)
    }

    func testBitcodeAndSimulatorBuildsExitCleanly() {
        XCTAssertEqual(run(["tool", "AAtoken"], ["ENABLE_BITCODE": "YES"]).0, 0)
        XCTAssertEqual(run(["tool", "AAtoken"], ["EFFECTIVE_PLATFORM_NAME": "-iphonesimulator"]).0, 0)
    }

    func testUsageErrors() {
        let (status, log) = run(["tool"], [:])
        XCTAssertEqual(status, 1)
        XCTAssertTrue(log.contains("Invalid Usage"))
        XCTAssertEqual(run(["tool", "AAtoken", "-appVersion"], [:]).0, 1)
    }

    func testMissingOrEmptyDsymFolderFails() throws {
        XCTAssertEqual(run(["tool", "AAtoken"], [:]).0, 1)
        let empty = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: empty, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: empty) }
        let (status, log) = run(["tool", "AAtoken"], ["DWARF_DSYM_FOLDER_PATH": empty.path])
        XCTAssertEqual(status, 1)
        XCTAssertTrue(log.contains("No dSYMs found"))
    }

    func testDebugLogRedactsToken() {
        let (_, log) = run(["tool", "eu01xx0123456789", "--debug"], [:])
        XCTAssertFalse(log.contains("eu01xx0123456789"))
        XCTAssertTrue(log.contains("apiKey = eu01xx**********"))
        XCTAssertTrue(log.contains("**** Using Region Aware URL: https://mobile-symbol-upload.eu01.nr-data.net"))
    }

    func testUploadsEveryDwarfBinaryInParallel() throws {
        let folder = try makeDsymFolder(["App", "Widget", "Intents"])
        defer { try? FileManager.default.removeItem(at: folder) }
        try FileManager.default.createDirectory(at: folder.appendingPathComponent("NotADsym"), withIntermediateDirectories: true)

        let runner = try FakeCommandRunner.symbolsFixtures()
        let (status, log) = run(["tool", "AAtoken"], ["DWARF_DSYM_FOLDER_PATH": folder.path], runner: runner)

        XCTAssertEqual(status, 0)
        let uuidCalls = runner.invocations.filter { $0.command == "symbols" && $0.arguments.first == "-uuid" }
        XCTAssertEqual(Set(uuidCalls.map { URL(fileURLWithPath: $0.arguments[1]).lastPathComponent }), ["App", "Widget", "Intents"])
        let curlTargets = runner.invocations.filter { $0.command == "curl" }.compactMap(\.arguments.last)
        XCTAssertEqual(curlTargets, Array(repeating: Configuration.defaultUploadURL + "/map", count: 3))
        XCTAssertTrue(log.hasSuffix("New Relic: Finished processing 3 dSYM binaries: 3 map uploads, 0 dSYM uploads, 0 oversized maps reported, 0 failed."))
    }

    func testConcurrentLogsAreWrittenAsOneBlockPerBinary() throws {
        let names = (1...8).map { "Framework\($0)" }
        let folder = try makeDsymFolder(names)
        defer { try? FileManager.default.removeItem(at: folder) }

        let (_, log) = run(["tool", "AAtoken", "--debug"], ["DWARF_DSYM_FOLDER_PATH": folder.path], runner: try .symbolsFixtures())

        // Every line that names a binary's path must sit in one contiguous run of lines for that binary.
        let lines = log.components(separatedBy: "\n")
        for name in names {
            // The opening "Processing" line is written immediately, outside the block.
            let indices = lines.indices.filter {
                lines[$0].contains("/\(name).dSYM/") && !lines[$0].hasPrefix("dSYMs located at") && !lines[$0].hasPrefix("New Relic: Processing ")
            }
            XCTAssertFalse(indices.isEmpty, name)
            let block = lines[indices.first!...indices.last!]
            let foreign = block.filter { line in names.contains { $0 != name && line.contains("/\($0).dSYM/") } }
            XCTAssertTrue(foreign.isEmpty, "\(name)'s log block is interleaved with: \(foreign)")
        }
    }

    func testSerialProcessingWhenConcurrencyIsOne() throws {
        let folder = try makeDsymFolder(["B", "A", "C"])
        defer { try? FileManager.default.removeItem(at: folder) }
        let runner = try FakeCommandRunner.symbolsFixtures()
        _ = run(["tool", "AAtoken"], ["DWARF_DSYM_FOLDER_PATH": folder.path, "NEWRELIC_SYMBOL_UPLOAD_CONCURRENCY": "1"], runner: runner)

        let uuidCalls = runner.invocations.filter { $0.command == "symbols" && $0.arguments.first == "-uuid" }
        XCTAssertEqual(uuidCalls.map { URL(fileURLWithPath: $0.arguments[1]).lastPathComponent }, ["A", "B", "C"])
    }

    func testUnreadableBundleIsSkippedNotFatal() throws {
        let folder = try makeDsymFolder(["App"])
        defer { try? FileManager.default.removeItem(at: folder) }
        try FileManager.default.createDirectory(at: folder.appendingPathComponent("Broken.dSYM"), withIntermediateDirectories: true)

        let (status, log) = run(["tool", "AAtoken"], ["DWARF_DSYM_FOLDER_PATH": folder.path], runner: try .symbolsFixtures())

        XCTAssertEqual(status, 0)
        XCTAssertTrue(log.contains("Warning: Skipping \(folder.path)/Broken.dSYM"))
        XCTAssertTrue(log.contains("1 map uploads"))
    }

    func testRejectedTokenSkipsDsymFallbackAndExplains() throws {
        let folder = try makeDsymFolder(["App"])
        defer { try? FileManager.default.removeItem(at: folder) }
        let runner = try FakeCommandRunner.symbolsFixtures(curlStatus: "401")

        let (_, log) = run(["tool", "AAtoken"], ["DWARF_DSYM_FOLDER_PATH": folder.path], runner: runner)

        XCTAssertEqual(runner.invocations.filter { $0.command == "curl" }.compactMap(\.arguments.last), [Configuration.defaultUploadURL + "/map"])
        XCTAssertTrue(log.contains(SymbolUploadPipeline.authenticationHint))
        XCTAssertFalse(log.contains("Falling back"))
        XCTAssertTrue(log.contains("1 failed."))
    }

    func testRejectionSkipsRemainingBinaries() throws {
        let folder = try makeDsymFolder(["A", "B", "C"])
        defer { try? FileManager.default.removeItem(at: folder) }
        let runner = try FakeCommandRunner.symbolsFixtures(curlStatus: "403")

        let (_, log) = run(["tool", "AAtoken"], ["DWARF_DSYM_FOLDER_PATH": folder.path, "NEWRELIC_SYMBOL_UPLOAD_CONCURRENCY": "1"], runner: runner)

        XCTAssertEqual(runner.invocations.filter { $0.command == "curl" }.count, 1)
        XCTAssertEqual(runner.invocations.filter { $0.arguments.first == "-uuid" }.count, 1)
        XCTAssertTrue(log.contains("Skipping \(folder.path)/B.dSYM/Contents/Resources/DWARF/B: an earlier upload was rejected."))
        XCTAssertTrue(log.hasSuffix("1 failed, 2 skipped."))
    }

    func testLargeBinariesAreProcessedFirstAndAlone() throws {
        let folder = try makeDsymFolder(["A", "B", "Huge", "C"])
        defer { try? FileManager.default.removeItem(at: folder) }
        // A sparse 200 MB file: over the 100 MB threshold without using the disk space.
        let huge = try FileHandle(forWritingTo: folder.appendingPathComponent("Huge.dSYM/Contents/Resources/DWARF/Huge"))
        try huge.truncate(atOffset: 200 * 1024 * 1024)
        try huge.close()

        let runner = try FakeCommandRunner.symbolsFixtures()
        let (_, log) = run(["tool", "AAtoken"], ["DWARF_DSYM_FOLDER_PATH": folder.path], runner: runner)

        let uuidCalls = runner.invocations.filter { $0.arguments.first == "-uuid" }.map { URL(fileURLWithPath: $0.arguments[1]).lastPathComponent }
        XCTAssertEqual(uuidCalls.first, "Huge")
        // Huge finished (its upload logged) before any other binary started.
        let lines = log.components(separatedBy: "\n")
        let hugeDone = try XCTUnwrap(lines.firstIndex { $0.hasPrefix("Successfully uploaded map") })
        let firstOtherStart = try XCTUnwrap(lines.firstIndex { $0.hasPrefix("New Relic: Processing ") && !$0.contains("/Huge.dSYM/") })
        XCTAssertLessThan(hugeDone, firstOtherStart)
        XCTAssertTrue(log.contains("4 map uploads"))
    }

    func testShortTokenDoesNotCorruptLogText() throws {
        // Regression: substring-based redaction turned "Exiting" into "E*iting" for the token "x".
        let (_, log) = run(["tool", "x", "--debug"], [:])
        XCTAssertTrue(log.contains("No directory to work on. ($DWARF_DSYM_FOLDER_PATH) Exiting."))
        XCTAssertTrue(log.contains("apiKey = *"))
    }
}
