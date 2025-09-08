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

static NSString* const kPayloadKey = @"Payload";

@implementation NRMARequestEvent

+ (BOOL) supportsSecureCoding {
    return YES;
}

- (nonnull instancetype) initWithTimestamp:(NSTimeInterval)timestamp
               sessionElapsedTimeInSeconds:(NSTimeInterval)sessionElapsedTimeSeconds
                                   payload:(NRMAPayload *)payload
                    withAttributeValidator:(__nullable id<AttributeValidatorProtocol>)attributeValidator {
    self = [super initWithTimestamp:timestamp sessionElapsedTimeInSeconds:sessionElapsedTimeSeconds withAttributeValidator:attributeValidator];
    if (self) {
        self.eventType = kNRMA_RET_mobileRequest;
        self.payload = payload;
    }
    
    return self;
}

- (id)JSONObject {
    NSDictionary *event = [super JSONObject];

    NSMutableDictionary *dict = [NSMutableDictionary dictionaryWithDictionary:event];
    dict[kNRMA_RA_payload] = [_payload JSONObject];

    return [NSDictionary dictionaryWithDictionary:dict];
}

- (void)encodeWithCoder:(NSCoder *)coder {
    [super encodeWithCoder:coder];
    
    [coder encodeObject:_payload forKey:kPayloadKey];
}

- (nullable instancetype)initWithCoder:(nonnull NSCoder *)coder {
    self = [super initWithCoder:coder];
    if(self) {
        self.payload = [coder decodeObjectOfClass:[NRMAPayload class] forKey:kPayloadKey];
    }
    
    return self;
}

@end
