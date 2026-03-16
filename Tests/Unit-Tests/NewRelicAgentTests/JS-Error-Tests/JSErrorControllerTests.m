//
//  JSErrorControllerTests.m
//  NewRelicAgentTests
//
//  Copyright © 2026 New Relic. All rights reserved.
//

#import <XCTest/XCTest.h>
#import "NRMAAnalytics.h"
#import "NRMAAgentConfiguration.h"
#import "NRMAAppToken.h"
#import "NRMAAttributeValidator.h"
#import "NewRelicInternalUtils.h"

// Import Swift classes from main NewRelic module (same as NewRelicAgentInternal.m does)
#import <NewRelic/NewRelic-Swift.h>

@interface JSErrorControllerTests : XCTestCase
@end

@implementation JSErrorControllerTests

// MARK: - Initialization Tests

- (void)testInitWithValidParameters {
    NRMAAnalytics* analytics = [[NRMAAnalytics alloc] initWithSessionStartTimeMS:0];
    NRMAAgentConfiguration* agentConfig = [[NRMAAgentConfiguration alloc]
        initWithAppToken:[[NRMAAppToken alloc] initWithApplicationToken:@"test-token-12345"]
        collectorAddress:nil
        crashAddress:nil];
    agentConfig.sessionIdentifier = @"test-session-id";

    JSErrorController* controller = [[JSErrorController alloc]
        initWithAnalyticsController:analytics
        sessionStartTime:[NSDate new]
        agentConfiguration:agentConfig
        platform:[NewRelicInternalUtils osName]
        sessionId:@"test-session-id"
        attributeValidator:[[NRMAAttributeValidator alloc] init]];

    XCTAssertNotNil(controller, @"Controller should initialize with valid parameters");
}

- (void)testInitWithNilParameters {
    // Test nil analytics
    JSErrorController* controller = [[JSErrorController alloc]
        initWithAnalyticsController:nil
        sessionStartTime:[NSDate new]
        agentConfiguration:nil
        platform:nil
        sessionId:nil
        attributeValidator:nil];

    XCTAssertNil(controller, @"Controller should return nil with nil parameters");
}

- (void)testInitWithNilAppToken {
    NRMAAnalytics* analytics = [[NRMAAnalytics alloc] initWithSessionStartTimeMS:0];
    NRMAAgentConfiguration* agentConfig = [[NRMAAgentConfiguration alloc]
        initWithAppToken:nil
        collectorAddress:nil
        crashAddress:nil];

    JSErrorController* controller = [[JSErrorController alloc]
        initWithAnalyticsController:analytics
        sessionStartTime:[NSDate new]
        agentConfiguration:agentConfig
        platform:@"iOS"
        sessionId:@"session-id"
        attributeValidator:[[NRMAAttributeValidator alloc] init]];

    XCTAssertNil(controller, @"Controller should return nil with nil app token");
}

- (void)testInitWithEmptyPlatform {
    NRMAAnalytics* analytics = [[NRMAAnalytics alloc] initWithSessionStartTimeMS:0];
    NRMAAgentConfiguration* agentConfig = [[NRMAAgentConfiguration alloc]
        initWithAppToken:[[NRMAAppToken alloc] initWithApplicationToken:@"test-token"]
        collectorAddress:nil
        crashAddress:nil];

    JSErrorController* controller = [[JSErrorController alloc]
        initWithAnalyticsController:analytics
        sessionStartTime:[NSDate new]
        agentConfiguration:agentConfig
        platform:@""  // Empty platform
        sessionId:@"session-id"
        attributeValidator:[[NRMAAttributeValidator alloc] init]];

    XCTAssertNil(controller, @"Controller should return nil with empty platform");
}

- (void)testInitWithEmptySessionId {
    NRMAAnalytics* analytics = [[NRMAAnalytics alloc] initWithSessionStartTimeMS:0];
    NRMAAgentConfiguration* agentConfig = [[NRMAAgentConfiguration alloc]
        initWithAppToken:[[NRMAAppToken alloc] initWithApplicationToken:@"test-token"]
        collectorAddress:nil
        crashAddress:nil];

    JSErrorController* controller = [[JSErrorController alloc]
        initWithAnalyticsController:analytics
        sessionStartTime:[NSDate new]
        agentConfiguration:agentConfig
        platform:@"iOS"
        sessionId:@""  // Empty session ID
        attributeValidator:[[NRMAAttributeValidator alloc] init]];

    XCTAssertNil(controller, @"Controller should return nil with empty session ID");
}

// MARK: - Error Recording Tests

