//
//  NRMATrace.m
//  NewRelicAgent
//
//  Created by Bryce Buchanan on 9/9/13.
//  Copyright © 2023 New Relic. All rights reserved.
//

#import "NRMATrace.h"
#import "NRMAMeasurementEngine.h"
// NRMATrace.h only forward-declares NRMATraceMachine; the initializer below reads through
// traceMachine.activityTrace, which needs the full declaration.
#import "NRMATraceMachine.h"
#import "NRMATraceController.h"
#import "NewRelicInternalUtils.h"
#import "NRMAHTTPTransactionMeasurement.h"
#import "NewRelicAgentInternal.h"
@implementation NRMATrace
- (id) init
{
    self = [super init];
    if (self) {
        self.children = [[NSMutableSet alloc] init];
        self.scopedMeasurements = [[NSMutableArray alloc] init];
        self.threadInfo = [[NRMAThreadInfo alloc] init];
    }
    return self;
}


- (id) initWithName:(NSString *)name
       traceMachine:(NRMATraceMachine *)traceMachine
{
    self = [self init];
    if (self) {
        self.traceMachine = traceMachine;
        self.name = name;
        // Latch the owning interaction's id now, while the machine is still alive. See the property
        // comment: traceMachine is weak, so this is the only durable record of which interaction's
        // segment stack this trace was pushed onto.
        self.interactionId = traceMachine.activityTrace.interactionId;
    }
    return self;
}

- (void) addChild:(NRMATrace*)trace
{
    if (trace.ignoreNode) {
        return;
    }
    @synchronized(_children) {
        [self.children addObject:trace];
    }
}

- (void) calculateExclusiveTime
{
    double subtime = 0;
    @synchronized(_children) {
        for (NRMATrace* child in self.children.allObjects) {
            if (self.threadInfo.identity == child.threadInfo.identity) {
                subtime += child.exitTimestamp - child.entryTimestamp;
            }
        }
    }
    _exclusiveTimeMillis = (self.exitTimestamp - self.entryTimestamp) - subtime;
    if (_exclusiveTimeMillis < 0) {
        _exclusiveTimeMillis = 0;
    }
    
}

- (void) complete
{
    self.exitTimestamp = NRMAMillisecondTimestamp();
}

- (NSString*) metricName
{
    if (![self.classLabel length] && ![self.methodLabel length]) {
        return [NSString stringWithFormat:@"Method/%@", self.name];
    } else {
        return [NSString stringWithFormat:@"Method/%@/%@", self.classLabel, self.methodLabel];
    }
}

- (NSTimeInterval) durationInSeconds
{
    return (self.exitTimestamp - self.entryTimestamp) / 1000;
}


#pragma mark - Consumer Methods

- (NRMAMeasurementType) measurementType
{
    return NRMAMT_Any; //since its registered with the TracePool it'll only get trace related measurments;
}

- (void) consumeMeasurement:(NRMAMeasurement *)measurement {
    
    if ([measurement isKindOfClass:[NRMAHTTPTransactionMeasurement class]]) {
        NSDate* sessionStartDate = [[NewRelicAgentInternal sharedInstance] getAppSessionStartDate];
        if(((NRMAHTTPTransactionMeasurement*)measurement).startTime < [sessionStartDate timeIntervalSince1970]*1000) {
            NRLOG_AGENT_WARNING(@"Trace machine ignoring network transaction older than session. Session started at %@, where network transaction began %f milliseconds prior.",sessionStartDate, [sessionStartDate timeIntervalSince1970]*1000 - ((NRMAHTTPTransactionMeasurement*)measurement).startTime);
            return;
        }
        _networkTimeMillis += ((NRMAHTTPTransactionMeasurement*)measurement).totalTime;
    }
//    if (measurement.threadInfo.identity == self.threadInfo.identity) {
        @synchronized(_scopedMeasurements) {
            [self.scopedMeasurements addObject:measurement];
        }
//    }
}

- (void) consumeMeasurements:(NSDictionary *)measurements {
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wstrict-selector-match"
    if (![measurements isKindOfClass:[NSDictionary class]]) {
        return;
    }
    for (NSNumber* key in [measurements allKeys]) {
        id value = [measurements objectForKey:key];
        if (![value respondsToSelector:@selector(allObjects)]) {
            continue;
        }
        // Defense-in-depth: snapshot inside a guard so a set mutated mid-enumeration on
        // another thread is skipped rather than crashing on a freed element.
        NSArray* snapshot = nil;
        @try {
            snapshot = [value allObjects];
        } @catch (NSException* exception) {
            continue;
        }
        for (NRMAMeasurement* measurement in snapshot) {
            [self consumeMeasurement:measurement];
        }
    }
#pragma clang diagnostic pop
}

- (NSString*) description
{
    return [NSString stringWithFormat:@"<(%@:%p):\"%@\">",NSStringFromClass([self class]),self,self.name];
}
@end

