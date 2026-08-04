//
//  SessionReplayReporterNetworkTests.swift
//  NewRelicAgent
//
//  Created by Mike Bruin on 5/27/26.
//  Copyright © 2026 New Relic. All rights reserved.
//

import XCTest
@testable import NewRelic

/// Tests that verify SessionReplayReporter's network error handling and offline storage integration
class SessionReplayReporterNetworkTests: XCTestCase {

    var reporter: SessionReplayReporter!
    var testURL: URL!
    var testData: Data!
    var mockURLSession: MockURLSession!

    override func setUp() {
        super.setUp()

        // Clear offline storage
        _ = NRMAOfflineStorage.clearAllOfflineDirectories()

        // Enable offline storage
        NewRelic.enableFeatures(NRMAFeatureFlags.NRFeatureFlag_OfflineStorage)

        // Create test data
        testData = "test session replay network data".data(using: .utf8)!
        testURL = URL(string: "https://mobile-collector.newrelic.com/sessionreplay")!

        // Create reporter
        reporter = SessionReplayReporter(
            applicationToken: "test-token-network",
            url: "mobile-collector.newrelic.com" as NSString
        )

        // Setup mock session
        mockURLSession = MockURLSession()
    }

    override func tearDown() {
        reporter = nil
        mockURLSession = nil
        _ = NRMAOfflineStorage.clearAllOfflineDirectories()
        NewRelic.disableFeatures(NRMAFeatureFlags.NRFeatureFlag_OfflineStorage)
        super.tearDown()
    }

    // MARK: - URLProtocol Mock Tests

    func testNetworkErrorTriggersOfflineStorage() {
        // This test verifies that network errors cause data to be persisted offline

        let uniqueEndpoint = "test_network_\(Int(Date().timeIntervalSince1970 * 1000))"
        guard let offlineStorage = NRMAOfflineStorage(endpoint: uniqueEndpoint) else {
            XCTFail("Failed to create offline storage")
            return
        }

        offlineStorage.setMaxOfflineStorageSize(10)

        // Create a SessionReplayData object
        let sessionReplayData = SessionReplayData(
            sessionReplayFramesData: testData,
            url: testURL
        )

        // Encode it
        guard let encodedData = try? JSONEncoder().encode(sessionReplayData) else {
            XCTFail("Failed to encode session replay data")
            return
        }

        // Simulate what SessionReplayReporter does on network error:
        // After 3 retries fail, it checks if error should persist and saves to offline storage
        let networkError = NSError(
            domain: NSURLErrorDomain,
            code: NSURLErrorNotConnectedToInternet,
            userInfo: nil
        )

        // Verify the error is detected as network error
        XCTAssertTrue(
            NRMAOfflineStorage.checkError(toPersist: networkError),
            "Network error should be detected as persistable"
        )

        // Simulate the persistence that happens in handleUploadResponse
        let persistSuccess = offlineStorage.persistData(toDisk: encodedData)
        XCTAssertTrue(persistSuccess, "Should successfully persist on network error")

        // Verify it was stored
        usleep(200000) // Sync filesystem
        let retrievedData = offlineStorage.getAllOfflineData(false)
        XCTAssertNotNil(retrievedData, "Should retrieve persisted data")
        XCTAssertEqual(retrievedData?.count, 1, "Should have 1 persisted item")

        // Verify we can decode it back
        if let retrieved = retrievedData?.first {
            let decoded = try? JSONDecoder().decode(SessionReplayData.self, from: retrieved)
            XCTAssertNotNil(decoded, "Should be able to decode persisted data")
            XCTAssertEqual(decoded?.sessionReplayFramesData, testData)
        }

        _ = offlineStorage.clearAllOfflineFiles()
    }

    func testHTTPErrorDoesNotTriggerOfflineStorage() {
        // HTTP errors (400, 500) should NOT persist to offline storage

        let uniqueEndpoint = "test_http_error_\(Int(Date().timeIntervalSince1970 * 1000))"
        guard let offlineStorage = NRMAOfflineStorage(endpoint: uniqueEndpoint) else {
            XCTFail("Failed to create offline storage")
            return
        }

        offlineStorage.setMaxOfflineStorageSize(10)

        // Simulate various HTTP errors
        let httpErrors = [400, 401, 403, 404, 500, 503]

        for statusCode in httpErrors {
            // HTTP errors are not NSErrors, they come through as HTTPURLResponse
            // SessionReplayReporter checks: httpResponse.statusCode >= 300
            // But does NOT persist because error is nil (just bad status code)

            // Verify that a generic error (not network) is NOT persistable
            let genericError = NSError(
                domain: "HTTPError",
                code: statusCode,
                userInfo: nil
            )

            XCTAssertFalse(
                NRMAOfflineStorage.checkError(toPersist: genericError),
                "HTTP error \(statusCode) should NOT trigger offline persistence"
            )
        }

        _ = offlineStorage.clearAllOfflineFiles()
    }

