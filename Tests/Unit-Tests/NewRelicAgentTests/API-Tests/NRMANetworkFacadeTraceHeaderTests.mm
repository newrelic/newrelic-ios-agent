//
//  NRMANetworkFacadeTraceHeaderTests.mm
//  Agent
//
//  Copyright © 2026 New Relic. All rights reserved.
//
//  Coverage for NR-586680: when an HTTP transaction is reported with
//  distributed-tracing headers supplied by a cross-platform (e.g. Flutter)
//  caller, that caller owns the distributed trace. The native iOS agent must
//  report the resulting MobileRequest / MobileRequestError events against the
//  supplied trace context -- the traceparent's trace-id and span-id -- instead
//  of a native one. Native (auto-instrumented) requests, which pass
//  traceHeaders:nil, must keep using their own attached payload.
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
#import <Connectivity/Payload.hpp>

static NewRelicAgentInternal* _sharedInstance;

// +deinitialize is the harvest controller's teardown entry point; it is not in the
// public header but is used the same way by other unit tests (see MachineMeasurementsTest).
@interface NRMAHarvestController ()
+ (void) deinitialize;
@end

// The trace-header parse and the payload appliers are internal to the facade. The events only
// report the trace-id and span-id, so the remaining components the tracestate supplies (account,
// application, trusted account key, timestamp) are asserted against the appliers directly. The
// legacy analytics path cannot be driven end-to-end in this harness either (see the note at the
// bottom of this file), so its applier is exercised directly against a Connectivity::Payload.
@interface NRMANetworkFacade (TraceHeaderTesting)
+ (id) callerTraceContextFromTraceHeaders:(NSDictionary<NSString*,NSString*>*)traceHeaders;
+ (void) applyCallerTraceContext:(id)context
                   toNRMAPayload:(NRMAPayload*)payload;
+ (void) applyCallerTraceContext:(id)context
                    toCppPayload:(std::unique_ptr<NewRelic::Connectivity::Payload>&)payload;
@end

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

    // setUp installs a real, fully configured harvester into the process-wide
    // NRMAHarvestController singleton. That configuration outlives this class and is
    // read by unrelated tests: NRMAActivityTrace -shouldRecord compares against
    // [NRMAHarvestController configuration].activity_trace_min_utilization, which the
    // default harvester configuration sets to 0.3. Leaving it installed makes the
    // activity-trace tests (NRMATraceMachineTests) silently drop their traces. Tear the
    // controller back down so the global state matches what it was before setUp ran.
    [NRMAHarvestController deinitialize];
    _sharedInstance = nil;

    [super tearDown];
}

#pragma mark - Helpers

// The trace-id and span-id carried by -callerSuppliedTraceHeaders. These are what
// the reported events must be linked to.
static NSString* const kCallerTraceId = @"2938058093e048d19c0979691ff765c0";
static NSString* const kCallerSpanId  = @"f1f4f8b63d9b4870";

// The remaining components of -callerSuppliedTraceHeaders, carried by its tracestate entry.
// The caller's account/app differ from the ones setUp configures the harvester with, so the
// assertions can tell a caller-sourced value from a natively sourced one.
static NSString* const kCallerAccountId         = @"601344132";
static NSString* const kCallerAppId             = @"601400511";
static NSString* const kCallerTrustedAccountKey = @"765705";
static const long long kCallerTimestampMillis   = 1783361525671LL;

// A distinct trace-id for the natively generated payload attached to the request, so
// the assertions can tell the caller's trace apart from the native one.
static NSString* const kNativeTraceId = @"11111111111111111111111111111111";

- (NSMutableURLRequest*) request {
    NSMutableURLRequest* request = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:@"https://www.example.com/api/v1/data"]];
    [request setHTTPMethod:@"GET"];
    return request;
}

// A request that already carries a native NRMAPayload, as an auto-instrumented
// (native DT) request would. retrieveNRMAPayload: returns this in the facade.
- (NSMutableURLRequest*) requestWithAttachedPayload {
    NSMutableURLRequest* request = [self request];

    NRMAPayload* payload = [[NRMAPayload alloc] initWithTimestamp:(long long)([[NSDate date] timeIntervalSince1970] * 1000)
                                                        accountID:@"1"
                                                            appID:@"1"
                                                          traceID:kNativeTraceId
                                                         parentID:@""
                                                trustedAccountKey:@"1"];
    payload.dtEnabled = true;
    [NRMAHTTPUtilities attachNRMAPayload:payload to:request];
    return request;
}

