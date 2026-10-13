//
//  SymbolsOutputParser.swift
//  2026 New Relic
//

import Foundation

/// Parses the text output of Apple's `symbols` tool.
///
/// `symbols -arch <arch> <path>` prints a tree whose depth is encoded by leading spaces:
///
///     8  spaces  segment          -> VM address
///     12 spaces  section          -> DWARF section symbol (only `__DWARF` sections are kept)
///     16 spaces  function         -> function symbol
///     20 spaces  source line      -> "<function> (<file>:<line>)" for the enclosing function
///
/// Large apps produce hundreds of megabytes of output, so the hot paths scan UTF-8 bytes rather than
/// Characters. Every delimiter involved (`(`, `)`, ` `, ` [`) is ASCII, so this gives the same results;
/// whitespace handling falls back to Foundation when a line has non-ASCII bytes at its edges.
enum SymbolsOutputParser {
    private static let vmAddressDepth = 8
    private static let dwarfDepth = 12
    private static let functionDepth = 16
    private static let sourceLineDepth = 20

    /// Parses `symbols -uuid <path>` lines of the form `<UUID> <arch> <path> [...]`.
    static func parseSlices(_ output: String) throws -> [DwarfSlice] {
        var slices = [DwarfSlice]()
        for line in output.split(whereSeparator: \.isNewline) {
            let parts = line.split(whereSeparator: { $0 == " " || $0 == "\t" })
            if parts.isEmpty { continue }
            guard parts.count > 1 else {
                throw SymbolToolError.conversionFailed("failed to parse `symbols -uuid` line: \(line)")
            }
            let uuid = parts[0].lowercased().replacingOccurrences(of: "-", with: "")
            let slice = DwarfSlice(uuid: uuid, architecture: String(parts[1]))
            // A UUID appears once per slice; keep the latest if `symbols` ever repeats one.
            if let existing = slices.firstIndex(where: { $0.uuid == uuid }) {
                slices[existing] = slice
            } else {
                slices.append(slice)
            }
        }
        return slices
    }

    /// Parses `symbols -arch <arch> <path>` into a map file for `slice`.
    static func parseSymbolMap(_ output: String, slice: DwarfSlice) throws -> SymbolMap {
        var map = SymbolMap(slice: slice)
        // Source lines are attributed to the most recent function line above them.
        var currentFunction = ""

        for line in lines(of: output) {
            let strippedLine = trimmingWhitespace(line)
            if strippedLine.isEmpty { continue }
            switch leadingWhitespaceCount(line) {
            case vmAddressDepth:
                map.vmAddresses.append(parseVmAddress(strippedLine))
            case dwarfDepth:
                if let (address, name) = try parseDwarf(strippedLine) {
                    map.symbols[address] = name
                }
            case functionDepth:
                let (address, name) = try parseFunction(strippedLine)
                currentFunction = String(trimmingWhitespace(Substring(name)))
                map.symbols[address] = name
            case sourceLineDepth:
                let (address, name) = try parseSourceLine(strippedLine, functionName: currentFunction)
                map.symbols[address] = name
            default:
                break
            }
        }
        return map
    }

    // MARK: - Line parsers

    static func parseVmAddress(_ line: Substring) -> String {
        let end = line.utf8.firstIndex(of: ascii(" ")) ?? line.endIndex
        return padHex(line[..<end].uppercased())
    }

    /// `0x… (  0x2f2) __DWARF __debug_line` -> (`0x…`, `__debug_line`); nil for non-DWARF sections.
    static func parseDwarf(_ line: Substring) throws -> (String, String)? {
        guard let closeParen = line.firstIndex(of: ")"), let openParen = line.firstIndex(of: "(") else {
            throw SymbolToolError.conversionFailed("found invalid DWARF symbol: \(line)")
        }
        // Skip ") " — clamped so a line that ends at ")" yields no symbol instead of trapping.
        let symbolStart = line.index(closeParen, offsetBy: 2, limitedBy: line.endIndex) ?? line.endIndex
        let symbolString = line[symbolStart...].trimmingCharacters(in: .whitespaces)

        guard symbolString.contains("__DWARF") else { return nil }
        guard let name = symbolString.components(separatedBy: " ").last else {
            throw SymbolToolError.conversionFailed("found invalid DWARF symbol: \(line)")
        }
        return (padHex(line[...openParen]), name)
    }

