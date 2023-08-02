//
//  NRMACustomEvent.m
//  Agent
//
//  Created by Steve Malsam on 6/13/23.
//  Copyright © 2023 New Relic. All rights reserved.
//

#import "NRMACustomEvent.h"

@implementation NRMACustomEvent

- (instancetype) initWithEventType:(NSString *)eventType
                         timestamp:(NSTimeInterval)timestamp
       sessionElapsedTimeInSeconds:(unsigned long long)sessionElapsedTimeSeconds
            withAttributeValidator:(__nullable id<AttributeValidatorProtocol>) attributeValidator
{
    self = [super init];
    if (self) {
        self.eventType = eventType;
        self.timestamp = timestamp;
        self.sessionElapsedTimeSeconds = sessionElapsedTimeSeconds;
        self.attributeValidator = attributeValidator;
    }
    
    return self;
}


@end
