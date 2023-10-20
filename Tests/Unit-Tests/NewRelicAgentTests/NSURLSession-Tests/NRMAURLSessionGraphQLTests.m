//
//  NRMAURLSessionGraphQLTests.m
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
#import "NRMAURLSessionGraphQLCPPHelper.h"
#import <objc/runtime.h>
#import "NRMAMethodSwizzling.h"
#import "NRMAFlags.h"

IMP NRMAOriginal__NoticeNetworkRequest;

@interface NRMAURLSessionGraphQLTests : XCTestCase <NSURLSessionDelegate,NSURLSessionDataDelegate,NSURLSessionTaskDelegate>
@property(strong) id mockSession;
@property(strong) NSOperationQueue* queue;
@end

@implementation NRMAURLSessionGraphQLTests

- (void)setUp {
    [super setUp];
    [NRMAURLSessionOverride beginInstrumentation];
    [NRMAURLSessionGraphQLCPPHelper startHelper];

    self.queue = [[NSOperationQueue alloc] init];
    NSURLSession* session = [NSURLSession sessionWithConfiguration:[NSURLSessionConfiguration defaultSessionConfiguration] delegate:self delegateQueue:self.queue];
    self.mockSession = [OCMockObject partialMockForObject:session];
    [NRMAURLSessionGraphQLCPPHelper sharedInstance].networkFinished = NO;
    
}

- (void) swizzleNoticeNetworkRequest {
    id clazz = objc_getClass("NRMANetworkFacade");
    if (clazz) {
        NRMAOriginal__NoticeNetworkRequest = NRMASwapImplementations(clazz,@selector(noticeNetworkRequest:response:withTimer:bytesSent:bytesReceived:responseData:traceHeaders:params:), (IMP)NRMAOverride__noticeNetworkRequest);
    }
}

- (void) deSwizzleNoticeNetworkRequest {
    id clazz = objc_getClass("NRMANetworkFacade");
    if (clazz) {
        NRMASwapImplementations(clazz, @selector(noticeNetworkRequest:response:withTimer:bytesSent:bytesReceived:responseData:traceHeaders:params:), (IMP)NRMAOriginal__NoticeNetworkRequest);
        NRMAOriginal__NoticeNetworkRequest = nil;
    }
}

- (void)tearDown {
    [self.mockSession stopMocking];
    [NRMAURLSessionOverride deinstrument];

    [super tearDown];
}

- (NSMutableURLRequest*) createRequestWithGraphQLHeaders {
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:@"http://www.newrelic.com"]];
    [request setValue:@"Test name" forHTTPHeaderField:@"X-APOLLO-OPERATION-NAME"];
    [request setValue:@"Test type" forHTTPHeaderField:@"X-APOLLO-OPERATION-TYPE"];
    [request setValue:@"Test id" forHTTPHeaderField:@"X-APOLLO-OPERATION-ID"];
    
    return request;
}

