//
//  NRMASessionExclusivityTests.m
//  NewRelicAgent
//
//  Created by Bryce Buchanan on 1/5/15.
//  Copyright © 2023 New Relic. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <XCTest/XCTest.h>
#import <OCMock/OCMock.h>
#import "NRMANetworkFacade.h"
#import "NRMAURLSessionOverride.h"
#import "NewRelicAgentInternal.h"
#import "NRMAAppToken.h"
#import "NRMAHarvestController.h"
#import "NRMAFlags.h"
#import "NRTestConstants.h"
@interface NRMASessionExclusivityWithDelegateTests : XCTestCase <NSURLSessionDelegate,NSURLSessionDataDelegate,NSURLSessionTaskDelegate>
@property(strong) id mockSession;
@property(strong) id mockNetwork;
@property(strong) NSOperationQueue* queue;
@property(nonatomic) BOOL networkFinished;
// Set when the agent's instrumentation captures the request via either the
// success path (noticeNetworkRequest) or the failure path (noticeNetworkFailure),
// as opposed to the test simply timing out.
@property(nonatomic) BOOL didCaptureRequest;
@end

@implementation NRMASessionExclusivityWithDelegateTests

- (void)setUp {
    [super setUp];
    [NRMAURLSessionOverride beginInstrumentation];

    self.queue = [[NSOperationQueue alloc] init];
    NSURLSession* session = [NSURLSession sessionWithConfiguration:[NSURLSessionConfiguration defaultSessionConfiguration] delegate:self delegateQueue:self.queue];
    self.mockSession = [OCMockObject partialMockForObject:session];
    self.networkFinished = NO;
    self.didCaptureRequest = NO;
    self.mockNetwork = [OCMockObject mockForClass:[NRMANetworkFacade class]];
    [[[[[self.mockNetwork expect] ignoringNonObjectArgs] classMethod] andDo:^(NSInvocation* invoke) {
        if (self.networkFinished == YES) {
            XCTFail(@"called notice network request too many times!");
        }
        self.networkFinished = YES;
        self.didCaptureRequest = YES;
    }] noticeNetworkRequest:OCMOCK_ANY
     response:OCMOCK_ANY
     withTimer:OCMOCK_ANY
     bytesSent:0
     bytesReceived:0
     responseData:OCMOCK_ANY
     traceHeaders:OCMOCK_ANY
     params:OCMOCK_ANY];
}

- (void)tearDown {
    [self.mockSession stopMocking];
    [self.mockNetwork stopMocking];
    [NRMAURLSessionOverride deinstrument];

    [super tearDown];
}


- (void) testDataTaskWithRequest {

    // Expectations
    [[[self.mockSession expect] andForwardToRealObject] dataTaskWithRequest:OCMOCK_ANY];
    [[self.mockSession reject]  dataTaskWithURL:OCMOCK_ANY];
    if( @available(iOS 13, *)) {
        [[[self.mockSession reject] andForwardToRealObject] dataTaskWithRequest:OCMOCK_ANY completionHandler:OCMOCK_ANY];
    } else if (@available(iOS 12,*)) {
        [[[self.mockSession expect] andForwardToRealObject] dataTaskWithRequest:OCMOCK_ANY completionHandler:OCMOCK_ANY];
    }

    // Rejections
    [[self.mockSession reject]  uploadTaskWithRequest:OCMOCK_ANY fromData:OCMOCK_ANY];
    [[self.mockSession reject]  uploadTaskWithRequest:OCMOCK_ANY fromData:OCMOCK_ANY completionHandler:OCMOCK_ANY];
    [[self.mockSession reject] uploadTaskWithRequest:OCMOCK_ANY fromFile:OCMOCK_ANY];
    [[self.mockSession reject]  uploadTaskWithRequest:OCMOCK_ANY fromFile:OCMOCK_ANY completionHandler:OCMOCK_ANY];
    [[self.mockSession reject]  uploadTaskWithStreamedRequest:OCMOCK_ANY];

    // Distributed-trace headers are only injected when the connectivity layer has a
    // valid account/application id (Connectivity::Facade::startTrip() returns nil
    // otherwise). That global state is normally established by agent startup in other
    // tests, which made this test order-dependent. Configure it here so the test is
    // self-contained.
    [NRMAFlags enableFeatures:NRFeatureFlag_DistributedTracing];
    NRMAAgentConfiguration *config = [[NRMAAgentConfiguration alloc] initWithAppToken:[[NRMAAppToken alloc] initWithApplicationToken:kNRMA_ENABLED_STAGING_APP_TOKEN]
                                                                     collectorAddress:KNRMA_TEST_COLLECTOR_HOST
                                                                         crashAddress:nil];
    [NRMAHarvestController initialize:config];
    NRMAHarvesterConfiguration* harvesterConfig = [NRMAHarvesterConfiguration defaultHarvesterConfiguration];
    [harvesterConfig setTrusted_account_key:@"777"];
    harvesterConfig.account_id = 1234567;
    harvesterConfig.application_id = 1234567;
    [[[NRMAHarvestController harvestController] harvester] configureHarvester:harvesterConfig];

    NSURLRequest *urlRequest = [NSURLRequest requestWithURL:[NSURL URLWithString:@"http://www.google.com"]];
    NSURLSessionDataTask* task = [self.mockSession dataTaskWithRequest:urlRequest];

    NSDictionary *headers = [[task currentRequest] allHTTPHeaderFields];

    XCTAssertNotNil(headers[@"newrelic"]);
    XCTAssertNotNil(headers[@"traceparent"]);
    XCTAssertNotNil(headers[@"tracestate"]);

    [task resume];

    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(20 * NSEC_PER_SEC)), dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        self.networkFinished = YES;
    });

    while (CFRunLoopGetMain() && !self.networkFinished) {}

    XCTAssertNoThrow([self.mockNetwork verify], @"did not capture network data");
    XCTAssertNoThrow([self.mockSession verify],@"a method that should have been called, was.");
}


