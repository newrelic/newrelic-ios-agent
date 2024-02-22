//
//  NewRelicTests.m
//  NewRelicAgent
//
//  Created by Bryce Buchanan on 12/2/13.
//  Copyright © 2023 New Relic. All rights reserved.
//

#import <XCTest/XCTest.h>
#import "NRMATraceController.h"
#import "NewRelic.h"
#import "NRMAExceptionHandler.h"
#import "NRMAFLags.h"
#import "NRMAAgentConfiguration.h"
#import "NRMAHarvestableHTTPTransaction.h"
#import "NRMAHTTPTransactionMeasurement.h"
#import "NRMAmeasurements.h"
#import "NRMeasurementConsumerHelper.h"
#import "NRMATraceMachineAgentUserInterface.h"
#import "NRCustomMetrics.h"
#import "NRMATaskQueue.h"
#import "NRMANamedValueMeasurement.h"
#import "NRMAMeasurements.h"
#import "NewRelicAgentInternal.h"
#import "NewRelicAgentTests.h"
#import "NRMAHarvestController.h"
#import "NRMAHTTPUtilities.h"

@interface NewRelicTests : XCTestCase {
}
@end

@implementation NewRelicTests


- (void) testBadSelectorMethodTrace
{
    [NRMATraceController startTracingWithName:@"TEST"
                            interactionObject:self];
    XCTAssertNoThrow(
                     [NewRelic startTracingMethod:NSSelectorFromString(@"asdf123__3;.//@@$@!")
                                           object:self
                                            timer:[[NRTimer alloc] init]
                                         category:NRTraceTypeDatabase], @"");

    XCTAssertNoThrow(
                     [NewRelic startTracingMethod:nil
                                           object:self
                                            timer:[[NRTimer alloc] init]
                                         category:NRTraceTypeImages],@"");


    [NRMATraceController completeActivityTrace];

}

- (void) testCrashNow {
    XCTAssertThrowsSpecific([NewRelic crashNow], NSException);
}

- (void) testEnableCrashReporting {
    [NRMAFlags setFeatureFlags:0];
    NRMAFeatureFlags flags = [NRMAFlags featureFlags];
    XCTAssertFalse(flags, @"flags should be empty");
    
    BOOL enable = TRUE;
    [NewRelic enableCrashReporting:enable];
    flags = [NRMAFlags featureFlags];

    XCTAssertTrue(flags & NRFeatureFlag_CrashReporting, @"flags should have Crash Reporting enabled");
    XCTAssertFalse(flags & ~NRFeatureFlag_CrashReporting , @"flags shouldn't have any other bit enabled.");
    
    BOOL disable = FALSE;
    [NewRelic enableCrashReporting:disable];
    flags = [NRMAFlags featureFlags];
    XCTAssertFalse(flags & NRFeatureFlag_CrashReporting, @"flags should have Crash Reporting disabled");
}

- (void) testSetPlatform {
    NRMAConnectInformation* config = [NRMAAgentConfiguration connectionInformation];
    NRMAApplicationPlatform currentPlatform = config.deviceInformation.platform;
    XCTAssertNotEqual(currentPlatform, NRMAPlatform_Flutter);
    [NewRelic setPlatform:NRMAPlatform_Flutter];
    config = [NRMAAgentConfiguration connectionInformation];
    currentPlatform = config.deviceInformation.platform;
    XCTAssertEqual(currentPlatform, NRMAPlatform_Flutter);
    
}

