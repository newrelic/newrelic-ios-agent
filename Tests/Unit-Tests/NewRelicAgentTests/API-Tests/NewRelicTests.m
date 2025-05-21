//
//  NewRelicTests.m
//  NewRelicAgent
//
//  Created by Bryce Buchanan on 12/2/13.
//  Copyright © 2023 New Relic. All rights reserved.
//

#import <XCTest/XCTest.h>
#import "NRMATraceController.h"
#import "NewRelicAgent.h"
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
                     [NewRelicAgentstartTracingMethod:NSSelectorFromString(@"asdf123__3;.//@@$@!")
                                           object:self
                                            timer:[[NRTimer alloc] init]
                                         category:NRTraceTypeDatabase], @"");

    XCTAssertNoThrow(
                     [NewRelicAgentstartTracingMethod:nil
                                           object:self
                                            timer:[[NRTimer alloc] init]
                                         category:NRTraceTypeImages],@"");


    [NRMATraceController completeActivityTrace];

}

- (void) testCrashNow {
    XCTAssertThrowsSpecific([NewRelicAgentcrashNow], NSException);
}

- (void) testEnableCrashReporting {
    [NRMAFlags setFeatureFlags:0];
    NRMAFeatureFlags flags = [NRMAFlags featureFlags];
    XCTAssertFalse(flags, @"flags should be empty");
    
    BOOL enable = TRUE;
    [NewRelicAgentenableCrashReporting:enable];
    flags = [NRMAFlags featureFlags];

    XCTAssertTrue(flags & NRFeatureFlag_CrashReporting, @"flags should have Crash Reporting enabled");
    XCTAssertFalse(flags & ~NRFeatureFlag_CrashReporting , @"flags shouldn't have any other bit enabled.");
    
    BOOL disable = FALSE;
    [NewRelicAgentenableCrashReporting:disable];
    flags = [NRMAFlags featureFlags];
    XCTAssertFalse(flags & NRFeatureFlag_CrashReporting, @"flags should have Crash Reporting disabled");
}

