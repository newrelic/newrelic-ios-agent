//
//  JSErrorControllerTests.m
//  NewRelicAgentTests
//
//  Copyright © 2024 New Relic. All rights reserved.
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
                                  jsAppVersion:@"1.0.0"
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
                                  jsAppVersion:@"1.0.0"
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
                     jsAppVersion:@"1.0.0"
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
                 jsAppVersion:@"1.0"
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
                 jsAppVersion:@"1.0"
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
                 jsAppVersion:@"1.0"
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
                 jsAppVersion:@"1.0"
         additionalAttributes:nil];

    // Record non-fatal error
    [controller recordJSError:@"NonFatalError"
                      message:@"Recoverable error"
                   stackTrace:@"stack"
                      isFatal:NO
                 jsAppVersion:@"1.0"
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
                 jsAppVersion:@"1.0.0"
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
                 jsAppVersion:@"1.0"
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
                 jsAppVersion:@"1.0"
         additionalAttributes:nil];

    NSArray* errors = [controller getErrorQueueForTesting];
    XCTAssertEqual(errors.count, 0, @"Should not record error with empty message");
}

// MARK: - Helper Methods

- (JSErrorController*)createTestController {
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

    // Clear any existing errors
    [controller clearErrorQueueForTesting];

    return controller;
}

@end
