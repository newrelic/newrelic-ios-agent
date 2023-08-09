//
//  NRMANetworkErrorEvent.m
//  Agent
//
//  Created by Mike Bruin on 8/2/23.
//  Copyright © 2023 New Relic. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "NRMANetworkErrorEvent.h"
#include "Constants.h"

@implementation NRMANetworkErrorEvent

- (nonnull instancetype) initWithTimestamp:(NSTimeInterval)timestamp
               sessionElapsedTimeInSeconds:(unsigned long long)sessionElapsedTimeSeconds
                       encodedResponseBody:(NSString *) encodedResponseBody
                             appDataHeader:(NSString *) appDataHeader
                                   payload:(NRMAPayload *)payload
                    withAttributeValidator:(__nullable id<AttributeValidatorProtocol>)attributeValidator
{
    self = [super initWithTimestamp:timestamp sessionElapsedTimeInSeconds:sessionElapsedTimeSeconds payload:payload withAttributeValidator:attributeValidator];
    if (self) {
        self.eventType = @"MobileRequestError";
        self.encodedResponseBody = encodedResponseBody;
        self.appDataHeader = appDataHeader;
    }
    
    return self;
}

- (id)JSONObject {
    NSDictionary *event = [super JSONObject];

    NSMutableDictionary *dict = [NSMutableDictionary dictionaryWithDictionary:event];
    dict[kNRMA_RA_responseBody] = self.encodedResponseBody;
    dict[kNRMA_RA_appDataHeader] = self.appDataHeader;

    return [NSDictionary dictionaryWithDictionary:dict];
}

@end