- (void) testDataTaskWithRequestGraphQL {
    [self swizzleNoticeNetworkRequest];
    
    NRMAHarvestController* controller = [NRMAHarvestController harvestController];

    NRMAAgentConfiguration *config = [[NRMAAgentConfiguration alloc] initWithAppToken:[[NRMAAppToken alloc] initWithApplicationToken:kNRMA_ENABLED_STAGING_APP_TOKEN]
                                                  collectorAddress:KNRMA_TEST_COLLECTOR_HOST
                                                      crashAddress:nil];
    [NRMAHarvestController initialize:config];

    NRMAHarvesterConfiguration* harvesterConfig = [NRMAHarvesterConfiguration defaultHarvesterConfiguration];
    [harvesterConfig setTrusted_account_key:@"777"];
    [[controller harvester] configureHarvester:harvesterConfig];
    
    [NRMAFlags enableFeatures:NRFeatureFlag_NetworkRequestEvents];
    NSMutableURLRequest * request = [self createRequestWithGraphQLHeaders];
    NSURLSessionDataTask* task = [self.mockSession dataTaskWithRequest:request];
    [task resume];

    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(5 * NSEC_PER_SEC)), dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        [NRMAURLSessionGraphQLCPPHelper sharedInstance].networkFinished = YES;
    });

    while (CFRunLoopGetMain() && ![NRMAURLSessionGraphQLCPPHelper sharedInstance].networkFinished) {}
    
    NSString* json = [[[NRMAURLSessionGraphQLCPPHelper sharedInstance] analytics] analyticsJSONString];
    NSArray* decode = [NSJSONSerialization JSONObjectWithData:[json dataUsingEncoding:NSUTF8StringEncoding]
                                                      options:0
                                                        error:nil];

    XCTAssertNotNil(decode);
    XCTAssertNotNil(decode[0]);
    XCTAssertNotNil(decode[0][@"connectionType"]);
    XCTAssertNotNil(decode[0][@"contentType"]);
    XCTAssertNotNil(decode[0][@"responseTime"]);
    XCTAssertTrue([decode[0][@"requestDomain"] isEqualToString:@"www.newrelic.com"]);
    XCTAssertTrue([decode[0][@"requestMethod"] isEqualToString:@"GET"]);
    XCTAssertTrue([decode[0][@"statusCode"] isEqual:@200]);
    XCTAssertFalse([decode[0][@"bytesReceived"] isEqual:@0]);
    XCTAssertFalse([decode[0][@"requestUrl"] containsString:@"?"]);
    XCTAssertFalse([decode[0][@"requestUrl"] containsString:@"request"]);
    XCTAssertFalse([decode[0][@"requestUrl"] containsString:@"parameter"]);
    XCTAssertTrue([decode[0][@"operationName"] isEqualToString:@"Test name"]);
    XCTAssertTrue([decode[0][@"operationType"] isEqualToString:@"Test type"]);
    XCTAssertTrue([decode[0][@"operationId"] isEqualToString:@"Test id"]);
    [self deSwizzleNoticeNetworkRequest];


}

- (void) testNoticeNetworkRequestGraphQL {
    NRTimer* timer = [[NRTimer alloc] init];
    NSMutableURLRequest * request = [self createRequestWithGraphQLHeaders];
    NSHTTPURLResponse* response = [[NSHTTPURLResponse alloc] initWithURL:request.URL
                                                              statusCode:200
                                                             HTTPVersion:nil
                                                            headerFields:nil];
    XCTAssertNoThrow([NRMANetworkFacade noticeNetworkRequest:request
                                   response:response
                                  withTimer:timer
                                  bytesSent:0
                              bytesReceived:0
                               responseData:nil
                               traceHeaders:nil
                                     params:nil]);
    
}

- (void) testNoticeNetworkRequestFailureWithStartAndEndTimeGraphQL
{
    double startTime = 6000;
    double endTime = 10000;
    NSMutableURLRequest * request = [self createRequestWithGraphQLHeaders];
    
    NSError* error = [NSError errorWithDomain:(NSString*)kCFErrorDomainCFNetwork
                                         code:kCFURLErrorDNSLookupFailed
                                     userInfo:nil];
    
    XCTAssertNoThrow([NRMANetworkFacade noticeNetworkFailure:request
                                  withTimer:[[NRTimer alloc] initWithStartTime:startTime andEndTime:endTime]
                                  withError:error]);
}

- (void) testNoticeNetworkRequestWithTraceHeadersGraphQL
{
    double startTime = 6000;
    double endTime = 10000;
    NSMutableURLRequest * request = [self createRequestWithGraphQLHeaders];
    NSHTTPURLResponse* response = [[NSHTTPURLResponse alloc] initWithURL:request.URL
                                                              statusCode:200
                                                             HTTPVersion:nil
                                                            headerFields:nil];
    XCTAssertNoThrow([NRMANetworkFacade noticeNetworkRequest:request
                                   response:response
                                  withTimer:[[NRTimer alloc] initWithStartTime:startTime andEndTime:endTime]
                                  bytesSent:0
                              bytesReceived:0
                               responseData:nil
                               traceHeaders:@{@"traceparent":@"parent-awesomeid-verycool"}
                                     params:nil]);
}

void NRMAOverride__noticeNetworkRequest(id self,
                                                SEL _cmd,
                                                 NSURLRequest* request,
                                                NSURLResponse* response,
                                                 NRTimer* timer,
                                                 NSUInteger bytesSent,
                                                 NSUInteger bytesReceived,
                                                 NSData* responseData,
                                                 NSDictionary<NSString*,NSString*>* traceHeaders,
                                                 NSDictionary* params){
    [NRMAURLSessionGraphQLCPPHelper noticeNetworkRequest:request response:response withTimer:timer bytesSent:bytesSent bytesReceived:bytesReceived responseData:responseData traceHeaders:traceHeaders params:params];
}

@end
