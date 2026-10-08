//
//  SymbolsParserDifferentialTests.swift
//  2026 New Relic
//

import XCTest
@testable import SymbolTool

/// Compares the byte-level parser with the original Character-based implementation on generated
/// `symbols` output, concentrating on the Unicode cases where byte and Character semantics could differ.
final class SymbolsParserDifferentialTests: XCTestCase {

    func testFixturesMatchLegacyParser() throws {
        for (name, uuid, arch) in [("TestApp-arm64", "bdbb53df45803bb69123234b492d9f65", "arm64"),
                                   ("TestApp-x86_64", "a6a0824813a13bceaed80b6f92dfab3b", "x86_64"),
                                   ("libSq-arm64", "libuuid", "arm64")] {
            let output = try Fixture.text(name)
            XCTAssertEqual(try render(output, uuid, arch), try LegacySymbolsParser.render(output, uuid, arch), name)
        }
    }

    func testGeneratedOutputMatchesLegacyParser() throws {
        var generator = SymbolsOutputGenerator(seed: 0x5EED)
        for document in 0..<300 {
            let output = generator.document(lineCount: 120)
            let expected = try LegacySymbolsParser.render(output, "uuid", "arm64")
            let actual = try render(output, "uuid", "arm64")
            if actual != expected {
                XCTFail("document \(document) differs from the legacy parser:\n\(firstDifference(actual, expected))\n--- input ---\n\(output)")
                return
            }
        }
    }

    private func render(_ output: String, _ uuid: String, _ arch: String) throws -> String {
        try SymbolsOutputParser.parseSymbolMap(output, slice: DwarfSlice(uuid: uuid, architecture: arch)).render()
    }

    private func firstDifference(_ actual: String, _ expected: String) -> String {
        let a = actual.components(separatedBy: "\n"), e = expected.components(separatedBy: "\n")
        for i in 0..<max(a.count, e.count) where (i < a.count ? a[i] : nil) != (i < e.count ? e[i] : nil) {
            return "line \(i)\n  new:    \(i < a.count ? a[i].debugDescription : "<none>")\n  legacy: \(i < e.count ? e[i].debugDescription : "<none>")"
        }
        return "(identical lines)"
    }
}

/// Produces well-formed `symbols -arch` style output (inputs the legacy parser does not trap on).
struct SymbolsOutputGenerator {
    private var state: UInt64

    init(seed: UInt64) { state = seed }

    /// SplitMix64, so failures are reproducible.
    private mutating func next() -> UInt64 {
        state &+= 0x9E37_79B9_7F4A_7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        return z ^ (z >> 31)
    }

    private mutating func int(_ upperBound: Int) -> Int { Int(next() % UInt64(upperBound)) }
    private mutating func pick<T>(_ items: [T]) -> T { items[int(items.count)] }
    private mutating func chance(_ percent: Int) -> Bool { int(100) < percent }

    private static let names = [
        "main", "Greeter.greet(times:)", "closure #1 in Greeter.greet(times:)",
        "lazy protocol witness table accessor for type [String] and conformance [A]",
        "café", "cafe\u{301}", "\u{301}leading combining mark", "naïve\u{00A0}name", "trailing nbsp\u{00A0}",
        "\u{00A0}leading nbsp", "em\u{2003}space", "日本語の関数", "🙂 emoji()", "👩‍👩‍👧 family", "operator()",
        "-[NSObject(Category) method:]", "+[Class classMethod]", "__block_descriptor_32_e5_v8\u{01}?0l",
        "tab\tinside", "ends with space ", "x ́y", "(paren) [bracket] name",
    ]
    private static let files = [
        "app.swift:5", "/<compiler-generated>:0", "Café.swift:12", "Cafe\u{301}.swift:3", "日本語.swift:9",
        "path with spaces.swift:7", "🙂.swift:1", "a\u{00A0}b.swift:2", "x.m:0",
    ]
    private static let attributes = ["[FUNC, EXT, NameNList, NList]", "[FUNC, PEXT, LENGTH, NameNList, MangledNameNList, Merged, NList, Dwarf]", "[]"]
    private static let sections = ["__DWARF __debug_line", "__DWARF __debug_info", "__TEXT __text", "MACH_HEADER", "__DATA_CONST __got"]

    private mutating func address() -> String { "0x" + String(next() % 0x2_0000_0000, radix: 16).leftPadded(to: 16) }
    private mutating func size() -> String { "(" + String(repeating: " ", count: 1 + int(6)) + "0x" + String(int(0x2000), radix: 16) + ")" }
    private func indent(_ depth: Int) -> String { String(repeating: " ", count: depth) }

    mutating func line() -> String {
        switch int(100) {
        case 0..<3:
            return indent(8) + "\(address()) \(size()) __TEXT SEGMENT"
        case 3..<8:
            return indent(12) + "\(address()) \(size()) \(pick(Self.sections))"
        case 8..<28:
            var name = pick(Self.names)
            if chance(15) { name += " " + pick(Self.names) }
            let tail = chance(80) ? " " + pick(Self.attributes) : pick(["", " ", "\u{00A0}", "  "])
            return indent(16) + "\(address()) \(size()) \(name)\(tail)"
        case 28..<92:
            return indent(20) + "\(address()) \(size()) \(pick(Self.files))" + (chance(10) ? pick([" ", "\t", "\u{00A0}"]) : "")
        case 92..<94:
            return ""
        case 94..<96:
            // Unusual indentation, including non-ASCII whitespace, which both parsers must skip or treat alike.
            return pick(["\u{00A0}", "\t", " \u{301}", "\u{2003}"]) + indent(pick([7, 8, 15, 16, 19, 20])) + "\(address()) \(size()) main [FUNC]"
        default:
            return indent(pick([0, 4, 10, 24])) + "\(address()) \(size()) ignored"
        }
    }

    mutating func document(lineCount: Int) -> String {
        var text = "Header [arm64, 0.1 seconds]:\n    UUID /path [dSYM_v3]\n"
        for _ in 0..<lineCount {
            text += line() + (chance(5) ? "\r\n" : "\n")
        }
        return text
    }
}

private extension String {
    func leftPadded(to length: Int) -> String {
        count >= length ? self : String(repeating: "0", count: length - count) + self
    }
}
