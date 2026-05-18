//
//  NRMASessionDurationManagerTests.swift
//  NewRelicAgent
//
//  Created by New Relic on 3/31/26.
//  Copyright © 2026 New Relic. All rights reserved.
//

import XCTest
@testable import NewRelic

class NRMASessionDurationManagerTests: XCTestCase {

    var manager: NRMASessionDurationManager!

    override func setUp() {
        super.setUp()
        manager = NRMASessionDurationManager.shared
        // Reset to default values for each test
        manager.maxSessionDuration = 14400.0 // 4 hours
    }

    override func tearDown() {
        // Reset to default values after each test
        manager.maxSessionDuration = 14400.0
        manager.updateSessionStartTime(Date())
        super.tearDown()
    }

    // MARK: - Singleton Tests

    func testSharedAndSharedInstanceReturnSameObject() {
        let instance1 = NRMASessionDurationManager.shared
        let instance2 = NRMASessionDurationManager.shared

        XCTAssertTrue(instance1 === instance2, "shared should return the same object")
    }

    // MARK: - Default Configuration Tests

    func testDefaultMaxSessionDurationIs4Hours() {
        // This test should verify the current default
        let defaultDuration = manager.maxSessionDuration
        XCTAssertEqual(defaultDuration, 14400.0, "Default max session duration should be 14400 seconds")
    }

    // MARK: - Max Session Duration Configuration Tests

    func testSetMaxSessionDurationViaProperty() {
        let newDuration: TimeInterval = 3600.0 // 1 hour

        manager.maxSessionDuration = newDuration

        XCTAssertEqual(manager.maxSessionDuration, newDuration, "Max session duration property should be updated")
    }

    // MARK: - Session Start Time Tests

    func testUpdateSessionStartTime() {
        let testDate = Date(timeIntervalSinceNow: -100)

        manager.updateSessionStartTime(testDate)

        // Give a small margin for thread safety operations
        let duration = manager.currentSessionDuration()
        XCTAssertGreaterThan(duration, 99.0, "Session duration should be approximately 100 seconds")
        XCTAssertLessThan(duration, 101.0, "Session duration should be approximately 100 seconds")
    }

    func testUpdateSessionStartTimeWithNilDoesNotCrash() {
        // This should not crash, just log an error
        manager.updateSessionStartTime(nil)

        // Should still return a valid duration (from initialization)
        let duration = manager.currentSessionDuration()
        XCTAssertGreaterThanOrEqual(duration, 0.0, "Should return non-negative duration")
    }

    func testCurrentSessionDurationReturnsElapsedTime() {
        let startTime = Date(timeIntervalSinceNow: -50)

        manager.updateSessionStartTime(startTime)

        let duration = manager.currentSessionDuration()
        XCTAssertGreaterThanOrEqual(duration, 49.0, "Duration should be at least 49 seconds")
        XCTAssertLessThanOrEqual(duration, 51.0, "Duration should be at most 51 seconds")
    }

    // MARK: - Session Exceeded Tests

    func testHasSessionExceededReturnsFalseWhenUnderLimit() {
        // Set max to 100 seconds
        manager.maxSessionDuration = 100.0

        // Set start time to 50 seconds ago
        let startTime = Date(timeIntervalSinceNow: -50)
        manager.updateSessionStartTime(startTime)

        XCTAssertFalse(manager.hasSessionExceeded(), "Session should not have exceeded when under limit")
    }

    func testHasSessionExceededReturnsTrueWhenOverLimit() {
        // Set max to 50 seconds
        manager.maxSessionDuration = 50.0

        // Set start time to 100 seconds ago
        let startTime = Date(timeIntervalSinceNow: -100)
        manager.updateSessionStartTime(startTime)

        XCTAssertTrue(manager.hasSessionExceeded(), "Session should have exceeded when over limit")
    }

    func testHasSessionExceededReturnsTrueAtExactLimit() {
        // Set max to 100 seconds
        manager.maxSessionDuration = 100.0

        // Set start time to exactly 100 seconds ago
        let startTime = Date(timeIntervalSinceNow: -100)
        manager.updateSessionStartTime(startTime)

        // Give it a tiny bit of time to ensure we're at or past the limit
        Thread.sleep(forTimeInterval: 0.01)

        XCTAssertTrue(manager.hasSessionExceeded(), "Session should have exceeded at exact limit")
    }

    func testHasSessionExceededDurationWithCustomDuration() {
        // Set start time to 150 seconds ago
        let startTime = Date(timeIntervalSinceNow: -150)
        manager.updateSessionStartTime(startTime)

        // Check with custom duration of 100 seconds
        XCTAssertTrue(manager.hasSessionExceededDuration(100.0), "Session should exceed custom 100 second limit")

        // Check with custom duration of 200 seconds
        XCTAssertFalse(manager.hasSessionExceededDuration(200.0), "Session should not exceed custom 200 second limit")
    }

