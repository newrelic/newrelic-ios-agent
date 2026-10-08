//
//  main.swift
//  2026 New Relic
//
// Uploads a build's debug symbols to New Relic. Launched from an Xcode Run Script build phase by
// the `run-symbol-tool` wrapper, which compiles every file in this directory with `swiftc` and runs
// the result. See README_RUN_SYMBOL_TOOL.MD for setup.
//
// Flow: RunSymbolTool (environment + argument checks) -> DSYMLocator (find DWARF binaries)
//   -> SymbolUploadPipeline per binary: MapFileConverter + SymbolsOutputParser -> Archiver
//   -> SymbolUploader, falling back to a zipped dSYM upload if any map step fails.

import Foundation

// Line-buffer stdout so upload_dsym_results.log fills in as the tool runs (and survives the
// background process being killed), instead of only when it exits.
setvbuf(stdout, nil, _IOLBF, 0)

exit(RunSymbolTool(arguments: CommandLine.arguments, environment: ProcessInfo.processInfo.environment).run())