//- (void) testDataTaskWithURLCompeltionHandler {
//
//
//    [[self.mockSession reject]  dataTaskWithRequest:OCMOCK_ANY];
//    if( @available(iOS 13, *)) {
//        [[[self.mockSession reject] andForwardToRealObject] dataTaskWithRequest:OCMOCK_ANY completionHandler:OCMOCK_ANY];
//    } else if (@available(iOS 12,*)) {
//        [[[self.mockSession expect] andForwardToRealObject] dataTaskWithRequest:OCMOCK_ANY completionHandler:OCMOCK_ANY];
//    }
//    [[self.mockSession reject]  uploadTaskWithRequest:OCMOCK_ANY fromData:OCMOCK_ANY];
//    [[self.mockSession reject]  uploadTaskWithRequest:OCMOCK_ANY fromData:OCMOCK_ANY completionHandler:OCMOCK_ANY];
//    [[self.mockSession reject]  uploadTaskWithRequest:OCMOCK_ANY fromFile:OCMOCK_ANY];
//    [[self.mockSession reject]  uploadTaskWithRequest:OCMOCK_ANY fromFile:OCMOCK_ANY completionHandler:OCMOCK_ANY];
//    [[self.mockSession reject]  uploadTaskWithStreamedRequest:OCMOCK_ANY];
//    NSURLSessionDataTask* task = [self.mockSession dataTaskWithURL:[NSURL URLWithString:@"http://www.google.com"] completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
//
//    }];
//
//    NSDictionary *headers = [[task currentRequest] allHTTPHeaderFields];
//
//    XCTAssertNotNil(headers[@"newrelic"]);
//    XCTAssertNotNil(headers[@"traceparent"]);
//    XCTAssertNotNil(headers[@"tracestate"]);
//
//    [task resume];
//
//
//    XCTAssertNoThrow([self.mockSession verify],@"a method that should have been called, was.");
//
//    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(20 * NSEC_PER_SEC)),dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
//        self.networkFinished = YES;
//    });
//
//    while (CFRunLoopGetCurrent() && !self.networkFinished) {}
//    XCTAssertNoThrow([self.mockNetwork verify], @"did not capture network data");
//}
- (void) testDataTaskWithURL {


    [[self.mockSession reject]  dataTaskWithRequest:OCMOCK_ANY];
    [[[self.mockSession expect] andForwardToRealObject] dataTaskWithURL:OCMOCK_ANY];
    if( @available(iOS 13, *)) {
        [[[self.mockSession reject] andForwardToRealObject] dataTaskWithRequest:OCMOCK_ANY completionHandler:OCMOCK_ANY];
    } else if ( @available(iOS 12, *)) {
        [[[self.mockSession expect] andForwardToRealObject] dataTaskWithRequest:OCMOCK_ANY completionHandler:OCMOCK_ANY];
    }

    [[self.mockSession reject]  uploadTaskWithRequest:OCMOCK_ANY fromData:OCMOCK_ANY];
    [[self.mockSession reject]  uploadTaskWithRequest:OCMOCK_ANY fromData:OCMOCK_ANY completionHandler:OCMOCK_ANY];
    [[self.mockSession reject]  uploadTaskWithRequest:OCMOCK_ANY fromFile:OCMOCK_ANY];
    [[self.mockSession reject]  uploadTaskWithRequest:OCMOCK_ANY fromFile:OCMOCK_ANY completionHandler:OCMOCK_ANY];
    [[self.mockSession reject]  uploadTaskWithStreamedRequest:OCMOCK_ANY];
    NSURLSessionDataTask* task = [self.mockSession dataTaskWithURL:[NSURL URLWithString:@"http://www.google.com"]];

    // TODO: Should [URLSession dataTaskWithURL] result in these headers being added to the request?
//    NSDictionary *headers = [[task currentRequest] allHTTPHeaderFields];
//
//    XCTAssertNotNil(headers[@"newrelic"]);
//    XCTAssertNotNil(headers[@"traceparent"]);
//    XCTAssertNotNil(headers[@"tracestate"]);

    [task resume];


    XCTAssertNoThrow([self.mockSession verify],@"a method that should have been called, was.");

    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(20 * NSEC_PER_SEC)),dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        self.networkFinished = YES;
    });

    while (CFRunLoopGetCurrent() && !self.networkFinished) {}
    XCTAssertNoThrow([self.mockNetwork verify], @"did not capture network data");
}
//- (void) testDataTaskWithRequestCompletionHandler {
//
//
//    [[self.mockSession reject]  dataTaskWithRequest:OCMOCK_ANY];
//    [[self.mockSession reject]  dataTaskWithURL:OCMOCK_ANY];
//    [[[self.mockSession expect] andForwardToRealObject] dataTaskWithRequest:OCMOCK_ANY completionHandler:OCMOCK_ANY];
//    [[self.mockSession reject]  uploadTaskWithRequest:OCMOCK_ANY fromData:OCMOCK_ANY];
//    [[self.mockSession reject]  uploadTaskWithRequest:OCMOCK_ANY fromData:OCMOCK_ANY completionHandler:OCMOCK_ANY];
//    [[self.mockSession reject]  uploadTaskWithRequest:OCMOCK_ANY fromFile:OCMOCK_ANY];
//    [[self.mockSession reject]  uploadTaskWithRequest:OCMOCK_ANY fromFile:OCMOCK_ANY completionHandler:OCMOCK_ANY];
//    [[self.mockSession reject]  uploadTaskWithStreamedRequest:OCMOCK_ANY];
//    NSURLSessionDataTask* task = [self.mockSession dataTaskWithRequest:[NSURLRequest requestWithURL:[NSURL URLWithString:@"http://www.google.com"]] completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
//
//    }];
//
//    NSDictionary *headers = [[task currentRequest] allHTTPHeaderFields];
//
//    XCTAssertNotNil(headers[@"newrelic"]);
//    XCTAssertNotNil(headers[@"traceparent"]);
//    XCTAssertNotNil(headers[@"tracestate"]);
//
//    [task resume];
//
//    XCTAssertNoThrow([self.mockSession verify],@"a method that should have been called, was.");
//
//    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(20 * NSEC_PER_SEC)), dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
//        self.networkFinished = YES;
//    });
//
//    while (CFRunLoopGetCurrent() && !self.networkFinished) {}
//    XCTAssertNoThrow([self.mockNetwork verify], @"did not capture network data");
//}

