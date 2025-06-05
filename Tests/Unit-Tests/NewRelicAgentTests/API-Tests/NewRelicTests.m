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
#import "NRMAAppToken.h"
#import "NRTestConstants.h"
#import <OCMock/OCMock.h>
#import <objc/runtime.h>

IMP originalMyBoolPropertyGetterIMP = NULL;

BOOL myBoolPropertyMockedGetter(id self, SEL _cmd) {
    return YES; // Return the mocked value
}

// Function to mock the myBoolProperty getter
void mockMyBoolProperty(void) {
    SEL getterSel = @selector(enabled);
    Method originalMethod = class_getInstanceMethod([NewRelicAgentInternal class], getterSel);
    originalMyBoolPropertyGetterIMP = method_getImplementation(originalMethod);
    method_setImplementation(originalMethod, (IMP)myBoolPropertyMockedGetter);
}

// Function to reset the myBoolProperty getter to its original implementation
void resetMyBoolPropertyMock(void) {
    if (originalMyBoolPropertyGetterIMP) {
        SEL getterSel = @selector(enabled);
        Method originalMethod = class_getInstanceMethod([NewRelicAgentInternal class], getterSel);
        method_setImplementation(originalMethod, originalMyBoolPropertyGetterIMP);
    }
}

static NewRelicAgentInternal* _sharedInstance;

@interface NewRelicTests : XCTestCase {
}

@property id mockNewRelicInternals;

@end

@implementation NewRelicTests

- (void)setUp {
    [super setUp];
    NSArray* paths = [[NSFileManager defaultManager] URLsForDirectory:NSLibraryDirectory
                                                            inDomains:NSUserDomainMask];
    NSURL* documentDirURL = paths[0];
    NSString *fileName = [documentDirURL.path stringByAppendingPathComponent:@"newrelic"];
    NSFileManager *fileManager = [NSFileManager defaultManager];
    if([fileManager fileExistsAtPath:fileName]) {
        [fileManager removeItemAtPath:fileName error:nil];
    }
    
    self.mockNewRelicInternals = [OCMockObject mockForClass:[NewRelicAgentInternal class]];
    _sharedInstance = [[NewRelicAgentInternal alloc] init];
    _sharedInstance.analyticsController = [[NRMAAnalytics alloc] initWithSessionStartTimeMS:0.0];
    [_sharedInstance.analyticsController removeAllSessionAttributes];
    [[[[self.mockNewRelicInternals stub] classMethod] andReturn:_sharedInstance] sharedInstance];
}

- (void)tearDown {
    [self.mockNewRelicInternals stopMocking];
    _sharedInstance = nil;
    
    [super tearDown];
}

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
    [NewRelic disableFeatures:NRFeatureFlag_NewEventSystem];
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
    XCTAssertTrue([analytics setSessionAttribute:@"userId" value:@"test"]);
    XCTAssertTrue([NewRelic setUserId:@"test"]);
}

- (void) testSetUserIdSessionBehavior {
    // set userId to testId
    BOOL success = [NewRelic setUserId:@"testId"];
    XCTAssertTrue(success);
    // set userId to Bob
    success = [NewRelic setUserId:@"Bob"];
    XCTAssertTrue(success);
    NSString* attributes = [[NewRelicAgentInternal sharedInstance].analyticsController sessionAttributeJSONString];
    NSDictionary* decode = [NSJSONSerialization JSONObjectWithData:[attributes dataUsingEncoding:NSUTF8StringEncoding]
                                                           options:0
                                                             error:nil];
    XCTAssertTrue([decode[@"userId"] isEqualToString:@"Bob"]);
    // set userId to NULL
    success = [NewRelic setUserId:NULL];
    XCTAssertTrue(success);
    [self.mockNewRelicInternals stopMocking];
}

- (void) testRemoveAttribute {
    NRMAAnalytics* analytics = [NewRelicAgentInternal sharedInstance].analyticsController;
    XCTAssertTrue([analytics setSessionAttribute:@"a" value:@"test"]);
    XCTAssertTrue([analytics removeSessionAttributeNamed:@"a"]);
    XCTAssertTrue([analytics setSessionAttribute:@"a" value:@"test"]);
    XCTAssertTrue([NewRelic removeAttribute:@"a"]);
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
    [self.mockNewRelicInternals stopMocking];
    
    if ([NewRelicAgentInternal sharedInstance] != Nil) {
        [[NewRelicAgentInternal sharedInstance] destroyAgent];
    }
    XCTAssertNil([NewRelicAgentInternal sharedInstance]);
    XCTAssertNoThrow([NewRelic setApplicationVersion:@"1.0"]);
    XCTAssertNoThrow([NewRelic setApplicationBuild:@"1.0"], );
    
}

