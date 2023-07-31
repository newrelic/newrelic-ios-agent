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

- (nonnull instancetype) initWithEventType:(NSString *)eventType
                                 timestamp:(NSTimeInterval)timestamp
               sessionElapsedTimeInSeconds:(unsigned long long)sessionElapsedTimeSeconds
                                   payload:(NRMAPayload *)payload
                    withAttributeValidator:(id<AttributeValidatorProtocol>)attributeValidator {
    self = [super init];
    if (self) {
        self.timestamp = timestamp;
        self.sessionElapsedTimeSeconds = sessionElapsedTimeSeconds;
        self.eventType = eventType;
        self.attributeValidator = attributeValidator;
        _payload = payload;
    }
    
    return self;
}

- (id)JSONObject {
    NRMAMobileEvent *sut = [[NRMAMobileEvent alloc] initWithEventType:self.eventType
                                                            timestamp:self.timestamp
                                          sessionElapsedTimeInSeconds:self.sessionElapsedTimeSeconds
                                               withAttributeValidator:self.attributeValidator];
    NSDictionary *event = [sut JSONObject];

    NSMutableDictionary *dict = [NSMutableDictionary dictionaryWithDictionary:event];
    [dict addEntriesFromDictionary:self.attributes];
    dict[@"payload"] = [_payload JSONObject];

    return [NSDictionary dictionaryWithDictionary:dict];
}

@end
