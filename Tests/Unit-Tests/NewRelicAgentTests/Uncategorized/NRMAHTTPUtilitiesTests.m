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

@interface NRMAHTTPUtilitiesTests : XCTestCase
@end

@implementation NRMAHTTPUtilitiesTests

- (void)setUp {
    [super setUp];
}

- (void)tearDown {
    // Put teardown code here. This method is called after the invocation of each test method in the class.

}

- (void) testDistributedTracingHeaders {

    NRMAAgentConfiguration *config = [[NRMAAgentConfiguration alloc] initWithAppToken:[[NRMAAppToken alloc] initWithApplicationToken:kNRMA_ENABLED_STAGING_APP_TOKEN]
                                                  collectorAddress:KNRMA_TEST_COLLECTOR_HOST
                                                      crashAddress:nil];
    [NRMAHarvestController initialize:config];

    NSURLRequest* request = [NSURLRequest requestWithURL:[NSURL URLWithString:@"google.com"]];

    NSMutableURLRequest* mutableRequest = [NRMAHTTPUtilities addCrossProcessIdentifier:request];
    NRMAPayloadContainer* payload = [NRMAHTTPUtilities addConnectivityHeader:mutableRequest];

    XCTAssertNotNil(payload);

    NSDictionary<NSString *, NSString *>* headers = [mutableRequest allHTTPHeaderFields];
    XCTAssertNotNil(headers[@"newrelic"]);
    XCTAssertNotNil(headers[@"traceparent"]);
    XCTAssertNotNil(headers[@"tracestate"]);

}

@end