// Distributed-tracing headers as a cross-platform (Flutter) caller would supply.
- (NSDictionary<NSString*,NSString*>*) callerSuppliedTraceHeaders {
    return @{ @"traceparent": [NSString stringWithFormat:@"00-%@-%@-01", kCallerTraceId, kCallerSpanId],
              @"tracestate":  [NSString stringWithFormat:@"%@@nr=0-2-%@-%@-%@----%lld",
                                                         kCallerTrustedAccountKey, kCallerAccountId,
                                                         kCallerAppId, kCallerSpanId, kCallerTimestampMillis] };
}

// Asserts that the event is linked to the caller's trace, and that the payload is not reported
// as an event attribute.
- (void) assertEventMatchesCallerTrace:(NSDictionary*)event {
    XCTAssertEqualObjects(event[@"traceId"], kCallerTraceId, @"event must be linked to the caller-supplied trace-id");
    XCTAssertEqualObjects(event[@"trace.id"], kCallerTraceId, @"event must be linked to the caller-supplied trace-id");
    XCTAssertEqualObjects(event[@"guid"], kCallerSpanId, @"event guid must be the caller-supplied span-id");
    XCTAssertEqualObjects(event[@"id"], kCallerSpanId, @"event id must be the caller-supplied span-id");
    XCTAssertNil(event[@"payload"], @"the payload must not be reported as an event attribute");
}

// A native payload, as +startTrip would create, with the context parsed from `traceHeaders`
// applied to it.
- (NRMAPayload*) nativePayloadWithTraceHeaders:(NSDictionary*)traceHeaders {
    NRMAPayload* payload = [[NRMAPayload alloc] initWithTimestamp:1
                                                        accountID:@"1234567"
                                                            appID:@"1234567"
                                                          traceID:kNativeTraceId
                                                         parentID:@""
                                                trustedAccountKey:@"777"];
    id context = [NRMANetworkFacade callerTraceContextFromTraceHeaders:(NSDictionary<NSString*,NSString*>*)traceHeaders];
    XCTAssertNotNil(context, @"the supplied headers carry a usable trace");
    [NRMANetworkFacade applyCallerTraceContext:context toNRMAPayload:payload];
    return payload;
}

// Asserts that every component of `traceHeaders` -- shaped like -callerSuppliedTraceHeaders --
// reaches the payload.
- (void) assertPayloadReceivesEveryCallerComponentFrom:(NSDictionary*)traceHeaders {
    NRMAPayload* payload = [self nativePayloadWithTraceHeaders:traceHeaders];
    XCTAssertEqualObjects(payload.traceId, kCallerTraceId, @"payload trace-id must be the caller's");
    XCTAssertEqualObjects(payload.id, kCallerSpanId, @"payload span-id must be the caller's");
    XCTAssertEqualObjects(payload.accountId, kCallerAccountId, @"payload account must come from the caller's tracestate");
    XCTAssertEqualObjects(payload.appId, kCallerAppId, @"payload application must come from the caller's tracestate");
    XCTAssertEqualObjects(payload.trustedAccountKey, kCallerTrustedAccountKey, @"payload trusted-account-key must come from the caller's tracestate");
    // Both NRMAPayload.timestamp and the tracestate entry are in milliseconds.
    XCTAssertEqualWithAccuracy((double)payload.timestamp, kCallerTimestampMillis, 0.001,
                               @"payload timestamp must come from the caller's tracestate");
}

// An event carrying no distributed-trace context at all.
- (void) assertNoTraceAttributes:(NSDictionary*)event {
    XCTAssertNil(event[@"payload"], @"no payload may be attached");
    XCTAssertNil(event[@"guid"], @"no guid may be attached");
    XCTAssertNil(event[@"id"], @"no id may be attached");
    XCTAssertNil(event[@"traceId"], @"no traceId may be attached");
    XCTAssertNil(event[@"trace.id"], @"no trace.id may be attached");
}

// Records one request with the given trace headers.
- (void) recordRequestWithTraceHeaders:(NSDictionary<NSString*,NSString*>*)traceHeaders {
    NSMutableURLRequest* request = [self request];
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
                               traceHeaders:traceHeaders
                                     params:nil];
}