-(void) testInvalidStartApplicationWithoutToken {
    [self.mockNewRelicInternals stopMocking];
    
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
    NRMAAgentConfiguration *config = [[NRMAAgentConfiguration alloc] initWithAppToken:[[NRMAAppToken alloc] initWithApplicationToken:kNRMA_ENABLED_STAGING_APP_TOKEN]
                                                  collectorAddress:KNRMA_TEST_COLLECTOR_HOST
                                                      crashAddress:nil];
    [NRMAHarvestController initialize:config];
    NRMAHarvestController* controller = [NRMAHarvestController harvestController];

    NRMAHarvesterConfiguration* harvesterConfig = [NRMAHarvesterConfiguration defaultHarvesterConfiguration];
    harvesterConfig.account_id = 1234567;
    harvesterConfig.application_id = 1234567;
    [[controller harvester] configureHarvester:harvesterConfig];
    
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
    [self.mockNewRelicInternals stopMocking];
    XCTAssertNil([NewRelicAgentInternal sharedInstance]);

    [NewRelic shutdown];
}

-(void) testAddHTTPHeaderTrackingDefault {
    [self.mockNewRelicInternals stopMocking];
    XCTAssertNil([NewRelicAgentInternal sharedInstance]);
//    [NewRelic httpHeadersAddedForTracking]
    XCTAssertNotNil([NewRelic httpHeadersAddedForTracking]);
    XCTAssertTrue([[NewRelic httpHeadersAddedForTracking] containsObject:@"X-APOLLO-OPERATION-NAME"]);
    XCTAssertTrue([[NewRelic httpHeadersAddedForTracking] containsObject:@"X-APOLLO-OPERATION-TYPE"]);
    XCTAssertTrue([[NewRelic httpHeadersAddedForTracking] containsObject:@"X-APOLLO-OPERATION-ID"]);
}

-(void) testAddHTTPHeaderTracking {
    [self.mockNewRelicInternals stopMocking];
    XCTAssertNil([NewRelicAgentInternal sharedInstance]);
    
    // Add a new header value to track
    [NewRelic addHTTPHeaderTrackingFor:@[@"Test"]];

    XCTAssertNotNil([NewRelic httpHeadersAddedForTracking]);
    XCTAssertTrue([[NewRelic httpHeadersAddedForTracking] containsObject:@"Test"]);
    XCTAssertFalse([[NewRelic httpHeadersAddedForTracking] containsObject:@"Fake"]);
    
    // Make sure you can't add duplicates
    NSUInteger count = [NewRelic httpHeadersAddedForTracking].count;
    [NewRelic addHTTPHeaderTrackingFor:@[@"Test", @"X-APOLLO-OPERATION-TYPE"]];
    XCTAssertTrue([NewRelic httpHeadersAddedForTracking].count == count);
}

-(void) testSetShutdown {
    @try{
        mockMyBoolProperty();
        
        XCTAssertNotNil([NewRelicAgentInternal sharedInstance]);
        
        [NewRelic shutdown];
        // Test double shutdown call
        [NewRelic shutdown];
        // Test log when agent is shutdown.
        XCTAssertNoThrow([NewRelic logInfo:@"Wazzzup?"]);
        XCTAssertNoThrow([NewRelic logError:@"Wazzzup?"]);
        XCTAssertNoThrow([NewRelic logVerbose:@"Wazzzup?"]);
        XCTAssertNoThrow([NewRelic logWarning:@"Wazzzup?"]);
        XCTAssertNoThrow([NewRelic logAudit:@"Wazzzup?"]);
        
        // Can't assert
        [NewRelic startTracingMethod:NSSelectorFromString(@"methodName")
                              object:self
                               timer:[[NRTimer alloc] init]
                            category:NRTraceTypeDatabase];
        
        // NR shouldn't crash if agent is shutdown.
        XCTAssertNoThrow([NewRelic crashNow]);
        
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
    } @finally{
        resetMyBoolPropertyMock();
    }
}

- (void) testLogging {
    XCTAssertNoThrow([NewRelic logInfo:@"Wazzzup?"]);
    XCTAssertNoThrow([NewRelic logError:@"Wazzzup?"]);
    XCTAssertNoThrow([NewRelic logVerbose:@"Wazzzup?"]);
    XCTAssertNoThrow([NewRelic logWarning:@"Wazzzup?"]);
    XCTAssertNoThrow([NewRelic logAudit:@"Wazzzup?"]);

    NSDictionary *dict = @{@"logLevel": @"WARN",
                           @"message": @"This is a test message for the New Relic logging system."};

    XCTAssertNoThrow([NewRelic logAll:dict]);

    NSError* error = [NSError errorWithDomain:@"NSErrorUnknownDomain" code:NSURLErrorUnknown userInfo:@{}];

    XCTAssertNoThrow([NewRelic logErrorObject:error]);

    NSDictionary *dict2 = @{@"logLevel": @"WARN",
                           @"message": @"This is a test message for the New Relic logging system."};

    XCTAssertNoThrow([NewRelic logAttributes:dict2]);

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
