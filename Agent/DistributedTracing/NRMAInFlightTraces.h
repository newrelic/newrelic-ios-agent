//
//  NRMAInFlightTraces.h
//  Agent
//
//  Copyright © 2026 New Relic. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

// The distributed traces of the instrumented requests currently in flight, so a log record written
// while one is in flight can carry its trace.id and span.id. The iOS counterpart of the Android
// agent's TraceListener (onTraceCreated / onSpanCreated) hook.
//
// A trace is keyed by the payload object the agent attaches to the request, and held weakly: a
// request that never reports back (never resumed, or dropped before completion) leaves the set
// when its payload is released, instead of tagging every later log record.
@interface NRMAInFlightTraces : NSObject

+ (void) traceStarted:(id)payload
              traceId:(NSString*)traceId
               spanId:(NSString*)spanId;

+ (void) traceFinished:(id _Nullable)payload;

// trace.id and span.id of the most recently started request still in flight; nil when none is.
// Requests can overlap and a log call has no tie to any one of them, so the newest is the best
// available guess.
+ (NSDictionary<NSString*, NSString*>* _Nullable) currentTraceAttributes;

+ (void) reset;

@end

NS_ASSUME_NONNULL_END
