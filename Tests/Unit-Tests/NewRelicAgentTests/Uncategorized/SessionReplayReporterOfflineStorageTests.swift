//
//  SessionReplayReporterOfflineStorageTests.swift
//  NewRelicAgent
//
//  Created by Mike Bruin on 5/26/26.
//  Copyright © 2026 New Relic. All rights reserved.
//

import XCTest
@testable import NewRelic

class SessionReplayReporterOfflineStorageTests: XCTestCase {

    var reporter: SessionReplayReporter!
    var mockOfflineStorage: MockNRMAOfflineStorage!
    var testURL: URL!
    var testData: Data!

    // Helper function to ensure unique filenames by waiting for new second
    func ensureUniqueTimestamp() {
        // Files use second-based timestamps (yyyy-MM-dd-HH-mm-ss)
        // Must wait until we're in a new second to avoid filename collisions

        let startTime = Date()
        let startSecond = Calendar.current.component(.second, from: startTime)

        // Wait until the second changes
        var currentSecond = startSecond
        while currentSecond == startSecond {
            usleep(50000) // Check every 0.05 seconds
            currentSecond = Calendar.current.component(.second, from: Date())
        }

        // Add small buffer to ensure filesystem is ready
        usleep(50000) // 0.05 seconds
    }

    // Helper to prepare storage with cleanup and filesystem sync
    func prepareStorage(_ storage: NRMAOfflineStorage) {
        _ = storage.clearAllOfflineFiles()
        UserDefaults.standard.set(0, forKey: "com.newrelic.offlineStorageCurrentSize")
        UserDefaults.standard.synchronize()
        // Delay to let file system settle after clearing - this is critical
        // for directory enumeration to return accurate results
        usleep(150000) // 0.15 seconds
    }

    // Helper to force filesystem sync after writes
    func syncFilesystem() {
        // Give filesystem time to flush buffers and update directory cache
        usleep(200000) // 0.2 seconds
    }

    override func setUp() {
        super.setUp()

        // Aggressively clear all offline storage before each test
        _ = NRMAOfflineStorage.clearAllOfflineDirectories()

        // Reset the global size counter AFTER clearing directories
        // (clearAllOfflineDirectories also resets this, but do it again to be sure)
        UserDefaults.standard.set(0, forKey: "com.newrelic.offlineStorageCurrentSize")
        UserDefaults.standard.synchronize()

        // Create test data
        testData = "test session replay data".data(using: .utf8)!
        testURL = URL(string: "https://mobile-collector.newrelic.com/sessionreplay")!

        // Initialize reporter
        reporter = SessionReplayReporter(
            applicationToken: "test-token-12345",
            url: "mobile-collector.newrelic.com" as NSString
        )

        // Enable offline storage feature flag
        NewRelic.enableFeatures(NRMAFeatureFlags.NRFeatureFlag_OfflineStorage)
    }

    override func tearDown() {
        reporter = nil
        mockOfflineStorage = nil
        _ = NRMAOfflineStorage.clearAllOfflineDirectories()
        UserDefaults.standard.set(0, forKey: "com.newrelic.offlineStorageCurrentSize")
        UserDefaults.standard.synchronize()
        super.tearDown()
    }

    // MARK: - JSON Encoding/Decoding Tests

    func testSessionReplayDataEncodingAndDecoding() {
        // Create a SessionReplayData object
        let sessionReplayData = SessionReplayData(
            sessionReplayFramesData: testData,
            url: testURL
        )

        // Encode to JSON
        let encoder = JSONEncoder()
        guard let encodedData = try? encoder.encode(sessionReplayData) else {
            XCTFail("Failed to encode SessionReplayData")
            return
        }

        XCTAssertGreaterThan(encodedData.count, 0, "Encoded data should not be empty")

        // Decode from JSON
        let decoder = JSONDecoder()
        guard let decodedData = try? decoder.decode(SessionReplayData.self, from: encodedData) else {
            XCTFail("Failed to decode SessionReplayData")
            return
        }

        // Verify decoded data matches original
        XCTAssertEqual(decodedData.sessionReplayFramesData, sessionReplayData.sessionReplayFramesData,
                      "Decoded data should match original data")
        XCTAssertEqual(decodedData.url, sessionReplayData.url,
                      "Decoded URL should match original URL")
    }

    func testSessionReplayDataWithGzippedData() {
        // Create gzipped data
        let uncompressedData = String(repeating: "test data ", count: 100).data(using: .utf8)!
        guard let gzippedData = try? uncompressedData.gzipped() else {
            XCTFail("Failed to gzip data")
            return
        }

        XCTAssertTrue(gzippedData.isGzipped, "Data should be marked as gzipped")

        // Create SessionReplayData with gzipped data
        let sessionReplayData = SessionReplayData(
            sessionReplayFramesData: gzippedData,
            url: testURL
        )

        // Encode and decode
        guard let encodedData = try? JSONEncoder().encode(sessionReplayData),
              let decodedData = try? JSONDecoder().decode(SessionReplayData.self, from: encodedData) else {
            XCTFail("Failed to encode/decode gzipped data")
            return
        }

        // Verify gzipped flag is preserved
        XCTAssertTrue(decodedData.sessionReplayFramesData.isGzipped,
                     "Gzipped flag should be preserved through encoding/decoding")
        XCTAssertEqual(decodedData.sessionReplayFramesData, gzippedData,
                      "Gzipped data should match after encoding/decoding")
    }

