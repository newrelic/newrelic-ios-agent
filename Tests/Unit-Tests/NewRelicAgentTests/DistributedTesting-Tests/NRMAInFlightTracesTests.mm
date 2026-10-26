//
//  NRMAInFlightTracesTests.mm
//  NewRelicAgent
//
//  Copyright © 2026 New Relic. All rights reserved.
//

#import <XCTest/XCTest.h>
#import "NRMAInFlightTraces.h"
#import "NRMAHTTPUtilities.h"
#import "NRMAHTTPUtilities+cppInterface.h"
#import "NRMAPayloadContainer+cppInterface.h"
#import "NRMAAppToken.h"
#import "NRMAHarvestController.h"
#import "NRTestConstants.h"
#import "NRMAFlags.h"
#import "NRConstants.h"

@interface NRMAInFlightTracesTests : XCTestCase
@end

@implementation NRMAInFlightTracesTests

- (void) setUp {
    [super setUp];
    [NRMAInFlightTraces reset];
}

- (void) tearDown {
    [NRMAInFlightTraces reset];
    [super tearDown];
}

- (void) configureAccount {
    NRMAAgentConfiguration *config = [[NRMAAgentConfiguration alloc] initWithAppToken:[[NRMAAppToken alloc] initWithApplicationToken:kNRMA_ENABLED_STAGING_APP_TOKEN]
                                                                     collectorAddress:KNRMA_TEST_COLLECTOR_HOST
                                                                         crashAddress:nil];
    [NRMAHarvestController initialize:config];

    NRMAHarvesterConfiguration* harvesterConfig = [NRMAHarvesterConfiguration defaultHarvesterConfiguration];
    harvesterConfig.account_id = 1234567;
    harvesterConfig.application_id = 1234567;
    [[[NRMAHarvestController harvestController] harvester] configureHarvester:harvesterConfig];
}

- (NSMutableURLRequest*) request {
    return [NSMutableURLRequest requestWithURL:[NSURL URLWithString:@"https://example.com/api"]];
}

#pragma mark - Registry

- (void) testNoTraceWhenNothingIsInFlight {
    XCTAssertNil([NRMAInFlightTraces currentTraceAttributes]);
}

- (void) testStartedTraceIsCurrent {
    NSObject* payload = [NSObject new];
    [NRMAInFlightTraces traceStarted:payload traceId:@"trace-1" spanId:@"span-1"];

    XCTAssertEqualObjects([NRMAInFlightTraces currentTraceAttributes],
                          (@{@"trace.id": @"trace-1", @"span.id": @"span-1"}));
}

- (void) testFinishedTraceIsCleared {
    NSObject* payload = [NSObject new];
    [NRMAInFlightTraces traceStarted:payload traceId:@"trace-1" spanId:@"span-1"];
    [NRMAInFlightTraces traceFinished:payload];

    XCTAssertNil([NRMAInFlightTraces currentTraceAttributes]);
}

- (void) testIncompleteTraceIsIgnored {
    [NRMAInFlightTraces traceStarted:[NSObject new] traceId:@"" spanId:@"span-1"];
    XCTAssertNil([NRMAInFlightTraces currentTraceAttributes]);
}

- (void) testNewestInFlightTraceWinsAndOlderOneResumes {
    NSObject* first = [NSObject new];
    NSObject* second = [NSObject new];
    [NRMAInFlightTraces traceStarted:first traceId:@"trace-1" spanId:@"span-1"];
    [NRMAInFlightTraces traceStarted:second traceId:@"trace-2" spanId:@"span-2"];

    XCTAssertEqualObjects([NRMAInFlightTraces currentTraceAttributes][@"trace.id"], @"trace-2");

    [NRMAInFlightTraces traceFinished:second];
    XCTAssertEqualObjects([NRMAInFlightTraces currentTraceAttributes][@"trace.id"], @"trace-1");

    [NRMAInFlightTraces traceFinished:first];
    XCTAssertNil([NRMAInFlightTraces currentTraceAttributes]);
}

- (void) testFinishingAnOlderTraceKeepsTheNewest {
    NSObject* first = [NSObject new];
    NSObject* second = [NSObject new];
    [NRMAInFlightTraces traceStarted:first traceId:@"trace-1" spanId:@"span-1"];
    [NRMAInFlightTraces traceStarted:second traceId:@"trace-2" spanId:@"span-2"];

    [NRMAInFlightTraces traceFinished:first];
    XCTAssertEqualObjects([NRMAInFlightTraces currentTraceAttributes][@"trace.id"], @"trace-2");
}

