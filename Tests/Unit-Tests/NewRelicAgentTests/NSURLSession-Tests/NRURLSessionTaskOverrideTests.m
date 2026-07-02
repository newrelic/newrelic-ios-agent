//
//  0Tests.m
//  NewRelicAgent
//
//  Created by Bryce Buchanan on 4/1/14.
//  Copyright © 2023 New Relic. All rights reserved.
//

#import <XCTest/XCTest.h>
#import "NRMAURLSessionOverride.h"
#import "NewRelicAgentInternal.h"
#import "NRMAURLSessionTaskOverride.h"
#import "NRMANSURLConnectionSupport+private.h"
#import "NRMANetworkFacade.h"
#import "NRMAHTTPUtilities.h"
#import "NRConstants.h"
#import <OCMock/OCMock.h>
#import <objc/runtime.h>
@interface NRMAURLSessionTaskOverrideTests : XCTestCase
@property(strong) NSURLSession* session;
- (BOOL) verifyTaskSwizzled:(NSURLSessionTask*)task;
@end

@implementation NRMAURLSessionTaskOverrideTests

- (void)setUp
{
    [super setUp];
    [NRMAURLSessionOverride beginInstrumentation];
    self.session = [NSURLSession sessionWithConfiguration:[NSURLSessionConfiguration defaultSessionConfiguration]];
}

- (void)tearDown
{
    [NRMAURLSessionOverride deinstrument];
    [super tearDown];
}

- (BOOL) verifyTaskSwizzled:(NSURLSessionTask*)task
{
    Method method = class_getInstanceMethod([task class], @selector(resume));
    IMP imp = method_getImplementation(method);

    return (imp == (IMP)NRMAOverride__resume);
}

- (void) testTimerCreationAndTaskCompletion
{
    __block BOOL finished = NO;
    id nrMock = [OCMockObject mockForClass:[NRMANetworkFacade class]];
    __block NRTimer* timer;
    [[[[[nrMock expect] ignoringNonObjectArgs] classMethod] andDo:^(NSInvocation* inv) {
        __autoreleasing NRTimer* localTimer;
        [inv getArgument:&localTimer
                 atIndex:4];
        timer = localTimer;
        [inv invoke];
        finished = YES;
    }] noticeNetworkRequest:OCMOCK_ANY
                   response:OCMOCK_ANY
                  withTimer:OCMOCK_ANY
                  bytesSent:0
              bytesReceived:0
               responseData:OCMOCK_ANY
               traceHeaders:OCMOCK_ANY
                     params:OCMOCK_ANY];

    __block NSURLSessionDataTask* task = [self.session dataTaskWithURL:[NSURL URLWithString:@"http://google.com"] completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {} ];

    XCTAssertTrue([self verifyTaskSwizzled:task],@"task's method 'resume' was not instrumented!");

    [task resume];
    while (CFRunLoopGetCurrent() && !finished) {}
    XCTAssertTrue([timer timeElapsedInMilliSeconds] > 0, @"timer was never stopped");
    [nrMock stopMocking];
}

- (void) testRecordNetworkActivity
{

    NSString* url = @"http://google.com";
    id mockURLConnectionSupport = [OCMockObject mockForClass:[NRMANSURLConnectionSupport class]];
    __block NSURLSessionDataTask* task = nil;
[[[[[mockURLConnectionSupport expect] ignoringNonObjectArgs] classMethod] andDo:^(NSInvocation *inv) {

    __autoreleasing NSURLResponse* response;
    [inv getArgument:&response atIndex:2];
    XCTAssertTrue(response == task.response, @"responses didn't match!");

    __autoreleasing NSURLRequest* request;
    [inv getArgument:&request atIndex:3];
    XCTAssertTrue([request.URL.absoluteString isEqualToString:url], @"url doesn't match!");

    __autoreleasing NRTimer* timer = nil;
    [inv getArgument:&timer atIndex:4];

     NSUInteger bytesSent;
    [inv getArgument:&bytesSent atIndex:6];
    XCTAssertTrue(bytesSent == task.countOfBytesSent, @"bytes sent don't match!");

    NSUInteger bytesReceived;
    [inv getArgument:&bytesReceived atIndex:7];
    XCTAssertTrue(bytesReceived == task.countOfBytesReceived, @"bytes received don't match!");

    XCTAssertTrue(timer == NRMA__getTimerForSessionTask(task), @"timers don't match!");

}] noticeResponse:OCMOCK_ANY
 forRequest:OCMOCK_ANY
 withTimer:OCMOCK_ANY
 andBody:OCMOCK_ANY
 bytesSent:0
 bytesReceived:0];

    __block BOOL finished = NO;
    task = [self.session dataTaskWithURL:[NSURL URLWithString:url] completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
        finished = YES;
    }];


    XCTAssertTrue([self verifyTaskSwizzled:task],@"task's method 'resume' was not instrumented!");
    [task resume];

    while (CFRunLoopGetCurrent() && !finished) {}

    XCTAssertNoThrow([mockURLConnectionSupport verify], @"NoticeRepsonse was not called!");
    [mockURLConnectionSupport stopMocking];
}

