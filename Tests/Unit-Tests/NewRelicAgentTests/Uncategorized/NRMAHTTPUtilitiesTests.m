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
#import "NRMABase64.h"

@interface NRMAHTTPUtilitiesTests : XCTestCase
@end

@implementation NRMAHTTPUtilitiesTests

- (void)testDistributedTracingHeadersNoTrustedAccountKey {
    NRMAAgentConfiguration *config = [[NRMAAgentConfiguration alloc] initWithAppToken:[[NRMAAppToken alloc] initWithApplicationToken:kNRMA_ENABLED_STAGING_APP_TOKEN]
                                                  collectorAddress:KNRMA_TEST_COLLECTOR_HOST
                                                      crashAddress:nil];
    [NRMAHarvestController initialize:config];

    NSURLRequest* request = [NSURLRequest requestWithURL:[NSURL URLWithString:@"google.com"]];

    NSMutableURLRequest* mutableRequest = [NRMAHTTPUtilities addCrossProcessIdentifier:request];
#ifdef USE_INTEGRATED_EVENT_MANAGER
    NRMAPayload* payload = [NRMAHTTPUtilities addConnectivityHeader:mutableRequest];
#else
    NRMAPayloadContainer* payload = [NRMAHTTPUtilities addConnectivityHeader:mutableRequest];
#endif
    XCTAssertNotNil(payload);

    NSDictionary<NSString *, NSString *>* headers = [mutableRequest allHTTPHeaderFields];
    NSString* newrelicHeader = headers[@"newrelic"];

    NSDictionary* decodedDict = [NSJSONSerialization JSONObjectWithData:[[NSData alloc] initWithBase64EncodedString:newrelicHeader options:0]
                                                           options:0
                                                             error:nil];
    // By default no "tk" is set, so we test for the default behavior of not including tk if no trust key is found.
    XCTAssertNil(decodedDict[@"d"][@"tk"]);

    NSString* traceparent = headers[@"traceparent"];
    XCTAssertNotNil(traceparent);

    NSString* tracestate = headers[@"tracestate"];
    XCTAssertTrue([tracestate hasPrefix: @"@nr=0-2-0-0"]);
}

- (void)testDistributedTracingHeadersWithTrustedAccountKey {
    NRMAHarvestController* controller = [NRMAHarvestController harvestController];

    NRMAAgentConfiguration *config = [[NRMAAgentConfiguration alloc] initWithAppToken:[[NRMAAppToken alloc] initWithApplicationToken:kNRMA_ENABLED_STAGING_APP_TOKEN]
                                                  collectorAddress:KNRMA_TEST_COLLECTOR_HOST
                                                      crashAddress:nil];
    [NRMAHarvestController initialize:config];

    NRMAHarvesterConfiguration* harvesterConfig = [NRMAHarvesterConfiguration defaultHarvesterConfiguration];
    [harvesterConfig setTrusted_account_key:@"777"];
    [[controller harvester] configureHarvester:harvesterConfig];

    NSURLRequest* request = [NSURLRequest requestWithURL:[NSURL URLWithString:@"google.com"]];

    NSMutableURLRequest* mutableRequest = [NRMAHTTPUtilities addCrossProcessIdentifier:request];
#ifdef USE_INTEGRATED_EVENT_MANAGER
    NRMAPayload* payload = [NRMAHTTPUtilities addConnectivityHeader:mutableRequest];
#else
    NRMAPayloadContainer* payload = [NRMAHTTPUtilities addConnectivityHeader:mutableRequest];
#endif
    
    XCTAssertNotNil(payload);

    NSDictionary<NSString *, NSString *>* headers = [mutableRequest allHTTPHeaderFields];

    NSString* newrelicHeader = headers[@"newrelic"];
    NSDictionary* decodedDict = [NSJSONSerialization JSONObjectWithData:[[NSData alloc] initWithBase64EncodedString:newrelicHeader options:0]
                                                           options:0
                                                             error:nil];
    XCTAssertTrue([decodedDict[@"d"][@"tk"] isEqualToString: @"777"]);

    NSString* traceparent = headers[@"traceparent"];
    XCTAssertNotNil(traceparent);

    NSString* tracestate = headers[@"tracestate"];
    XCTAssertTrue([tracestate hasPrefix: @"777@nr=0-2-0-0"]);
}

@end