- (void) testUploadTaskWithRequestFromData {


    [[[self.mockSession reject] andForwardToRealObject] dataTaskWithRequest:OCMOCK_ANY];
    [[[self.mockSession reject] andForwardToRealObject] dataTaskWithURL:OCMOCK_ANY];
    [[[self.mockSession reject] andForwardToRealObject] dataTaskWithRequest:OCMOCK_ANY completionHandler:OCMOCK_ANY];
    [[[self.mockSession expect] andForwardToRealObject] uploadTaskWithRequest:OCMOCK_ANY fromData:OCMOCK_ANY];
    [[[self.mockSession reject] andForwardToRealObject] uploadTaskWithRequest:OCMOCK_ANY fromData:OCMOCK_ANY completionHandler:OCMOCK_ANY];
    [[[self.mockSession reject] andForwardToRealObject] uploadTaskWithRequest:OCMOCK_ANY fromFile:OCMOCK_ANY];
    [[[self.mockSession reject] andForwardToRealObject] uploadTaskWithRequest:OCMOCK_ANY fromFile:OCMOCK_ANY completionHandler:OCMOCK_ANY];
    [[[self.mockSession reject] andForwardToRealObject] uploadTaskWithStreamedRequest:OCMOCK_ANY];

    // The request below hits a live endpoint, so depending on network conditions it may
    // either succeed (noticeNetworkRequest) or fail (e.g. a TLS/connection error ->
    // noticeNetworkFailure). Either way the agent's delegate instrumentation should
    // capture it, so accept the failure path too instead of only the success path.
    [[[[self.mockNetwork stub] classMethod] andDo:^(NSInvocation* invoke) {
        self.networkFinished = YES;
        self.didCaptureRequest = YES;
    }] noticeNetworkFailure:OCMOCK_ANY
     withTimer:OCMOCK_ANY
     withError:OCMOCK_ANY];

    NSMutableURLRequest* request = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:@"https://api.imgur.com/3/image"]];
    [request addValue:@"Client-ID 3e81eb4ece83db7" forHTTPHeaderField:@"Authorization"];
    [request setHTTPMethod:@"POST"];
    NSURL* imgURL = [[NSBundle bundleForClass:[self class]] URLForResource:@"JdAWN9v" withExtension:@"png"];
    NSData* data = [NSData dataWithContentsOfFile:imgURL.path];

    NSURLSessionUploadTask* task = [self.mockSession uploadTaskWithRequest:request
                                                                  fromData:data];
    [task resume];

    XCTAssertNoThrow([self.mockSession verify],@"a method that should have been called, was.");

    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(20 * NSEC_PER_SEC)), dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        self.networkFinished = YES;
    });

    while (CFRunLoopGetCurrent() && !self.networkFinished) {}
    XCTAssertTrue(self.didCaptureRequest, @"did not capture network data via the success or failure path");
}

