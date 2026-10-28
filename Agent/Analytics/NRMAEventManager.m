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
#import "NRMAAgentConfiguration.h"
#import "NRMASupportMetricHelper.h"
#import "NRMAFlags.h"
#import "NewRelicAgentInternal.h"
#import "NRMAExceptionMetaDataStore.h"
#import <NewRelic/NewRelic-Swift.h>

static const NSUInteger kDefaultBufferSize = 1000;
static const NSUInteger kDefaultBufferTimeSeconds = 60; // 60 seconds
static const NSUInteger kBufferTimeSecondsLeeway = 60; // 60 seconds
static const double kMillisecondsPerSecond = 1000.0; // milliseconds to seconds conversion

@implementation NRMAEventManager {
    NSMutableArray<NRMAAnalyticEventProtocol> *events;
    
    NSUInteger maxBufferSize;
    NSUInteger maxBufferTimeSeconds;
    
    NSUInteger totalAttemptedInserts;
    NSTimeInterval oldestEventTimestamp;

    NSUInteger eventsRecorded;
    NSUInteger eventsEvicted;
}

- (nonnull instancetype)init {
    self = [super init];
    if (self) {
        events = [[NSMutableArray<NRMAAnalyticEventProtocol> alloc] init];
        maxBufferSize = [NRMAAgentConfiguration getMaxEventBufferSize];
        maxBufferTimeSeconds = [NRMAAgentConfiguration getMaxEventBufferTime];
        totalAttemptedInserts = 0;
        oldestEventTimestamp = 0;
    }
    return self;
}

- (void)setMaxEventBufferSize:(NSUInteger)size {
    maxBufferSize = size;
}

- (NSUInteger)getMaxEventBufferSize {
    return maxBufferSize;
}

- (void)setMaxEventBufferTimeInSeconds:(NSUInteger)seconds {
    maxBufferTimeSeconds = seconds;
}

- (NSUInteger)getMaxEventBufferTimeInSeconds {
    return maxBufferTimeSeconds;
}

- (BOOL)didReachMaxQueueTime:(NSTimeInterval)currentTimeMilliseconds {
    if(oldestEventTimestamp == 0) {
        return false;
    }

    NSTimeInterval oldestEventAge = currentTimeMilliseconds - oldestEventTimestamp;
    return (oldestEventAge / kMillisecondsPerSecond) + kBufferTimeSecondsLeeway >= maxBufferTimeSeconds;
}

- (BOOL)didExceedMaxQueueTime:(NSTimeInterval)currentTimeMilliseconds {
    if(oldestEventTimestamp == 0) {
        return false;
    }
    NSTimeInterval oldestEventAge = currentTimeMilliseconds - oldestEventTimestamp;
    return (oldestEventAge / kMillisecondsPerSecond) >= maxBufferTimeSeconds;
}

- (NSUInteger)getEvictionIndex {
    if(totalAttemptedInserts > 0) {
        return arc4random() % totalAttemptedInserts;
    } else {
        return 0;
    }
}

- (BOOL)addEvent:(id<NRMAAnalyticEventProtocol>)event {
    BOOL added = NO;
    @synchronized (events) {
        // The event fits within the buffer
        if (events.count < maxBufferSize) {
            [events addObject:event];

            if(events.count == 1) {
                oldestEventTimestamp = event.timestamp;
            }
            added = YES;
        } else {
            [NRMASupportMetricHelper enqueueEventOverflowMetric];
            [NRMASupportMetricHelper enqueueEventQueueSizeExceededMetric];

            // we need to throw away an event. We try to balance
            // between evicting newer events and older events.
            NSUInteger evictionIndex = [self getEvictionIndex];
            if (evictionIndex < events.count) {
                id<NRMAAnalyticEventProtocol> evictedEvent = events[evictionIndex];
                [events removeObjectAtIndex:evictionIndex];
                [events addObject:event];
                added = YES;

                if (evictedEvent.eventUUID && [NRMAFlags shouldEnableEventPersistence]) {
                    [[NREventPersistenceController shared] discardPersistedEventWithEventUUID:evictedEvent.eventUUID];
                }
            }
            // else: the random eviction index landed outside the queue's current
            // bounds -- drop the incoming event instead of silently losing it,
            // matching the Android agent's handling of the same case.
            [NRMASupportMetricHelper enqueueEventEvictedMetric];
            eventsEvicted++;
        }

        totalAttemptedInserts++;
        if (added) {
            [NRMASupportMetricHelper enqueueEventAddedMetric];
            eventsRecorded++;

            // Persist freshly-recorded events for crash/force-quit recovery.
            if ([NRMAFlags shouldEnableEventPersistence]) {
                NSString *sessionId = [[NewRelicAgentInternal sharedInstance] currentSessionId] ?: @"";
                [[NREventPersistenceController shared] recordEventWithEventUUID:event.eventUUID
                                                                        eventType:event.eventType
                                                                      timestampMs:(int64_t)event.timestamp
                                                                       attributes:(NSDictionary *)[event JSONObject]
                                                                        sessionId:sessionId
                                                                      realAgentId:NRMA_getAgentId()];
            }
        }
    }
    return added;
}

- (NSUInteger)getEventsRecordedCount {
    return eventsRecorded;
}

- (NSUInteger)getEventsEvictedCount {
    return eventsEvicted;
}

- (void)empty {
    @synchronized (events) {
        [events removeAllObjects];
        totalAttemptedInserts = 0;
    }
}

- (void)resetTimestamp {
    oldestEventTimestamp = 0;
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
                                                           error:error];
            eventJsonString = [[NSString alloc] initWithData:eventJsonData
                                                    encoding:NSUTF8StringEncoding];
        } @catch (NSException *e) {
            NRLOG_AGENT_ERROR(@"FAILED TO CREATE EVENT JSON: %@", e.reason);
        }
        // Clear under the same lock the events were read under. Clearing after releasing it
        // also wiped any event -addEvent: inserted in between, which was never serialized.
        if (clearEvents) {
            // This batch is about to be handed to a harvest attempt whose outcome
            // isn't known yet -- mark pending (not delete) so the persisted copies
            // survive until a later confirmed success. Otherwise a successfully
            // harvested event's on-disk copy would linger forever and get wrongly
            // recovered/re-sent as a duplicate on a future relaunch.
            if ([NRMAFlags shouldEnableEventPersistence]) {
                NSMutableArray<NSString *> *eventUUIDs = [NSMutableArray arrayWithCapacity:events.count];
                for (id<NRMAAnalyticEventProtocol> event in events) {
                    if (event.eventUUID) {
                        [eventUUIDs addObject:event.eventUUID];
                    }
                }
                [[NREventPersistenceController shared] markEventsPendingConfirmationWithEventUUIDs:eventUUIDs];
            }
            [self empty];
        }
    }
    return eventJsonString;
}

@end
