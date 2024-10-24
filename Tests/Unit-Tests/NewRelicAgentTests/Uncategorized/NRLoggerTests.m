//
//  NRLoggerTests.m
//  NewRelicAgent
//
//  Created by Chris Dillard on 2/15/24.
//  Copyright © 2024 New Relic. All rights reserved.
//

@import NewRelic;

#import "NRCustomMetrics.h"
#import "NRMAHarvestableMetric.h"
#import "NRLoggerTests.h"
#import "NRCustomMetrics+private.h"
#import "NRLogger.h"
#import "NRMANamedValueMeasurement.h"
#import "NRMAMeasurements.h"
#import "NRMATaskQueue.h"
#import "NRMASupportMetricHelper.h"
#import "NRMAFlags.h"
#import "NRMAFakeDataHelper.h"
#import "NRMAAppToken.h"
#import "NRMAHarvestController.h"
#import "NRTestConstants.h"
#import "NRAutoLogCollector.h"
#import <os/log.h>

@implementation NRLoggerTests
- (void) setUp
{
    [super setUp];
    [NRMAFlags enableFeatures: NRFeatureFlag_LogReporting];
    [NRLogger setLogTargets:NRLogTargetFile | NRLogTargetConsole];

    [NRLogger setLogLevels:NRLogLevelDebug];
    [NRLogger setRemoteLogLevel:NRLogLevelDebug];

    [NRLogger setLogEntityGuid:@"Entity-Guid-XXXX"];

    NRMAAgentConfiguration *config = [[NRMAAgentConfiguration alloc] initWithAppToken:[[NRMAAppToken alloc] initWithApplicationToken:kNRMA_ENABLED_STAGING_APP_TOKEN]
                                                                     collectorAddress:KNRMA_TEST_COLLECTOR_HOST
                                                                         crashAddress:nil];
    [NRMAHarvestController initialize:config];

    category = @"hello";
    name = @"world";

    helper = [[NRMAMeasurementConsumerHelper alloc] initWithType:NRMAMT_NamedValue];

    [NRMAMeasurements initializeMeasurements];
    [NRMAMeasurements addMeasurementConsumer:helper];

    [NRLogger clearLog];


}
- (void) tearDown
{
    [NRMAMeasurements removeMeasurementConsumer:helper];
    helper = nil;

    [NRMAMeasurements shutdown];
    [NRMAFlags disableFeatures: NRFeatureFlag_LogReporting];
    [NRLogger setLogTargets:NRLogTargetConsole];

    [super tearDown];
}

- (void) testNRLogger {

    XCTestExpectation *delayExpectation1 = [self expectationWithDescription:@"Waiting for Log Queue"];

    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(2 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        [delayExpectation1 fulfill];
    });

    [self waitForExpectationsWithTimeout:5 handler:^(NSError * _Nullable error) {
        if (error) {
            XCTFail(@"Timeout error");
        }
    }];

    [NewRelic logInfo:   @"Info Log..."];
    [NewRelic logError:  @"Error Log..."];
    [NewRelic logVerbose:@"Verbose Log..."];
    [NewRelic logWarning:@"Warning Log..."];
    [NewRelic logAudit:  @"Audit Log..."];
    [NewRelic logDebug:  @"Debug Log..."];
    [NewRelic logAttributes:@{
        @"logLevel": @"WARN",
        @"message": @"This is a test message for the New Relic logging system.",
        @"additionalAttribute1": @"attribute1",
        @"additionalAttribute2": @"attribute2"
    }];

    XCTestExpectation *delayExpectation2 = [self expectationWithDescription:@"Waiting for Log Queue"];

    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(2 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        [delayExpectation2 fulfill];
    });

    [self waitForExpectationsWithTimeout:5 handler:^(NSError * _Nullable error) {
        if (error) {
            XCTFail(@"Timeout error");
        }
    }];
    
    NSError* error;
    NSString *path = [NRLogger logFilePath];
    NSData* logData = [NRLogger logFileData:&error];
    if(error){
        NSLog(@"%@", error.localizedDescription);
    }

    NSString* logMessagesJson = [NSString stringWithFormat:@"[ %@ ]", [[NSString alloc] initWithData:logData encoding:NSUTF8StringEncoding]];
    NSData* formattedData = [logMessagesJson dataUsingEncoding:NSUTF8StringEncoding];

    NSArray* decode = [NSJSONSerialization JSONObjectWithData:formattedData
                                                      options:0
                                                        error:nil];
    NSLog(@"decode=%@", decode);

    NSArray * expectedValues = @[
        @{@"message": @"Info Log..."},
        @{@"message": @"Error Log..."},
        @{@"message": @"Verbose Log..."},
        @{@"message": @"Warning Log..."},
        @{@"message": @"Audit Log..."},
        @{@"message": @"Debug Log..."},
        @{@"message": @"This is a test message for the New Relic logging system."},
    ];
    // check for existence of 6 logs.
    int foundCount = 0;
    // For each expected message.
    for (NSDictionary *dict in expectedValues) {
        // Iterate through the collected message logs.
        for (NSDictionary *dict2 in decode) {
            //
            NSString* currentMessage = [dict objectForKey:@"message"];
            if ([[dict2 objectForKey:@"message"] isEqualToString: currentMessage]) {
                foundCount += 1;
                XCTAssertTrue([[dict2 objectForKey:@"entity.guid"] isEqualToString:@"Entity-Guid-XXXX"],@"entity.guid set incorrectly");
                XCTAssertTrue([[dict2 objectForKey:NRLogMessageInstrumentationProviderKey] isEqualToString:NRLogMessageMobileValue],@"instrumentation provider set incorrectly");
                XCTAssertTrue([[dict2 objectForKey:NRLogMessageInstrumentationVersionKey] isEqualToString:@"DEV"],@"instrumentation name set incorrectly");

#if TARGET_OS_WATCH
                XCTAssertTrue([[dict2 objectForKey:NRLogMessageInstrumentationNameKey] isEqualToString:@"watchOSAgent"],@"instrumentation name set incorrectly");
#else
                if ([[[UIDevice currentDevice] systemName] isEqualToString:@"tvOS"]) {
                    XCTAssertTrue([[dict2 objectForKey:NRLogMessageInstrumentationNameKey] isEqualToString:@"tvOSAgent"],@"instrumentation name set incorrectly");

                }
                else {
                    XCTAssertTrue([[dict2 objectForKey:NRLogMessageInstrumentationNameKey] isEqualToString:@"iOSAgent"],@"instrumentation name set incorrectly");
                }
#endif
            }
            // Verify added attributes with logAttributes.
            if ([[dict2 objectForKey:@"message"] isEqualToString:@"This is a test message for the New Relic logging system."]) {
                XCTAssertTrue([[dict2 objectForKey:@"additionalAttribute1"] isEqualToString:@"attribute1"],@"additionalAttribute1 set incorrectly");
                XCTAssertTrue([[dict2 objectForKey:@"additionalAttribute2"] isEqualToString:@"attribute2"],@"additionalAttribute2 set incorrectly");
            }
        }
    }

    XCTAssertEqual(foundCount, 7, @"Seven messages should be found.");
}


