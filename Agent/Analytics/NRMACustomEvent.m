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
    attributes[name] = value;
    return true;
}

- (id)JSONObject {
//    NSDictionary *dict = @{
//        @"timestamp":[NSNumber numberWithUnsignedLongLong:self.timestamp],
//        @"timeSinceLoad":[NSNumber numberWithUnsignedLongLong:self.sessionElapsedTimeSeconds],
//        @"eventType":self.eventType
//    };
    
    // There was a way to do this using the Objective-C runtime
    // to iterate through the properties, but I do not remember it
    NSMutableDictionary *dict = [NSMutableDictionary dictionaryWithDictionary:attributes];
    dict[@"timestamp"] = @(self.timestamp);
    dict[@"timeSinceLoad"] = @(self.sessionElapsedTimeSeconds);
    dict[@"eventType"] = self.eventType;
    

    return [NSDictionary dictionaryWithDictionary:dict];
}

@end