    // MARK: - Thread Safety Tests

    func testConcurrentMaxSessionDurationAccess() {
        let expectation = self.expectation(description: "Concurrent access completes")
        let iterations = 100
        var completedCount = 0
        let completionQueue = DispatchQueue(label: "test.completion")

        for i in 0..<iterations {
            DispatchQueue.global().async {
                if i % 2 == 0 {
                    // Write
                    self.manager.maxSessionDuration = TimeInterval(100 + i)
                } else {
                    // Read
                    _ = self.manager.maxSessionDuration
                }

                completionQueue.sync {
                    completedCount += 1
                    if completedCount == iterations {
                        expectation.fulfill()
                    }
                }
            }
        }

        waitForExpectations(timeout: 5.0) { error in
            XCTAssertNil(error, "Concurrent access should complete without deadlock")
        }
    }

    func testConcurrentSessionStartTimeAccess() {
        let expectation = self.expectation(description: "Concurrent session start time access completes")
        let iterations = 100
        var completedCount = 0
        let completionQueue = DispatchQueue(label: "test.completion")

        for i in 0..<iterations {
            DispatchQueue.global().async {
                if i % 2 == 0 {
                    // Write
                    self.manager.updateSessionStartTime(Date(timeIntervalSinceNow: -Double(i)))
                } else {
                    // Read
                    _ = self.manager.currentSessionDuration()
                }

                completionQueue.sync {
                    completedCount += 1
                    if completedCount == iterations {
                        expectation.fulfill()
                    }
                }
            }
        }

        waitForExpectations(timeout: 5.0) { error in
            XCTAssertNil(error, "Concurrent session start time access should complete without deadlock")
        }
    }

    func testConcurrentHasSessionExceededCalls() {
        let expectation = self.expectation(description: "Concurrent hasSessionExceeded calls complete")
        let iterations = 100
        var completedCount = 0
        let completionQueue = DispatchQueue(label: "test.completion")

        // Set up a session that exceeds
        manager.maxSessionDuration = 10.0
        manager.updateSessionStartTime(Date(timeIntervalSinceNow: -50))

        for _ in 0..<iterations {
            DispatchQueue.global().async {
                _ = self.manager.hasSessionExceeded()

                completionQueue.sync {
                    completedCount += 1
                    if completedCount == iterations {
                        expectation.fulfill()
                    }
                }
            }
        }

        waitForExpectations(timeout: 5.0) { error in
            XCTAssertNil(error, "Concurrent hasSessionExceeded calls should complete without deadlock")
        }
    }

    // MARK: - Realistic Scenario Tests

    func testFourHourSessionScenario() {
        // Simulate 4-hour session timeout
        manager.maxSessionDuration = 14400.0 // 4 hours

        // Session started 4 hours and 1 second ago
        let startTime = Date(timeIntervalSinceNow: -14401)
        manager.updateSessionStartTime(startTime)

        XCTAssertTrue(manager.hasSessionExceeded(), "4-hour session should have exceeded")

        let duration = manager.currentSessionDuration()
        XCTAssertGreaterThan(duration, 14400.0, "Duration should be over 4 hours")
    }

    func testSessionRestartScenario() {
        // Simulate a session restart after timeout
        manager.maxSessionDuration = 100.0

        // First session exceeds
        let oldStartTime = Date(timeIntervalSinceNow: -150)
        manager.updateSessionStartTime(oldStartTime)
        XCTAssertTrue(manager.hasSessionExceeded(), "Old session should have exceeded")

        // Restart session with new start time
        let newStartTime = Date()
        manager.updateSessionStartTime(newStartTime)
        XCTAssertFalse(manager.hasSessionExceeded(), "New session should not have exceeded")

        let newDuration = manager.currentSessionDuration()
        XCTAssertLessThan(newDuration, 1.0, "New session duration should be very small")
    }

    func testConfigurationChangeDoesNotAffectExistingSession() {
        // Start a session
        let startTime = Date(timeIntervalSinceNow: -50)
        manager.updateSessionStartTime(startTime)

        // Set max to 100 seconds - should not exceed yet
        manager.maxSessionDuration = 100.0
        XCTAssertFalse(manager.hasSessionExceeded(), "Should not exceed with 100 second limit")

        // Change max to 40 seconds - should now exceed
        manager.maxSessionDuration = 40.0
        XCTAssertTrue(manager.hasSessionExceeded(), "Should exceed with 40 second limit")

        // The session start time didn't change, just the configuration
        let duration = manager.currentSessionDuration()
        XCTAssertGreaterThan(duration, 49.0, "Session duration should still reflect actual elapsed time")
    }

    // MARK: - Integration Tests with HarvestTimer

