//
//  NRMAURLSessionHeaderTrackingTests.m
//  Agent
//
//  Created by Mike Bruin on 10/18/23.
//  Copyright © 2023 New Relic. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <XCTest/XCTest.h>
#import <OCMock/OCMock.h>
#import "NRMANetworkFacade.h"
#import "NRMAURLSessionOverride.h"
#import "NewRelicAgentInternal.h"
#import "NRMAAppToken.h"
#import "NRMAHarvestController.h"
#import "NRTestConstants.h"
#import "NRMAFlags.h"
#import "NRMAHTTPUtilities.h"

static NewRelicAgentInternal* _sharedInstance;

@interface NRMAURLSessionHeaderTrackingTests : XCTestCase <NSURLSessionDelegate,NSURLSessionDataDelegate,NSURLSessionTaskDelegate>
@property(strong) id mockSession;
@property(strong) NSOperationQueue* queue;

@property id mockNewRelicInternals;

@property bool finished;

@end

@implementation NRMAURLSessionHeaderTrackingTests

- (void)setUp {
    [super setUp];
    [NRMAFlags enableFeatures: NRFeatureFlag_NetworkRequestEvents | NRFeatureFlag_NewEventSystem];

    [NRMAURLSessionOverride beginInstrumentation];
    self.mockNewRelicInternals = [OCMockObject mockForClass:[NewRelicAgentInternal class]];
    _sharedInstance = [[NewRelicAgentInternal alloc] init];
    _sharedInstance.analyticsController = [[NRMAAnalytics alloc] initWithSessionStartTimeMS:0 with:@[]];
    [[[[self.mockNewRelicInternals stub] classMethod] andReturn:_sharedInstance] sharedInstance];

    self.queue = [[NSOperationQueue alloc] init];
    NSURLSession* session = [NSURLSession sessionWithConfiguration:[NSURLSessionConfiguration defaultSessionConfiguration] delegate:self delegateQueue:self.queue];
    self.mockSession = [OCMockObject partialMockForObject:session];
    
    NRMAHarvestController* controller = [NRMAHarvestController harvestController];

    NRMAAgentConfiguration *config = [[NRMAAgentConfiguration alloc] initWithAppToken:[[NRMAAppToken alloc] initWithApplicationToken:kNRMA_ENABLED_STAGING_APP_TOKEN]
                                                  collectorAddress:KNRMA_TEST_COLLECTOR_HOST
                                                      crashAddress:nil];
    [NRMAHarvestController initialize:config];

    NRMAHarvesterConfiguration* harvesterConfig = [NRMAHarvesterConfiguration defaultHarvesterConfiguration];
    [harvesterConfig setTrusted_account_key:@"777"];
    [[controller harvester] configureHarvester:harvesterConfig];
    
    self.finished = false;
    
}

- (void)tearDown {
    [self.mockSession stopMocking];
    [self.mockNewRelicInternals stopMocking];
    [NRMAURLSessionOverride deinstrument];

    [super tearDown];
}

- (NSMutableURLRequest*) createRequestWithGraphQLHeaders {
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:@"http://www.google.com"]];
    [request setValue:@"Test name" forHTTPHeaderField:@"X-APOLLO-OPERATION-NAME"];
    [request setValue:@"Test type" forHTTPHeaderField:@"X-APOLLO-OPERATION-TYPE"];
    [request setValue:@"Test id" forHTTPHeaderField:@"X-APOLLO-OPERATION-ID"];
    
    return request;
}

- (void) testDataTaskWithRequestGraphQL {
    
    NSMutableURLRequest * request = [self createRequestWithGraphQLHeaders];
    NSURLSessionDataTask* task = [self.mockSession dataTaskWithRequest:request];
    [task resume];
    
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(2 * NSEC_PER_SEC)), dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        self.finished = true;
    });

    while (CFRunLoopGetMain() && !self.finished) {}
    
    NSString* json = [[NewRelicAgentInternal sharedInstance].analyticsController analyticsJSONString];
    NSArray* decode = [NSJSONSerialization JSONObjectWithData:[json dataUsingEncoding:NSUTF8StringEncoding]
                                                      options:0
                                                        error:nil];

    XCTAssertNotNil(decode);
    XCTAssertNotNil(decode[0]);
    XCTAssertNotNil(decode[0][@"connectionType"]);
    XCTAssertNotNil(decode[0][@"contentType"]);
    XCTAssertNotNil(decode[0][@"responseTime"]);
    XCTAssertTrue([decode[0][@"requestDomain"] isEqualToString:@"www.google.com"]);
    XCTAssertTrue([decode[0][@"requestMethod"] isEqualToString:@"GET"]);
    XCTAssertTrue([decode[0][@"statusCode"] isEqual:@200]);
    XCTAssertFalse([decode[0][@"bytesReceived"] isEqual:@0]);
    XCTAssertFalse([decode[0][@"requestUrl"] containsString:@"?"]);
    XCTAssertFalse([decode[0][@"requestUrl"] containsString:@"request"]);
    XCTAssertFalse([decode[0][@"requestUrl"] containsString:@"parameter"]);
    XCTAssertTrue([decode[0][@"operationName"] isEqualToString:@"Test name"]);
    XCTAssertTrue([decode[0][@"operationType"] isEqualToString:@"Test type"]);
    XCTAssertTrue([decode[0][@"operationId"] isEqualToString:@"Test id"]);

}