    /// `0x… (   0x174) main [FUNC, EXT, …]` -> (`0x…`, ` main `).
    ///
    /// The name keeps its surrounding spaces; that is the established map format.
    static func parseFunction(_ line: Substring) throws -> (String, String) {
        let bytes = line.utf8
        guard let closeParen = bytes.firstIndex(of: ascii(")")), let openParen = bytes.firstIndex(of: ascii("(")) else {
            throw SymbolToolError.conversionFailed("found invalid FUNCTION symbol: \(line)")
        }
        let nameStart = bytes.index(after: closeParen)
        let name: String
        // The first " [" after ")" starts the attribute list. Searching only after ")" avoids an
        // inverted range when " [" also appears before it.
        if let attributes = firstAttributeListIndex(in: line[nameStart...]) {
            name = String(line[nameStart..<bytes.index(after: attributes)])
        } else {
            name = trimmingWhitespace(line[nameStart...]) + " "
        }
        return (padHex(line[..<bytes.index(after: openParen)]), name)
    }

    /// `0x… (    0x20) app.swift:5` -> (`0x…`, `<functionName> (app.swift:5)`).
    static func parseSourceLine(_ line: Substring, functionName: String) throws -> (String, String) {
        // Fields are space-separated; only the first four are needed.
        let fields = line.utf8.split(separator: ascii(" "), maxSplits: 4, omittingEmptySubsequences: true)
        guard fields.count > 3 else {
            throw SymbolToolError.conversionFailed("found invalid SOURCE LINE symbol: \(line)")
        }
        return (padHex(Substring(fields[0])), "\(functionName) (\(Substring(fields[3])))")
    }

    /// Normalizes `0x…` to `0x` + exactly 16 digits (right-padded with zeros, or truncated).
    static func padHex<S: StringProtocol>(_ hexString: S) -> String {
        let bytes = hexString.utf8
        guard bytes.allSatisfy({ $0 < 0x80 }) else {
            return "0x" + String(hexString.dropFirst(2)).padding(toLength: 16, withPad: "0", startingAt: 0)
        }
        let digits = bytes.dropFirst(2)
        var result = "0x"
        result.reserveCapacity(18)
        result += String(decoding: digits.prefix(16), as: UTF8.self)
        if digits.count < 16 {
            result += String(repeating: "0", count: 16 - digits.count)
        }
        return result
    }

    // MARK: - Byte-level helpers

    private static func ascii(_ scalar: Unicode.Scalar) -> UInt8 {
        UInt8(ascii: scalar)
    }

    /// Splits on line breaks. `symbols` writes "\n"; "\r", vertical tab and form feed also count as breaks.
    private static func lines(of text: String) -> [Substring] {
        text.utf8
            .split(whereSeparator: { $0 == 0x0A || $0 == 0x0D || $0 == 0x0B || $0 == 0x0C })
            .map { Substring($0) }
    }

    private static func isASCIIWhitespace(_ byte: UInt8) -> Bool {
        byte == ascii(" ") || byte == ascii("\t")
    }

    /// The number of leading whitespace Characters (Unicode `.whitespaces`, like `trimmingCharacters`).
    private static func leadingWhitespaceCount(_ line: Substring) -> Int {
        var count = 0
        for byte in line.utf8 {
            if isASCIIWhitespace(byte) {
                count += 1
            } else if byte >= 0x80 {
                // Possibly non-ASCII whitespace (e.g. U+00A0): count Characters exactly.
                return line.prefix(while: { $0.unicodeScalars.allSatisfy(CharacterSet.whitespaces.contains) }).count
            } else {
                break
            }
        }
        return count
    }

    /// Equivalent to `trimmingCharacters(in: .whitespaces)`, without Foundation for ASCII edges.
    private static func trimmingWhitespace(_ line: Substring) -> Substring {
        let bytes = line.utf8
        guard let first = bytes.firstIndex(where: { !isASCIIWhitespace($0) }),
              let last = bytes.lastIndex(where: { !isASCIIWhitespace($0) }) else {
            return ""
        }
        if bytes[first] >= 0x80 || bytes[last] >= 0x80 {
            return Substring(line.trimmingCharacters(in: .whitespaces))
        }
        return line[first..<bytes.index(after: last)]
    }

    /// Index of the space in the first " [" of `text`.
    private static func firstAttributeListIndex(in text: Substring) -> String.Index? {
        let bytes = text.utf8
        var searchStart = bytes.startIndex
        while let space = bytes[searchStart...].firstIndex(of: ascii(" ")) {
            let next = bytes.index(after: space)
            if next < bytes.endIndex, bytes[next] == ascii("[") {
                return space
            }
            searchStart = next
        }
        return nil
    }
}