// Is this test failing for you? Do you have Charles running? Try with it turned off.
- (void) testRecordNetworkFailure
{
    NSLog(@"did this (^) test hang? do you have charles running? ಠ_ಠ");
    NSString* badURL = @"http://googleq34.colm";
    id mockURLConnectionSupport = [OCMockObject mockForClass:[NRMANSURLConnectionSupport class]];

     __block NSURLSessionDataTask* task = nil;
    __block BOOL finished = NO;
    [[[[[mockURLConnectionSupport expect] ignoringNonObjectArgs] classMethod] andDo:^(NSInvocation *inv) {
//        //verify some of the values!
       __autoreleasing NSURLRequest* request = nil;
        [inv getArgument:&request atIndex:3];
        XCTAssertTrue([request.URL.absoluteString isEqualToString:badURL], @"url does not match!");

       __autoreleasing NSError* error;
        [inv getArgument:&error atIndex:2];
        XCTAssertTrue(error.code == -1003, @"the error does not match. should be \"host name could not be found\"");
        __autoreleasing NRTimer* timer;
        [inv getArgument:&timer atIndex:4];
        NRTimer* originalTimer = NRMA__getTimerForSessionTask(task);
        XCTAssertTrue(timer == originalTimer, @"timers do not match!");
        request = nil;
        finished = YES;
    }] noticeError:OCMOCK_ANY forRequest:OCMOCK_ANY withTimer:OCMOCK_ANY];


    task = [self.session dataTaskWithURL:[NSURL URLWithString:badURL] completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {

    }];


    XCTAssertTrue([self verifyTaskSwizzled:task],@"task's method 'resume' was not instrumented!");
    [task resume];

    while (CFRunLoopGetCurrent() && !finished) {
        [[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:0.01]];
    }

    XCTAssertNoThrow([mockURLConnectionSupport verify], @"NoticeRepsonse was not called!");
    [mockURLConnectionSupport stopMocking];
}



- (void) testUploadTaskFailure
{
    NSString* badURL = @"http://googleq34.colm";
    id mockURLConnectionSupport = [OCMockObject mockForClass:[NRMANSURLConnectionSupport class]];

    __block NSURLSessionUploadTask* task = nil;

    [[[[[mockURLConnectionSupport expect] ignoringNonObjectArgs] classMethod] andDo:^(NSInvocation *inv) {
        //        //verify some of the values!
        __autoreleasing NSURLRequest* request = nil;
        [inv getArgument:&request atIndex:3];
        XCTAssertTrue([request.URL.absoluteString isEqualToString:badURL], @"url does not match!");

        __autoreleasing NSError* error;
        [inv getArgument:&error atIndex:2];
        XCTAssertTrue(error.code == -1003, @"error \"%ld\" does not match. should be \"host name could not be found\"",(long)error.code);
        __autoreleasing NRTimer* timer;
        [inv getArgument:&timer atIndex:4];
        NRTimer* originalTimer = NRMA__getTimerForSessionTask(task);
        XCTAssertTrue(timer == originalTimer, @"timers do not match!");
        request = nil;
    }] noticeError:OCMOCK_ANY forRequest:OCMOCK_ANY withTimer:OCMOCK_ANY];

    __block BOOL finished = NO;
    NSURLRequest* request = [NSURLRequest requestWithURL:[NSURL URLWithString:badURL]];
    task = [self.session uploadTaskWithRequest:request
                                      fromData:[@"hello world" dataUsingEncoding:NSUTF8StringEncoding]
                             completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
                                 finished = YES;
                             }];


    XCTAssertTrue([self verifyTaskSwizzled:task],@"task's method 'resume' was not instrumented!");
    [task resume];

    while (CFRunLoopGetCurrent() && !finished) {
    }

    XCTAssertNoThrow([mockURLConnectionSupport verify], @"NoticeRepsonse was not called!");
    [mockURLConnectionSupport stopMocking];
}