- (void) testUploadTaskWithRequestFromDataCompletionHandler {


    [[self.mockSession reject]  dataTaskWithRequest:OCMOCK_ANY];
    [[self.mockSession reject]  dataTaskWithURL:OCMOCK_ANY];
    [[self.mockSession reject]  dataTaskWithRequest:OCMOCK_ANY completionHandler:OCMOCK_ANY];
    [[self.mockSession reject]  uploadTaskWithRequest:OCMOCK_ANY fromData:OCMOCK_ANY];
    [[[self.mockSession expect] andForwardToRealObject] uploadTaskWithRequest:OCMOCK_ANY fromData:OCMOCK_ANY completionHandler:OCMOCK_ANY];
    [[self.mockSession reject]  uploadTaskWithRequest:OCMOCK_ANY fromFile:OCMOCK_ANY];
    [[self.mockSession reject]  uploadTaskWithRequest:OCMOCK_ANY fromFile:OCMOCK_ANY completionHandler:OCMOCK_ANY];
    [[self.mockSession reject]  uploadTaskWithStreamedRequest:OCMOCK_ANY];

    // The request below hits a live endpoint, so depending on network conditions it may
    // either succeed (noticeNetworkRequest) or fail (e.g. a TLS/connection error ->
    // noticeNetworkFailure). Either way the agent's instrumentation should capture it,
    // so accept the failure path too instead of only the success path.
    [[[[self.mockNetwork stub] classMethod] andDo:^(NSInvocation* invoke) {
        self.networkFinished = YES;
        self.didCaptureRequest = YES;
    }] noticeNetworkFailure:OCMOCK_ANY
     withTimer:OCMOCK_ANY
     withError:OCMOCK_ANY];

    NSMutableURLRequest* request = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:@"https://api.imgur.com/3/image"]];

    [request addValue:@"Client-ID 3e81eb4ece83db7" forHTTPHeaderField:@"Authorization"];
    [request setHTTPMethod:@"POST"];

    NSURL* imgURL = [[NSBundle bundleForClass:[self class]] URLForResource:@"JdAWN9v" withExtension:@"png"];
    NSData* data = [NSData dataWithContentsOfFile:imgURL.path];
    NSURLSessionUploadTask* task = [self.mockSession uploadTaskWithRequest:request
                                                                  fromData:data
                                                         completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {

    }];

    [task resume];


    XCTAssertNoThrow([self.mockSession verify],@"a method that should have been called, was.");

    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(20 * NSEC_PER_SEC)),dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0) , ^{
        self.networkFinished = YES;
    });

    while (CFRunLoopGetCurrent() && !self.networkFinished) {}
    XCTAssertTrue(self.didCaptureRequest, @"did not capture network data via the success or failure path");
}
- (void) testUploadTaskWithRequestFromFile {

    [[self.mockSession reject]  dataTaskWithRequest:OCMOCK_ANY];
    [[self.mockSession reject]  dataTaskWithURL:OCMOCK_ANY];
    [[self.mockSession reject]  dataTaskWithRequest:OCMOCK_ANY completionHandler:OCMOCK_ANY];

    [[self.mockSession reject]  uploadTaskWithRequest:OCMOCK_ANY fromData:OCMOCK_ANY];

    [[self.mockSession reject]  uploadTaskWithRequest:OCMOCK_ANY fromData:OCMOCK_ANY completionHandler:OCMOCK_ANY];
    [[[self.mockSession expect] andForwardToRealObject] uploadTaskWithRequest:OCMOCK_ANY fromFile:OCMOCK_ANY];
    [[self.mockSession reject]  uploadTaskWithRequest:OCMOCK_ANY fromFile:OCMOCK_ANY completionHandler:OCMOCK_ANY];
    [[self.mockSession reject]  uploadTaskWithStreamedRequest:OCMOCK_ANY];

    // The request below hits a live endpoint, so depending on network conditions it may
    // either succeed (noticeNetworkRequest) or fail (e.g. a TLS/connection error ->
    // noticeNetworkFailure). Either way the agent's instrumentation should capture it,
    // so accept the failure path too instead of only the success path.
    [[[[self.mockNetwork stub] classMethod] andDo:^(NSInvocation* invoke) {
        self.networkFinished = YES;
        self.didCaptureRequest = YES;
    }] noticeNetworkFailure:OCMOCK_ANY
     withTimer:OCMOCK_ANY
     withError:OCMOCK_ANY];

    NSMutableURLRequest* request = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:@"https://api.imgur.com/3/image"]];

    [request addValue:@"Client-ID 3e81eb4ece83db7" forHTTPHeaderField:@"Authorization"];
    [request setHTTPMethod:@"POST"];


    NSURLSessionUploadTask* task = [self.mockSession  uploadTaskWithRequest:request
                                                                   fromFile:[[NSURL alloc] initFileURLWithPath:[[NSBundle bundleForClass:[self class]] pathForResource:@"JdAWN9v" ofType:@"png"]]];

    [task resume];


    XCTAssertNoThrow([self.mockSession verify],@"a method that should have been called, was.");

    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(20 * NSEC_PER_SEC)), dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        self.networkFinished = YES;
    });

    while (CFRunLoopGetCurrent() && !self.networkFinished) {}
    XCTAssertTrue(self.didCaptureRequest, @"did not capture network data via the success or failure path");
}


