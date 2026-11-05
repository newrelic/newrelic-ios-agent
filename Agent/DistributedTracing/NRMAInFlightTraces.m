//
//  NRMAInFlightTraces.m
//  Agent
//
//  Copyright © 2026 New Relic. All rights reserved.
//

#import "NRMAInFlightTraces.h"

// Bounds the set if an app holds many traced requests it never runs to completion, e.g. tasks it
// creates and keeps without resuming. Far above the number of requests genuinely in flight at once.
#define kNRMAMaxInFlightTraces 64

static NSString* const kNRMALogAttributeTraceId = @"trace.id";
static NSString* const kNRMALogAttributeSpanId  = @"span.id";

@interface NRMAInFlightTrace : NSObject
@property (nonatomic, weak) id payload;
@property (nonatomic, copy) NSString* traceId;
@property (nonatomic, copy) NSString* spanId;
@end

@implementation NRMAInFlightTrace
@end

@implementation NRMAInFlightTraces

// Ordered oldest to newest.
static NSMutableArray<NRMAInFlightTrace*>* _traces;

+ (void) initialize {
    if (self == [NRMAInFlightTraces class]) {
        _traces = [NSMutableArray array];
    }
}

+ (void) traceStarted:(id)payload
              traceId:(NSString*)traceId
               spanId:(NSString*)spanId {
    if (payload == nil || !traceId.length || !spanId.length) {
        return;
    }

    NRMAInFlightTrace* trace = [NRMAInFlightTrace new];
    trace.payload = payload;
    trace.traceId = traceId;
    trace.spanId = spanId;

    @synchronized (self) {
        [self removeTracesForPayload:nil];
        [_traces addObject:trace];
        if (_traces.count > kNRMAMaxInFlightTraces) {
            [_traces removeObjectAtIndex:0];
        }
    }
}

+ (void) traceFinished:(id)payload {
    if (payload == nil) {
        return;
    }

    @synchronized (self) {
        [self removeTracesForPayload:payload];
    }
}

+ (NSDictionary<NSString*, NSString*>*) currentTraceAttributes {
    @synchronized (self) {
        [self removeTracesForPayload:nil];

        NRMAInFlightTrace* trace = _traces.lastObject;
        if (trace == nil) {
            return nil;
        }

        return @{kNRMALogAttributeTraceId: trace.traceId,
                 kNRMALogAttributeSpanId: trace.spanId};
    }
}

+ (void) reset {
    @synchronized (self) {
        [_traces removeAllObjects];
    }
}

// Removes the traces of `payload`, and those whose payload has been released. Passing nil removes
// only the released ones. Callers hold the lock.
+ (void) removeTracesForPayload:(id)payload {
    NSIndexSet* finished = [_traces indexesOfObjectsPassingTest:^BOOL(NRMAInFlightTrace* trace, NSUInteger idx, BOOL* stop) {
        id tracePayload = trace.payload;
        return tracePayload == nil || tracePayload == payload;
    }];
    [_traces removeObjectsAtIndexes:finished];
}

@end
