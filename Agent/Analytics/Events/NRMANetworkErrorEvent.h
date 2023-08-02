//
//  NRMANetworkErrorEvent.h
//  Agent
//
//  Created by Mike Bruin on 8/2/23.
//  Copyright © 2023 New Relic. All rights reserved.
//

#import <Foundation/Foundation.h>

#import "NRMARequestEvent.h"
#import "AttributeValidatorProtocol.h"
#import "NRMAPayload.h"

NS_ASSUME_NONNULL_BEGIN

@interface NRMANetworkErrorEvent : NRMARequestEvent

@property (nonatomic, strong) NSString * encodedResponseBody;
@property (nonatomic, strong) NSString * appDataHeader;

- (nonnull instancetype) initWithTimestamp:(NSTimeInterval)timestamp
               sessionElapsedTimeInSeconds:(unsigned long long)sessionElapsedTimeSeconds
                       encodedResponseBody:(NSString *) encodedResponseBody
                             appDataHeader:(NSString *) appDataHeader
                                   payload:(NRMAPayload *)payload
                    withAttributeValidator:(id<AttributeValidatorProtocol>)attributeValidator;

@end

NS_ASSUME_NONNULL_END