- (void) testNoticeNetworkFailureForURLWithTimer {
    NRMAMeasurementConsumerHelper* helper = [[NRMAMeasurementConsumerHelper alloc] initWithType:NRMAMT_HTTPTransaction];
    [NRMAMeasurements initializeMeasurements];
    [NRMAMeasurements addMeasurementConsumer:helper];
    double startTime = 6000;
    double endTime = 10000;

    [NewRelic noticeNetworkFailureForURL:[NSURL URLWithString:@"google.com"]
                              httpMethod:@"post"
                               withTimer:[[NRTimer alloc] initWithStartTime:startTime andEndTime:endTime]
                          andFailureCode:-1];

    while(CFRunLoopGetCurrent() && !helper.result) {}

    NRMAHTTPTransactionMeasurement* result = (NRMAHTTPTransactionMeasurement*)helper.result;

    XCTAssertEqualObjects(result.url, @"google.com", @"Result url does not match recorded url.");
    XCTAssertEqual(result.startTime, (double) 6000, @"Result start time did not match expected start time.");
    XCTAssertEqual((long long)result.endTime,(long long) 10000,@"Result end time did not match expected end time.");
    XCTAssertEqual(result.totalTime, 4000);
    XCTAssertEqual(result.statusCode, 0, @"Result status code did not match expected status code.");
    
    [NRMAMeasurements removeMeasurementConsumer:helper];
    [NRMAMeasurements shutdown];
}

- (void) testEnableStartInteraction {
    [NRMAFlags setFeatureFlags:0];
    NRMAFeatureFlags flags = [NRMAFlags featureFlags];
    XCTAssertFalse(flags, @"flags should be empty");
    
    XCTAssertFalse([NRMAFlags shouldEnableInteractionTracing], @"flags should be empty");
    XCTAssertNil([NewRelic startInteractionWithName:@"test"], @"should be nil when Interaction Tracing is disabled");
    
    [NewRelic enableFeatures:NRFeatureFlag_InteractionTracing];
    flags = [NRMAFlags featureFlags];
    XCTAssertTrue(flags & NRFeatureFlag_InteractionTracing, @"flags should have Interaction Tracing enabled");
    XCTAssertFalse(flags & ~NRFeatureFlag_InteractionTracing , @"flags shouldn't have any other bit enabled.");
    
    XCTAssertNotNil([NewRelic startInteractionWithName:@"test"]);
}

- (void) testEnableNewEventSystem {
    [NRMAFlags setFeatureFlags:0];
    NRMAFeatureFlags flags = [NRMAFlags featureFlags];
    XCTAssertFalse(flags, @"flags should be empty");
    
    XCTAssertFalse([NRMAFlags shouldEnableNewEventSystem], @"flags should be empty");
    
    [NewRelic enableFeatures:NRFeatureFlag_NewEventSystem];
    flags = [NRMAFlags featureFlags];
    XCTAssertTrue(flags & NRFeatureFlag_NewEventSystem, @"flags should have New Event System enabled");
    XCTAssertFalse(flags & ~NRFeatureFlag_NewEventSystem , @"flags shouldn't have any other bit enabled.");
}

- (void) testEnableOfflineStorage {
    [NRMAFlags setFeatureFlags:0];
    NRMAFeatureFlags flags = [NRMAFlags featureFlags];
    XCTAssertFalse(flags, @"flags should be empty");
    
    XCTAssertFalse([NRMAFlags shouldEnableOfflineStorage], @"flags should be empty");
    
    [NewRelic enableFeatures:NRFeatureFlag_OfflineStorage];
    flags = [NRMAFlags featureFlags];
    XCTAssertTrue(flags & NRFeatureFlag_OfflineStorage, @"flags should have offline storage enabled");
    XCTAssertFalse(flags & ~NRFeatureFlag_OfflineStorage , @"flags shouldn't have any other bit enabled.");
}

- (void) testRecordMetricsConsistency
{
    NRMAMeasurementConsumerHelper* metricHelper = [[NRMAMeasurementConsumerHelper alloc] initWithType:NRMAMT_NamedValue];
    [NRMAMeasurements initializeMeasurements];
    [NRMAMeasurements addMeasurementConsumer:metricHelper];
    [NewRelic recordMetricWithName:@"world" category:@"hello"];

    double delayInSeconds = 2.0;
    __block bool done = false;
    dispatch_time_t popTime = dispatch_time(DISPATCH_TIME_NOW, (int64_t)(delayInSeconds * NSEC_PER_SEC));
    dispatch_after(popTime, dispatch_get_main_queue(), ^(void){
        if (!done) {
            XCTFail(@"Test timed out. metricHelper.result was never populated");
        }
    });


    [NRMATaskQueue synchronousDequeue];

    XCTAssertTrue([metricHelper.result isKindOfClass:[NRMANamedValueMeasurement class]],@"assert the result is a named value");

    NRMANamedValueMeasurement* measurement = ((NRMANamedValueMeasurement*)metricHelper.result);
    
    
    NSString* fullMetricName = [NSString stringWithFormat:@"Custom/%@/%@",@"hello",@"world"];
    XCTAssertNotNil(measurement.name, @"We should find this metric in the set.");
    XCTAssertEqualObjects(measurement.name, fullMetricName, @"name is generated properly.");
    done = true;
}