- (void) testRecordUploadTask
{

    NSString* url = @"http://google.com";
    id mockURLConnectionSupport = [OCMockObject mockForClass:[NRMANSURLConnectionSupport class]];
    __block NSURLSessionDataTask* task = nil;
    [[[[[mockURLConnectionSupport expect] ignoringNonObjectArgs] classMethod] andDo:^(NSInvocation *inv) {

        __autoreleasing NSURLResponse* response;
        [inv getArgument:&response atIndex:2];
        XCTAssertTrue(response == task.response, @"responses didn't match!");

        __autoreleasing NSURLRequest* request;
        [inv getArgument:&request atIndex:3];
        XCTAssertTrue([request.URL.absoluteString isEqualToString:url], @"url doesn't match!");

        __autoreleasing NRTimer* timer = nil;
        [inv getArgument:&timer atIndex:4];

        NSUInteger bytesSent;
        [inv getArgument:&bytesSent atIndex:6];
        XCTAssertTrue(bytesSent == task.countOfBytesSent, @"bytes sent don't match!");

        NSUInteger bytesReceived;
        [inv getArgument:&bytesReceived atIndex:7];
        XCTAssertTrue(bytesReceived == task.countOfBytesReceived, @"bytes received don't match!");

        XCTAssertTrue(timer == NRMA__getTimerForSessionTask(task), @"timers don't match!");

    }] noticeResponse:OCMOCK_ANY
     forRequest:OCMOCK_ANY
     withTimer:OCMOCK_ANY
     andBody:OCMOCK_ANY
     bytesSent:0
     bytesReceived:0];

    __block BOOL finished = NO;
    NSURLRequest* request = [NSURLRequest requestWithURL:[NSURL URLWithString:url]];
    task = [self.session uploadTaskWithRequest:request
                                      fromData:[NSData new]
                             completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
                                 finished = YES;
                             }];


    XCTAssertTrue([self verifyTaskSwizzled:task],@"task's method 'resume' was not instrumented!");
    [task resume];

    while (CFRunLoopGetCurrent() && !finished) {}
    
    XCTAssertNoThrow([mockURLConnectionSupport verify], @"NoticeRepsonse was not called!");
    [mockURLConnectionSupport stopMocking];
}

