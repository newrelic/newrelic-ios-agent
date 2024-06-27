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
#import "AttributeValidatorProtocol.h"
#import "Constants.h"
#import "NRMAAnalytics.h"

@interface NRMASAM ()
@end

@implementation NRMASAM {
    NSMutableDictionary<NSString*, id> *attributeDict;
    NSMutableDictionary<NSString*, id> *privateAttributeDict;
    
    PersistentEventStore * _attributePersistentStore;
    PersistentEventStore * _privateAttributePersistentStore;

    __nullable id<AttributeValidatorProtocol> attributeValidator;
}

- (id)initWithAttributeValidator:(__nullable id<AttributeValidatorProtocol>)validator {
    self = [super init];
    if (self) {
        _attributePersistentStore = [[PersistentEventStore alloc] initWithFilename:[NRMASAM attributeFilePath] andMinimumDelay:.025];
        
        _privateAttributePersistentStore = [[PersistentEventStore alloc] initWithFilename:[NRMASAM privateAttributeFilePath] andMinimumDelay:.025];

        // Load public attributes from file.
        NSDictionary *lastSessionAttributes = [PersistentEventStore getLastSessionEventsFromFilename:[NRMASAM attributeFilePath]];
        if (lastSessionAttributes != nil) {
            attributeDict = [lastSessionAttributes mutableCopy];
        }
        if (!attributeDict) {
            attributeDict = [[NSMutableDictionary alloc] init];
        }

        // Load private attributes from file.
        NSDictionary *lastSessionPrivateAttributes = [PersistentEventStore getLastSessionEventsFromFilename:[NRMASAM privateAttributeFilePath]];

        if (lastSessionPrivateAttributes != nil) {
            privateAttributeDict = [lastSessionPrivateAttributes mutableCopy];
        }
        if (!privateAttributeDict) {
            privateAttributeDict = [[NSMutableDictionary alloc] init];
        }

        attributeValidator = validator;
    }
    return self;
}

- (BOOL) setLastInteraction:(NSString*)name {
    return [self setNRSessionAttribute:kNRMA_RA_lastInteraction value:name];
}

- (BOOL) setNRSessionAttribute:(NSString*)name value:(id)value {

    if([value isKindOfClass:[NRMABool class]]) {
        value = @(([(NRMABool*) value value]));
    }

    @synchronized (privateAttributeDict) {
        [privateAttributeDict setValue:value forKey:name];
        [_privateAttributePersistentStore setObject:value forKey:name];
    }
    return YES;
}

- (BOOL) setSessionAttribute:(NSString*)name value:(id)value {
    return [self setAttribute:name value:value];
}

-  (BOOL) setAttribute:(NSString*)name value:(id)value {
    if ([self checkAttribute:name value:value]){
        return YES;
    }
    return NO;
}

-  (BOOL) checkAttribute:(NSString*)name value:(id)value {
    BOOL validAttribute = [attributeValidator nameValidator:name];
    BOOL validValue = [attributeValidator valueValidator:value];

    if (!(validAttribute && validValue)) {
        NRLOG_AGENT_VERBOSE(@"Failed to create attribute named %@", name);
        return NO;
    }
    if (attributeDict.count >= kNRMA_Attrib_Max_Number_Attributes) {
        NRLOG_AGENT_VERBOSE(@"Unable to add attribute %@, the max attribute limit (128) is reached", name);
        return NO;
    }

    if([value isKindOfClass:[NRMABool class]]) {
        value = @(([(NRMABool*) value value]));
    }

    @synchronized (attributeDict) {
        [attributeDict setValue:value forKey:name];
        [_attributePersistentStore setObject:value forKey:name];
    }

    return YES;
}

- (BOOL) setUserId:(NSString *)userId {
    return [self setSessionAttribute:kNRMA_Attrib_userId value:userId];
}

- (BOOL) removeSessionAttributeNamed:(NSString*)name {
    @synchronized (attributeDict) {
        id value = [attributeDict objectForKey:name];

        if (value) {
            [attributeDict removeObjectForKey:name];
            [_attributePersistentStore removeObjectForKey:name];
            return YES;
        }
        else {
            NRLOG_AGENT_VERBOSE(@"Failed to remove Session Attribute - it does not exist.");

            return NO;
        }
    }
}

