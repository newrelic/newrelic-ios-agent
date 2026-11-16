//
//  RRWebJSONArraySlicer.swift
//  Agent
//
//  Copyright © 2026 New Relic. All rights reserved.
//

import Foundation

#if os(iOS) || os(tvOS)

/// Finds the elements of a JSON array without decoding them, so each rrweb event
/// can be stored with exactly the bytes it arrived with.
@available(iOS 13.0, *)
enum RRWebJSONArraySlicer {
    private static let openBracket = UInt8(ascii: "[")
    private static let closeBracket = UInt8(ascii: "]")
    private static let openBrace = UInt8(ascii: "{")
    private static let closeBrace = UInt8(ascii: "}")
    private static let comma = UInt8(ascii: ",")
    private static let quote = UInt8(ascii: "\"")
    private static let backslash = UInt8(ascii: "\\")

    /// The byte ranges of the top-level elements of one JSON array, with surrounding
    /// whitespace trimmed, or nil if `data` isn't exactly one JSON array.
    /// Only the structure is checked; the content is validated by the caller.
    static func elementRanges(in data: Data) -> [Range<Data.Index>]? {
        let base = data.startIndex
        return data.withUnsafeBytes { (bytes: UnsafeRawBufferPointer) -> [Range<Data.Index>]? in
            func trimmed(_ start: Int, _ end: Int) -> Range<Int> {
                var start = start, end = end
                while start < end && isWhitespace(bytes[start]) { start += 1 }
                while end > start && isWhitespace(bytes[end - 1]) { end -= 1 }
                return start..<end
            }

            var elements: [Range<Int>] = []
            var depth = 0
            var inString = false
            var escaped = false
            var elementStart = 0
            var closed = false

            for (offset, byte) in bytes.enumerated() {
                if closed {
                    guard isWhitespace(byte) else { return nil }
                    continue
                }
                if inString {
                    if escaped {
                        escaped = false
                    } else if byte == backslash {
                        escaped = true
                    } else if byte == quote {
                        inString = false
                    }
                    continue
                }
                if depth == 0 {
                    if isWhitespace(byte) { continue }
                    guard byte == openBracket else { return nil }
                    depth = 1
                    elementStart = offset + 1
                    continue
                }
                switch byte {
                case quote:
                    inString = true
                case openBracket, openBrace:
                    depth += 1
                case closeBracket, closeBrace:
                    depth -= 1
                    if depth == 0 {
                        guard byte == closeBracket else { return nil }
                        let element = trimmed(elementStart, offset)
                        if element.isEmpty {
                            // Only "[]" may end on an empty element.
                            guard elements.isEmpty else { return nil }
                        } else {
                            elements.append(element)
                        }
                        closed = true
                    }
                case comma where depth == 1:
                    let element = trimmed(elementStart, offset)
                    guard !element.isEmpty else { return nil }
                    elements.append(element)
                    elementStart = offset + 1
                default:
                    break
                }
            }

            guard closed else { return nil }
            return elements.map { (base + $0.lowerBound)..<(base + $0.upperBound) }
        }
    }

    private static func isWhitespace(_ byte: UInt8) -> Bool {
        return byte == 0x20 || byte == 0x09 || byte == 0x0A || byte == 0x0D
    }
}

#endif
