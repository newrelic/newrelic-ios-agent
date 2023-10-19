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
       sessionElapsedTimeInSeconds:(NSTimeInterval)sessionElapsedTimeSeconds
            withAttributeValidator:(__nullable id<AttributeValidatorProtocol>) attributeValidator
{
    self = [super initWithTimestamp:timestamp sessionElapsedTimeInSeconds:sessionElapsedTimeSeconds withAttributeValidator:attributeValidator];
    if (self) {
        self.eventType = eventType;
    }
    
    return self;
}

@end
