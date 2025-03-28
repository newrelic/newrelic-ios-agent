//
//  NRMAAttributeValidator.m
//  Agent
//
//  Created by Mike Bruin on 1/24/25.
//  Copyright © 2025 New Relic. All rights reserved.
//

#import "NRMAAttributeValidator.h"
#import "Constants.h"
#import "NRMAAnalytics.h"
#import "NRLogger.h"

@implementation NRMAAttributeValidator

- (BOOL)eventTypeValidator:(NSString *)eventType {
    return YES;
}

- (BOOL)nameValidator:(NSString *)name {
    if ([name length] == 0) {
        NRLOG_AGENT_ERROR(@"invalid attribute: name length = 0");
        return false;
    }
    if ([name hasPrefix:@" "]) {
        NRLOG_AGENT_ERROR(@"invalid attribute: name prefix = \" \"");
        return false;
    }
    // check if attribute name is reserved or attribute name matches reserved prefix.
    for (NSString* key in [NRMAAnalytics reservedKeywords]) {
        if ([key isEqualToString:name]) {
            NRLOG_AGENT_ERROR(@"invalid attribute: name prefix disallowed");
            return false;
        }
    }
    for (NSString* key in [NRMAAnalytics reservedPrefixes]) {
        if ([name hasPrefix:key])  {
            NRLOG_AGENT_ERROR(@"invalid attribute: name prefix disallowed");
            return false;
        }
    }
    
    // check if attribute name exceeds max length.
    if ([name length] > kNRMA_Attrib_Max_Name_Length) {
        NRLOG_AGENT_ERROR(@"invalid attribute: name length exceeds limit");
        return false;
    }
    return true;
}

- (BOOL)valueValidator:(id)value {
    if ([value isKindOfClass:[NSString class]]) {
        if ([(NSString*)value length] == 0) {
            NRLOG_AGENT_ERROR(@"invalid attribute: value length = 0");
            return false;
        }
        else if ([(NSString*)value length] >= kNRMA_Attrib_Max_Value_Size_Bytes) {
            NRLOG_AGENT_ERROR(@"invalid attribute: value exceeded maximum byte size exceeded");
            return false;
        }
    }
    if (value == nil || [value isKindOfClass:[NSNull class]]) {
        NRLOG_AGENT_ERROR(@"invalid attribute: value cannot be nil");
        return false;
    }
    
    return true;
}

@end