- (void) testRecordMetricWithValue {
    
    NRMAMeasurementConsumerHelper* metricHelper = [[NRMAMeasurementConsumerHelper alloc] initWithType:NRMAMT_NamedValue];
    [NRMAMeasurements initializeMeasurements];
    [NRMAMeasurements addMeasurementConsumer:metricHelper];
    [NewRelic recordMetricWithName:@"world" category:@"hello" value:[NSNumber numberWithInt:200]];

    double delayInSeconds = 2.0;
    __block bool done = NO;
    dispatch_time_t popTime = dispatch_time(DISPATCH_TIME_NOW, (int64_t)(delayInSeconds * NSEC_PER_SEC));
    dispatch_after(popTime, dispatch_get_main_queue(), ^(void){
        if (!done) {
            XCTFail(@"Test timed out. metricHelper.result was never populated");
        }
    });


    [NRMATaskQueue synchronousDequeue];

    XCTAssertTrue([metricHelper.result isKindOfClass:[NRMANamedValueMeasurement class]],@"assert the result is a named value");
    NRMANamedValueMeasurement* measurement = ((NRMANamedValueMeasurement*)metricHelper.result);
    
    
    XCTAssertEqualObjects(measurement.value, [NSNumber numberWithInteger:200], @"verify value is perserved");
    done = YES;
}
- (void) testRecordMetricWithMetricUnits
{
    NRMAMeasurementConsumerHelper* metricHelper = [[NRMAMeasurementConsumerHelper alloc] initWithType:NRMAMT_NamedValue];
    [NRMAMeasurements initializeMeasurements];
    [NRMAMeasurements addMeasurementConsumer:metricHelper];
    NSString* fullMetricName = [NSString stringWithFormat:@"Custom/%@/%@[%@]",@"hello",@"world",kNRMetricUnitsOperations];
    [NewRelic recordMetricWithName:@"world"
                          category:@"hello"
                             value:[NSNumber numberWithInt:100]
                        valueUnits:kNRMetricUnitsOperations];

    double delayInSeconds = 2.0;
    __block bool done = NO;
    dispatch_time_t popTime = dispatch_time(DISPATCH_TIME_NOW, (int64_t)(delayInSeconds * NSEC_PER_SEC));
    dispatch_after(popTime, dispatch_get_main_queue(), ^(void){
        if (!done) {
            XCTFail(@"Test timed out. helper.result was never populated");
        }
    });

    [NRMATaskQueue synchronousDequeue];

    XCTAssertTrue([metricHelper.result isKindOfClass:[NRMANamedValueMeasurement class]],@"assert the result is a named value");
    NRMANamedValueMeasurement* measurement = ((NRMANamedValueMeasurement*)metricHelper.result);
    
    XCTAssertEqualObjects(measurement.name, fullMetricName, @"Names should match");
    done = YES;
}

