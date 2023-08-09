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
#import "NRMAAnalyticsConstants.h"

@implementation NRMASAM {
    NSMutableDictionary<NSString*, id> *attributeDict;
    BlockAttributeValidator *attributeValidator;
}

- (id)initWithAttributeValidator:(BlockAttributeValidator*)validator {
    self = [super init];
    if (self) {
        attributeDict = [[NSMutableDictionary alloc] init];
        attributeValidator = validator;
    }
    return self;
}

- (BOOL) setLastInteraction:(NSString*)name {
    return [self setNRSessionAttribute:lastInteractionReservedKey value:name];
}

- (BOOL) setNRSessionAttribute:(NSString*)name value:(id)value {
    return [self setAttribute:name value:value validate:false];
}

- (BOOL) setSessionAttribute:(NSString*)name value:(id)value {
    return [self setAttribute:name value:value validate:true];
}

-  (BOOL) setAttribute:(NSString*)name value:(id)value validate:(BOOL)validate {
    if (validate) {
        BOOL validAttribute = [attributeValidator nameValidator:name];
        BOOL validValue = [attributeValidator valueValidator:value];

        if (!(validAttribute && validValue)) {
            NRLOG_VERBOSE(@"Failed to create attribute named %@", name);
            return false;
        }
        unsigned long countOfPrivateAttributes = [self countOfPrivateAttributes];

        if (attributeDict.count >= maxNumberAttributes + countOfPrivateAttributes) {
            NRLOG_VERBOSE(@"Unable to add attribute %@, the max attribute limit (128) is reached", name);
            return false;
        }
    }

    if([value isKindOfClass:[NRMABool class]]) {
        value = @(([(NRMABool*) value value]));
    }
    unsigned long preAddCount = attributeDict.count;

    [attributeDict setValue:value forKey:name];

    unsigned long postAddCount = attributeDict.count;

    // If a NR System Attrib was added to attributeDict increment the count
    if (!validate && (preAddCount != postAddCount)) {
        unsigned long currentCount = [self countOfPrivateAttributes];

        unsigned long newValue = currentCount == 0 ? 2 : currentCount + 1;
        [attributeDict setValue:@(newValue) forKey:privateAttributeCountIdentifier];
    }

    [self persistToDisk];

    return true;
}

- (BOOL) setUserId:(NSString *)userId {
    return [self setSessionAttribute:userIdReservedKey value:userId];
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

- (BOOL) incrementSessionAttribute:(NSString*)name value:(NSNumber*)number {
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

// Helpers

-(unsigned long) countOfPrivateAttributes {
    id existingCount = attributeDict[privateAttributeCountIdentifier];
    unsigned long existingCountInt = 0;
    if (existingCount != nil) {
        existingCountInt = [existingCount unsignedLongValue];
    }
    return existingCountInt;
}

+(NSString*)attributeFilePath {
    return [NSString stringWithFormat:@"%@/%@",[NewRelicInternalUtils getStorePath],attributesFileName];
}

@end
