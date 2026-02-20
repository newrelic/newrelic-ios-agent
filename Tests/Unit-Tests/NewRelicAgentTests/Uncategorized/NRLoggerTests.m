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

    // 2. Poll the file until we find all 7 messages
    NSArray *expectedMessages = @[
        @"Info Log...",
        @"Error Log...",
        @"Verbose Log...",
        @"Warning Log...",
        @"Audit Log...",
        @"Debug Log...",
        @"This is a test message for the New Relic logging system."
    ];

    __block int foundCount = 0;
    __block NSArray *decodedArray = nil;
    __block NSDictionary *decodedCommonBlock = nil;
    
    NSTimeInterval timeout = 10.0;
    NSDate *timeoutDate = [NSDate dateWithTimeIntervalSinceNow:timeout];

    while ([timeoutDate timeIntervalSinceNow] > 0) {
        foundCount = 0;
        NSError* error = nil;
        NSData* logData = [NRLogger logFileData:&error];
        
        if (logData && logData.length > 0) {
            NSMutableDictionary *commonBlock = [[NRLogger logger] commonBlockDict];
            NSData *json = [NRMAJSON dataWithJSONObject:commonBlock options:0 error:&error];
            
            if (!error) {
                NSString* logMessagesJson = [NSString stringWithFormat:@"[{ \"common\": { \"attributes\": %@}, \"logs\": [ %@ ] }]",
                                             [[NSString alloc] initWithData:json encoding:NSUTF8StringEncoding],
                                             [[NSString alloc] initWithData:logData encoding:NSUTF8StringEncoding]];
                
                NSData* formattedData = [logMessagesJson dataUsingEncoding:NSUTF8StringEncoding];
                NSDictionary* decode = [NSJSONSerialization JSONObjectWithData:formattedData options:0 error:&error];
                
                if (!error && [decode valueForKey:@"logs"]) {
                    decodedArray = [[decode valueForKey:@"logs"] objectAtIndex:0];
                    decodedCommonBlock = [[[decode valueForKey:@"common"] objectAtIndex:0] valueForKey:@"attributes"];

                    // Check for existence of expected logs
                    for (NSString *expectedMsg in expectedMessages) {
                        for (NSDictionary *actualLog in decodedArray) {
                            if ([[actualLog objectForKey:@"message"] isEqualToString:expectedMsg]) {
                                foundCount++;
                                break;
                            }
                        }
                    }
                }
            }
        }

        if (foundCount >= 7) break;
        
        // Let the background logging threads work
        [[NSRunLoop currentRunLoop] runMode:NSDefaultRunLoopMode beforeDate:[NSDate dateWithTimeIntervalSinceNow:0.1]];
    }

    // 3. Final Assertions
    XCTAssertEqual(foundCount, 7, @"Seven messages should be found. Found only %d. Logs: %@", foundCount, decodedArray);

    // Verify Attributes on the complex log
    for (NSDictionary *dict2 in decodedArray) {
        if ([[dict2 objectForKey:@"message"] isEqualToString:@"This is a test message for the New Relic logging system."]) {
            XCTAssertEqualObjects([dict2 objectForKey:@"additionalAttribute1"], @"attribute1");
            XCTAssertEqualObjects([dict2 objectForKey:@"additionalAttribute2"], @"attribute2");
        }
    }

    // Verify Common Block metadata
    XCTAssertTrue([[decodedCommonBlock objectForKey:@"entity.guid"] isEqualToString:@"Entity-Guid-XXXX"]);
    XCTAssertEqualObjects([decodedCommonBlock objectForKey:@"myAttribute"], @(1));
    
    // Check OS-specific Instrumentation Name
#if TARGET_OS_WATCH
    XCTAssertTrue([[decodedCommonBlock objectForKey:NRLogMessageInstrumentationNameKey] isEqualToString:@"watchOSAgent"]);
#else
    NSString *expectedAgent = [[[UIDevice currentDevice] systemName] isEqualToString:@"tvOS"] ? @"tvOSAgent" : @"iOSAgent";
    XCTAssertTrue([[decodedCommonBlock objectForKey:NRLogMessageInstrumentationNameKey] isEqualToString:expectedAgent]);
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
    // 1. Setup - Local is Debug, but Remote is only Info
    [NRLogger setLogLevels:NRLogLevelDebug];
    [NRLogger setRemoteLogLevel:NRLogLevelInfo];
    
    // 2. Fire Logs (Only 4 of these should reach the Remote file)
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

    // 3. Intelligent Polling
    NSArray *expectedMessages = @[
        @"Info Log...",
        @"Error Log...",
        @"Warning Log...",
        @"This is a test message for the New Relic logging system."
    ];

    __block int foundCount = 0;
    __block NSArray *decodedArray = nil;
    NSTimeInterval timeout = 10.0;
    NSDate *timeoutDate = [NSDate dateWithTimeIntervalSinceNow:timeout];

    while ([timeoutDate timeIntervalSinceNow] > 0) {
        foundCount = 0;
        NSError* error = nil;
        NSData* logData = [NRLogger logFileData:&error];
        
        if (logData && logData.length > 0) {
            NSMutableDictionary *commonBlock = [[NRLogger logger] commonBlockDict];
            NSData *json = [NRMAJSON dataWithJSONObject:commonBlock options:0 error:&error];
            
            if (json) {
                NSString* logMessagesJson = [NSString stringWithFormat:@"[{ \"common\": { \"attributes\": %@}, \"logs\": [ %@ ] }]",
                                             [[NSString alloc] initWithData:json encoding:NSUTF8StringEncoding],
                                             [[NSString alloc] initWithData:logData encoding:NSUTF8StringEncoding]];
                
                NSData* formattedData = [logMessagesJson dataUsingEncoding:NSUTF8StringEncoding];
                NSDictionary* decode = [NSJSONSerialization JSONObjectWithData:formattedData options:0 error:&error];
                
                if (decode && [decode valueForKey:@"logs"]) {
                    decodedArray = [[decode valueForKey:@"logs"] objectAtIndex:0];
                    
                    // Count matches
                    for (NSString *expectedMsg in expectedMessages) {
                        for (NSDictionary *actualLog in decodedArray) {
                            if ([[actualLog objectForKey:@"message"] isEqualToString:expectedMsg]) {
                                foundCount++;
                                break;
                            }
                        }
                    }
                }
            }
        }

        if (foundCount >= 4) break;

        [[NSRunLoop currentRunLoop] runMode:NSDefaultRunLoopMode beforeDate:[NSDate dateWithTimeIntervalSinceNow:0.1]];
    }

    // 4. Final Assertion
    XCTAssertTrue(foundCount >= 4, @"Expected 4 messages, found %d. Data: %@", foundCount, decodedArray);
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