- (void) testRecordMetricWithValueUnits
{
    NRMAMeasurementConsumerHelper* metricHelper = [[NRMAMeasurementConsumerHelper alloc] initWithType:NRMAMT_NamedValue];
    [NRMAMeasurements initializeMeasurements];
    [NRMAMeasurements addMeasurementConsumer:metricHelper];
    NSString* fullMetricName = [NSString stringWithFormat:@"Custom/%@/%@[|%@]",@"hello",@"world",kNRMetricUnitSeconds];
    [NewRelic recordMetricWithName:@"world"
                          category:@"hello"
                             value:[NSNumber numberWithInt:1]
                        valueUnits:nil
                        countUnits:kNRMetricUnitSeconds];

    double delayInSeconds = 2.0;
    __block bool done = NO;
    dispatch_time_t popTime = dispatch_time(DISPATCH_TIME_NOW, (int64_t)(delayInSeconds * NSEC_PER_SEC));
    dispatch_after(popTime, dispatch_get_main_queue(), ^(void){
        if (!done) {
            XCTFail(@"Test timed out. helper.result was never populated");
        }
    });
    
    [NRMATaskQueue synchronousDequeue];

    XCTAssertTrue([metricHelper.result isKindOfClass:[NRMANamedValueMeasurement class]],@"assert the result is a named value");
    NRMANamedValueMeasurement* measurement = ((NRMANamedValueMeasurement*)metricHelper.result);
    
    XCTAssertEqualObjects(measurement.name, fullMetricName, @"Names should match");
    done = YES;
}
- (void) testSetAttribute {
    NRMAAnalytics* analytics = [NewRelicAgentInternal sharedInstance].analyticsController;
    XCTAssertEqual([analytics setSessionAttribute:@"a" value:@4], [NewRelic setAttribute:@"a" value:@4]);
}

- (void) testIncrementAttribute {
    NRMAAnalytics* analytics = [NewRelicAgentInternal sharedInstance].analyticsController;
    XCTAssertEqual([analytics incrementSessionAttribute:@"a" value:@1], [NewRelic incrementAttribute:@"a"]);
}

- (void) testSetUserID {
    NRMAAnalytics* analytics = [NewRelicAgentInternal sharedInstance].analyticsController;
    XCTAssertEqual([analytics setSessionAttribute:@"userId" value:@"test"], [NewRelic setUserId:@"test"]);
}

- (void) testRemoveAttribute {
    NRMAAnalytics* analytics = [NewRelicAgentInternal sharedInstance].analyticsController;
    XCTAssertEqual([analytics removeSessionAttributeNamed:@"a"], [NewRelic removeAttribute:@"a"]);
}
- (void) testRemoveAllAttributes {
    NRMAAnalytics* analytics = [NewRelicAgentInternal sharedInstance].analyticsController;
    XCTAssertEqual([analytics removeAllSessionAttributes], [NewRelic removeAllAttributes]);
}
- (void) testRecordHandledExceptions {
    XCTAssertNoThrow([NewRelic recordHandledException:[NSException exceptionWithName:@"testException"
                                                                              reason:@"testing"
                                                                            userInfo:@{}]]);
    XCTAssertNoThrow([NewRelic recordHandledException:nil withAttributes: nil]);
    XCTAssertNoThrow([NewRelic recordHandledException:[NSException exceptionWithName:@"testException"
                                                                              reason:@"testing"
                                                                            userInfo:@{}] withAttributes: nil]);
    NSDictionary *dict = @{ @"name" : @"test name", @"reason" : @"test reason"};
    XCTAssertNoThrow([NewRelic recordHandledExceptionWithStackTrace: dict]);
}
- (void) testRecordError {
    XCTAssertNoThrow([NewRelic recordError:[NSError errorWithDomain:@"Unknown" code:NSURLErrorCancelled userInfo:nil]]);
    XCTAssertNoThrow([NewRelic recordError:nil attributes: nil]);
    XCTAssertNoThrow([NewRelic recordError:[NSException exceptionWithName:@"testException"
                                                                   reason:@"testing"
                                                                 userInfo:@{}] attributes: nil]);
}

-(void) testSetApplicationBuildAndVersionBeforeSessionStart {
    if ([NewRelicAgentInternal sharedInstance] != Nil) {
        [[NewRelicAgentInternal sharedInstance] destroyAgent];
    }
    XCTAssertNil([NewRelicAgentInternal sharedInstance]);
    XCTAssertNoThrow([NewRelic setApplicationVersion:@"1.0"]);
    XCTAssertNoThrow([NewRelic setApplicationBuild:@"1.0"], );
    
}

-(void) testInvalidStartApplicationWithoutToken{
    XCTAssertNil([NewRelicAgentInternal sharedInstance]);
    [NewRelic startWithApplicationToken:Nil];
    XCTAssertNil([NewRelicAgentInternal sharedInstance], @"Should not start agent without application token");
}