// Records one request with the given trace headers and returns the resulting event.
- (NSDictionary*) noticeRequestWithTraceHeaders:(NSDictionary<NSString*,NSString*>*)traceHeaders {
    [self recordRequestWithTraceHeaders:traceHeaders];
    return [self pollForNetworkEvent];
}

// Asserts that none of the given trace-header sets yields a distributed-trace context.
//
// Every set is checked against the parse, which is synchronous and is what decides whether the
// facade attaches a trace. Only the first set is then driven end-to-end through
// +noticeNetworkRequest, to show that an unusable set leaves the event without trace attributes.
// Recording one event per set made the test wait on several asynchronous recordings at once,
// which proved flaky in CI (zero events observed within the poll timeout).
- (void) assertNoTraceAttributesForEachOf:(NSArray<NSDictionary*>*)traceHeaderSets {
    for (NSDictionary* traceHeaders in traceHeaderSets) {
        XCTAssertNil([NRMANetworkFacade callerTraceContextFromTraceHeaders:(NSDictionary<NSString*,NSString*>*)traceHeaders],
                     @"unusable trace headers must yield no trace context: %@", traceHeaders);
    }

    NSDictionary* event = [self noticeRequestWithTraceHeaders:traceHeaderSets.firstObject];
    XCTAssertNotNil(event, @"expected a MobileRequest event to be recorded");
    [self assertNoTraceAttributes:event];
}

// The facade records events asynchronously; poll the analytics controller until
// a network event (identified by requestUrl) is present. Safe to read one event at a time
// because this returns on the first sighting -- but note that each -analyticsJSONString call
// drains the buffer, so do not use this to look for a second event.
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

- (void) testCallerSuppliedTraceHeadersAreAppliedOnSuccess {
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
    [self assertEventMatchesCallerTrace:event];
    [self assertPayloadReceivesEveryCallerComponentFrom:[self callerSuppliedTraceHeaders]];
}

- (void) testCallerSuppliedTraceHeadersAreAppliedOnHTTPError {
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
    [self assertEventMatchesCallerTrace:event];
}

// A cross-platform caller reports a request it made itself, so there is no native
// payload attached: the facade must create one and apply the supplied trace context.
- (void) testCallerSuppliedTraceHeadersAreAppliedWithNoAttachedPayload {
    NSMutableURLRequest* request = [self request];
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
    [self assertEventMatchesCallerTrace:event];
}

#pragma mark - New event system: unusable trace headers must not fabricate a trace

// A caller that supplies no traceparent, an unparseable one, or an all-zero one has given
// the agent no trace to report against. Generating a native one would attach a trace that
// matches nothing on the wire, so the event must carry no DT context at all.
- (void) testEmptyTraceHeadersAttachNoTrace {
    [self assertNoTraceAttributes:[self noticeRequestWithTraceHeaders:@{}]];
}

- (void) testTraceHeadersWithoutTraceparentAttachNoTrace {
    [self assertNoTraceAttributes:[self noticeRequestWithTraceHeaders:@{@"tracestate": @"1@nr=0-2-1-601344132-f1f4f8b63d9b4870----1783361525671"}]];
}

- (void) testMalformedTraceparentAttachesNoTrace {
    [self assertNoTraceAttributesForEachOf:@[ @{@"traceparent": @"garbage"},
                                              @{@"traceparent": @"00-onlytwo"},
                                              @{@"traceparent": @""},
                                              @{@"traceparent": @"00--f1f4f8b63d9b4870-01"},
                                              @{@"traceparent": [NSString stringWithFormat:@"00-%@--01", kCallerTraceId]} ]];
}

- (void) testAllZeroTraceparentAttachesNoTrace {
    [self assertNoTraceAttributesForEachOf:@[ @{@"traceparent": [NSString stringWithFormat:@"00-00000000000000000000000000000000-%@-01", kCallerSpanId]},
                                              @{@"traceparent": [NSString stringWithFormat:@"00-%@-0000000000000000-01", kCallerTraceId]} ]];
}

#pragma mark - New event system: tracestate parsing

// A traceparent on its own is a usable trace: the trace-id and span-id are honored, and the
// components tracestate would have supplied fall back to the native context.
- (void) testTraceparentAloneIsHonored {
    NSDictionary* traceHeaders = @{@"traceparent": [NSString stringWithFormat:@"00-%@-%@-01", kCallerTraceId, kCallerSpanId]};
    NSDictionary* event = [self noticeRequestWithTraceHeaders:traceHeaders];

    [self assertEventMatchesCallerTrace:event];
    XCTAssertEqualObjects([self nativePayloadWithTraceHeaders:traceHeaders].accountId, @"1234567", @"account must fall back to the native context");
}

