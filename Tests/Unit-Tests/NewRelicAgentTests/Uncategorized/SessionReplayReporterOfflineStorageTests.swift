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
