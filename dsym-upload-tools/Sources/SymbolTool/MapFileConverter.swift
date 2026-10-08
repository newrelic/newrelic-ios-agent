//
//  MapFileConverter.swift
//  2026 New Relic
//

import Foundation

/// Converts a DWARF binary into one `SymbolMap` per architecture using Apple's `symbols` tool.
struct MapFileConverter {
    let runner: CommandRunning
    let logger: Logger

    func convert(dwarfPath: String) throws -> [SymbolMap] {
        let uuidOutput = try symbols(["-uuid", dwarfPath])
        logger.debug("result from symbols --uuid: \(uuidOutput)")

        let slices = try SymbolsOutputParser.parseSlices(uuidOutput)
        guard !slices.isEmpty else {
            throw SymbolToolError.conversionFailed("`symbols -uuid` found no UUIDs in \(dwarfPath)")
        }
        logger.debug("Parsed uuids: \(slices.map { "\($0.uuid): \($0.architecture)" })")

        var maps = [SymbolMap]()
        for slice in slices {
            let output = try symbols(["-arch", slice.architecture, dwarfPath])
            logger.debug("Processing symbols output...")
            let map = try SymbolsOutputParser.parseSymbolMap(output, slice: slice)
            logger.debug("Successfully processed symbols output. COUNT: \(map.vmAddresses.count) VM, \(map.symbols.count) SYM")
            if map.symbols.isEmpty {
                logger.info("Warning: `symbols -arch \(slice.architecture)` produced no symbols for \(dwarfPath); skipping that architecture.")
            } else {
                maps.append(map)
            }
        }
        // Maps with no symbols can't symbolicate anything; the dSYM fallback is the better upload.
        guard !maps.isEmpty else {
            throw SymbolToolError.conversionFailed("`symbols` produced no symbols for any architecture of \(dwarfPath)")
        }
        return maps
    }

    private func symbols(_ arguments: [String]) throws -> String {
        let commandLine = "symbols \(arguments.joined(separator: " "))"
        logger.debug("Executing $ \(commandLine)")
        let result: CommandResult
        do {
            result = try runner.run("symbols", arguments)
        } catch {
            throw SymbolToolError.conversionFailed("could not launch `symbols`: \(error)")
        }
        if !result.succeeded {
            // `symbols` can exit non-zero over warnings while still printing a usable tree, so only
            // give up when there is no output to parse. Parsing then decides whether it is usable.
            guard !result.output.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                throw SymbolToolError.conversionFailed("`\(commandLine)` exited with status \(result.exitStatus): \(result.errorOutput)")
            }
            logger.info("Warning: `\(commandLine)` exited with status \(result.exitStatus); using its output. \(result.errorOutput)")
        }
        return result.output
    }
}
