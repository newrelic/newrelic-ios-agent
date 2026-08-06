//
//  UIHostingViewRecordOrchestratorWidthOffsetTests.swift
//  NewRelicAgent
//
//  Copyright © 2026 New Relic. All rights reserved.
//

import XCTest
@testable import NewRelic

/// NR-546764: a SwiftUI `Text`'s captured wireframe width is padded by
/// `calculatedOffset` (2pt per space in the string) to compensate for SwiftUI
/// under-measuring space-heavy strings. That padding scaled with the string's
/// word count and was never bounded, so a NavigationLink row's description
/// label could grow past the row's real content width and overlap the
/// trailing disclosure chevron. These tests pin down the clamp that keeps the
/// padding from ever pushing a label past its container's bounds.
@available(iOS 13.0, *)
class UIHostingViewRecordOrchestratorWidthOffsetTests: XCTestCase {

    func testAmpleRoom_offsetPassesThroughUnchanged() {
        // A short single-line label ("Quick Settings") has few spaces and
        // plenty of room in its row, so the offset should be untouched.
        let rawOffset: CGFloat = 4 // 2 spaces
        let clamped = UIHostingViewRecordOrchestrator.clampedWidthOffset(
            rawOffset, frameOriginX: 32, frameWidth: 50, containerMaxX: 375)

        XCTAssertEqual(clamped, rawOffset)
        XCTAssertLessThanOrEqual(32 + 50 + clamped, 375)
    }

    func testNavigationLinkDescription_wouldOverlapChevronWithoutClamp() {
        // Reproduces NR-546764: a near-full-width description row where the
        // real content boundary (containerMaxX) sits where the disclosure
        // chevron begins. "Try new features before they're released to
        // everyone. These features may be unstable..." has 21 spaces, so the
        // pre-fix offset (spaces * 2 = 42) overshoots the row's real bound.
        let frameOriginX: CGFloat = 32
        let frameWidth: CGFloat = 330
        let containerMaxX: CGFloat = 375 // row's real content boundary, before the chevron
        let rawOffset: CGFloat = 42

        let unclampedMaxX = frameOriginX + frameWidth + rawOffset
        XCTAssertGreaterThan(unclampedMaxX, containerMaxX,
                              "sanity check: the raw offset does overshoot the row bound")

        let clamped = UIHostingViewRecordOrchestrator.clampedWidthOffset(
            rawOffset, frameOriginX: frameOriginX, frameWidth: frameWidth, containerMaxX: containerMaxX)

        XCTAssertEqual(frameOriginX + frameWidth + clamped, containerMaxX,
                        "clamped offset should fill exactly up to the row's real bound, not past it")
    }

    func testNoRoomLeft_offsetClampsToZero() {
        // The raw frame already reaches (or exceeds) the container bound —
        // there's no room to add any compensation, and we must never produce
        // a negative-width adjustment.
        let clamped = UIHostingViewRecordOrchestrator.clampedWidthOffset(
            10, frameOriginX: 32, frameWidth: 343, containerMaxX: 375)

        XCTAssertEqual(clamped, 0)
    }

    func testZeroRawOffset_passesThroughUnchanged() {
        let clamped = UIHostingViewRecordOrchestrator.clampedWidthOffset(
            0, frameOriginX: 32, frameWidth: 100, containerMaxX: 375)

        XCTAssertEqual(clamped, 0)
    }
}
