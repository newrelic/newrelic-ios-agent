//
//  NREventRecord.swift
//  Agent
//
//  Copyright © 2026 New Relic. All rights reserved.
//

import Foundation

/// On-disk representation of a single analytics event, captured at the moment
/// it was recorded so it can survive a force-quit/crash and be replayed on the
/// next launch with its original timestamp and session attribution intact.
/// Mirrors the Android agent's `EventRecord` schema.
struct NREventRecord {
    static let currentSchemaVersion = 1

    let schemaVersion: Int
    let eventUUID: String
    let eventType: String
    let name: String?
    /// Epoch milliseconds -- write time, matches `NRMAAnalyticEventProtocol.timestamp`'s unit.
    let timestamp: Int64
    let attributes: [String: Any]
    /// The session this event originated in -- preserved verbatim through replay.
    let sessionId: String
    let realAgentId: UInt64
    /// User-set attributes (via setAttribute/setUserId) captured at write time,
    /// kept separate from the session's stableAttributes so replay can overlay
    /// them onto whichever SessionManifest is found for `sessionId`.
    let mutableAttributesSnapshot: [String: Any]

    init(eventUUID: String,
         eventType: String,
         name: String?,
         timestamp: Int64,
         attributes: [String: Any],
         sessionId: String,
         realAgentId: UInt64,
         mutableAttributesSnapshot: [String: Any],
         schemaVersion: Int = NREventRecord.currentSchemaVersion) {
        self.schemaVersion = schemaVersion
        self.eventUUID = eventUUID
        self.eventType = eventType
        self.name = name
        self.timestamp = timestamp
        self.attributes = attributes
        self.sessionId = sessionId
        self.realAgentId = realAgentId
        self.mutableAttributesSnapshot = mutableAttributesSnapshot
    }

    /// Reconstructs a record from a decoded JSON dictionary. Returns nil only
    /// when a field required to safely replay the event (uuid/type/timestamp/
    /// sessionId) is missing or malformed -- corrupt storage should be treated
    /// as "no record", never crash the caller.
    init?(dictionary: [String: Any]) {
        guard let eventUUID = dictionary["eventUUID"] as? String,
              let eventType = dictionary["eventType"] as? String,
              let timestampNumber = dictionary["timestamp"] as? NSNumber,
              let sessionId = dictionary["sessionId"] as? String else {
            return nil
        }
        self.schemaVersion = (dictionary["schemaVersion"] as? NSNumber)?.intValue ?? NREventRecord.currentSchemaVersion
        self.eventUUID = eventUUID
        self.eventType = eventType
        self.name = dictionary["name"] as? String
        self.timestamp = timestampNumber.int64Value
        self.attributes = (dictionary["attributes"] as? [String: Any]) ?? [:]
        self.sessionId = sessionId
        self.realAgentId = (dictionary["realAgentId"] as? NSNumber)?.uint64Value ?? 0
        self.mutableAttributesSnapshot = (dictionary["mutableAttributesSnapshot"] as? [String: Any]) ?? [:]
    }

    var dictionaryRepresentation: [String: Any] {
        var dict: [String: Any] = [
            "schemaVersion": schemaVersion,
            "eventUUID": eventUUID,
            "eventType": eventType,
            "timestamp": timestamp,
            "attributes": attributes,
            "sessionId": sessionId,
            "realAgentId": realAgentId,
            "mutableAttributesSnapshot": mutableAttributesSnapshot
        ]
        if let name {
            dict["name"] = name
        }
        return dict
    }
}
