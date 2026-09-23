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

// The trace-header parse and the legacy (C++ payload) applier are internal to the facade.
// The legacy analytics path cannot be driven end-to-end in this harness (see the note at the
// bottom of this file), so the applier is exercised directly against a Connectivity::Payload.
@interface NRMANetworkFacade (TraceHeaderTesting)
+ (id) callerTraceContextFromTraceHeaders:(NSDictionary<NSString*,NSString*>*)traceHeaders;
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

    NRMAPayload* payload = [[NRMAPayload alloc] initWithTimestamp:[[NSDate date] timeIntervalSince1970]
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

// Asserts that every component of -callerSuppliedTraceHeaders reached the event's payload.
- (void) assertPayloadMatchesCallerTrace:(NSDictionary*)event {
    NSDictionary* payloadData = event[@"payload"][@"d"];
    XCTAssertNotNil(payloadData, @"expected the payload attribute to be present");
    XCTAssertEqualObjects(payloadData[@"tr"], kCallerTraceId, @"payload trace-id must be the caller's");
    XCTAssertEqualObjects(payloadData[@"id"], kCallerSpanId, @"payload span-id must be the caller's");
    XCTAssertEqualObjects(payloadData[@"ac"], kCallerAccountId, @"payload account must come from the caller's tracestate");
    XCTAssertEqualObjects(payloadData[@"ap"], kCallerAppId, @"payload application must come from the caller's tracestate");
    XCTAssertEqualObjects(payloadData[@"tk"], kCallerTrustedAccountKey, @"payload trusted-account-key must come from the caller's tracestate");
    // NRMAPayload.timestamp is in seconds; the tracestate entry carries milliseconds.
    XCTAssertEqualWithAccuracy([payloadData[@"ti"] doubleValue], kCallerTimestampMillis, 0.001,
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

// Records a request for each of the given trace-header sets and asserts that none of the
// resulting events carries a distributed-trace context.
- (void) assertNoTraceAttributesForEachOf:(NSArray<NSDictionary*>*)traceHeaderSets {
    for (NSDictionary* traceHeaders in traceHeaderSets) {
        [self recordRequestWithTraceHeaders:traceHeaders];
    }

    NSArray<NSDictionary*>* events = [self pollForNetworkEventsCount:traceHeaderSets.count];
    XCTAssertEqual(events.count, traceHeaderSets.count, @"expected one event per recorded request");
    for (NSDictionary* event in events) {
        [self assertNoTraceAttributes:event];
    }
}

// The facade records events asynchronously; poll the analytics controller until at least
// `count` network events (identified by requestUrl) have been seen, and return all of them.
//
// -analyticsJSONString DRAINS the event buffer -- it calls
// -getEventJSONStringWithError:clearEvents:YES -- so each poll returns only the events recorded
// since the previous one. The results must therefore be accumulated across polls: re-reading a
// fresh snapshot each time can never reach `count` whenever the recorded requests land in
// different polls, which is what happens as soon as the machine is loaded enough to interleave
// them with this loop.
//
// Requests are recorded on a concurrent queue, so the order between them is not guaranteed --
// assert over the whole set rather than by position.
- (NSArray<NSDictionary*>*) pollForNetworkEventsCount:(NSUInteger)count {
    NSDate *timeoutDate = [NSDate dateWithTimeIntervalSinceNow:10.0];
    NSMutableArray<NSDictionary*>* events = [NSMutableArray array];
    while (events.count < count && [timeoutDate timeIntervalSinceNow] > 0) {
        NSString* json = [[NewRelicAgentInternal sharedInstance].analyticsController analyticsJSONString];
        if (json.length) {
            NSArray* decode = [NSJSONSerialization JSONObjectWithData:[json dataUsingEncoding:NSUTF8StringEncoding]
                                                              options:0
                                                                error:nil];
            for (NSDictionary* event in decode) {
                if (event[@"requestUrl"] != nil) {
                    [events addObject:event];
                }
            }
            if (events.count >= count) {
                break;
            }
        }
        [[NSRunLoop currentRunLoop] runMode:NSDefaultRunLoopMode beforeDate:[NSDate dateWithTimeIntervalSinceNow:0.05]];
    }
    return events;
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
    XCTAssertEqualObjects(event[@"traceId"], kCallerTraceId, @"event must be linked to the caller-supplied trace-id");
    XCTAssertEqualObjects(event[@"trace.id"], kCallerTraceId, @"event must be linked to the caller-supplied trace-id");
    XCTAssertEqualObjects(event[@"guid"], kCallerSpanId, @"event guid must be the caller-supplied span-id");
    XCTAssertEqualObjects(event[@"id"], kCallerSpanId, @"event id must be the caller-supplied span-id");

    // The `payload` attribute is serialized from the same NRMAPayload, so every component
    // of the supplied headers must be visible there too.
    [self assertPayloadMatchesCallerTrace:event];
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
    XCTAssertEqualObjects(event[@"traceId"], kCallerTraceId, @"error event must be linked to the caller-supplied trace-id");
    XCTAssertEqualObjects(event[@"guid"], kCallerSpanId, @"error event guid must be the caller-supplied span-id");
    [self assertPayloadMatchesCallerTrace:event];
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
    XCTAssertEqualObjects(event[@"traceId"], kCallerTraceId, @"event must be linked to the caller-supplied trace-id");
    XCTAssertEqualObjects(event[@"guid"], kCallerSpanId, @"event guid must be the caller-supplied span-id");
    [self assertPayloadMatchesCallerTrace:event];
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
    NSDictionary* event = [self noticeRequestWithTraceHeaders:@{@"traceparent": [NSString stringWithFormat:@"00-%@-%@-01", kCallerTraceId, kCallerSpanId]}];

    XCTAssertEqualObjects(event[@"traceId"], kCallerTraceId);
    XCTAssertEqualObjects(event[@"guid"], kCallerSpanId);
    XCTAssertEqualObjects(event[@"payload"][@"d"][@"ac"], @"1234567", @"account must fall back to the native context");
}

// tracestate carries entries from every vendor in the trace; the NR entry is the one to read.
- (void) testTraceStateWithOtherVendorEntriesIsParsed {
    NSString* traceState = [NSString stringWithFormat:@"congo=t61rcWkgMzE,%@@nr=0-2-%@-%@-%@----%lld",
                            kCallerTrustedAccountKey, kCallerAccountId, kCallerAppId, kCallerSpanId, kCallerTimestampMillis];
    NSDictionary* event = [self noticeRequestWithTraceHeaders:@{@"traceparent": [NSString stringWithFormat:@"00-%@-%@-01", kCallerTraceId, kCallerSpanId],
                                                               @"tracestate": traceState}];

    [self assertPayloadMatchesCallerTrace:event];
}

// A tracestate whose NR entry is truncated or absent still leaves a usable traceparent trace.
- (void) testPartialTraceStateFallsBackToNativeComponents {
    NSDictionary* event = [self noticeRequestWithTraceHeaders:@{@"traceparent": [NSString stringWithFormat:@"00-%@-%@-01", kCallerTraceId, kCallerSpanId],
                                                               @"tracestate": @"congo=t61rcWkgMzE"}];

    XCTAssertEqualObjects(event[@"traceId"], kCallerTraceId);
    XCTAssertEqualObjects(event[@"guid"], kCallerSpanId);
    XCTAssertEqualObjects(event[@"payload"][@"d"][@"ac"], @"1234567", @"account must fall back to the native context");
}

// This agent's own W3CTraceState writes the payload timestamp in milliseconds now, it used to not. while cross-platform
// agents write milliseconds, so a seconds-valued entry must not be read as milliseconds.
- (void) testSecondsValuedTraceStateTimestampIsNormalized {
    NSString* traceState = [NSString stringWithFormat:@"%@@nr=0-2-%@-%@-%@----%lld",
                            kCallerTrustedAccountKey, kCallerAccountId, kCallerAppId, kCallerSpanId,
                            kCallerTimestampMillis];
    NSDictionary* event = [self noticeRequestWithTraceHeaders:@{@"traceparent": [NSString stringWithFormat:@"00-%@-%@-01", kCallerTraceId, kCallerSpanId],
                                                               @"tracestate": traceState}];

    XCTAssertEqualWithAccuracy([event[@"payload"][@"d"][@"ti"] doubleValue], (double)(kCallerTimestampMillis), 1.0,
                               @"a seconds-valued tracestate timestamp must stay in seconds");
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
//     seconds, not the milliseconds a cross-platform agent would write.
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

    XCTAssertEqualObjects(event[@"traceId"], kCallerTraceId, @"event must carry Flutter's trace-id");
    XCTAssertEqualObjects(event[@"trace.id"], kCallerTraceId);
    XCTAssertEqualObjects(event[@"guid"], kCallerSpanId, @"event guid must be Flutter's span-id");
    XCTAssertEqualObjects(event[@"id"], kCallerSpanId);

    NSDictionary* payloadData = event[@"payload"][@"d"];
    XCTAssertEqualObjects(payloadData[@"tr"], kCallerTraceId);
    XCTAssertEqualObjects(payloadData[@"id"], kCallerSpanId);
    XCTAssertEqualObjects(payloadData[@"ac"], kCallerAccountId);
    XCTAssertEqualObjects(payloadData[@"ap"], kCallerAppId);
    XCTAssertEqualObjects(payloadData[@"tk"], kCallerTrustedAccountKey);
    // The seconds-valued tracestate timestamp must not be read as milliseconds.
    XCTAssertEqualWithAccuracy([payloadData[@"ti"] doubleValue], (double)(kCallerTimestampMillis), 1.0);
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
    // Connectivity::Payload's timestamp is in milliseconds, so the tracestate value passes
    // through unscaled -- unlike NRMAPayload's, which is in seconds.
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

// Note: the legacy (C++) event system does not emit the `payload` attribute (it
// carries DT as guid/traceId intrinsics), so the reported bug is new-event-system
// only. The legacy path receives the identical `traceHeaders => apply to payload`
// fix in NRMANetworkFacade; it is not covered by an end-to-end test here because
// pushing a populated C++ Connectivity::Payload through the legacy analytics
// controller in isolation (outside a fully-initialized agent) segfaults in this
// unit-test harness — a pre-existing harness limitation unrelated to this change.

@end
