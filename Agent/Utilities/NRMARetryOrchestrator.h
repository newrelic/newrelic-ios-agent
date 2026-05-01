//
//  NRMARetryOrchestrator.h
//  NewRelicAgent
//
//  Copyright © 2025 New Relic. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/// Block that performs a single network request attempt and delivers the result via callback.
/// Sync implementation: calls onResponse before returning (e.g. URLSession wrapped with DispatchSemaphore).
/// Async implementation: fires a non-blocking request and calls onResponse in the completion handler.
typedef void (^NRMAExecuteRequestBlock)(void (^onResponse)(NSHTTPURLResponse *_Nullable response,
                                                            NSData *_Nullable data,
                                                            NSError *_Nullable error));

/// Block that waits for a delay and then calls onReady.
/// Sync implementation: [NSThread sleepForTimeInterval:delay] then onReady().
/// Async implementation: dispatch_after(delay, queue, onReady) without blocking.
typedef void (^NRMAWaitForDelayBlock)(NSTimeInterval delaySeconds, dispatch_block_t onReady);

/// Stateless retry orchestrator. Calls executeRequest up to (maxRetries + 1) times,
/// inserting exponential backoff delays between attempts via waitForDelay.
///
/// Because orchestration proceeds entirely through callbacks, the same code path runs
/// correctly whether the supplied executeRequest and waitForDelay blocks are synchronous
/// (blocking the calling thread) or asynchronous (returning immediately and continuing
/// on a queue or thread).
@interface NRMARetryOrchestrator : NSObject

/// @param initialDelay Delay before the first retry, in seconds. Doubles for each subsequent retry.
/// @param maxDelay     Upper bound on retry delay, in seconds.
- (instancetype) initWithInitialDelay:(NSTimeInterval)initialDelay
                             maxDelay:(NSTimeInterval)maxDelay;

/// Execute a request with automatic retry.
///
/// @param maxRetries      Maximum number of retry attempts after the initial attempt.
///                        Pass 0 to make a single attempt with no retries.
/// @param executeRequest  Called once per attempt. Must call onResponse exactly once per invocation.
///                        Sync impl: calls onResponse before returning.
///                        Async impl: calls onResponse inside a completion handler.
/// @param shouldRetry     Called after each attempt. Return YES to schedule a retry.
/// @param waitForDelay    Called between attempts with the calculated exponential delay.
///                        Sync impl: blocks with NSThread.sleep, then calls onReady.
///                        Async impl: schedules onReady via dispatch_after without blocking.
/// @param completion      Called exactly once after the final attempt with the response and
///                        the number of retries that were made (0 if first attempt succeeded).
- (void) executeWithMaxRetries:(NSInteger)maxRetries
                executeRequest:(NRMAExecuteRequestBlock)executeRequest
                   shouldRetry:(BOOL (^)(NSHTTPURLResponse *_Nullable, NSError *_Nullable))shouldRetry
                  waitForDelay:(NRMAWaitForDelayBlock)waitForDelay
                    completion:(void (^)(NSHTTPURLResponse *_Nullable response,
                                        NSData *_Nullable data,
                                        NSError *_Nullable error,
                                        NSInteger retryCount))completion;

/// Returns a shouldRetry block that retries on any network error and HTTP 429/500/502/503/504.
+ (BOOL (^)(NSHTTPURLResponse *_Nullable, NSError *_Nullable)) standardShouldRetry;

/// Returns a waitForDelay block that blocks the calling thread via NSThread.sleep.
/// Use with synchronous executeRequest implementations.
+ (NRMAWaitForDelayBlock) syncWaitForDelay;

/// Returns a waitForDelay block that schedules onReady on the given queue after the delay
/// without blocking the calling thread.
/// Use with asynchronous executeRequest implementations.
+ (NRMAWaitForDelayBlock) asyncWaitForDelayOnQueue:(dispatch_queue_t)queue;

@end

NS_ASSUME_NONNULL_END