- (void) testUploadTaskWithRequestFromFileCompletionHandler {

    [[self.mockSession reject]  dataTaskWithRequest:OCMOCK_ANY];
    [[self.mockSession reject]  dataTaskWithURL:OCMOCK_ANY];
    [[self.mockSession reject]  dataTaskWithRequest:OCMOCK_ANY completionHandler:OCMOCK_ANY];

    [[self.mockSession reject]  uploadTaskWithRequest:OCMOCK_ANY fromData:OCMOCK_ANY];

    [[self.mockSession reject]  uploadTaskWithRequest:OCMOCK_ANY fromData:OCMOCK_ANY completionHandler:OCMOCK_ANY];
    [[self.mockSession reject]  uploadTaskWithRequest:OCMOCK_ANY fromFile:OCMOCK_ANY];
    [[[self.mockSession expect] andForwardToRealObject] uploadTaskWithRequest:OCMOCK_ANY fromFile:OCMOCK_ANY completionHandler:OCMOCK_ANY];
    [[self.mockSession reject]  uploadTaskWithStreamedRequest:OCMOCK_ANY];

    // The request below hits a live endpoint, so depending on network conditions it may
    // either succeed (noticeNetworkRequest) or fail (e.g. a TLS/connection error ->
    // noticeNetworkFailure). Either way the agent's instrumentation should capture it,
    // so accept the failure path too instead of only the success path.
    [[[[self.mockNetwork stub] classMethod] andDo:^(NSInvocation* invoke) {
        self.networkFinished = YES;
        self.didCaptureRequest = YES;
    }] noticeNetworkFailure:OCMOCK_ANY
     withTimer:OCMOCK_ANY
     withError:OCMOCK_ANY];

    NSMutableURLRequest* request = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:@"https://api.imgur.com/3/image"]];

    [request addValue:@"Client-ID 3e81eb4ece83db7" forHTTPHeaderField:@"Authorization"];
    [request setHTTPMethod:@"POST"];

    NSURLSessionUploadTask* task = [self.mockSession  uploadTaskWithRequest:request
                                                                   fromFile:[[NSURL alloc] initFileURLWithPath:[[NSBundle bundleForClass:[self class]] pathForResource:@"JdAWN9v" ofType:@"png"]]
                                                          completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {

    }];

    [task resume];

    XCTAssertNoThrow([self.mockSession verify],@"a method that should have been called, was.");

    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(20 * NSEC_PER_SEC)), dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        self.networkFinished = YES;
    });

    while (CFRunLoopGetCurrent() && !self.networkFinished) {}
    XCTAssertTrue(self.didCaptureRequest, @"did not capture network data via the success or failure path");
}

