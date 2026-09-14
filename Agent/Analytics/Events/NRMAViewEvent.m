//
//  NRMAViewEvent.m
//  Agent
//
//  Copyright © 2026 New Relic. All rights reserved.
//

#import "NRMAViewEvent.h"
#import "Constants.h"

@implementation NRMAViewEvent

+ (BOOL) supportsSecureCoding {
    return YES;
}

- (nonnull instancetype) initWithEventType:(NSString *)eventType
                                 timestamp:(NSTimeInterval)timestamp
               sessionElapsedTimeInSeconds:(NSTimeInterval)sessionElapsedTimeSeconds
                    withAttributeValidator:(__nullable id<AttributeValidatorProtocol>)attributeValidator
{
    self = [super initWithTimestamp:timestamp
        sessionElapsedTimeInSeconds:sessionElapsedTimeSeconds
             withAttributeValidator:attributeValidator];
    if (self) {
        self.eventType = eventType.length > 0 ? eventType : kNRMA_RET_mobileView;
    }

    return self;
}

@end