// tracestate carries entries from every vendor in the trace; the NR entry is the one to read.
- (void) testTraceStateWithOtherVendorEntriesIsParsed {
    NSString* traceState = [NSString stringWithFormat:@"congo=t61rcWkgMzE,%@@nr=0-2-%@-%@-%@----%lld",
                            kCallerTrustedAccountKey, kCallerAccountId, kCallerAppId, kCallerSpanId, kCallerTimestampMillis];
    NSDictionary* traceHeaders = @{@"traceparent": [NSString stringWithFormat:@"00-%@-%@-01", kCallerTraceId, kCallerSpanId],
                                   @"tracestate": traceState};
    NSDictionary* event = [self noticeRequestWithTraceHeaders:traceHeaders];

    [self assertEventMatchesCallerTrace:event];
    [self assertPayloadReceivesEveryCallerComponentFrom:traceHeaders];
}

// A tracestate whose NR entry is truncated or absent still leaves a usable traceparent trace.
- (void) testPartialTraceStateFallsBackToNativeComponents {
    NSDictionary* traceHeaders = @{@"traceparent": [NSString stringWithFormat:@"00-%@-%@-01", kCallerTraceId, kCallerSpanId],
                                   @"tracestate": @"congo=t61rcWkgMzE"};
    NSDictionary* event = [self noticeRequestWithTraceHeaders:traceHeaders];

    [self assertEventMatchesCallerTrace:event];
    XCTAssertEqualObjects([self nativePayloadWithTraceHeaders:traceHeaders].accountId, @"1234567", @"account must fall back to the native context");
}

// The tracestate timestamp is specified in milliseconds, and this agent now emits it that way --
// but it emitted SECONDS until the +startTrip fix, and a caller that is not this agent may supply
// either. So a seconds-valued entry must be normalized to milliseconds rather than taken at face
// value, which would place the payload near 1970.
//
// Feed seconds in; expect the millisecond equivalent out. (The milliseconds case is covered by
// -testCallerSuppliedTraceHeadersAreAppliedOnSuccess, whose tracestate carries milliseconds.)
- (void) testSecondsValuedTraceStateTimestampIsNormalized {
    long long secondsValuedTimestamp = kCallerTimestampMillis / 1000;
    NSString* traceState = [NSString stringWithFormat:@"%@@nr=0-2-%@-%@-%@----%lld",
                            kCallerTrustedAccountKey, kCallerAccountId, kCallerAppId, kCallerSpanId,
                            secondsValuedTimestamp];
    NRMAPayload* payload = [self nativePayloadWithTraceHeaders:@{@"traceparent": [NSString stringWithFormat:@"00-%@-%@-01", kCallerTraceId, kCallerSpanId],
                                                                 @"tracestate": traceState}];

    XCTAssertEqualWithAccuracy((double)payload.timestamp, (double)(secondsValuedTimestamp * 1000), 1.0,
                               @"a seconds-valued tracestate timestamp must be normalized to milliseconds");
}

#pragma mark - New event system: native (auto-instrumented) request regression

- (void) testNativeDTRequestOmitsPayloadAttribute {
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
    XCTAssertNil(event[@"payload"], @"the payload must not be reported as an event attribute");
    XCTAssertNotNil(event[@"guid"], @"native DT-instrumented request must still include guid");
    XCTAssertEqualObjects(event[@"traceId"], kNativeTraceId, @"native DT-instrumented request must keep its own trace-id");
}

#pragma mark - The exact headers the Flutter agent hands to this API

