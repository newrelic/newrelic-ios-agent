//
//  NRMARequestEvent.m
//  Agent
//
//  Created by Mike Bruin on 7/26/23.
//  Copyright © 2023 New Relic. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "NRMARequestEvent.h"

@implementation NRMARequestEvent

- (nonnull instancetype) initWithTimestamp:(NSTimeInterval)timestamp
               sessionElapsedTimeInSeconds:(unsigned long long)sessionElapsedTimeSeconds
                                   payload:(NRMAPayload *)payload
                    withAttributeValidator:(id<AttributeValidatorProtocol>)attributeValidator {
    self = [super init];
    if (self) {
        self.timestamp = timestamp;
        self.sessionElapsedTimeSeconds = sessionElapsedTimeSeconds;
        self.eventType = @"MobileRequest";
        self.attributeValidator = attributeValidator;
        _payload = payload;
    }
    
    return self;
}

- (id)JSONObject {
    NSDictionary *event = [super JSONObject];

    NSMutableDictionary *dict = [NSMutableDictionary dictionaryWithDictionary:event];
    dict[@"payload"] = [_payload JSONObject];//TODO: make sure this is the right key

    return [NSDictionary dictionaryWithDictionary:dict];
}

@end
