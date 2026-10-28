//
//  NREventPersistenceFileSupport.swift
//  Agent
//
//  Copyright © 2026 New Relic. All rights reserved.
//

import Foundation

/// Shared directory-protection setup for the event-persistence stores, so
/// `NRFileEventStore` and `NRSessionManifestStore` don't each reimplement it.
enum NREventPersistenceFileSupport {

    /// Creates `url` (if needed) with Session Replay's file-protection level, and
    /// excludes it from iCloud/iTunes backup (data here must not outlive the 7-day cap).
    static func prepareProtectedDirectory(at url: URL) {
        do {
            try FileManager.default.createDirectory(
                at: url,
                withIntermediateDirectories: true,
                attributes: [.protectionKey: FileProtectionType.completeUntilFirstUserAuthentication]
            )
        } catch {
            NRLOG_AGENT_ERROR("NREventPersistence: failed to create directory at \(url.path): \(error)")
            return
        }

        var excludedURL = url
        var resourceValues = URLResourceValues()
        resourceValues.isExcludedFromBackup = true
        do {
            try excludedURL.setResourceValues(resourceValues)
        } catch {
            NRLOG_AGENT_WARNING("NREventPersistence: failed to exclude \(url.path) from backup: \(error)")
        }
    }
}
