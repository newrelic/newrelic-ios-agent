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

static NRMATraceMachine* __traceMachine;


NSString * const kNRMAStartAndEndTracingLock = @"startTracingLock";

@interface NRMATraceController()



+ (void) exitMethodWithTimestampMillis:(double)exitTimestampMilliseconds;
+ (void) completeTrace:(NRMATrace*)trace withExitTimestampMillis:(NSNumber*)exitTimestampMilliseconds;
+ (BOOL) completeActivityTraceWithExitTimestampMillis:(double)exitTimestampMilliseconds;
+ (BOOL) completeActivityTraceWithExitTimestampMillis:(double)exitTimestampMilliseconds
                                         endedByTimer:(BOOL)endedByTimer;

@end

@implementation NRMATraceController


static const NSString* __newRelicTraceMachAsyncLock = @"lock";
+ (NRMATraceMachine*)traceMachine
{
    @synchronized(__newRelicTraceMachAsyncLock) {
        return __traceMachine;
    }
}

+ (void) setTraceMachine:(NRMATraceMachine*)traceMachine
{
    @synchronized(__newRelicTraceMachAsyncLock) {
        __traceMachine = traceMachine;
    }
}


+ (void) cleanup
{
    NRMATraceMachine* localTraceMachine = [self traceMachine];
    [localTraceMachine.tracePool shutdown];
    [NRMATraceController clearMeasurementTransmitters];
    [self setTraceMachine:nil];
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
    NSMutableArray* measurementTransmitters = [self traceMachine].measurementTransmitters;
    @synchronized(measurementTransmitters) {
        for (NRMAMeasurementTransmitter* transmitter in measurementTransmitters) {
            [NRMAMeasurements removeMeasurementConsumer:transmitter];
        }
    }
}



+ (void) startTracingWithName:(NSString *)name interactionObject:(id __unsafe_unretained)obj
{
    @synchronized(kNRMAStartAndEndTracingLock) {
        // If Agent is shutdown we shouldn't record traces.
        if([NewRelicAgentInternal sharedInstance].isShutdown) {
            return;
        }

        NRLOG_AGENT_VERBOSE(@"\"%@\" Activity started", name);
        [NRMATraceController startTracing:NO];
        [[[NewRelicAgentInternal sharedInstance] analyticsController] setLastInteraction:name];
        NRMATraceMachine* traceMach = [self traceMachine];
        traceMach.activityTrace.name = name;
        traceMach.activityTrace.initiatingObjectIdentifier = [NSString stringWithFormat:@"%p",obj];
        // Re-publish now that the real name is known; startTracingWithRootTrace: only had the
        // placeholder root-trace name to work with.
        [self publishRunningInteractionId:traceMach.activityTrace.interactionId name:name];
        [NRMAInteractionHistoryObjCInterface insertInteraction:name startTime:(long long)(traceMach.activityTrace.startTime)];
    }
}

+ (BOOL) isInteractionObject:(id __unsafe_unretained)obj
{
    NRMATraceMachine* traceMach = [self traceMachine];
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
        
        [NRMATraceController startTracingWithRootTrace:rootTrace];
        
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
    @synchronized(kNRMAStartAndEndTracingLock) {

        // If Agent is shutdown we shouldn't record traces.
        if([NewRelicAgentInternal sharedInstance].isShutdown) {
            return;
        }

        if ([NRMATraceController isTracingActive]) {
            [NRMATraceController completeActivityTrace];
        }

        [NRMATraceController cleanup];
        
        NSString* activityName = rootTrace.name;
        rootTrace.name = @"UI_Thread";

        NRMATraceMachine* traceMach = [[NRMATraceMachine alloc] initWithRootTrace:rootTrace];

        traceMach.activityTrace.name = activityName;
        // Single choke point for activity-trace creation, so every interaction gets an id here.
        // The name is still the placeholder at this point; startTracingWithName: re-publishes it.
        traceMach.activityTrace.interactionId = [[NSUUID UUID] UUIDString];
        [self publishRunningInteractionId:traceMach.activityTrace.interactionId name:nil];

        rootTrace.traceMachine = traceMach;
        [NRMAThreadLocalStore setThreadRootTrace:rootTrace];
        [traceMach.tracePool addMeasurementConsumer:rootTrace];

        [self setTraceMachine:traceMach];
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

+ (BOOL) completeActivityTraceWithExitTimestampMillis:(double)exitTimestampMilliseconds
{
    return [self completeActivityTraceWithExitTimestampMillis:exitTimestampMilliseconds
                                                endedByTimer:NO];
}

+ (BOOL) completeActivityTraceWithExitTimestampMillis:(double)exitTimestampMilliseconds
                                         endedByTimer:(BOOL)endedByTimer
{
    @synchronized(kNRMAStartAndEndTracingLock) {

        // If Agent is shutdown we shouldn't record traces.
        if([NewRelicAgentInternal sharedInstance].isShutdown) {
            return NO;
        }

        if(![NRMATraceController isTracingActive]) {
            NRLOG_AGENT_VERBOSE(@"completeTrace called while no trace was running.");
            return NO;
        }
#ifndef  DISABLE_NRMA_EXCEPTION_WRAPPER
        @try {
#endif  
            NRMATraceMachine* traceMach = [self traceMachine];

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
        [self publishRunningInteractionId:nil name:nil];
        [[self class] cleanup];
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
        if (![NRMATraceController isTracingActive]) {
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

    if (![NRMATraceController isTracingActive]) {
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
    NRMATraceMachine* localTraceMachine = [self traceMachine];
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

    NRMATraceMachine *localTraceMachine = [self traceMachine];

    if (localTraceMachine == nil || ![NRMATraceController isTracingActive] || localTraceMachine != trace.traceMachine) {
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
    NRMATrace *theTrace = [NRMAThreadLocalStore threadLocalTrace];

    if (theTrace) {
        return theTrace;
    } else {
        return [self traceMachine].activityTrace.rootTrace;
    }
}

+ (NRMATrace*) currentTrace
{
    if (![NRMATraceController isTracingActive]) {
        return nil;
    }
    return [NRMATraceController getCurrentTrace];
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
    return [self traceMachine] != nil;
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
