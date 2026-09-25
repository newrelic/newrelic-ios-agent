//
//  NRMAHTTPUtilitiesTests.m
//  NewRelicAgent
//
//  Created on 12/13/17.
//  Copyright © 2023 New Relic. All rights reserved.
//


#import <XCTest/XCTest.h>
#import "NRMAHTTPUtilities.h"
#import "NRMAAppToken.h"
#import "NRMAHarvestController.h"
#import "NRTestConstants.h"
#import "NRMAFlags.h"
#import "NewRelic.h"

@interface NRMAHTTPUtilitiesTests : XCTestCase
@end

@implementation NRMAHTTPUtilitiesTests

- (void)testDistributedTracingHeadersNoTrustedAccountKey {
    NRMAAgentConfiguration *config = [[NRMAAgentConfiguration alloc] initWithAppToken:[[NRMAAppToken alloc] initWithApplicationToken:kNRMA_ENABLED_STAGING_APP_TOKEN]
                                                  collectorAddress:KNRMA_TEST_COLLECTOR_HOST
                                                      crashAddress:nil];
    [NRMAHarvestController initialize:config];
    NRMAHarvestController* controller = [NRMAHarvestController harvestController];

    NRMAHarvesterConfiguration* harvesterConfig = [NRMAHarvesterConfiguration defaultHarvesterConfiguration];
    harvesterConfig.account_id = 1234567;
    harvesterConfig.application_id = 1234567;
    [[controller harvester] configureHarvester:harvesterConfig];
    
    NSURLRequest* request = [NSURLRequest requestWithURL:[NSURL URLWithString:@"google.com"]];

    NSMutableURLRequest* mutableRequest = [NRMAHTTPUtilities addCrossProcessIdentifier:request];

    NRMAPayloadContainer* payload = [NRMAHTTPUtilities addConnectivityHeader:mutableRequest];
    XCTAssertNotNil(payload);

    NSDictionary<NSString *, NSString *>* headers = [mutableRequest allHTTPHeaderFields];

    // The proprietary "newrelic" header is no longer sent for Distributed Tracing.
    XCTAssertNil(headers[@"newrelic"]);

    NSString* traceparent = headers[@"traceparent"];
    XCTAssertNotNil(traceparent);

    NSString* tracestate = headers[@"tracestate"];
    XCTAssertTrue([tracestate hasPrefix: @"@nr=0-2-1234567-1234567"]);
}

- (void)testDistributedTracingHeadersNRMAPayloadNoTrustedAccountKey {
    NRMAAgentConfiguration *config = [[NRMAAgentConfiguration alloc] initWithAppToken:[[NRMAAppToken alloc] initWithApplicationToken:kNRMA_ENABLED_STAGING_APP_TOKEN]
                                                  collectorAddress:KNRMA_TEST_COLLECTOR_HOST
                                                      crashAddress:nil];
    [NRMAHarvestController initialize:config];
    NRMAHarvestController* controller = [NRMAHarvestController harvestController];

    NRMAHarvesterConfiguration* harvesterConfig = [NRMAHarvesterConfiguration defaultHarvesterConfiguration];
    harvesterConfig.account_id = 1234567;
    harvesterConfig.application_id = 1234567;
    [[controller harvester] configureHarvester:harvesterConfig];
    NSURLRequest* request = [NSURLRequest requestWithURL:[NSURL URLWithString:@"google.com"]];

    NSMutableURLRequest* mutableRequest = [NRMAHTTPUtilities addCrossProcessIdentifier:request];
    NRMAPayload* payload = [NRMAHTTPUtilities addConnectivityHeaderNRMAPayload:mutableRequest];

    XCTAssertNotNil(payload);

    NSDictionary<NSString *, NSString *>* headers = [mutableRequest allHTTPHeaderFields];

    // The proprietary "newrelic" header is no longer sent for Distributed Tracing.
    XCTAssertNil(headers[@"newrelic"]);

    NSString* traceparent = headers[@"traceparent"];
    XCTAssertNotNil(traceparent);

    NSString* tracestate = headers[@"tracestate"];
    XCTAssertTrue([tracestate hasPrefix: @"@nr=0-2-1234567-1234567"]);
}

- (void)testNoAccountIdNRMAPayload {
    [NRMAFlags enableFeatures: NRFeatureFlag_NewEventSystem];
    NRMAAgentConfiguration *config = [[NRMAAgentConfiguration alloc] initWithAppToken:[[NRMAAppToken alloc] initWithApplicationToken:kNRMA_ENABLED_STAGING_APP_TOKEN]
                                                  collectorAddress:KNRMA_TEST_COLLECTOR_HOST
                                                      crashAddress:nil];
    [NRMAHarvestController initialize:config];
    
    NSURLRequest* request = [NSURLRequest requestWithURL:[NSURL URLWithString:@"google.com"]];

    NSMutableURLRequest* mutableRequest = [NRMAHTTPUtilities addCrossProcessIdentifier:request];

    NRMAPayloadContainer* payload = [NRMAHTTPUtilities addConnectivityHeader:mutableRequest];
    XCTAssertNil(payload);
    [NRMAFlags disableFeatures: NRFeatureFlag_NewEventSystem];
}

