//
//  NRMANetworkFacadeTraceHeaderTests.mm
//  Agent
//
//  Copyright © 2026 New Relic. All rights reserved.
//
//  Coverage for NR-586680: when an HTTP transaction is reported with
//  distributed-tracing headers supplied by a cross-platform (e.g. Flutter)
//  caller, the native iOS agent must NOT attach its own distributed-trace
//  context (the `payload` attribute or the guid/traceId linkage) to the
//  resulting MobileRequest / MobileRequestError events. Native (auto-
//  instrumented) requests, which pass traceHeaders:nil, must be unaffected.
//

#import <Foundation/Foundation.h>
#import <XCTest/XCTest.h>
#import <OCMock/OCMock.h>
#import "NRMANetworkFacade.h"
#import "NewRelicAgentInternal.h"
#import "NRMAAppToken.h"
#import "NRMAHarvestController.h"
#import "NRTestConstants.h"
#import "NRMAFlags.h"
#import "NRMAHTTPUtilities.h"
#import "NRMAPayload.h"
#import "NRTimer.h"
#import "NRMAAnalytics.h"

static NewRelicAgentInternal* _sharedInstance;

@interface NRMANetworkFacadeTraceHeaderTests : XCTestCase {
    NRMAFeatureFlags _originalFlags;
}
@property id mockNewRelicInternals;
@end

@implementation NRMANetworkFacadeTraceHeaderTests

- (void)setUp {
    [super setUp];
    _originalFlags = [NRMAFlags featureFlags];
    [NRMAFlags enableFeatures:NRFeatureFlag_NetworkRequestEvents | NRFeatureFlag_RequestErrorEvents | NRFeatureFlag_NewEventSystem];

    // Route the facade's [[NewRelicAgentInternal sharedInstance] analyticsController]
    // to a real, inspectable NRMAAnalytics instance.
    self.mockNewRelicInternals = [OCMockObject mockForClass:[NewRelicAgentInternal class]];
    _sharedInstance = [[NewRelicAgentInternal alloc] init];
    _sharedInstance.analyticsController = [[NRMAAnalytics alloc] initWithSessionStartTimeMS:0.0];
    [[[[self.mockNewRelicInternals stub] classMethod] andReturn:_sharedInstance] sharedInstance];

    NRMAAgentConfiguration *config = [[NRMAAgentConfiguration alloc] initWithAppToken:[[NRMAAppToken alloc] initWithApplicationToken:kNRMA_ENABLED_STAGING_APP_TOKEN]
                                                                     collectorAddress:KNRMA_TEST_COLLECTOR_HOST
                                                                         crashAddress:nil];
    [NRMAHarvestController initialize:config];
    NRMAHarvestController* controller = [NRMAHarvestController harvestController];
    NRMAHarvesterConfiguration* harvesterConfig = [NRMAHarvesterConfiguration defaultHarvesterConfiguration];
    [harvesterConfig setTrusted_account_key:@"777"];
    harvesterConfig.account_id = 1234567;
    harvesterConfig.application_id = 1234567;
    [[controller harvester] configureHarvester:harvesterConfig];
}

- (void)tearDown {
    [self.mockNewRelicInternals stopMocking];
    [NRMAFlags setFeatureFlags:_originalFlags];
    [super tearDown];
}

#pragma mark - Helpers

// A request that already carries a native NRMAPayload, as an auto-instrumented
// (native DT) request would. retrieveNRMAPayload: returns this in the facade.
- (NSMutableURLRequest*) requestWithAttachedPayload {
    NSMutableURLRequest* request = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:@"https://www.example.com/api/v1/data"]];
    [request setHTTPMethod:@"GET"];

    NRMAPayload* payload = [[NRMAPayload alloc] initWithTimestamp:[[NSDate date] timeIntervalSince1970]
                                                        accountID:@"1"
                                                            appID:@"1"
                                                          traceID:@"2938058093e048d19c0979691ff765c0"
                                                         parentID:@""
                                                trustedAccountKey:@"1"];
    payload.dtEnabled = true;
    [NRMAHTTPUtilities attachNRMAPayload:payload to:request];
    return request;
}

// Distributed-tracing headers as a cross-platform (Flutter) caller would supply.
- (NSDictionary<NSString*,NSString*>*) callerSuppliedTraceHeaders {
    return @{ @"traceparent": @"00-2938058093e048d19c0979691ff765c0-f1f4f8b63d9b4870-01",
              @"tracestate":  @"1@nr=0-2-1-601344132-f1f4f8b63d9b4870----1783361525671",
              @"newrelic":    @"eyJ2IjpbMCwyXX0=" };
}

