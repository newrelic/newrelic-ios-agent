//
//  NRMAMobileEvent.m
//  Agent
//
//  Created by Mike Bruin on 7/31/23.
//  Copyright © 2023 New Relic. All rights reserved.
//

#import "NRMAMobileEvent.h"

@implementation NRMAMobileEvent

-(id) init {
    self = [super init];
    if (self) {
        _attributes = [[NSMutableDictionary alloc] init];
    }
    return self;
}

- (nonnull instancetype) initWithTimestamp:(NSTimeInterval)timestamp
               sessionElapsedTimeInSeconds:(unsigned long long)sessionElapsedTimeSeconds
                    withAttributeValidator:(id<AttributeValidatorProtocol>) attributeValidator {
    self = [super init];
    if (self) {
        _eventType = @"Mobile";
        _timestamp = timestamp;
        _sessionElapsedTimeSeconds = sessionElapsedTimeSeconds;
        _attributeValidator = attributeValidator;
    }
    
    return self;
}

- (NSTimeInterval)getEventAge {
    return [[[NSDate alloc] init] timeIntervalSince1970] - self.timestamp;
}

- (BOOL)addAttribute:(NSString *)name value:(id)value {
    if(![self.attributeValidator nameValidator:name]) {
        return NO;
    }
    
    if(![self.attributeValidator valueValidator:value]) {
        return NO;
    }
    
    _attributes[name] = value;
    return true;
}

- (id)JSONObject {
    
    // There was a way to do this using the Objective-C runtime
    // to iterate through the properties, but I do not remember it
    NSMutableDictionary *dict = [NSMutableDictionary dictionaryWithDictionary:_attributes];
    dict[@"timestamp"] = @(self.timestamp);
    dict[@"timeSinceLoad"] = @(self.sessionElapsedTimeSeconds);
    dict[@"eventType"] = self.eventType;

    return [NSDictionary dictionaryWithDictionary:dict];
}

@end