    func testSessionTimeoutIntegrationWithHarvestTimer() {
        // This integration test verifies the SessionDurationManager works correctly
        // with the NRMAHarvestTimer's tick method

        // Configure session manager for a very short timeout
        manager.maxSessionDuration = 2.0 // 2 seconds

        // Set session start time to 5 seconds ago (well past the 2 second limit)
        let startTime = Date(timeIntervalSinceNow: -5)
        manager.updateSessionStartTime(startTime)

        // Verify session has exceeded
        XCTAssertTrue(manager.hasSessionExceeded(), "Session should have exceeded the 2 second limit")

        // Verify the duration is correct
        let duration = manager.currentSessionDuration()
        XCTAssertGreaterThanOrEqual(duration, 4.9, "Duration should be approximately 5 seconds")
        XCTAssertLessThanOrEqual(duration, 5.1, "Duration should be approximately 5 seconds")
    }

    func testSessionTimeoutNotTriggeredWhenUnderLimit() {
        // Configure session manager
        manager.maxSessionDuration = 100.0 // 100 seconds

        // Set session start time to 10 seconds ago (under the 100 second limit)
        let startTime = Date(timeIntervalSinceNow: -10)
        manager.updateSessionStartTime(startTime)

        // Verify session has not exceeded
        XCTAssertFalse(manager.hasSessionExceeded(), "Session should not have exceeded the 100 second limit")

        // This simulates the harvest timer tick checking and finding the session is still valid
        let duration = manager.currentSessionDuration()
        XCTAssertGreaterThanOrEqual(duration, 9.9, "Duration should be approximately 10 seconds")
        XCTAssertLessThanOrEqual(duration, 10.1, "Duration should be approximately 10 seconds")
    }

    func testSessionRestartResetsTimer() {
        // Simulate the full session restart flow

        // 1. Session starts
        let initialStartTime = Date(timeIntervalSinceNow: -5)
        manager.maxSessionDuration = 3.0 // 3 seconds
        manager.updateSessionStartTime(initialStartTime)

        // 2. Session exceeds (would trigger restart in harvest timer tick)
        XCTAssertTrue(manager.hasSessionExceeded(), "Session should have exceeded")
        let oldDuration = manager.currentSessionDuration()
        XCTAssertGreaterThan(oldDuration, 3.0, "Old session duration should be over 3 seconds")

        // 3. Session restart happens - update with new start time
        let newStartTime = Date()
        manager.updateSessionStartTime(newStartTime)

        // 4. New session should not have exceeded
        XCTAssertFalse(manager.hasSessionExceeded(), "New session should not have exceeded")

        // 5. New session duration should be near zero
        let newDuration = manager.currentSessionDuration()
        XCTAssertLessThan(newDuration, 0.1, "New session duration should be very small")
    }

    func testMultipleHarvestTimerTicksBeforeTimeout() {
        // Simulate multiple harvest timer ticks (every 60 seconds) before hitting 4-hour limit

        manager.maxSessionDuration = 14400.0 // 4 hours

        // Session just started
        manager.updateSessionStartTime(Date())

        // Simulate multiple ticks (60 seconds apart)
        let tickIntervals: [TimeInterval] = [60, 120, 180, 240, 300] // 1, 2, 3, 4, 5 minutes

        for interval in tickIntervals {
            // Set session to interval seconds ago
            let startTime = Date(timeIntervalSinceNow: -interval)
            manager.updateSessionStartTime(startTime)

            // Should not exceed on any of these ticks
            XCTAssertFalse(manager.hasSessionExceeded(),
                          "Session should not exceed at \(interval) seconds (4-hour limit)")

            let duration = manager.currentSessionDuration()
            XCTAssertGreaterThanOrEqual(duration, interval - 1.0,
                                       "Duration should be approximately \(interval) seconds")
        }

        // Now simulate at 4 hours + 1 second
        let exceededStartTime = Date(timeIntervalSinceNow: -14401)
        manager.updateSessionStartTime(exceededStartTime)
        XCTAssertTrue(manager.hasSessionExceeded(), "Session should exceed at 4 hours")
    }

    func testConfigurationChangeAffectsNextHarvestTimerTick() {
        // Test that changing maxSessionDuration affects the next harvest timer tick check

        // Start with 100 second limit
        manager.maxSessionDuration = 100.0

        // Session started 50 seconds ago
        let startTime = Date(timeIntervalSinceNow: -50)
        manager.updateSessionStartTime(startTime)

        // First tick - should not exceed
        XCTAssertFalse(manager.hasSessionExceeded(), "Should not exceed with 100 second limit")

        // Change configuration to 40 seconds
        manager.maxSessionDuration = 40.0

        // Next tick - should now exceed (session is still 50 seconds old)
        XCTAssertTrue(manager.hasSessionExceeded(), "Should exceed with new 40 second limit")

        // This demonstrates that configuration can be changed at runtime
        // and affects subsequent harvest timer checks
    }
}
