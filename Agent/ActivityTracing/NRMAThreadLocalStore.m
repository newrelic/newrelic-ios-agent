//
//  NRMAThreadLocalStore.m
//  NewRelicAgent
//
//  Created by Jonathan Karon on 2/20/14.
//  Copyright © 2023 New Relic. All rights reserved.
//

#import "NRMAThreadLocalStore.h"

#import "NRMATrace.h"
#import "NRLogger.h"
#import "NRMATaskQueue.h"
#import "NRConstants.h"
#import "NRMAMetric.h"
#import "NRMATraceController.h"

#import <pthread.h>

const NSString* NRMA_TRACE_FIELD_KEY = @"_nr_threadTrace";
const NSString* NRMA_TRACE_STACK_KEY = @"_nr_threadStackTrace";
// Per-thread: interactionId -> {NRMA_TRACE_FIELD_KEY: frame, NRMA_TRACE_STACK_KEY: stack}
static NSString* const NRMA_INTERACTIONS_KEY = @"_nr_threadInteractions";
// Per-thread: the interaction instrumented code on this thread is currently inside.
static NSString* const NRMA_CURRENT_INTERACTION_KEY = @"_nr_threadCurrentInteraction";
// Stands in for an interaction id when a trace has none. A root trace is built before its machine
// exists, and a caller can still push segments before any id is assigned; bucketing those under one
// stable key keeps the legacy single-interaction behaviour intact rather than dropping the segment.
static NSString* const NRMA_UNSCOPED_INTERACTION_KEY = @"_nr_unscopedInteraction";

// Internals. Declared up front so definition order below does not matter. Every one of these assumes
// the caller already holds __threadDictionaryLock.
@interface NRMAThreadLocalStore()
+ (NSMutableDictionary*) currentThreadDictionary;
+ (NSString*) scopeKeyForTrace:(NRMATrace*)trace;
+ (NSMutableDictionary*) scopeDictionaryForInteractionId:(NSString*)interactionId;
+ (NRMATrace*) frameForInteractionId:(NSString*)interactionId;
+ (NSMutableArray*) threadLocalStackForInteractionId:(NSString*)interactionId;
+ (void) setThreadLocalTrace:(NRMATrace*)trace;
+ (void) cleanupCurrentThreadLocalForInteractionId:(NSString*)interactionId;
+ (int) prepareNewThread:(NSMutableArray*)stack child:(NRMATrace*)child withParent:(NRMATrace*)parent;
+ (int) prepareSameThread:(NSMutableArray*)stack child:(NRMATrace*)child withParent:(NRMATrace*)parent;
+ (BOOL) isThreadMatchForChild:(NRMATrace*)child parent:(NRMATrace*)parent;
+ (BOOL) validateIsSerialParent:(NRMATrace*)parent child:(NRMATrace*)child;
@end

@implementation NRMAThreadLocalStore

static NSString *__threadDictionaryLock = @"threadDictionaryLock";
static NSMutableDictionary* __threadDictionaries;


// Public methods - must acquire a lock and prevent reentrancy

#pragma mark - Ambient interaction for this thread

+ (NSString *)currentInteractionId
{
    @synchronized(__threadDictionaryLock)
    {
        return [[self class] currentThreadDictionary][NRMA_CURRENT_INTERACTION_KEY];
    }
}

+ (NSString *)setCurrentInteractionId:(NSString *)interactionId
{
    @synchronized(__threadDictionaryLock)
    {
        NSMutableDictionary* threadDict = [[self class] currentThreadDictionary];
        NSString* previous = threadDict[NRMA_CURRENT_INTERACTION_KEY];
        if (interactionId.length) {
            threadDict[NRMA_CURRENT_INTERACTION_KEY] = [interactionId copy];
        } else {
            [threadDict removeObjectForKey:NRMA_CURRENT_INTERACTION_KEY];
        }
        return previous;
    }
}

#pragma mark - Segment stack

/** return the currently active trace segment (i.e. frame ptr) for this thread */
+ (NRMATrace*)threadLocalTrace
{
    @synchronized(__threadDictionaryLock)
    {
        NSMutableDictionary* threadDict = [[self class] currentThreadDictionary];
        return [[self class] frameForInteractionId:threadDict[NRMA_CURRENT_INTERACTION_KEY]];
    }
}

+ (NRMATrace*)threadLocalTraceForInteractionId:(NSString *)interactionId
{
    @synchronized(__threadDictionaryLock)
    {
        return [[self class] frameForInteractionId:interactionId];
    }
}

