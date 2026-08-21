    //
//  NRMATraceController.m
//  NewRelicAgent
//
//  Created by Bryce Buchanan on 9/9/13.
//  Copyright © 2023 New Relic. All rights reserved.
//

#import "NRMAMeasurements.h"
#import "NRMATraceController.h"
#import "NRMATrace.h"
#import "NRMAActivityTrace.h"
#import "NRCustomMetrics+private.h"
#import "NRMAMeasurementTransmitter.h"
#import "NewRelicInternalUtils.h"
#import "NRMAHarvestController.h"
#import "NRMATaskQueue.h"
#import "NRMAExceptionHandler.h"
#import "NRMAMetric.h"
#import "NRMAThreadLocalStore.h"
#import "NRMALastActivityTraceController.h"
#import "NRMAInteractionHistoryObjCInterface.h"
#import <objc/runtime.h>
#import "NRMATraceMachine.h"
#import "NewRelicAgentInternal.h"
#import "NRMAFlags.h"
#import "NRMAViewContext.h"
// Quiescence timeout: how long an interaction may go with no instrumented method entry/exit before
// the trace machine decides it is finished. This is the setting that used to cap an interaction at
// roughly a second: at 0.5s an interaction could not outlive its screen-load burst, so a screen the
// user sat on for 30s still reported a sub-second interaction.
//
// At 30s the quiescence timer stops being the thing that ends a typical interaction. A UIKit
// auto-interaction now ends when the next screen supersedes it (NRMA__shouldCancelCurrentTrace), so
// its duration becomes screen dwell time; a custom interaction ends when the host calls
// stopCurrentInteraction:. The timer remains the backstop for an interaction that is simply
// abandoned. Hosts wanting the old load-only semantics can call +setHealthyTraceTimeout:.
//
// #define rather than a const: these initialize file-static storage below, and in C a const
// variable is not a constant expression.
#define NRMA_HEALTHY_TRACE_TIMEOUT 30.0
// Hard ceiling. The real backstop for an interaction that is never explicitly stopped — note that a
// custom activity is immune to supersession (-isInteractionObject: always returns YES for it), so
// without this a single missed stopCurrentInteraction: would block every later interaction for the
// rest of the foreground session. Settable via +setUnhealthyTraceTimeout:.
#define NRMA_UNHEALTHY_TRACE_TIMEOUT 300.0

NSString* const kNRMACustomInteractionIdentifier = @"CUSTOM";
const int NRMA_MAX_NODE_LIMIT = 2000;

// The registry of live interactions, keyed by NRMAActivityTrace.interactionId. Replaces the single
// __traceMachine slot this class used to hold.
//
// Concurrency is opt-in: +startTracingWithRootTrace: still supersedes whatever is running, so the
// UIKit auto-interaction path and every existing caller see exactly one live interaction and behave
// as before. Only +startConcurrentTracingWithName:interactionObject: adds a machine alongside the
// others.
static NSMutableDictionary<NSString*, NRMATraceMachine*>* __traceMachines;
// The interaction a thread with no explicit binding resolves to — the most recently started one.
// This is what preserves the old "there is a current interaction" behaviour for instrumented code
// that never opts into concurrency.
static NSString* __mostRecentInteractionId;

// Ceiling on live interactions. Each one holds an activity trace, a measurement pool and three
// measurement transmitters, and every one of them is harvested; an unbounded registry would let a
// host that never stops its interactions grow memory without limit. Beyond the cap, a concurrent
// start is refused rather than silently superseding something.
#define NRMA_MAX_CONCURRENT_INTERACTIONS 16
static NSUInteger __maxConcurrentInteractions = NRMA_MAX_CONCURRENT_INTERACTIONS;

NSString * const kNRMAStartAndEndTracingLock = @"startTracingLock";

@interface NRMATraceController()



+ (void) exitMethodWithTimestampMillis:(double)exitTimestampMilliseconds;
+ (void) completeTrace:(NRMATrace*)trace withExitTimestampMillis:(NSNumber*)exitTimestampMilliseconds;
+ (BOOL) completeActivityTraceWithExitTimestampMillis:(double)exitTimestampMilliseconds;
+ (BOOL) completeActivityTraceWithExitTimestampMillis:(double)exitTimestampMilliseconds
                                         endedByTimer:(BOOL)endedByTimer;

// Registry internals. Declared up front so the definition order below does not matter.
+ (NRMATraceMachine*) traceMachine;
+ (NRMATraceMachine*) traceMachineForInteractionId:(NSString*)interactionId;
+ (NSMutableDictionary*) traceMachinesLocked;
+ (void) registerTraceMachine:(NRMATraceMachine*)traceMachine forInteractionId:(NSString*)interactionId;
+ (void) unregisterTraceMachineForInteractionId:(NSString*)interactionId;
+ (void) clearMeasurementTransmitters;
+ (void) clearMeasurementTransmittersForTraceMachine:(NRMATraceMachine*)traceMachine;
+ (void) publishRunningInteractionId:(NSString*)interactionId name:(NSString*)name;
+ (void) clearPublishedInteractionIdIfCurrent:(NSString*)interactionId;
+ (BOOL) shouldCorrelateMobileViews;
+ (NSDictionary*) correlationAttributesForActivityTrace:(NRMAActivityTrace*)activityTrace;
+ (NRMATrace*) getCurrentTrace;
+ (NRMATrace*) getCurrentTraceForInteractionId:(NSString*)interactionId;
+ (BOOL) isTracingActiveForSegmentParent:(NRMATrace*)parentTrace;
+ (NRMATrace*) threadLocalTrace;
+ (BOOL) newTraceSetup:(NRMATrace*)newTrace parentTrace:(NRMATrace*)parentTrace;
+ (BOOL) completeActivityTraceForInteractionId:(NSString*)interactionId
                           exitTimestampMillis:(double)exitTimestampMilliseconds
                                  endedByTimer:(BOOL)endedByTimer;

@end

@implementation NRMATraceController


static const NSString* __newRelicTraceMachAsyncLock = @"lock";

+ (NSMutableDictionary*) traceMachinesLocked
{
    if (__traceMachines == nil) {
        __traceMachines = [[NSMutableDictionary alloc] init];
    }
    return __traceMachines;
}

