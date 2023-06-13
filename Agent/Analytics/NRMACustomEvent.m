//
//  NRMACustomEvent.m
//  Agent
//
//  Created by Steve Malsam on 6/13/23.
//  Copyright © 2023 New Relic. All rights reserved.
//

#import "NRMACustomEvent.h"

@implementation NRMACustomEvent

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
    }
    
    return self;
}

- (NSTimeInterval)getEventAge {
//    NSDate *now = [[NSDate alloc] init];
//    return [now timeIntervalSinceDate:[NSDate dateWithTimeIntervalSinceReferenceDate:self.timestamp]];
    return [[[NSDate alloc] init] timeIntervalSince1970] - self.timestamp;
}

- (BOOL)addAttribute:(NSString *)name value:(id)value {
    return true;
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
