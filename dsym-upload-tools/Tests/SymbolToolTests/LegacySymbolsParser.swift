//
//  LegacySymbolsParser.swift
//  2026 New Relic
//
// The parsing code from the original single-file run-symbol-tool.swift (7.7.8), kept as a reference
// implementation for differential tests. Only the logging and file writing were removed; the parsing
// logic is unchanged, including its known traps (see SymbolsOutputParserTests).

import Foundation

enum LegacySymbolsParser {
    struct Failed: Error {}

    /// Returns the map file contents that processSymbolsOutput used to write to disk.
    static func render(_ symbolsOutput: String, _ key: String, _ value: String) throws -> String {
        let vmAddressOffset = 8
        let dwarfAddressOffset = 12
        let functionOffset = 16
        let sourceLineOffset = 20

        var vmAddresses = [String]()
        var symbols = [String: String]()

        let lines = symbolsOutput.split(whereSeparator: \.isNewline)
        var currentFunction = ""
        for line in lines where !line.isEmpty {
            let whitespaceEndIndex = line.firstIndex(where: { !CharacterSet(charactersIn: String($0)).isSubset(of: .whitespaces) })
            let whitespaceCount: Int
            if let whitespaceEndIndex = whitespaceEndIndex {
                whitespaceCount = line.distance(from: line.startIndex, to: whitespaceEndIndex)
            }
            else {
                whitespaceCount = 0
            }
            let strippedLine = line.trimmingCharacters(in: .whitespaces)
            switch whitespaceCount {
            case vmAddressOffset:
                let vmAddress = try parseVmAddress(strippedLine)
                vmAddresses.append(vmAddress)
            case dwarfAddressOffset:
                if let dwarfSymbol = try parseDwarf(strippedLine) {
                    symbols[dwarfSymbol.0] = dwarfSymbol.1
                }
            case functionOffset:
                let funcSymbol = try parseFunction(strippedLine)
                currentFunction = funcSymbol.1
                symbols[funcSymbol.0] = funcSymbol.1
            case sourceLineOffset:
                let sourceLineSymbol = try parseSourceLine(strippedLine, currentFunction)
                symbols[sourceLineSymbol.0] = sourceLineSymbol.1
            default:
                break
            }
        }

        var mapFileContents = ""
        mapFileContents.append("# uuid \(key.uppercased())\n")
        mapFileContents.append("# architecture \(value)\n")
        for vmAddress in vmAddresses.sorted() {
            let vmAddrLine = "# vmaddr \(vmAddress)\n"
            mapFileContents.append(vmAddrLine)
        }
        for key in symbols.keys.sorted() {
            if let symbolValue = symbols[key] {
                let symbolLine = "\(key) \(symbolValue)\n"
                mapFileContents.append(symbolLine)
            }
        }
        return mapFileContents
    }

    static func parseVmAddress(_ line: String) throws -> String {
        guard let vmAddress = line.components(separatedBy: " ").first?.uppercased() else {
            throw Failed()
        }
        return padHex(vmAddress)
    }

    static func parseDwarf(_ line: String) throws -> (String, String)? {
        guard let closeParen = line.firstIndex(of: ")") else {
            throw Failed()
        }
        let closeParenIndex = line.index(closeParen, offsetBy: 2)
        guard let openParen = line.firstIndex(of: "(") else {
            throw Failed()
        }
        let openParenIndex = line.index(openParen, offsetBy: 0)
        let symbolString = line[closeParenIndex...].trimmingCharacters(in: .whitespaces)

        guard symbolString.range(of: "__DWARF") != nil else {
            return nil
        }
        let returnKey = padHex(String(line[...openParenIndex]))
        guard let returnValue = symbolString.components(separatedBy: " ").last else {
            throw Failed()
        }
        return (returnKey, returnValue)
    }

    static func parseFunction(_ line: String) throws -> (String, String) {
        guard let closeParen = line.firstIndex( of: ")"),
              let openParen = line.firstIndex( of: "(") else {
            throw Failed()
        }
        let closeParenIndex = line.index(closeParen, offsetBy: 1)
        let openParenIndex = line.index(openParen, offsetBy: 0)
        var currentFunction = ""
        if let bracket = line.range(of: " [") {
            let bracketIndex = line.index(bracket.lowerBound, offsetBy: 0)
            currentFunction = String(line[closeParenIndex...bracketIndex])
        }
        else {
            currentFunction = String(line[closeParenIndex...]).trimmingCharacters(in: .whitespaces) + " "
        }

        return (padHex(String(line[...openParenIndex])), currentFunction)
    }

    static func parseSourceLine(_ line: String, _ currentFunction: String) throws -> (String, String) {
        let lineSplit = line.components(separatedBy: " ").filter { !$0.isEmpty }
        guard lineSplit.count > 3 else {
            throw Failed()
        }
        let sourceString = "\(currentFunction.trimmingCharacters(in: .whitespaces)) (\(lineSplit[3]))"

        return (padHex(lineSplit[0]), sourceString)
    }

    static func padHex(_ hexString: String) -> String {
        let subHexString = String(hexString.dropFirst(2))
        let filledSubHexString = subHexString.padding(toLength: 16, withPad: "0", startingAt: 0)
        return "0x\(filledSubHexString)"
    }
}
