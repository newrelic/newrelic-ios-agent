//
//  NRMAMobileEvent.m
//  Agent
//
//  Created by Mike Bruin on 7/31/23.
//  Copyright © 2023 New Relic. All rights reserved.
//

#import <UIKit/UIKit.h>

#import "NRMAMobileEvent.h"
#import "Constants.h"
#import "NRMAFlags.h"
#import "NewRelicInternalUtils.h"
#import "NewRelicAgentInternal.h"

static NSString* const kTimestampKey = @"Timestamp";
static NSString* const kSessionElapsedTimeKey = @"SessionElapsedTime";
static NSString* const kEventTypeKey = @"EventType";
static NSString* const kAttributesKey = @"Attributes";

@implementation NRMAMobileEvent

+ (BOOL) supportsSecureCoding {
    return YES;
}

- (nonnull instancetype) initWithTimestamp:(NSTimeInterval)timestamp
               sessionElapsedTimeInSeconds:(NSTimeInterval)sessionElapsedTimeSeconds
                    withAttributeValidator:(__nullable id<AttributeValidatorProtocol>) attributeValidator {
    self = [super init];
    if (self) {
        _eventType = kNRMA_RET_mobile;
        _timestamp = timestamp;
        _sessionElapsedTimeSeconds = sessionElapsedTimeSeconds;
        _attributeValidator = attributeValidator;
        _attributes = [[NSMutableDictionary alloc] init];
        
        if([NRMAFlags shouldEnableOfflineStorage]) {
            NRMAReachability* r = [NewRelicInternalUtils reachability];
            @synchronized(r) {
#if TARGET_OS_WATCH
                NRMANetworkStatus status = [NewRelicInternalUtils currentReachabilityStatusTo:[NSURL URLWithString:[NewRelicInternalUtils collectorHostDataURL]]];
#else
                NRMANetworkStatus status = [r currentReachabilityStatus];
#endif
                if (status == NotReachable) {
                    [self addAttribute:kNRMA_Attrib_offline value:@YES];
                }
            }
        }
        // Handle Background attribute addition.
        if([NRMAFlags shouldEnableBackgroundReporting]) {
#if TARGET_OS_WATCH
            if ([NewRelicAgentInternal sharedInstance].currentApplicationState == WKApplicationStateBackground) {
#else
            if ([NewRelicAgentInternal sharedInstance].currentApplicationState == UIApplicationStateBackground) {
#endif
                [self addAttribute:kNRMA_Attrib_background value:@YES];
            }
        }
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

- (void)encodeWithCoder:(nonnull NSCoder *)coder {
    [coder encodeDouble:_timestamp forKey:kTimestampKey];
    [coder encodeDouble:_sessionElapsedTimeSeconds forKey:kSessionElapsedTimeKey];
    [coder encodeObject:_eventType forKey:kEventTypeKey];
    [coder encodeObject:_attributes forKey:kAttributesKey];
}

- (nullable instancetype)initWithCoder:(nonnull NSCoder *)coder {
    self = [super init];
    if(self) {
        self.timestamp = [coder decodeDoubleForKey:kTimestampKey];
        self.sessionElapsedTimeSeconds = [coder decodeDoubleForKey:kSessionElapsedTimeKey];
        self.eventType = [coder decodeObjectOfClass:[NSString class] forKey:kEventTypeKey];
        self.attributes = [coder decodeObjectOfClass:[NSString class] forKey:kAttributesKey];
    }
    
    return self;
}
@end
