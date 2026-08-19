//
//  NRTraceMachine.h
//  NewRelicAgent
//
//  Created by Bryce Buchanan on 9/9/13.
//  Copyright © 2023 New Relic. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "NRTimer.h"
#import "NRConstants.h"

@class NRMAActivityTrace;
@class NRMATrace;
@class NRTraceMachineInterface;


//used to synchronized start and end traces. 
extern NSString* const kNRMAStartAndEndTracingLock;
extern NSString* const kNRMACustomInteractionIdentifier;

@interface NRMATraceController : NSObject


+ (NSTimeInterval) healthyTraceTimeout;
+ (NSTimeInterval) unhealthyTraceTimeout;

/// Seconds an interaction may go with no instrumented method entry/exit before the trace machine
/// completes it. Raise it to let interactions span a screen's dwell time; lower it (0.5 restores the
/// historical value) to make an interaction describe only the screen-load burst.
///
/// Applies to the next interaction to start — an in-flight interaction keeps the timeout it captured
/// at creation (see -[NRMATraceMachine initWithRootTrace:]). Non-positive values are ignored.
+ (void) setHealthyTraceTimeout:(NSTimeInterval)healthyTraceTimeout;

/// Hard ceiling, in seconds, on an interaction's lifetime. Backstop for an interaction that is never
/// explicitly stopped. Same next-interaction-only semantics as +setHealthyTraceTimeout:.
+ (void) setUnhealthyTraceTimeout:(NSTimeInterval)unhealthyTraceTimeout;


+ (void) exitCustomMethodWithTimer:(NRTimer*)timer;

+ (NSString*) getCurrentActivityName;

+ (void) startTracingWithRootTrace:(NRMATrace*)rootTrace;

+ (NRMATrace*) startTracing:(BOOL)persistentTrace;

+ (NRMATrace*) registerNewTrace:(NSString *)name
                   withParent:(NRMATrace*) parentTrace;

+ (BOOL) isInteractionObject:(id __unsafe_unretained)obj;

+ (void) startTracingWithName:(NSString *)name interactionObject:(id __unsafe_unretained)obj;

+ (BOOL) completeActivityTrace;

/// Completes the running interaction as a *quiescence* event: its end time is its last instrumented
/// method boundary rather than now, so the timeout that triggered completion is not counted in the
/// reported duration. For the trace machine's healthy/unhealthy timers only — every other caller
/// wants +completeActivityTrace.
+ (BOOL) completeActivityTraceOnTimeout;

+ (NRMATrace*) enterMethod:(SEL)selector
           fromObjectNamed:(NSString*)objName
               parentTrace:(NRMATrace*)parentTrace
             traceCategory:(enum NRTraceType)category;

+ (NRMATrace*) enterMethod:(SEL)selector
           fromObjectNamed:(NSString*)objName
               parentTrace:(NRMATrace*)parentTrace
             traceCategory:(enum NRTraceType)category
                 withTimer:(NRTimer *)timer;

+ (BOOL) enterMethod:(NRMATrace*)parentTrace
                name:(NSString*)newTraceName;

/// Records an already-finished segment on the interaction covering this thread, using timestamps
/// the caller captured earlier. For work whose boundaries are only known after the fact — a view's
/// load span, which straddles two runloop turns and so cannot hold the thread's trace stack open
/// between them the way an instrumented method does.
///
/// A no-op when no interaction is running: a segment describes work *inside* an interaction and
/// must never start one of its own.
///
/// The segment emits its metrics but is deliberately kept out of the harvested trace tree: its span
/// overlaps the instrumented methods it covers, so a node would subtract its whole duration from
/// the exclusive time of the frame it was recorded from.
///
/// `objectName` and `methodName` become the segment's `Method/<objectName>/<methodName>` metric,
/// which is the row the interaction's breakdown shows. Both are cleansed for the collector, so
/// host-app text is safe to pass. Strings rather than a SEL deliberately: a selector built from a
/// dynamic view name would be interned in the runtime's selector table for the life of the process.
+ (void) recordCompletedSegmentWithObjectNamed:(NSString*)objectName
                                   methodNamed:(NSString*)methodName
                          entryTimestampMillis:(double)entryTimestampMillis
                           exitTimestampMillis:(double)exitTimestampMillis
                                 traceCategory:(enum NRTraceType)category;

+ (void) exitMethod;

+ (NRMATrace*) currentTrace;

+ (NSString*) currentScope;

+ (BOOL) isTracingActive;

+ (BOOL) shouldCollectTraces;

+ (void) cleanup; 

@end
