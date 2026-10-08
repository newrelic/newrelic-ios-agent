//
//  RunSymbolTool.swift
//  2026 New Relic
//

import Foundation

/// Entry point: validates the build environment, then uploads symbols for every dSYM in the build.
struct RunSymbolTool {
    let arguments: [String]
    let environment: [String: String]
    var fileManager: FileManager = .default
    var runner: CommandRunning = ProcessCommandRunner()
    var write: (String) -> Void = { print($0) }

    /// Returns the process exit status.
    func run() -> Int32 {
        var logger = Logger(write: write)
        logger.info("New Relic: Starting dSYM upload script...")

        guard environment["ENABLE_BITCODE"] != "YES" else {
            logger.info("New Relic: Build is Bitcode enabled. No dSYM has been uploaded. Bitcode enabled apps require dSYM files to be downloaded from App Store Connect. For more information please review https://docs.newrelic.com/docs/mobile-monitoring/new-relic-mobile-ios/install-configure/retrieve-upload-dsyms  Exiting without failure.")
            return 0
        }

        let effectivePlatformName = environment["EFFECTIVE_PLATFORM_NAME"]
        guard effectivePlatformName != "-iphonesimulator" else {
            logger.info("New Relic: Skipping automatic upload of simulator build symbols")
            return 0
        }

        let options: CommandLineOptions
        do {
            options = try CommandLineOptions.parse(arguments)
        } catch let error as CommandLineOptions.ParseError {
            logger.info(error.message)
            return 1
        } catch {
            logger.info("\(error)")
            return 1
        }
        for argument in options.unrecognizedArguments {
            logger.info("New Relic: Ignoring unrecognized argument: \(argument)")
        }

        let configuration = Configuration(options: options, environment: environment)
        logger = Logger(debug: configuration.isDebug, write: write)
        logger.info(configuration.appVersion.logMessage)
        if configuration.usesRegionAwareURL {
            logger.info("**** Using Region Aware URL: \(configuration.uploadURL)")
        }

        let dsymFolder = environment["DWARF_DSYM_FOLDER_PATH"]
        logger.debug("========== dSYM directory = \(dsymFolder ?? "NOT FOUND")")
        logger.debug("========== Platform = \(effectivePlatformName ?? "NOT FOUND")")
        logger.debug("========== URL = \(configuration.uploadURL)")
        logger.debug("========== apiKey = \(Logger.mask(configuration.appToken))")

        guard let dsymFolder = dsymFolder else {
            logger.info("No directory to work on. ($DWARF_DSYM_FOLDER_PATH) Exiting.")
            return 1
        }

        let located: DSYMLocator.Result
        do {
            located = try DSYMLocator(fileManager: fileManager).locate(in: dsymFolder)
        } catch {
            logger.info("\(error)")
            logger.info("Error: We've encountered an error opening the dSYM directory. Exiting.")
            return 1
        }
        for bundle in located.unreadableBundles {
            logger.info("Warning: Skipping \(bundle): it has no readable Contents/Resources/DWARF folder.")
        }
        let dwarfPaths = located.dwarfBinaryPaths
        logger.debug("dSYMs located at: \(dwarfPaths)")
        guard !dwarfPaths.isEmpty else {
            logger.info("Error: No dSYMs found to process. Make sure your Xcode project target build setting 'Debug Information Format' is set to 'DWARF with dSYM File'.  Exiting.")
            return 1
        }

        let outcomes = process(dwarfPaths, configuration: configuration, logger: logger)
        logger.info(Self.summary(of: outcomes))
        return 0
    }

