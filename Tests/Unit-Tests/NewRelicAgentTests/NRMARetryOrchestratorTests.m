//
//  NRMARetryOrchestratorTests.m
//  NewRelicAgentTests
//
//  Copyright © 2025 New Relic. All rights reserved.
//

#import <XCTest/XCTest.h>
#import "NRMARetryOrchestrator.h"

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

/// Builds an NSHTTPURLResponse with the given status code.
static NSHTTPURLResponse *responseWithStatus(NSInteger status) {
    return [[NSHTTPURLResponse alloc] initWithURL:[NSURL URLWithString:@"https://example.com"]
                                       statusCode:status
                                      HTTPVersion:@"HTTP/1.1"
                                     headerFields:nil];
}

/// Builds a sync executeRequest block that always returns the provided response/error.
static NRMAExecuteRequestBlock syncRequest(NSHTTPURLResponse *response, NSError *error) {
    return ^(void (^onResponse)(NSHTTPURLResponse *, NSData *, NSError *)) {
        onResponse(response, nil, error);
    };
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

@interface NRMARetryOrchestratorTests : XCTestCase
@end

@implementation NRMARetryOrchestratorTests

#pragma mark - Delay calculation

- (void)testDelayCalculation_exponentialNoCap {
    // delay(0)=1, delay(1)=2, delay(2)=4, delay(3)=8
    NRMARetryOrchestrator *orc = [[NRMARetryOrchestrator alloc] initWithInitialDelay:1.0 maxDelay:100.0];

    __block NSInteger callCount = 0;
    __block NSTimeInterval lastDelay = -1;

    NRMAWaitForDelayBlock captureDelay = ^(NSTimeInterval delay, dispatch_block_t onReady) {
        callCount++;
        lastDelay = delay;
        onReady();
    };

    // 429 response — will retry up to maxRetries=3 times, capturing delays
    __block NSHTTPURLResponse *bResponse = responseWithStatus(429);
    NRMAExecuteRequestBlock req = ^(void (^onResponse)(NSHTTPURLResponse *, NSData *, NSError *)) {
        onResponse(bResponse, nil, nil);
    };

    BOOL (^shouldRetry)(NSHTTPURLResponse *, NSError *) = ^BOOL(NSHTTPURLResponse *r, NSError *e) {
        return r.statusCode == 429;
    };

    [orc executeWithMaxRetries:3
               executeRequest:req
                  shouldRetry:shouldRetry
                 waitForDelay:captureDelay
                   completion:^(NSHTTPURLResponse *r, NSData *d, NSError *e, NSInteger retryCount) {
        XCTAssertEqual(retryCount, 3);
    }];

    // delays should have been: 0.0 (immediate), 1.0, 2.0
    // First retry fires immediately; backoff starts on the second retry.
    XCTAssertEqual(callCount, 3, @"waitForDelay should be called once per retry");
    XCTAssertEqualWithAccuracy(lastDelay, 2.0, 0.001, @"third delay should be 2.0");
}

- (void)testDelayCalculation_cappedAtMaxDelay {
    NRMARetryOrchestrator *orc = [[NRMARetryOrchestrator alloc] initWithInitialDelay:1.0 maxDelay:16.0];

    __block NSTimeInterval lastDelay = -1;
    NRMAWaitForDelayBlock captureDelay = ^(NSTimeInterval delay, dispatch_block_t onReady) {
        lastDelay = delay;
        onReady();
    };

    NRMAExecuteRequestBlock req = syncRequest(responseWithStatus(429), nil);
    BOOL (^shouldRetry)(NSHTTPURLResponse *, NSError *) = ^BOOL(NSHTTPURLResponse *r, NSError *e) {
        return YES;
    };

    [orc executeWithMaxRetries:10
               executeRequest:req
                  shouldRetry:shouldRetry
                 waitForDelay:captureDelay
                   completion:^(NSHTTPURLResponse *r, NSData *d, NSError *e, NSInteger retryCount) {}];

    XCTAssertEqualWithAccuracy(lastDelay, 16.0, 0.001, @"delay should be capped at maxDelay");
}

#pragma mark - Success on first attempt

- (void)testSuccessOnFirstAttempt_noRetry_noDelay {
    NRMARetryOrchestrator *orc = [[NRMARetryOrchestrator alloc] initWithInitialDelay:1.0 maxDelay:16.0];

    __block NSInteger waitCallCount = 0;
    NRMAWaitForDelayBlock noDelay = ^(NSTimeInterval d, dispatch_block_t onReady) {
        waitCallCount++;
        onReady();
    };

    __block NSInteger completionRetryCount = -1;
    [orc executeWithMaxRetries:3
               executeRequest:syncRequest(responseWithStatus(200), nil)
                  shouldRetry:[NRMARetryOrchestrator standardShouldRetry]
                 waitForDelay:noDelay
                   completion:^(NSHTTPURLResponse *r, NSData *d, NSError *e, NSInteger retryCount) {
        completionRetryCount = retryCount;
    }];

    XCTAssertEqual(waitCallCount, 0, @"no delay should be applied on first-attempt success");
    XCTAssertEqual(completionRetryCount, 0, @"retryCount should be 0 on first-attempt success");
}

#pragma mark - Non-retryable status

- (void)testNonRetryableStatus_401_noRetry {
    NRMARetryOrchestrator *orc = [[NRMARetryOrchestrator alloc] initWithInitialDelay:1.0 maxDelay:16.0];

    __block NSInteger waitCallCount = 0;
    NRMAWaitForDelayBlock noDelay = ^(NSTimeInterval d, dispatch_block_t onReady) {
        waitCallCount++;
        onReady();
    };

    __block NSInteger completionRetryCount = -1;
    [orc executeWithMaxRetries:3
               executeRequest:syncRequest(responseWithStatus(401), nil)
                  shouldRetry:[NRMARetryOrchestrator standardShouldRetry]
                 waitForDelay:noDelay
                   completion:^(NSHTTPURLResponse *r, NSData *d, NSError *e, NSInteger retryCount) {
        completionRetryCount = retryCount;
        XCTAssertEqual(r.statusCode, 401);
    }];

    XCTAssertEqual(waitCallCount, 0, @"should not retry on 401");
    XCTAssertEqual(completionRetryCount, 0, @"retryCount should be 0 for non-retryable");
}

#pragma mark - Retryable status 429

- (void)testRetryableStatus_429_retriesUpToMaxRetries {
    NRMARetryOrchestrator *orc = [[NRMARetryOrchestrator alloc] initWithInitialDelay:1.0 maxDelay:16.0];

    __block NSInteger requestCallCount = 0;
    NRMAExecuteRequestBlock countingReq = ^(void (^onResponse)(NSHTTPURLResponse *, NSData *, NSError *)) {
        requestCallCount++;
        onResponse(responseWithStatus(429), nil, nil);
    };

    NRMAWaitForDelayBlock noDelay = ^(NSTimeInterval d, dispatch_block_t onReady) { onReady(); };

    __block NSInteger completionRetryCount = -1;
    [orc executeWithMaxRetries:2
               executeRequest:countingReq
                  shouldRetry:[NRMARetryOrchestrator standardShouldRetry]
                 waitForDelay:noDelay
                   completion:^(NSHTTPURLResponse *r, NSData *d, NSError *e, NSInteger retryCount) {
        completionRetryCount = retryCount;
    }];

    // 1 initial attempt + 2 retries = 3 total calls
    XCTAssertEqual(requestCallCount, 3, @"should attempt initial + maxRetries times");
    XCTAssertEqual(completionRetryCount, 2);
}

#pragma mark - Retry on network error

- (void)testRetryOnNetworkError {
    NRMARetryOrchestrator *orc = [[NRMARetryOrchestrator alloc] initWithInitialDelay:1.0 maxDelay:16.0];

    NSError *networkError = [NSError errorWithDomain:NSURLErrorDomain code:NSURLErrorNotConnectedToInternet userInfo:nil];

    __block NSInteger requestCallCount = 0;
    NRMAExecuteRequestBlock errorReq = ^(void (^onResponse)(NSHTTPURLResponse *, NSData *, NSError *)) {
        requestCallCount++;
        onResponse(nil, nil, networkError);
    };

    NRMAWaitForDelayBlock noDelay = ^(NSTimeInterval d, dispatch_block_t onReady) { onReady(); };

    __block NSInteger completionRetryCount = -1;
    [orc executeWithMaxRetries:2
               executeRequest:errorReq
                  shouldRetry:[NRMARetryOrchestrator standardShouldRetry]
                 waitForDelay:noDelay
                   completion:^(NSHTTPURLResponse *r, NSData *d, NSError *e, NSInteger retryCount) {
        completionRetryCount = retryCount;
        XCTAssertNotNil(e);
    }];

    XCTAssertEqual(requestCallCount, 3, @"should attempt initial + 2 retries on network error");
    XCTAssertEqual(completionRetryCount, 2);
}

#pragma mark - Max retries exhausted

- (void)testMaxRetriesExhausted_completionCalledWithFinalFailure {
    NRMARetryOrchestrator *orc = [[NRMARetryOrchestrator alloc] initWithInitialDelay:1.0 maxDelay:16.0];

    NRMAExecuteRequestBlock alwaysFail = syncRequest(responseWithStatus(500), nil);
    NRMAWaitForDelayBlock noDelay = ^(NSTimeInterval d, dispatch_block_t onReady) { onReady(); };

    __block BOOL completionCalled = NO;
    __block NSInteger finalRetryCount = -1;

    [orc executeWithMaxRetries:3
               executeRequest:alwaysFail
                  shouldRetry:[NRMARetryOrchestrator standardShouldRetry]
                 waitForDelay:noDelay
                   completion:^(NSHTTPURLResponse *r, NSData *d, NSError *e, NSInteger retryCount) {
        completionCalled = YES;
        finalRetryCount = retryCount;
        XCTAssertEqual(r.statusCode, 500);
    }];

    XCTAssertTrue(completionCalled, @"completion should always be called");
    XCTAssertEqual(finalRetryCount, 3, @"should have retried 3 times");
}

#pragma mark - maxRetries = 0 (no retry)

- (void)testMaxRetriesZero_noRetry {
    NRMARetryOrchestrator *orc = [[NRMARetryOrchestrator alloc] initWithInitialDelay:1.0 maxDelay:16.0];

    __block NSInteger requestCallCount = 0;
    NRMAExecuteRequestBlock countingReq = ^(void (^onResponse)(NSHTTPURLResponse *, NSData *, NSError *)) {
        requestCallCount++;
        onResponse(responseWithStatus(429), nil, nil);
    };

    NRMAWaitForDelayBlock noDelay = ^(NSTimeInterval d, dispatch_block_t onReady) { onReady(); };

    [orc executeWithMaxRetries:0
               executeRequest:countingReq
                  shouldRetry:[NRMARetryOrchestrator standardShouldRetry]
                 waitForDelay:noDelay
                   completion:^(NSHTTPURLResponse *r, NSData *d, NSError *e, NSInteger retryCount) {
        XCTAssertEqual(retryCount, 0);
    }];

    XCTAssertEqual(requestCallCount, 1, @"with maxRetries=0, only one attempt should be made");
}

#pragma mark - standardShouldRetry

- (void)testStandardShouldRetry_retryableStatuses {
    BOOL (^shouldRetry)(NSHTTPURLResponse *, NSError *) = [NRMARetryOrchestrator standardShouldRetry];

    // Network error → retry
    NSError *err = [NSError errorWithDomain:NSURLErrorDomain code:NSURLErrorTimedOut userInfo:nil];
    XCTAssertTrue(shouldRetry(nil, err));

    // 429 → retry
    XCTAssertTrue(shouldRetry(responseWithStatus(429), nil));

    // 500 → retry
    XCTAssertTrue(shouldRetry(responseWithStatus(500), nil));

    // 502, 503, 504 → retry
    XCTAssertTrue(shouldRetry(responseWithStatus(502), nil));
    XCTAssertTrue(shouldRetry(responseWithStatus(503), nil));
    XCTAssertTrue(shouldRetry(responseWithStatus(504), nil));
}

- (void)testStandardShouldRetry_nonRetryableStatuses {
    BOOL (^shouldRetry)(NSHTTPURLResponse *, NSError *) = [NRMARetryOrchestrator standardShouldRetry];

    // 200 → no retry
    XCTAssertFalse(shouldRetry(responseWithStatus(200), nil));

    // 400, 401, 403, 404 → no retry
    XCTAssertFalse(shouldRetry(responseWithStatus(400), nil));
    XCTAssertFalse(shouldRetry(responseWithStatus(401), nil));
    XCTAssertFalse(shouldRetry(responseWithStatus(403), nil));
    XCTAssertFalse(shouldRetry(responseWithStatus(404), nil));
}

#pragma mark - syncWaitForDelay

- (void)testSyncWaitForDelay_callsOnReadySynchronously {
    NRMAWaitForDelayBlock syncWait = [NRMARetryOrchestrator syncWaitForDelay];

    __block BOOL calledBack = NO;
    syncWait(0.001, ^{ calledBack = YES; });

    // Because it's sync, calledBack must be YES immediately after the call returns.
    XCTAssertTrue(calledBack, @"syncWaitForDelay should invoke onReady synchronously");
}

#pragma mark - asyncWaitForDelayOnQueue

- (void)testAsyncWaitForDelayOnQueue_callsOnReadyAsynchronously {
    dispatch_queue_t testQueue = dispatch_queue_create("com.test.retryqueue", DISPATCH_QUEUE_SERIAL);
    NRMAWaitForDelayBlock asyncWait = [NRMARetryOrchestrator asyncWaitForDelayOnQueue:testQueue];

    XCTestExpectation *exp = [self expectationWithDescription:@"async onReady called"];
    asyncWait(0.0, ^{ [exp fulfill]; });

    [self waitForExpectationsWithTimeout:2.0 handler:nil];
}

#pragma mark - Eventual success after retries

- (void)testEventualSuccess_afterOneRetry {
    NRMARetryOrchestrator *orc = [[NRMARetryOrchestrator alloc] initWithInitialDelay:1.0 maxDelay:16.0];

    __block NSInteger callCount = 0;
    NRMAExecuteRequestBlock req = ^(void (^onResponse)(NSHTTPURLResponse *, NSData *, NSError *)) {
        callCount++;
        NSHTTPURLResponse *response = (callCount == 1) ? responseWithStatus(500) : responseWithStatus(200);
        onResponse(response, nil, nil);
    };

    NRMAWaitForDelayBlock noDelay = ^(NSTimeInterval d, dispatch_block_t onReady) { onReady(); };

    __block NSInteger finalStatusCode = 0;
    [orc executeWithMaxRetries:3
               executeRequest:req
                  shouldRetry:[NRMARetryOrchestrator standardShouldRetry]
                 waitForDelay:noDelay
                   completion:^(NSHTTPURLResponse *r, NSData *d, NSError *e, NSInteger retryCount) {
        finalStatusCode = r.statusCode;
        XCTAssertEqual(retryCount, 1);
    }];

    XCTAssertEqual(callCount, 2);
    XCTAssertEqual(finalStatusCode, 200);
}

@end