/// The interaction this thread is operating inside: an explicit per-thread binding if one exists,
/// otherwise the most recently started interaction.
+ (NSString*) currentInteractionId
{
    NSString* bound = [NRMAThreadLocalStore currentInteractionId];
    if (bound.length) {
        @synchronized(__newRelicTraceMachAsyncLock) {
            // A stale binding — the interaction it names has already completed — must not shadow the
            // live one, or instrumented code on this thread would silently stop being recorded.
            if ([self traceMachinesLocked][bound] != nil) {
                return bound;
            }
        }
    }
    @synchronized(__newRelicTraceMachAsyncLock) {
        return __mostRecentInteractionId;
    }
}

+ (NRMATraceMachine*)traceMachine
{
    return [self traceMachineForInteractionId:[self currentInteractionId]];
}

+ (NRMATraceMachine*)traceMachineForInteractionId:(NSString*)interactionId
{
    if (interactionId.length == 0) {
        return nil;
    }
    @synchronized(__newRelicTraceMachAsyncLock) {
        return [self traceMachinesLocked][interactionId];
    }
}

+ (NSArray<NSString*>*)activeInteractionIds
{
    @synchronized(__newRelicTraceMachAsyncLock) {
        return [[self traceMachinesLocked] allKeys];
    }
}

+ (NSUInteger)activeInteractionCount
{
    @synchronized(__newRelicTraceMachAsyncLock) {
        return [self traceMachinesLocked].count;
    }
}

+ (NSUInteger)maxConcurrentInteractions
{
    return __maxConcurrentInteractions;
}

+ (void)setMaxConcurrentInteractions:(NSUInteger)maxConcurrentInteractions
{
    if (maxConcurrentInteractions == 0) {
        NRLOG_AGENT_ERROR(@"Ignoring a max concurrent interaction count of 0; no interaction could ever start.");
        return;
    }
    __maxConcurrentInteractions = maxConcurrentInteractions;
}

/// Adds `traceMachine` to the registry under `interactionId` and makes it the fallback for threads
/// with no explicit binding.
+ (void) registerTraceMachine:(NRMATraceMachine*)traceMachine forInteractionId:(NSString*)interactionId
{
    if (traceMachine == nil || interactionId.length == 0) {
        return;
    }
    @synchronized(__newRelicTraceMachAsyncLock) {
        [self traceMachinesLocked][interactionId] = traceMachine;
        __mostRecentInteractionId = [interactionId copy];
    }
}

/// Removes one interaction from the registry. When it was the most-recent fallback, another live
/// interaction takes over that role so unbound threads keep resolving to something real.
+ (void) unregisterTraceMachineForInteractionId:(NSString*)interactionId
{
    if (interactionId.length == 0) {
        return;
    }
    @synchronized(__newRelicTraceMachAsyncLock) {
        NSMutableDictionary* machines = [self traceMachinesLocked];
        [machines removeObjectForKey:interactionId];
        if ([__mostRecentInteractionId isEqualToString:interactionId]) {
            // anyObject rather than a real recency order: the registry is unordered, and the only
            // requirement is that an unbound thread resolves to *a* live interaction. Callers that
            // care which one bind their thread explicitly.
            __mostRecentInteractionId = [[machines allKeys] firstObject];
        }
    }
}

+ (void) bindCurrentThreadToInteractionId:(NSString*)interactionId
{
    [NRMAThreadLocalStore setCurrentInteractionId:interactionId];
}

+ (NSString*) currentThreadInteractionId
{
    return [NRMAThreadLocalStore currentInteractionId];
}


+ (void) cleanup
{
    [self cleanupInteractionId:[self currentInteractionId]];
}

/// Tears down a single interaction: its measurement pool, its transmitters, its registry entry, and
/// its per-thread segment stacks. Scoped rather than wholesale — the thread-local store and the
/// measurement transmitters both used to be destroyed globally here, which with a registry would
/// take out interactions that are still running.
+ (void) cleanupInteractionId:(NSString*)interactionId
{
    NRMATraceMachine* localTraceMachine = [self traceMachineForInteractionId:interactionId];
    [localTraceMachine.tracePool shutdown];
    [NRMATraceController clearMeasurementTransmittersForTraceMachine:localTraceMachine];
    [self unregisterTraceMachineForInteractionId:interactionId];
    [NRMAThreadLocalStore destroyStateForInteractionId:interactionId];
}

/// Tears down every live interaction. For agent shutdown and test teardown, where the whole
/// thread-local store should go with it.
+ (void) cleanupAll
{
    for (NSString* interactionId in [self activeInteractionIds]) {
        NRMATraceMachine* machine = [self traceMachineForInteractionId:interactionId];
        [machine.tracePool shutdown];
        [NRMATraceController clearMeasurementTransmittersForTraceMachine:machine];
        [self unregisterTraceMachineForInteractionId:interactionId];
    }
    @synchronized(__newRelicTraceMachAsyncLock) {
        [[self traceMachinesLocked] removeAllObjects];
        __mostRecentInteractionId = nil;
    }
    [NRMAThreadLocalStore destroyStore];
}



// Statically initialized rather than lazily via dispatch_once. These are settable from the host app,
// and a default applied on first *read* would clobber a value set before that first read — which is
// the normal ordering, since a host configures the agent at startup and nothing reads the timeout
// until the first interaction begins.
//
// Both are plain doubles read on the main run loop (timer scheduling) and written from whichever
// thread calls the setter. A torn read is not possible for an aligned double on any platform the
// agent supports, and a stale read only affects the interval of the next timer, so no lock.
static NSTimeInterval __unhealthyTraceTimeout = NRMA_UNHEALTHY_TRACE_TIMEOUT;
+ (NSTimeInterval) unhealthyTraceTimeout
{
    return __unhealthyTraceTimeout;
}

+ (void) setUnhealthyTraceTimeout:(NSTimeInterval)unhealthyTraceTimeout
{
    if (unhealthyTraceTimeout <= 0) {
        NRLOG_AGENT_ERROR(@"Ignoring non-positive unhealthy trace timeout %f; interactions would complete immediately.", unhealthyTraceTimeout);
        return;
    }
    __unhealthyTraceTimeout = unhealthyTraceTimeout;
}