// XCode will run tests in alphabetical order, so the sharedInstance will exist for any tests alphabetically after this
-(void) testSetApplicationBuildAndVersionPostSessionStart {
    [NewRelic startWithApplicationToken:@"test"];
    XCTAssertNotNil([NewRelicAgentInternal sharedInstance]);
    XCTAssertThrows([NewRelic setApplicationBuild:@"1.0"], @"Should throw if a session has already been started. Application Version must be set first.");
    XCTAssertThrows([NewRelic setApplicationVersion:@"1.0"], @"Should throw if a session has already been started. Application Version must be set first.");
    [[NewRelicAgentInternal sharedInstance] destroyAgent];
}

-(void) testTracingHeaders {
    XCTAssertNotNil([NewRelicAgentInternal sharedInstance]);
    XCTAssertNotNil([NewRelic generateDistributedTracingHeaders]);
}

-(void) testCrossProcessId {
    XCTAssertEqual([[[[NRMAHarvestController harvestController] harvester] crossProcessID] copy], [NewRelic crossProcessId]);
}

-(void) testCurrentSessionId {
    XCTAssertEqual([[[NewRelicAgentInternal sharedInstance] currentSessionId] copy], [NewRelic currentSessionId]);
}

-(void) testRecordBreadcrumb {
    NRMAAnalytics* analytics = [NewRelicAgentInternal sharedInstance].analyticsController;
    XCTAssertEqual([analytics addBreadcrumb:@"test" withAttributes:nil], [NewRelic recordBreadcrumb:@"test" attributes:nil]);
}

-(void) testURLRegexRules {
    NSDictionary<NSString *, NSString *> *regexs =
    @{ @"^http(s{0,1})://(http).*/(\\d)\\d*" : @"https://httpbin.org/status/418"
    };
    
    [NewRelic setURLRegexRules:regexs];
    NRMAURLTransformer *regexTransformer = [[NRMAURLTransformer alloc] initWithRegexRules:regexs];
    NRMAURLTransformer *internalTransformer = [NewRelicAgentInternal getURLTransformer];
    NSURL *test1 = [regexTransformer transformURL:[NSURL URLWithString:@"https://httpstat.us/200"]];
    NSURL *test2 = [internalTransformer transformURL:[NSURL URLWithString:@"https://httpstat.us/200"]];
    XCTAssertEqualObjects(test1, test2);
}

// XCode will run tests in alphabetical order, so the sharedInstance will not exist for testA*.
-(void) testAShutdownBeforeEnable {
    XCTAssertNil([NewRelicAgentInternal sharedInstance]);

    [NewRelic shutdown];
}

-(void) testAddHTTPHeaderTrackingDefault {
    XCTAssertNil([NewRelicAgentInternal sharedInstance]);
    XCTAssertNotNil([NRMAHTTPUtilities trackedHeaderFields]);
    XCTAssertTrue([[NRMAHTTPUtilities trackedHeaderFields] containsObject:@"X-APOLLO-OPERATION-NAME"]);
    XCTAssertTrue([[NRMAHTTPUtilities trackedHeaderFields] containsObject:@"X-APOLLO-OPERATION-TYPE"]);
    XCTAssertTrue([[NRMAHTTPUtilities trackedHeaderFields] containsObject:@"X-APOLLO-OPERATION-ID"]);
}

-(void) testAddHTTPHeaderTracking {
    XCTAssertNil([NewRelicAgentInternal sharedInstance]);

    // Add a new header value to track
    [NewRelic addHTTPHeaderTrackingFor:@[@"Test"]];

    XCTAssertNotNil([NRMAHTTPUtilities trackedHeaderFields]);
    XCTAssertTrue([[NRMAHTTPUtilities trackedHeaderFields] containsObject:@"Test"]);
    XCTAssertFalse([[NRMAHTTPUtilities trackedHeaderFields] containsObject:@"Fake"]);
    
    // Make sure you can't add duplicates
    NSUInteger count = [NRMAHTTPUtilities trackedHeaderFields].count;
    [NewRelic addHTTPHeaderTrackingFor:@[@"Test", @"X-APOLLO-OPERATION-TYPE"]];
    XCTAssertTrue([NRMAHTTPUtilities trackedHeaderFields].count == count);
}

