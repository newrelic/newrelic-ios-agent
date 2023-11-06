//
//  NRMACustomEvent.h
//  Agent
//
//  Created by Steve Malsam on 6/13/23.
//  Copyright © 2023 New Relic. All rights reserved.
//

#import <Foundation/Foundation.h>

#import "NRMAMobileEvent.h"
#import "AttributeValidatorProtocol.h"

NS_ASSUME_NONNULL_BEGIN

@interface NRMACustomEvent : NRMAMobileEvent

- (instancetype) initWithEventType:(NSString *)eventType
                         timestamp:(NSTimeInterval)timestamp
       sessionElapsedTimeInSeconds:(NSTimeInterval)sessionElapsedTimeSeconds
            withAttributeValidator:(__nullable id<AttributeValidatorProtocol>) attributeValidator;

@end

NS_ASSUME_NONNULL_END
