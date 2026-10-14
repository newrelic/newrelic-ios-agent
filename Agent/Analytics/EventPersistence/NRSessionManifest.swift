//
//  NRSessionManifest.swift
//  Agent
//
//  Copyright © 2026 New Relic. All rights reserved.
//

import Foundation

/// Per-session snapshot of "stable" attributes (app version, OS, install id,
/// carrier, etc.) that don't change over the life of a session. Looked up by
/// `sessionId` at replay time to resolve the final attribute set for a
/// recovered `NREventRecord`. Mirrors the Android agent's `SessionManifest`.
struct NRSessionManifest {
    static let currentSchemaVersion = 1

    let schemaVersion: Int
    let sessionId: String
    let realAgentId: UInt64
    /// Epoch milliseconds.
    let sessionStartMs: Int64
    /// Epoch milliseconds -- refreshed on every harvest tick so a manifest's
    /// own retention can be judged independently of any event referencing it.
    var lastUpdateMs: Int64
    let stableAttributes: [String: Any]

    init(sessionId: String,
         realAgentId: UInt64,
         sessionStartMs: Int64,
         lastUpdateMs: Int64,
         stableAttributes: [String: Any],
         schemaVersion: Int = NRSessionManifest.currentSchemaVersion) {
        self.schemaVersion = schemaVersion
        self.sessionId = sessionId
        self.realAgentId = realAgentId
        self.sessionStartMs = sessionStartMs
        self.lastUpdateMs = lastUpdateMs
        self.stableAttributes = stableAttributes
    }

    init?(dictionary: [String: Any]) {
        guard let sessionId = dictionary["sessionId"] as? String,
              let sessionStartMsNumber = dictionary["sessionStartMs"] as? NSNumber else {
            return nil
        }
        self.schemaVersion = (dictionary["schemaVersion"] as? NSNumber)?.intValue ?? NRSessionManifest.currentSchemaVersion
        self.sessionId = sessionId
        self.realAgentId = (dictionary["realAgentId"] as? NSNumber)?.uint64Value ?? 0
        self.sessionStartMs = sessionStartMsNumber.int64Value
        self.lastUpdateMs = (dictionary["lastUpdateMs"] as? NSNumber)?.int64Value ?? sessionStartMsNumber.int64Value
        self.stableAttributes = (dictionary["stableAttributes"] as? [String: Any]) ?? [:]
    }

    var dictionaryRepresentation: [String: Any] {
        [
            "schemaVersion": schemaVersion,
            "sessionId": sessionId,
            "realAgentId": realAgentId,
            "sessionStartMs": sessionStartMs,
            "lastUpdateMs": lastUpdateMs,
            "stableAttributes": stableAttributes
        ]
    }
}
