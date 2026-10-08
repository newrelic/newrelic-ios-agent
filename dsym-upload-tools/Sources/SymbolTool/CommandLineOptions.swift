//
//  CommandLineOptions.swift
//  2026 New Relic
//

import Foundation

/// `run-symbol-tool <APP_TOKEN> [--debug] [-appVersion <version>]`
struct CommandLineOptions: Equatable {
    static let usage = "Invalid Usage: Ex: run-symbol-tool $APP_TOKEN [--debug] [-appVersion <version>]"

    enum ParseError: Error, Equatable {
        case missingAppToken
        case missingValue(flag: String)

        var message: String {
            switch self {
            case .missingAppToken:
                return CommandLineOptions.usage
            case .missingValue(let flag):
                return "New Relic: Invalid Usage: \(flag) requires a value, e.g. -appVersion 7.8.2. Exiting."
            }
        }
    }

    var appToken: String
    var isDebug = false
    var appVersionOverride: String?
    var unrecognizedArguments: [String] = []

    /// Parses `CommandLine.arguments` (element 0 is the executable). Optional flags may appear in any order.
    static func parse(_ arguments: [String]) throws -> CommandLineOptions {
        guard arguments.count > 1 else { throw ParseError.missingAppToken }
        var options = CommandLineOptions(appToken: arguments[1])

        var remaining = arguments.dropFirst(2).makeIterator()
        while let argument = remaining.next() {
            switch argument {
            case "--debug":
                options.isDebug = true
            case "-appVersion", "--appVersion", "--app-version":
                // NR-417639: agvtool / multi-target apps often leave MARKETING_VERSION unset or empty.
                guard let value = remaining.next() else { throw ParseError.missingValue(flag: argument) }
                options.appVersionOverride = value.trimmingCharacters(in: .whitespacesAndNewlines)
            default:
                options.unrecognizedArguments.append(argument)
            }
        }
        return options
    }
}