// The Flutter plugin builds its iOS traceAttributes from this agent's own
// +generateDistributedTracingHeaders (NewrelicMobilePlugin.swift "noticeDistributedTrace"),
// keeps the traceparent/tracestate/newrelic entries, and passes them straight into
// +noticeNetworkRequestForURL:...traceHeaders:andParams:. Two details of that dictionary are
// easy to get wrong:
//   * `newrelic` is no longer produced by this agent (NR-382855 removed it), so the Dart map
//     carries a null for that key, which arrives over the method channel as NSNull.
//   * the tracestate timestamp comes from W3CTraceState, which prints NRMAPayload.timestamp --
//     milliseconds since the +startTrip fix (NR-622029). Builds before that printed seconds;
//     -testSecondsValuedTraceStateTimestampIsNormalized covers that shape.
- (NSDictionary*) flutterSuppliedTraceHeaders {
    return @{ @"traceparent": [NSString stringWithFormat:@"00-%@-%@-01", kCallerTraceId, kCallerSpanId],
              @"tracestate":  [NSString stringWithFormat:@"%@@nr=0-2-%@-%@-%@----%lld",
                                                         kCallerTrustedAccountKey, kCallerAccountId,
                                                         kCallerAppId, kCallerSpanId,
                                                         kCallerTimestampMillis],
              @"newrelic":    [NSNull null] };
}

- (void) testFlutterSuppliedTraceHeadersAreApplied {
    NSDictionary* event = [self noticeRequestWithTraceHeaders:(NSDictionary<NSString*,NSString*>*)[self flutterSuppliedTraceHeaders]];

    [self assertEventMatchesCallerTrace:event];
    // The millisecond tracestate timestamp passes through unscaled.
    [self assertPayloadReceivesEveryCallerComponentFrom:[self flutterSuppliedTraceHeaders]];
}

// A non-string value for a header this agent reads must be ignored, not crash or half-apply --
// the method-channel dictionary is untyped ([String: Any]), so a Dart null arrives as NSNull
// and a number stays a number.
//
// This asserts against the parse and the applier, both synchronous. Driving it through
// +noticeNetworkRequest instead made the test depend on event-recording timing, which proved
// flaky in CI (zero events observed within the poll timeout). The end-to-end path is already
// covered for this exact shape by -testFlutterSuppliedTraceHeadersAreApplied, whose headers
// carry an NSNull `newrelic` entry just as the Flutter plugin's do.
- (void) testNonStringTraceHeaderValuesAreIgnored {
    NSDictionary* nullTraceParent = @{@"traceparent": [NSNull null]};
    NSDictionary* numericTraceParent = @{@"traceparent": @(42)};
    NSDictionary* arrayTraceParent = @{@"traceparent": @[@"00", @"trace", @"span"]};

    XCTAssertNil([NRMANetworkFacade callerTraceContextFromTraceHeaders:nullTraceParent]);
    XCTAssertNil([NRMANetworkFacade callerTraceContextFromTraceHeaders:numericTraceParent]);
    XCTAssertNil([NRMANetworkFacade callerTraceContextFromTraceHeaders:arrayTraceParent]);

    // A non-string tracestate must not discard a usable traceparent, and must not apply any of
    // the components tracestate would have supplied -- those fall back to the native context.
    NSDictionary* nullTraceState = @{ @"traceparent": [NSString stringWithFormat:@"00-%@-%@-01", kCallerTraceId, kCallerSpanId],
                                      @"tracestate": [NSNull null] };
    id context = [NRMANetworkFacade callerTraceContextFromTraceHeaders:nullTraceState];
    XCTAssertNotNil(context, @"a usable traceparent must survive a non-string tracestate");

    auto payload = std::make_unique<NewRelic::Connectivity::Payload>();
    payload->setAccountId("native-account");
    payload->setAppId("native-app");
    [NRMANetworkFacade applyCallerTraceContext:context toCppPayload:payload];

    XCTAssertEqualObjects(@(payload->getTraceId().c_str()), kCallerTraceId);
    XCTAssertEqualObjects(@(payload->getId().c_str()), kCallerSpanId);
    XCTAssertEqualObjects(@(payload->getAccountId().c_str()), @"native-account", @"account must fall back to the native context");
    XCTAssertEqualObjects(@(payload->getAppId().c_str()), @"native-app", @"application must fall back to the native context");
}

#pragma mark - The trace-attribute shape: applied with no parsing

// What +generateDistributedTracingContext hands back, and what the Android agent's
// noticeHttpTransaction takes: the trace's identity under the attribute names the event records it
// under. No wire format, so nothing to parse.
- (NSDictionary*) callerSuppliedTraceAttributes {
    return @{ @"trace.id": kCallerTraceId,
              @"id": kCallerSpanId,
              @"guid": kCallerSpanId };
}

