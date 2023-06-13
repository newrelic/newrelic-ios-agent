//
//  NRMAAnalyticEvent.m
//  Agent
//
//  Created by Steve Malsam on 6/8/23.
//  Copyright © 2023 New Relic. All rights reserved.
//

#import "NRMAAnalyticEvent.h"

@implementation NRMAAnalyticEvent

//- (instancetype) init {
//    self = [super init];
//    if (self) {
//        _timestamp = [[NSDate date] timeIntervalSince1970];
//    }
//    return self;
//}

- (nonnull instancetype)initWithTimestamp:(NSTimeInterval)timestamp
              sessionElapsedTimeInSeconds:(unsigned long long)sessionElapsedTimeSeconds {
    self = [super init];
    if (self) {
        _timestamp = timestamp;
        _sessionElapsedTimeSeconds = sessionElapsedTimeSeconds;
    }
    
    return self;
}

- (id)JSONObject {
    NSDictionary *dict = @{
        @"timestamp":[NSNumber numberWithUnsignedLongLong:self.timestamp],
        @"timeSinceLoad":[NSNumber numberWithUnsignedLongLong:self.sessionElapsedTimeSeconds]
    };

    return dict;
}



@end