- (void) testDataTaskWithRequestHeaderTracking {
    
    [NRMAHTTPUtilities addHTTPHeaderTrackingFor:@[@"TEST_CUSTOM", @"TEST_NOT_PRESENT"]];

    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:@"http://www.gooogle.com"]];
    [request setValue:@"Test custom" forHTTPHeaderField:@"TEST_CUSTOM"];
    NSURLSessionDataTask* task = [self.mockSession dataTaskWithRequest:request];
    [task resume];

    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(2 * NSEC_PER_SEC)), dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        self.finished = true;
    });

    while (CFRunLoopGetMain() && !self.finished) {}
    
    NSString* json = [[NewRelicAgentInternal sharedInstance].analyticsController analyticsJSONString];
    NSArray* decode = [NSJSONSerialization JSONObjectWithData:[json dataUsingEncoding:NSUTF8StringEncoding]
                                                      options:0
                                                        error:nil];
    
    XCTAssertNotNil(decode);
    XCTAssertNotNil(decode[0]);
    XCTAssertNotNil(decode[0][@"connectionType"]);
    XCTAssertNotNil(decode[0][@"contentType"]);
    XCTAssertNotNil(decode[0][@"responseTime"]);
    XCTAssertTrue([decode[0][@"requestDomain"] isEqualToString:@"www.gooogle.com"]);
    XCTAssertTrue([decode[0][@"requestMethod"] isEqualToString:@"GET"]);
    XCTAssertTrue([decode[0][@"statusCode"] isEqual:@200]);
    XCTAssertFalse([decode[0][@"bytesReceived"] isEqual:@0]);
    XCTAssertFalse([decode[0][@"requestUrl"] containsString:@"?"]);
    XCTAssertFalse([decode[0][@"requestUrl"] containsString:@"request"]);
    XCTAssertFalse([decode[0][@"requestUrl"] containsString:@"parameter"]);
    XCTAssertTrue([decode[0][@"TEST_CUSTOM"] isEqualToString:@"Test custom"]);
    XCTAssertNil(decode[0][@"TEST_NOT_PRESENT"]);

}

- (void) testDataTaskErrorWithRequestHeaderTracking {
    [NRMAHTTPUtilities addHTTPHeaderTrackingFor:@[@"TEST_CUSTOM", @"TEST_NOT_PRESENT"]];

    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:@"www.gooogle.com"]];
    [request setValue:@"Test custom" forHTTPHeaderField:@"TEST_CUSTOM"];
    NSURLSessionDataTask* task = [self.mockSession dataTaskWithRequest:request];
    [task resume];

    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(2 * NSEC_PER_SEC)), dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        self.finished = true;
    });

    while (CFRunLoopGetMain() && !self.finished) {}
    
    NSString* json = [[NewRelicAgentInternal sharedInstance].analyticsController analyticsJSONString];
    NSArray* decode = [NSJSONSerialization JSONObjectWithData:[json dataUsingEncoding:NSUTF8StringEncoding]
                                                      options:0
                                                        error:nil];
    
    XCTAssertNotNil(decode);
    XCTAssertNotNil(decode[0]);
    XCTAssertNotNil(decode[0][@"connectionType"]);
    XCTAssertNotNil(decode[0][@"id"]);
    XCTAssertNotNil(decode[0][@"responseTime"]);
    XCTAssertTrue([decode[0][@"requestUrl"] isEqualToString:@"www.gooogle.com"]);
    XCTAssertTrue([decode[0][@"errorType"] isEqualToString:@"NetworkFailure"]);
    XCTAssertTrue([decode[0][@"requestMethod"] isEqualToString:@"GET"]);
    XCTAssertTrue([decode[0][@"networkErrorCode"] isEqual:@-1002]);
    XCTAssertFalse([decode[0][@"bytesReceived"] isEqual:@0]);
    XCTAssertFalse([decode[0][@"requestUrl"] containsString:@"?"]);
    XCTAssertFalse([decode[0][@"requestUrl"] containsString:@"request"]);
    XCTAssertFalse([decode[0][@"requestUrl"] containsString:@"parameter"]);
    XCTAssertTrue([decode[0][@"TEST_CUSTOM"] isEqualToString:@"Test custom"]);
    
}

@end