    // MARK: - Offline Storage Integration Tests

    func testOfflineStoragePersistsDataOnNetworkError() {
        // Use unique endpoint to avoid conflicts
        let uniqueEndpoint = "test_persist_\(Int(Date().timeIntervalSince1970 * 1000))"
        guard let storage = NRMAOfflineStorage(endpoint: uniqueEndpoint) else {
            XCTFail("Failed to create offline storage")
            return
        }

        // Clear and reset with delay
        prepareStorage(storage)

        storage.setMaxOfflineStorageSize(10) // 10 MB

        // Create session replay data
        let sessionReplayData = SessionReplayData(
            sessionReplayFramesData: testData,
            url: testURL
        )

        // Encode the data
        guard let encodedData = try? JSONEncoder().encode(sessionReplayData) else {
            XCTFail("Failed to encode data")
            return
        }

        // Persist to offline storage (synchronous operation)
        let success = storage.persistData(toDisk: encodedData)
        XCTAssertTrue(success, "Should successfully persist data to offline storage")

        // Force filesystem sync
        syncFilesystem()

        // Verify data was persisted
        guard let offlineData = storage.getAllOfflineData(false) else {
            XCTFail("Failed to retrieve offline data - got nil")
            return
        }

        XCTAssertGreaterThanOrEqual(offlineData.count, 1, "Should have at least 1 offline data item")

        // Verify we can decode the persisted data
        guard let decodedData = try? JSONDecoder().decode(SessionReplayData.self, from: offlineData[0]) else {
            XCTFail("Failed to decode persisted data")
            return
        }

        XCTAssertEqual(decodedData.sessionReplayFramesData, testData)
        XCTAssertEqual(decodedData.url, testURL)

        // Clean up
        _ = storage.clearAllOfflineFiles()
    }

    func testOfflineStorageWithURLContainingSpecialCharacters() {
        // Test URL with query parameters and special characters
        let complexURL = URL(string: "https://mobile-collector.newrelic.com/sessionreplay?type=SessionReplay&app_id=12345&attributes=key1=value1&key2=value%20with%20spaces")!

        let sessionReplayData = SessionReplayData(
            sessionReplayFramesData: testData,
            url: complexURL
        )

        // Encode and decode
        guard let encodedData = try? JSONEncoder().encode(sessionReplayData),
              let decodedData = try? JSONDecoder().decode(SessionReplayData.self, from: encodedData) else {
            XCTFail("Failed to encode/decode URL with special characters")
            return
        }

        XCTAssertEqual(decodedData.url, complexURL,
                      "Complex URL should be preserved through encoding/decoding")
        XCTAssertEqual(decodedData.url.absoluteString, complexURL.absoluteString,
                      "URL string representation should match")
    }
}

// MARK: - TTL + LRU Eviction Tests

// Mirrors the Android agent's OfflineStorageTest TTL/LRU coverage (NR-577137 / PR #574).
// Stale offline payloads (older than the TTL) must be deleted instead of re-uploaded forever,
// and the size cap must evict the oldest payloads rather than dropping current data.
class NRMAOfflineStorageTTLTests: XCTestCase {

    let sizeKey = "com.newrelic.offlineStorageCurrentSize"
    var storage: NRMAOfflineStorage!

    override func setUp() {
        super.setUp()
        // Unique endpoint per test run avoids cross-test file collisions.
        let endpoint = "ttl_test_\(Int(Date().timeIntervalSince1970 * 1000))"
        storage = NRMAOfflineStorage(endpoint: endpoint)
        _ = storage.clearAllOfflineFiles()
        UserDefaults.standard.set(0, forKey: sizeKey)
        UserDefaults.standard.synchronize()
        NewRelic.enableFeatures(NRMAFeatureFlags.NRFeatureFlag_OfflineStorage)
    }

    override func tearDown() {
        _ = storage.clearAllOfflineFiles()
        UserDefaults.standard.set(0, forKey: sizeKey)
        UserDefaults.standard.synchronize()
        // TTL is a process-wide setting; restore the default so other tests aren't affected.
        NRMAOfflineStorage.setOfflineStorageTTL(NRMAOfflineStorage.defaultOfflineStorageTTL())
        storage = nil
        super.tearDown()
    }

    // MARK: Helpers