- (void)testRecordJSErrorWithValidParameters {
    JSErrorController* controller = [self createTestController];
    XCTAssertNotNil(controller);

    XCTAssertNoThrow([controller recordJSError:@"TypeError"
                                       message:@"Cannot read property 'foo' of undefined"
                                    stackTrace:@"at testFunction (app.js:123:45)"
                                       isFatal:NO
                          additionalAttributes:@{@"screen": @"HomeScreen"}]);

    // Verify error was recorded
    NSArray* errors = [controller getErrorQueueForTesting];
    XCTAssertEqual(errors.count, 1, @"Should have recorded one error");

    NSDictionary* error = errors.firstObject;
    XCTAssertEqualObjects(error[@"name"], @"TypeError");
    XCTAssertEqualObjects(error[@"message"], @"Cannot read property 'foo' of undefined");
    XCTAssertEqual([error[@"isFatal"] boolValue], NO);
}

- (void)testRecordJSErrorWithNilAdditionalAttributes {
    JSErrorController* controller = [self createTestController];
    XCTAssertNotNil(controller);

    XCTAssertNoThrow([controller recordJSError:@"ReferenceError"
                                       message:@"x is not defined"
                                    stackTrace:@"at <anonymous>:1:1"
                                       isFatal:NO
                          additionalAttributes:nil]);

    NSArray* errors = [controller getErrorQueueForTesting];
    XCTAssertEqual(errors.count, 1);
}

- (void)testRecordMultipleErrors {
    JSErrorController* controller = [self createTestController];
    XCTAssertNotNil(controller);

    for (int i = 0; i < 5; i++) {
        [controller recordJSError:[NSString stringWithFormat:@"Error%d", i]
                          message:[NSString stringWithFormat:@"Message %d", i]
                       stackTrace:[NSString stringWithFormat:@"Stack %d", i]
                          isFatal:NO
             additionalAttributes:@{@"index": @(i)}];
    }

    NSArray* errors = [controller getErrorQueueForTesting];
    XCTAssertEqual(errors.count, 5, @"Should have recorded all 5 errors");
}

// MARK: - Collision Handling Tests

- (void)testNameParameterTakesPrecedenceOverAdditionalAttributes {
    JSErrorController* controller = [self createTestController];
    XCTAssertNotNil(controller);

    NSString* explicitName = @"ExplicitErrorName";
    NSString* attributeName = @"AttributeErrorName";

    NSDictionary* additionalAttributes = @{
        @"name": attributeName,
        @"customKey": @"customValue"
    };

    [controller recordJSError:explicitName
                      message:@"Test message"
                   stackTrace:@"test stack"
                      isFatal:NO
         additionalAttributes:additionalAttributes];

    NSArray* errors = [controller getErrorQueueForTesting];
    XCTAssertEqual(errors.count, 1);

    NSDictionary* error = errors.firstObject;

    // Verify explicit name is at top level
    XCTAssertEqualObjects(error[@"name"], explicitName,
                         @"Explicit name parameter must take precedence");

    // Verify attribute name is in attributes sub-dictionary
    NSDictionary* attributes = error[@"attributes"];
    XCTAssertNotNil(attributes, @"Attributes should be present");
    XCTAssertEqualObjects(attributes[@"name"], attributeName,
                         @"Attribute name should be in attributes sub-dictionary");

    // Verify no collision - they are in different places
    XCTAssertNotEqualObjects(error[@"name"], attributeName,
                            @"Top-level name should NOT be overridden");
}

- (void)testMessageParameterTakesPrecedenceOverAdditionalAttributes {
    JSErrorController* controller = [self createTestController];
    XCTAssertNotNil(controller);

    NSString* explicitMessage = @"Explicit error message";
    NSString* attributeMessage = @"Attribute error message";

    NSDictionary* additionalAttributes = @{
        @"message": attributeMessage,
        @"customKey": @"customValue"
    };

    [controller recordJSError:@"TestError"
                      message:explicitMessage
                   stackTrace:@"test stack"
                      isFatal:NO
         additionalAttributes:additionalAttributes];

    NSArray* errors = [controller getErrorQueueForTesting];
    NSDictionary* error = errors.firstObject;

    // Verify explicit message is at top level
    XCTAssertEqualObjects(error[@"message"], explicitMessage,
                         @"Explicit message parameter must take precedence");

    // Verify attribute message is in attributes sub-dictionary
    NSDictionary* attributes = error[@"attributes"];
    XCTAssertEqualObjects(attributes[@"message"], attributeMessage,
                         @"Attribute message should be in attributes sub-dictionary");
}

- (void)testBothNameAndMessageParametersTakePrecedence {
    JSErrorController* controller = [self createTestController];
    XCTAssertNotNil(controller);

    NSDictionary* additionalAttributes = @{
        @"name": @"AttributeName",
        @"message": @"AttributeMessage",
        @"customKey": @"customValue"
    };

    [controller recordJSError:@"ExplicitName"
                      message:@"ExplicitMessage"
                   stackTrace:@"test stack"
                      isFatal:NO
         additionalAttributes:additionalAttributes];

    NSArray* errors = [controller getErrorQueueForTesting];
    NSDictionary* error = errors.firstObject;

    // Both explicit parameters should be at top level
    XCTAssertEqualObjects(error[@"name"], @"ExplicitName");
    XCTAssertEqualObjects(error[@"message"], @"ExplicitMessage");

    // Custom attributes should be preserved
    NSDictionary* attributes = error[@"attributes"];
    XCTAssertEqualObjects(attributes[@"customKey"], @"customValue");
}