static NSTimeInterval __healthyTraceTimeout = NRMA_HEALTHY_TRACE_TIMEOUT;
+ (NSTimeInterval) healthyTraceTimeout
{
    return __healthyTraceTimeout;
}

+ (void) setHealthyTraceTimeout:(NSTimeInterval) healthyTraceTimeout
{
    if (healthyTraceTimeout <= 0) {
        NRLOG_AGENT_ERROR(@"Ignoring non-positive healthy trace timeout %f; interactions would complete immediately.", healthyTraceTimeout);
        return;
    }
    __healthyTraceTimeout = healthyTraceTimeout;
}


#pragma mark - MobileViews correlation

// Correlation is active whenever either MobileViews producer is enabled, matching the referrer
// stamping rule in +[NewRelic recordBreadcrumb:attributes:]. With both flags off (the default) a
// default-configured agent behaves exactly as before: nothing is published to NRMAViewContext and
// no attributes are added to the interaction event.
+ (BOOL) shouldCorrelateMobileViews
{
    return [NRMAFlags shouldEnableAutomaticMobileViews] || [NRMAFlags shouldEnableManualMobileViews];
}

// Publishes the running interaction so MobileView events emitted while it runs carry its identity.
//
// LOCK ORDER: callers hold kNRMAStartAndEndTracingLock, and NRMAViewContext takes its own
// os_unfair_lock and never calls back into this class. That edge must stay one-way
// (trace lock -> view lock) or the two locks can deadlock.
+ (void) publishRunningInteractionId:(NSString*)interactionId name:(NSString*)name
{
    if (![self shouldCorrelateMobileViews]) { return; }
    [[NRMAViewContext sharedInstance] setCurrentInteractionId:interactionId name:name];
}

// Clears the published identity only when `interactionId` is the one currently published.
//
// NRMAViewContext holds a single interaction slot, so with several interactions live it names
// whichever published most recently. Completing any other one must leave that slot alone; otherwise
// the first sibling to finish would strip interactionId from every subsequent MobileView event even
// though an interaction is still running.
+ (void) clearPublishedInteractionIdIfCurrent:(NSString*)interactionId
{
    if (![self shouldCorrelateMobileViews]) { return; }
    [[NRMAViewContext sharedInstance] clearCurrentInteractionIdIfEqualTo:interactionId];
}

// Read at *completion*, not at start. An auto-interaction starts in viewDidLoad/viewWillAppear:,
// when the outgoing screen is still current; the loading screen only becomes current in
// viewDidAppear:. Binding at start would blame the previous screen for every screen load.
+ (NSDictionary*) correlationAttributesForActivityTrace:(NRMAActivityTrace*)activityTrace
{
    if (![self shouldCorrelateMobileViews]) { return nil; }

    NSMutableDictionary* attrs =
        [NSMutableDictionary dictionaryWithDictionary:[[NRMAViewContext sharedInstance] viewCorrelationAttributes]];
    if (activityTrace.interactionId.length > 0) {
        attrs[kNRMAAttributeInteractionId] = activityTrace.interactionId;
    }
    return attrs.count > 0 ? attrs : nil;
}

#pragma mark - Static Functions
+ (NSString*) getCurrentActivityName
{
    NSString* scope = @"";
#ifndef  DISABLE_NRMA_EXCEPTION_WRAPPER
    @try {
#endif
        // Snapshot each object into a local strong reference before dereferencing further.
        // traceMachine and activityTrace are atomic; name is atomic (see NRMAActivityTrace.h),
        // so each getter returns a retained+autoreleased value that a concurrent setter on
        // another thread cannot free before we copy it. Defensively copy to fully detach.
        NRMATraceMachine* localTraceMachine = [self traceMachine];
        NRMAActivityTrace* activityTrace = localTraceMachine.activityTrace;
        NSString* name = activityTrace.name;
        if (name.length) {
            scope = [name copy];
        }
#ifndef  DISABLE_NRMA_EXCEPTION_WRAPPER
    } @catch (NSException* exception) {
        [NRMAExceptionHandler logException:exception
                                   class:NSStringFromClass([self class])
                                selector:NSStringFromSelector(@selector(getCurrentActivityName))];
    }
#endif
    return scope ?: @"";
}


static NSString *__measurementLock = @"measurementTransmittersLock";

+ (void) clearMeasurementTransmitters
{
    [self clearMeasurementTransmittersForTraceMachine:[self traceMachine]];
}

/// Removes only `traceMachine`'s transmitters from the measurement engine. Each machine installs its
/// own three consumers in -setupTracePool, so tearing down one interaction must not unhook the
/// consumers belonging to interactions that are still running.
+ (void) clearMeasurementTransmittersForTraceMachine:(NRMATraceMachine*)traceMachine
{
    NSMutableArray* measurementTransmitters = traceMachine.measurementTransmitters;
    @synchronized(measurementTransmitters) {
        for (NRMAMeasurementTransmitter* transmitter in measurementTransmitters) {
            [NRMAMeasurements removeMeasurementConsumer:transmitter];
        }
    }
}



+ (void) startTracingWithName:(NSString *)name interactionObject:(id __unsafe_unretained)obj
{
    (void)[self startTracingWithName:name interactionObject:obj concurrent:NO];
}