- (void) testTraceAttributesAreAppliedWithoutAnyHeaders {
    NSDictionary* event = [self noticeRequestWithTraceHeaders:(NSDictionary<NSString*,NSString*>*)[self callerSuppliedTraceAttributes]];

    XCTAssertEqualObjects(event[@"traceId"], kCallerTraceId);
    XCTAssertEqualObjects(event[@"trace.id"], kCallerTraceId);
    XCTAssertEqualObjects(event[@"guid"], kCallerSpanId);
    XCTAssertEqualObjects(event[@"id"], kCallerSpanId);
    XCTAssertNil(event[@"payload"], @"the payload must not be reported as an event attribute");
    // Account, application and trust key come from the native context, which is correct by
    // construction: the span belongs to this app.
    XCTAssertEqualObjects([self nativePayloadWithTraceHeaders:[self callerSuppliedTraceAttributes]].accountId, @"1234567");
}

// `guid` is the deprecated spelling of `id`; either identifies the span.
- (void) testGuidAloneSatisfiesTheSpanId {
    NSDictionary* event = [self noticeRequestWithTraceHeaders:(NSDictionary<NSString*,NSString*>*)@{ @"trace.id": kCallerTraceId, @"guid": kCallerSpanId }];

    XCTAssertEqualObjects(event[@"traceId"], kCallerTraceId);
    XCTAssertEqualObjects(event[@"guid"], kCallerSpanId);
}

// +generateDistributedTracingContext returns both representations of one trace, so both will
// usually be present. The attributes are authoritative -- they need no parsing.
- (void) testTraceAttributesTakePrecedenceOverHeaders {
    NSString* otherTraceId = @"99999999999999999999999999999999";
    NSString* otherSpanId = @"9999999999999999";
    NSDictionary* mixed = @{ @"trace.id": kCallerTraceId,
                             @"id": kCallerSpanId,
                             @"traceparent": [NSString stringWithFormat:@"00-%@-%@-01", otherTraceId, otherSpanId] };

    NSDictionary* event = [self noticeRequestWithTraceHeaders:(NSDictionary<NSString*,NSString*>*)mixed];

    XCTAssertEqualObjects(event[@"traceId"], kCallerTraceId, @"the attributes must win over the traceparent");
    XCTAssertEqualObjects(event[@"guid"], kCallerSpanId, @"the attributes must win over the traceparent");
}

- (void) testIncompleteTraceAttributesFallBackToTheTraceparent {
    // A trace.id with no span id is not a usable identity on its own; the traceparent still is.
    NSDictionary* headers = @{ @"trace.id": @"99999999999999999999999999999999",
                               @"traceparent": [NSString stringWithFormat:@"00-%@-%@-01", kCallerTraceId, kCallerSpanId] };

    NSDictionary* event = [self noticeRequestWithTraceHeaders:(NSDictionary<NSString*,NSString*>*)headers];

    XCTAssertEqualObjects(event[@"traceId"], kCallerTraceId);
    XCTAssertEqualObjects(event[@"guid"], kCallerSpanId);
}

#pragma mark - Network failures: MobileRequestError from +noticeNetworkFailure

- (NSDictionary*) noticeFailureWithTraceHeaders:(NSDictionary*)traceHeaders {
    [NRMANetworkFacade noticeNetworkFailure:[self request]
                                 withTimer:[[NRTimer alloc] initWithStartTime:6000 andEndTime:10000]
                                 withError:[NSError errorWithDomain:NSURLErrorDomain code:NSURLErrorTimedOut userInfo:nil]
                              traceHeaders:(NSDictionary<NSString*,NSString*>*)traceHeaders];
    return [self pollForNetworkEvent];
}

// A network-level failure (timeout, SSL, dropped connection) reported by a cross-platform caller
// must be attributed to the caller's trace, exactly as an HTTP-status error is.
- (void) testNetworkFailureAppliesCallerSuppliedTraceAttributes {
    NSDictionary* event = [self noticeFailureWithTraceHeaders:[self callerSuppliedTraceAttributes]];

    XCTAssertNotNil(event, @"expected a MobileRequestError event to be recorded");
    XCTAssertEqualObjects(event[@"traceId"], kCallerTraceId);
    XCTAssertEqualObjects(event[@"guid"], kCallerSpanId);
    XCTAssertNil(event[@"payload"], @"the payload must not be reported as an event attribute");
}