// MARK: - Fatal Error Tests

- (void)testFatalErrorFlag {
    JSErrorController* controller = [self createTestController];
    XCTAssertNotNil(controller);

    // Record fatal error
    [controller recordJSError:@"FatalError"
                      message:@"Critical failure"
                   stackTrace:@"stack"
                      isFatal:YES
         additionalAttributes:nil];

    // Record non-fatal error
    [controller recordJSError:@"NonFatalError"
                      message:@"Recoverable error"
                   stackTrace:@"stack"
                      isFatal:NO
         additionalAttributes:nil];

    NSArray* errors = [controller getErrorQueueForTesting];
    XCTAssertEqual(errors.count, 2);

    // Find and verify fatal error
    for (NSDictionary* error in errors) {
        if ([error[@"name"] isEqualToString:@"FatalError"]) {
            XCTAssertTrue([error[@"isFatal"] boolValue],
                         @"Fatal error should be marked as fatal");
        } else if ([error[@"name"] isEqualToString:@"NonFatalError"]) {
            XCTAssertFalse([error[@"isFatal"] boolValue],
                          @"Non-fatal error should be marked as non-fatal");
        }
    }
}

// MARK: - Data Parity Tests (Similar to MobileHandledException)

- (void)testErrorDataStructure {
    JSErrorController* controller = [self createTestController];
    XCTAssertNotNil(controller);

    [controller recordJSError:@"TypeError"
                      message:@"Test error"
                   stackTrace:@"at function (file.js:10:5)"
                      isFatal:NO
         additionalAttributes:@{@"screen": @"Home"}];

    NSArray* errors = [controller getErrorQueueForTesting];
    NSDictionary* error = errors.firstObject;

    // Verify required fields exist
    XCTAssertNotNil(error[@"name"]);
    XCTAssertNotNil(error[@"message"]);
    XCTAssertNotNil(error[@"stackTrace"]);
    XCTAssertNotNil(error[@"isFatal"]);
    XCTAssertNotNil(error[@"timestamp"]);
    XCTAssertNotNil(error[@"errorId"]);

    // Verify types
    XCTAssertTrue([error[@"name"] isKindOfClass:[NSString class]]);
    XCTAssertTrue([error[@"message"] isKindOfClass:[NSString class]]);
    XCTAssertTrue([error[@"isFatal"] isKindOfClass:[NSNumber class]]);
}

// MARK: - Validation Tests

- (void)testRecordJSErrorWithEmptyName {
    JSErrorController* controller = [self createTestController];
    XCTAssertNotNil(controller);

    // Should not record with empty name
    [controller recordJSError:@""
                      message:@"Test message"
                   stackTrace:@"stack"
                      isFatal:NO
         additionalAttributes:nil];

    NSArray* errors = [controller getErrorQueueForTesting];
    XCTAssertEqual(errors.count, 0, @"Should not record error with empty name");
}

- (void)testRecordJSErrorWithEmptyMessage {
    JSErrorController* controller = [self createTestController];
    XCTAssertNotNil(controller);

    // Should not record with empty message
    [controller recordJSError:@"TestError"
                      message:@""
                   stackTrace:@"stack"
                      isFatal:NO
         additionalAttributes:nil];

    NSArray* errors = [controller getErrorQueueForTesting];
    XCTAssertEqual(errors.count, 0, @"Should not record error with empty message");
}

// MARK: - Helper Methods

// MARK: - Persistence and Duplicate Prevention Tests

- (void)testPersistedErrorsLoadedOnNewControllerInstance {
    // This tests the full disk persistence flow, not the duplicate prevention.
    // For duplicate prevention tests, see testOnHarvestConnected and testNoDuplicates tests.

    // Setup: Create controller and clear any old persisted errors
    JSErrorController* firstController = [self createTestController];
    [firstController clearPersistedErrorsForTesting];

    // Record error → goes to memory + disk
    [firstController recordJSError:@"TestError"
                          message:@"Test message"
                       stackTrace:@"test stack"
                          isFatal:NO
              additionalAttributes:nil];

    // Harvest clears memory but leaves disk
    [firstController onHarvest];

    // Verify memory queue is empty
    XCTAssertEqual([firstController errorQueueSizeForTesting], 0,
                   @"Queue should be empty after harvest");

    // Create new instance (simulates app restart)
    JSErrorController* secondController =
        [self createTestControllerWithSessionId:@"test-session-id-2" clearQueue:NO];

    // Should load from disk
    XCTAssertEqual([secondController errorQueueSizeForTesting], 1,
                   @"New controller instance should load persisted errors from disk");

    // Cleanup
    [secondController clearPersistedErrorsForTesting];
}