/** clear the thread's trace stack, and set rootTrace as the frame ptr and 0th item on the stack */
+ (void)setThreadRootTrace:(NRMATrace *)root
{
    if (root == nil) {
        NRLOG_AGENT_DEBUG(@"Attempted to load a nil trace.");
        return;
    }

    @synchronized(__threadDictionaryLock)
    {
        // A root trace defines its interaction's stack, so entering it also makes that interaction
        // ambient on this thread — instrumented code that follows lands in the right bucket.
        NSString* interactionId = [[self class] scopeKeyForTrace:root];
        [[self class] currentThreadDictionary][NRMA_CURRENT_INTERACTION_KEY] = interactionId;

        [NRMAThreadLocalStore setThreadLocalTrace:root];

        NSMutableArray *stack = [NRMAThreadLocalStore threadLocalStackForInteractionId:interactionId];
        [stack removeAllObjects];
        [stack addObject:root];
    }

    NRLOG_AGENT_DEBUG(@"Trace %@ is now active", root);
}

/** delete thread-local data on all threads */
+ (void)destroyStore
{
    NSMutableDictionary *oldDict;

    @synchronized(__threadDictionaryLock)
    {
        oldDict = __threadDictionaries;
        __threadDictionaries = nil;
    }
    [oldDict removeAllObjects];
}

+ (void)destroyStateForInteractionId:(NSString *)interactionId
{
    NSString* scopeKey = interactionId.length ? interactionId : NRMA_UNSCOPED_INTERACTION_KEY;

    @synchronized(__threadDictionaryLock)
    {
        // Every thread may hold a stack for this interaction — a single interaction's segments can be
        // spread across any number of threads — so all of them are visited, not just the caller's.
        for (NSMutableDictionary* threadDict in [__threadDictionaries allValues]) {
            NSMutableDictionary* interactions = threadDict[NRMA_INTERACTIONS_KEY];
            [interactions removeObjectForKey:scopeKey];
            if ([threadDict[NRMA_CURRENT_INTERACTION_KEY] isEqualToString:scopeKey]) {
                [threadDict removeObjectForKey:NRMA_CURRENT_INTERACTION_KEY];
            }
        }
    }
}

/** push childTrace onto the thread's stack and set it as the frame ptr.
 if parentTrace is not on the same thread this will clear the stack and set parentTrace as the 0th item before pushing childTrace. */

+ (BOOL) pushChild:(NRMATrace *)childTrace forParent:(NRMATrace *)parentTrace
{
    if (childTrace == nil || parentTrace == nil) {
        NRLOG_AGENT_VERBOSE(@"<Activity: \"%@\">  Trace enterMethod has nil child or parent trace segment. p=%@, c=%@",[NRMATraceController getCurrentActivityName], parentTrace, childTrace);
        return NO;
    }
    BOOL parentIsOnSameThread = [self isThreadMatchForChild:childTrace parent:parentTrace];
    @synchronized(__threadDictionaryLock)
    {
        // The child's interaction owns the stack. A cross-interaction parent would otherwise splice
        // this segment onto the wrong interaction's stack and corrupt both unwinds.
        NSString* scopeKey = [[self class] scopeKeyForTrace:childTrace];
        NSMutableArray *stack = [NRMAThreadLocalStore threadLocalStackForInteractionId:scopeKey];
        if (!parentIsOnSameThread) {
            //case for new thread
            [self prepareNewThread:stack child:childTrace withParent:parentTrace];
        } else {
            [self prepareSameThread:stack child:childTrace withParent:parentTrace];
        }
        [NRMAThreadLocalStore setThreadLocalTrace:childTrace];
        [stack addObject:childTrace];
    }

    return parentIsOnSameThread;
}

+ (int) prepareNewThread:(NSMutableArray*)stack child:(NRMATrace*)child withParent:(NRMATrace*)parent
{
    int error = 0;
    if (stack.count > 0) {
        NRLOG_AGENT_VERBOSE(@"<Activity: \"%@\"> thread local stack is not empty! Entering thread %ud from %ud, p=%@, c=%@, stack=%@",
                      [NRMATraceController getCurrentActivityName],
                      child.threadInfo.identity,
                      parent.threadInfo.identity,
                      parent, child, stack);
        [NRMATaskQueue queue:[[NRMAMetric alloc]
                            initWithName:kNRSupportabilityPrefix@"/OrphanedThreadLocalStackEntries"
                            value:[NSNumber numberWithInteger:stack.count]
                            scope:@""]];
        error = 1;
        [stack removeAllObjects];
    }

    [stack addObject:parent];

    return error;
}