- (void)testNoAccountIdPayload {
    NRMAAgentConfiguration *config = [[NRMAAgentConfiguration alloc] initWithAppToken:[[NRMAAppToken alloc] initWithApplicationToken:kNRMA_ENABLED_STAGING_APP_TOKEN]
                                                  collectorAddress:KNRMA_TEST_COLLECTOR_HOST
                                                      crashAddress:nil];
    [NRMAHarvestController initialize:config];
    
    NSURLRequest* request = [NSURLRequest requestWithURL:[NSURL URLWithString:@"google.com"]];

    NSMutableURLRequest* mutableRequest = [NRMAHTTPUtilities addCrossProcessIdentifier:request];

    NRMAPayloadContainer* payload = [NRMAHTTPUtilities addConnectivityHeader:mutableRequest];
    XCTAssertNil(payload);
}

- (void)testDistributedTracingHeadersWithTrustedAccountKey {
    NRMAAgentConfiguration *config = [[NRMAAgentConfiguration alloc] initWithAppToken:[[NRMAAppToken alloc] initWithApplicationToken:kNRMA_ENABLED_STAGING_APP_TOKEN]
                                                  collectorAddress:KNRMA_TEST_COLLECTOR_HOST
                                                      crashAddress:nil];
    [NRMAHarvestController initialize:config];
    NRMAHarvestController* controller = [NRMAHarvestController harvestController];

    NRMAHarvesterConfiguration* harvesterConfig = [NRMAHarvesterConfiguration defaultHarvesterConfiguration];
    harvesterConfig.account_id = 1234567;
    harvesterConfig.application_id = 1234567;
    [harvesterConfig setTrusted_account_key:@"777"];
    [[controller harvester] configureHarvester:harvesterConfig];

    NSURLRequest* request = [NSURLRequest requestWithURL:[NSURL URLWithString:@"google.com"]];

    NSMutableURLRequest* mutableRequest = [NRMAHTTPUtilities addCrossProcessIdentifier:request];

    NRMAPayloadContainer* payload = [NRMAHTTPUtilities addConnectivityHeader:mutableRequest];
    
    XCTAssertNotNil(payload);

    NSDictionary<NSString *, NSString *>* headers = [mutableRequest allHTTPHeaderFields];

    // The proprietary "newrelic" header is no longer sent for Distributed Tracing.
    XCTAssertNil(headers[@"newrelic"]);

    NSString* traceparent = headers[@"traceparent"];
    XCTAssertNotNil(traceparent);

    NSString* tracestate = headers[@"tracestate"];
    XCTAssertTrue([tracestate hasPrefix: @"777@nr=0-2-1234567-1234567"]);
}

- (void)testDistributedTracingHeadersNRMAPayloadWithTrustedAccountKey {
    NRMAAgentConfiguration *config = [[NRMAAgentConfiguration alloc] initWithAppToken:[[NRMAAppToken alloc] initWithApplicationToken:kNRMA_ENABLED_STAGING_APP_TOKEN]
                                                  collectorAddress:KNRMA_TEST_COLLECTOR_HOST
                                                      crashAddress:nil];
    [NRMAHarvestController initialize:config];
    NRMAHarvestController* controller = [NRMAHarvestController harvestController];

    NRMAHarvesterConfiguration* harvesterConfig = [NRMAHarvesterConfiguration defaultHarvesterConfiguration];
    harvesterConfig.account_id = 1234567;
    harvesterConfig.application_id = 1234567;
    [harvesterConfig setTrusted_account_key:@"777"];
    [[controller harvester] configureHarvester:harvesterConfig];

    NSURLRequest* request = [NSURLRequest requestWithURL:[NSURL URLWithString:@"google.com"]];

    NSMutableURLRequest* mutableRequest = [NRMAHTTPUtilities addCrossProcessIdentifier:request];
    NRMAPayload* payload = [NRMAHTTPUtilities addConnectivityHeaderNRMAPayload:mutableRequest];

    XCTAssertNotNil(payload);

    NSDictionary<NSString *, NSString *>* headers = [mutableRequest allHTTPHeaderFields];

    // The proprietary "newrelic" header is no longer sent for Distributed Tracing.
    XCTAssertNil(headers[@"newrelic"]);

    NSString* traceparent = headers[@"traceparent"];
    XCTAssertNotNil(traceparent);

    NSString* tracestate = headers[@"tracestate"];
    XCTAssertTrue([tracestate hasPrefix: @"777@nr=0-2-1234567-1234567"]);
}

