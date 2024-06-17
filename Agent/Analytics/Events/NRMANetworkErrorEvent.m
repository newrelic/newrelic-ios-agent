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

static NSString* const kEncodedResponseKey = @"EncodedResponseBody";
static NSString* const kAppDataHeaderKey = @"AppDataHeader";

@implementation NRMANetworkErrorEvent

+ (BOOL) supportsSecureCoding {
    return YES;
}

- (nonnull instancetype) initWithTimestamp:(NSTimeInterval)timestamp
               sessionElapsedTimeInSeconds:(NSTimeInterval)sessionElapsedTimeSeconds
                       encodedResponseBody:(NSString *) encodedResponseBody
                             appDataHeader:(NSString *) appDataHeader
                                   payload:(NRMAPayload *)payload
                    withAttributeValidator:(__nullable id<AttributeValidatorProtocol>)attributeValidator
{
    self = [super initWithTimestamp:timestamp sessionElapsedTimeInSeconds:sessionElapsedTimeSeconds payload:payload withAttributeValidator:attributeValidator];
    if (self) {
        self.eventType = kNRMA_RET_mobileRequestError;
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

- (void)encodeWithCoder:(NSCoder *)coder {
    [super encodeWithCoder:coder];
    
    [coder encodeObject:self.encodedResponseBody forKey:kEncodedResponseKey];
    [coder encodeObject:self.appDataHeader forKey:kAppDataHeaderKey];
}

- (nullable instancetype)initWithCoder:(nonnull NSCoder *)coder {
    self = [super initWithCoder:coder];
    if(self) {
        self.encodedResponseBody = [coder decodeObjectOfClass:[NSString class] forKey:kEncodedResponseKey];
        self.appDataHeader =  [coder decodeObjectOfClass:[NSString class] forKey:kAppDataHeaderKey];
    }
    
    return self;
}

@end
