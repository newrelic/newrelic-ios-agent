//
//  NRMASAM.mm
//  NewRelicAgent
//
//  Created by Chris Dillard on 7/26/23.
//  Copyright © 2023 New Relic. All rights reserved.
//

#import "NRMASAM.h"
#import "NRLogger.h"
#import "NewRelicInternalUtils.h"
#import "NRMABool.h"

NSArray *reservedKeys = @[@"eventType",
                          @"type",
                          @"timestamp",
                          @"category",
                          @"accountId",
                          @"appId",
                          @"appName",
                          @"uuid",
                          @"sessionDuration",
                          @"osName",
                          @"osVersion",
                          @"osMajorVersion",
                          @"deviceManufacturer",
                          @"deviceModel",
                          @"carrier",
                          @"newRelicVersion",
                          @"memUsageMb",
                          @"sessionId",
                          @"install",
                          @"upgradeFrom",
                          @"platform",
                          @"platformVersion",
                          @"lastInteraction",
];

NSString* userIdReservedKey = @"userId";
NSString* lastInteractionReservedKey = @"lastInteraction";

int maxNameLength = 256;
int maxValueSizeBytes = 4096;
int maxNumberAttributes = 128;

NSString *attributesFileName = @"attributes.txt";

@implementation NRMASAM {
    NSMutableDictionary<NSString*, id> *attributeDict;
}

- (nonnull instancetype)init {
    self = [super init];
    if (self) {
        attributeDict = [[NSMutableDictionary alloc] init];
    }
    return self;
}

- (BOOL) setLastInteraction:(NSString*)name {
    return [self setNRSessionAttribute:lastInteractionReservedKey value:name];
}

- (BOOL) setNRSessionAttribute:(NSString*)name value:(id)value {
    return [self setAttribute:name value:value validate:false];
}

- (BOOL) setSessionAttribute:(NSString*)name value:(id)value persistent:(BOOL)isPersistent {
    return [self setAttribute:name value:value validate:true];
}

-  (BOOL) setAttribute:(NSString*)name value:(id)value validate:(BOOL)validate {
    if (validate) {
        BOOL validAttribute = [self isValidAttributeName:name];
        BOOL validValue = [self isValidValue:value];

        if (!(validAttribute && validValue)) {
            NRLOG_VERBOSE(@"Failed to create attribute named %@", name);
            return false;
        }
    }
    if (attributeDict.count >= maxNumberAttributes) {
        NRLOG_VERBOSE(@"Unable to add attribute %@, the max attribute limit (128) is reached", name);
        return false;
    }

    if([value isKindOfClass:[NRMABool class]]) {
        value = @(([(NRMABool*) value value]));
    }

    [attributeDict setValue:value forKey:name];

    [self persistToDisk];

    return true;
}

- (BOOL) setUserId:(NSString *)userId {
    return [self setSessionAttribute:userIdReservedKey value:userId persistent:true];
}

- (BOOL) removeSessionAttributeNamed:(NSString*)name {
    id value = [attributeDict objectForKey:name];
    [attributeDict removeObjectForKey:name];
    [self persistToDisk];

    if (value) {
        return true;
    }
    else {
        NRLOG_VERBOSE(@"Failed to remove Session Attribute - it does not exist.");
        
        return false;
    }
}

- (BOOL) removeAllSessionAttributes {
    [attributeDict removeAllObjects];

    [self persistToDisk];

    return true;
}

