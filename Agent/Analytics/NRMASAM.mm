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
#import "PersistentEventStore.h"

@interface NRMASAM ()
@end

@implementation NRMASAM {
    NSMutableDictionary<NSString*, id> *attributeDict;
    NSMutableDictionary<NSString*, id> *privateAttributeDict;

    __nullable id<AttributeValidatorProtocol> attributeValidator;
}

static PersistentEventStore* __attributePersistentStore;
+ (PersistentEventStore*) attributePersistentStore
{
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        NSString *attributeFilePath = [NRMASAM attributeFilePath];
        __attributePersistentStore = [[PersistentEventStore alloc] initWithFilename:attributeFilePath andMinimumDelay:.025];
    });
    return (__attributePersistentStore);
}

static PersistentEventStore* __privateAttributePersistentStore;
+ (PersistentEventStore*) privateAttributePersistentStore
{
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        NSString *privateAttributeFilePath = [NRMASAM privateAttributeFilePath];
        __privateAttributePersistentStore = [[PersistentEventStore alloc] initWithFilename:privateAttributeFilePath andMinimumDelay:.025];
    });
    return (__privateAttributePersistentStore);
}

- (id)initWithAttributeValidator:(__nullable id<AttributeValidatorProtocol>)validator {
    self = [super init];
    if (self) {

        NSDictionary *lastSessionAttributes = [[NRMASAM attributePersistentStore] getLastSessionEvents];
        if (lastSessionAttributes != nil) {
            attributeDict = [lastSessionAttributes mutableCopy];
        }
        if (!attributeDict) {
            attributeDict = [[NSMutableDictionary alloc] init];
        }

        // Load private attributes from file.
        NSDictionary *existingPrivateData = [[NRMASAM privateAttributePersistentStore] getLastSessionEvents];
        if (existingPrivateData != nil) {
            privateAttributeDict = [existingPrivateData mutableCopy];
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

        [[NRMASAM privateAttributePersistentStore] setObject:value forKey:name];
    }
    return YES;
}

- (BOOL) setSessionAttribute:(NSString*)name value:(id)value {
    return [self setAttribute:name value:value];
}

-  (BOOL) setAttribute:(NSString*)name value:(id)value {
    BOOL validAttribute = [attributeValidator nameValidator:name];
    BOOL validValue = [attributeValidator valueValidator:value];

    if (!(validAttribute && validValue)) {
        NRLOG_VERBOSE(@"Failed to create attribute named %@", name);
        return NO;
    }
    if (attributeDict.count >= kNRMA_Attrib_Max_Number_Attributes) {
        NRLOG_VERBOSE(@"Unable to add attribute %@, the max attribute limit (128) is reached", name);
        return NO;
    }

    if([value isKindOfClass:[NRMABool class]]) {
        value = @(([(NRMABool*) value value]));
    }

    @synchronized (attributeDict) {
        [attributeDict setValue:value forKey:name];
        [[NRMASAM attributePersistentStore] setObject:value forKey:name];
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
            [[NRMASAM attributePersistentStore] removeObjectForKey:name];
            return YES;
        }
        else {
            NRLOG_VERBOSE(@"Failed to remove Session Attribute - it does not exist.");

            return NO;
        }
    }
}

+ (void) clearDuplicationStores
{
    [[NRMASAM attributePersistentStore] clearAll];
    [[NRMASAM privateAttributePersistentStore] clearAll];
}

- (BOOL) removeAllSessionAttributes {
    @synchronized (attributeDict) {
        @synchronized (privateAttributeDict) {

            [attributeDict removeAllObjects];
            [privateAttributeDict removeAllObjects];

            [NRMASAM clearDuplicationStores];
        }
    }
    return YES;
}

- (BOOL) incrementSessionAttribute:(NSString*)name value:(NSNumber*)number {
    id existingValue;
    @synchronized (attributeDict) {
        existingValue = [attributeDict objectForKey:name];
    }
    NSNumber *newValue;

    // if the existing value doesn't exist, the user meant to call setAttribute.
    // Should this return NO, to indicate the attribute doesn't exist?
    if (!existingValue) {
        return [self setAttribute:name value:number];
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

    @synchronized (attributeDict) {
        [attributeDict setValue:newValue forKey:name];
        [[NRMASAM attributePersistentStore] setObject:newValue forKey:name];
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
        NRLOG_VERBOSE(@"Failed to create session attribute json w/ error = %@", error);
    }
    else {
        NSString* jsonString =  [[NSString alloc] initWithData:jsonData encoding:NSUTF8StringEncoding];
        return jsonString;
    }
    return nil;
}

// Public Attributes Only
- (NSString*) publicSessionAttributeJSONString {

    NSError *error;
    NSData *jsonData = [NSJSONSerialization dataWithJSONObject:attributeDict options:0 error:&error];
    if (!jsonData) {
        NRLOG_VERBOSE(@"Failed to create session attribute json w/ error = %@", error);
    }
    else {
        NSString* jsonString =  [[NSString alloc] initWithData:jsonData encoding:NSUTF8StringEncoding];

        return jsonString;
    }
    return nil;
}

// Private Attributes Only
- (NSString*) privateSessionAttributeJSONString {

    NSError *error;
    NSData *jsonData = [NSJSONSerialization dataWithJSONObject:privateAttributeDict options:0 error:&error];
    if (!jsonData) {
        NRLOG_VERBOSE(@"Failed to create session attribute json w/ error = %@", error);
    }
    else {
        NSString* jsonString =  [[NSString alloc] initWithData:jsonData encoding:NSUTF8StringEncoding];

        return jsonString;
    }
    return nil;
}

+ (NSString*) getLastSessionsAttributes {
    NSDictionary *lastSessionAttributes = [[NRMASAM attributePersistentStore] getLastSessionEvents];
    NSString *lastSessionAttributesJsonString = nil;
    @synchronized (lastSessionAttributes) {
        @try {
            NSData *lastSessionAttributesJsonData = [NRMAJSON dataWithJSONObject:lastSessionAttributes
                                                                         options:0
                                                                           error:nil];
            lastSessionAttributesJsonString = [[NSString alloc] initWithData:lastSessionAttributesJsonData
                                                                    encoding:NSUTF8StringEncoding];
        }
        @catch (NSException *e) {
            NRLOG_ERROR(@"FAILED TO CREATE LAST SESSION ATTRIBUTE JSON: %@", e.reason);
        }
    }
    
    return lastSessionAttributesJsonString;
}

- (void) clearLastSessionsAnalytics {
    @synchronized (attributeDict) {
        @synchronized (privateAttributeDict) {
            [attributeDict removeAllObjects];
            [privateAttributeDict removeAllObjects];
            
            [NRMASAM clearDuplicationStores];
        }
    }

}

// Helpers

+(NSString*)attributeFilePath {
    return [NSString stringWithFormat:@"%@/%@",[NewRelicInternalUtils getStorePath],kNRMA_Attrib_file];
}
+(NSString*)privateAttributeFilePath {
    return [NSString stringWithFormat:@"%@/%@",[NewRelicInternalUtils getStorePath],kNRMA_Attrib_file_private];
}
@end