/// Starts an interaction named `name`, returning its interactionId.
///
/// `concurrent` NO reproduces the historical behaviour: any running interaction is completed first,
/// so exactly one is ever live. YES leaves the others running and adds this one to the registry
/// alongside them, and binds the calling thread to it so instrumented code that follows on this
/// thread is attributed here rather than to whichever interaction started most recently.
///
/// Returns nil when the agent is shut down or the concurrency ceiling is already reached.
+ (NSString*) startTracingWithName:(NSString *)name
                 interactionObject:(id __unsafe_unretained)obj
                        concurrent:(BOOL)concurrent
{
    @synchronized(kNRMAStartAndEndTracingLock) {
        // If Agent is shutdown we shouldn't record traces.
        if([NewRelicAgentInternal sharedInstance].isShutdown) {
            return nil;
        }

        if (concurrent && [self activeInteractionCount] >= [self maxConcurrentInteractions]) {
            NRLOG_AGENT_ERROR(@"Refusing to start concurrent interaction \"%@\": %lu are already running (ceiling is %lu). Stop one, or raise +setMaxConcurrentInteractions:.",
                              name,
                              (unsigned long)[self activeInteractionCount],
                              (unsigned long)[self maxConcurrentInteractions]);
            return nil;
        }

        NRLOG_AGENT_VERBOSE(@"\"%@\" Activity started", name);
        NRMATrace* rootTrace = [NRMATraceController startTracing:NO superseding:!concurrent];
        if (rootTrace == nil) {
            return nil;
        }
        [[[NewRelicAgentInternal sharedInstance] analyticsController] setLastInteraction:name];
        NRMATraceMachine* traceMach = [self traceMachineForInteractionId:rootTrace.interactionId];
        traceMach.activityTrace.name = name;
        traceMach.activityTrace.initiatingObjectIdentifier = [NSString stringWithFormat:@"%p",obj];
        // Re-publish now that the real name is known; startTracingWithRootTrace: only had the
        // placeholder root-trace name to work with.
        [self publishRunningInteractionId:traceMach.activityTrace.interactionId name:name];
        [NRMAInteractionHistoryObjCInterface insertInteraction:name startTime:(long long)(traceMach.activityTrace.startTime)];
        return traceMach.activityTrace.interactionId;
    }
}

+ (BOOL) isInteractionObject:(id __unsafe_unretained)obj
{
    return [self isInteractionObject:obj forInteractionId:[self currentInteractionId]];
}

+ (BOOL) isInteractionObject:(id __unsafe_unretained)obj forInteractionId:(NSString*)interactionId
{
    NRMATraceMachine* traceMach = [self traceMachineForInteractionId:interactionId];
    if ([traceMach.activityTrace.initiatingObjectIdentifier isEqualToString:kNRMACustomInteractionIdentifier]) {
        //a special case, only custom activites are set to kNRMACustomInteractionIdentifier
        //and we want to prevent system activities from terminating a custom activity.
        return YES;
    }
    NSString* obj_addr = [NSString stringWithFormat:@"%p",obj];
    return [traceMach.activityTrace.initiatingObjectIdentifier isEqualToString:obj_addr];
}


// MARK: Bryce says persistentTrace is not used and a relic from the Android agent, no idea what it means.
+ (NRMATrace*) startTracing:(BOOL)persistentTrace
{
    return [self startTracing:persistentTrace superseding:YES];
}

+ (NRMATrace*) startTracing:(BOOL)persistentTrace superseding:(BOOL)superseding
{
    @synchronized(kNRMAStartAndEndTracingLock) {

        // If Agent is shutdown we shouldn't record traces.
        if([NewRelicAgentInternal sharedInstance].isShutdown) {
            return nil;
        }

        NRMATrace* rootTrace = [[NRMATrace alloc] init];
        rootTrace.persistent = persistentTrace;
        rootTrace.name = @"UI_Thread";
        rootTrace.entryTimestamp = NRMAMillisecondTimestamp();

        NRLOG_AGENT_VERBOSE(@"Started activity with root trace : %@", rootTrace);

        [NRMATraceController startTracingWithRootTrace:rootTrace superseding:superseding];

        return rootTrace;
    }
}

//this method is used by the custom api :
//+ (void) startInteractionFromMethodName:(NSString*)selectorName
//                                 object:(id)object
//                         customizedName:(NSString*)interactionName
//                     cancelRunningTrace:(BOOL)cancel
+ (void) startTracingWithRootTrace:(NRMATrace*)rootTrace
{
    [self startTracingWithRootTrace:rootTrace superseding:YES];
}

+ (void) startTracingWithRootTrace:(NRMATrace*)rootTrace superseding:(BOOL)superseding
{
    @synchronized(kNRMAStartAndEndTracingLock) {

        // If Agent is shutdown we shouldn't record traces.
        if([NewRelicAgentInternal sharedInstance].isShutdown) {
            return;
        }

        // Superseding is the historical behaviour and stays the default: the new interaction replaces
        // whatever was running. When it is off the running interactions are left alone and this one
        // joins them in the registry.
        if (superseding) {
            if ([NRMATraceController isTracingActive]) {
                [NRMATraceController completeActivityTrace];
            }

            [NRMATraceController cleanup];
        }

        NSString* activityName = rootTrace.name;
        rootTrace.name = @"UI_Thread";

        // Assigned before the machine is built so the id is available to stamp onto rootTrace, which
        // the thread-local store needs in order to file the root on the right interaction's stack.
        NSString* interactionId = [[NSUUID UUID] UUIDString];
        rootTrace.interactionId = interactionId;

        NRMATraceMachine* traceMach = [[NRMATraceMachine alloc] initWithRootTrace:rootTrace];

        traceMach.activityTrace.name = activityName;
        // Single choke point for activity-trace creation, so every interaction gets an id here.
        // The name is still the placeholder at this point; startTracingWithName: re-publishes it.
        traceMach.activityTrace.interactionId = interactionId;
        [self publishRunningInteractionId:interactionId name:nil];

        rootTrace.traceMachine = traceMach;

        // Registered before the root is filed so that anything the store logs about this interaction
        // can already resolve its machine.
        [self registerTraceMachine:traceMach forInteractionId:interactionId];

        // Also binds this interaction as ambient on the calling thread, so instrumented code that
        // follows here is attributed to it rather than to whichever interaction started last.
        [NRMAThreadLocalStore setThreadRootTrace:rootTrace];
        [traceMach.tracePool addMeasurementConsumer:rootTrace];
    }
}

+ (BOOL) completeActivityTrace
{
    return [self completeActivityTraceWithExitTimestampMillis:NRMAMillisecondTimestamp()];
}

+ (BOOL) completeActivityTraceWithTimer:(NRTimer*)timer
{
    return [self completeActivityTraceWithExitTimestampMillis:timer.endTimeMillis];
}

