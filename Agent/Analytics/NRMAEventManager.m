//
//  NRMAEventManager.m
//  Agent
//
//  Created by Steve Malsam on 6/7/23.
//  Copyright © 2023 New Relic. All rights reserved.
//

#import "NRMAEventManager.h"

#import "NRLogger.h"
#import "NRMAJSON.h"
#import "NRMARequestEvent.h"
#import "NRMANetworkErrorEvent.h"

static const NSUInteger kDefaultBufferSize = 1000;
static const NSUInteger kDefaultBufferTimeSeconds = 600; // 10 Minutes
static const NSUInteger kMinBufferTimeSeconds = 60; // 60 seconds

@implementation NRMAEventManager {
    NSMutableArray<NRMAAnalyticEventProtocol> *events;
    
    NSUInteger maxBufferSize;
    NSUInteger maxBufferTimeSeconds;
    
    NSUInteger totalAttemptedInserts;
    NSTimeInterval oldestEventTimestamp;
}

- (nonnull instancetype)init {
    self = [super init];
    if (self) {
        events = [[NSMutableArray<NRMAAnalyticEventProtocol> alloc] init];
        maxBufferSize = kDefaultBufferSize;
        maxBufferTimeSeconds = kDefaultBufferTimeSeconds;
        totalAttemptedInserts = 0;
        oldestEventTimestamp = 0;
    }
    return self;
}

- (void)setMaxEventBufferSize:(NSUInteger)size {
    maxBufferSize = size;
}

- (void)setMaxEventBufferTimeInSeconds:(NSUInteger)seconds {
    if(seconds < kMinBufferTimeSeconds) {
        NRLOG_ERROR(@"Buffer Time cannot be less than %lu Seconds", (unsigned long)kMinBufferTimeSeconds);
        maxBufferTimeSeconds = kMinBufferTimeSeconds;
    } else if (seconds > kDefaultBufferTimeSeconds){
        NRLOG_WARNING(@"Buffer Time should not be longer than %lu seconds", (unsigned long)kDefaultBufferTimeSeconds);
        maxBufferTimeSeconds = kDefaultBufferTimeSeconds;
    }
    
    maxBufferTimeSeconds = seconds;
}

- (BOOL)didReachMaxQueueTime:(NSTimeInterval)currentTimeMilliseconds {
    if(oldestEventTimestamp == 0) {
        return false;
    }
    
    NSTimeInterval oldestEventAge = currentTimeMilliseconds - oldestEventTimestamp;
    return (oldestEventAge / 1000) >= maxBufferTimeSeconds;
}

- (NSUInteger)getEvictionIndex {
    if(totalAttemptedInserts > 0) {
        return arc4random() % totalAttemptedInserts;
    } else {
        return 0;
    }
}

- (BOOL)addEvent:(id<NRMAAnalyticEventProtocol>)event {
    @synchronized (events) {
        // The event fits within the buffer
        if (events.count < maxBufferSize) {
            [events addObject:event];
            if(events.count == 1) {
                oldestEventTimestamp = event.timestamp;
            }
        } else {
            // we need to throw away an event. We try to balance
            // between evicting newer events and older events.
            NSUInteger evictionIndex = [self getEvictionIndex];
            if (evictionIndex < events.count) {
                [events removeObjectAtIndex:evictionIndex];
                [events addObject:event];
            }
        }
    }
    totalAttemptedInserts++;
    return YES;
}

- (void)empty {
    @synchronized (events) {
        [events removeAllObjects];
        oldestEventTimestamp = 0;
        totalAttemptedInserts = 0;
    }
}

- (nullable NSString *)getEventJSONStringWithError:(NSError *__autoreleasing *)error clearEvents:(BOOL)clearEvents {
    NSString *eventJsonString = nil;
    @synchronized (events) {
        @try {
            NSMutableArray *jsonEvents = [[NSMutableArray alloc] init];
            for(id<NRMAAnalyticEventProtocol> event in events) {
                [jsonEvents addObject:[event JSONObject]];
            }
            
            NSData *eventJsonData = [NRMAJSON dataWithJSONObject:jsonEvents
                                                         options:0
                                                           error:&error];
            eventJsonString = [[NSString alloc] initWithData:eventJsonData
                                                    encoding:NSUTF8StringEncoding];
        } @catch (NSException *e) {
            NRLOG_ERROR(@"FAILED TO CREATE EVENT JSON: %@", e.reason);
        }
    }
    if (clearEvents){
        [self empty];
    }
    return eventJsonString;
}

@end
