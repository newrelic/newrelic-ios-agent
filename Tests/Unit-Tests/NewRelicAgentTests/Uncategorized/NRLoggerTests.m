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

    // Open a file descriptor for the file
    self.fileDescriptor = open([[NRLogger logFilePath] fileSystemRepresentation], O_EVTONLY);
    if (self.fileDescriptor < 0) {
        XCTFail(@"Failed to open file descriptor");
        return;
    }
    
    // Set up dispatch source for file monitoring
    self.source = dispatch_source_create(DISPATCH_SOURCE_TYPE_VNODE, self.fileDescriptor, DISPATCH_VNODE_WRITE, DISPATCH_TARGET_QUEUE_DEFAULT);

    __weak typeof(self) weakSelf = self;
    dispatch_source_set_cancel_handler(self.source, ^{
        if (weakSelf.fileDescriptor) {
            close(weakSelf.fileDescriptor);
            weakSelf.fileDescriptor = 0;
        }
    });


}
- (void) tearDown
{
    if (self.fileDescriptor > 0) {
        close(self.fileDescriptor);
    }
    if (self.source) {
        dispatch_source_cancel(self.source);
    }
    
    [NRMAMeasurements removeMeasurementConsumer:helper];
    helper = nil;

    [NRMAMeasurements shutdown];
    [NRMAFlags disableFeatures: NRFeatureFlag_LogReporting];
    [NRLogger setLogTargets:NRLogTargetConsole];

    [super tearDown];
}

- (void) testNRLogger {

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

    sleep(5);

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

    [NRLogger setLogLevels:NRLogLevelInfo];

    // Set the remote log level to Debug.
    [NRLogger setRemoteLogLevel:NRLogLevelDebug];

    // Set up the expectation
    XCTestExpectation *fileWrittenExpectation = [self expectationWithDescription:@"File has been modified"];
    
    __block int count = 0;
    dispatch_source_set_event_handler(self.source, ^{
        count++;
        if(count == 7){
            // Fulfill the expectation when a write is detected
            sleep(1);
            [fileWrittenExpectation fulfill];
        }
    });
    
    // Start monitoring
    dispatch_resume(self.source);
    
    // Seven messages should reach the remote log file for upload.

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

    [self waitForExpectationsWithTimeout:30 handler:^(NSError * _Nullable error) {
        if (error) {
            // Handle timeout here
            NSLog(@"Timeout occurred, but the test will not fail.");
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

    XCTAssertEqual(foundCount, 7, @"Seven remote messages should be found.");
}

- (void) testLocalLogLevels {

    // Set the local log level to Debug
    [NRLogger setLogLevels:NRLogLevelDebug];
    // Set the remote log level to Info.
    [NRLogger setRemoteLogLevel:NRLogLevelInfo];

    // Set up the expectation
    XCTestExpectation *fileWrittenExpectation = [self expectationWithDescription:@"File has been modified"];
    
    __block int count = 0;
    dispatch_source_set_event_handler(self.source, ^{
        count++;
        if(count == 4){
            // Fulfill the expectation when a write is detected
            sleep(1);
            [fileWrittenExpectation fulfill];
        }
    });
    
    // Start monitoring
    dispatch_resume(self.source);
    
    // Seven messages should reach the remote log file for upload.
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

    [self waitForExpectationsWithTimeout:30 handler:^(NSError * _Nullable error) {
        if (error) {
            // Handle timeout here
            NSLog(@"Timeout occurred, but the test will not fail.");
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

    XCTAssertEqual(foundCount, 4, @"Four remote messages should be found.");
}

- (void) testAutoCollectedLogs {
    // Set the remote log level to debug.
    [NRLogger setRemoteLogLevel:NRLogLevelDebug];
    XCTAssertTrue([NRAutoLogCollector redirectStandardOutputAndError]);

    // Set up the expectation
    XCTestExpectation *fileWrittenExpectation = [self expectationWithDescription:@"File has been modified"];
    
    __block int count = 0;
    dispatch_source_set_event_handler(self.source, ^{
        count++;
        if(count == 5){
            // Fulfill the expectation when a write is detected
            sleep(1);
            [fileWrittenExpectation fulfill];
        }
    });
    
    // Start monitoring
    dispatch_resume(self.source);
    // Three messages should reach the remote log file for upload.
    NSLog(@"NSLog Test \n\n");
    os_log_t customLog = os_log_create("com.agent.tests", "logTest");
    // Log messages at different levels
    os_log(customLog, "This is a default os_log message.\n");
    os_log_info(customLog, "This is an info os_log message.\n");
    os_log_error(customLog, "This is an error os_log message.\n");
    os_log_fault(customLog, "This is a fault os_log message.\n");
    
    [self waitForExpectationsWithTimeout:30 handler:^(NSError * _Nullable error) {
        if (error) {
            // Handle timeout here
            NSLog(@"Timeout occurred, but the test will not fail.");
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
}
@end
