//
//  APINetworkNoticeTest.m
//  NewRelicAgent
//
//  Created by Bryce Buchanan on 11/7/13.
//  Copyright © 2023 New Relic. All rights reserved.
//

#import <XCTest/XCTest.h>
#import "NRMeasurementConsumerHelper.h"
#import "NRMAMeasurements.h"
#import "NRMAHTTPTransactionMeasurement.h"
#import "NRMATaskQueue.h"
#import "NRMANetworkFacade.h"
#import "NewRelicAgentInternal.h"
@interface NRMATaskQueue ()
+ (NRMATaskQueue*) taskQueue;
- (void) dequeue;
@end

@interface APINetworkNoticeTest : XCTestCase
{
    NRMAMeasurementConsumerHelper* helper;
}
@end

@implementation APINetworkNoticeTest

- (void)setUp
{
    [super setUp];
    helper = [[NRMAMeasurementConsumerHelper alloc] initWithType:NRMAMT_HTTPTransaction];
    [NRMAMeasurements initializeMeasurements];
    [NRMAMeasurements addMeasurementConsumer:helper];
}

- (void)tearDown
{
    [NRMAMeasurements removeMeasurementConsumer:helper];
    [NRMAMeasurements shutdown];
    [super tearDown];
}

- (void) testNoticeNetworkRequest
{
    NRTimer* timer = [[NRTimer alloc] init];
    NSMutableURLRequest* request = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:@"google.com"]];
    NSHTTPURLResponse* response = [[NSHTTPURLResponse alloc] initWithURL:request.URL
                                                              statusCode:200
                                                             HTTPVersion:nil
                                                            headerFields:nil];
    [NRMANetworkFacade noticeNetworkRequest:request
                                   response:response
                                  withTimer:timer
                                  bytesSent:0
                              bytesReceived:0
                               responseData:nil
                               traceHeaders:nil
                                     params:nil];

    while(CFRunLoopGetCurrent() && !helper.result) {}

    NRMAHTTPTransactionMeasurement* result = (NRMAHTTPTransactionMeasurement*)helper.result;
    XCTAssertEqualObjects(result.url, @"google.com", @"result url matches recorded url");
    XCTAssertEqual(result.startTime, timer.startTimeMillis, @"Result start time did not match timer start time.");
    XCTAssertEqual((long long)result.endTime,  (long long)timer.endTimeMillis,@"Result end time did not match timer end time.");
    XCTAssertEqual(result.statusCode, 200, @"Result status code did not match expected status code.");
}

- (void) testNoticeNilValues
{

    NSMutableURLRequest* request = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:@"google.com"]];

    NSHTTPURLResponse* response = [[NSHTTPURLResponse alloc] initWithURL:request.URL
                                                              statusCode:200
                                                             HTTPVersion:nil
                                                            headerFields:nil];
    XCTAssertNoThrow([NRMANetworkFacade noticeNetworkRequest:request
                                                    response:response
                                                   withTimer:nil
                                                   bytesSent:0
                                               bytesReceived:0
                                                responseData:nil
                                                traceHeaders:nil
                                                      params:nil], @"crashed because of nil values");
}

- (void) testNoticeNetworkRequestWithStartAndEndTime
{
    double startTime = 6000;
    double endTime = 10000;
    NSMutableURLRequest* request = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:@"google.com"]];
    NSHTTPURLResponse* response = [[NSHTTPURLResponse alloc] initWithURL:request.URL
                                                              statusCode:200
                                                             HTTPVersion:nil
                                                            headerFields:nil];
    [NRMANetworkFacade noticeNetworkRequest:request
                                   response:response
                                  withTimer:[[NRTimer alloc] initWithStartTime:startTime andEndTime:endTime]
                                  bytesSent:0
                              bytesReceived:0
                               responseData:nil
                               traceHeaders:nil 
                                     params:nil];

    while(CFRunLoopGetCurrent() && !helper.result) {}

    NRMAHTTPTransactionMeasurement* result = (NRMAHTTPTransactionMeasurement*)helper.result;

    XCTAssertEqualObjects(result.url, @"google.com", @"Result url does not match recorded url.");
    XCTAssertEqual(result.startTime, (double) 6000, @"Result start time did not match expected start time.");
    XCTAssertEqual((long long)result.endTime,(long long) 10000,@"Result end time did not match expected end time.");
    XCTAssertEqual(result.totalTime, 4000);
    XCTAssertEqual(result.statusCode, 200, @"Result status code did not match expected status code.");
}

- (void) testNoticeNetworkRequestFailureWithStartAndEndTime
{
    double startTime = 6000;
    double endTime = 10000;
    NSMutableURLRequest* request = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:@"google.com"]];

    NSError* error = [NSError errorWithDomain:(NSString*)kCFErrorDomainCFNetwork
                                         code:kCFURLErrorDNSLookupFailed
                                     userInfo:nil];

    [NRMANetworkFacade noticeNetworkFailure:request
                                  withTimer:[[NRTimer alloc] initWithStartTime:startTime andEndTime:endTime]
                                  withError:error];

    while(CFRunLoopGetCurrent() && !helper.result) {}

    NRMAHTTPTransactionMeasurement* result = (NRMAHTTPTransactionMeasurement*)helper.result;

    XCTAssertEqualObjects(result.url, @"google.com", @"Result url does not match recorded url.");
    XCTAssertEqual(result.startTime, (double) 6000, @"Result start time did not match expected start time.");
    XCTAssertEqual((long long)result.endTime,(long long) 10000,@"Result end time did not match expected end time.");
    XCTAssertEqual(result.totalTime, 4000);
    XCTAssertEqual(result.statusCode, 0, @"Result status code did not match expected status code.");
}

- (void) testNoticeNetworkRequestWithTraceHeaders
{
    double startTime = 6000;
    double endTime = 10000;
    NSMutableURLRequest* request = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:@"google.com"]];
    NSHTTPURLResponse* response = [[NSHTTPURLResponse alloc] initWithURL:request.URL
                                                              statusCode:200
                                                             HTTPVersion:nil
                                                            headerFields:nil];
    [NRMANetworkFacade noticeNetworkRequest:request
                                   response:response
                                  withTimer:[[NRTimer alloc] initWithStartTime:startTime andEndTime:endTime]
                                  bytesSent:0
                              bytesReceived:0
                               responseData:nil
                               traceHeaders:@{@"traceparent":@"parent-awesomeid-verycool"}
                                     params:nil];

    while(CFRunLoopGetCurrent() && !helper.result) {}

    NRMAHTTPTransactionMeasurement* result = (NRMAHTTPTransactionMeasurement*)helper.result;

    XCTAssertEqualObjects(result.url, @"google.com", @"Result url does not match recorded url.");
    XCTAssertEqual(result.startTime, (double) 6000, @"Result start time did not match expected start time.");
    XCTAssertEqual((long long)result.endTime,(long long) 10000,@"Result end time did not match expected end time.");
    XCTAssertEqual(result.totalTime, 4000);
    XCTAssertEqual(result.statusCode, 200, @"Result status code did not match expected status code.");
}

@end
