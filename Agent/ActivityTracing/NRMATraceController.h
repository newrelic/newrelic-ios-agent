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

+ (void) exitMethod;

+ (NRMATrace*) currentTrace;

+ (NSString*) currentScope;

+ (BOOL) isTracingActive;

+ (BOOL) shouldCollectTraces;

+ (void) cleanup; 

@end