- (void) testSetPlatform {
    NRMAConnectInformation* config = [NRMAAgentConfiguration connectionInformation];
    NRMAApplicationPlatform currentPlatform = config.deviceInformation.platform;
    XCTAssertNotEqual(currentPlatform, NRMAPlatform_Flutter);
    [NewRelicAgentsetPlatform:NRMAPlatform_Flutter];
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

    [NewRelicAgentnoticeNetworkFailureForURL:[NSURL URLWithString:@"google.com"]
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
    XCTAssertNil([NewRelicAgentstartInteractionWithName:@"test"], @"should be nil when Interaction Tracing is disabled");
    
    [NewRelicAgentenableFeatures:NRFeatureFlag_InteractionTracing];
    flags = [NRMAFlags featureFlags];
    XCTAssertTrue(flags & NRFeatureFlag_InteractionTracing, @"flags should have Interaction Tracing enabled");
    XCTAssertFalse(flags & ~NRFeatureFlag_InteractionTracing , @"flags shouldn't have any other bit enabled.");
    
    XCTAssertNotNil([NewRelicAgentstartInteractionWithName:@"test"]);
}

- (void) testEnableNewEventSystem {
    [NRMAFlags setFeatureFlags:0];
    NRMAFeatureFlags flags = [NRMAFlags featureFlags];
    XCTAssertFalse(flags, @"flags should be empty");
    
    XCTAssertFalse([NRMAFlags shouldEnableNewEventSystem], @"flags should be empty");
    
    [NewRelicAgentenableFeatures:NRFeatureFlag_NewEventSystem];
    flags = [NRMAFlags featureFlags];
    XCTAssertTrue(flags & NRFeatureFlag_NewEventSystem, @"flags should have New Event System enabled");
    XCTAssertFalse(flags & ~NRFeatureFlag_NewEventSystem , @"flags shouldn't have any other bit enabled.");
    [NewRelicAgentdisableFeatures:NRFeatureFlag_NewEventSystem];
}

- (void) testEnableOfflineStorage {
    [NRMAFlags setFeatureFlags:0];
    NRMAFeatureFlags flags = [NRMAFlags featureFlags];
    XCTAssertFalse(flags, @"flags should be empty");
    
    XCTAssertFalse([NRMAFlags shouldEnableOfflineStorage], @"flags should be empty");
    
    [NewRelicAgentenableFeatures:NRFeatureFlag_OfflineStorage];
    flags = [NRMAFlags featureFlags];
    XCTAssertTrue(flags & NRFeatureFlag_OfflineStorage, @"flags should have offline storage enabled");
    XCTAssertFalse(flags & ~NRFeatureFlag_OfflineStorage , @"flags shouldn't have any other bit enabled.");
}

- (void) testRecordMetricsConsistency
{
    NRMAMeasurementConsumerHelper* metricHelper = [[NRMAMeasurementConsumerHelper alloc] initWithType:NRMAMT_NamedValue];
    [NRMAMeasurements initializeMeasurements];
    [NRMAMeasurements addMeasurementConsumer:metricHelper];
    [NewRelicAgentrecordMetricWithName:@"world" category:@"hello"];

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
    [NewRelicAgentrecordMetricWithName:@"world" category:@"hello" value:[NSNumber numberWithInt:200]];

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
    [NewRelicAgentrecordMetricWithName:@"world"
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
    [NewRelicAgentrecordMetricWithName:@"world"
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
    XCTAssertEqual([analytics setSessionAttribute:@"a" value:@4], [NewRelicAgentsetAttribute:@"a" value:@4]);
}

- (void) testIncrementAttribute {
    NRMAAnalytics* analytics = [NewRelicAgentInternal sharedInstance].analyticsController;
    XCTAssertEqual([analytics incrementSessionAttribute:@"a" value:@1], [NewRelicAgentincrementAttribute:@"a"]);
}

- (void) testSetUserID {
    NRMAAnalytics* analytics = [NewRelicAgentInternal sharedInstance].analyticsController;
    XCTAssertTrue([analytics setSessionAttribute:@"userId" value:@"test"]);
    XCTAssertTrue([NewRelicAgentsetUserId:@"test"]);
}

- (void) testSetUserIdSessionBehavior {
    // set userId to testId
    BOOL success = [NewRelicAgentsetUserId:@"testId"];
    XCTAssertTrue(success);
    // set userId to Bob
    success = [NewRelicAgentsetUserId:@"Bob"];
    XCTAssertTrue(success);
    NSString* attributes = [[NewRelicAgentInternal sharedInstance].analyticsController sessionAttributeJSONString];
    NSDictionary* decode = [NSJSONSerialization JSONObjectWithData:[attributes dataUsingEncoding:NSUTF8StringEncoding]
                                                           options:0
                                                             error:nil];
    XCTAssertTrue([decode[@"userId"] isEqualToString:@"Bob"]);
    // set userId to NULL
    success = [NewRelicAgentsetUserId:NULL];
    XCTAssertTrue(success);
    [self.mockNewRelicInternals stopMocking];
}

- (void) testRemoveAttribute {
    NRMAAnalytics* analytics = [NewRelicAgentInternal sharedInstance].analyticsController;
    XCTAssertTrue([analytics setSessionAttribute:@"a" value:@"test"]);
    XCTAssertTrue([analytics removeSessionAttributeNamed:@"a"]);
    XCTAssertTrue([analytics setSessionAttribute:@"a" value:@"test"]);
    XCTAssertTrue([NewRelicAgentremoveAttribute:@"a"]);
}

- (void) testRemoveAllAttributes {
    NRMAAnalytics* analytics = [NewRelicAgentInternal sharedInstance].analyticsController;
    XCTAssertEqual([analytics removeAllSessionAttributes], [NewRelicAgentremoveAllAttributes]);
}
- (void) testRecordHandledExceptions {
    XCTAssertNoThrow([NewRelicAgentrecordHandledException:[NSException exceptionWithName:@"testException"
                                                                              reason:@"testing"
                                                                            userInfo:@{}]]);
    XCTAssertNoThrow([NewRelicAgentrecordHandledException:nil withAttributes: nil]);
    XCTAssertNoThrow([NewRelicAgentrecordHandledException:[NSException exceptionWithName:@"testException"
                                                                              reason:@"testing"
                                                                            userInfo:@{}] withAttributes: nil]);
    NSDictionary *dict = @{ @"name" : @"test name", @"reason" : @"test reason"};
    XCTAssertNoThrow([NewRelicAgentrecordHandledExceptionWithStackTrace: dict]);
}
- (void) testRecordError {
    XCTAssertNoThrow([NewRelicAgentrecordError:[NSError errorWithDomain:@"Unknown" code:NSURLErrorCancelled userInfo:nil]]);
    XCTAssertNoThrow([NewRelicAgentrecordError:nil attributes: nil]);
    XCTAssertNoThrow([NewRelicAgentrecordError:[NSException exceptionWithName:@"testException"
                                                                   reason:@"testing"
                                                                 userInfo:@{}] attributes: nil]);
}

-(void) testSetApplicationBuildAndVersionBeforeSessionStart {
    [self.mockNewRelicInternals stopMocking];
    
    if ([NewRelicAgentInternal sharedInstance] != Nil) {
        [[NewRelicAgentInternal sharedInstance] destroyAgent];
    }
    XCTAssertNil([NewRelicAgentInternal sharedInstance]);
    XCTAssertNoThrow([NewRelicAgentsetApplicationVersion:@"1.0"]);
    XCTAssertNoThrow([NewRelicAgentsetApplicationBuild:@"1.0"], );
    
}

-(void) testInvalidStartApplicationWithoutToken {
    [self.mockNewRelicInternals stopMocking];
    
    XCTAssertNil([NewRelicAgentInternal sharedInstance]);
    [NewRelicAgentstartWithApplicationToken:Nil];
    XCTAssertNil([NewRelicAgentInternal sharedInstance], @"Should not start agent without application token");
}

// XCode will run tests in alphabetical order, so the sharedInstance will exist for any tests alphabetically after this
-(void) testSetApplicationBuildAndVersionPostSessionStart {
    [NewRelicAgentstartWithApplicationToken:@"test"];
    XCTAssertNotNil([NewRelicAgentInternal sharedInstance]);
    XCTAssertThrows([NewRelicAgentsetApplicationBuild:@"1.0"], @"Should throw if a session has already been started. Application Version must be set first.");
    XCTAssertThrows([NewRelicAgentsetApplicationVersion:@"1.0"], @"Should throw if a session has already been started. Application Version must be set first.");
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
    XCTAssertNotNil([NewRelicAgentgenerateDistributedTracingHeaders]);
}

-(void) testCrossProcessId {
    XCTAssertEqual([[[[NRMAHarvestController harvestController] harvester] crossProcessID] copy], [NewRelicAgentcrossProcessId]);
}

-(void) testCurrentSessionId {
    XCTAssertEqual([[[NewRelicAgentInternal sharedInstance] currentSessionId] copy], [NewRelicAgentcurrentSessionId]);
}

-(void) testRecordBreadcrumb {
    NRMAAnalytics* analytics = [NewRelicAgentInternal sharedInstance].analyticsController;
    XCTAssertEqual([analytics addBreadcrumb:@"test" withAttributes:nil], [NewRelicAgentrecordBreadcrumb:@"test" attributes:nil]);
}

-(void) testURLRegexRules {
    NSDictionary<NSString *, NSString *> *regexs =
    @{ @"^http(s{0,1})://(http).*/(\\d)\\d*" : @"https://httpbin.org/status/418"
    };
    
    [NewRelicAgentsetURLRegexRules:regexs];
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

    [NewRelicAgentshutdown];
}

-(void) testAddHTTPHeaderTrackingDefault {
    [self.mockNewRelicInternals stopMocking];
    XCTAssertNil([NewRelicAgentInternal sharedInstance]);
//    [NewRelicAgenthttpHeadersAddedForTracking]
    XCTAssertNotNil([NewRelicAgenthttpHeadersAddedForTracking]);
    XCTAssertTrue([[NewRelicAgenthttpHeadersAddedForTracking] containsObject:@"X-APOLLO-OPERATION-NAME"]);
    XCTAssertTrue([[NewRelicAgenthttpHeadersAddedForTracking] containsObject:@"X-APOLLO-OPERATION-TYPE"]);
    XCTAssertTrue([[NewRelicAgenthttpHeadersAddedForTracking] containsObject:@"X-APOLLO-OPERATION-ID"]);
}

-(void) testAddHTTPHeaderTracking {
    [self.mockNewRelicInternals stopMocking];
    XCTAssertNil([NewRelicAgentInternal sharedInstance]);
    
    // Add a new header value to track
    [NewRelicAgentaddHTTPHeaderTrackingFor:@[@"Test"]];

    XCTAssertNotNil([NewRelicAgenthttpHeadersAddedForTracking]);
    XCTAssertTrue([[NewRelicAgenthttpHeadersAddedForTracking] containsObject:@"Test"]);
    XCTAssertFalse([[NewRelicAgenthttpHeadersAddedForTracking] containsObject:@"Fake"]);
    
    // Make sure you can't add duplicates
    NSUInteger count = [NewRelicAgenthttpHeadersAddedForTracking].count;
    [NewRelicAgentaddHTTPHeaderTrackingFor:@[@"Test", @"X-APOLLO-OPERATION-TYPE"]];
    XCTAssertTrue([NewRelicAgenthttpHeadersAddedForTracking].count == count);
}

-(void) testSetShutdown {
    @try{
        mockMyBoolProperty();
        
        XCTAssertNotNil([NewRelicAgentInternal sharedInstance]);
        
        [NewRelicAgentshutdown];
        // Test double shutdown call
        [NewRelicAgentshutdown];
        // Test log when agent is shutdown.
        XCTAssertNoThrow([NewRelicAgentlogInfo:@"Wazzzup?"]);
        XCTAssertNoThrow([NewRelicAgentlogError:@"Wazzzup?"]);
        XCTAssertNoThrow([NewRelicAgentlogVerbose:@"Wazzzup?"]);
        XCTAssertNoThrow([NewRelicAgentlogWarning:@"Wazzzup?"]);
        XCTAssertNoThrow([NewRelicAgentlogAudit:@"Wazzzup?"]);
        
        // Can't assert
        [NewRelicAgentstartTracingMethod:NSSelectorFromString(@"methodName")
                              object:self
                               timer:[[NRTimer alloc] init]
                            category:NRTraceTypeDatabase];
        
        // NR shouldn't crash if agent is shutdown.
        XCTAssertNoThrow([NewRelicAgentcrashNow]);
        
        // Can't assert.
        [NewRelicAgentrecordHandledException:[NSException exceptionWithName:@"Hot Tea Exception" reason:@"the Tea is too hot" userInfo:@{}]];
        NSDictionary* dict = @{@"string":@"string",
                               @"num":@1};
        // Can't assert
        [NewRelicAgentrecordHandledException:[NSException exceptionWithName:@"Hot Tea Exception"
                                                                 reason:@"the tea is too hot"
                                                               userInfo:nil]
                          withAttributes:dict];
        // Can't assert
        [NewRelicAgentrecordHandledExceptionWithStackTrace:dict];
        // Can't assert
        [NewRelicAgentrecordError:[NSError errorWithDomain:@"domain" code:NSURLErrorUnknown userInfo:@{}]];
        // Can't assert
        [NewRelicAgentrecordError:[NSError errorWithDomain:@"domain" code:NSURLErrorUnknown userInfo:@{}] attributes:dict];
        
        XCTAssertFalse([NewRelicAgentstartInteractionWithName:@"InteractionName"]);
        
        // Can't assert
        [NewRelicAgentstopCurrentInteraction:@"InteractionName"];
        
        // Can't assert
        [NewRelicAgentendTracingMethodWithTimer:[[NRTimer alloc] init]];
        
        XCTAssertFalse([NewRelicAgentsetAttribute:@"attr" value:@5]);
        XCTAssertFalse([NewRelicAgentincrementAttribute: @"attr"]);
        
        XCTAssertFalse([NewRelicAgentremoveAttribute: @"attr"]);
        XCTAssertFalse([NewRelicAgentremoveAllAttributes]);
        XCTAssertFalse([NewRelicAgentrecordCustomEvent:@"asdf"
                                              name:@"blah"
                                        attributes:@{@"name":@"unblah"}]);
        XCTAssertFalse([NewRelicAgentrecordBreadcrumb:@"test" attributes:dict]);
        
        // Can't assert
        [NewRelicAgentrecordCustomEvent:@"EventName" attributes:dict];
    } @finally{
        resetMyBoolPropertyMock();
    }
}

- (void) testLogging {
    XCTAssertNoThrow([NewRelicAgentlogInfo:@"Wazzzup?"]);
    XCTAssertNoThrow([NewRelicAgentlogError:@"Wazzzup?"]);
    XCTAssertNoThrow([NewRelicAgentlogVerbose:@"Wazzzup?"]);
    XCTAssertNoThrow([NewRelicAgentlogWarning:@"Wazzzup?"]);
    XCTAssertNoThrow([NewRelicAgentlogAudit:@"Wazzzup?"]);

    NSDictionary *dict = @{@"logLevel": @"WARN",
                           @"message": @"This is a test message for the New Relic logging system."};

    XCTAssertNoThrow([NewRelicAgentlogAll:dict]);

    NSError* error = [NSError errorWithDomain:@"NSErrorUnknownDomain" code:NSURLErrorUnknown userInfo:@{}];

    XCTAssertNoThrow([NewRelicAgentlogErrorObject:error]);

    NSDictionary *dict2 = @{@"logLevel": @"WARN",
                           @"message": @"This is a test message for the New Relic logging system."};

    XCTAssertNoThrow([NewRelicAgentlogAttributes:dict2]);

}

- (void) testRecordHandledExceptionsNewEventSystem {
    [NewRelicAgentenableFeatures:NRFeatureFlag_NewEventSystem];
    XCTAssertNoThrow([NewRelicAgentrecordHandledException:[NSException exceptionWithName:@"testException"
                                                                              reason:@"testing"
                                                                            userInfo:@{}]]);
    XCTAssertNoThrow([NewRelicAgentrecordHandledException:nil withAttributes: nil]);
    XCTAssertNoThrow([NewRelicAgentrecordHandledException:[NSException exceptionWithName:@"testException"
                                                                              reason:@"testing"
                                                                            userInfo:@{}] withAttributes: nil]);
    NSDictionary *dict = @{ @"name" : @"test name", @"reason" : @"test reason"};
    XCTAssertNoThrow([NewRelicAgentrecordHandledExceptionWithStackTrace: dict]);
    [NewRelicAgentdisableFeatures:NRFeatureFlag_NewEventSystem];

}

@end