- (void) testUploadTaskWithStreamedRequest {

    [[self.mockSession reject]  dataTaskWithRequest:OCMOCK_ANY];
    [[self.mockSession reject]  dataTaskWithURL:OCMOCK_ANY];
    [[self.mockSession reject]  dataTaskWithRequest:OCMOCK_ANY completionHandler:OCMOCK_ANY];

    [[self.mockSession reject]  uploadTaskWithRequest:OCMOCK_ANY fromData:OCMOCK_ANY];

    [[self.mockSession reject]  uploadTaskWithRequest:OCMOCK_ANY fromData:OCMOCK_ANY completionHandler:OCMOCK_ANY];
    [[self.mockSession reject]  uploadTaskWithRequest:OCMOCK_ANY fromFile:OCMOCK_ANY];
    [[self.mockSession reject]  uploadTaskWithRequest:OCMOCK_ANY fromFile:OCMOCK_ANY completionHandler:OCMOCK_ANY];
    [[[self.mockSession expect] andForwardToRealObject] uploadTaskWithStreamedRequest:OCMOCK_ANY];

    // The request below hits a live endpoint, so depending on network conditions it may
    // either succeed (noticeNetworkRequest) or fail (e.g. a TLS/connection error ->
    // noticeNetworkFailure). Either way the agent's instrumentation should capture it,
    // so accept the failure path too instead of only the success path.
    [[[[self.mockNetwork stub] classMethod] andDo:^(NSInvocation* invoke) {
        self.networkFinished = YES;
        self.didCaptureRequest = YES;
    }] noticeNetworkFailure:OCMOCK_ANY
     withTimer:OCMOCK_ANY
     withError:OCMOCK_ANY];

    NSMutableURLRequest* request = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:@"https://api.imgur.com/3/image"]];

    [request addValue:@"Client-ID 3e81eb4ece83db7" forHTTPHeaderField:@"Authorization"];
    [request setHTTPMethod:@"POST"];


    NSURLSessionUploadTask* task = [self.mockSession uploadTaskWithStreamedRequest:request];
    [task resume];

    XCTAssertNoThrow([self.mockSession verify],@"a method that should have been called, was.");

    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(20 * NSEC_PER_SEC)), dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        self.networkFinished = YES;
    });

    while (CFRunLoopGetCurrent() && !self.networkFinished) {}
    XCTAssertTrue(self.didCaptureRequest, @"did not capture network data via the success or failure path");
}

/* Sent as the last message related to a specific task.  Error may be
 * nil, which implies that no error occurred and this task is complete.
 */
- (void)URLSession:(NSURLSession *)session
              task:(NSURLSessionTask *)task
didCompleteWithError:(NSError *)error {

}
- (void)URLSession:(NSURLSession *)session task:(NSURLSessionTask *)task needNewBodyStream:(void (^)(NSInputStream * _Nullable))completionHandler
{
    NSString* path = [[NSBundle bundleForClass:[self class]] pathForResource:@"JdAWN9v" ofType:@"png"];
    completionHandler([[NSInputStream alloc]initWithFileAtPath:path]);
}
@end