// Regression test for the CFNetwork CacheDB-write / CFGetTypeID crash.
//
// When the swizzled -setState: fires for the *Completed* transition, the override
// must NOT create a mutable copy of, or inject Distributed Tracing headers into, the
// task's request. That request-mutation work used to run on every state transition,
// including completion — the exact moment CFNetwork serializes the same request's
// header dictionary into the shared URL cache on com.apple.CFNetwork.CacheDB-write.
// Racing on the (non-thread-safe) header dictionary left a dangling object that
// CFNetwork later walked into via CFGetTypeID. This test locks in that at completion
// we only record and never touch the request.
- (void) testSetStateCompletedDoesNotMutateRequestButStillRecords
{
    NSString* url = @"http://google.com";

    // Count any request-mutating DT header injection. At completion it must stay zero.
    __block int mutationCount = 0;
    id mockHTTPUtils = [OCMockObject niceMockForClass:[NRMAHTTPUtilities class]];
    [[[[mockHTTPUtils stub] classMethod] andDo:^(NSInvocation* inv) {
        mutationCount++;
    }] addCrossProcessIdentifier:OCMOCK_ANY];

    // Recording must still occur at completion.
    __block BOOL recorded = NO;
    id mockURLConnectionSupport = [OCMockObject mockForClass:[NRMANSURLConnectionSupport class]];
    [[[[[mockURLConnectionSupport expect] ignoringNonObjectArgs] classMethod] andDo:^(NSInvocation* inv) {
        recorded = YES;
    }] noticeResponse:OCMOCK_ANY
          forRequest:OCMOCK_ANY
           withTimer:OCMOCK_ANY
             andBody:OCMOCK_ANY
           bytesSent:0
       bytesReceived:0];

    // Deinstrument so the session factory does not mark the task "already handled"
    // (that marker would make the override early-return before our branch). We still
    // invoke the setState override directly below to exercise the async-URLSession path.
    [NRMAURLSessionOverride deinstrument];
    NSURLSessionDataTask* task = [self.session dataTaskWithURL:[NSURL URLWithString:url]];
    // A task that has not been resumed exposes a nil currentRequest, so stub it to drive
    // the override's async-URLSession branch deterministically (no real networking).
    id taskMock = [OCMockObject partialMockForObject:task];
    [[[taskMock stub] andReturn:[NSURLRequest requestWithURL:[NSURL URLWithString:url]]] currentRequest];
    NRMA__setTimerForSessionTask(task, [NRTimer new]);

    NRMAOverride__urlSessionTask_SetState(task, @selector(setState:), NSURLSessionTaskStateCompleted);

    XCTAssertNoThrow([mockURLConnectionSupport verify], @"NoticeResponse was not called at completion!");
    XCTAssertTrue(recorded, @"completed task was not recorded");
    XCTAssertEqual(mutationCount, 0, @"request was mutated at completion — reintroduces the CFNetwork cache-write race");

    [taskMock stopMocking];
    [mockURLConnectionSupport stopMocking];
    [mockHTTPUtils stopMocking];
}

// Companion to the above: on a *starting* (non-completed) transition it is still safe
// and correct to inject Distributed Tracing headers, because the task is not yet being
// torn down / cached by CFNetwork — and it must NOT record the task yet.
- (void) testSetStateRunningStillInjectsDistributedTracingHeaders
{
    NSString* url = @"http://google.com";

    // Count DT header injection; it must happen on the running transition.
    __block int injectionCount = 0;
    id mockHTTPUtils = [OCMockObject niceMockForClass:[NRMAHTTPUtilities class]];
    [[[[mockHTTPUtils stub] classMethod] andDo:^(NSInvocation* inv) {
        injectionCount++;
    }] addCrossProcessIdentifier:OCMOCK_ANY];

    // Recording must NOT occur for a non-completed transition.
    id mockURLConnectionSupport = [OCMockObject mockForClass:[NRMANSURLConnectionSupport class]];
    [[[[mockURLConnectionSupport reject] ignoringNonObjectArgs] classMethod] noticeResponse:OCMOCK_ANY
                                                                                 forRequest:OCMOCK_ANY
                                                                                  withTimer:OCMOCK_ANY
                                                                                    andBody:OCMOCK_ANY
                                                                                  bytesSent:0
                                                                              bytesReceived:0];

    // See note in the completed-state test: deinstrument so the task is not marked handled.
    [NRMAURLSessionOverride deinstrument];
    NSURLSessionDataTask* task = [self.session dataTaskWithURL:[NSURL URLWithString:url]];
    id taskMock = [OCMockObject partialMockForObject:task];
    [[[taskMock stub] andReturn:[NSURLRequest requestWithURL:[NSURL URLWithString:url]]] currentRequest];
    NRMA__setTimerForSessionTask(task, [NRTimer new]);

    NRMAOverride__urlSessionTask_SetState(task, @selector(setState:), NSURLSessionTaskStateRunning);

    XCTAssertTrue(injectionCount > 0, @"DT headers were not injected on the running transition");
    XCTAssertNoThrow([mockURLConnectionSupport verify], @"a non-completed transition must not record the task");

    [taskMock stopMocking];
    [mockHTTPUtils stopMocking];
    [mockURLConnectionSupport stopMocking];
}

@end