// Called only by the trace machine's healthy/unhealthy timers. Separated from the ordinary
// completion path because the two mean different things about *when* the interaction ended: a timer
// firing says "nothing has happened for a while", so the interaction ended back at its last
// instrumented boundary, not now. Ending it at "now" would add the whole timeout to every duration.
+ (BOOL) completeActivityTraceOnTimeout
{
    return [self completeActivityTraceWithExitTimestampMillis:NRMAMillisecondTimestamp()
                                                endedByTimer:YES];
}

/// Timeout completion for one specific interaction. The trace machine's timers must use this rather
/// than +completeActivityTraceOnTimeout: each machine owns its own healthy/unhealthy timers, so with
/// several interactions live, a timer resolving "the current interaction" would complete a sibling
/// instead of the machine whose timer actually fired.
+ (BOOL) completeActivityTraceOnTimeoutForInteractionId:(NSString*)interactionId
{
    return [self completeActivityTraceForInteractionId:interactionId
                              exitTimestampMillis:NRMAMillisecondTimestamp()
                                     endedByTimer:YES];
}

+ (BOOL) completeActivityTraceWithExitTimestampMillis:(double)exitTimestampMilliseconds
{
    return [self completeActivityTraceWithExitTimestampMillis:exitTimestampMilliseconds
                                                endedByTimer:NO];
}

+ (BOOL) completeActivityTraceWithExitTimestampMillis:(double)exitTimestampMilliseconds
                                         endedByTimer:(BOOL)endedByTimer
{
    return [self completeActivityTraceForInteractionId:[self currentInteractionId]
                              exitTimestampMillis:exitTimestampMilliseconds
                                     endedByTimer:endedByTimer];
}

+ (BOOL) completeActivityTraceForInteractionId:(NSString*)interactionId
{
    return [self completeActivityTraceForInteractionId:interactionId
                              exitTimestampMillis:NRMAMillisecondTimestamp()
                                     endedByTimer:NO];
}

/// Completes every live interaction. For the points where the app is going away — background and
/// shutdown — which want everything flushed rather than only whichever interaction the calling thread
/// happens to resolve to.
+ (BOOL) completeAllActivityTraces
{
    BOOL completedAny = NO;
    // Snapshot the ids first: completing one mutates the registry, so iterating it live would
    // enumerate a collection being modified.
    for (NSString* interactionId in [self activeInteractionIds]) {
        completedAny |= [self completeActivityTraceForInteractionId:interactionId];
    }
    return completedAny;
}

+ (BOOL) completeActivityTraceForInteractionId:(NSString*)interactionId
                           exitTimestampMillis:(double)exitTimestampMilliseconds
                                  endedByTimer:(BOOL)endedByTimer
{
    @synchronized(kNRMAStartAndEndTracingLock) {

        // If Agent is shutdown we shouldn't record traces.
        if([NewRelicAgentInternal sharedInstance].isShutdown) {
            return NO;
        }

        if(![NRMATraceController isTracingActiveForInteractionId:interactionId]) {
            NRLOG_AGENT_VERBOSE(@"completeTrace called while no trace was running.");
            return NO;
        }
#ifndef  DISABLE_NRMA_EXCEPTION_WRAPPER
        @try {
#endif
            NRMATraceMachine* traceMach = [self traceMachineForInteractionId:interactionId];

            [traceMach invalidateTimers]; //invalidate any timers that might be running.

            NRMAActivityTrace *activityTrace = traceMach.activityTrace;
            // NRLOG_AGENT_VERBOSE(@"\"%@\" Activity Completed.", activityTrace.name);


            [traceMach.tracePool removeMeasurementConsumer:activityTrace.rootTrace];

            // The root trace always ends at the real wall-clock exit: it describes the UI_Thread
            // span, and its exclusive-time arithmetic needs the true boundary. Set before completing
            // so the trace is fully formed by the time it is queued for harvest below.
            activityTrace.rootTrace.exitTimestamp = exitTimestampMilliseconds;

            // The interaction's own end time is what becomes interactionDuration. On a timer-driven
            // completion that is the last instrumented boundary (quiescence); on an explicit stop or
            // supersession by the next screen it is the real timestamp. Previously this was always
            // lastUpdated, which is why calling stopCurrentInteraction: after 30 seconds still
            // reported a sub-second interaction.
            if (endedByTimer) {
                [activityTrace complete];
            } else {
                [activityTrace completeWithEndTimestampMillis:exitTimestampMilliseconds];
            }

            activityTrace.totalNetworkTimeMillis += activityTrace.rootTrace.networkTimeMillis;

            NSNumber* totalTimeSeconds = [NSNumber numberWithDouble:[activityTrace durationInSeconds]];

            [NRCustomMetrics addMetric:[NSString stringWithFormat:@"Mobile/Activity/Name/%@", activityTrace.name]
                                 value:totalTimeSeconds]; //needs to be in seconds
            [NRCustomMetrics addMetric:[NSString stringWithFormat:@"Mobile/Activity/Background/Name/%@", activityTrace.name]
                                 value:totalTimeSeconds]; //needs to be in seconds

            [NRMALastActivityTraceController storeLastActivityStampWithName:activityTrace.name
                                                             startTimestamp:[NSNumber numberWithDouble:activityTrace.startTime]
                                                                   duration:[NSNumber numberWithDouble:(activityTrace.endTime - activityTrace.startTime)]];
            [NRMATaskQueue queue:activityTrace];

            [[NewRelicAgentInternal sharedInstance].analyticsController  addInteractionEvent:activityTrace.name
                                      interactionDuration:activityTrace.endTime - activityTrace.startTime
                                               attributes:[self correlationAttributesForActivityTrace:activityTrace]];

#ifndef  DISABLE_NR_EXCEPTION_WRAPPER
        } @catch (NSException* exception) {
            [NRMAExceptionHandler logException:exception class:NSStringFromClass([self class]) selector:NSStringFromSelector(_cmd)];
        }
#endif
        // Outside the @try so it runs even if emitting the event threw: this interaction is over and
        // no later MobileView event may carry its id.
        //
        // Cleared only if this interaction is the one currently published. With concurrent
        // interactions an unconditional clear would wipe a sibling's identity off every MobileView
        // event emitted after this one happened to finish first.
        [self clearPublishedInteractionIdIfCurrent:interactionId];
        [[self class] cleanupInteractionId:interactionId];
    }

    return YES;
}