- (void)testOnHarvestConnectedDoesNotReloadPersistedErrors {
    // Setup: Create a controller with a persisted error
    JSErrorController* controller = [self createTestController];

    [controller recordJSError:@"TestError"
                      message:@"Test message"
                   stackTrace:@"test stack"
                      isFatal:NO
          additionalAttributes:nil];

    // Error is in memory queue (1) and on disk
    NSInteger queueSizeInitial = [controller errorQueueSizeForTesting];
    XCTAssertEqual(queueSizeInitial, 1, @"Should have 1 error in queue");

    // Simulate network reconnection
    [controller onHarvestConnected];

    // Queue size should still be 1 (not reloaded from disk)
    NSInteger queueSizeAfterReconnect = [controller errorQueueSizeForTesting];
    XCTAssertEqual(queueSizeAfterReconnect, 1, @"Should still have 1 error (no duplicate from disk)");

    // Clean up
    [controller clearPersistedErrorsForTesting];
}

- (void)testNoDuplicatesWhenNetworkDisconnectsBeforeHarvest {
    // This is the key test for the bug fix

    // Scenario: Error recorded → network drops → network reconnects → harvest
    // Expected: Only 1 error sent, not 2

    JSErrorController* controller = [self createTestController];

    // Step 1: Record error (goes to memory + disk)
    [controller recordJSError:@"TestError"
                      message:@"Test message"
                   stackTrace:@"test stack"
                      isFatal:NO
          additionalAttributes:nil];

    NSInteger queueSizeAfterRecord = [controller errorQueueSizeForTesting];
    XCTAssertEqual(queueSizeAfterRecord, 1, @"Should have 1 error after recording");

    // Step 2: Network disconnects (simulated - no action needed)

    // Step 3: Network reconnects
    [controller onHarvestConnected];

    // Queue should still have only 1 error (not reloaded from disk)
    NSInteger queueSizeAfterReconnect = [controller errorQueueSizeForTesting];
    XCTAssertEqual(queueSizeAfterReconnect, 1, @"Should have 1 error (no duplicate)");

    // Step 4: Harvest
    [controller onHarvest];

    // Queue should now be empty
    NSInteger queueSizeAfterHarvest = [controller errorQueueSizeForTesting];
    XCTAssertEqual(queueSizeAfterHarvest, 0, @"Queue should be empty after harvest");

    // Clean up
    [controller clearPersistedErrorsForTesting];
}

- (void)testPersistedErrorsClearedAfterSuccessfulHarvest {
    JSErrorController* controller = [self createTestController];

    // Record error
    [controller recordJSError:@"TestError"
                      message:@"Test message"
                   stackTrace:@"test stack"
                      isFatal:NO
          additionalAttributes:nil];

    // Harvest the error
    [controller onHarvest];

    // Simulate successful harvest
    [controller onHarvestComplete];

    // Create new controller to check if persisted errors are gone
    JSErrorController* newController = [self createTestController];
    NSInteger queueSize = [newController errorQueueSizeForTesting];

    XCTAssertEqual(queueSize, 0, @"Persisted errors should be cleared after successful harvest");
}

// MARK: - Helper Methods

- (JSErrorController*)createTestController {
    return [self createTestControllerWithClearQueue:YES];
}

- (JSErrorController*)createTestControllerWithClearQueue:(BOOL)shouldClear {
    return [self createTestControllerWithSessionId:@"test-session-id" clearQueue:shouldClear];
}

- (JSErrorController*)createTestControllerWithSessionId:(NSString*)sessionId clearQueue:(BOOL)shouldClear {
    NRMAAnalytics* analytics = [[NRMAAnalytics alloc] initWithSessionStartTimeMS:0];
    NRMAAgentConfiguration* agentConfig = [[NRMAAgentConfiguration alloc]
        initWithAppToken:[[NRMAAppToken alloc] initWithApplicationToken:@"test-token-12345"]
        collectorAddress:nil
        crashAddress:nil];
    agentConfig.sessionIdentifier = sessionId;

    JSErrorController* controller = [[JSErrorController alloc]
        initWithAnalyticsController:analytics
        sessionStartTime:[NSDate new]
        agentConfiguration:agentConfig
        platform:[NewRelicInternalUtils osName]
        sessionId:sessionId
        attributeValidator:[[NRMAAttributeValidator alloc] init]];

    // Optionally clear any existing errors (persisted errors loaded in init)
    if (shouldClear) {
        [controller clearErrorQueueForTesting];
    }

    return controller;
}

@end
