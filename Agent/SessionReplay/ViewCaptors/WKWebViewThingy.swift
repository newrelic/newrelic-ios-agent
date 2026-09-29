//
//  WKWebViewThingy.swift
//  Agent
//
//  Copyright © 2026 New Relic. All rights reserved.
//

import Foundation
import UIKit

#if os(iOS)
import WebKit

/// Maps a `WKWebView` to an empty rrweb `<iframe>` node.
///
/// The page's DOM arrives separately, from the browser agent injected into the WebView, with its node
/// IDs remapped into the native ID space (`WebViewReplayRemapper`). It is attached to this node as a
/// single-add mutation carrying the page's document -- the same mechanism rrweb itself uses for
/// iframes -- so the whole replay is one tree on the stock replayer (`WebViewReplayChunkBuilder`).
///
/// Position and size come from the native view's frame. The page's own viewport is deliberately
/// unused: its Meta event would resize the entire player.
class WKWebViewThingy: SessionReplayViewThingy {
    static let sourceAttribute = "data-nr-src"

    var isMasked: Bool
    var isBlocked: Bool
    var subviews = [any SessionReplayViewThingy]()

    /// A WebView's content is rendered by WebKit, not by UIKit subviews. Descending into its private
    /// view hierarchy (WKScrollView, WKContentView, ...) would emit nodes that correspond to nothing the
    /// user sees, inside the iframe whose content is about to be the page's document.
    var shouldRecordSubviews: Bool {
        false
    }

    var viewDetails: ViewDetails

    /// The URL loaded at capture time. Diagnostics only.
    let url: String?

    init(view: WKWebView, viewDetails: ViewDetails) {
        self.viewDetails = viewDetails
        self.isMasked = viewDetails.isMasked ?? false
        self.isBlocked = viewDetails.blockView ?? false
        self.url = view.url?.absoluteString
    }

    /// The iframe's node ID, which the page's document is attached under. It is the WebView's stable
    /// node ID, which lives on the view and so survives navigation.
    var channelId: Int {
        viewDetails.viewId
    }

    private func iframeStyle() -> String {
        var style = generateBaseCSSStyle()
        // Browsers draw a default inset border on iframes.
        if viewDetails.borderWidth == 0 && !isBlocked {
            style.append(" border: 0;")
        }
        return style
    }

    func cssDescription() -> String {
        return "#\(viewDetails.cssSelector) {\(iframeStyle())} "
    }

    private func nodeAttributes() -> RRWebAttributes {
        var attributes: RRWebAttributes = ["id": viewDetails.cssSelector]
        if let url = url, !url.isEmpty {
            // An inert data-* attribute, never `src`: a live `src` would navigate the replayed iframe
            // away from the about:blank document the page's DOM is built into, and rrweb would drop
            // the attachment.
            attributes[Self.sourceAttribute] = url
        }
        return attributes
    }

    func generateRRWebNode() -> ElementNodeData {
        return ElementNodeData(id: viewDetails.viewId,
                               tagName: .iframe,
                               attributes: nodeAttributes(),
                               childNodes: [])
    }

    func generateRRWebAdditionNode(parentNodeId: Int) -> [RRWebMutationData.AddRecord] {
        let node = generateRRWebNode()
        node.attributes["style"] = iframeStyle()
        return [.init(parentId: parentNodeId, nextId: viewDetails.nextId, node: .element(node))]
    }

    func generateDifference<T: SessionReplayViewThingy>(from other: T) -> [MutationRecord] {
        guard let typedOther = other as? WKWebViewThingy else {
            return []
        }
        var attributes = typedOther.nodeAttributes()
        attributes["style"] = typedOther.iframeStyle()
        return [RRWebMutationData.AttributeRecord(id: viewDetails.viewId, attributes: attributes)]
    }
}

extension WKWebViewThingy: Equatable {
    static func == (lhs: WKWebViewThingy, rhs: WKWebViewThingy) -> Bool {
        return lhs.viewDetails == rhs.viewDetails && lhs.url == rhs.url
    }
}

extension WKWebViewThingy: Hashable {
    func hash(into hasher: inout Hasher) {
        hasher.combine(viewDetails)
        hasher.combine(url)
    }
}
#endif