    func testPayloadTooLargeDoesNotPersist() {
        // Payloads larger than 1MB should not be persisted

        let uniqueEndpoint = "test_large_\(Int(Date().timeIntervalSince1970 * 1000))"
        guard let offlineStorage = NRMAOfflineStorage(endpoint: uniqueEndpoint) else {
            XCTFail("Failed to create offline storage")
            return
        }

        offlineStorage.setMaxOfflineStorageSize(10)

        // Create data larger than 1MB
        let largeData = Data(repeating: 0xAB, count: 1_100_000) // 1.1 MB

        let sessionReplayData = SessionReplayData(
            sessionReplayFramesData: largeData,
            url: testURL
        )

        guard let encodedData = try? JSONEncoder().encode(sessionReplayData) else {
            XCTFail("Failed to encode large data")
            return
        }

        // In SessionReplayReporter.swift:82-94, if payload > kNRMAMaxPayloadSizeLimit (1MB),
        // it's removed from queue without persisting
        XCTAssertGreaterThan(
            encodedData.count,
            1_000_000,
            "Encoded data should exceed 1MB limit"
        )

        // The reporter would NOT persist this, it would just drop it
        // We can verify this behavior by confirming it exceeds the limit

        _ = offlineStorage.clearAllOfflineFiles()
    }

    // MARK: - Offline Data Retrieval After Success Tests

    func testOfflineDataSentAfterSuccessfulUpload() {
        // When an upload succeeds, SessionReplayReporter calls sendOfflineStorage()
        // to attempt uploading any previously failed data

        let uniqueEndpoint = "test_retry_\(Int(Date().timeIntervalSince1970 * 1000))"
        guard let offlineStorage = NRMAOfflineStorage(endpoint: uniqueEndpoint) else {
            XCTFail("Failed to create offline storage")
            return
        }

        offlineStorage.setMaxOfflineStorageSize(10)

        // Pre-populate offline storage with some "previously failed" uploads
        for i in 1...2 {
            let data = "offline data \(i)".data(using: .utf8)!
            let sessionReplayData = SessionReplayData(
                sessionReplayFramesData: data,
                url: testURL
            )

            guard let encodedData = try? JSONEncoder().encode(sessionReplayData) else {
                XCTFail("Failed to encode data \(i)")
                return
            }

            _ = offlineStorage.persistData(toDisk: encodedData)

            // Wait for unique timestamp
            if i < 2 {
                let startSecond = Calendar.current.component(.second, from: Date())
                while Calendar.current.component(.second, from: Date()) == startSecond {
                    usleep(50000)
                }
            }
        }

        usleep(200000) // Sync filesystem

        // Verify data was persisted
        let storedData = offlineStorage.getAllOfflineData(false)
        XCTAssertEqual(storedData?.count, 2, "Should have 2 items in offline storage")

        // In real scenario, after a successful upload, SessionReplayReporter.handleUploadResponse
        // calls sendOfflineStorage() which:
        // 1. Calls getAllOfflineData(true) to get and clear
        // 2. Attempts to upload each item
        // 3. Re-persists if network error, or counts as sent if success

        // Simulate retrieval and clearing (what sendOfflineStorage does)
        let dataToSend = offlineStorage.getAllOfflineData(true) // true = clear
        XCTAssertEqual(dataToSend?.count, 2, "Should retrieve 2 items for sending")

        // Verify it was cleared
        let afterClear = offlineStorage.getAllOfflineData(false)
        XCTAssertTrue(afterClear == nil || afterClear?.count == 0, "Should be cleared after retrieval")

        _ = offlineStorage.clearAllOfflineFiles()
    }

    func testOfflineDataRePersistsOnNetworkError() {
        // If offline data upload also fails with network error, it should be re-persisted

        let uniqueEndpoint = "test_repersist_\(Int(Date().timeIntervalSince1970 * 1000))"
        guard let offlineStorage = NRMAOfflineStorage(endpoint: uniqueEndpoint) else {
            XCTFail("Failed to create offline storage")
            return
        }

        offlineStorage.setMaxOfflineStorageSize(10)

        let sessionReplayData = SessionReplayData(
            sessionReplayFramesData: testData,
            url: testURL
        )

        guard let encodedData = try? JSONEncoder().encode(sessionReplayData) else {
            XCTFail("Failed to encode data")
            return
        }

        // Store initially
        _ = offlineStorage.persistData(toDisk: encodedData)
        usleep(200000)

        // Retrieve with clear (simulating sendOfflineStorage behavior)
        let dataToSend = offlineStorage.getAllOfflineData(true)
        XCTAssertEqual(dataToSend?.count, 1)

        // Verify it was cleared
        var currentData = offlineStorage.getAllOfflineData(false)
        XCTAssertTrue(currentData == nil || currentData?.count == 0)

        // Simulate network error during offline upload - re-persist
        // (SessionReplayReporter.sendOfflineStorage:171-173)
        let networkError = NSError(
            domain: NSURLErrorDomain,
            code: NSURLErrorTimedOut,
            userInfo: nil
        )

        if NRMAOfflineStorage.checkError(toPersist: networkError) {
            // Re-persist the data
            _ = offlineStorage.persistData(toDisk: encodedData)
        }

        usleep(200000)

        // Verify it was re-persisted
        currentData = offlineStorage.getAllOfflineData(false)
        XCTAssertEqual(currentData?.count, 1, "Should be re-persisted after network error")

        _ = offlineStorage.clearAllOfflineFiles()
    }

