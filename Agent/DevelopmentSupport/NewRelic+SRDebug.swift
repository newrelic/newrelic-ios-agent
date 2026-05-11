//
//  NewRelic+SRDebug.swift
//
//  Debug-only accessor that exposes the internal SessionReplayManager to
//  in-process diagnostic tooling (e.g. NRTestApp's Dev HUD). The entire file
//  is compiled out of release builds; the symbol does not ship in the
//  binary XCFramework that SDK consumers install.
//
//  This is not a supported public API.
//

#if DEBUG

import Foundation
import UIKit
@_implementationOnly import NewRelicPrivate

@available(iOS 13.0, *)
extension NewRelic {
    @objc public static func debugSessionReplayManager() -> SessionReplayManager? {
        return NewRelicAgentInternal.sharedInstance()?.debugSessionReplayManager() as? SessionReplayManager
    }
}

@objc public enum SRDebugOverlayKind: Int {
    case regular     = 0
    case masked      = 1
    case blocked     = 2
    case swiftUIHost = 3
    case clear       = 4
}

@objc public final class SRDebugOverlayRect: NSObject {
    @objc public let frame: CGRect
    @objc public let viewName: String
    @objc public let viewId: Int
    @objc public let kind: SRDebugOverlayKind
    @objc public let depth: Int

    @objc public init(frame: CGRect, viewName: String, viewId: Int, kind: SRDebugOverlayKind, depth: Int) {
        self.frame = frame
        self.viewName = viewName
        self.viewId = viewId
        self.kind = kind
        self.depth = depth
        super.init()
    }
}

#if os(iOS) || os(tvOS)
@available(iOS 13.0, *)
enum SRDebugOverlayFlattener {
    static func flatten(frame: SessionReplayFrame) -> [SRDebugOverlayRect] {
        var out: [SRDebugOverlayRect] = []
        walk(frame.views, rootSwiftUIViewId: frame.rootSwiftUIViewId, depth: 0, into: &out)
        return out
    }

    private static func walk(_ thingy: any SessionReplayViewThingy,
                             rootSwiftUIViewId: Int?,
                             depth: Int,
                             into out: inout [SRDebugOverlayRect]) {
        let details = thingy.viewDetails
        if details.isVisible && !details.frame.isEmpty {
            let kind = classify(details: details, thingy: thingy, rootSwiftUIViewId: rootSwiftUIViewId)
            out.append(SRDebugOverlayRect(frame: details.frame,
                                          viewName: details.viewName,
                                          viewId: details.viewId,
                                          kind: kind,
                                          depth: depth))
        }
        for child in thingy.subviews {
            walk(child, rootSwiftUIViewId: rootSwiftUIViewId, depth: depth + 1, into: &out)
        }
    }

    private static func classify(details: ViewDetails,
                                 thingy: any SessionReplayViewThingy,
                                 rootSwiftUIViewId: Int?) -> SRDebugOverlayKind {
        if thingy.isBlocked || details.blockView == true {
            return .blocked
        }
        if thingy.isMasked || details.isMasked == true {
            return .masked
        }
        if let root = rootSwiftUIViewId, root == details.viewId {
            return .swiftUIHost
        }
        if details.isClear {
            return .clear
        }
        return .regular
    }
}
#endif

#endif