+ (int) prepareSameThread:(NSMutableArray*)stack child:(NRMATrace*)child withParent:(NRMATrace*)parent
{
    int error = 0;

            if ([NRMAThreadLocalStore frameForInteractionId:[[self class] scopeKeyForTrace:child]] != parent) {
                if (![self validateIsSerialParent:parent child:child]) {
                    NRLOG_AGENT_ERROR(@"<Activity: \"%@\"> threadLocalTrace is not parentTrace! On thread %ud, p=%@, c=%@, f=%@, stack=%@",
                                [NRMATraceController getCurrentActivityName],
                                child.threadInfo.identity,
                                parent, child, [NRMAThreadLocalStore frameForInteractionId:[[self class] scopeKeyForTrace:child]], stack);
                    [NRMATaskQueue queue:[[NRMAMetric alloc]
                                        initWithName:kNRSupportabilityPrefix@"/ThreadLocalParentNotField"
                                        value:@1
                                        scope:@""]];
                    error = 1;
                }
            } else if ([stack lastObject] != parent) {
                if (![self validateIsSerialParent:parent child:child]) {

                    NRLOG_AGENT_ERROR(@"<Activity: \"%@\"> parentTrace is not at bottom of threadLocalStack! On thread %ud, p=%@, c=%@, f=%@, stack=%@",
                                [NRMATraceController getCurrentActivityName],
                                child.threadInfo.identity,
                                parent, child, [NRMAThreadLocalStore frameForInteractionId:[[self class] scopeKeyForTrace:child]], stack);
                    [NRMATaskQueue queue:[[NRMAMetric alloc]
                                        initWithName:kNRSupportabilityPrefix@"/ThreadLocalParentNotOnStack"
                                        value:@1
                                        scope:@""]];

                    error = 2;
                }
            }
    return error;
}

+ (BOOL) isThreadMatchForChild:(NRMATrace*)child parent:(NRMATrace*)parent
{
    return child.threadInfo.identity == parent.threadInfo.identity;
}

+ (BOOL) validateIsSerialParent:(NRMATrace*)parent child:(NRMATrace*)child
{
    if (parent.threadInfo.identity == child.threadInfo.identity) {
        //this means the child executed serially in relation to the parent
        //on the same thread as the parent.
        //we want to perserve this relationship
        return child.entryTimestamp > parent.exitTimestamp;
    }
    return NO;
}
/** if the innermost element on the stack is equal to `trace` remove current trace from stack,
 set parent trace to be active on this thread, and return the parent trace
 returns YES if the trace's metric data should be recorded */
+ (BOOL)popCurrentTraceIfEqualTo:(NRMATrace*)trace returningParent:(NRMATrace *__autoreleasing *)parent
{
    *parent = nil;
    @synchronized(__threadDictionaryLock)
    {
        // Unwind the stack belonging to this trace's own interaction, not whichever interaction
        // happens to be ambient on the thread right now: an interleaved interaction must not be able
        // to pop another's frames.
        NSString* scopeKey = [[self class] scopeKeyForTrace:trace];
        NSMutableDictionary *scopeDict = [[self class] scopeDictionaryForInteractionId:scopeKey];

        NRMATrace *currentTrace = scopeDict[NRMA_TRACE_FIELD_KEY];
        NSMutableArray *stack = scopeDict[NRMA_TRACE_STACK_KEY];

        if (trace.threadInfo.identity != pthread_mach_thread_np(pthread_self()))
        {
            // whoops, trace is on the wrong thread
            NRLOG_AGENT_VERBOSE(@"<Activity: \"%@\"> popCurrentTrace: exited trace is not on the current thread! et=%@, tlc=%@",[NRMATraceController getCurrentActivityName], trace, currentTrace);
            return NO;
        }

        if (trace != currentTrace) {
            NRLOG_AGENT_VERBOSE(@"<Activity: \"%@\"> popCurrentTrace: exited trace is not the current threadLocalTrace. et=%@, tlc=%@",[NRMATraceController getCurrentActivityName], trace, currentTrace);
        }

        if ([stack lastObject] != trace) {
            if ([stack containsObject:trace]) {
                while ([stack lastObject] != nil && [stack lastObject] != trace) {
                    [stack removeLastObject];
                }
            }
        }

        if ([stack lastObject] == trace) {
            [stack removeLastObject];
        }
        else
        {
            NRLOG_AGENT_VERBOSE(@"<Activity: \"%@\"> popCurrentTrace: exited trace is not on the current stack! et=%@, tlc=%@",[NRMATraceController getCurrentActivityName], trace, stack);
        }

        *parent = [stack lastObject];

        // update the frame ptr to the parent (if on the same thread)
        if ((*parent).threadInfo.identity == trace.threadInfo.identity) {
            scopeDict[NRMA_TRACE_FIELD_KEY] = *parent;
        }
        else {
            // or clean out this interaction's state on this thread. Scoped rather than wholesale:
            // other interactions may still hold live stacks on this same thread.
            [[self class] cleanupCurrentThreadLocalForInteractionId:scopeKey];
        }

        return YES;
    }
}




