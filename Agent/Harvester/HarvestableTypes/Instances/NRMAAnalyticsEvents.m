//
// Created by Bryce Buchanan on 2/9/15.
// Copyright © 2023 New Relic. All rights reserved.
//

#import "NRMAAnalyticsEvents.h"
#import "NRMAHarvestableEvent.h"
#import "NRMAHarvestController.h"
@implementation NRMAAnalyticsEvents
- (instancetype) init
{
    self = [super init];
    if (self) {
        self.events = [NSMutableArray new];
    }
    return self;
}
- (void) clear
{
    @synchronized (_events) {
        [_events removeAllObjects];
    }
}
- (NSUInteger) count
{
    @synchronized (_events) {
        return [_events count];
    }
}

- (id) JSONObject {
    NSMutableArray* array = [NSMutableArray new];
    @synchronized(_events) {
        for(NRMAHarvestableEvent* event in self.events) {
            [array addObject:[event JSONObject]];
        }
    }
    return array;
}
- (void) addEvents:(NSArray*) events  // array of dictionaries
{
    @synchronized (_events) {
        for (NSDictionary* event in events) {
            NRMAHarvestableEvent* harvestableEvent = [[NRMAHarvestableEvent alloc] initWithDictionary:event];
            [_events addObject:harvestableEvent];
        }
    }
}

- (void) onHarvestBefore {
   NSMutableArray* removalArray = [NSMutableArray new];
    int maxSendAttempts;
    NRMAHarvesterConfiguration *config = [NRMAHarvestController configuration];
    if (config == nil) {
        maxSendAttempts = NRMA_DEFAULT_ACTIVITY_TRACE_MAX_SEND_ATTEMPTS;
    } else {
        maxSendAttempts = config.activity_trace_max_send_attempts;
    }

    @synchronized(_events) {
        for (NRMAHarvestableEvent* event in _events) {
            event.sendAttempts++;
            if (event.sendAttempts > maxSendAttempts) {
                [removalArray addObject:event];
            }
        }
        if ([removalArray count]) {
            [_events removeObjectsInArray:removalArray];
        }
    }
}

- (void)onHarvestError
{
    NSMutableArray *removalArray = [NSMutableArray array];
    int maxSendAttempts;
    NRMAHarvesterConfiguration *config = [NRMAHarvestController configuration];
    if (config == nil) {
        maxSendAttempts = NRMA_DEFAULT_ACTIVITY_TRACE_MAX_SEND_ATTEMPTS;
    } else {
        maxSendAttempts = config.activity_trace_max_send_attempts;
    }

    @synchronized(_events) {
        for (NRMAHarvestableEvent* event in _events) {
            if (event.sendAttempts >= maxSendAttempts) {
                [removalArray addObject:event];
            }
        }
        if ([removalArray count]) {
            [_events removeObjectsInArray:removalArray];
        }
    }
}
@end
