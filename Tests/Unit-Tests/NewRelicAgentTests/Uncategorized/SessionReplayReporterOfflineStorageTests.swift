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

    // Files use second-resolution timestamps (yyyy-MM-dd-HH-mm-ss). Wait for a new second
    // so consecutive persists produce distinct files instead of overwriting each other.
    private func waitForNewSecond() {
        let startSecond = Calendar.current.component(.second, from: Date())
        while Calendar.current.component(.second, from: Date()) == startSecond {
            usleep(50_000)
        }
        usleep(50_000)
    }

    // Returns this endpoint's offline files sorted oldest-modified first.
    private func offlineFilesSortedByDate() -> [String] {
        guard let dir = storage.offlineDirectoryPath() else { return [] }
        let names = (try? FileManager.default.contentsOfDirectory(atPath: dir)) ?? []
        let paths = names.map { "\(dir)/\($0)" }
        return paths.sorted { lhs, rhs in
            let a = modificationDate(ofPath: lhs)
            let b = modificationDate(ofPath: rhs)
            return a < b
        }
    }

    private func modificationDate(ofPath path: String) -> Date {
        let attrs = try? FileManager.default.attributesOfItem(atPath: path)
        return (attrs?[.modificationDate] as? Date) ?? .distantPast
    }

    private func backdateFile(atPath path: String, byDays days: Double) {
        let oldDate = Date().addingTimeInterval(-days * 24 * 60 * 60)
        try? FileManager.default.setAttributes([.modificationDate: oldDate], ofItemAtPath: path)
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
        let data = "{\"expired\":\"data\"}".data(using: .utf8)!
        XCTAssertTrue(storage.persistData(toDisk: data))

        let files = offlineFilesSortedByDate()
        XCTAssertEqual(files.count, 1)
        backdateFile(atPath: files[0], byDays: 8) // past the 7-day TTL

        let result = storage.getAllOfflineData(false)
        XCTAssertEqual(result?.count, 0, "Expired payloads should not be returned for upload")
        XCTAssertFalse(FileManager.default.fileExists(atPath: files[0]),
                       "Expired file should be deleted from disk")
    }

    func testNonExpiredFilesAreReturned() {
        let data = "{\"fresh\":\"data\"}".data(using: .utf8)!
        XCTAssertTrue(storage.persistData(toDisk: data))

        let result = storage.getAllOfflineData(false)
        XCTAssertEqual(result?.count, 1, "Fresh payloads should be returned for upload")
    }

    func testMixedExpiredAndValidFiles() {
        XCTAssertTrue(storage.persistData(toDisk: "{\"expired\":\"data\"}".data(using: .utf8)!))
        waitForNewSecond()
        XCTAssertTrue(storage.persistData(toDisk: "{\"fresh\":\"data\"}".data(using: .utf8)!))

        let files = offlineFilesSortedByDate()
        XCTAssertEqual(files.count, 2)
        backdateFile(atPath: files[0], byDays: 8) // expire the oldest

        let result = storage.getAllOfflineData(false)
        XCTAssertEqual(result?.count, 1, "Only the fresh payload should be returned")
        XCTAssertFalse(FileManager.default.fileExists(atPath: files[0]), "Expired file should be deleted")
        XCTAssertTrue(FileManager.default.fileExists(atPath: files[1]), "Fresh file should be retained")
    }

    // MARK: LRU eviction on persist

    func testLruEvictionEvictsOldestFile() {
        // Cap of 1 MB. Each ~400KB payload: two fit, the third triggers eviction of the oldest.
        storage.setMaxOfflineStorageSize(1)
        let payload = String(repeating: "x", count: 400_000).data(using: .utf8)!

        XCTAssertTrue(storage.persistData(toDisk: payload))
        waitForNewSecond()
        XCTAssertTrue(storage.persistData(toDisk: payload))

        let filesBefore = offlineFilesSortedByDate()
        XCTAssertEqual(filesBefore.count, 2)
        let oldest = filesBefore[0]

        waitForNewSecond()
        XCTAssertTrue(storage.persistData(toDisk: payload),
                      "New payload should be saved after evicting the oldest")
        XCTAssertFalse(FileManager.default.fileExists(atPath: oldest),
                       "Oldest file should have been evicted")
    }

    func testPersistReturnsFalseWhenEvictionCannotFreeEnoughSpace() {
        // A single payload larger than the entire cap — eviction can never make room.
        storage.setMaxOfflineStorageSize(1) // 1 MB
        let payload = String(repeating: "x", count: 1_500_000).data(using: .utf8)!

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
