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

@implementation NRMAEventManager {
    NSMutableArray<NRMAAnalyticEventProtocol> *events;
}

- (nonnull instancetype)init {
    self = [super init];
    if (self) {
        events = [[NSMutableArray alloc] init];
    }
    return self;
}

- (BOOL)addEvent:(id<NRMAAnalyticEventProtocol>)event {
    @synchronized (self) {
        [events addObject:event];
    }
    return YES;
}

- (nullable NSString *)getEventJSONStringWithError:(NSError *__autoreleasing *)error {
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
    return eventJsonString;
}

@end
