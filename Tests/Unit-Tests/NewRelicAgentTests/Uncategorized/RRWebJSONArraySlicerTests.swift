//
//  RRWebJSONArraySlicerTests.swift
//  NewRelicAgent
//
//  Copyright © 2026 New Relic. All rights reserved.
//

import XCTest
@testable import NewRelic

final class RRWebJSONArraySlicerTests: XCTestCase {
    private func slices(_ json: String) -> [String]? {
        let data = Data(json.utf8)
        return RRWebJSONArraySlicer.elementRanges(in: data)?.map { String(decoding: data[$0], as: UTF8.self) }
    }

    func testEmptyArrayHasNoElements() {
        XCTAssertEqual(slices("[]"), [])
        XCTAssertEqual(slices(" [ \n ] "), [])
    }

    func testSlicesTopLevelElementsExactly() {
        XCTAssertEqual(slices(#"[{"type":4,"data":{"w":1}} , {"type":2,"s":"a,]}"}]"#),
                       [#"{"type":4,"data":{"w":1}}"#, #"{"type":2,"s":"a,]}"}"#])
    }

    func testEscapesStayInsideStrings() {
        XCTAssertEqual(slices(#"[{"s":"\"],"},{"s":"\\"}]"#), [#"{"s":"\"],"}"#, #"{"s":"\\"}"#])
    }

    func testMultiByteTextKeepsItsBytes() {
        XCTAssertEqual(slices(#"[{"s":"€😀漢"}]"#), [#"{"s":"€😀漢"}"#])
    }

    func testNestedArraysAndScalars() {
        XCTAssertEqual(slices(#"[[1,[2]],3,"x",null,true]"#)?.count, 5)
    }

    func testRejectsAnythingButOneArray() {
        for json in ["", "{}", #""x""#, "[1,2", "[1,,2]", "[1,]", "[1]x", "[1] [2]"] {
            XCTAssertNil(slices(json), json)
        }
    }
}
