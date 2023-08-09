//
//  NRMAMobileEvent.m
//  Agent
//
//  Created by Mike Bruin on 7/31/23.
//  Copyright © 2023 New Relic. All rights reserved.
//

#import "NRMAMobileEvent.h"
#import "Constants.h"

@implementation NRMAMobileEvent

- (nonnull instancetype) initWithTimestamp:(NSTimeInterval)timestamp
               sessionElapsedTimeInSeconds:(unsigned long long)sessionElapsedTimeSeconds
                    withAttributeValidator:(__nullable id<AttributeValidatorProtocol>) attributeValidator {
    self = [super init];
    if (self) {
        _eventType = kNRMA_RET_mobile;
        _timestamp = timestamp;
        _sessionElapsedTimeSeconds = sessionElapsedTimeSeconds;
        _attributeValidator = attributeValidator;
        _attributes = [[NSMutableDictionary alloc] init];
    }
    
    return self;
}

- (NSTimeInterval)getEventAge {
    return [[[NSDate alloc] init] timeIntervalSince1970] - self.timestamp;
}

- (BOOL)addAttribute:(NSString *)name value:(id)value {
    if(self.attributeValidator != nil && ![self.attributeValidator nameValidator:name]) {
        return NO;
    }
    
    if(self.attributeValidator != nil && ![self.attributeValidator valueValidator:value]) {
        return NO;
    }
    
    _attributes[name] = value;
    return true;
}

- (id)JSONObject {
    
    // There was a way to do this using the Objective-C runtime
    // to iterate through the properties, but I do not remember it
    NSMutableDictionary *dict = [NSMutableDictionary dictionaryWithDictionary:_attributes];
    dict[kNRMA_RA_timestamp] = @(self.timestamp);
    dict[kNRMA_RA_sessionElapsedTime] = @(self.sessionElapsedTimeSeconds);
    dict[kNRMA_RA_eventType] = self.eventType;

    return [NSDictionary dictionaryWithDictionary:dict];
}

@end