+ (BOOL) newTraceSetup:(NRMATrace*)newTrace
           parentTrace:(NRMATrace*)parentTrace
{
    if (newTrace == nil || parentTrace == nil) {
        NRLOG_AGENT_VERBOSE(@"<Activity : \"%@\"> : newTraceSetup called with a nil parent or child trace: p=%@, c=%@",
                      [NRMATraceController getCurrentActivityName],parentTrace, newTrace);
        return NO;
    }

    /* this code is invoked from enterMethod*
     
     rules:
        newTrace is executing on the current thread
        parentTrace may be the deepest open trace segment on the current thread or a trace from another thread
     
        assumptions if parentTrace is on the same thread:
            threadLocalTrace frame object is parentTrace
            threadLocalStack is allocated and lastObject is parentTrace
            newTrace should be pushed onto stack and set as active frame
        assumptions if parentTrace is not on the same thread:
            threadLocalStack is empty or nil
            threadLocalTrace frame is nil
            threadLocalStack should be allocated and contain [parentTrace, newTrace]
            newTrace should be set as active frame

        at the end of this method, newTrace should be on the stack and set as the current trace for the thread.

     */

    /*  it's important to set the entry timestamp of newTrace before we push
     *  push it onto the thread local store. because veriftying 
     *  the trace requires the entryTimestamp being set. */
    newTrace.entryTimestamp = NRMAMillisecondTimestamp();
    
    [NRMAThreadLocalStore pushChild:newTrace forParent:parentTrace];
    
    return YES;
}


+ (BOOL) enterMethod:(NRMATrace*)parentTrace
                name:(NSString*)newTraceName
{
    if ([NewRelicAgentInternal sharedInstance].isShutdown) {
        return NO;
    }
    // Serialize against the trace lifecycle (see completeTrace:). Without this lock a stale
    // method-entry on one thread can keep mutating an activity trace that completeActivityTrace
    // has already queued for harvest and torn down, corrupting the heap. isTracingActive is
    // re-checked inside the lock to close the time-of-check/time-of-use window.
    @synchronized(kNRMAStartAndEndTracingLock) {
        // Scoped to the parent's interaction, not "is anything running": a segment whose own
        // interaction has completed must be refused even while a sibling interaction is still live.
        if (![NRMATraceController isTracingActiveForSegmentParent:parentTrace]) {
            return NO;
        }
        NRMATrace* childTrace = [NRMATraceController registerNewTrace:newTraceName withParent:parentTrace];
        if (!childTrace) {
            return NO;
        }
        childTrace.entryTimestamp = NRMAMillisecondTimestamp();

        return [NRMATraceController newTraceSetup:childTrace
                                 parentTrace:parentTrace];
    }
}

+ (NRMATrace*) enterMethod:(SEL)selector
           fromObjectNamed:(NSString*)objName
               parentTrace:(NRMATrace*)parentTrace
             traceCategory:(enum NRTraceType)category
{
    return [[self class] enterMethod:selector
                     fromObjectNamed:objName
                         parentTrace:parentTrace
                       traceCategory:category
                           withTimer:nil];
}


