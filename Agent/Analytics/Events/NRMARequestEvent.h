//
//  NRMARequestEvent.h
//  Agent
//
//  Created by Mike Bruin on 7/26/23.
//  Copyright © 2023 New Relic. All rights reserved.
//

#import <Foundation/Foundation.h>

#import "NRMACustomEvent.h"
#import "NRMAAnalyticEventProtocol.h"
#import "AttributeValidatorProtocol.h"
#import "NRMAPayload.h"

NS_ASSUME_NONNULL_BEGIN

@interface NRMARequestEvent : NRMACustomEvent <NRMAAnalyticEventProtocol>
@property (weak) NRMAPayload* payload;

- (nonnull instancetype) initWithEventType:(NSString *)eventType
                                 timestamp:(NSTimeInterval)timestamp
               sessionElapsedTimeInSeconds:(unsigned long long)sessionElapsedTimeSeconds
                                   payload:(NRMAPayload *)payload
                    withAttributeValidator:(id<AttributeValidatorProtocol>)attributeValidator;

@end

NS_ASSUME_NONNULL_END
