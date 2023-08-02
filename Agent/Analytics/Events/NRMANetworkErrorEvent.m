//
//  NRMANetworkErrorEvent.m
//  Agent
//
//  Created by Mike Bruin on 8/2/23.
//  Copyright © 2023 New Relic. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "NRMANetworkErrorEvent.h"

@implementation NRMANetworkErrorEvent

- (nonnull instancetype) initWithTimestamp:(NSTimeInterval)timestamp
               sessionElapsedTimeInSeconds:(unsigned long long)sessionElapsedTimeSeconds
                       encodedResponseBody:(NSString *) encodedResponseBody
                             appDataHeader:(NSString *) appDataHeader
                                   payload:(NRMAPayload *)payload
                    withAttributeValidator:(id<AttributeValidatorProtocol>)attributeValidator
{
    self = [super init];
    if (self) {
        self.timestamp = timestamp;
        self.sessionElapsedTimeSeconds = sessionElapsedTimeSeconds;
        self.eventType = @"MobileRequestError";
        self.attributeValidator = attributeValidator;
        self.payload = payload;
        self.encodedResponseBody = encodedResponseBody;
        self.appDataHeader = appDataHeader;
    }
    
    return self;
}

- (id)JSONObject {
    NSDictionary *event = [super JSONObject];

    NSMutableDictionary *dict = [NSMutableDictionary dictionaryWithDictionary:event];
//TODO: make sure these are the right keys
    dict[@"encodedResponseBody"] = self.encodedResponseBody;
    dict[@"appDataHeader"] = self.appDataHeader;

    return [NSDictionary dictionaryWithDictionary:dict];
}

@end
