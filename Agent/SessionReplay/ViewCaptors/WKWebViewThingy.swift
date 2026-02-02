//
//  WKWebViewThingy.swift
//  Agent_iOS
//
//  Created for handling WKWebView with rrweb data
//  Copyright © 2025 New Relic. All rights reserved.
//

import Foundation
import UIKit
import WebKit

class WKWebViewThingy: SessionReplayViewThingy {
    var isMasked: Bool

    var subviews = [any SessionReplayViewThingy]()

    var shouldRecordSubviews: Bool {
        false  // WebView handles its own content via rrweb
    }

    var viewDetails: ViewDetails

    // Store the rrweb JSON events for this webview
    var rrwebEvents: [String]

    init(view: WKWebView, viewDetails: ViewDetails, rrwebEvents: [String] = []) {
        self.viewDetails = viewDetails
        self.isMasked = viewDetails.isMasked ?? false
        self.rrwebEvents = rrwebEvents
    }

    init(viewDetails: ViewDetails, rrwebEvents: [String] = []) {
        self.viewDetails = viewDetails
        self.isMasked = viewDetails.isMasked ?? false
        self.rrwebEvents = rrwebEvents
    }

    func cssDescription() -> String {
        return """
                #\(viewDetails.cssSelector) { \
                \(generateBaseCSSStyle())\
                overflow: hidden;
                }
                """
    }

    func generateRRWebNode() -> ElementNodeData {
        // Create a container iframe-like div for the webview
        // The webview acts as an isolated document, similar to an iframe in web rrweb
        let attributes: [String: String] = [
            "id": viewDetails.cssSelector,
            "data-webview": "true",
            "data-webview-id": String(viewDetails.viewId)
        ]

        return ElementNodeData(
            id: viewDetails.viewId,
            tagName: .div,
            attributes: attributes,
            childNodes: []
        )
    }

    func generateRRWebAdditionNode(parentNodeId: Int) -> [RRWebMutationData.AddRecord] {
        let node = generateRRWebNode()
        node.attributes["style"] = generateBaseCSSStyle() + " overflow: hidden;"
        let addNode: RRWebMutationData.AddRecord = .init(
            parentId: parentNodeId,
            nextId: viewDetails.nextId,
            node: .element(node)
        )

        return [addNode]
    }

    func generateDifference<T: SessionReplayViewThingy>(from other: T) -> [MutationRecord] {
        guard let typedOther = other as? WKWebViewThingy else {
            return []
        }

        var mutations = [MutationRecord]()
        var allAttributes = [String: String]()

        // Check for style changes
        let newStyle = typedOther.generateBaseCSSStyle() + " overflow: hidden;"
        allAttributes["style"] = newStyle

        if !allAttributes.isEmpty {
            let attributeRecord = RRWebMutationData.AttributeRecord(
                id: viewDetails.viewId,
                attributes: allAttributes
            )
            mutations.append(attributeRecord)
        }

        // Note: rrweb events are handled separately through the event stream
        // This only handles the container view changes

        return mutations
    }

    // Method to get the accumulated rrweb events as strings
    func getRRWebEvents() -> [String] {
        return rrwebEvents
    }

    // Method to add new rrweb events
    func addRRWebEvent(_ jsonString: String) {
        rrwebEvents.append(jsonString)
    }

    // Method to get and clear rrweb events (for continuous capture)
    func getAndClearRRWebEvents() -> [String] {
        let events = rrwebEvents
        rrwebEvents.removeAll()
        return events
    }

    // Parse rrweb JSON events into RRWebEvent objects that can be merged into the main stream
    func parseRRWebEvents() -> [AnyRRWebEvent] {
        var parsedEvents: [AnyRRWebEvent] = []

        for jsonString in rrwebEvents {
            guard let jsonData = jsonString.data(using: .utf8) else {
                continue
            }

            do {
                // Try to decode the JSON as a generic dictionary first to determine event type
                if let eventDict = try JSONSerialization.jsonObject(with: jsonData) as? [String: Any],
                   let eventType = eventDict["type"] as? Int {

                    // Decode based on event type
                    // Type 2 = Full Snapshot, Type 3 = Incremental Snapshot, Type 4 = Meta, Type 5 = Custom Event
                    let decoder = JSONDecoder()

                    switch eventType {
                    case 2: // Full Snapshot
                        if let fullSnapshotEvent = try? decoder.decode(FullSnapshotEvent.self, from: jsonData) {
                            parsedEvents.append(AnyRRWebEvent(fullSnapshotEvent))
                        }
                    case 3: // Incremental Snapshot
                        if let incrementalEvent = try? decoder.decode(IncrementalEvent.self, from: jsonData) {
                            parsedEvents.append(AnyRRWebEvent(incrementalEvent))
                        }
                    case 4: // Meta Event
                        if let metaEvent = try? decoder.decode(MetaEvent.self, from: jsonData) {
                           // parsedEvents.append(AnyRRWebEvent(metaEvent))
                        }
                    default:
                        // For other event types, try to decode as a generic event
                        break
                    }
                }
            } catch {
                // Skip events that fail to parse
                continue
            }
        }

        return parsedEvents
    }

    // Get parsed rrweb events and clear them for continuous capture
    func getAndClearParsedRRWebEvents() -> [AnyRRWebEvent] {
        let events = parseRRWebEvents()
        rrwebEvents.removeAll()
        return events
    }
}

extension WKWebViewThingy: Equatable {
    static func == (lhs: WKWebViewThingy, rhs: WKWebViewThingy) -> Bool {
        return lhs.viewDetails == rhs.viewDetails &&
            lhs.rrwebEvents == rhs.rrwebEvents
    }
}

extension WKWebViewThingy: Hashable {
    func hash(into hasher: inout Hasher) {
        hasher.combine(viewDetails)
        hasher.combine(rrwebEvents)
    }
}
