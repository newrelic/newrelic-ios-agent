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

/// Maps a `WKWebView` to an rrweb `<div>` carrying a `data-nr-webview-channel` attribute: the mount
/// point for that WebView's own replay stream.
///
/// The WebView's DOM never enters this node. It travels as a separate stream of `EventType.Plugin`
/// events (see `WebViewReplayEnvelope`), and the replay plugin hosts a nested `Replayer` -- with its
/// own `Mirror` and ID space -- rooted at this node. The two streams share exactly one thing: the
/// channel ID in this attribute.
///
/// Deliberately a `div` and not an `iframe`. The plugin mounts with `new Replayer([], {root: node})`,
/// which appends the replayer's own wrapper element as a child of `node`, and HTML ignores the
/// children of an `<iframe>` element.
class WKWebViewThingy: SessionReplayViewThingy {
    static let channelAttribute = "data-nr-webview-channel"
    static let sourceAttribute = "data-nr-src"

    var isMasked: Bool
    var isBlocked: Bool
    var subviews = [any SessionReplayViewThingy]()

    /// A WebView's content is rendered by WebKit, not by UIKit subviews. Descending into its private
    /// view hierarchy (WKScrollView, WKContentView, ...) would emit nodes that correspond to nothing the
    /// user sees, inside the node the plugin is about to mount into.
    var shouldRecordSubviews: Bool {
        false
    }

    var viewDetails: ViewDetails

    /// The URL loaded at capture time. Diagnostics only: it lands in an inert data-* attribute, never
    /// `src`.
    let url: String?

    init(view: WKWebView, viewDetails: ViewDetails) {
        self.viewDetails = viewDetails
        self.isMasked = viewDetails.isMasked ?? false
        self.isBlocked = viewDetails.blockView ?? false
        self.url = view.url?.absoluteString
    }

    /// The channel ID is the WebView's stable node ID, which lives on the view and so survives
    /// navigation. That matters: the plugin keys its nested replayer by channel, and an ID that changed
    /// on navigation would orphan it.
    var channelId: Int {
        viewDetails.viewId
    }

    func cssDescription() -> String {
        return "#\(viewDetails.cssSelector) {\(generateBaseCSSStyle())} "
    }

    private func nodeAttributes() -> RRWebAttributes {
        var attributes: RRWebAttributes = ["id": viewDetails.cssSelector]
        // A blocked WebView renders as the base black box; without a channel the plugin never mounts
        // into it.
        if !isBlocked {
            attributes[Self.channelAttribute] = String(channelId)
            if let url = url, !url.isEmpty {
                attributes[Self.sourceAttribute] = url
            }
        }
        return attributes
    }

    func generateRRWebNode() -> ElementNodeData {
        return ElementNodeData(id: viewDetails.viewId,
                               tagName: .div,
                               attributes: nodeAttributes(),
                               childNodes: [])
    }

    func generateRRWebAdditionNode(parentNodeId: Int) -> [RRWebMutationData.AddRecord] {
        let node = generateRRWebNode()
        node.attributes["style"] = generateBaseCSSStyle()
        return [.init(parentId: parentNodeId, nextId: viewDetails.nextId, node: .element(node))]
    }

    func generateDifference<T: SessionReplayViewThingy>(from other: T) -> [MutationRecord] {
        guard let typedOther = other as? WKWebViewThingy else {
            return []
        }
        var attributes = typedOther.nodeAttributes()
        attributes["style"] = typedOther.generateBaseCSSStyle()
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
