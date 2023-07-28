//
//  NRMARequestEvent.m
//  Agent
//
//  Created by Mike Bruin on 7/26/23.
//  Copyright © 2023 New Relic. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "NRMARequestEvent.h"

@implementation NRMARequestEvent {
    NSMutableDictionary<NSString *, id> *attributes;
}

@synthesize timestamp = m_timestamp;
@synthesize sessionElapsedTimeSeconds = m_sessionElapsedTimeSeconds;
@synthesize eventType = m_eventType;
@synthesize attributeValidator = m_attributeValidator;


- (nonnull instancetype) initWithEventType:(NSString *)eventType
                                 timestamp:(NSTimeInterval)timestamp
               sessionElapsedTimeInSeconds:(unsigned long long)sessionElapsedTimeSeconds
                                   payload:(NRMAPayload *)payload
                    withAttributeValidator:(id<AttributeValidatorProtocol>)attributeValidator {
    self = [super init];
    if (self) {
        m_timestamp = timestamp;
        m_sessionElapsedTimeSeconds = sessionElapsedTimeSeconds;
        m_eventType = eventType;
        m_attributeValidator = attributeValidator;
        _payload = payload;
        
        attributes = [[NSMutableDictionary alloc] init];
    }
    
    return self;
}

- (id)JSONObject {
    NRMACustomEvent *sut = [[NRMACustomEvent alloc] initWithEventType:m_eventType
                                                            timestamp:m_timestamp
                                          sessionElapsedTimeInSeconds:m_sessionElapsedTimeSeconds
                                               withAttributeValidator:m_attributeValidator];
    NSDictionary *event = [sut JSONObject];

    NSMutableDictionary *dict = [NSMutableDictionary dictionaryWithDictionary:event];
    dict[@"payload"] = [_payload JSONObject];

    return [NSDictionary dictionaryWithDictionary:dict];
}

@end