+ (NRMATrace*) enterMethod:(SEL)selector
           fromObjectNamed:(NSString*)objName
               parentTrace:(NRMATrace*)parentTrace
             traceCategory:(enum NRTraceType)category
                 withTimer:(NRTimer *)timer
{
    if ([NewRelicAgentInternal sharedInstance].isShutdown) {
        return nil;
    }

    // Serialize against the trace lifecycle (see completeTrace:). Re-check isTracingActive
    // inside the lock so a concurrent completeActivityTrace/cleanup can't leave us mutating
    // a torn-down, already-harvested activity trace (heap corruption).
    @synchronized(kNRMAStartAndEndTracingLock) {

    // Scoped to the parent's interaction — see +enterMethod:name:.
    if (![NRMATraceController isTracingActiveForSegmentParent:parentTrace]) {
        return nil;
    }

    NRMATrace* childTrace = [NRMATraceController registerNewTrace:[NSString stringWithFormat:@"%@#%@",objName,NSStringFromSelector(selector)]
                                                withParent:parentTrace];
    if (!childTrace) {
        return nil;
    }
    childTrace.category = category;
    childTrace.classLabel = objName;
    childTrace.methodLabel = NSStringFromSelector(selector);

    if (timer) {

        objc_setAssociatedObject(timer, (__bridge const void *)(kNRTraceAssociatedKey), childTrace, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }

#ifndef  DISABLE_NRMA_EXCEPTION_WRAPPER
    @try {
#endif

        [NRMATraceController newTraceSetup:childTrace parentTrace:parentTrace];

        if (timer) {
            childTrace.entryTimestamp = timer.startTimeInMillis;
        }

#ifndef  DISABLE_NRMA_EXCEPTION_WRAPPER
    } @catch (NSException* exception) {
        [NRMAExceptionHandler logException:exception
                                   class:NSStringFromClass([self class])
                                selector:NSStringFromSelector(_cmd)];
        if (timer) {

            objc_setAssociatedObject(timer, (__bridge const void *)(kNRTraceAssociatedKey), nil, OBJC_ASSOCIATION_ASSIGN);
        }
        [NRMATraceController cleanup];

        return nil;
    }
#endif

    return childTrace;
    } // @synchronized(kNRMAStartAndEndTracingLock)
}

+ (void) recordCompletedSegmentWithObjectNamed:(NSString*)objectName
                                   methodNamed:(NSString*)methodName
                          entryTimestampMillis:(double)entryTimestampMillis
                           exitTimestampMillis:(double)exitTimestampMillis
                                 traceCategory:(enum NRTraceType)category
{
    if ([NewRelicAgentInternal sharedInstance].isShutdown) {
        return;
    }
    if (![NRMAFlags shouldEnableInteractionTracing]) {
        return;
    }
    if (!objectName.length || !methodName.length) {
        return;
    }

    NSString* classLabel  = [NewRelicInternalUtils cleanseStringForCollector:objectName];
    NSString* methodLabel = [NewRelicInternalUtils cleanseStringForCollector:methodName];

    // The same lock the rest of the trace lifecycle takes (see completeTrace:), held across
    // register/push/complete so a concurrent teardown can't free the activity trace underneath
    // a half-recorded segment. @synchronized is recursive, so completeTrace: retaking it is fine.
    @synchronized(kNRMAStartAndEndTracingLock) {
        if (![NRMATraceController isTracingActive]) {
            return;
        }
        NRMATrace* parentTrace = [NRMATraceController currentTrace];
        if (parentTrace == nil) {
            return;
        }

        // Registered with no parent, and marked ignoreNode, so the segment never joins the trace
        // tree: its span was measured after the fact and overlaps the instrumented methods it
        // covers, so as a child of the frame it is recorded from it would subtract its whole
        // duration from that frame's exclusive time and start before its parent began. The row the
        // caller wants comes from the metric completeTrace: emits, not from a place in the tree.
        //
        // registerNewTrace: still adds the node to the activity trace's missing-children set, so
        // from here on every path has to reach completeTrace: — otherwise the interaction is left
        // waiting on a child that never finishes.
        NRMATrace* segment = [NRMATraceController registerNewTrace:[NSString stringWithFormat:@"%@#%@", classLabel, methodLabel]
                                                       withParent:nil];
        if (segment == nil) {
            return;
        }
        segment.ignoreNode  = YES;
        segment.category    = category;
        segment.classLabel  = classLabel;
        segment.methodLabel = methodLabel;

        // Pushing stamps entry with *now*, which the caller's timestamp then replaces — the same
        // order enterMethod:...withTimer: uses, because the push validates a set entryTimestamp.
        [NRMATraceController newTraceSetup:segment parentTrace:parentTrace];
        segment.entryTimestamp = entryTimestampMillis;

        // Pops the segment straight back off, restoring parentTrace as the thread's current trace.
        [NRMATraceController completeTrace:segment withExitTimestampMillis:@(exitTimestampMillis)];
    }
}

+ (NRMATrace*) registerNewTrace:(NSString *)name
                   withParent:(NRMATrace*) parentTrace
{
    // Follow the parent's machine when there is one. Resolving through the thread's ambient
    // interaction instead would register the child on a different interaction than its parent whenever
    // a segment is entered under a parent belonging to another interaction, which splits one logical
    // tree across two activity traces.
    NRMATraceMachine* localTraceMachine = parentTrace.traceMachine ?: [self traceMachine];
    @synchronized(localTraceMachine) {
        if (localTraceMachine == nil) {

            NRLOG_AGENT_VERBOSE(@"tried to register a new trace but tracing is inactive");
            return nil;
        }
        
        NRMATrace* childTrace = [[NRMATrace alloc] initWithName:name
                                               traceMachine:localTraceMachine];
        
        if( localTraceMachine.activityTrace.nodes >= NRMA_MAX_NODE_LIMIT){
            NRLOG_AGENT_VERBOSE(@"<Activity: \"%@\"> : NR_MAX_NODE_LIMIT(%d) reached dropping node",[NRMATraceController getCurrentActivityName],NRMA_MAX_NODE_LIMIT);
            childTrace.ignoreNode = YES;
#ifndef  DISABLE_NRMA_EXCEPTION_WRAPPER
            @try {
#endif
                [NRMAMeasurements recordAndScopeMetricNamed:kNRSupportabilityPrefix@"/InteractionTraceNodeLimited"
                                                    value:@1];
#ifndef  DISABLE_NRMA_EXCEPTION_WRAPPER
            } @catch (NSException* exception) {
                [NRMAExceptionHandler logException:exception
                                           class:NSStringFromClass([self class])
                                        selector:NSStringFromSelector(_cmd)];
            }
#endif
        }
        
        [localTraceMachine.activityTrace addTrace:childTrace];
        
        [parentTrace addChild:childTrace];
        return childTrace;
    }
}

+ (void) exitMethod
{
    [self exitMethodWithTimestampMillis:NRMAMillisecondTimestamp()];
}
+ (void) exitCustomMethodWithTimer:(NRTimer*)timer
{
    [self exitMethodWithTimestampMillis:timer.endTimeMillis];
}

+ (void)exitMethodWithTimestampMillis:(double)exitTimestampMilliseconds
{
    [NRMATraceController completeTrace:[[self class] threadLocalTrace]
          withExitTimestampMillis:[NSNumber numberWithDouble:exitTimestampMilliseconds]];
}

/// Pops a known segment rather than "whatever is on top of this thread's ambient stack".
///
/// +exitMethod has to guess, and with concurrent interactions the ambient stack may belong to a
/// sibling — so a caller holding the trace it entered (the method profiler does) must say which one
/// it means, or the wrong segment gets popped and the right one is left as a permanent missing child.
+ (void) exitMethodForTrace:(NRMATrace*)trace
{
    [NRMATraceController completeTrace:trace
              withExitTimestampMillis:[NSNumber numberWithDouble:NRMAMillisecondTimestamp()]];
}

+ (void) completeTrace:(NRMATrace*)trace withExitTimestampMillis:(NSNumber*)exitTimestampMilliseconds
{
    if (trace == nil) {
        return;
    }

    // Serialize trace completion against the trace lifecycle (startTracing*/completeActivityTrace*/
    // cleanup), which mutate and tear down the trace machine under this same lock. Without it,
    // completion (invoked by the method profiler on an arbitrary thread) races a concurrent
    // teardown, dereferencing freed trace state and corrupting the heap (SIGTRAP in libsystem_malloc).
    // The validity check below MUST run inside the lock to close the time-of-check/time-of-use window.
    @synchronized(kNRMAStartAndEndTracingLock) {

    // Derived from the trace itself rather than from the thread's ambient interaction. A segment
    // always completes against the machine that created it — with concurrent interactions the ambient
    // one may well be a sibling, and the old identity check (localTraceMachine != trace.traceMachine)
    // would then reject a perfectly valid completion and leave the segment on the stack forever.
    NRMATraceMachine *localTraceMachine = trace.traceMachine;

    if (localTraceMachine == nil || ![NRMATraceController isTracingActiveForInteractionId:trace.interactionId]) {
        return;
    }

    NRMATrace* parentTrace = nil;
    BOOL recordTraceData = [NRMAThreadLocalStore popCurrentTraceIfEqualTo:trace
                                                        returningParent:&parentTrace];

    if (! recordTraceData) {
        return;
    }

    trace.exitTimestamp = [exitTimestampMilliseconds doubleValue]; //set end timestamp for trace

    NSTimeInterval totalTimeSeconds = [trace durationInSeconds]; //calculate total time in seconds
    [trace calculateExclusiveTime]; //calculate exclusive time

    NSString* metricName = [trace metricName]; // fetch metric name for trace
    [localTraceMachine.activityTrace recordVitalsThrottled]; // record vitals

    NSString* scope = @"";
#ifndef  DISABLE_NRMA_EXCEPTION_WRAPPER
    @try {
#endif
        if (totalTimeSeconds == 0) {
            totalTimeSeconds=1;
        }
        if (trace.threadInfo.identity == localTraceMachine.activityTrace.rootTrace.threadInfo.identity) {
            //if the trace is on the main thread we want a main metric
            scope = [NRMAMeasurements recordAndScopeMetricNamed:metricName value:[NSNumber numberWithDouble:totalTimeSeconds]];
        } else {
            //if the trace is on a background thread we want to make a background metric.
            scope = [NRMAMeasurements recordBackgroundScopedMetricNamed:metricName
                                                                value:[NSNumber numberWithDouble:totalTimeSeconds]];
        }
#ifndef  DISABLE_NRMA_EXCEPTION_WRAPPER
    } @catch (NSException* exception) {
        //failed to record proper metrics
        //don't add this trace to info
        [NRMAExceptionHandler logException:exception
                                   class:NSStringFromClass([self class])
                                selector:NSStringFromSelector(_cmd)];

    }
#endif
    //record exclusive time!

    BOOL recordSummaryTimes = YES;
#ifndef  DISABLE_NRMA_EXCEPTION_WRAPPER
    @try {
#endif
        [NRMATaskQueue queue:[[NRMAMetric alloc] initWithName:[NSString stringWithFormat:@"%@/ExclusiveTime", metricName]
                                   value:[NSNumber numberWithDouble:trace.exclusiveTimeMillis / 1000] //convert to seconds from milliseconds
                               scope:scope
                         produceUnscoped:YES
                         additionalValue:nil]];
#ifndef  DISABLE_NRMA_EXCEPTION_WRAPPER
    } @catch (NSException* exception) {
        recordSummaryTimes = NO;
        [NRMAExceptionHandler logException:exception
                                   class:NSStringFromClass([self class])
                                selector:NSStringFromSelector(_cmd)];
    }
#endif

    [NRMATaskQueue queue:trace];
    //accumulate a totalExclusiveTime to compare to total time
    //and avoid empty traces

    BOOL loggedExclusiveTime = NO;
    if (recordSummaryTimes) { // we don't want to record exclusive time if we fail to create a metric for it, right?
        loggedExclusiveTime = YES;
        localTraceMachine.activityTrace.totalExclusiveTimeMillis += trace.exclusiveTimeMillis;
    }

    localTraceMachine.activityTrace.totalNetworkTimeMillis += trace.networkTimeMillis;

    @synchronized(localTraceMachine.activityTrace.missingChildren){
        //now that this trace is complete it is no longer a missing child
        [localTraceMachine.activityTrace.missingChildren removeObject:trace];
        localTraceMachine.activityTrace.lastUpdated = NRMAMillisecondTimestamp();
    }
    } // @synchronized(kNRMAStartAndEndTracingLock)
}



+ (NRMATrace*) getCurrentTrace
{
    return [self getCurrentTraceForInteractionId:[self currentInteractionId]];
}

+ (NRMATrace*) getCurrentTraceForInteractionId:(NSString*)interactionId
{
    // The open frame on this thread for that interaction, or — when this thread has never entered a
    // segment of it — the interaction's root. This fallback is what lets work on a thread the
    // interaction has not touched still attach to it.
    NRMATrace *theTrace = [NRMAThreadLocalStore threadLocalTraceForInteractionId:interactionId];

    if (theTrace) {
        return theTrace;
    } else {
        return [self traceMachineForInteractionId:interactionId].activityTrace.rootTrace;
    }
}

+ (NRMATrace*) currentTrace
{
    return [self currentTraceForInteractionId:[self currentInteractionId]];
}

+ (NRMATrace*) currentTraceForInteractionId:(NSString*)interactionId
{
    if (![NRMATraceController isTracingActiveForInteractionId:interactionId]) {
        return nil;
    }
    return [NRMATraceController getCurrentTraceForInteractionId:interactionId];
}

+ (NRMATrace*) threadLocalTrace
{
    return [NRMAThreadLocalStore threadLocalTrace];
}

+ (NSString*) currentScope
{
    return [NRMATraceController getCurrentTrace].name;
}
+ (BOOL) isTracingActive
{
    // "Is any interaction running", which is what every existing caller means by it. Callers that
    // need to know about one specific interaction use +isTracingActiveForInteractionId:.
    return [self activeInteractionCount] > 0;
}

+ (BOOL) isTracingActiveForInteractionId:(NSString*)interactionId
{
    return [self traceMachineForInteractionId:interactionId] != nil;
}

/// Whether the interaction a prospective segment would belong to is still running.
///
/// A parent carries its interaction id, so it answers the question exactly. Only when the parent has
/// no id — a trace built before its interaction existed — does this fall back to "is anything
/// running", which is the pre-registry behaviour.
+ (BOOL) isTracingActiveForSegmentParent:(NRMATrace*)parentTrace
{
    NSString* interactionId = parentTrace.interactionId;
    if (interactionId.length == 0) {
        return [self isTracingActive];
    }
    return [self isTracingActiveForInteractionId:interactionId];
}

// Forwarders. The trace-collection gate lives in NRMAHarvestController, which owns the harvest
// buffer and the at_capture configuration it compares against; these duplicated the logic and had no
// callers. Kept as thin forwarders rather than deleted outright because the declaration is in the
// header and may be linked against out of tree.
+ (BOOL) shouldCollectTraces
{
    return [NRMAHarvestController shouldCollectTraces];
}

+ (BOOL) shouldNotCollectTraces
{
    return [NRMAHarvestController shouldNotCollectTraces];
}

@end
