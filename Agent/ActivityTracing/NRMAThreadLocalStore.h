//
//  NRMAThreadLocalStore.h
//  NewRelicAgent
//
//  Created by Jonathan Karon on 2/20/14.
//  Copyright © 2023 New Relic. All rights reserved.
//
//  Per-thread segment stacks, keyed by interaction.
//
//  Each thread used to have exactly one frame pointer and one open-segment stack, which was
//  sufficient while the agent could only ever have one activity trace in flight. Now that
//  NRMATraceController keeps a registry of concurrent interactions, a single stack per thread would
//  interleave two interactions' segments onto one another: interaction B's push would land on top of
//  interaction A's frame, and A's pop would then fail to find its own trace at the top of the stack.
//
//  So the state is keyed (thread, interactionId). Each thread also carries a *current* interaction
//  id, which is the ambient interaction for instrumented code on that thread. Every legacy entry
//  point below resolves against that ambient id, so callers that never opt into concurrency behave
//  exactly as they did.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@class NRMATrace;

@interface NRMAThreadLocalStore : NSObject

#pragma mark - Ambient interaction for this thread

/// The interaction that instrumented code on this thread is currently considered to be inside.
/// nil when this thread has no interaction bound, in which case the caller should fall back to the
/// controller's most-recently-started interaction (see +[NRMATraceController currentTrace]).
+ (nullable NSString *)currentInteractionId;

/// Binds this thread to `interactionId`. Pass nil to unbind. Returns the id that was bound before
/// the call, so a caller entering an interaction on a thread can restore the previous binding on the
/// way out — nested interactions on one thread unwind correctly.
+ (nullable NSString *)setCurrentInteractionId:(nullable NSString *)interactionId;

#pragma mark - Segment stack

/** clear the thread's trace stack and frame ptr for rootTrace's interaction, set rootTrace as the
    0th item on that stack, and make its interaction current on this thread */
+ (void)setThreadRootTrace:(NRMATrace *)rootTrace;

/** push childTrace onto the stack for childTrace's interaction on this thread and set it as the
    frame ptr. if parentTrace is not on the same thread this will clear that stack and set
    parentTrace as the 0th item before pushing childTrace. */
+ (BOOL)pushChild:(NRMATrace *)childTrace forParent:(NRMATrace *)parentTrace;

/** if the innermost element on `trace`'s interaction stack is equal to `trace` remove it, set the
    parent trace to be active on this thread, and return the parent trace */
+ (BOOL)popCurrentTraceIfEqualTo:(NRMATrace *)trace
                 returningParent:(NRMATrace *_Nullable __autoreleasing *_Nullable)parent;

/** return the currently active trace segment (i.e. frame ptr) for this thread's ambient interaction */
+ (nullable NRMATrace *)threadLocalTrace;

/** return the currently active trace segment for `interactionId` on this thread */
+ (nullable NRMATrace *)threadLocalTraceForInteractionId:(nullable NSString *)interactionId;

#pragma mark - Teardown

/** delete thread-local data on all threads, for every interaction */
+ (void)destroyStore;

/** delete this interaction's stacks on every thread, leaving other interactions' state intact.
    Used when a single interaction completes while others are still running. */
+ (void)destroyStateForInteractionId:(nullable NSString *)interactionId;

@end

NS_ASSUME_NONNULL_END
