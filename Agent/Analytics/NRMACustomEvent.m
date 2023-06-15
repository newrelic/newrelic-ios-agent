//
//  NRMACustomEvent.m
//  Agent
//
//  Created by Steve Malsam on 6/13/23.
//  Copyright © 2023 New Relic. All rights reserved.
//

#import "NRMACustomEvent.h"

@implementation NRMACustomEvent {
    NSMutableDictionary<NSString *, id> *attributes;
}

//- (instancetype) init {
//    self = [super init];
//    if (self) {
//        _timestamp = [[NSDate date] timeIntervalSince1970];
//    }
//    return self;
//}

- (nonnull instancetype) initWithEventType:(NSString *)eventType
                                 timestamp:(NSTimeInterval)timestamp
               sessionElapsedTimeInSeconds:(unsigned long long)sessionElapsedTimeSeconds {
    self = [super init];
    if (self) {
        _timestamp = timestamp;
        _sessionElapsedTimeSeconds = sessionElapsedTimeSeconds;
        _eventType = eventType;
        
        attributes = [[NSMutableDictionary alloc] init];
    }
    
    return self;
}

- (NSTimeInterval)getEventAge {
    return [[[NSDate alloc] init] timeIntervalSince1970] - self.timestamp;
}

- (BOOL)addAttribute:(NSString *)name value:(id)value {
    
}

- (id)JSONObject {
    NSDictionary *dict = @{
        @"timestamp":[NSNumber numberWithUnsignedLongLong:self.timestamp],
        @"timeSinceLoad":[NSNumber numberWithUnsignedLongLong:self.sessionElapsedTimeSeconds],
        @"eventType":self.eventType
    };

    return dict;
}

@end
