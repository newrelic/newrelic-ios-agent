//
//  WebViewEventStitcher.swift
//  Agent_iOS
//
//  Re-namespaces rrweb events captured inside a WKWebView and re-parents them
//  under that webview's container node in the native session-replay tree, so the
//  player sees one continuous DOM instead of two competing root documents.
//
//  Copyright © 2026 New Relic. All rights reserved.
//

import Foundation

/// Re-emits webview rrweb events as mutations under a given native container node.
///
/// Webview events arrive with their own ID space (rrweb numbers nodes from 1). Native
/// session-replay events use `IDGenerator.shared`, which also starts low. Without
/// translation, the two streams would collide and the player would treat the webview
/// snapshot as a fresh document, replacing the native tree.
///
/// This stitcher:
///   * Adds a fixed offset to every webview-side node id, plus a per-checkout epoch
///     bump so that a new rrweb full-snapshot doesn't collide with the previous one.
///   * Converts each webview FullSnapshot into a mutation that removes the previously
///     injected children and adds the new tree under `parentNodeId`.
///   * Re-namespaces ids inside Incremental mutations / mouse / touch events.
final class WebViewEventStitcher {
    /// Native session-replay nodeId of the WKWebView container (`WKWebViewThingy.viewDetails.viewId`).
    private(set) var parentNodeId: Int

    /// Top-level children currently injected under the container, tracked so the next
    /// checkout can remove them before adding a fresh tree.
    private var lastTopLevelChildIds: [Int] = []

    /// Bumps each time we transform a FullSnapshot, giving every checkout a fresh
    /// id range. Without this, rrweb's post-checkout ids (which restart at 1) would
    /// alias the previous epoch's translated ids.
    private var epochCount: Int = 0

    private let baseOffset: Int
    private let epochSize: Int

    init(parentNodeId: Int, baseOffset: Int = 1_000_000_000, epochSize: Int = 1_000_000) {
        self.parentNodeId = parentNodeId
        self.baseOffset = baseOffset
        self.epochSize = epochSize
    }

    func update(parentNodeId: Int) {
        self.parentNodeId = parentNodeId
    }

    private var currentOffset: Int {
        return baseOffset + epochCount * epochSize
    }

    /// Transforms a parsed webview event into one or more native-tree-compatible events.
    /// Returns an empty array if the event type isn't supported (e.g. meta).
    func stitch(_ event: AnyRRWebEvent) -> [AnyRRWebEvent] {
        if let full = event.base as? FullSnapshotEvent {
            return stitchFullSnapshot(full)
        }
        if let incremental = event.base as? IncrementalEvent {
            if let stitched = stitchIncremental(incremental) {
                return [AnyRRWebEvent(stitched)]
            }
            return []
        }
        return []
    }

    // MARK: - Full snapshot

    private func stitchFullSnapshot(_ event: FullSnapshotEvent) -> [AnyRRWebEvent] {
        epochCount += 1
        let offset = currentOffset

        let translatedRoot = translate(event.data.node, offset: offset)

        // The webview emits a tree rooted at a Document node. We want to inject only
        // its element children (head/body sit beneath the html element) under the
        // native container; the documentType node has no meaningful place in the
        // native parent and would be ignored by the player anyway.
        var newChildren: [SerializedNode] = []
        if case .document(let doc) = translatedRoot {
            newChildren = doc.childNodes.filter { node in
                if case .documentType = node { return false }
                return true
            }
        } else {
            return []
        }

        let removes: [RRWebMutationData.RemoveRecord] = lastTopLevelChildIds.map { childId in
            RRWebMutationData.RemoveRecord(parentId: parentNodeId, id: childId)
        }

        var adds: [RRWebMutationData.AddRecord] = []
        adds.reserveCapacity(newChildren.count)
        for node in newChildren {
            adds.append(RRWebMutationData.AddRecord(parentId: parentNodeId, nextId: nil, node: node))
        }

        lastTopLevelChildIds = newChildren.map { idOf($0) }

        let mutation = RRWebMutationData(adds: adds, removes: removes, texts: nil, attributes: nil)
        let incremental = IncrementalEvent(timestamp: event.timestamp, data: .mutation(mutation))
        return [AnyRRWebEvent(incremental)]
    }

    // MARK: - Incremental snapshot

    private func stitchIncremental(_ event: IncrementalEvent) -> IncrementalEvent? {
        let offset = currentOffset
        let translatedData: RRWebIncrementalData
        switch event.data {
        case .mutation(let m):
            translatedData = .mutation(translate(m, offset: offset))
        case .mouseInteraction(let m):
            translatedData = .mouseInteraction(RRWebMouseInteractionData(
                type: m.type,
                id: m.id + offset,
                x: m.x,
                y: m.y
            ))
        case .touchMove(let t):
            let positions = t.positions.map { p in
                RRWebTouchPosition(x: p.x, y: p.y, id: p.id + offset, timeOffset: p.timeOffset)
            }
            translatedData = .touchMove(RRWebTouchMoveData(positions: positions))
        }
        return IncrementalEvent(timestamp: event.timestamp, data: translatedData)
    }

    // MARK: - Tree translation

    private func translate(_ node: SerializedNode, offset: Int) -> SerializedNode {
        switch node {
        case .document(let d):
            return .document(DocumentNodeData(
                id: d.id + offset,
                childNodes: d.childNodes.map { translate($0, offset: offset) }
            ))
        case .documentType(let dt):
            return .documentType(DocumentTypeNodeData(
                id: dt.id + offset,
                name: dt.name,
                publicId: dt.publicId,
                systemId: dt.systemId
            ))
        case .element(let e):
            let translated = ElementNodeData(
                id: e.id + offset,
                tagName: e.tagName,
                attributes: e.attributes,
                childNodes: e.childNodes.map { translate($0, offset: offset) },
                isSVG: e.isSVG
            )
            return .element(translated)
        case .text(let t):
            return .text(TextNodeData(
                id: t.id + offset,
                isStyle: t.isStyle,
                textContent: t.textContent,
                childNodes: t.childNodes.map { translate($0, offset: offset) }
            ))
        }
    }

    private func translate(_ data: RRWebMutationData, offset: Int) -> RRWebMutationData {
        let adds = data.adds?.map { record in
            RRWebMutationData.AddRecord(
                parentId: record.parentId + offset,
                nextId: record.nextId.map { $0 + offset },
                node: translate(record.node, offset: offset)
            )
        }
        let removes = data.removes?.map { record in
            RRWebMutationData.RemoveRecord(parentId: record.parentId + offset, id: record.id + offset)
        }
        let texts = data.texts?.map { record in
            RRWebMutationData.TextRecord(id: record.id + offset, value: record.value)
        }
        let attributes = data.attributes?.map { record in
            RRWebMutationData.AttributeRecord(id: record.id + offset, attributes: record.attributes)
        }
        return RRWebMutationData(adds: adds, removes: removes, texts: texts, attributes: attributes)
    }

    private func idOf(_ node: SerializedNode) -> Int {
        switch node {
        case .document(let d): return d.id
        case .documentType(let dt): return dt.id
        case .element(let e): return e.id
        case .text(let t): return t.id
        }
    }
}