#pragma mark - Distributed-tracing timestamp units

// The NR tracestate entry's timestamp and the DT payload's `ti` field are specified in
// milliseconds since the epoch. +startTrip previously seeded NRMAPayload.timestamp from
// -timeIntervalSince1970, which is in SECONDS, so every header generated under the new event
// system carried a value 1000x too small -- while the legacy C++ path, which seeds from
// chrono::milliseconds, was correct. Nothing covered +startTrip's own output, which is why the
// divergence went unnoticed: the DT unit tests all construct NRMAPayload with millisecond
// literals of their own.
//
// A seconds-valued timestamp for any date this century is ~1.7e9, three orders of magnitude
// below this bound; a millisecond value only falls below it for dates before 1973. So the
// bound alone pins the unit, independently of the wall-clock window checked alongside it.
static const long long kMinimumPlausibleEpochMillis = 100000000000LL;

- (long long) wallClockMillis {
    return (long long)([[NSDate date] timeIntervalSince1970] * 1000);
}

- (void) configureHarvesterForDistributedTracing {
    NRMAAgentConfiguration *config = [[NRMAAgentConfiguration alloc] initWithAppToken:[[NRMAAppToken alloc] initWithApplicationToken:kNRMA_ENABLED_STAGING_APP_TOKEN]
                                                  collectorAddress:KNRMA_TEST_COLLECTOR_HOST
                                                      crashAddress:nil];
    [NRMAHarvestController initialize:config];
    NRMAHarvestController* controller = [NRMAHarvestController harvestController];

    NRMAHarvesterConfiguration* harvesterConfig = [NRMAHarvesterConfiguration defaultHarvesterConfiguration];
    harvesterConfig.account_id = 1234567;
    harvesterConfig.application_id = 1234567;
    [harvesterConfig setTrusted_account_key:@"777"];
    [[controller harvester] configureHarvester:harvesterConfig];
}

// Extracts the timestamp from the NR entry of a tracestate header, whose layout is
// "<trustedAccountKey>@nr=<version>-<parentType>-<accountId>-<appId>-<spanId>-<transactionId>-
// <sampled>-<priority>-<timestamp>".
- (long long) traceStateTimestampFrom:(NSString*)tracestate {
    XCTAssertNotNil(tracestate, @"expected a tracestate header");

    NSRange separator = [tracestate rangeOfString:@"="];
    XCTAssertTrue(separator.location != NSNotFound, @"malformed tracestate: %@", tracestate);

    NSArray<NSString*>* fields = [[tracestate substringFromIndex:NSMaxRange(separator)] componentsSeparatedByString:@"-"];
    XCTAssertEqual(fields.count, (NSUInteger)9, @"unexpected NR tracestate layout: %@", tracestate);

    return [fields.lastObject longLongValue];
}

- (void) testGeneratedNRMAPayloadTimestampIsInMilliseconds {
    NRMAFeatureFlags originalFlags = [NRMAFlags featureFlags];
    [NRMAFlags enableFeatures:NRFeatureFlag_DistributedTracing | NRFeatureFlag_NewEventSystem];
    [self configureHarvesterForDistributedTracing];

    long long before = [self wallClockMillis];
    NRMAPayload* payload = [NRMAHTTPUtilities generateNRMAPayload];
    long long after = [self wallClockMillis];

    XCTAssertNotNil(payload, @"expected a payload once the harvester is configured");
    XCTAssertTrue(payload.timestamp >= kMinimumPlausibleEpochMillis,
                  @"payload timestamp must be in milliseconds, got %lld", payload.timestamp);
    XCTAssertTrue(payload.timestamp >= before && payload.timestamp <= after,
                  @"payload timestamp %lld must fall inside [%lld, %lld]", payload.timestamp, before, after);

    [NRMAFlags setFeatureFlags:originalFlags];
}

- (void) testGeneratedTraceStateTimestampIsInMillisecondsWithNRMAPayload {
    NRMAFeatureFlags originalFlags = [NRMAFlags featureFlags];
    [NRMAFlags enableFeatures:NRFeatureFlag_DistributedTracing | NRFeatureFlag_NewEventSystem];
    [self configureHarvesterForDistributedTracing];

    long long before = [self wallClockMillis];
    NSDictionary<NSString*, NSString*>* headers = [NRMAHTTPUtilities generateConnectivityHeadersWithNRMAPayload:[NRMAHTTPUtilities generateNRMAPayload]];
    long long after = [self wallClockMillis];

    long long timestamp = [self traceStateTimestampFrom:headers[@"tracestate"]];
    XCTAssertTrue(timestamp >= kMinimumPlausibleEpochMillis,
                  @"tracestate timestamp must be in milliseconds, got %lld", timestamp);
    XCTAssertTrue(timestamp >= before && timestamp <= after,
                  @"tracestate timestamp %lld must fall inside [%lld, %lld]", timestamp, before, after);

    [NRMAFlags setFeatureFlags:originalFlags];
}