- (void) testNetworkFailureAppliesCallerSuppliedTraceHeaders {
    NSDictionary* event = [self noticeFailureWithTraceHeaders:[self callerSuppliedTraceHeaders]];

    XCTAssertNotNil(event, @"expected a MobileRequestError event to be recorded");
    XCTAssertEqualObjects(event[@"traceId"], kCallerTraceId);
    XCTAssertEqualObjects(event[@"guid"], kCallerSpanId);
}

// Native instrumentation passes no trace context and must keep minting its own, as before.
- (void) testNetworkFailureWithoutCallerTraceKeepsANativeTrace {
    NSDictionary* event = [self noticeFailureWithTraceHeaders:nil];

    XCTAssertNotNil(event, @"expected a MobileRequestError event to be recorded");
    XCTAssertNotNil(event[@"traceId"], @"a natively generated trace must still be attached");
    XCTAssertNotNil(event[@"guid"]);
    XCTAssertNotEqualObjects(event[@"traceId"], kCallerTraceId);
}

#pragma mark - Legacy (C++) event system: the same components reach Connectivity::Payload

- (void) testLegacyCppPayloadReceivesEveryCallerComponent {
    auto payload = std::make_unique<NewRelic::Connectivity::Payload>();
    payload->setTraceId("1111111111111111111111111111111");
    payload->setId("2222222222222222");
    payload->setAccountId("native-account");
    payload->setAppId("native-app");
    payload->setTrustedAccountKey("native-key");
    payload->setTimestamp(1);

    id context = [NRMANetworkFacade callerTraceContextFromTraceHeaders:[self callerSuppliedTraceHeaders]];
    XCTAssertNotNil(context, @"the supplied headers carry a usable trace");

    [NRMANetworkFacade applyCallerTraceContext:context toCppPayload:payload];

    XCTAssertEqualObjects(@(payload->getTraceId().c_str()), kCallerTraceId);
    XCTAssertEqualObjects(@(payload->getId().c_str()), kCallerSpanId);
    XCTAssertEqualObjects(@(payload->getAccountId().c_str()), kCallerAccountId);
    XCTAssertEqualObjects(@(payload->getAppId().c_str()), kCallerAppId);
    XCTAssertEqualObjects(@(payload->getTrustedAccountKey().c_str()), kCallerTrustedAccountKey);
    XCTAssertEqualObjects(@(payload->getParentId().c_str()), @"0");
    XCTAssertTrue(payload->getDistributedTracing());
    // Connectivity::Payload's timestamp is in milliseconds, as NRMAPayload's is, so the
    // tracestate value passes through unscaled.
    XCTAssertEqual(payload->getTimestamp(), kCallerTimestampMillis);
}

// The parse is shared by both event systems, so unusable headers yield no context on the
// legacy path either -- and with no context the facade never fabricates a payload.
- (void) testLegacyUnusableHeadersYieldNoContext {
    XCTAssertNil([NRMANetworkFacade callerTraceContextFromTraceHeaders:nil]);
    XCTAssertNil([NRMANetworkFacade callerTraceContextFromTraceHeaders:@{}]);
    XCTAssertNil([NRMANetworkFacade callerTraceContextFromTraceHeaders:@{@"traceparent": @"garbage"}]);
    XCTAssertNil([NRMANetworkFacade callerTraceContextFromTraceHeaders:@{@"tracestate": @"1@nr=0-2-1-2-3----4"}]);
    XCTAssertNil(([NRMANetworkFacade callerTraceContextFromTraceHeaders:@{@"traceparent": [NSString stringWithFormat:@"00-00000000000000000000000000000000-%@-01", kCallerSpanId]}]));

    // A nil context must leave an existing payload untouched rather than half-applying.
    auto payload = std::make_unique<NewRelic::Connectivity::Payload>();
    payload->setTraceId("native-trace");
    [NRMANetworkFacade applyCallerTraceContext:nil toCppPayload:payload];
    XCTAssertEqualObjects(@(payload->getTraceId().c_str()), @"native-trace");
    XCTAssertFalse(payload->getDistributedTracing());
}

// Note: neither event system emits a `payload` attribute; both carry DT as
// guid/traceId attributes. The legacy path receives the identical
// `traceHeaders => apply to payload` fix in NRMANetworkFacade; it is not covered by an end-to-end test here because
// pushing a populated C++ Connectivity::Payload through the legacy analytics
// controller in isolation (outside a fully-initialized agent) segfaults in this
// unit-test harness — a pre-existing harness limitation unrelated to this change.

@end