- (void) testRemoteLogLevels {

    // Set the remote log level to warning.
    [NRLogger setRemoteLogLevel:NRLogLevelWarning];

    XCTestExpectation *delayExpectation1 = [self expectationWithDescription:@"Waiting for Log Queue"];

    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(2 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        [delayExpectation1 fulfill];
    });

    [self waitForExpectationsWithTimeout:5 handler:^(NSError * _Nullable error) {
        if (error) {
            XCTFail(@"Timeout error");
        }
    }];

    // Three messages should reach the remote log file for upload.

    [NewRelic logInfo:   @"Info Log..."];
    [NewRelic logError:  @"Error Log..."];
    [NewRelic logVerbose:@"Verbose Log..."];
    [NewRelic logWarning:@"Warning Log..."];
    [NewRelic logAudit:  @"Audit Log..."];
    [NewRelic logDebug:  @"Debug Log..."];
    [NewRelic logAttributes:@{
        @"logLevel": @"WARN",
        @"message": @"This is a test message for the New Relic logging system.",
        @"additionalAttribute1": @"attribute1",
        @"additionalAttribute2": @"attribute2"
    }];

    XCTestExpectation *delayExpectation2 = [self expectationWithDescription:@"Waiting for Log Queue"];

    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(2 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        [delayExpectation2 fulfill];
    });

    [self waitForExpectationsWithTimeout:5 handler:^(NSError * _Nullable error) {
        if (error) {
            XCTFail(@"Timeout error");
        }
    }];

    NSError* error;
    NSData* logData = [NRLogger logFileData:&error];
    if(error){
        NSLog(@"%@", error.localizedDescription);
    }
    NSString* logMessagesJson = [NSString stringWithFormat:@"[ %@ ]", [[NSString alloc] initWithData:logData encoding:NSUTF8StringEncoding]];
    NSData* formattedData = [logMessagesJson dataUsingEncoding:NSUTF8StringEncoding];
    NSArray* decode = [NSJSONSerialization JSONObjectWithData:formattedData
                                                      options:0
                                                        error:nil];
    NSLog(@"decode=%@", decode);

    NSArray * expectedValues = @[
        @{@"message": @"Info Log..."},
        @{@"message": @"Error Log..."},
        @{@"message": @"Verbose Log..."},
        @{@"message": @"Warning Log..."},
        @{@"message": @"Audit Log..."},
        @{@"message": @"Debug Log..."},
        @{@"message": @"This is a test message for the New Relic logging system."},
    ];
    // check for existence of 6 logs.
    int foundCount = 0;
    // For each expected message.
    for (NSDictionary *dict in expectedValues) {
        // Iterate through the collected message logs.
        for (NSDictionary *dict2 in decode) {
            //
            NSString* currentMessage = [dict objectForKey:@"message"];
            if ([[dict2 objectForKey:@"message"] isEqualToString: currentMessage]) {
                foundCount += 1;
                XCTAssertTrue([[dict2 objectForKey:@"entity.guid"] isEqualToString:@"Entity-Guid-XXXX"],@"entity.guid set incorrectly");
            }
            // Verify added attributes with logAttributes.
            if ([[dict2 objectForKey:@"message"] isEqualToString:@"This is a test message for the New Relic logging system."]) {
                XCTAssertTrue([[dict2 objectForKey:@"additionalAttribute1"] isEqualToString:@"attribute1"],@"additionalAttribute1 set incorrectly");
                XCTAssertTrue([[dict2 objectForKey:@"additionalAttribute2"] isEqualToString:@"attribute2"],@"additionalAttribute2 set incorrectly");
            }
        }
    }

    XCTAssertEqual(foundCount, 3, @"Three remote messages should be found.");
}

