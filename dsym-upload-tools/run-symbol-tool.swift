//
//  run-symbol-tool.swift
//  2026 New Relic
//
// Compatibility entry point. The tool now lives in Sources/SymbolTool and is built by the
// run-symbol-tool wrapper. Build phases that still run
//
//   /usr/bin/xcrun --sdk macosx swift run-symbol-tool.swift <APP_TOKEN> [--debug] [-appVersion <version>]
//
// keep working: this forwards to the wrapper in the foreground. New setups should call the
// run-symbol-tool wrapper directly (see README_RUN_SYMBOL_TOOL.MD).

import Foundation

let arguments = Array(CommandLine.arguments.dropFirst())
guard let appToken = arguments.first else {
    print("Invalid Usage: Ex: run-symbol-tool $APP_TOKEN [--debug] [-appVersion <version>]")
    exit(1)
}

let wrapper = URL(fileURLWithPath: #filePath).deletingLastPathComponent().appendingPathComponent("run-symbol-tool")
let process = Process()
process.executableURL = URL(fileURLWithPath: "/bin/sh")
process.arguments = [wrapper.path, appToken, "--foreground"] + arguments.dropFirst()
do {
    try process.run()
} catch {
    print("New Relic: could not launch \(wrapper.path): \(error)")
    exit(1)
}
process.waitUntilExit()
exit(process.terminationStatus)
