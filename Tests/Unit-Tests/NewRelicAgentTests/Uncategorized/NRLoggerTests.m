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
#import "NewRelicAgentInternal.h"
#import <OCMock/OCMock.h>

@interface NRLogger()
+ (NRLogger *)logger;
- (NSMutableDictionary*) commonBlockDict;
@end

static NewRelicAgentInternal* _sharedInstance;

@implementation NRLoggerTests
- (void) setUp
{
    [super setUp];
    [NRMAFlags enableFeatures: NRFeatureFlag_LogReporting];
    [NRLogger setLogTargets:NRLogTargetFile | NRLogTargetConsole];

    [NRLogger setLogLevels:NRLogLevelDebug];
    [NRLogger setRemoteLogLevel:NRLogLevelDebug];
    [NRLogger setLogEntityGuid:@"Entity-Guid-XXXX"];


    self.mockNewRelicInternals = [OCMockObject mockForClass:[NewRelicAgentInternal class]];
    _sharedInstance = [[NewRelicAgentInternal alloc] init];
    _sharedInstance.analyticsController = [[NRMAAnalytics alloc] initWithSessionStartTimeMS:0.0];
    [[[[self.mockNewRelicInternals stub] classMethod] andReturn:_sharedInstance] sharedInstance];
    
    [_sharedInstance.analyticsController setSessionAttribute:@"myAttribute" value:@(1)];

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
    [self.mockNewRelicInternals stopMocking];
    _sharedInstance = nil;
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

    NSError* error = nil;
    NSData* logData = [NRLogger logFileData:&error];
    if(error){
        NSLog(@"%@", error.localizedDescription);
    }

    NSMutableDictionary *commonBlock = [[NRLogger logger] commonBlockDict];

    NSData *json = [NRMAJSON dataWithJSONObject:commonBlock
                                                 options:0
                                                   error:&error];

    if (error) {
        NRLOG_AGENT_ERROR(@"Failed to create log payload w error = %@", error);
        XCTAssertNil(error, @"Error creating log payload");
        return;
    }

    error = nil;
    // New version of the line
    NSString* logMessagesJson = [NSString stringWithFormat:@"[{ \"common\": { \"attributes\": %@}, \"logs\": [ %@ ] }]",
                                 [[NSString alloc] initWithData:json encoding:NSUTF8StringEncoding],
                                 [[NSString alloc] initWithData:logData encoding:NSUTF8StringEncoding]];

    NSData* formattedData = [logMessagesJson dataUsingEncoding:NSUTF8StringEncoding];

    NSDictionary* decode = [NSJSONSerialization JSONObjectWithData:formattedData
                                                      options:0
                                                        error:&error];
    NSLog(@"decode=%@", decode);

    NSArray *decodedArray = [[decode valueForKey:@"logs"] objectAtIndex:0];
    NSDictionary *decodedCommonBlock = [[[decode valueForKey:@"common"] objectAtIndex:0] valueForKey:@"attributes"];

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
        for (NSDictionary *dict2 in decodedArray) {
            //
            NSString* currentMessage = [dict objectForKey:@"message"];

            // Check the logs entries
            if ([[dict2 objectForKey:@"message"] isEqualToString: currentMessage]) {
                foundCount += 1;
            }
            // Verify added attributes with logAttributes.
            if ([[dict2 objectForKey:@"message"] isEqualToString:@"This is a test message for the New Relic logging system."]) {
                XCTAssertTrue([[dict2 objectForKey:@"additionalAttribute1"] isEqualToString:@"attribute1"],@"additionalAttribute1 set incorrectly");
                XCTAssertTrue([[dict2 objectForKey:@"additionalAttribute2"] isEqualToString:@"attribute2"],@"additionalAttribute2 set incorrectly");
            }
        }
    }

    XCTAssertEqual(foundCount, 7, @"Seven messages should be found.");

    // Verify Common Block
    XCTAssertTrue([[decodedCommonBlock objectForKey:@"entity.guid"] isEqualToString:@"Entity-Guid-XXXX"],@"entity.guid set incorrectly");
    XCTAssertTrue([[decodedCommonBlock objectForKey:NRLogMessageInstrumentationProviderKey] isEqualToString:NRLogMessageMobileValue],@"instrumentation provider set incorrectly");
    XCTAssertTrue([[decodedCommonBlock objectForKey:NRLogMessageInstrumentationVersionKey] isEqualToString:@"DEV"],@"instrumentation name set incorrectly");

    // Check for added session attributes
    XCTAssertTrue([[decodedCommonBlock objectForKey:@"myAttribute"] isEqualToNumber:@(1)],@"session attribute set incorrectly");