#if !TARGET_OS_WATCH
- (void) testAutoCollectedLogs {
    [NRMAFlags enableFeatures: NRFeatureFlag_RedirectStdOutStdErr];
    // Set the remote log level to debug.
    [NRLogger setRemoteLogLevel:NRLogLevelDebug];
    [NRAutoLogCollector redirectStandardOutputAndError];

    XCTestExpectation *delayExpectation1 = [self expectationWithDescription:@"Waiting for Log Queue"];

    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        [delayExpectation1 fulfill];
    });

    [self waitForExpectationsWithTimeout:5 handler:^(NSError * _Nullable error) {
        if (error) {
            XCTFail(@"Timeout error");
        }
    }];

    // Three messages should reach the remote log file for upload.
    NSLog(@"NSLog Test \n\n");
    os_log_t customLog = os_log_create("com.agent.tests", "logTest");
    // Log messages at different levels
    os_log(customLog, "This is a default os_log message.\n");
    os_log_info(customLog, "This is an info os_log message.\n");
    os_log_error(customLog, "This is an error os_log message.\n");
    os_log_fault(customLog, "This is a fault os_log message.\n");
    
    XCTestExpectation *delayExpectation2 = [self expectationWithDescription:@"Waiting for Log Queue"];

    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        [delayExpectation2 fulfill];
    });

    [self waitForExpectationsWithTimeout:8 handler:^(NSError * _Nullable error) {
        if (error) {
            XCTFail(@"Timeout error");
        }
    }];
    [NRAutoLogCollector restoreStandardOutputAndError];

    NSError* error;
    NSData* logData = [NRLogger logFileData:&error];
    if(error){
        NSLog(@"%@", error.localizedDescription);
    }
    NSString* logMessagesJson = [NSString stringWithFormat:@"[ %@ ]", [[NSString alloc] initWithData:logData encoding:NSUTF8StringEncoding]];
    NSData* formattedData = [logMessagesJson dataUsingEncoding:NSUTF8StringEncoding];
    NSArray* decode = [NSJSONSerialization JSONObjectWithData:formattedData
                                                      options:0
                                                        error:nil];
    NSLog(@"decode=%@", decode);

    NSArray * expectedValues = @[
        @{@"message": @"NSLog Test"},
        @{@"message": @"This is a default os_log message."},
        @{@"message": @"This is an info os_log message."},
        @{@"message": @"This is an error os_log message."},
        @{@"message": @"This is a fault os_log message."},
    ];
    // check for existence of 5 logs.
    int foundCount = 0;
    // For each expected message.
    for (NSDictionary *dict in expectedValues) {
        // Iterate through the collected message logs.
        for (NSDictionary *dict2 in decode) {
            //
            NSString* currentMessage = [dict objectForKey:@"message"];
            if ([[dict2 objectForKey:@"message"] containsString: currentMessage]) {
                foundCount += 1;
                XCTAssertTrue([[dict2 objectForKey:@"entity.guid"] isEqualToString:@"Entity-Guid-XXXX"],@"entity.guid set incorrectly");
            }
            // Verify added attributes with logAttributes.
            if ([[dict2 objectForKey:@"message"] isEqualToString:@"This is a test message for the New Relic logging system."]) {
                XCTAssertTrue([[dict2 objectForKey:@"additionalAttribute1"] isEqualToString:@"attribute1"],@"additionalAttribute1 set incorrectly");
                XCTAssertTrue([[dict2 objectForKey:@"additionalAttribute2"] isEqualToString:@"attribute2"],@"additionalAttribute2 set incorrectly");
            }
        }
    }

    XCTAssertEqual(foundCount, 5, @"Five remote messages should be found.");
    [NRMAFlags disableFeatures: NRFeatureFlag_RedirectStdOutStdErr];
}
#endif
@end