// Internal only - should only be called if you already have a lock on __threadDictionaryLock


+ (NSMutableDictionary*)currentThreadDictionary
{
    if (!__threadDictionaries) {
        __threadDictionaries = [[NSMutableDictionary alloc] init];
    }

    NSString* threadID = [NSString stringWithFormat:@"%d",pthread_mach_thread_np(pthread_self())];
    NSMutableDictionary* threadDictionary = nil;

    threadDictionary = [__threadDictionaries objectForKey:threadID];
    if (!threadDictionary) {
        threadDictionary = [[NSMutableDictionary alloc] init];
        [__threadDictionaries setObject:threadDictionary forKey:threadID];
    }

    return threadDictionary;
}

/// The key a trace's segment stack lives under. Traces created before their interaction had an id
/// fall back to a single shared bucket rather than being dropped.
+ (NSString*)scopeKeyForTrace:(NRMATrace*)trace
{
    NSString* interactionId = trace.interactionId;
    return interactionId.length ? interactionId : NRMA_UNSCOPED_INTERACTION_KEY;
}

/// The {frame, stack} pair for one interaction on the current thread, created on demand.
+ (NSMutableDictionary*)scopeDictionaryForInteractionId:(NSString*)interactionId
{
    NSString* scopeKey = interactionId.length ? interactionId : NRMA_UNSCOPED_INTERACTION_KEY;
    NSMutableDictionary* threadDict = [NRMAThreadLocalStore currentThreadDictionary];

    NSMutableDictionary* interactions = threadDict[NRMA_INTERACTIONS_KEY];
    if (interactions == nil) {
        interactions = [[NSMutableDictionary alloc] init];
        threadDict[NRMA_INTERACTIONS_KEY] = interactions;
    }

    NSMutableDictionary* scopeDict = interactions[scopeKey];
    if (scopeDict == nil) {
        scopeDict = [[NSMutableDictionary alloc] init];
        interactions[scopeKey] = scopeDict;
    }

    return scopeDict;
}

+ (NRMATrace*)frameForInteractionId:(NSString*)interactionId
{
    return [[self class] scopeDictionaryForInteractionId:interactionId][NRMA_TRACE_FIELD_KEY];
}

+ (NSMutableArray*)threadLocalStackForInteractionId:(NSString*)interactionId {
    NSMutableDictionary* scopeDict = [[self class] scopeDictionaryForInteractionId:interactionId];

    NSMutableArray* array = scopeDict[NRMA_TRACE_STACK_KEY];
    if (array == nil) {
        array = [[NSMutableArray alloc] init];
        scopeDict[NRMA_TRACE_STACK_KEY] = array;
    }

    return array;
}

+ (void) setThreadLocalTrace:(NRMATrace*)trace
{
    if (trace == nil) {
        NRLOG_AGENT_ERROR(@"Attempted to set a nil trace to the thread  local dictionary");
        return;
    }

    [[self class] scopeDictionaryForInteractionId:[[self class] scopeKeyForTrace:trace]][NRMA_TRACE_FIELD_KEY] = trace;
}


+ (void)cleanupCurrentThreadLocalForInteractionId:(NSString*)interactionId
{
    if (!__threadDictionaries) {
        return;
    }
    NSString* scopeKey = interactionId.length ? interactionId : NRMA_UNSCOPED_INTERACTION_KEY;
    NSString* threadID = [NSString stringWithFormat:@"%d",pthread_mach_thread_np(pthread_self())];
    NSMutableDictionary* threadDict = __threadDictionaries[threadID];

    NSMutableDictionary* interactions = threadDict[NRMA_INTERACTIONS_KEY];
    [interactions removeObjectForKey:scopeKey];
    if ([threadDict[NRMA_CURRENT_INTERACTION_KEY] isEqualToString:scopeKey]) {
        [threadDict removeObjectForKey:NRMA_CURRENT_INTERACTION_KEY];
    }

    // Drop the whole thread entry once nothing is left, which is what keeps the store from growing
    // an entry per thread that ever ran an interaction.
    if (interactions.count == 0) {
        [__threadDictionaries removeObjectForKey:threadID];
    }
}

// for testing only
+ (NSMutableDictionary*)threadDictionaries
{
    if (!__threadDictionaries) {
        __threadDictionaries = [[NSMutableDictionary alloc] init];
    }
    return __threadDictionaries;
}
@end