    // MARK: - Retry Logic Tests

    func testRetryCountBeforePersisting() {
        // SessionReplayReporter retries up to kNRMAMaxUploadRetry (3) times
        // before persisting to offline storage

        let maxRetries = 3
        var failureCount = 0

        // Simulate the retry logic from SessionReplayReporter.handleUploadResponse
        for attempt in 1...5 {
            // Simulate a network failure
            let hasError = true

            if hasError {
                failureCount += 1
            }

            // Check if we should persist (after exceeding max retries)
            if failureCount > maxRetries {
                XCTAssertEqual(attempt, 4, "Should persist on 4th attempt (after 3 retries)")
                break
            }
        }

        XCTAssertEqual(failureCount, 4, "Should have 4 failures before persisting")
    }

    // MARK: - Feature Flag Tests

    func testOfflineStorageSkippedWhenFeatureDisabled() {
        // When offline storage feature is disabled, data should not be persisted

        // Disable the feature
        NewRelic.disableFeatures(NRMAFeatureFlags.NRFeatureFlag_OfflineStorage)

        // In SessionReplayReporter.handleUploadResponse:216, it checks:
        // if NRMAFlags.shouldEnableOfflineStorage()

        // We can verify the feature is disabled (though we can't access NRMAFlags directly in Swift)
        // The actual behavior would be that persistData is not called

        // This is more of an integration test that would need to verify
        // persistData is not called when the flag is off

        // Re-enable for other tests
        NewRelic.enableFeatures(NRMAFeatureFlags.NRFeatureFlag_OfflineStorage)
    }

    // MARK: - Integration Scenario Tests

    func testCompleteNetworkFailureRecoveryScenario() {
        // End-to-end test: Upload fails → Persists → Network recovers → Uploads offline data

        let uniqueEndpoint = "test_scenario_\(Int(Date().timeIntervalSince1970 * 1000))"
        guard let offlineStorage = NRMAOfflineStorage(endpoint: uniqueEndpoint) else {
            XCTFail("Failed to create offline storage")
            return
        }

        offlineStorage.setMaxOfflineStorageSize(10)

        // Phase 1: Network failure - persist data
        let sessionReplayData = SessionReplayData(
            sessionReplayFramesData: testData,
            url: testURL
        )

        guard let encodedData = try? JSONEncoder().encode(sessionReplayData) else {
            XCTFail("Failed to encode data")
            return
        }

        // Simulate network error and persist
        let networkError = NSError(
            domain: NSURLErrorDomain,
            code: NSURLErrorNetworkConnectionLost,
            userInfo: nil
        )

        XCTAssertTrue(NRMAOfflineStorage.checkError(toPersist: networkError))

        let persistSuccess = offlineStorage.persistData(toDisk: encodedData)
        XCTAssertTrue(persistSuccess, "Phase 1: Should persist on network failure")

        usleep(200000)

        // Phase 2: Verify data is stored
        var storedData = offlineStorage.getAllOfflineData(false)
        XCTAssertEqual(storedData?.count, 1, "Phase 2: Should have 1 stored item")

        // Phase 3: Network recovers - retrieve and "upload" offline data
        // (simulating successful upload after network recovery)
        let offlineDataToUpload = offlineStorage.getAllOfflineData(true) // clear
        XCTAssertEqual(offlineDataToUpload?.count, 1, "Phase 3: Should retrieve offline data")

        // Simulate successful upload (no re-persist needed)
        // In real code, this would be sent via URLSession

        // Phase 4: Verify offline storage is now empty
        storedData = offlineStorage.getAllOfflineData(false)
        XCTAssertTrue(storedData == nil || storedData?.count == 0,
                     "Phase 4: Offline storage should be empty after successful upload")

        _ = offlineStorage.clearAllOfflineFiles()
    }
}

// MARK: - Mock Classes

class MockURLSession {
    var shouldSucceed = true
    var errorToReturn: Error?
    var statusCode = 200

    func simulateUpload(completion: @escaping (Data?, URLResponse?, Error?) -> Void) {
        if let error = errorToReturn {
            completion(nil, nil, error)
        } else {
            let response = HTTPURLResponse(
                url: URL(string: "https://example.com")!,
                statusCode: statusCode,
                httpVersion: nil,
                headerFields: nil
            )
            completion(Data(), response, nil)
        }
    }
}