- (BOOL) incrementSessionAttribute:(NSString*)name value:(NSNumber*)number persistent:(BOOL)persistent {
    id existingValue = [attributeDict objectForKey:name];

    if ([NewRelicInternalUtils isInteger:number] || ([NewRelicInternalUtils isFloat:number])) {
        float incrementValue = 0;
        if ([NewRelicInternalUtils isInteger:number] ) {
            unsigned long long incrementValueLongLong = (unsigned long long)[number integerValue];
            incrementValue = (float) incrementValueLongLong;
        } else if ([NewRelicInternalUtils isFloat:number])  {
            incrementValue =  [number floatValue];
        }
        if (existingValue && [existingValue isKindOfClass:[NSNumber class]]) {
            float existingFloatValue = 0;

            if ([NewRelicInternalUtils isInteger:existingValue] ) {
                existingFloatValue = (float) [existingValue integerValue];
            } else if ([NewRelicInternalUtils isFloat:existingValue])  {
                existingFloatValue = [existingValue floatValue];
            }
            [attributeDict setValue:@(existingFloatValue + incrementValue) forKey:name];
            [self persistToDisk];

            return true;
        }
        else {
            [attributeDict setValue:number forKey:name];
            [self persistToDisk];
            return false;
        }
    }

    return false;
}

- (NSString*) sessionAttributeJSONString {
    NSError *error;
    NSData *jsonData = [NSJSONSerialization dataWithJSONObject:attributeDict options:0 error:&error];
    if (!jsonData) {
        NRLOG_VERBOSE(@"Failed to create session attribute json w/ error = %@", error);
    }
    else {
        return( [[NSString alloc] initWithData:jsonData encoding:NSUTF8StringEncoding]);
    }
    return nil;
}

+ (NSString*) getLastSessionsAttributes {
    NSData *data = [NSData dataWithContentsOfFile:[self attributeFilePath]];
    if (data) {
        return [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
    }
    return nil;
}

- (void) clearLastSessionsAnalytics {
    [attributeDict removeAllObjects];
}

- (void) clearPersistedSessionAnalytics {
    [attributeDict removeAllObjects];

    NSError* error;
    [[NSFileManager defaultManager] removeItemAtPath:[NRMASAM attributeFilePath] error:&error];
    if (error) {
        NRLOG_VERBOSE(@"Failed to clear Persisted Session Analytics w/ error = %@", error);
    }
}

- (BOOL) persistToDisk {
    NSString* currentAttributes = [self sessionAttributeJSONString];

    NSData* data = [currentAttributes dataUsingEncoding:NSUTF8StringEncoding];
    if (data) {
        [data writeToFile:[NRMASAM attributeFilePath] atomically:true];

        return true;
    }
    else {
        return false;
    }
}

// Validators

-(BOOL) isValidAttributeName:(NSString*)name {
    if ([name length] == 0) {
        NRLOG_ERROR(@"invalid attribute: name length = 0");
        return false;
    }
    if ([name hasPrefix:@" "]) {
        NRLOG_ERROR(@"invalid attribute: name prefix = \" \"");
        return false;
    }
    // check if attribute name is reserved or attribute name matches reserved prefix.
    for (NSString* key in reservedKeys) {
        if ([key isEqualToString:name]) {
            NRLOG_ERROR(@"invalid attribute: name prefix disallowed");
            return false;
        }
        if ([name hasPrefix: key])  {
            NRLOG_ERROR(@"invalid attribute: name prefix disallowed");
            return false;
        }
    }
    // check if attribute name exceeds max length.
    if ([name length] > maxNameLength) {
        NRLOG_ERROR(@"invalid attribute: name length exceeds limit");
        return false;
    }

    return true;
}

-(BOOL) isValidValue:(id)value {
    if ([value isKindOfClass:[NSString class]]) {
        if ([(NSString*)value length] == 0) {
            NRLOG_ERROR(@"invalid attribute: value length = 0");
            return false;
        }
        else if ([(NSString*)value length] >= maxValueSizeBytes) {
            NRLOG_ERROR(@"invalid attribute: value exceeded maximum byte size exceeded");
            return false;
        }
    }
    if (value == nil) {
        NRLOG_ERROR(@"invalid attribute: value cannot be nil");
        return false;
    }

    return true;
}

// Helpers

+(NSString*)attributeFilePath {
    return [NSString stringWithFormat:@"%@/%@",[NewRelicInternalUtils getStorePath],attributesFileName];
}

@end