// The facade records events asynchronously; poll the analytics controller until
// a network event (identified by requestUrl) is present.
- (NSDictionary*) pollForNetworkEvent {
    NSDate *timeoutDate = [NSDate dateWithTimeIntervalSinceNow:10.0];
    while ([timeoutDate timeIntervalSinceNow] > 0) {
        NSString* json = [[NewRelicAgentInternal sharedInstance].analyticsController analyticsJSONString];
        if (json.length) {
            NSArray* decode = [NSJSONSerialization JSONObjectWithData:[json dataUsingEncoding:NSUTF8StringEncoding]
                                                              options:0
                                                                error:nil];
            for (NSDictionary* event in decode) {
                if (event[@"requestUrl"] != nil) {
                    return event;
                }
            }
        }
        [[NSRunLoop currentRunLoop] runMode:NSDefaultRunLoopMode beforeDate:[NSDate dateWithTimeIntervalSinceNow:0.05]];
    }
    return nil;
}

#pragma mark - New event system: caller-supplied trace headers (Flutter)

- (void) testCallerSuppliedTraceHeadersOmitPayloadOnSuccess {
    NSMutableURLRequest* request = [self requestWithAttachedPayload];
    NSHTTPURLResponse* response = [[NSHTTPURLResponse alloc] initWithURL:request.URL
                                                             statusCode:200
                                                            HTTPVersion:@"1.1"
                                                           headerFields:nil];

    [NRMANetworkFacade noticeNetworkRequest:request
                                   response:response
                                  withTimer:[[NRTimer alloc] initWithStartTime:6000 andEndTime:10000]
                                  bytesSent:10
                              bytesReceived:20
                               responseData:nil
                               traceHeaders:[self callerSuppliedTraceHeaders]
                                     params:nil];

    NSDictionary* event = [self pollForNetworkEvent];
    XCTAssertNotNil(event, @"expected a MobileRequest event to be recorded");
    XCTAssertNil(event[@"payload"], @"native DT payload must be omitted for caller-supplied traces");
    XCTAssertNil(event[@"guid"], @"native DT guid must be omitted for caller-supplied traces");
    XCTAssertNil(event[@"traceId"], @"native DT traceId must be omitted for caller-supplied traces");
    XCTAssertNil(event[@"trace.id"], @"native DT trace.id must be omitted for caller-supplied traces");
}

- (void) testCallerSuppliedTraceHeadersOmitPayloadOnHTTPError {
    NSMutableURLRequest* request = [self requestWithAttachedPayload];
    NSHTTPURLResponse* response = [[NSHTTPURLResponse alloc] initWithURL:request.URL
                                                             statusCode:403
                                                            HTTPVersion:@"1.1"
                                                           headerFields:nil];

    [NRMANetworkFacade noticeNetworkRequest:request
                                   response:response
                                  withTimer:[[NRTimer alloc] initWithStartTime:6000 andEndTime:10000]
                                  bytesSent:10
                              bytesReceived:20
                               responseData:[@"unauthorized" dataUsingEncoding:NSUTF8StringEncoding]
                               traceHeaders:[self callerSuppliedTraceHeaders]
                                     params:nil];

    NSDictionary* event = [self pollForNetworkEvent];
    XCTAssertNotNil(event, @"expected a MobileRequestError event to be recorded");
    XCTAssertTrue([event[@"statusCode"] isEqual:@403], @"expected the HTTP error event");
    XCTAssertNil(event[@"payload"], @"native DT payload must be omitted on MobileRequestError for caller-supplied traces");
    XCTAssertNil(event[@"guid"], @"native DT guid must be omitted on MobileRequestError for caller-supplied traces");
}

#pragma mark - New event system: native (auto-instrumented) request regression

- (void) testNativeDTRequestStillIncludesPayload {
    NSMutableURLRequest* request = [self requestWithAttachedPayload];
    NSHTTPURLResponse* response = [[NSHTTPURLResponse alloc] initWithURL:request.URL
                                                             statusCode:200
                                                            HTTPVersion:@"1.1"
                                                           headerFields:nil];

    // Native auto-instrumentation passes traceHeaders:nil.
    [NRMANetworkFacade noticeNetworkRequest:request
                                   response:response
                                  withTimer:[[NRTimer alloc] initWithStartTime:6000 andEndTime:10000]
                                  bytesSent:10
                              bytesReceived:20
                               responseData:nil
                               traceHeaders:nil
                                     params:nil];

    NSDictionary* event = [self pollForNetworkEvent];
    XCTAssertNotNil(event, @"expected a MobileRequest event to be recorded");
    XCTAssertNotNil(event[@"payload"], @"native DT-instrumented request must still include the payload attribute");
    XCTAssertNotNil(event[@"guid"], @"native DT-instrumented request must still include guid");
    XCTAssertNotNil(event[@"traceId"], @"native DT-instrumented request must still include traceId");
}

// Note: the legacy (C++) event system does not emit the `payload` attribute (it
// carries DT as guid/traceId intrinsics), so the reported bug is new-event-system
// only. The legacy path receives the identical `traceHeaders => suppress payload`
// fix in NRMANetworkFacade; it is not covered by an end-to-end test here because
// pushing a populated C++ Connectivity::Payload through the legacy analytics
// controller in isolation (outside a fully-initialized agent) segfaults in this
// unit-test harness — a pre-existing harness limitation unrelated to this change.

@end
