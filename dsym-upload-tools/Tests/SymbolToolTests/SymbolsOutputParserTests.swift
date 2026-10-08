//
//  SymbolsOutputParserTests.swift
//  2026 New Relic
//

import XCTest
@testable import SymbolTool

final class SymbolsOutputParserTests: XCTestCase {

    // MARK: Golden files
    // The .map fixtures were rendered by the original single-file run-symbol-tool.swift from the
    // matching `symbols -arch` output, so these tests pin the map format byte-for-byte.

    func testRendersTestAppArm64MapIdenticallyToOriginalTool() throws {
        try assertGolden(symbols: "TestApp-arm64", map: "TestApp-arm64",
                         slice: DwarfSlice(uuid: "bdbb53df45803bb69123234b492d9f65", architecture: "arm64"))
    }

    func testRendersTestAppX86MapIdenticallyToOriginalTool() throws {
        try assertGolden(symbols: "TestApp-x86_64", map: "TestApp-x86_64",
                         slice: DwarfSlice(uuid: "a6a0824813a13bceaed80b6f92dfab3b", architecture: "x86_64"))
    }

    func testRendersCLibraryMapIdenticallyToOriginalTool() throws {
        try assertGolden(symbols: "libSq-arm64", map: "libSq-arm64",
                         slice: DwarfSlice(uuid: "libuuid", architecture: "arm64"))
    }

    private func assertGolden(symbols: String, map: String, slice: DwarfSlice, file: StaticString = #filePath, line: UInt = #line) throws {
        let output = try Fixture.text(symbols)
        let expected = try Fixture.text(map, "map")
        let rendered = try SymbolsOutputParser.parseSymbolMap(output, slice: slice).render()
        XCTAssertEqual(rendered, expected, file: file, line: line)
    }

    // MARK: symbols -uuid

    func testParsesSlicesFromUUIDOutput() throws {
        let slices = try SymbolsOutputParser.parseSlices(try Fixture.text("TestApp-uuid"))
        XCTAssertEqual(slices, [
            DwarfSlice(uuid: "a6a0824813a13bceaed80b6f92dfab3b", architecture: "x86_64"),
            DwarfSlice(uuid: "bdbb53df45803bb69123234b492d9f65", architecture: "arm64"),
        ])
    }

    func testUUIDParsingSkipsBlankLinesAndToleratesExtraSpaces() throws {
        let slices = try SymbolsOutputParser.parseSlices("\n   \nABCD-EF01  arm64e   /path/App\n")
        XCTAssertEqual(slices, [DwarfSlice(uuid: "abcdef01", architecture: "arm64e")])
    }

    func testUUIDLineWithoutArchitectureFails() {
        XCTAssertThrowsError(try SymbolsOutputParser.parseSlices("ABCD-EF01\n"))
    }

    // MARK: Line parsers

    func testPadHexRightPadsAndTruncatesToSixteenDigits() {
        XCTAssertEqual(SymbolsOutputParser.padHex("0x1f"), "0x1f00000000000000")
        XCTAssertEqual(SymbolsOutputParser.padHex("0x0000000100000a90 ("), "0x0000000100000a90")
    }

    func testDwarfLineEndingAtCloseParenIsIgnoredInsteadOfTrapping() throws {
        // The original implementation offset two characters past ")" and trapped on this input.
        XCTAssertNil(try SymbolsOutputParser.parseDwarf("0x000000010000d000 (0x3000)"))
    }

    func testNonDwarfSectionIsIgnored() throws {
        XCTAssertNil(try SymbolsOutputParser.parseDwarf("0x0000000100000a90 (  0x1850) __TEXT __text"))
    }

    func testDwarfSectionIsParsed() throws {
        let symbol = try XCTUnwrap(try SymbolsOutputParser.parseDwarf("0x000000010000d000 (   0x2f2) __DWARF __debug_line"))
        XCTAssertEqual(symbol.0, "0x000000010000d000")
        XCTAssertEqual(symbol.1, "__debug_line")
    }

    func testFunctionWithBracketBeforeCloseParenDoesNotTrap() throws {
        // " [" before ")" used to produce an inverted range.
        let symbol = try SymbolsOutputParser.parseFunction("0x10 [x] (0x4) main [FUNC]")
        XCTAssertEqual(symbol.1, " main ")
    }

    func testInvalidLinesThrowConversionErrors() {
        XCTAssertThrowsError(try SymbolsOutputParser.parseFunction("no parens here"))
        XCTAssertThrowsError(try SymbolsOutputParser.parseDwarf("no parens here"))
        XCTAssertThrowsError(try SymbolsOutputParser.parseSourceLine("0x10 (0x4)", functionName: "main"))
    }

    func testSourceLinesUseEnclosingFunction() throws {
        let output = """
                        0x0000000100000c04 (     0x4) Greeter.init(name:) [FUNC, PEXT]
                            0x0000000100000c04 (     0x4) app.swift:2
        """
        let map = try SymbolsOutputParser.parseSymbolMap(output, slice: DwarfSlice(uuid: "u", architecture: "arm64"))
        XCTAssertEqual(map.symbols["0x0000000100000c04"], "Greeter.init(name:) (app.swift:2)")
    }

    func testWhitespaceOnlyLinesAreIgnored() throws {
        let map = try SymbolsOutputParser.parseSymbolMap("        \n            \n", slice: DwarfSlice(uuid: "u", architecture: "arm64"))
        XCTAssertTrue(map.vmAddresses.isEmpty)
        XCTAssertTrue(map.symbols.isEmpty)
    }
}
