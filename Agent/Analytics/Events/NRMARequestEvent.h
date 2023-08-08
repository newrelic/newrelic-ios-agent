//
//  NRMARequestEvent.h
//  Agent
//
//  Created by Mike Bruin on 7/26/23.
//  Copyright © 2023 New Relic. All rights reserved.
//

#import <Foundation/Foundation.h>

#import "NRMAMobileEvent.h"
#import "AttributeValidatorProtocol.h"
#import "NRMAPayload.h"

NS_ASSUME_NONNULL_BEGIN

@interface NRMARequestEvent : NRMAMobileEvent
@property (weak) NRMAPayload* payload;

- (nonnull instancetype) initWithTimestamp:(NSTimeInterval)timestamp
               sessionElapsedTimeInSeconds:(unsigned long long)sessionElapsedTimeSeconds
                                   payload:(NRMAPayload *)payload
                    withAttributeValidator:(__nullable id<AttributeValidatorProtocol>)attributeValidator;

@end

NS_ASSUME_NONNULL_END