    /// Large binaries are processed first, one at a time; the rest run in parallel (bounded by
    /// `maxConcurrentUploads`). Once an upload is rejected (bad app token, unreachable server), the
    /// remaining binaries are skipped since they would fail the same way.
    private func process(_ dwarfPaths: [String], configuration: Configuration, logger: Logger) -> [UploadOutcome] {
        let output = SerializedOutput(write: write)
        let large = dwarfPaths.filter { fileSize(of: $0) > configuration.largeBinaryThreshold }
        let small = dwarfPaths.filter { !large.contains($0) }

        for dwarfPath in large {
            run(dwarfPath, buffered: false, configuration: configuration, output: output)
        }

        let concurrency = max(1, min(configuration.maxConcurrentUploads, small.count))
        if concurrency > 1 {
            logger.debug("Processing \(small.count) dSYM binaries, up to \(concurrency) at a time.")
        }
        let queue = OperationQueue()
        queue.maxConcurrentOperationCount = concurrency
        for dwarfPath in small {
            queue.addOperation {
                run(dwarfPath, buffered: concurrency > 1, configuration: configuration, output: output)
            }
        }
        queue.waitUntilAllOperationsAreFinished()
        return output.outcomes
    }

    /// Processes one binary. When `buffered`, its log lines are collected and written as one block so
    /// concurrent output doesn't interleave; the opening line is written immediately either way, so the
    /// log shows which binaries were in flight if the process is killed.
    private func run(_ dwarfPath: String, buffered: Bool, configuration: Configuration, output: SerializedOutput) {
        guard !output.isRejected else {
            output.finish(lines: ["Skipping \(dwarfPath): an earlier upload was rejected."], outcome: .skipped)
            return
        }
        output.write("New Relic: Processing \(dwarfPath)")
        let buffer = buffered ? LineBuffer() : nil
        let taskLogger = Logger(debug: configuration.isDebug, write: buffer.map { buffer in { buffer.lines.append($0) } } ?? write)
        let outcome = makePipeline(configuration: configuration, logger: taskLogger).process(dwarfPath: dwarfPath)
        output.finish(lines: buffer?.lines ?? [], outcome: outcome)
    }

    private func fileSize(of path: String) -> UInt64 {
        ((try? fileManager.attributesOfItem(atPath: path))?[.size] as? UInt64) ?? 0
    }

    private func makePipeline(configuration: Configuration, logger: Logger) -> SymbolUploadPipeline {
        SymbolUploadPipeline(
            converter: MapFileConverter(runner: runner, logger: logger),
            uploader: CurlSymbolUploader(configuration: configuration, runner: runner, logger: logger),
            logger: logger,
            archiver: Archiver(fileManager: fileManager),
            mapSizeThreshold: configuration.mapSizeThreshold,
            uploadDsymsOnly: configuration.uploadDsymsOnly)
    }

    static func summary(of outcomes: [UploadOutcome]) -> String {
        func count(_ matching: UploadOutcome...) -> Int { outcomes.filter(matching.contains).count }
        var summary = "New Relic: Finished processing \(outcomes.count) dSYM binaries: \(count(.mapUploaded)) map uploads, \(count(.dsymUploaded)) dSYM uploads, \(count(.oversizedMapReported)) oversized maps reported, \(count(.failed, .rejected)) failed"
        let skipped = count(.skipped)
        if skipped > 0 {
            summary += ", \(skipped) skipped"
        }
        return summary + "."
    }
}

/// Log lines collected by one task; only touched by the thread running that task.
private final class LineBuffer {
    var lines: [String] = []
}

/// Serializes log output across tasks and records their outcomes.
private final class SerializedOutput {
    private let lock = NSLock()
    private let writeLine: (String) -> Void
    private var recordedOutcomes: [UploadOutcome] = []

    init(write: @escaping (String) -> Void) {
        writeLine = write
    }

    var outcomes: [UploadOutcome] {
        lock.lock(); defer { lock.unlock() }
        return recordedOutcomes
    }

    var isRejected: Bool {
        lock.lock(); defer { lock.unlock() }
        return recordedOutcomes.contains(.rejected)
    }

    func write(_ line: String) {
        lock.lock(); defer { lock.unlock() }
        writeLine(line)
    }

    /// Writes a finished task's buffered log block atomically and records its outcome.
    func finish(lines: [String], outcome: UploadOutcome) {
        lock.lock(); defer { lock.unlock() }
        lines.forEach(writeLine)
        recordedOutcomes.append(outcome)
    }
}
