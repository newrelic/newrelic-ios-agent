//
//  NRMAAnalyticEventProtocol.h
//  Agent
//
//  Created by Steve Malsam on 6/8/23.
//  Copyright © 2023 New Relic. All rights reserved.
//

#ifndef NRMAAnalyticEventProtocol_h
#define NRMAAnalyticEventProtocol_h

#import "NRMAJSON.h"

@protocol NRMAAnalyticEventProtocol <NSObject, NRMAJSONABLE, NSSecureCoding>

@property (readonly) NSTimeInterval timestamp;
@property (readonly) NSTimeInterval sessionElapsedTimeSeconds;
@property (nonatomic, strong) NSString *eventType;
@property (strong) NSMutableDictionary<NSString *, id> *attributes;

// Stable identifier for this event, used only internally (persisted-event
// filename / dedup key) -- never sent in the harvest JSON payload.
@property (nonatomic, strong) NSString *eventUUID;

// YES if this event was reloaded from the on-disk persisted-event store (e.g.
// during startup recovery) rather than freshly recorded. Recovered events are
// never re-persisted -- they're already on disk under their original UUID.
@property (nonatomic) BOOL isRecoveredEvent;

- (BOOL) addAttribute:(NSString *)name value:(id)value;
- (NSTimeInterval)getEventAge;

@end

#endif /* NRMAAnalyticEventProtocol_h */
