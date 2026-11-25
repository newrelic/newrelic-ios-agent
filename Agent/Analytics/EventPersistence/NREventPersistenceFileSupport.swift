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

    // MARK: - Layout
    //
    // <storePath>/nr_event_cache/<sessionId>/<eventUUID>.json   one file per event
    // <storePath>/nr_event_cache/<sessionId>/_manifest.json     that session's manifest
    //
    // The files are the only state: there is no index to keep consistent with them, so a crash
    // can never leave an event the store doesn't know about.

    static let rootDirectoryName = "nr_event_cache"
    static let manifestFileName = "_manifest.json"

    static func rootURL(storePath: String) -> URL {
        URL(fileURLWithPath: storePath).appendingPathComponent(rootDirectoryName, isDirectory: true)
    }

    private static let safeNameCharacters: CharacterSet = {
        var set = CharacterSet.alphanumerics
        set.insert(charactersIn: "-_")
        return set
    }()

    /// Ids become path components, so percent-encode anything that isn't alphanumeric, `-` or
    /// `_` (this also neutralizes `/` and `..`).
    static func encodedName(_ id: String) -> String {
        id.addingPercentEncoding(withAllowedCharacters: safeNameCharacters) ?? ""
    }

    static func decodedName(_ name: String) -> String {
        name.removingPercentEncoding ?? name
    }

    /// Removes `url` only if it is an empty directory. POSIX `rmdir` fails on a non-empty one,
    /// so this can never delete a file another store wrote in between.
    static func removeDirectoryIfEmpty(_ url: URL) {
        _ = rmdir(url.path)
    }
}