- (void) testTraceOfReleasedPayloadIsDropped {
    NSObject* survivor = [NSObject new];
    [NRMAInFlightTraces traceStarted:survivor traceId:@"trace-1" spanId:@"span-1"];
    @autoreleasepool {
        NSObject* abandoned = [NSObject new];
        [NRMAInFlightTraces traceStarted:abandoned traceId:@"trace-2" spanId:@"span-2"];
        abandoned = nil;
    }

    XCTAssertEqualObjects([NRMAInFlightTraces currentTraceAttributes][@"trace.id"], @"trace-1");
}

- (void) testSetIsBounded {
    NSMutableArray* payloads = [NSMutableArray array];
    for (int i = 0; i < 200; i++) {
        NSObject* payload = [NSObject new];
        [payloads addObject:payload];
        [NRMAInFlightTraces traceStarted:payload
                                 traceId:[NSString stringWithFormat:@"trace-%d", i]
                                  spanId:[NSString stringWithFormat:@"span-%d", i]];
    }

    XCTAssertEqualObjects([NRMAInFlightTraces currentTraceAttributes][@"trace.id"], @"trace-199");

    // Only the newest 64 are kept: once they finish, nothing is in flight, though the older
    // payloads are still alive.
    for (NSUInteger i = payloads.count - 64; i < payloads.count; i++) {
        [NRMAInFlightTraces traceFinished:payloads[i]];
    }
    XCTAssertNil([NRMAInFlightTraces currentTraceAttributes]);
}

#pragma mark - Request lifecycle

- (void) testRequestTraceIsInFlightUntilRequestFinishes {
    [self configureAccount];
    NSMutableURLRequest* request = [self request];

    NRMAPayload* payload = [NRMAHTTPUtilities addConnectivityHeaderNRMAPayload:request];
    XCTAssertNotNil(payload);
    [NRMAHTTPUtilities attachNRMAPayload:payload to:request];

    XCTAssertEqualObjects([NRMAInFlightTraces currentTraceAttributes],
                          (@{@"trace.id": payload.traceId, @"span.id": payload.id}));
    // The span.id is the parent-id the request carried on the wire.
    XCTAssertTrue([[request valueForHTTPHeaderField:@"traceparent"] containsString:payload.id]);

    [NRMAHTTPUtilities finishTraceForRequest:request];
    XCTAssertNil([NRMAInFlightTraces currentTraceAttributes]);

    // The network event still needs the payload.
    XCTAssertEqual([NRMAHTTPUtilities retrieveNRMAPayload:request], payload);
}

- (void) testRequestTraceIsInFlightUntilRequestFinishesOldEventSystem {
    [self configureAccount];
    NSMutableURLRequest* request = [self request];

    NRMAPayloadContainer* payload = [NRMAHTTPUtilities addConnectivityHeader:request];
    XCTAssertNotNil(payload);
    [NRMAHTTPUtilities attachPayload:payload to:request];

    NSDictionary* expected = @{@"trace.id": @([payload getReference]->getTraceId().c_str()),
                               @"span.id": @([payload getReference]->getId().c_str())};
    XCTAssertEqualObjects([NRMAInFlightTraces currentTraceAttributes], expected);

    [NRMAHTTPUtilities finishTraceForRequest:request];
    XCTAssertNil([NRMAInFlightTraces currentTraceAttributes]);
}

- (void) testFinishingUntracedRequestIsHarmless {
    NSObject* payload = [NSObject new];
    [NRMAInFlightTraces traceStarted:payload traceId:@"trace-1" spanId:@"span-1"];

    [NRMAHTTPUtilities finishTraceForRequest:[self request]];

    XCTAssertEqualObjects([NRMAInFlightTraces currentTraceAttributes][@"trace.id"], @"trace-1");
}

- (void) testAgentRequestIsNotTracked {
    [self configureAccount];
    NSMutableURLRequest* request = [self request];
    [request setValue:@"license" forHTTPHeaderField:X_APP_LICENSE_KEY_REQUEST_HEADER];

    XCTAssertNotNil([NRMAHTTPUtilities addConnectivityHeaderNRMAPayload:request]);
    XCTAssertNil([NRMAInFlightTraces currentTraceAttributes]);
}

- (void) testNoTraceWhenDistributedTracingIsDisabled {
    [self configureAccount];
    [NRMAFlags disableFeatures:NRFeatureFlag_DistributedTracing];

    XCTAssertNil([NRMAHTTPUtilities addConnectivityHeaderNRMAPayload:[self request]]);
    XCTAssertNil([NRMAHTTPUtilities addConnectivityHeader:[self request]]);
    XCTAssertNil([NRMAInFlightTraces currentTraceAttributes]);

    [NRMAFlags enableFeatures:NRFeatureFlag_DistributedTracing];
}

@end