#if TARGET_OS_WATCH
    XCTAssertTrue([[decodedCommonBlock objectForKey:NRLogMessageInstrumentationNameKey] isEqualToString:@"watchOSAgent"],@"instrumentation name set incorrectly");
#else
    if ([[[UIDevice currentDevice] systemName] isEqualToString:@"tvOS"]) {
        XCTAssertTrue([[decodedCommonBlock objectForKey:NRLogMessageInstrumentationNameKey] isEqualToString:@"tvOSAgent"],@"instrumentation name set incorrectly");
    }
    else {
        XCTAssertTrue([[decodedCommonBlock objectForKey:NRLogMessageInstrumentationNameKey] isEqualToString:@"iOSAgent"],@"instrumentation name set incorrectly");
    }
#endif
}


- (void) testRemoteLogLevels {

    [NRLogger setLogLevels:NRLogLevelInfo];

    // Set the remote log level to Debug.
    [NRLogger setRemoteLogLevel:NRLogLevelDebug];
    
    __block BOOL operationCompleted = NO;
    __block int count = 0;
    dispatch_source_set_event_handler(self.source, ^{
        count++;
        if(count == 7){
            // Fulfill the expectation when a write is detected
            sleep(1);
            operationCompleted = YES;
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
    
    // Set a timeout duration
    NSTimeInterval timeout = 30.0;
    NSDate *timeoutDate = [NSDate dateWithTimeIntervalSinceNow:timeout];
    
    // Run the run loop until the operation completes or the timeout is reached
    while (!operationCompleted && [timeoutDate timeIntervalSinceNow] > 0) {
        // Allow other scheduled run loop activities to proceed
        [[NSRunLoop currentRunLoop] runMode:NSDefaultRunLoopMode beforeDate:[NSDate dateWithTimeIntervalSinceNow:0.1]];
    }
    if (!operationCompleted) {
        NSLog(@"Failed to detect 7 writes to the log file.");
    }

    NSError* error;
    NSData* logData = [NRLogger logFileData:&error];
    if(error){
        NSLog(@"%@", error.localizedDescription);
    }
    NSMutableDictionary *commonBlock = [[NRLogger logger] commonBlockDict];

    NSData *json = [NRMAJSON dataWithJSONObject:commonBlock
                                                 options:0
                                                   error:&error];

    if (error) {
        NRLOG_AGENT_ERROR(@"Failed to create log payload w error = %@", error);
        XCTAssertNil(error, @"Error creating log payload");
        return;
    }

    error = nil;
    // New version of the line
    NSString* logMessagesJson = [NSString stringWithFormat:@"[{ \"common\": { \"attributes\": %@}, \"logs\": [ %@ ] }]",
                                 [[NSString alloc] initWithData:json encoding:NSUTF8StringEncoding],
                                 [[NSString alloc] initWithData:logData encoding:NSUTF8StringEncoding]];

    NSData* formattedData = [logMessagesJson dataUsingEncoding:NSUTF8StringEncoding];

    NSDictionary* decode = [NSJSONSerialization JSONObjectWithData:formattedData
                                                      options:0
                                                        error:&error];
    NSLog(@"decode=%@", decode);

    NSArray *decodedArray = [[decode valueForKey:@"logs"] objectAtIndex:0];
    NSDictionary *decodedCommonBlock = [[[decode valueForKey:@"common"] objectAtIndex:0] valueForKey:@"attributes"];

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
        for (NSDictionary *dict2 in decodedArray) {
            //
            NSString* currentMessage = [dict objectForKey:@"message"];
            if ([[dict2 objectForKey:@"message"] isEqualToString: currentMessage]) {
                foundCount += 1;
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

    __block BOOL operationCompleted = NO;
    __block int count = 0;
    dispatch_source_set_event_handler(self.source, ^{
        count++;
        if(count == 4){
            // Fulfill the expectation when a write is detected
            sleep(1);
            operationCompleted = YES;
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

    // Set a timeout duration
    NSTimeInterval timeout = 30.0;
    NSDate *timeoutDate = [NSDate dateWithTimeIntervalSinceNow:timeout];
    
    // Run the run loop until the operation completes or the timeout is reached
    while (!operationCompleted && [timeoutDate timeIntervalSinceNow] > 0) {
        // Allow other scheduled run loop activities to proceed
        [[NSRunLoop currentRunLoop] runMode:NSDefaultRunLoopMode beforeDate:[NSDate dateWithTimeIntervalSinceNow:0.1]];
    }
    if (!operationCompleted) {
        NSLog(@"Failed to detect 4 writes to the log file.");
    }
    NSError* error;
    NSData* logData = [NRLogger logFileData:&error];
    if(error){
        NSLog(@"%@", error.localizedDescription);
    }
    NSMutableDictionary *commonBlock = [[NRLogger logger] commonBlockDict];

    NSData *json = [NRMAJSON dataWithJSONObject:commonBlock
                                                 options:0
                                                   error:&error];

    if (error) {
        NRLOG_AGENT_ERROR(@"Failed to create log payload w error = %@", error);
        XCTAssertNil(error, @"Error creating log payload");
        return;
    }

    error = nil;
    // New version of the line
    NSString* logMessagesJson = [NSString stringWithFormat:@"[{ \"common\": { \"attributes\": %@}, \"logs\": [ %@ ] }]",
                                 [[NSString alloc] initWithData:json encoding:NSUTF8StringEncoding],
                                 [[NSString alloc] initWithData:logData encoding:NSUTF8StringEncoding]];

    NSData* formattedData = [logMessagesJson dataUsingEncoding:NSUTF8StringEncoding];

    NSDictionary* decode = [NSJSONSerialization JSONObjectWithData:formattedData
                                                      options:0
                                                        error:&error];
    NSLog(@"decode=%@", decode);

    NSArray *decodedArray = [[decode valueForKey:@"logs"] objectAtIndex:0];
    NSDictionary *decodedCommonBlock = [[[decode valueForKey:@"common"] objectAtIndex:0] valueForKey:@"attributes"];

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
        for (NSDictionary *dict2 in decodedArray) {
            //
            NSString* currentMessage = [dict objectForKey:@"message"];
            if ([[dict2 objectForKey:@"message"] isEqualToString: currentMessage]) {
                foundCount += 1;
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

    __block BOOL operationCompleted = NO;
    __block int count = 0;
    dispatch_source_set_event_handler(self.source, ^{
        count++;
        if(count == 5){
            // Fulfill the expectation when a write is detected
            sleep(1);
            operationCompleted = YES;
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
    
    // Set a timeout duration
    NSTimeInterval timeout = 30.0;
    NSDate *timeoutDate = [NSDate dateWithTimeIntervalSinceNow:timeout];
    
    // Run the run loop until the operation completes or the timeout is reached
    while (!operationCompleted && [timeoutDate timeIntervalSinceNow] > 0) {
        // Allow other scheduled run loop activities to proceed
        [[NSRunLoop currentRunLoop] runMode:NSDefaultRunLoopMode beforeDate:[NSDate dateWithTimeIntervalSinceNow:0.1]];
    }
    if (!operationCompleted) {
        NSLog(@"Failed to detect 5 writes to the log file.");
    }
    
    [NRAutoLogCollector restoreStandardOutputAndError];

    NSError* error;
    NSData* logData = [NRLogger logFileData:&error];
    if(error){
        NSLog(@"%@", error.localizedDescription);
    }
    NSMutableDictionary *commonBlock = [[NRLogger logger] commonBlockDict];

    NSData *json = [NRMAJSON dataWithJSONObject:commonBlock
                                                 options:0
                                                   error:&error];

    if (error) {
        NRLOG_AGENT_ERROR(@"Failed to create log payload w error = %@", error);
        XCTAssertNil(error, @"Error creating log payload");
        return;
    }

    error = nil;
    // New version of the line
    NSString* logMessagesJson = [NSString stringWithFormat:@"[{ \"common\": { \"attributes\": %@}, \"logs\": [ %@ ] }]",
                                 [[NSString alloc] initWithData:json encoding:NSUTF8StringEncoding],
                                 [[NSString alloc] initWithData:logData encoding:NSUTF8StringEncoding]];

    NSData* formattedData = [logMessagesJson dataUsingEncoding:NSUTF8StringEncoding];

    NSDictionary* decode = [NSJSONSerialization JSONObjectWithData:formattedData
                                                      options:0
                                                        error:&error];
    NSLog(@"decode=%@", decode);

    NSArray *decodedArray = [[decode valueForKey:@"logs"] objectAtIndex:0];
    NSDictionary *decodedCommonBlock = [[[decode valueForKey:@"common"] objectAtIndex:0] valueForKey:@"attributes"];


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
        for (NSDictionary *dict2 in decodedArray) {
            //
            NSString* currentMessage = [dict objectForKey:@"message"];
            if ([[dict2 objectForKey:@"message"] containsString: currentMessage]) {
                foundCount += 1;
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