-(void) testSetShutdown {

    XCTAssertNotNil([NewRelicAgentInternal sharedInstance]);

    [NewRelic shutdown];
    // Test double shutdown call
    [NewRelic shutdown];
    // Test log when agent is shutdown.
    [NewRelic startWithApplicationToken:@"TOKEN"];

    // Can't assert
    [NewRelic startTracingMethod:NSSelectorFromString(@"methodName")
                          object:self
                           timer:[[NRTimer alloc] init]
                        category:NRTraceTypeDatabase];

    // NR shouldn't crash if agent is shutdown.
    [NewRelic crashNow];

    // Can't assert.
    [NewRelic recordHandledException:[NSException exceptionWithName:@"Hot Tea Exception" reason:@"the Tea is too hot" userInfo:@{}]];
    NSDictionary* dict = @{@"string":@"string",
                           @"num":@1};
    // Can't assert
    [NewRelic recordHandledException:[NSException exceptionWithName:@"Hot Tea Exception"
                                                             reason:@"the tea is too hot"
                                                           userInfo:nil]
                      withAttributes:dict];
    // Can't assert
    [NewRelic recordHandledExceptionWithStackTrace:dict];
    // Can't assert
    [NewRelic recordError:[NSError errorWithDomain:@"domain" code:NSURLErrorUnknown userInfo:@{}]];
    // Can't assert
    [NewRelic recordError:[NSError errorWithDomain:@"domain" code:NSURLErrorUnknown userInfo:@{}] attributes:dict];

    XCTAssertFalse([NewRelic startInteractionWithName:@"InteractionName"]);

    // Can't assert
    [NewRelic stopCurrentInteraction:@"InteractionName"];

    // Can't assert
    [NewRelic endTracingMethodWithTimer:[[NRTimer alloc] init]];

    XCTAssertFalse([NewRelic setAttribute:@"attr" value:@5]);
    XCTAssertFalse([NewRelic incrementAttribute: @"attr"]);

    XCTAssertFalse([NewRelic removeAttribute: @"attr"]);
    XCTAssertFalse([NewRelic removeAllAttributes]);
    XCTAssertFalse([NewRelic recordCustomEvent:@"asdf"
                                          name:@"blah"
                                    attributes:@{@"name":@"unblah"}]);
    XCTAssertFalse([NewRelic recordBreadcrumb:@"test" attributes:dict]);

    // Can't assert
    [NewRelic recordCustomEvent:@"EventName" attributes:dict];
}

- (void) testLogging {
    XCTAssertNoThrow([NewRelic logInfo:@"Wazzzup?"]);
    XCTAssertNoThrow([NewRelic logError:@"Wazzzup?"]);
    XCTAssertNoThrow([NewRelic logVerbose:@"Wazzzup?"]);
    XCTAssertNoThrow([NewRelic logWarning:@"Wazzzup?"]);
    XCTAssertNoThrow([NewRelic logAudit:@"Wazzzup?"]);

}

- (void) testRecordHandledExceptionsNewEventSystem {
    [NewRelic enableFeatures:NRFeatureFlag_NewEventSystem];
    XCTAssertNoThrow([NewRelic recordHandledException:[NSException exceptionWithName:@"testException"
                                                                              reason:@"testing"
                                                                            userInfo:@{}]]);
    XCTAssertNoThrow([NewRelic recordHandledException:nil withAttributes: nil]);
    XCTAssertNoThrow([NewRelic recordHandledException:[NSException exceptionWithName:@"testException"
                                                                              reason:@"testing"
                                                                            userInfo:@{}] withAttributes: nil]);
    NSDictionary *dict = @{ @"name" : @"test name", @"reason" : @"test reason"};
    XCTAssertNoThrow([NewRelic recordHandledExceptionWithStackTrace: dict]);
    [NewRelic disableFeatures:NRFeatureFlag_NewEventSystem];

}

@end