    // Writes a file straight into the offline directory with a controlled byte size and
    // modification date. Production filenames are second-resolution, so persisting twice
    // within the same second collides — and busy-waiting for the next wall-clock second
    // hangs CI. Seeding files directly keeps every test deterministic and instant, while
    // still exercising the real read/evict code paths (which key off file attributes, not
    // filename format).
    @discardableResult
    private func writeOfflineFile(named name: String, bytes: Int, daysOld: Double) -> String {
        let dir = storage.offlineDirectoryPath() ?? ""
        try? FileManager.default.createDirectory(atPath: dir, withIntermediateDirectories: true)
        let path = "\(dir)/\(name)"
        FileManager.default.createFile(atPath: path, contents: Data(repeating: 0x78, count: bytes))
        let date = Date().addingTimeInterval(-daysOld * 24 * 60 * 60)
        try? FileManager.default.setAttributes([.modificationDate: date], ofItemAtPath: path)
        return path
    }

    private func exists(_ path: String) -> Bool {
        FileManager.default.fileExists(atPath: path)
    }

    // MARK: TTL configuration

    func testDefaultTTLIsSevenDays() {
        XCTAssertEqual(NRMAOfflineStorage.defaultOfflineStorageTTL(), 7 * 24 * 60 * 60,
                       "Default TTL should be 7 days in seconds")
        XCTAssertEqual(NRMAOfflineStorage.offlineStorageTTL(), NRMAOfflineStorage.defaultOfflineStorageTTL(),
                       "TTL should default to defaultOfflineStorageTTL")
    }

    func testSetGetTTL() {
        let customTTL: TimeInterval = 14 * 24 * 60 * 60
        NRMAOfflineStorage.setOfflineStorageTTL(customTTL)
        XCTAssertEqual(NRMAOfflineStorage.offlineStorageTTL(), customTTL)
    }

    // MARK: TTL expiry on read

    func testExpiredFilesAreDeletedOnRead() {
        let path = writeOfflineFile(named: "expired.txt", bytes: 32, daysOld: 8) // past the 7-day TTL

        let result = storage.getAllOfflineData(false)
        XCTAssertEqual(result?.count, 0, "Expired payloads should not be returned for upload")
        XCTAssertFalse(exists(path), "Expired file should be deleted from disk")
    }

    func testNonExpiredFilesAreReturned() {
        writeOfflineFile(named: "fresh.txt", bytes: 32, daysOld: 0)

        let result = storage.getAllOfflineData(false)
        XCTAssertEqual(result?.count, 1, "Fresh payloads should be returned for upload")
    }

    func testMixedExpiredAndValidFiles() {
        let expired = writeOfflineFile(named: "expired.txt", bytes: 32, daysOld: 8)
        let fresh = writeOfflineFile(named: "fresh.txt", bytes: 32, daysOld: 1)

        let result = storage.getAllOfflineData(false)
        XCTAssertEqual(result?.count, 1, "Only the fresh payload should be returned")
        XCTAssertFalse(exists(expired), "Expired file should be deleted")
        XCTAssertTrue(exists(fresh), "Fresh file should be retained")
    }

    // MARK: LRU eviction on persist

    func testLruEvictionEvictsOldestFile() {
        // Cap of 1 MB. Two ~400KB files already fit; persisting a third triggers eviction
        // of the oldest. Files are seeded with explicit modification dates so ordering is
        // deterministic, and the tracked size counter is set to match what they occupy.
        storage.setMaxOfflineStorageSize(1) // 1 MB
        let oldest = writeOfflineFile(named: "oldest.txt", bytes: 400_000, daysOld: 2)
        let newer = writeOfflineFile(named: "newer.txt", bytes: 400_000, daysOld: 1)
        UserDefaults.standard.set(800_000, forKey: sizeKey)

        let payload = Data(repeating: 0x78, count: 400_000)
        XCTAssertTrue(storage.persistData(toDisk: payload),
                      "New payload should be saved after evicting the oldest")
        XCTAssertFalse(exists(oldest), "Oldest file should have been evicted")
        XCTAssertTrue(exists(newer), "Newer file should be retained")
    }

    func testPersistReturnsFalseWhenEvictionCannotFreeEnoughSpace() {
        // A single payload larger than the entire cap — eviction can never make room.
        storage.setMaxOfflineStorageSize(1) // 1 MB
        let payload = Data(repeating: 0x78, count: 1_500_000)

        XCTAssertFalse(storage.persistData(toDisk: payload),
                       "Should return false when the payload exceeds the cap and eviction can't help")
    }
}

// MARK: - Mock Classes

class MockNRMAOfflineStorage: NRMAOfflineStorage {
    var persistDataCalled = false
    var persistDataCallCount = 0
    var getAllOfflineDataCalled = false
    var clearAllOfflineFilesCalled = false
    var mockDataToReturn: [Data]?
    var shouldPersistSucceed = true

    override func persistData(toDisk data: Data) -> Bool {
        persistDataCalled = true
        persistDataCallCount += 1
        return shouldPersistSucceed
    }

    override func getAllOfflineData(_ clear: Bool) -> [Data]? {
        getAllOfflineDataCalled = true
        return mockDataToReturn
    }

    override func clearAllOfflineFiles() -> Bool {
        clearAllOfflineFilesCalled = true
        return true
    }
}
