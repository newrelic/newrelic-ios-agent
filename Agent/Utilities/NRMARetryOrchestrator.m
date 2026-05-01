//
//  NRMARetryOrchestrator.m
//  NewRelicAgent
//
//  Copyright © 2025 New Relic. All rights reserved.
//

#import "NRMARetryOrchestrator.h"
#import "NRLogger.h"

@interface NRMARetryOrchestrator ()
@property(assign, nonatomic) NSTimeInterval initialDelay;
@property(assign, nonatomic) NSTimeInterval maxDelay;
@end

@implementation NRMARetryOrchestrator

- (instancetype) initWithInitialDelay:(NSTimeInterval)initialDelay
                             maxDelay:(NSTimeInterval)maxDelay {
    self = [super init];
    if (self) {
        _initialDelay = initialDelay;
        _maxDelay = maxDelay;
    }
    return self;
}

- (void) executeWithMaxRetries:(NSInteger)maxRetries
                executeRequest:(NRMAExecuteRequestBlock)executeRequest
                   shouldRetry:(BOOL (^)(NSHTTPURLResponse *_Nullable, NSError *_Nullable))shouldRetry
                  waitForDelay:(NRMAWaitForDelayBlock)waitForDelay
                    completion:(void (^)(NSHTTPURLResponse *_Nullable,
                                        NSData *_Nullable,
                                        NSError *_Nullable,
                                        NSInteger))completion {
    NRLOG_AGENT_VERBOSE(@"NRMARetryOrchestrator: starting request (attempt 1/%ld)", (long)(maxRetries + 1));
    [self attemptRequest:executeRequest
           attemptNumber:0
             maxRetries:maxRetries
            shouldRetry:shouldRetry
           waitForDelay:waitForDelay
             completion:completion];
}

- (void) attemptRequest:(NRMAExecuteRequestBlock)executeRequest
          attemptNumber:(NSInteger)attemptNumber
             maxRetries:(NSInteger)maxRetries
            shouldRetry:(BOOL (^)(NSHTTPURLResponse *_Nullable, NSError *_Nullable))shouldRetry
           waitForDelay:(NRMAWaitForDelayBlock)waitForDelay
             completion:(void (^)(NSHTTPURLResponse *_Nullable,
                                  NSData *_Nullable,
                                  NSError *_Nullable,
                                  NSInteger))completion {
    executeRequest(^(NSHTTPURLResponse *response, NSData *data, NSError *error) {
        if (shouldRetry(response, error) && attemptNumber < maxRetries) {
            NSTimeInterval delay = [self delayForAttempt:attemptNumber];
            NRLOG_AGENT_DEBUG(@"NRMARetryOrchestrator: retrying after %.1fs (attempt %ld/%ld)",
                              delay, (long)(attemptNumber + 2), (long)(maxRetries + 1));
            waitForDelay(delay, ^{
                [self attemptRequest:executeRequest
                       attemptNumber:attemptNumber + 1
                          maxRetries:maxRetries
                         shouldRetry:shouldRetry
                        waitForDelay:waitForDelay
                          completion:completion];
            });
        } else {
            completion(response, data, error, attemptNumber);
        }
    });
}

- (NSTimeInterval) delayForAttempt:(NSInteger)attempt {
    // The first retry fires immediately; exponential backoff starts on the second retry.
    if (attempt == 0) return 0.0;
    NSTimeInterval exponential = self.initialDelay * pow(2.0, (double)(attempt - 1));
    return MIN(self.maxDelay, exponential);
}

+ (BOOL (^)(NSHTTPURLResponse *_Nullable, NSError *_Nullable)) standardShouldRetry {
    return ^BOOL(NSHTTPURLResponse *response, NSError *error) {
        if (error != nil) {
            return YES;
        }
        NSInteger status = response.statusCode;
        return status == 429 || status == 500 || status == 502 || status == 503 || status == 504;
    };
}

+ (NRMAWaitForDelayBlock) syncWaitForDelay {
    return ^(NSTimeInterval delay, dispatch_block_t onReady) {
        if (delay > 0) {
            [NSThread sleepForTimeInterval:delay];
        }
        onReady();
    };
}

+ (NRMAWaitForDelayBlock) asyncWaitForDelayOnQueue:(dispatch_queue_t)queue {
    return ^(NSTimeInterval delay, dispatch_block_t onReady) {
        if (delay > 0) {
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(delay * NSEC_PER_SEC)),
                           queue,
                           onReady);
        } else {
            dispatch_async(queue, onReady);
        }
    };
}

@end