- (BOOL) removeAllSessionAttributes {
    @synchronized (attributeDict) {
        @synchronized (privateAttributeDict) {

            [attributeDict removeAllObjects];
            [privateAttributeDict removeAllObjects];

            [_attributePersistentStore clearAll];
            [_privateAttributePersistentStore clearAll];
        }
    }
    return YES;
}

- (BOOL) incrementSessionAttribute:(NSString*)name value:(NSNumber*)number {
    @synchronized (attributeDict) {
        id existingValue = [attributeDict objectForKey:name];
        NSNumber *newValue;
        
        // if the existing value doesn't exist, the user meant to call setAttribute.
        // Should this return NO, to indicate the attribute doesn't exist?
        if (!existingValue) {
            if ([self checkAttribute:name value:number]){
                [attributeDict setValue:number forKey:name];
                [_attributePersistentStore setObject:number forKey:name];
                return YES;
            }
            return NO;
        }
        
        // cannot increment with non number values
        if (![NewRelicInternalUtils isInteger:number] && ![NewRelicInternalUtils isFloat:number]) {
            return NO;
        }
        
        // Cannot increment a non-number attribute
        if (![existingValue isKindOfClass:[NSNumber class]] ||
            (![NewRelicInternalUtils isInteger:existingValue] && ![NewRelicInternalUtils isFloat:existingValue])) {
            return NO;
        }
        
        if ([NewRelicInternalUtils isInteger:existingValue]) {
            unsigned long long incrementValueLongLong = [number unsignedLongLongValue];
            newValue = [NSNumber numberWithUnsignedLongLong:[existingValue unsignedLongLongValue] + incrementValueLongLong];
        } else if ([NewRelicInternalUtils isFloat:existingValue]) {
            double incrementValueDouble = [number doubleValue];
            newValue = [NSNumber numberWithDouble:[existingValue doubleValue] + incrementValueDouble];
        } else {
            // something that's not an integer or a floating point number got through
            return NO;
        }
        
        [attributeDict setValue:newValue forKey:name];
        [_attributePersistentStore setObject:newValue forKey:name];
    }

    return YES;
}

// Includes Public and Private Attributes
- (NSString*) sessionAttributeJSONString {

    NSMutableDictionary *output = [attributeDict mutableCopy];
    [output addEntriesFromDictionary:privateAttributeDict];

    NSError *error;
    NSData *jsonData = [NSJSONSerialization dataWithJSONObject:output options:0 error:&error];
    if (!jsonData) {
        NRLOG_AGENT_VERBOSE(@"Failed to create session attribute json w/ error = %@", error);
    }
    else {
        NSString* jsonString =  [[NSString alloc] initWithData:jsonData encoding:NSUTF8StringEncoding];
        return jsonString;
    }
    return nil;
}

+ (NSString*) getLastSessionsAttributes {
    NSError *error;
    NSString *lastSessionAttributesJsonString = nil;
    NSDictionary *lastSessionAttributes = [PersistentEventStore getLastSessionEventsFromFilename:[self attributeFilePath]];
    NSDictionary *lastSessionPrivateAttributes = [PersistentEventStore getLastSessionEventsFromFilename:[NRMASAM privateAttributeFilePath]];

    NSMutableDictionary *mergedDictionary = [NSMutableDictionary dictionary];
    [mergedDictionary addEntriesFromDictionary:lastSessionAttributes];
    [mergedDictionary addEntriesFromDictionary:lastSessionPrivateAttributes];

    @try {
         NSData *lastSessionAttributesJsonData = [NRMAJSON dataWithJSONObject:mergedDictionary
                                                                      options:0
                                                                        error:&error];
         lastSessionAttributesJsonString = [[NSString alloc] initWithData:lastSessionAttributesJsonData
                                                                 encoding:NSUTF8StringEncoding];
     }
     @catch (NSException *e) {
         NRLOG_AGENT_ERROR(@"FAILED TO CREATE LAST SESSION ATTRIBUTE JSON: %@", e.reason);
     }
    return lastSessionAttributesJsonString;
}

// Helpers

+(NSString*)attributeFilePath {
    return [NSString stringWithFormat:@"%@/%@",[NewRelicInternalUtils getStorePath],kNRMA_Attrib_file];
}
+(NSString*)privateAttributeFilePath {
    return [NSString stringWithFormat:@"%@/%@",[NewRelicInternalUtils getStorePath],kNRMA_Attrib_file_private];
}
@end
