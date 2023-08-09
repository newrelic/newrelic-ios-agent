//
//  NRMARequestEvent.m
//  Agent
//
//  Created by Mike Bruin on 7/26/23.
//  Copyright © 2023 New Relic. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "NRMARequestEvent.h"
#import "Constants.h"

@implementation NRMARequestEvent

- (nonnull instancetype) initWithTimestamp:(NSTimeInterval)timestamp
               sessionElapsedTimeInSeconds:(NSTimeInterval)sessionElapsedTimeSeconds
                                   payload:(NRMAPayload *)payload
                    withAttributeValidator:(__nullable id<AttributeValidatorProtocol>)attributeValidator {
    self = [super initWithTimestamp:timestamp sessionElapsedTimeInSeconds:sessionElapsedTimeSeconds withAttributeValidator:attributeValidator];
    if (self) {
        self.eventType = kNRMA_RET_mobileRequest;
        _payload = payload;
    }
    
    return self;
}

- (id)JSONObject {
    NSDictionary *event = [super JSONObject];

    NSMutableDictionary *dict = [NSMutableDictionary dictionaryWithDictionary:event];
    dict[kNRMA_RA_payload] = [_payload JSONObject];//TODO: make sure this is the right key

    return [NSDictionary dictionaryWithDictionary:dict];
}

@end
