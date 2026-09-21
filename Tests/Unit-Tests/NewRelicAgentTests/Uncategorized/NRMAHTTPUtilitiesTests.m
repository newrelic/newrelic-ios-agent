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

@end