// The legacy path was already correct; this pins it so the two event systems cannot drift
// apart again.
- (void) testGeneratedTraceStateTimestampIsInMillisecondsWithCppPayload {
    NRMAFeatureFlags originalFlags = [NRMAFlags featureFlags];
    [NRMAFlags enableFeatures:NRFeatureFlag_DistributedTracing];
    [NRMAFlags disableFeatures:NRFeatureFlag_NewEventSystem];
    [self configureHarvesterForDistributedTracing];

    long long before = [self wallClockMillis];
    NSDictionary<NSString*, NSString*>* headers = [NRMAHTTPUtilities generateConnectivityHeadersWithPayload:[NRMAHTTPUtilities generatePayload]];
    long long after = [self wallClockMillis];

    long long timestamp = [self traceStateTimestampFrom:headers[@"tracestate"]];
    XCTAssertTrue(timestamp >= kMinimumPlausibleEpochMillis,
                  @"tracestate timestamp must be in milliseconds, got %lld", timestamp);
    XCTAssertTrue(timestamp >= before && timestamp <= after,
                  @"tracestate timestamp %lld must fall inside [%lld, %lld]", timestamp, before, after);

    [NRMAFlags setFeatureFlags:originalFlags];
}

#pragma mark - +generateDistributedTracingContext

// The context must describe ONE trace in both representations: the W3C headers to put on the wire
// and the identity to hand back through a notice* API. Two separate generator calls would mint two
// unrelated traces, which is the trap this API exists to remove.
- (void) assertContextDescribesOneTrace:(NSDictionary<NSString*,NSString*>*)context {
    NSString* traceparent = context[@"traceparent"];
    XCTAssertNotNil(traceparent, @"context must carry the wire headers");
    XCTAssertNotNil(context[@"tracestate"], @"context must carry the wire headers");

    NSArray<NSString*>* fields = [traceparent componentsSeparatedByString:@"-"];
    XCTAssertEqual(fields.count, (NSUInteger)4, @"malformed traceparent: %@", traceparent);

    XCTAssertEqualObjects(context[@"trace.id"], fields[1], @"trace.id must match the traceparent's trace-id");
    XCTAssertEqualObjects(context[@"id"], fields[2], @"id must match the traceparent's span-id");
    XCTAssertEqualObjects(context[@"guid"], fields[2], @"guid is the deprecated spelling of id");
}

- (void) testGeneratedContextDescribesOneTraceWithNewEventSystem {
    NRMAFeatureFlags originalFlags = [NRMAFlags featureFlags];
    [NRMAFlags enableFeatures:NRFeatureFlag_DistributedTracing | NRFeatureFlag_NewEventSystem];
    [self configureHarvesterForDistributedTracing];

    [self assertContextDescribesOneTrace:[NewRelic generateDistributedTracingContext]];

    [NRMAFlags setFeatureFlags:originalFlags];
}

- (void) testGeneratedContextDescribesOneTraceWithCppPayload {
    NRMAFeatureFlags originalFlags = [NRMAFlags featureFlags];
    [NRMAFlags enableFeatures:NRFeatureFlag_DistributedTracing];
    [NRMAFlags disableFeatures:NRFeatureFlag_NewEventSystem];
    [self configureHarvesterForDistributedTracing];

    [self assertContextDescribesOneTrace:[NewRelic generateDistributedTracingContext]];

    [NRMAFlags setFeatureFlags:originalFlags];
}

// Successive calls are separate traces; nothing is cached or reused.
- (void) testEachGeneratedContextIsADistinctTrace {
    NRMAFeatureFlags originalFlags = [NRMAFlags featureFlags];
    [NRMAFlags enableFeatures:NRFeatureFlag_DistributedTracing | NRFeatureFlag_NewEventSystem];
    [self configureHarvesterForDistributedTracing];

    NSDictionary<NSString*,NSString*>* first = [NewRelic generateDistributedTracingContext];
    NSDictionary<NSString*,NSString*>* second = [NewRelic generateDistributedTracingContext];

    XCTAssertNotEqualObjects(first[@"trace.id"], second[@"trace.id"]);
    XCTAssertNotEqualObjects(first[@"id"], second[@"id"]);

    [NRMAFlags setFeatureFlags:originalFlags];
}

@end
